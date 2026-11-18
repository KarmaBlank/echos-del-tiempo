import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../app/theme/vision_palette.dart';
import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/models/eco.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/models/item.dart';
import '../../../../game_engine/models/loot.dart';
import '../../../../game_engine/models/loot_filter.dart';
import '../../../../game_engine/rules/loot_filter_rules.dart';
import '../../../../game_engine/rules/session_engine.dart';

/// Loot en el piso del mapa (docs/specs/loot.md § 4 y § 19.6,
/// docs/specs/exploration.md § "Loot en el piso"): ícono por tipo de arma
/// o material con brillo de rareza, etiqueta con el estilo del filtro del
/// jugador local y haz de luz en los Legendarios.

/// `FilterColor` → `Color`. Los colores de rareza por defecto siguen al
/// modo daltónico (`VisionPalette.remap`; accessibility.md § 3).
Color filterColor(FilterColor c) =>
    VisionPalette.remap(Color.fromARGB(c.a, c.r, c.g, c.b));

/// Color de rareza (el del filtro por defecto; con el modo daltónico, el
/// de su paleta).
Color rarityColor(Rarity r) => filterColor(LootFilterRules.rarityColor(r));

/// Color "de rareza" de un drop: el de su rareza, o el de los materiales.
Color dropColor(LootDrop d) => d.item != null
    ? rarityColor(d.item!.rarity)
    : d.eco != null
        ? rarityColor(d.eco!.rarity)
        : filterColor(LootFilterRules.defaultStyle(d).textColor!);

/// Nombre para mostrar de un drop: el del arma ([itemName], p. ej.
/// `ItemRules.displayName`) o `N Material`.
String lootDropName(String Function(ItemInstance) itemName, LootDrop d,
    {String Function(EcoItem)? ecoName}) {
  final it = d.item;
  if (it != null) return itemName(it);
  final eco = d.eco;
  if (eco != null) return ecoName?.call(eco) ?? 'Eco T${eco.tier}';
  final k = d.stack!;
  return d.count > 1 ? '${d.count} ${k.label}' : k.label;
}

/// Tamaño del filtro (18–45, como PoE) → px del lienzo virtual (5–7;
/// el mapa se ve ×2.5, y los nombres de los actores son de 6).
double labelPx(int? size) =>
    (5 + ((size ?? FilterStyle.defaultSize) - FilterStyle.minSize) / 13.5)
        .roundToDouble();

/// Un objeto del piso tal como lo ve el jugador local.
class LootOnFloor {
  const LootOnFloor(this.ground, this.verdict, {required this.hidden});

  final GroundLoot ground;
  final FilterVerdict verdict;

  /// El filtro lo oculta y se ve solo porque se mantiene Alt.
  final bool hidden;

  FilterStyle get style => verdict.style;
  bool get legendary => ground.drop.item?.rarity == Rarity.legendario;
}

/// Lo que se dibuja del piso para [localId]: lo suyo y lo compartido
/// (`groundFor`), lo que su filtro muestra y, con [showAll] (Alt), también
/// lo oculto.
List<LootOnFloor> visibleLoot(
  GameSession s,
  String localId,
  FilterVerdict Function(LootDrop d) verdict, {
  bool showAll = false,
}) {
  final out = <LootOnFloor>[];
  for (final g in s.groundFor(localId)) {
    final v = verdict(g.drop);
    if (!v.visible && !showAll) continue;
    out.add(LootOnFloor(g, v, hidden: !v.visible));
  }
  return out;
}

/// Qué levantaría E: el objeto dibujado más cercano a ≤ `pickReach`
/// (`PickUpAction`; el host vuelve a validar).
LootOnFloor? nearestPickable(List<LootOnFloor> loot, double x, double y) {
  LootOnFloor? best;
  var bd = SessionEngine.pickReach;
  for (final l in loot) {
    final d =
        math.sqrt(math.pow(l.ground.x - x, 2) + math.pow(l.ground.y - y, 2));
    if (d <= bd) {
      bd = d;
      best = l;
    }
  }
  return best;
}

/// Detecta el flanco de bajada de una tecla leída por frame (E / Espacio
/// para levantar).
class KeyEdge {
  bool _was = false;

  /// `true` solo en el frame en que [pressed] pasa a verdadero.
  bool poll(bool pressed) {
    final edge = pressed && !_was;
    _was = pressed;
    return edge;
  }
}

/// Colores de una etiqueta: los del filtro (texto, borde, fondo) o, sin
/// ellos, el color de la rareza sobre negro translúcido y sin borde. Lo
/// oculto que se ve con Alt, a media opacidad.
({Color text, Color background, Color? border}) labelColors(LootOnFloor l) {
  final st = l.style;
  final k = l.hidden ? 0.5 : 1.0;
  Color fade(Color c) => c.withValues(alpha: c.a * k);
  return (
    text: fade(st.textColor != null
        ? filterColor(st.textColor!)
        : dropColor(l.ground.drop)),
    background: fade(st.backgroundColor != null
        ? filterColor(st.backgroundColor!)
        : const Color(0xB3000000)),
    border: st.borderColor == null ? null : fade(filterColor(st.borderColor!)),
  );
}

/// Una etiqueta ya ubicada (px del mundo).
class PlacedLabel {
  PlacedLabel(this.loot, this.rect);
  final LootOnFloor loot;
  Rect rect;
}

/// Dibuja íconos, brillos, haces y etiquetas del loot del piso.
class LootPainter {
  LootPainter({required this.nameOf, required this.weaponTypeOf});

  /// Nombre para mostrar de un drop.
  final String Function(LootDrop d) nameOf;

  /// Tipo de arma de una base (`null` si no se conoce).
  final String? Function(String baseId) weaponTypeOf;

  final _fill = Paint()..isAntiAlias = false;
  final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..isAntiAlias = false;
  final _texts = <(String, int, double), TextPainter>{};

  /// Alto mínimo entre etiquetas apiladas.
  static const labelGap = 1.0;

  /// Haz de luz del Legendario: alto y ancho (px del mundo).
  static const beamHeight = 90.0;
  static const beamWidth = 9.0;

  void _rect(Canvas c, Color color, double x, double y, double w, double h) {
    _fill.color = color;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _fill);
  }

  TextPainter layout(String s, Color color, double size) {
    if (_texts.length > 256) _texts.clear();
    return _texts.putIfAbsent((s, color.toARGB32(), size), () {
      return TextPainter(
        text: TextSpan(
          text: retroText(s),
          style: TextStyle(
            fontFamily: RetroTheme.fontFamily,
            fontSize: size,
            color: color,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  // ------------------------------------------------------------ piso

  /// Brillo de rareza + ícono (capa del piso, debajo de los actores).
  void drawItem(Canvas c, LootOnFloor l, double t) {
    final g = l.ground;
    final d = g.drop;
    final x = g.x.roundToDouble(), y = g.y.roundToDouble();
    final col = dropColor(d);
    final alpha = l.hidden ? 0.45 : 1.0;
    final rarity = d.item?.rarity ?? d.eco?.rarity;
    // Brillo en el piso: más fuerte cuanto más rara.
    final k = 0.5 + 0.5 * math.sin(t / 260 + g.id);
    final strength = switch (rarity) {
      null => 0.25,
      Rarity.comun => 0.12,
      Rarity.magico => 0.25,
      Rarity.raro => 0.32,
      Rarity.epico => 0.4,
      Rarity.legendario => 0.5,
    };
    _fill.color = col.withValues(alpha: (strength + 0.12 * k) * alpha);
    c.drawOval(
        Rect.fromCenter(center: Offset(x, y + 1), width: 16, height: 6), _fill);
    _fill.color = const Color(0x55000000);
    c.drawOval(
        Rect.fromCenter(center: Offset(x, y + 1), width: 9, height: 3), _fill);
    c.save();
    c.translate(x, y);
    if (alpha < 1) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    }
    if (d.item case final it?) {
      _weaponIcon(c, weaponTypeOf(it.baseId));
    } else if (d.eco != null) {
      _ecoIcon(c, t);
    } else {
      _stackIcon(c, d.stack!);
    }
    // Destellos de Épicos y Legendarios.
    if ((rarity?.index ?? 0) >= Rarity.epico.index &&
        (t / 300 + g.id).floor() % 3 == 0) {
      _rect(c, const Color(0xFFFFFFFF), 4, -7, 1, 1);
      _rect(c, col, 3, -7, 1, 1);
      _rect(c, col, 5, -7, 1, 1);
    }
    if (alpha < 1) c.restore();
    c.restore();
  }

  /// Ícono de 9×5 px aprox. del arma tirada en diagonal.
  void _weaponIcon(Canvas c, String? type) {
    const steel = Color(0xFFDFE6E9);
    const wood = Color(0xFF8A5A2B);
    const gold = Color(0xFFFFD166);
    const dark = Color(0xFF636E72);
    switch (type) {
      case 'espada' || 'espada+escudo':
        for (var i = 0; i < 6; i++) {
          _rect(c, steel, -3.0 + i, -4.0 + i * 0.5, 1, 1);
        }
        _rect(c, gold, -5, -5, 1, 3);
        _rect(c, const Color(0xFF6B4423), -6, -5, 1, 1);
        if (type == 'espada+escudo') _shield(c);
      case 'hacha':
        _rect(c, wood, -5, -2, 9, 1);
        _rect(c, steel, 2, -5, 3, 4);
        _rect(c, dark, 2, -5, 1, 4);
      case 'maza+escudo':
        _rect(c, wood, -5, -2, 7, 1);
        _rect(c, const Color(0xFFB2BEC3), 2, -4, 3, 3);
        _rect(c, steel, 3, -5, 1, 1);
        _shield(c);
      case 'martillo+escudo':
        _rect(c, wood, -5, -2, 7, 1);
        _rect(c, const Color(0xFF95A5A6), 2, -5, 3, 5);
        _shield(c);
      case 'báculo':
        _rect(c, wood, -6, -2, 10, 1);
        _fill.color = const Color(0xFF74B9FF);
        c.drawCircle(const Offset(5, -2), 1.8, _fill);
      case 'tomo':
        _rect(c, const Color(0xFF6C5CE7), -4, -5, 8, 5);
        _rect(c, const Color(0xFFDFE6E9), -3, -4, 6, 1);
        _rect(c, gold, -1, -3, 2, 2);
      case 'arco':
        for (var i = 0; i < 7; i++) {
          final dy = ((i - 3).abs() * 0.7).roundToDouble();
          _rect(c, wood, -4.0 + i, -5 + dy, 1, 1);
        }
        _rect(c, steel, -4, -2, 7, 1);
      case 'rifle':
        _rect(c, dark, -5, -3, 9, 2);
        _rect(c, const Color(0xFF6B4423), -5, -1, 3, 2);
      case 'lanza':
        _rect(c, wood, -6, -2, 10, 1);
        _rect(c, steel, 4, -3, 2, 3);
        _rect(c, const Color(0xFFD63031), 3, -3, 1, 1);
      case 'dagas':
        _rect(c, steel, -4, -4, 4, 1);
        _rect(c, const Color(0xFF6C5CE7), -5, -5, 1, 3);
        _rect(c, steel, 0, -1, 4, 1);
        _rect(c, const Color(0xFF6C5CE7), -1, -2, 1, 3);
      case 'varita':
        _rect(c, const Color(0xFF5A3A1A), -4, -2, 7, 1);
        _rect(c, const Color(0xFFA29BFE), 3, -3, 2, 2);
        _rect(c, const Color(0xFFFFFFFF), 5, -4, 1, 1);
      case 'ballesta':
        _rect(c, const Color(0xFF6B4423), -5, -2, 8, 2);
        _rect(c, const Color(0xFF95A5A6), 3, -5, 1, 7);
        _rect(c, steel, -2, -3, 6, 1);
      default:
        _rect(c, steel, -3, -4, 6, 3);
    }
  }

  void _shield(Canvas c) {
    _rect(c, const Color(0xFF2C3E50), -6, -6, 4, 5);
    _rect(c, const Color(0xFFD4AF37), -5, -5, 2, 3);
  }

  /// Eco en el piso: un anillo turquesa que late, con un punto adentro.
  void _ecoIcon(Canvas c, double t) {
    const ring = Color(0xFF5AE6D2);
    const core = Color(0xFFE8FFFB);
    final k = ((t / 200).floor() % 2).toDouble();
    _rect(c, ring, -2, -7, 4, 1);
    _rect(c, ring, -2, -1, 4, 1);
    _rect(c, ring, -3, -6, 1, 5);
    _rect(c, ring, 2, -6, 1, 5);
    _rect(c, core, -1, -5 + k, 2, 2);
  }

  void _stackIcon(Canvas c, StackKind k) {
    switch (k) {
      case StackKind.potion || StackKind.ether:
        final liquid = k == StackKind.potion
            ? const Color(0xFFFF4757)
            : const Color(0xFF74B9FF);
        _rect(c, const Color(0xFFDFE6E9), -1, -7, 2, 2);
        _rect(c, liquid, -2, -5, 4, 4);
        _rect(c, const Color(0xFFFFFFFF), -1, -4, 1, 1);
      case StackKind.esquirla:
        _fill.color = const Color(0xFF81ECEC);
        c.drawPath(
            Path()
              ..moveTo(0, -7)
              ..lineTo(2, -2)
              ..lineTo(0, 0)
              ..lineTo(-2, -2)
              ..close(),
            _fill);
        _rect(c, const Color(0xFFFFFFFF), 0, -5, 1, 2);
      case StackKind.cristal:
        _rect(c, const Color(0xFF0984E3), -2, -6, 4, 6);
        _rect(c, const Color(0xFF74B9FF), -1, -6, 2, 5);
        _rect(c, const Color(0xFFFFFFFF), -1, -5, 1, 1);
      case StackKind.ancla:
        _rect(c, const Color(0xFF9FB4FF), 0, -7, 1, 6);
        _rect(c, const Color(0xFFDFE6E9), -2, -6, 5, 1);
        _rect(c, const Color(0xFF9FB4FF), -2, -2, 1, 1);
        _rect(c, const Color(0xFF9FB4FF), 2, -2, 1, 1);
        _rect(c, const Color(0xFF9FB4FF), -1, -1, 3, 1);
      case StackKind.prisma:
        _fill.color = const Color(0xFFFDCB6E);
        c.drawPath(
            Path()
              ..moveTo(0, -7)
              ..lineTo(3, 0)
              ..lineTo(-3, 0)
              ..close(),
            _fill);
        _rect(c, const Color(0xFFE84393), -1, -3, 1, 1);
        _rect(c, const Color(0xFF74B9FF), 0, -3, 1, 1);
        _rect(c, const Color(0xFF55EFC4), 1, -3, 1, 1);
    }
  }

  /// Haz de luz vertical (Legendario en el piso o recién caído). [boost]
  /// 0..1 = estallido de los primeros instantes.
  /// [density]: ajuste PARTÍCULAS (motas que suben).
  void drawBeam(Canvas c, double x, double y, double t,
      {double boost = 0, double density = 1}) {
    const orange = Color(0xFFFF8C28);
    final k = 0.5 + 0.5 * math.sin(t / 180);
    final w = beamWidth + 6 * boost;
    final h = beamHeight + 60 * boost;
    final top = y - h;
    // Columna con degradé (sin antialias: tres franjas).
    for (var i = 0; i < 6; i++) {
      final f = i / 6;
      _fill.color = orange.withValues(
          alpha: (0.65 + 0.15 * k + 0.3 * boost).clamp(0.0, 1.0) *
              (0.2 + 0.8 * f));
      c.drawRect(Rect.fromLTWH(x - w / 2, y - h * (1 - f), w, h / 6), _fill);
    }
    _fill.color = const Color(0xFFFFF0C8)
        .withValues(alpha: (0.7 + 0.25 * k + 0.3 * boost).clamp(0.0, 1.0));
    c.drawRect(Rect.fromLTWH(x - 1, top + h * 0.15, 3, h * 0.85), _fill);
    // Motas que suben.
    for (var i = 0; i < scaledCount(4, density); i++) {
      final f = (t / 900 + i / 4) % 1.0;
      _fill.color = const Color(0xFFFFF3B0).withValues(alpha: 1 - f);
      c.drawRect(
          Rect.fromLTWH((x - 3 + (i * 5) % 7).roundToDouble(),
              (y - f * h * 0.8).roundToDouble(), 1, 1),
          _fill);
    }
    if (boost > 0) {
      _stroke.color = orange.withValues(alpha: boost);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(x, y),
              width: 40 * (1 - boost) + 10,
              height: 14 * (1 - boost) + 4),
          _stroke);
    }
  }

  // --------------------------------------------------------- etiquetas

  /// Texto de la etiqueta: el nombre, con ★ si cumple tu plan de build
  /// (build_planner.md § 6).
  String labelText(LootOnFloor l) => l.verdict.buildMatch
      ? '★ ${nameOf(l.ground.drop)}'
      : nameOf(l.ground.drop);

  /// Ubica las etiquetas encima de cada objeto, apilándolas hacia arriba
  /// para que no se pisen (como los filtros del género) y, con [view]
  /// (lo visible del mundo), sin salirse de la pantalla por los costados.
  List<PlacedLabel> placeLabels(List<LootOnFloor> loot, {Rect? view}) {
    final sorted = [...loot]..sort((a, b) {
        final c = b.ground.y.compareTo(a.ground.y);
        return c != 0 ? c : a.ground.id.compareTo(b.ground.id);
      });
    final placed = <PlacedLabel>[];
    for (final l in sorted) {
      final size = labelPx(l.style.size);
      final tp = layout(labelText(l), Colors.white, size);
      final w = tp.width + 6, h = size + 4;
      var left = l.ground.x - w / 2;
      if (view != null) {
        left = left.clamp(
            view.left + 2, math.max(view.left + 2, view.right - w - 2));
      }
      var r = Rect.fromLTWH(
          left.roundToDouble(), (l.ground.y - 12 - h).roundToDouble(), w, h);
      for (var i = 0; i < 12; i++) {
        final hit = placed.where((p) => p.rect.overlaps(r)).toList();
        if (hit.isEmpty) break;
        final top = hit.map((p) => p.rect.top).reduce(math.min);
        r = r.shift(Offset(0, top - labelGap - r.bottom));
      }
      placed.add(PlacedLabel(l, r));
    }
    return placed;
  }

  /// Dibuja una etiqueta: fondo, borde y texto con el estilo del filtro
  /// (lo oculto que se ve con Alt, a media opacidad).
  void drawLabel(Canvas c, PlacedLabel p) {
    final l = p.loot;
    final col = labelColors(l);
    _fill.color = col.background;
    c.drawRect(p.rect, _fill);
    if (col.border case final b?) {
      _stroke.color = b;
      c.drawRect(p.rect.deflate(0.5), _stroke);
    }
    final tp = layout(labelText(l), col.text, labelPx(l.style.size));
    tp.paint(c, Offset(p.rect.left + 3, p.rect.top + 2));
  }
}
