import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/quest_track_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../../../../game_engine/rules/sky_rules.dart';
import '../../../../game_engine/rules/town_plan.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import 'map_themes.dart';

class _Pop {
  _Pop(this.playerId, this.tx, this.ty, this.label, this.color, this.fruit,
      this.t0);
  final String playerId;
  final int tx, ty;
  final String label;
  final Color color, fruit;
  final double t0;
}

typedef MapText = void Function(
    String text, double x, double y, Color color, double size);

/// La huerta dibujada en el mapa del pueblo (farming.md § 2.3, v0.23.0):
/// surcos de lo arado, tierra oscura si está regada, abono, las etapas de
/// cada cultivo (semilla, brote, crecido, maduro con brillo), el ayudante
/// y el "pop" de la cosecha que salta hacia quien cosechó. Arte
/// procedural; colores en [FarmPalette].
class MapFarmLayer {
  final _pops = <_Pop>[];

  /// Duración del salto de la cosecha (ms).
  static const popMs = 800.0;

  /// Hay un pop en curso (tests y capturas).
  bool get popping => _pops.isNotEmpty;

  static const ts = 16.0;

  /// Parcelas (debajo de los actores). [view]: rectángulo visible (px).
  void drawPlots(Canvas c, TownState town, Rect view, double t) {
    for (final e in town.plots.entries) {
      final xy = parsePlotKey(e.key);
      if (xy == null) continue;
      final px = xy.$1 * ts, py = xy.$2 * ts;
      if (px + ts < view.left || px > view.right) continue;
      if (py + ts < view.top || py > view.bottom) continue;
      _plot(c, e.value, xy.$1, xy.$2, t);
    }
  }

  /// La azada en la mano del jugador local, mirando a [face] (-1/0/1).
  void drawHoe(Canvas c, double px, double py, num face) {
    final f = face < 0 ? -1.0 : 1.0;
    final hand = Offset(px + f * 4, py - 6);
    final top = Offset(px + f * 9, py - 17);
    c.drawLine(
        hand,
        top,
        Paint()
          ..color = FarmPalette.hoeHandle
          ..strokeWidth = 1.5);
    c.drawRect(Rect.fromLTWH(top.dx - (f < 0 ? 4 : 0), top.dy, 4, 2),
        Paint()..color = FarmPalette.hoeBlade);
  }

  /// Recuadro de los tiles que tocará el próximo E / clic: verde si la
  /// herramienta elegida sirve, naranja si no (el motivo va en el aviso).
  void drawTarget(Canvas c, List<(int, int)> tiles, bool ok) {
    final p = Paint()
      ..color = ok ? FarmPalette.targetOk : FarmPalette.targetBad
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (x, y) in tiles) {
      c.drawRect(Rect.fromLTWH(x * ts + 0.5, y * ts + 0.5, ts - 1, ts - 1), p);
    }
  }

  /// La bolsita de semillas en la mano, con el color del fruto elegido.
  void drawSeedBag(Canvas c, double px, double py, num face, Color fruit) {
    final f = face < 0 ? -1.0 : 1.0;
    final x = px + f * 6 - 2.5, y = py - 10;
    c.drawRect(Rect.fromLTWH(x, y, 5, 5), Paint()..color = FarmPalette.seedBag);
    c.drawRect(
        Rect.fromLTWH(x + 1, y - 1, 3, 1), Paint()..color = FarmPalette.seedBagTie);
    c.drawRect(Rect.fromLTWH(x + 2, y + 2, 1, 1), Paint()..color = fruit);
  }

  /// La regadera en la mano, con el pico hacia [face].
  void drawCan(Canvas c, double px, double py, num face) {
    final f = face < 0 ? -1.0 : 1.0;
    final x = px + f * 6 - 3, y = py - 11;
    c.drawRect(Rect.fromLTWH(x, y, 6, 5), Paint()..color = FarmPalette.can);
    c.drawRect(Rect.fromLTWH(x + 1, y - 2, 4, 1), Paint()..color = FarmPalette.canDark);
    c.drawLine(Offset(px + f * (f < 0 ? 3 : 9), y + 1),
        Offset(px + f * 12, y - 2), Paint()
          ..color = FarmPalette.canDark
          ..strokeWidth = 1);
  }

  /// Una parcela en el tile ([tx], [ty]) (tests y capturas).
  void drawPlot(Canvas c, FarmPlot p, int tx, int ty, double t) =>
      _plot(c, p, tx, ty, t);

  /// Punto (relativo al tile) donde cae la semilla: al azar pero
  /// determinista por parcela, cultivo y quien plantó, así todos los
  /// clientes lo ven igual y no salta entre cuadros (farming.md § 2.3).
  static Offset seedOffset(int tx, int ty, String seed, String? planter) {
    var h = 0x811C9DC5;
    for (final u in '$tx,$ty|$seed|${planter ?? ''}'.codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
    }
    final dx = 4 + (h & 0xFF) % 9; // 4..12
    final dy = 9 + ((h >> 8) & 0xFF) % 5; // 9..13
    return Offset(dx.toDouble(), dy.toDouble());
  }

  /// La planta crecida ([ripe] = false) o madura con su fruto. [r] pinta
  /// un rectángulo relativo a la base de la planta.
  void _plant(void Function(double, double, double, double, Color) r,
      CropLook l, bool ripe, double t) {
    final g = l.plant, f = l.fruit, a = l.accent;
    switch (l.shape) {
      case CropShape.root:
        r(-3, -6, 2, 3, g);
        r(1, -7, 2, 4, g);
        r(-1, -5, 1, 3, g);
        if (ripe) {
          r(-2, -2, 5, 3, f);
          r(-2, -3, 5, 1, a);
          r(0, 1, 1, 1, f);
        }
      case CropShape.grain:
        for (final (dx, hgt) in const [(-2.0, 9.0), (0.0, 11.0), (2.0, 10.0)]) {
          r(dx, -hgt, 1, hgt, g);
          if (ripe) {
            r(dx - 1, -hgt - 1, 1, 3, f);
            r(dx + 1, -hgt, 1, 3, f);
            r(dx, -hgt - 2, 1, 1, a);
          }
        }
      case CropShape.tuber:
        r(-4, -5, 8, 2, g);
        r(-2, -7, 4, 2, g);
        r(0, -3, 1, 3, g);
        if (ripe) {
          r(-5, -1, 3, 2, f);
          r(-1, 0, 3, 2, f);
          r(3, -1, 2, 2, f);
          r(-4, 0, 1, 1, a);
          r(0, 1, 1, 1, a);
        }
      case CropShape.pumpkin:
        r(-5, -3, 3, 2, g);
        r(3, -4, 3, 2, g);
        r(0, -6, 1, 3, g);
        if (ripe) {
          r(-3, -3, 7, 4, f);
          r(-2, -4, 5, 1, f);
          r(-1, -3, 1, 4, a);
          r(1, -3, 1, 4, a);
          r(0, -6, 1, 2, g);
        } else {
          r(-1, -2, 3, 2, a);
        }
      case CropShape.berries:
        r(-4, -6, 8, 3, g);
        r(-2, -8, 4, 2, g);
        r(0, -3, 1, 3, g);
        if (ripe) {
          for (final (dx, dy) in const [
            (-4.0, -3.0),
            (-1.0, -2.0),
            (2.0, -3.0),
            (0.0, -6.0)
          ]) {
            r(dx, dy, 2, 2, f);
            r(dx, dy, 1, 1, a);
          }
        }
      case CropShape.bulb:
        r(-2, -8, 1, 6, g);
        r(0, -10, 1, 8, g);
        r(2, -7, 1, 5, g);
        if (ripe) {
          r(-2, -3, 5, 3, f);
          r(-1, -4, 3, 1, f);
          r(-1, -2, 1, 1, a);
          r(0, 0, 1, 1, f);
        }
      case CropShape.flower:
        r(0, -9, 1, 9, g);
        r(-3, -5, 3, 1, g);
        r(1, -6, 3, 1, g);
        if (ripe) {
          r(-1, -12, 3, 1, f);
          r(-2, -11, 5, 1, f);
          r(-1, -10, 3, 1, f);
          r(-2, -13, 1, 1, f);
          r(2, -13, 1, 1, f);
          r(0, -11, 1, 1, a);
        } else {
          r(-1, -10, 2, 2, a);
        }
      case CropShape.melon:
        r(-6, -4, 4, 2, g);
        r(3, -5, 4, 2, g);
        r(-1, -7, 2, 2, g);
        if (ripe) {
          r(-4, -4, 8, 5, f);
          r(-3, -5, 6, 1, f);
          r(-2, -4, 1, 5, a);
          r(1, -4, 1, 5, a);
          r(-5, -2, 1, 1, a);
          r(4, -2, 1, 1, a);
        }
      case CropShape.rose:
        r(0, -10, 1, 10, g);
        r(-3, -6, 3, 2, g);
        r(1, -4, 3, 2, g);
        r(1, -8, 1, 1, g);
        if (ripe) {
          r(-1, -13, 3, 3, f);
          r(-2, -12, 1, 2, f);
          r(2, -12, 1, 2, f);
          r(0, -12, 1, 1, a);
        } else {
          r(0, -12, 1, 2, f);
        }
      case CropShape.crystal:
        r(-3, -4, 2, 4, g);
        r(2, -3, 2, 3, g);
        if (ripe) {
          r(-1, -9, 3, 9, f);
          r(0, -11, 1, 2, f);
          r(-3, -6, 2, 5, f);
          r(2, -5, 2, 4, f);
          r(0, -8, 1, 4, a);
        } else {
          r(-1, -5, 2, 5, g);
        }
    }
    if (ripe && l.glow) {
      // Destellos que se alternan (legendarios).
      final on = (t ~/ 300) % 2 == 0;
      final sp = on
          ? const [(-5.0, -10.0), (4.0, -7.0)]
          : const [(5.0, -12.0), (-4.0, -4.0)];
      for (final (dx, dy) in sp) {
        r(dx, dy, 1, 1, a);
      }
    }
  }

  void _plot(Canvas c, FarmPlot p, int tx, int ty, double t) {
    final px = tx * ts, py = ty * ts;
    final paint = Paint();

    c.drawRect(Rect.fromLTWH(px + 1, py + 1, ts - 2, ts - 2),
        paint..color = p.watered ? FarmPalette.wet : FarmPalette.tilled);
    paint.color = FarmPalette.furrow;
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(px + 2, py + 3 + i * 5, ts - 4, 1), paint);
    }
    if (p.fert != null) {
      paint.color = FarmPalette.fert;
      for (final (dx, dy) in const [(3, 2), (11, 7), (6, 12)]) {
        c.drawRect(Rect.fromLTWH(px + dx, py + dy, 1, 1), paint);
      }
    }
    final seed = p.seed;
    if (seed == null) return;
    final look = CropPalette.of(seed);
    final o = seedOffset(tx, ty, seed, p.planter);
    final x = px + o.dx, y = py + o.dy;
    void r(double dx, double dy, double w, double h, Color col) =>
        c.drawRect(Rect.fromLTWH(x + dx, y + dy, w, h), paint..color = col);
    switch (FarmingRules.stage(p)) {
      case CropStage.arada:
        break;
      case CropStage.semilla:
        r(-1, -1, 2, 2, look.seed);
      case CropStage.brote:
        r(0, -4, 1, 4, look.plant);
        r(-2, -4, 2, 1, look.plant);
        r(1, -5, 2, 1, look.plant);
        r(-1, 0, 2, 1, look.seed);
      case CropStage.crecido:
        _plant(r, look, false, t);
      case CropStage.maduro:
        final glow = 0.5 + 0.5 * math.sin(t / 260);
        c.drawRect(
            Rect.fromLTWH(px - 1, py - 4, ts + 2, ts + 3),
            paint
              ..color = FarmPalette.ripeGlow
                  .withValues(alpha: FarmPalette.ripeGlow.a * glow));
        _plant(r, look, true, t);
    }
    if (p.watered && !FarmingRules.ripe(p)) {
      c.drawRect(Rect.fromLTWH(px + 12, py + 2, 1, 2),
          paint..color = FarmPalette.droplet);
    }
  }

  /// El nombre de cada construcción sobre su cartel (LAGO / HUERTA;
  /// town_editor.md § 4.3).
  void drawZoneLabels(Canvas c, TownState town, MapText text) {
    final (ox, oy) = town.origin;
    for (final b in town.builds) {
      final (sx, sy) = TownPlan.signOf(town, b);
      text(b.kind.label, (sx + ox + 0.5) * ts, (sy + oy) * ts - 4,
          TownPalette.label, 6);
    }
  }

  /// Los ayudantes (farming.md § 8, v0.25.5): granjeros caminando por
  /// su área y pescadores en su lugar de la orilla, con sus sprites
  /// (`items.vida_npc_*` del manifest; [sprite] los resuelve), el cofre
  /// de cada construcción con lo que tiene y, con el mouse encima de un
  /// ayudante ([hover]), el contorno de su área. [time]: reloj de la sala
  /// (igual en todos); [t]: ms de animación.
  void drawHelpers(Canvas c, TownState town, double time, double t,
      ui.Image? Function(String id) sprite, MapText text,
      {({TownBuild build, int index})? hover,
      NpcMark Function(BiomeNpcDef n)? markOf}) {
    final (ox, oy) = town.origin;
    final paint = SpriteCatalog.pixelPaint();
    void img(String id, double cx, double bottom) {
      final im = sprite(id);
      if (im == null) return;
      final w = im.width.toDouble(), h = im.height.toDouble();
      c.drawImageRect(im, Rect.fromLTWH(0, 0, w, h),
          Rect.fromLTWH((cx - w / 2).roundToDouble(), bottom - h, w, h), paint);
    }

    for (final b in town.builds) {
      if (b.kind == BuildKind.casa) {
        // Casa de habitante (town_editor.md § 3.4): sprite por nivel.
        final bb = b.bounds;
        img('casa_${b.level.clamp(1, 3)}', (bb.x + ox + bb.w / 2) * ts,
            (bb.bottom + oy) * ts);
        continue;
      }
      // Cofre al lado del cartel, con cuántas cosas tiene.
      final (cx, cy) = TownRules.chestOf(town, b);
      final px = (cx + ox + 0.5) * ts, py = (cy + oy + 1) * ts;
      img('cofre_oficio', px, py);
      if (b.chestTotal > 0) {
        text('${b.chestTotal}', px, py - ts - 2, TownPalette.label, 6);
      }
      for (var i = 0; i < b.helper; i++) {
        final pos = TownRules.helperPos(town, b, i, time);
        final farm = b.kind == BuildKind.huerta;
        final work = pos.work && (t ~/ 400) % 2 == 0;
        final id = farm
            ? (work ? 'npc_granjero_trabajo' : 'npc_granjero')
            : (work ? 'npc_pescador_trabajo' : 'npc_pescador');
        final bob = pos.work ? 0.0 : (math.sin(t / 120) * 1).roundToDouble();
        img(id, pos.x, pos.y + 6 + bob);
      }
    }
    // Habitantes (overworld_biomes.md § 10.1): caminan frente a su casa
    // de día; "!" si tienen pedido u orden.
    final night = SkyRules.isNight(town.sky);
    for (final n in kBiomeNpcs) {
      final r = town.resident(n.id);
      if (!r.invited) continue;
      final pos = ResidentRules.position(town, n.id, time, night: night);
      if (pos == null) continue;
      final bob = (math.sin(t / 140) * 1).roundToDouble();
      img(n.sprite, pos.$1, pos.$2 + 6 + bob);
      text(n.name, pos.$1, pos.$2 - 14, TownPalette.label, 6);
      // Marca por jugador (roles.md § 7.4): "!" algo nuevo, "?" listo
      // para entregar.
      drawNpcMark(text, markOf?.call(n) ?? NpcMark.none, pos.$1,
          pos.$2 - 22, t);
    }
    final h = hover;
    if (h == null) return;
    final b = town.build(h.build.id) ?? h.build;
    final line = Paint()
      ..color = FarmPalette.targetOk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final tiles = b.kind == BuildKind.huerta
        ? [
            for (final (x, y) in TownRules.helperArea(b, h.index))
              (x + b.anchor.$1, y + b.anchor.$2)
          ]
        : [TownRules.fisherSpot(town, b, h.index)];
    for (final (x, y) in tiles) {
      c.drawRect(
          Rect.fromLTWH((x + ox) * ts + 0.5, (y + oy) * ts + 0.5, ts - 1, ts - 1),
          line);
    }
  }

  /// Cosecha: el fruto salta del tile hacia quien cosechó.
  void addPop(String playerId, int tx, int ty, String label, Color color,
          Color fruit, double t) =>
      _pops.add(_Pop(playerId, tx, ty, label, color, fruit, t));

  void drawPops(Canvas c, double t, (double, double)? Function(String) posOf,
      MapText text) {
    _pops.removeWhere((p) => t - p.t0 > popMs + 900);
    for (final p in _pops) {
      final sx = (p.tx + 0.5) * ts, sy = (p.ty + 0.5) * ts;
      final to = posOf(p.playerId) ?? (sx, sy);
      final k = ((t - p.t0) / popMs).clamp(0.0, 1.0);
      final x = sx + (to.$1 - sx) * k;
      final y = sy + (to.$2 - 10 - sy) * k - math.sin(k * math.pi) * 20;
      if (k < 1) {
        c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 5, height: 5),
            Paint()..color = p.fruit);
        if (k < 0.25) {
          final r = 2 + k * 24;
          final paint = Paint()..color = FarmPalette.pop;
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3;
            c.drawRect(
                Rect.fromCenter(
                    center: Offset(sx + math.cos(a) * r, sy + math.sin(a) * r),
                    width: 2,
                    height: 2),
                paint);
          }
        }
      }
      text(p.label, to.$1, to.$2 - 34 - k * 4, p.color, 6);
    }
  }
}

/// Marca de habitante sobre la cabeza (roles.md § 7.4): "!" dorado si
/// tiene algo nuevo para contarte, "?" si tenés listo lo que pide; con un
/// rebote chico. [t]: ms de animación.
void drawNpcMark(MapText text, NpcMark mark, double x, double y, double t) {
  if (mark == NpcMark.none) return;
  final bob = (math.sin(t / 150) * 1.5).roundToDouble();
  text(mark == NpcMark.news ? '!' : '?', x, y + bob, TownPalette.request, 10);
}
