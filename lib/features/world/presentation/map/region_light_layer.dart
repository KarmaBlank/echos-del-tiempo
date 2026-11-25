import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/rules/light_shaft_rules.dart';
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
  }
}
