import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/data/light_catalog.dart';
import '../../../../game_engine/rules/light_rules.dart';
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

  /// Luces puestas del cuadro (centros en tiles): las luciérnagas se
  /// apagan de a poco cerca de ellas (lighting.md § 3.4). La carga el
  /// mapa antes de pedir las luciérnagas.
  List<(double, double)> placedLights = const [];

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
        var blink = 0.5 + 0.5 * math.sin(t / 520 + ph * 3);
        if (placedLights.isNotEmpty) {
          blink *= LightRules.fireflyFade(x / ts, y / ts, placedLights,
              radius: kLightDefs[LightId.faro]!.radius,
              survivor: (h >> 20) % LightRules.fireflySurvivorEvery == 0);
          if (blink <= 0.01) continue;
        }
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
      bool motion = true,
      bool tint = true,
      Weather? weather,
      bool precipitation = true}) {
    final dark = SkyRules.darkness(sky);
    // [weather]: the weather of the place on screen (weather_seasons.md
    // § 2); by default, the town's.
    final w = weather ?? SkyRules.now(sky);
    final overcast = overcastOf(w);
    final alpha = math.max(dark * 0.72, overcast);
    final flies = dark > 0.3 ? fireflies(view, t, density) : const <(Offset, double)>[];
    // Sin [tint]: la noche la pone la capa de luz (lighting.md § 4).
    if (tint && alpha > 0.01) {
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
    if (tint && dark > 0.05) {
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
    // No rain or snow particles on hot ground (weather_seasons.md § 2.3).
    if (precipitation && w.wet) {
      _rain(c, view, t, w == Weather.tormenta, density, motion);
    }
    if (precipitation && w == Weather.snow) _snow(c, view, t, density, motion);
    if (w == Weather.fog) _fog(c, view, t, motion);
    _bolts(c, view, t, flash);
  }

  /// How much the weather darkens the day (0–1 of the overcast tint):
  /// storm darkest, then rain, fog and snow.
  static double overcastOf(Weather w) => switch (w) {
        Weather.tormenta => 0.32,
        Weather.lluvia => 0.18,
        Weather.fog => 0.12,
        Weather.snow => 0.1,
        Weather.despejado => 0.0,
      };

  /// Max snowflakes per frame (the point buffer is allocated once).
  static const maxFlakes = 140;
  final _flakes = Float32List(maxFlakes * 2);
  static final _snowPaint = Paint()
    ..isAntiAlias = false
    ..color = SkyPalette.snow
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.square;
  static final _fogPaint = Paint()..isAntiAlias = false;

  /// Writes up to [n] snowflakes inside [view] (px of the world) into
  /// [out] as x, y pairs and returns how many. Pure: same [t], same
  /// flakes; every flake is inside the visible area.
  static int snowFlakes(Rect view, double t, int n, Float32List out,
      {bool motion = true}) {
    final k = math.min(n, out.length ~/ 2);
    if (k <= 0 || view.width <= 0 || view.height <= 0) return 0;
    final speed = motion ? 0.05 : 0.02;
    final wv = view.width, hv = view.height;
    for (var i = 0; i < k; i++) {
      final h = _hash(i, 11);
      final ph = (h >> 6) % 628 / 100;
      final sway = motion ? math.sin(t / 900 + ph) * 6 : 0.0;
      out[i * 2] = view.left + ((h % 1000) / 1000 * wv + sway + wv) % wv;
      out[i * 2 + 1] =
          view.top + ((h >> 10) % 1000 / 1000 * hv + t * speed) % hv;
    }
    return k;
  }

  void _snow(Canvas c, Rect view, double t, double density, bool motion) {
    final n = snowFlakes(view, t, scaledCount(110, density), _flakes,
        motion: motion);
    if (n <= 0) return;
    c.drawRawPoints(ui.PointMode.points,
        _flakeView(n), _snowPaint);
  }

  // The view over the first n flakes, rebuilt only when n changes (the
  // density setting), so a steady frame allocates nothing.
  Float32List? _view;
  int _viewN = -1;
  Float32List _flakeView(int n) {
    if (n != _viewN || _view == null) {
      _viewN = n;
      _view = Float32List.sublistView(_flakes, 0, n * 2);
    }
    return _view!;
  }

  /// Pixelated fog (weather_seasons.md § 6): a faint veil plus two
  /// layers of soft noise patches drawn as world-anchored 8 px cells,
  /// each layer at its own scale and drift, so it reads as drifting
  /// mist rather than solid bands. Only visible cells are drawn.
  void _fog(Canvas c, Rect view, double t, bool motion) {
    _fogPaint.color = SkyPalette.fog.withValues(alpha: 0.08);
    c.drawRect(view, _fogPaint);
    const cell = 8.0;
    final x0 = (view.left / cell).floor(), x1 = (view.right / cell).ceil();
    final y0 = (view.top / cell).floor(), y1 = (view.bottom / cell).ceil();
    // Perf (v0.48.3): the cell grid is rebuilt only when the visible cells
    // change or every [fogRefreshMs] (the drift is a few px/s), and drawn
    // as one point batch per alpha step instead of one rect per cell.
    final stale = x0 != _fogX0 ||
        y0 != _fogY0 ||
        x1 != _fogX1 ||
        y1 != _fogY1 ||
        (motion && (t - _fogT).abs() >= fogRefreshMs);
    if (stale) {
      _fogX0 = x0;
      _fogY0 = y0;
      _fogX1 = x1;
      _fogY1 = y1;
      _fogT = t;
      for (final b in _fogBuckets) {
        b.clear();
      }
      for (var layer = 0; layer < 2; layer++) {
        final scale = layer == 0 ? 7.0 : 4.0;
        final dx = motion ? t / (layer == 0 ? 260 : 170) : 0.0;
        final dy = motion ? t / (layer == 0 ? 900 : 640) : 0.0;
        for (var cy = y0; cy < y1; cy++) {
          for (var cx = x0; cx < x1; cx++) {
            final n = _noise((cx + dx / cell) / scale,
                (cy + dy / cell) / scale, 31 + layer);
            final k = ((n - 0.45) / 0.55).clamp(0.0, 1.0);
            // Quantised alpha keeps the pixel look (no smooth gradient).
            final step = (k * 3).round();
            if (step <= 0) continue;
            _fogBuckets[layer * 3 + step - 1]
              ..add(cx * cell + cell / 2)
              ..add(cy * cell + cell / 2);
          }
        }
      }
      for (var i = 0; i < 6; i++) {
        _fogPts[i] = Float32List.fromList(_fogBuckets[i]);
      }
    }
    _fogPtPaint.strokeWidth = cell;
    for (var i = 0; i < 6; i++) {
      final pts = _fogPts[i];
      if (pts == null || pts.isEmpty) continue;
      final maxA = i < 3 ? 0.16 : 0.10;
      _fogPtPaint.color =
          SkyPalette.fog.withValues(alpha: (i % 3 + 1) / 3 * maxA);
      c.drawRawPoints(ui.PointMode.points, pts, _fogPtPaint);
    }
  }

  /// How often the fog grid is resampled while drifting (ms).
  static const fogRefreshMs = 200.0;
  int _fogX0 = 0, _fogY0 = 0, _fogX1 = -1, _fogY1 = -1;
  double _fogT = -1e9;
  final _fogBuckets = List.generate(6, (_) => <double>[]);
  final _fogPts = List<Float32List?>.filled(6, null);
  static final _fogPtPaint = Paint()
    ..isAntiAlias = false
    ..strokeCap = StrokeCap.square;

  // Smooth value noise in 0–1 from the integer lattice hash.
  static double _noise(double x, double y, int seed) {
    final xi = x.floor(), yi = y.floor();
    final fx = x - xi, fy = y - yi;
    double v(int a, int b) => _hash(a * 7919 + b * 104729, seed) % 1000 / 1000;
    final sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    final top = v(xi, yi) + (v(xi + 1, yi) - v(xi, yi)) * sx;
    final bot = v(xi, yi + 1) + (v(xi + 1, yi + 1) - v(xi, yi + 1)) * sx;
    return top + (bot - top) * sy;
  }

  /// Cuánto ilumina ahora el último rayo (0–1, lighting.md § 5.2).
  double boltLight(double t) {
    var k = 0.0;
    for (final b in bolts) {
      final q = (t - b.t0) / boltMs;
      if (q >= 0 && q < 1) k = math.max(k, 1 - q);
    }
    return k;
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
