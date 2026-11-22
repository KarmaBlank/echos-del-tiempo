import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/town_layout.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/farming_rules.dart';
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
      _plot(c, e.value, px, py, t);
    }
  }

  void _plot(Canvas c, FarmPlot p, double px, double py, double t) {
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
    final rar = kCrops[seed]?.rarity.index ?? 0;
    final cx = px + ts / 2, by = py + ts - 3;
    switch (FarmingRules.stage(p)) {
      case CropStage.arada:
        break;
      case CropStage.semilla:
        c.drawRect(Rect.fromLTWH(cx - 1, by - 2, 2, 2),
            paint..color = FarmPalette.fert);
      case CropStage.brote:
        paint.color = FarmPalette.sprout;
        c.drawRect(Rect.fromLTWH(cx, by - 5, 1, 5), paint);
        c.drawRect(Rect.fromLTWH(cx - 2, by - 5, 2, 1), paint);
        c.drawRect(Rect.fromLTWH(cx + 1, by - 6, 2, 1), paint);
      case CropStage.crecido:
        paint.color = FarmPalette.stem;
        c.drawRect(Rect.fromLTWH(cx, by - 9, 1, 9), paint);
        paint.color = FarmPalette.leaf;
        c.drawRect(Rect.fromLTWH(cx - 4, by - 7, 4, 2), paint);
        c.drawRect(Rect.fromLTWH(cx + 1, by - 9, 4, 2), paint);
        paint.color = FarmPalette.leafDark;
        c.drawRect(Rect.fromLTWH(cx - 3, by - 4, 3, 2), paint);
      case CropStage.maduro:
        final glow = 0.5 + 0.5 * math.sin(t / 260);
        c.drawRect(
            Rect.fromLTWH(px - 1, py - 4, ts + 2, ts + 3),
            paint
              ..color = FarmPalette.ripeGlow
                  .withValues(alpha: FarmPalette.ripeGlow.a * glow));
        paint.color = FarmPalette.stem;
        c.drawRect(Rect.fromLTWH(cx, by - 11, 1, 11), paint);
        paint.color = FarmPalette.leaf;
        c.drawRect(Rect.fromLTWH(cx - 5, by - 7, 5, 2), paint);
        c.drawRect(Rect.fromLTWH(cx + 1, by - 9, 5, 2), paint);
        paint.color = FarmPalette.fruit[rar.clamp(0, 3)];
        c.drawRect(Rect.fromLTWH(cx - 3, by - 13, 3, 3), paint);
        c.drawRect(Rect.fromLTWH(cx + 2, by - 11, 3, 3), paint);
    }
    if (p.watered && !FarmingRules.ripe(p)) {
      c.drawRect(Rect.fromLTWH(px + 12, py + 2, 1, 2),
          paint..color = FarmPalette.droplet);
    }
  }

  /// Nombres de las zonas del pueblo (arriba de cada una, sobre pasto:
  /// nunca tapan cultivos ni la pesca).
  void drawZoneLabels(Canvas c, TownState town, MapText text) {
    const bf = TownLayout.baseFarm;
    text('HUERTA', (bf.x + bf.w / 2) * ts, bf.y * ts - 6, TownPalette.label, 6);
    final slots = town.expansions * 2;
    for (var i = 0; i < slots; i++) {
      final r = TownLayout.slotRect(i);
      final kind = i < town.zones.length ? town.zones[i] : null;
      final label = switch (kind) {
        TownZoneKind.lago => 'LAGO',
        TownZoneKind.huerta => 'HUERTA',
        null => 'TERRENO LIBRE',
      };
      text(label, (r.x + r.w / 2) * ts, r.y * ts - 6, TownPalette.label, 6);
    }
  }

  /// El ayudante de la huerta (si está contratado), al costado de la
  /// huerta del pueblo.
  void drawHelper(Canvas c, TownState town, double t) {
    if (town.helper <= 0) return;
    const bf = TownLayout.baseFarm;
    final x = (bf.x + bf.w) * ts + 6, y = (bf.y + 1) * ts + 6;
    final bob = math.sin(t / 300) * 1;
    final p = Paint()..color = FarmPalette.helper;
    c.drawRect(Rect.fromLTWH(x - 3, y - 6 + bob, 6, 8), p);
    c.drawRect(Rect.fromLTWH(x - 2, y - 11 + bob, 4, 4), p);
    c.drawRect(Rect.fromLTWH(x - 4, y - 12 + bob, 8, 2),
        p..color = FarmPalette.helperHat);
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
