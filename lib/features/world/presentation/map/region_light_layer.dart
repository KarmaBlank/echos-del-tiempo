import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/rules/biome_regions.dart';
import '../../../../game_engine/rules/light_shaft_rules.dart';
import '../../../../game_engine/rules/region_ambience_rules.dart';
import 'map_themes.dart';
import 'sky_layer.dart';
import 'tile_painter.dart';

/// Cloud shadows, cave shade and light shafts (docs/specs/biome_regions.md
/// § 7). Built for the frame budget: only what is inside the view is
/// drawn, the static cave shade is a cached picture per layout, and the
/// per-frame path reuses its paints, shapes and lists (no allocation per
/// cloud or shaft).
class RegionLightLayer {
  static const ts = 16.0;

  /// Alpha steps for the paints (the cover is quantized to these).
  static const _steps = 8;

  final _visible = <(int, int)>[];
  final List<Paint> _beam = [
    for (var i = 0; i <= _steps; i++)
      Paint()
        ..color =
            RegionPalette.shaftBeam.withValues(alpha: 0.16 * i / _steps)
  ];
  final List<Paint> _patch = [
    for (var i = 0; i <= _steps; i++)
      Paint()
        ..color =
            RegionPalette.shaftPatch.withValues(alpha: 0.28 * i / _steps)
  ];
  final List<Paint> _shadeAlpha = [
    for (var i = 0; i <= _steps; i++)
      Paint()..color = Color.fromRGBO(0, 0, 0, i / _steps)
  ];
  final Paint _mote = Paint()
    ..color = RegionPalette.shaftPatch.withValues(alpha: 0.8);
  final Paint _dapple = Paint()
    ..color = RegionPalette.shaftPatch.withValues(alpha: 0.18);

  /// The beam: a slanted band from above the tile down to the floor.
  final Path _beamPath = Path()
    ..moveTo(-6, -64)
    ..lineTo(10, -64)
    ..lineTo(16, 6)
    ..lineTo(-12, 6)
    ..close();
  static const _patchRect = Rect.fromLTWH(-15, -5, 30, 12);
  static const _patchCore = Rect.fromLTWH(-9, -2, 18, 6);
  static const _moteRect = Rect.fromLTWH(0, 0, 1, 1);
  static const _fleck = Rect.fromLTWH(0, 0, 2, 1);

  ui.Picture? _shade;
  Object? _shadeKey;
  ui.Picture? _roof;
  Object? _roofKey;

  /// Light pools: one paint per alpha step (no allocation per frame).
  final List<Paint> _pool = [
    for (var i = 0; i <= _steps * 4; i++)
      Paint()
        ..color = RegionPalette.shaftPatch
            .withValues(alpha: i / (_steps * 4))
        ..isAntiAlias = false
  ];

  /// Times the roof-edge picture was built (perf test).
  int roofBuilds = 0;

  /// Times the cave-shade picture was built (perf test).
  int shadeBuilds = 0;

  /// Shafts drawn last frame (perf test / debug line).
  int lastShafts = 0;

  int _q(double v) => (v.clamp(0.0, 1.0) * _steps).round();

  /// Soft cloud shadows drifting over an outdoor map by day.
  /// [cover] from `LightShaftRules.cloudCover`; [t] in seconds.
  void drawClouds(Canvas c, Rect view, double t, double cover,
      double fieldW, double fieldH) {
    final n = LightShaftRules.cloudCount(cover);
    if (n == 0) return;
    final k = _q(cover);
    if (k == 0) return;
    // Pixelated, irregular shadows (v0.48.4, owner): each cloud is a
    // grid of 8 px cells whose edge is broken by value noise that moves
    // with the cloud, faded in [_cloudLevels] alpha steps toward the rim.
    // Cells are batched as square points, one draw per step.
    const cell = 8.0;
    for (final b in _cloudPts) {
      b.clear();
    }
    for (var i = 0; i < n; i++) {
      final (x, y, rx, ry) = LightShaftRules.cloud(i, t, fieldW, fieldH);
      final ex = rx * 1.25, ey = ry * 1.25;
      if (x + ex < view.left ||
          x - ex > view.right ||
          y + ey < view.top ||
          y - ey > view.bottom) {
        continue;
      }
      // Snap the cloud to the cell grid so it slides a pixel step at a time.
      final ox = (x / cell).round() * cell, oy = (y / cell).round() * cell;
      final cw = (ex / cell).ceil(), ch = (ey / cell).ceil();
      for (var cy = -ch; cy <= ch; cy++) {
        final wy = oy + cy * cell;
        if (wy + cell < view.top || wy > view.bottom) continue;
        for (var cx = -cw; cx <= cw; cx++) {
          final wx = ox + cx * cell;
          if (wx + cell < view.left || wx > view.right) continue;
          final dx = cx * cell / rx, dy = cy * cell / ry;
          final d = math.sqrt(dx * dx + dy * dy);
          // Low-frequency noise only bends the outline (lobes), the body stays
          // one flat shade: a shadow, not smoke.
          final nz = MapSkyLayer.noise(cx / 5.0, cy / 5.0, 57 + i) - 0.5;
          final v = (1.0 - d + nz * 0.45) / 0.22;
          if (v <= 0) continue;
          final step = (v.clamp(0.0, 1.0) * _cloudLevels).ceil();
          if (step <= 0) continue;
          _cloudPts[step - 1]
            ..add(wx + cell / 2)
            ..add(wy + cell / 2);
        }
      }
    }
    for (var s = 0; s < _cloudLevels; s++) {
      final pts = _cloudPts[s];
      if (pts.isEmpty) continue;
      _cloudPx
        ..strokeWidth = cell
        ..color = RegionPalette.cloudShadow
            .withValues(alpha: 0.18 * (k / _steps) * (s + 1) / _cloudLevels);
      c.drawRawPoints(ui.PointMode.points, Float32List.fromList(pts), _cloudPx);
    }
  }

  static const _cloudLevels = 3;
  final _cloudPts = List.generate(_cloudLevels, (_) => <double>[]);
  final _cloudPx = Paint()
    ..isAntiAlias = false
    ..strokeCap = StrokeCap.square;

  /// Darkness under cave roofs of a region ([lay]) with a vignette
  /// toward the walls (biome_regions.md § 7.2.1): a cached picture of the
  /// whole layout in 8 px cells (each the mean of its tile and the roofed
  /// neighbours it leans to), clipped by the canvas to the view.
  void drawCaveShade(Canvas c, BiomeLayout lay, double strength) {
    if (strength <= 0) return;
    if (_shade == null || !identical(_shadeKey, lay)) {
      _shade?.dispose();
      final rec = ui.PictureRecorder();
      final pc = Canvas(rec);
      final paint = Paint()..isAntiAlias = false;
      double dark(int x, int y) =>
          lay.isIndoor(x, y) ? RegionAmbienceRules.caveDarkness(lay, x, y) : -1;
      for (var y = 0; y < BiomeLayout.height; y++) {
        for (var x = 0; x < BiomeLayout.width; x++) {
          final d0 = dark(x, y);
          if (d0 < 0) continue;
          for (var sy = 0; sy < 2; sy++) {
            for (var sx = 0; sx < 2; sx++) {
              final nx = x + (sx == 0 ? -1 : 1), ny = y + (sy == 0 ? -1 : 1);
              var sum = d0, n = 1;
              for (final v in [dark(nx, y), dark(x, ny), dark(nx, ny)]) {
                if (v >= 0) {
                  sum += v;
                  n++;
                }
              }
              final k = (sum / n * _steps * 2).round() / (_steps * 2);
              paint.color = RegionPalette.caveShade.withValues(alpha: k);
              pc.drawRect(
                  Rect.fromLTWH(x * ts + sx * 8, y * ts + sy * 8, 8, 8),
                  paint);
            }
          }
        }
      }
      _shade = rec.endRecording();
      _shadeKey = lay;
      shadeBuilds++;
    }
    final k = _q(strength);
    if (k == 0) return;
    c.saveLayer(null, _shadeAlpha[k]);
    c.drawPicture(_shade!);
    c.restore();
  }

  ui.Picture? _glow;
  Object? _glowKey;
  final _water = <(int, int)>[];
  final Paint _mist = Paint()..isAntiAlias = false;
  final Paint _ring = Paint()..isAntiAlias = false;

  /// Above the darkness (§ 7.2.1): the faint cold glow of the cave water
  /// and the glowing specks (cached picture), slow low mist over each
  /// cave lake and an occasional drip ripple (a handful of rects).
  void drawCaveLife(Canvas c, BiomeLayout lay, double t,
      {double strength = 1, bool motion = true}) {
    if (strength <= 0) return;
    final pal = CavePalette.of(lay.base.theme);
    if (_glow == null || !identical(_glowKey, lay)) {
      _glow?.dispose();
      _water.clear();
      final rec = ui.PictureRecorder();
      final pc = Canvas(rec);
      final glowA = RegionAmbienceRules.waterGlow;
      Paint p(Color col, double a) => Paint()
        ..color = col.withValues(alpha: a.clamp(0.0, 1.0))
        ..isAntiAlias = false;
      final water = p(pal.waterGlow, glowA);
      final shine = p(pal.waterGlow, glowA * 1.8);
      final halo = p(pal.speck, 0.2);
      final core = p(pal.speck, 1);
      for (var y = 0; y < BiomeLayout.height; y++) {
        for (var x = 0; x < BiomeLayout.width; x++) {
          if (!lay.isIndoor(x, y)) continue;
          final h = TilePainter.tileHash(x, y);
          if (lay.isLake(x, y)) {
            _water.add((x, y));
            pc.drawRect(Rect.fromLTWH(x * ts, y * ts, ts, ts), water);
            if (h % 3 == 0) {
              pc.drawRect(
                  Rect.fromLTWH(
                      x * ts + 2 + h % 8, y * ts + 4 + (h >> 4) % 8, 4, 1),
                  shine);
            }
            continue;
          }
          if (!RegionAmbienceRules.speckAt(x, y)) continue;
          // The mushroom the tile painter draws on this tile.
          final mx = x * ts + 5 + (h >> 7) % 6, my = y * ts + 6 + (h >> 9) % 6;
          pc
            ..drawRect(Rect.fromLTWH(mx - 1, my, 5, 1), halo)
            ..drawRect(Rect.fromLTWH(mx + 1, my - 2, 1, 5), halo)
            ..drawRect(Rect.fromLTWH(mx, my - 1, 3, 3), halo)
            ..drawRect(Rect.fromLTWH(mx + 1, my, 1, 1), core);
        }
      }
      _glow = rec.endRecording();
      _glowKey = lay;
    }
    c.drawPicture(_glow!);
    if (!motion) return;
    final bands = RegionAmbienceRules.mistBands;
    var salt = 0;
    for (final lk in lay.lakes) {
      if (lk.cave == null) continue;
      salt++;
      // Mist (§ 7.2.1): the weather fog's style — world-anchored 8 px
      // cells of soft value noise with quantized alpha, drifting slowly,
      // kept low over the lake and fading out toward its shore.
      final (ex, ey, erx, ery) = lk.ellipse;
      const cell = 8.0;
      final speed = RegionAmbienceRules.mistSpeed;
      final x0 = ((ex - erx - 1) * ts / cell).floor(),
          x1 = ((ex + erx + 1) * ts / cell).ceil();
      final y0 = ((ey - ery - 1) * ts / cell).floor(),
          y1 = ((ey + ery + 1) * ts / cell).ceil();
      for (var layer = 0; layer < bands; layer++) {
        final scale = 5.0 - layer * 1.5;
        final dx = t * speed * (1 + layer * 0.6);
        final dy = t * speed * 0.2;
        final maxA = (0.14 - layer * 0.04) * strength;
        if (maxA <= 0) continue;
        for (var cy = y0; cy < y1; cy++) {
          for (var cx = x0; cx < x1; cx++) {
            final wx = (cx + 0.5) * cell / ts, wy = (cy + 0.5) * cell / ts;
            final nx = (wx - ex) / (erx + 1), ny = (wy - ey) / (ery + 0.8);
            final r2 = nx * nx + ny * ny;
            if (r2 > 1) continue;
            final n = MapSkyLayer.noise((cx + dx / cell) / scale,
                (cy + dy / cell) / scale, 57 + layer + salt * 5);
            final k = ((n - 0.4) / 0.6).clamp(0.0, 1.0) * (1 - r2);
            final a = (k * 3).round() / 3 * maxA;
            if (a <= 0) continue;
            _mist.color = pal.mist.withValues(alpha: a);
            c.drawRect(Rect.fromLTWH(cx * cell, cy * cell, cell, cell), _mist);
          }
        }
      }
      // Drip ripple: a widening pixel ring on one water tile.
      final rp = RegionAmbienceRules.ripple(_water, salt, t);
      if (rp != null) {
        final ((wx, wy), age) = rp;
        final r = (1 + age * 6).roundToDouble();
        final rh = (r * 0.5).roundToDouble();
        _ring.color =
            pal.waterGlow.withValues(alpha: 0.4 * (1 - age) * strength);
        final cx = wx * ts + 8, cy = wy * ts + 8;
        c
          ..drawRect(Rect.fromLTWH(cx - r, cy - rh, r * 2, 1), _ring)
          ..drawRect(Rect.fromLTWH(cx - r, cy + rh, r * 2, 1), _ring)
          ..drawRect(Rect.fromLTWH(cx - r - 1, cy - rh, 1, rh * 2), _ring)
          ..drawRect(Rect.fromLTWH(cx + r, cy - rh, 1, rh * 2), _ring);
      }
    }
  }

  /// Roof edge / overhang at the mouths of the roofed caves of [lay]
  /// (biome_regions.md § 7.2.1); drawn above the actors. Cached picture.
  void drawRoofEdges(Canvas c, BiomeLayout lay, String Function(int, int) at) {
    final lip = RegionAmbienceRules.roofLip;
    if (lip <= 0) return;
    if (_roof == null || !identical(_roofKey, lay)) {
      _roof?.dispose();
      final rec = ui.PictureRecorder();
      final pc = Canvas(rec);
      final pal = CavePalette.of(lay.base.theme);
      Paint p(Color col) => Paint()
        ..color = col
        ..isAntiAlias = false;
      final body = p(pal.rock), mid = p(pal.rockMid);
      final deep = p(pal.rockDeep), lit = p(pal.rockLit);
      // Seen from outside: a lit brow juts past the mouth and casts a
      // soft shadow on the ground in front of it.
      final shadow = Paint()
        ..color = RegionPalette.caveShade.withValues(alpha: 0.35)
        ..isAntiAlias = false;
      for (var y = 0; y < BiomeLayout.height; y++) {
        for (var x = 0; x < BiomeLayout.width; x++) {
          for (final side in RegionAmbienceRules.roofEdges(lay, at, x, y)) {
            final px = x * ts, py = y * ts;
            final h = LightShaftRules.hash(x, y);
            // A jagged band of rock along the open side, lit on its outer
            // edge, with stalactites hanging inward (4 px columns).
            for (var k = 0; k < 4; k++) {
              final hk = h >> (k * 4);
              final d = lip - 2 + hk % 4;
              final o = k * 4.0;
              final len = 2.0 + (hk >> 2) % 6, wd = 1.0 + (hk >> 1) % 2;
              final brow = 2.0 + hk % 2;
              final Rect band, edge, tip, point, out, shade;
              switch (side) {
                case RoofSide.north:
                  band = Rect.fromLTWH(px + o, py, 4, d);
                  edge = Rect.fromLTWH(px + o, py, 4, 1);
                  tip = Rect.fromLTWH(px + o + 1, py + d, wd, len);
                  point = Rect.fromLTWH(px + o + 1, py + d + len, 1, 1);
                  out = Rect.fromLTWH(px + o, py - brow, 4, brow);
                  shade = Rect.fromLTWH(px + o, py - brow - 3, 4, 3);
                case RoofSide.south:
                  band = Rect.fromLTWH(px + o, py + ts - d, 4, d);
                  edge = Rect.fromLTWH(px + o, py + ts - 1, 4, 1);
                  tip = Rect.fromLTWH(px + o + 1, py + ts - d - len, wd, len);
                  point =
                      Rect.fromLTWH(px + o + 1, py + ts - d - len - 1, 1, 1);
                  out = Rect.fromLTWH(px + o, py + ts, 4, brow);
                  shade = Rect.fromLTWH(px + o, py + ts + brow, 4, 3);
                case RoofSide.west:
                  band = Rect.fromLTWH(px, py + o, d, 4);
                  edge = Rect.fromLTWH(px, py + o, 1, 4);
                  tip = Rect.fromLTWH(px + d, py + o + 1, len, wd);
                  point = Rect.fromLTWH(px + d + len, py + o + 1, 1, 1);
                  out = Rect.fromLTWH(px - brow, py + o, brow, 4);
                  shade = Rect.fromLTWH(px - brow - 3, py + o, 3, 4);
                case RoofSide.east:
                  band = Rect.fromLTWH(px + ts - d, py + o, d, 4);
                  edge = Rect.fromLTWH(px + ts - 1, py + o, 1, 4);
                  tip = Rect.fromLTWH(px + ts - d - len, py + o + 1, len, wd);
                  point =
                      Rect.fromLTWH(px + ts - d - len - 1, py + o + 1, 1, 1);
                  out = Rect.fromLTWH(px + ts, py + o, brow, 4);
                  shade = Rect.fromLTWH(px + ts + brow, py + o, 3, 4);
              }
              pc
                ..drawRect(shade, shadow)
                ..drawRect(band, k.isEven ? body : mid)
                ..drawRect(out, k.isEven ? mid : body)
                ..drawRect(edge, lit);
              if (hk % 3 != 0) {
                pc
                  ..drawRect(tip, deep)
                  ..drawRect(point, deep);
              }
            }
          }
        }
      }
      _roof = rec.endRecording();
      _roofKey = lay;
      roofBuilds++;
    }
    c.drawPicture(_roof!);
  }

  /// Soft, dim, pixelated light pools under the openings of a biome
  /// region's roofed caves, with a few drifting dust motes (§ 7.2.1).
  /// No beam: the light only touches the floor.
  void drawPools(Canvas c, GameMap map, Rect view, double t,
      {double strength = 1, bool motion = true}) {
    lastShafts = 0;
    if (strength <= 0) return;
    final x0 = (view.left / ts).floor() - 2, y0 = (view.top / ts).floor() - 2;
    final x1 = (view.right / ts).ceil() + 2,
        y1 = (view.bottom / ts).ceil() + 2;
    LightShaftRules.visible(map, x0, y0, x1, y1, _visible);
    if (_visible.isEmpty) return;
    final size = RegionAmbienceRules.poolSize;
    final step = RegionAmbienceRules.poolPixel;
    final n = RegionAmbienceRules.moteCount;
    final top = _pool.length - 1;
    for (final (tx, ty) in _visible) {
      final px = ((tx + 0.5) * ts).floorToDouble(),
          py = ((ty + 0.5) * ts).floorToDouble();
      final h = LightShaftRules.hash(tx, ty);
      final a = RegionAmbienceRules.poolAlpha(h, t, motion: motion) *
          strength;
      // Three stacked, pixel-snapped ellipse rings: brighter to the core.
      for (var ring = 0; ring < 3; ring++) {
        final f = 1.0 - ring * 0.3;
        final paint = _pool[(a * (0.45 + ring * 0.3) * top)
            .round()
            .clamp(0, top)];
        final rw = (size * f / step).round() * step;
        final rh = (size * 0.5 * f / step).round() * step;
        if (rw <= 0 || rh <= 0) continue;
        // Pixelated ellipse: rows of rects of shrinking width.
        for (var yy = -rh; yy < rh; yy += step) {
          final k = 1 - ((yy + step / 2) / rh) * ((yy + step / 2) / rh);
          if (k <= 0) continue;
          final w = (rw * math.sqrt(k) / step).round() * step;
          if (w <= 0) continue;
          c.drawRect(Rect.fromLTWH(px - w, py + yy, w * 2, step), paint);
        }
      }
      if (motion) {
        for (var k = 0; k < n; k++) {
          final (mx, my, ma) = RegionAmbienceRules.mote(h, k, t);
          final p = _pool[(ma * a * 2.2 * top).round().clamp(0, top)];
          c.drawRect(
              Rect.fromLTWH((px + mx).roundToDouble(),
                  (py + my).roundToDouble(), 1, 1),
              p);
        }
      }
      lastShafts++;
    }
  }

  /// Light shafts of [map] inside [view] (px). [strength] 0..1 (daylight
  /// through the openings); [t] in seconds; [motion] animates the motes.
  void drawShafts(Canvas c, GameMap map, Rect view, double t,
      {double strength = 1, bool motion = true}) {
    lastShafts = 0;
    if (strength <= 0) return;
    final x0 = (view.left / ts).floor() - 1, y0 = (view.top / ts).floor() - 1;
    final x1 = (view.right / ts).ceil() + 2,
        y1 = (view.bottom / ts).ceil() + 5;
    LightShaftRules.visible(map, x0, y0, x1, y1, _visible);
    if (_visible.isEmpty) return;
    final beam = _beam[_q(strength)], patch = _patch[_q(strength)];
    for (final (tx, ty) in _visible) {
      final px = (tx + 0.5) * ts, py = (ty + 0.5) * ts;
      final h = LightShaftRules.hash(tx, ty);
      c.save();
      c.translate(px, py);
      c.drawPath(_beamPath, beam);
      c.drawOval(_patchRect, patch);
      c.drawOval(_patchCore, patch);
      // Dappled flecks around the patch, and dust drifting down.
      for (var k = 0; k < 4; k++) {
        final hk = h >> (k * 4);
        c.save();
        c.translate(-18.0 + (hk % 36), -8.0 + ((hk >> 3) % 16));
        c.drawRect(_fleck, _dapple);
        c.restore();
      }
      if (motion) {
        for (var k = 0; k < 3; k++) {
          final ph = ((h >> (k * 5)) % 100) / 100;
          final f = (t * 0.12 + ph) % 1.0;
          c.save();
          c.translate(-4.0 + k * 5 + math.sin(t + k) * 2, -60 + f * 64);
          c.drawRect(_moteRect, _mote);
          c.restore();
        }
      }
      c.restore();
      lastShafts++;
    }
  }

  void dispose() {
    _shade?.dispose();
    _shade = null;
    _glow?.dispose();
    _glow = null;
    _roof?.dispose();
    _roof = null;
  }
}
