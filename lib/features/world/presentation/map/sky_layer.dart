import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/rules/sky_rules.dart';
import 'map_themes.dart';

/// Un rayo que cayó (px del mundo) y cuándo (ms del reloj del mapa).
class SkyBolt {
  SkyBolt(this.x, this.y, this.t0);
  final double x, y, t0;
}

/// La noche, la lluvia y la tormenta sobre el mapa al aire libre
/// (day_night_weather.md § 4). Todo sale del cielo del mundo
/// ([SkyState]) y del reloj de dibujo: igual en todos los clientes salvo
/// las partículas, que son solo decorado.
class MapSkyLayer {
  static const ts = 16.0;

  /// Duración del rayo dibujado y del destello (ms).
  static const boltMs = 420.0;

  final bolts = <SkyBolt>[];

  void addBolt(int tx, int ty, double t) {
    bolts.add(SkyBolt((tx + 0.5) * ts, (ty + 0.5) * ts, t));
    if (bolts.length > 6) bolts.removeAt(0);
  }

  static int _hash(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  /// Luciérnagas visibles en [view] (px del mundo): una cada tanto por
  /// celda de 5×5 tiles, flotando cerca de su lugar.
  List<(Offset, double)> fireflies(Rect view, double t, double density) {
    const cell = 5 * ts;
    final out = <(Offset, double)>[];
    final keep = (density.clamp(0.0, 1.0) * 3).round();
    if (keep <= 0) return out;
    for (var cy = (view.top / cell).floor(); cy * cell < view.bottom; cy++) {
      for (var cx = (view.left / cell).floor(); cx * cell < view.right; cx++) {
        final h = _hash(cx, cy);
        if (h % 3 >= keep) continue;
        final ph = (h >> 4) % 1000 / 1000 * math.pi * 2;
        final bx = cx * cell + (h >> 8) % cell;
        final by = cy * cell + (h >> 14) % cell;
        final x = bx + math.sin(t / 2300 + ph) * 10;
        final y = by + math.cos(t / 1900 + ph * 1.3) * 6;
        final blink = 0.5 + 0.5 * math.sin(t / 520 + ph * 3);
        out.add((Offset(x, y), blink));
      }
    }
    return out;
  }

  /// Dibuja la noche con sus luces, las luciérnagas, la lluvia y los
  /// rayos sobre [view] (px del mundo). [lights]: centros de faros y
  /// braseros encendidos. [flash]: factor de destellos de los ajustes
  /// (0 = sin destellos); [motion]: `false` con «reducir movimiento».
  void draw(Canvas c, SkyState sky, Rect view, double t,
      {required List<Offset> lights,
      double density = 1,
      double flash = 1,
      bool motion = true}) {
    final dark = SkyRules.darkness(sky);
    final w = SkyRules.now(sky);
    final overcast = switch (w) {
      Weather.tormenta => 0.32,
      Weather.lluvia => 0.18,
      Weather.despejado => 0.0,
    };
    final alpha = math.max(dark * 0.72, overcast);
    final flies = dark > 0.3 ? fireflies(view, t, density) : const <(Offset, double)>[];
    if (alpha > 0.01) {
      c.saveLayer(view, Paint());
      c.drawRect(
          view,
          Paint()
            ..color = (dark * 0.72 >= overcast ? SkyPalette.night : SkyPalette.overcast)
                .withValues(alpha: alpha));
      // Las luces "comen" la noche (solo de noche).
      if (dark > 0.05) {
        final cut = Paint()..blendMode = BlendMode.dstOut;
        void hole(Offset o, double r, double k) {
          cut.shader = ui.Gradient.radial(o, r, [
            SkyPalette.cut.withValues(alpha: k),
            SkyPalette.cutClear,
          ]);
          c.drawCircle(o, r, cut);
        }

        final flick = motion ? 0.04 * math.sin(t / 130) : 0.0;
        for (final l in lights) {
          hole(l, 46 * (1 + flick), 0.9 * dark);
        }
        for (final (o, b) in flies) {
          hole(o, 9, 0.5 * b * dark);
        }
      }
      c.restore();
    }
    if (dark > 0.05) {
      // Halo cálido de los faros.
      final glow = Paint();
      for (final l in lights) {
        glow.shader = ui.Gradient.radial(l, 30, [
          SkyPalette.warm.withValues(alpha: 0.22 * dark),
          SkyPalette.warmEdge,
        ]);
        c.drawCircle(l, 30, glow);
      }
    }
    if (flies.isNotEmpty) {
      final dot = Paint()..isAntiAlias = false;
      for (final (o, b) in flies) {
        final k = b * ((dark - 0.3) / 0.7).clamp(0.0, 1.0);
        dot.color = SkyPalette.fireflyGlow.withValues(alpha: 0.4 * k);
        c.drawRect(Rect.fromLTWH(o.dx.roundToDouble() - 1, o.dy.roundToDouble() - 1, 3, 3), dot);
        dot.color = SkyPalette.firefly.withValues(alpha: k);
        c.drawRect(Rect.fromLTWH(o.dx.roundToDouble(), o.dy.roundToDouble(), 1, 1), dot);
      }
    }
    if (w.wet) _rain(c, view, t, w == Weather.tormenta, density, motion);
    _bolts(c, view, t, flash);
  }

  void _rain(Canvas c, Rect view, double t, bool storm, double density,
      bool motion) {
    final n = scaledCount(storm ? 150 : 90, density);
    if (n <= 0) return;
    final p = Paint()
      ..isAntiAlias = false
      ..color = SkyPalette.rain
      ..strokeWidth = 1;
    final speed = (storm ? 0.42 : 0.3) * (motion ? 1 : 0.4);
    final slant = storm ? 3.0 : 1.5;
    final wv = view.width + 40, hv = view.height + 20;
    for (var i = 0; i < n; i++) {
      final h = _hash(i, 7);
      final x =
          view.left + ((h % 1000) / 1000 * wv + t * speed * 0.08) % wv - 20;
      final y =
          view.top + ((h >> 10) % 1000 / 1000 * hv + t * speed) % hv - 10;
      c.drawLine(Offset(x, y), Offset(x - slant, y + 5), p);
    }
  }

  void _bolts(Canvas c, Rect view, double t, double flash) {
    bolts.removeWhere((b) => t - b.t0 > boltMs || t < b.t0);
    if (bolts.isEmpty) return;
    final line = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke;
    for (final b in bolts) {
      final q = (t - b.t0) / boltMs;
      // Destello de pantalla (respeta los ajustes de destellos).
      if (flash > 0) {
        c.drawRect(
            view,
            Paint()
              ..color = SkyPalette.flash
                  .withValues(alpha: (0.45 * (1 - q) * flash).clamp(0.0, 1.0)));
      }
      final path = Path()..moveTo(b.x + 6, view.top);
      var y = view.top;
      var i = 0;
      while (y < b.y) {
        y = math.min(b.y, y + 10);
        final dx = (_hash(b.t0.round(), i++) % 9) - 4.0;
        path.lineTo(b.x + (y >= b.y ? 0 : dx), y);
      }
      final a = (1 - q).clamp(0.0, 1.0);
      c.drawPath(path, line..strokeWidth = 3..color = SkyPalette.boltGlow.withValues(alpha: a * 0.6));
      c.drawPath(path, line..strokeWidth = 1..color = SkyPalette.bolt.withValues(alpha: a));
    }
  }
}
