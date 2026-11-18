import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/models/loot_filter.dart';
import '../map/map_themes.dart';

/// Un ícono de loot en el minimapa (`Icono` del filtro, loot.md § 6).
class MinimapLoot {
  const MinimapLoot(this.x, this.y, this.icon);
  final double x, y;
  final MapIcon icon;
}

/// Color de arte de cada `MapIconColor`.
Color mapIconColor(MapIconColor c) => switch (c) {
      MapIconColor.blanco => const Color(0xFFFFFFFF),
      MapIconColor.rojo => const Color(0xFFFF4757),
      MapIconColor.verde => const Color(0xFF7BED9F),
      MapIconColor.azul => const Color(0xFF4B7BEC),
      MapIconColor.amarillo => const Color(0xFFFFD166),
      MapIconColor.naranja => const Color(0xFFFF8C28),
      MapIconColor.violeta => const Color(0xFFBE6EFF),
      MapIconColor.celeste => const Color(0xFF48DBFB),
    };

/// Color de un tile en el minimapa (exploration.md § "HUD" y § "Minimapa
/// (v0.3)"). Colores = arte del prototipo.
Color minimapTileColor(String ch) => switch (ch) {
      // v0.6: los PdI no se ven en la base (worldgen.md § 11.7).
      Tile.wall ||
      Tile.gate ||
      Tile.cracked ||
      Tile.shortcut =>
        const Color(0xFF0B0E1A),
      Tile.tree => const Color(0xFF1D3B26),
      Tile.rock => const Color(0xFF3A3D48),
      Tile.water => const Color(0xFF2E86DE),
      Tile.merchant => const Color(0xFFFFD166),
      Tile.path => const Color(0xFF6C7A9C),
      Tile.grass => const Color(0xFF3E6B48),
      Tile.stairsDown || Tile.stairsUp => const Color(0xFFFFD166),
      Tile.voidTile => kMinimapVoid,
      Tile.bridge => const Color(0xFFA07A44),
      Tile.lava => const Color(0xFFFF5A1F),
      Tile.tombstone => const Color(0xFF6C707A),
      Tile.gear => const Color(0xFFB08A3A),
      _ when Tile.entranceZone(ch) != null => const Color(0xFF3E6B48),
      _ => const Color(0xFF4B5878),
    };

/// Color del punto de un PdI descubierto (worldgen.md § 11.7); `null` = no
/// se marca (reliquia ya levantada).
Color? poiMinimapColor(MapPoi p, MissionRun m) {
  final used = m.poiUsed.contains(p.id);
  const spent = Color(0xFF6C707A);
  return switch (p.kind) {
    PoiKind.secret => used ? spent : const Color(0xFFBE6EFF),
    PoiKind.shrine => used ? spent : const Color(0xFF5AE6D2),
    PoiKind.waystone =>
      used ? const Color(0xFFFFD166) : const Color(0xFFB0B6C8),
    PoiKind.wind => const Color(0xFFBFEFFF),
    PoiKind.shortcut => used ? spent : const Color(0xFFFF8C28),
    PoiKind.brazier => used ? const Color(0xFFFF8C28) : const Color(0xFFE8D6B0),
    PoiKind.relic => used ? null : const Color(0xFFFFB347),
  };
}

/// Los PdI que se marcan en el minimapa y el mapa en grande: solo los
/// descubiertos (`MissionRun.poiSeen`), con su color (worldgen.md § 11.7).
List<(MapPoi, Color)> minimapPois(MapFloor? floor, MissionRun m) => [
      for (final poi in floor?.pois ?? const <MapPoi>[])
        if (m.poiSeen.contains(poi.id))
          if (poiMinimapColor(poi, m) case final c?) (poi, c),
    ];

/// Vacío en el minimapa (como el fondo fuera del mapa).
const kMinimapVoid = Color(0xFF05060C);

/// `drawMinimap` del prototipo como widget (docs/specs/exploration.md §
/// "HUD"). Colores = arte del prototipo, igual que el mapa.
///
/// v0.8.1: con [view] muestra solo una ventana de `view` tiles (como
/// mucho) centrada en [center] (por defecto, el jugador local) y recortada
/// a los bordes del piso; [cell] es el zoom (px de pantalla por tile).
class Minimap extends StatelessWidget {
  const Minimap({
    super.key,
    required this.map,
    required this.session,
    required this.localId,
    required this.localX,
    required this.localY,
    required this.time,
    this.loot = const [],
    this.bounds,
    this.entranceOpen,
    this.cell = baseCell,
    this.view,
    this.center,
  });

  /// Rectángulo del atlas a mostrar (el piso actual); `null` = todo.
  final TileRect? bounds;

  /// Si la entrada de la zona está abierta para el jugador local (mapa del
  /// mundo; las cerradas van en gris).
  final bool Function(int zone)? entranceOpen;

  /// Píxeles de pantalla por tile sin zoom (el prototipo usa 1.25 px
  /// virtuales, ×2 para la pantalla).
  static const baseCell = 2.5;

  /// Factor de los puntos respecto del prototipo.
  static const dotScale = baseCell / 1.25;

  /// Zoom: píxeles de pantalla por tile.
  final double cell;

  /// Ventana en tiles (`null` = el piso entero).
  final Size? view;

  /// Centro de la ventana en tiles (`null` = el jugador local).
  final Offset? center;

  final GameMap map;
  final GameSession session;
  final String localId;
  final double localX, localY;

  /// Reloj de la sesión en segundos (parpadeo del jefe).
  final double time;

  /// Loot del piso con ícono según el filtro del jugador local.
  final List<MinimapLoot> loot;

  /// El rectángulo mostrado del piso (o el mapa).
  TileRect get area => bounds ?? TileRect(0, 0, map.width, map.height);

  /// La ventana visible en tiles: a lo sumo [view], centrada en [center]
  /// (o en el jugador) y sin salirse de [area].
  Rect get visible =>
      viewRect(area, view, center ?? Offset(localX / 16, localY / 16));

  /// Ventana de [view] tiles centrada en [c], recortada a [b] (si [b] es
  /// más chico que la ventana, se ve [b] entero).
  static Rect viewRect(TileRect b, Size? view, Offset c) {
    if (view == null) {
      return Rect.fromLTWH(
          b.x.toDouble(), b.y.toDouble(), b.w.toDouble(), b.h.toDouble());
    }
    final w = math.min(view.width, b.w.toDouble());
    final h = math.min(view.height, b.h.toDouble());
    final x = (c.dx - w / 2).clamp(b.x.toDouble(), b.x + b.w - w);
    final y = (c.dy - h / 2).clamp(b.y.toDouble(), b.y + b.h - h);
    return Rect.fromLTWH(x, y, w, h);
  }

  @override
  Widget build(BuildContext context) {
    final v = visible;
    return SizedBox(
      width: v.width * cell,
      height: v.height * cell,
      child: CustomPaint(
        painter: _MinimapPainter(this, v),
      ),
    );
  }
}

/// La base del minimapa (tiles) se graba una vez por mapa.
final _baseCache = Expando<ui.Picture>('minimapa');

class _MinimapPainter extends CustomPainter {
  _MinimapPainter(this.w, this.v);

  final Minimap w;

  /// Ventana visible (tiles).
  final Rect v;

  static const _ts = 16.0;

  ui.Picture _base(GameMap map) {
    final cached = _baseCache[map];
    if (cached != null) return cached;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final p = Paint()..isAntiAlias = false;
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        final ch = map.tileAt(x, y);
        p.color = minimapTileColor(ch);
        c.drawRect(
            Rect.fromLTWH(x * Minimap.baseCell, y * Minimap.baseCell,
                Minimap.baseCell, Minimap.baseCell),
            p);
      }
    }
    return _baseCache[map] = rec.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final map = w.map;
    final s = w.session;
    final b = w.area;
    const cell = Minimap.baseCell;
    // Zoom: se dibuja en unidades de 2.5 px por tile y se escala. Los
    // puntos crecen menos que el mapa (raíz del zoom).
    final k = w.cell / cell;
    final dk = math.sqrt(k) / k;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(k);
    canvas.translate(-v.left * cell, -v.top * cell);
    final shown = Rect.fromLTWH(
        v.left * cell, v.top * cell, v.width * cell, v.height * cell);
    canvas.saveLayer(
        shown, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.85));
    canvas.drawPicture(_base(map));
    canvas.restore();

    final p = Paint()..isAntiAlias = false;
    final x0 = math.max(b.x, v.left.floor());
    final y0 = math.max(b.y, v.top.floor());
    final x1 = math.min(b.x + b.w, v.right.ceil());
    final y1 = math.min(b.y + b.h, v.bottom.ceil());
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        if (map.tileAt(x, y) != Tile.gate) continue;
        p.color =
            s.gateOpen ? const Color(0xFF7BED9F) : const Color(0xFFFF4757);
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), p);
      }
    }
    void dot(double px, double py, Color c, double s2) {
      final d = s2 * Minimap.dotScale * dk;
      p.color = c;
      canvas.drawRect(
          Rect.fromLTWH(px / _ts * cell - d / 2, py / _ts * cell - d / 2, d, d),
          p);
    }

    // Entradas de zona (mundo): cuadro de 3 tiles del color de la zona.
    for (final e in map.entrances) {
      final open = w.entranceOpen?.call(e.zone) ?? true;
      p.color = const Color(0xFF000000);
      canvas.drawRect(
          Rect.fromLTWH((e.tx - 1) * cell - 1, (e.ty - 1) * cell - 1,
              cell * 3 + 2, cell * 3 + 2),
          p);
      p.color = open ? zoneColor(e.zone) : kLockedZoneColor;
      canvas.drawRect(
          Rect.fromLTWH(
              (e.tx - 1) * cell, (e.ty - 1) * cell, cell * 3, cell * 3),
          p);
    }

    final m = s.mission;
    if (m != null) {
      for (final e in m.enemies) {
        if (e.floor != m.floor) continue;
        if (e.alive && !e.boss) {
          dot(
              e.x,
              e.y,
              e.elite ? const Color(0xFFFFD166) : const Color(0xFFFF4757),
              e.elite ? 3 : 2);
        }
      }
      for (final it in m.items) {
        if (it.floor != m.floor) continue;
        switch (it.kind) {
          case MissionItemKind.fragment when !it.done:
            dot(it.x, it.y, const Color(0xFF48DBFB), 3);
          case MissionItemKind.seal:
            dot(it.x, it.y,
                it.done ? const Color(0xFF7BED9F) : const Color(0xFFA29BFE), 3);
          case MissionItemKind.chest
              when !it.done &&
                  (it.secret == null || m.poiUsed.contains(it.secret)):
            dot(it.x, it.y, const Color(0xFFFFD166),
                it.tier == ChestTier.oro ? 4 : 3);
          default:
            break;
        }
      }
      // Puntos de interés descubiertos (worldgen.md § 11.7).
      for (final (poi, c) in minimapPois(map.floor(m.floor), m)) {
        dot(poi.center.x, poi.center.y, c, 3);
      }
      for (final e in m.enemies) {
        if (!e.boss || !e.alive || e.floor != m.floor) continue;
        final blink = (w.time * 1000 / 300).floor() % 2 == 1;
        final tp = TextPainter(
          text: TextSpan(
            text: '★',
            style: TextStyle(
              fontFamily: RetroTheme.fontFamily,
              fontSize: 8 * dk,
              height: 1,
              color: blink ? const Color(0xFFE84393) : const Color(0xFFFFD166),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            Offset(e.x / _ts * cell - tp.width / 2,
                e.y / _ts * cell - tp.height / 2));
      }
    }
    for (final l in w.loot) {
      _lootIcon(canvas, p, l, dk);
    }
    final merchant = map.merchant;
    if (merchant != null) {
      dot(merchant.x, merchant.y - 10, const Color(0xFFFFD166), 3);
    }
    for (final pl in s.playerList) {
      final mine = pl.id == w.localId;
      dot(mine ? w.localX : pl.x, mine ? w.localY : pl.y,
          mine ? const Color(0xFFFFFFFF) : const Color(0xFF48DBFB), 3);
    }
    canvas.restore();
  }

  /// Ícono de 5 px (de pantalla) con contorno negro.
  void _lootIcon(Canvas canvas, Paint p, MinimapLoot l, double dk) {
    const cell = Minimap.baseCell;
    final o = Offset(l.x / _ts * cell, l.y / _ts * cell);
    final r = 3.0 * dk;
    final path = switch (l.icon.shape) {
      MapIconShape.circulo => Path()
        ..addOval(Rect.fromCircle(center: o, radius: r)),
      MapIconShape.cuadrado => Path()
        ..addRect(Rect.fromCircle(center: o, radius: r - 0.5 * dk)),
      MapIconShape.triangulo => Path()
        ..moveTo(o.dx, o.dy - r)
        ..lineTo(o.dx + r, o.dy + r)
        ..lineTo(o.dx - r, o.dy + r)
        ..close(),
      MapIconShape.diamante => Path()
        ..moveTo(o.dx, o.dy - r - 0.5 * dk)
        ..lineTo(o.dx + r, o.dy)
        ..lineTo(o.dx, o.dy + r + 0.5 * dk)
        ..lineTo(o.dx - r, o.dy)
        ..close(),
      MapIconShape.estrella => _star(o, r + dk),
    };
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * dk
          ..color = const Color(0xFF000000));
    p.color = mapIconColor(l.icon.color);
    canvas.drawPath(path, p);
  }

  static Path _star(Offset o, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -1.5708 + i * 0.6283;
      final pt = o + Offset(rr * math.cos(a), rr * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_MinimapPainter old) => true;
}
