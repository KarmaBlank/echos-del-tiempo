import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/rules/biome_regions.dart';
import '../../../../game_engine/rules/light_shaft_rules.dart';
import '../../../../game_engine/rules/region_ambience_rules.dart';
import 'map_themes.dart';

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
  final List<Paint> _cloud = [
    for (var i = 0; i <= _steps; i++)
      Paint()
        ..color = RegionPalette.cloudShadow
            .withValues(alpha: 0.055 * i / _steps)
  ];
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
    final p = _cloud[k];
    for (var i = 0; i < n; i++) {
      final (x, y, rx, ry) = LightShaftRules.cloud(i, t, fieldW, fieldH);
      if (x + rx < view.left ||
          x - rx > view.right ||
          y + ry < view.top ||
          y - ry > view.bottom) {
        continue;
      }
      c.save();
      c.translate(x, y);
      c.scale(1, ry / rx);
      // Three stacked discs: a soft edge without a shader or blur.
      c.drawCircle(Offset.zero, rx, p);
      c.drawCircle(Offset.zero, rx * 0.78, p);
      c.drawCircle(Offset.zero, rx * 0.55, p);
      c.restore();
    }
  }

  /// Darkness under cave roofs of a daylit region ([lay]); a cached
  /// picture of the whole layout, clipped by the canvas to the view.
  void drawCaveShade(Canvas c, BiomeLayout lay, double strength) {
    if (strength <= 0) return;
    if (_shade == null || !identical(_shadeKey, lay)) {
      _shade?.dispose();
      final rec = ui.PictureRecorder();
      final pc = Canvas(rec);
      final paint = Paint()..color = RegionPalette.caveShade;
      for (var y = 0; y < BiomeLayout.height; y++) {
        var run = -1;
        for (var x = 0; x <= BiomeLayout.width; x++) {
          final inn = x < BiomeLayout.width && lay.isIndoor(x, y);
          if (inn && run < 0) run = x;
          if (!inn && run >= 0) {
            pc.drawRect(
                Rect.fromLTWH(run * ts, y * ts, (x - run) * ts, ts), paint);
            run = -1;
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

  /// Roof edge / overhang at the mouths of the roofed caves of [lay]
  /// (biome_regions.md § 7.2.1); drawn above the actors. Cached picture.
  void drawRoofEdges(Canvas c, BiomeLayout lay, String Function(int, int) at) {
    final lip = RegionAmbienceRules.roofLip;
    if (lip <= 0) return;
    if (_roof == null || !identical(_roofKey, lay)) {
      _roof?.dispose();
      final rec = ui.PictureRecorder();
      final pc = Canvas(rec);
      final body = Paint()
        ..color = RegionPalette.roofLip
        ..isAntiAlias = false;
      final edge = Paint()
        ..color = RegionPalette.roofLipEdge
        ..isAntiAlias = false;
      for (var y = 0; y < BiomeLayout.height; y++) {
        for (var x = 0; x < BiomeLayout.width; x++) {
          for (final side in RegionAmbienceRules.roofEdges(lay, at, x, y)) {
            final px = x * ts, py = y * ts;
            final h = LightShaftRules.hash(x, y);
            switch (side) {
              case RoofSide.north || RoofSide.south:
                final top = side == RoofSide.north;
                final y0 = top ? py : py + ts - lip;
                pc.drawRect(Rect.fromLTWH(px, y0, ts, lip), body);
                pc.drawRect(
                    Rect.fromLTWH(px, top ? y0 : y0 + lip - 1, ts, 1), edge);
                // Hanging teeth of rock.
                for (var k = 0; k < 3; k++) {
                  final tx = px + 1 + k * 5 + (h >> k) % 2;
                  final th = 1.0 + ((h >> (k + 2)) % 3);
                  pc.drawRect(
                      Rect.fromLTWH(tx, top ? y0 + lip : y0 - th, 2, th), body);
                }
              case RoofSide.west || RoofSide.east:
                final left = side == RoofSide.west;
                final x0 = left ? px : px + ts - lip;
                pc.drawRect(Rect.fromLTWH(x0, py, lip, ts), body);
                pc.drawRect(
                    Rect.fromLTWH(left ? x0 : x0 + lip - 1, py, 1, ts), edge);
                for (var k = 0; k < 3; k++) {
                  final ty = py + 1 + k * 5 + (h >> k) % 2;
                  final tw = 1.0 + ((h >> (k + 2)) % 3);
                  pc.drawRect(
                      Rect.fromLTWH(left ? x0 + lip : x0 - tw, ty, tw, 2),
                      body);
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
    _roof?.dispose();
    _roof = null;
  }
}
