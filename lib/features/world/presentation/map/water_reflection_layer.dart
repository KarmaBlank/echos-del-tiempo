import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/data/tuning_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/rules/reflection_rules.dart';
import 'map_themes.dart';
import 'region_light_layer.dart';
import 'tile_cache.dart';

/// One actor to reflect: foot (px), moving, and how to draw it on any
/// canvas (the same code that draws it on the map).
typedef ReflectedActor = ({
  double x,
  double y,
  bool moving,
  bool onWater,
  void Function(Canvas c) draw,
});

/// One light that may leave a glow on the water: center (px), colour.
typedef ReflectedLight = ({double x, double y, Color color});

/// Pixel-art water reflections (docs/specs/water_reflections.md).
///
/// Built for the frame budget (§ 3): the water mask and the flipped shore
/// are rebuilt only when the 8-tile-aligned window around the view
/// changes; every frame records ONE picture (shore texture + flipped
/// actors + fade + tint + sky behind), turns it into one image and draws
/// it with one `drawRawAtlas` per water kind, one entry per horizontal
/// strip of each water run, the source shifted by the integer wave. The
/// strips only cover water, so the clip comes for free.
class WaterReflectionLayer {
  WaterReflectionLayer(this.tiles);

  /// Draws single shore tiles like the tile cache.
  final TileLayerCache tiles;

  static const ts = 16.0;
  static const _align = 8;
  static const _margin = 4;
  static const _pad = 4;

  /// Player setting.
  ReflectionLevel level = ReflectionLevel.high;

  /// Automatic low quality while frames are slow (§ 3).
  bool autoLow = false;
  double _frameMs = 16;

  // --- window cache ---
  Object? _key;
  int _wx0 = 0, _wy0 = 0, _ww = 0, _wh = 0;
  Uint8List _kind = Uint8List(0);

  /// Water runs of the window: (y, x0, x1 exclusive, kind) in tiles.
  final _runs = <int>[];
  ui.Image? _shore;

  // --- per-frame buffers ---
  final _xf = <WaterKind, Float32List>{};
  final _rc = <WaterKind, Float32List>{};
  final _n = <WaterKind, int>{};
  final _pts = List.generate(3, (_) => <double>[]);
  final _px = Paint()
    ..isAntiAlias = false
    ..strokeCap = StrokeCap.square
    ..strokeWidth = 1;
  final _fill = Paint()..isAntiAlias = false;
  double _tintK = -1;
  Color? _tintWater;
  ColorFilter? _tintFilter;
  final _atlas = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  /// Diagnostics (tests and perf): window builds, actors reflected and
  /// strips drawn last frame, frame images made.
  int windowBuilds = 0, lastActors = 0, lastStrips = 0, frames = 0;

  /// Microseconds spent turning the frame picture into an image (in
  /// tests this is software rasterization; in the app it is GPU work on
  /// the raster thread), summed over all frames (perf test).
  int imageMicros = 0;
  final _clock = Stopwatch();

  T _timed<T>(T Function() f) {
    _clock
      ..reset()
      ..start();
    final v = f();
    _clock.stop();
    imageMicros += _clock.elapsedMicroseconds;
    return v;
  }

  /// Cloud cells reflected last frame, per step (tests).
  final debugCloudCells = List.generate(3, (_) => <double>[]);

  /// Quality in use this frame.
  bool get high => level == ReflectionLevel.high && !autoLow;

  /// Feed the frame time (ms) for the automatic low quality.
  void frameTime(double ms) {
    _frameMs = _frameMs * 0.95 + ms * 0.05;
    final limit = kTuning[TuningId.regions]!.d('reflAutoLowMs');
    if (!autoLow && _frameMs > limit) autoLow = true;
    if (autoLow && _frameMs < limit * 0.7) autoLow = false;
  }

  void dispose() {
    _shore?.dispose();
    _shore = null;
    _key = null;
  }

  /// Whether the water at (x, y) px reflects the sky (open or murky water
  /// in the current window).
  bool reflectsSky(double x, double y) {
    final k = kindAt((x / ts).floor(), (y / ts).floor());
    return k == WaterKind.clear || k == WaterKind.murky;
  }

  /// Water kind at tile (x, y) inside the window (none outside).
  WaterKind kindAt(int x, int y) {
    final lx = x - _wx0, ly = y - _wy0;
    if (lx < 0 || ly < 0 || lx >= _ww || ly >= _wh) return WaterKind.none;
    return WaterKind.values[_kind[ly * _ww + lx]];
  }

  /// Rebuilds the mask and the shore texture when the window around
  /// [view] changes. Returns `false` when there is no water.
  bool _sync(GameMap map, Rect view, bool Function(int, int) roofed,
      List<(int, int)> lamps, Object? lampsKey) {
    final rows = kTuning[TuningId.regions]!.i('reflRows');
    int al(int v) => (v / _align).floor() * _align;
    final x0 = math.max(0, al((view.left / ts).floor() - _margin));
    final y0 = math.max(0, al((view.top / ts).floor() - _margin));
    final x1 = math.min(map.width, al((view.right / ts).ceil() + _margin) + _align);
    final y1 =
        math.min(map.height, al((view.bottom / ts).ceil() + _margin) + _align);
    final key = (map, x0, y0, x1, y1, lampsKey, rows);
    if (key == _key) return _runs.isNotEmpty;
    _key = key;
    windowBuilds++;
    _shore?.dispose();
    _shore = null;
    _wx0 = x0;
    _wy0 = y0;
    _ww = math.max(0, x1 - x0);
    _wh = math.max(0, y1 - y0);
    _kind = Uint8List(_ww * _wh);
    _runs.clear();
    var any = false;
    for (var y = y0; y < y1; y++) {
      final row = map.rows[y];
      for (var x = x0; x < x1; x++) {
        final ch = row[x];
        if (ch != Tile.water && ch != Tile.fishing) continue;
        final k = ReflectionRules.kindOf(ch, map.theme, roofed: roofed(x, y));
        _kind[(y - y0) * _ww + x - x0] = k.index;
        any = true;
      }
    }
    if (!any) return false;
    // Runs of the same kind per row.
    for (var y = 0; y < _wh; y++) {
      var x = 0;
      while (x < _ww) {
        final k = _kind[y * _ww + x];
        if (k == 0) {
          x++;
          continue;
        }
        final s = x;
        while (x < _ww && _kind[y * _ww + x] == k) {
          x++;
        }
        _runs
          ..add(y + y0)
          ..add(s + x0)
          ..add(x + x0)
          ..add(k);
      }
    }
    _shore = _buildShore(map, rows, lamps);
    return true;
  }

  /// The flipped shore of the window, faded in steps (§ 1.2).
  ui.Image? _buildShore(GameMap map, int rows, List<(int, int)> lamps) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..translate(-_wx0 * ts, -_wy0 * ts);
    final water = mapTheme(map.theme).water;
    final lampSet = {for (final l in lamps) l};
    final r = kTuning[TuningId.regions]!;
    final lip = r.d('reflBankLip');
    final bank = Paint()
      ..color = Color.fromRGBO(0, 0, 0, r.d('reflBankAlpha').clamp(0.0, 1.0));
    var drew = false;
    for (var y = _wy0; y < _wy0 + _wh; y++) {
      for (var x = _wx0; x < _wx0 + _ww; x++) {
        final k = kindAt(x, y);
        if (k != WaterKind.clear && k != WaterKind.murky) continue;
        // Only the first water tile of a column run has a shore above.
        if (!map.contains(x, y - 1)) continue;
        final above = map.tileAt(x, y - 1);
        if (above == Tile.water || above == Tile.fishing) continue;
        final line = y * ts;
        c
          ..save()
          ..clipRect(Rect.fromLTWH(x * ts, line, ts, rows * ts))
          ..translate(0, 2 * line)
          ..scale(1, -1);
        // The plain bank: only a short, faded lip right at the water line.
        if (_plain.contains(map.tileAt(x, y - 1))) {
          c
            ..save()
            ..clipRect(Rect.fromLTWH(x * ts, line - lip, ts, lip))
            ..saveLayer(Rect.fromLTWH(x * ts, line - lip, ts, lip), bank);
          tiles.drawTileAt(c, map, x, y - 1);
          c
            ..restore()
            ..restore();
        }
        for (var row = 1; row <= rows; row++) {
          for (var dx = -1; dx <= 1; dx++) {
            final sx = x + dx, sy = y - row;
            if (!map.contains(sx, sy)) continue;
            final ch = map.tileAt(sx, sy);
            if (ch == Tile.water ||
                ch == Tile.fishing ||
                ch == Tile.lava ||
                _plain.contains(ch)) {
              continue;
            }
            tiles.tiles.noGround = true;
            tiles.drawTileAt(c, map, sx, sy);
            tiles.tiles.noGround = false;
            if (lampSet.contains((sx, sy))) {
              tiles.tiles.faro(c, sx * ts, sy * ts, 0, lit: false);
            }
          }
        }
        c.restore();
        _fadeBands(c, x * ts, ts, line, rows * ts, water);
        drew = true;
      }
    }
    final pic = rec.endRecording();
    if (!drew) {
      pic.dispose();
      return null;
    }
    final img = pic.toImageSync((_ww * ts).round(), (_wh * ts).round());
    pic.dispose();
    return img;
  }

  /// Ground without a prop: reflected only as a short faded lip.
  static const _plain = {
    Tile.grass,
    Tile.floor,
    Tile.path,
    Tile.soil,
    Tile.bridge,
    Tile.forageUsed,
  };

  /// Fades what is already drawn under [line] in the discrete steps of
  /// `ReflectionRules.fadeStep`, toward [water] (srcATop: only where
  /// something is drawn).
  void _fadeBands(
      Canvas c, double x, double w, double line, double len, Color water) {
    final r = kTuning[TuningId.regions]!;
    final f1 = r.d('reflFade1'), f2 = r.d('reflFade2');
    _fill.blendMode = BlendMode.srcATop;
    _fill.color = water.withValues(alpha: ReflectionRules.fadeBlend[1]);
    c.drawRect(Rect.fromLTWH(x, line + f1, w, f2 - f1), _fill);
    _fill.color = water.withValues(alpha: ReflectionRules.fadeBlend[2]);
    c.drawRect(Rect.fromLTWH(x, line + f2, w, math.max(0, len - f2)), _fill);
    _fill.blendMode = BlendMode.srcOver;
  }

  /// The reflection pass (§ 4): under the actors. [t] in seconds (0 with
  /// reduced motion), [darkness] 0 day .. 1 night, [cover] the cloud
  /// cover (0 = no sky: indoors), [field] the map size in px.
  void draw(
    Canvas c,
    GameMap map,
    Rect view, {
    required double t,
    required double darkness,
    required double cover,
    required Size field,
    required List<ReflectedActor> actors,
    required bool Function(int, int) roofed,
    bool sky = true,
    List<(int, int)> lamps = const [],
    Object? lampsKey,
  }) {
    lastActors = 0;
    lastStrips = 0;
    if (level == ReflectionLevel.off) return;
    if (!_sync(map, view, roofed, lamps, lampsKey)) return;
    final r = kTuning[TuningId.regions]!;
    final water = mapTheme(map.theme).water;
    final hi = high;
    final sh = ReflectionRules.stripHeight(high: hi);
    // --- the frame picture: only the visible reflecting water (+ pad) ---
    var bx0 = double.infinity, by0 = double.infinity;
    var bx1 = -double.infinity, by1 = -double.infinity;
    for (var i = 0; i < _runs.length; i += 4) {
      if (_runs[i + 3] == WaterKind.cave.index) continue;
      final y = _runs[i] * ts;
      if (y + ts <= view.top || y >= view.bottom) continue;
      final a = _runs[i + 1] * ts, b = _runs[i + 2] * ts;
      if (b <= view.left || a >= view.right) continue;
      bx0 = math.min(bx0, a);
      bx1 = math.max(bx1, b);
      by0 = math.min(by0, y);
      by1 = math.max(by1, y + ts);
    }
    if (bx1 <= bx0) return;
    final box = Rect.fromLTRB(bx0, by0, bx1, by1).intersect(view);
    final ox = box.left.floor() - _pad, oy = box.top.floor() - _pad;
    final iw = box.width.ceil() + 2 * _pad + 1;
    final ih = box.height.ceil() + 2 * _pad + 1;
    final rec = ui.PictureRecorder();
    final p = Canvas(rec)..translate(-ox.toDouble(), -oy.toDouble());
    if (_shore case final img?) {
      final dst = Rect.fromLTWH(
          ox.toDouble(), oy.toDouble(), iw.toDouble(), ih.toDouble());
      final src = dst.shift(Offset(-_wx0 * ts, -_wy0 * ts)).intersect(
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
      if (!src.isEmpty) {
        p.drawImageRect(
            img, src, src.shift(Offset(_wx0 * ts, _wy0 * ts)), _atlas);
      }
    }
    // Actors near the water, capped (§ 1.1).
    final cands = <ReflectionCandidate>[];
    final lines = <double>[];
    final keep = <ReflectedActor>[];
    for (final a in actors) {
      if (a.x < view.left - 24 || a.x > view.right + 24) continue;
      if (a.y < view.top - 48 || a.y > view.bottom + 8) continue;
      final l0 = ReflectionRules.anchor(a.x, a.y, kindAt);
      if (l0 == null) continue;
      final l = a.onWater ? l0 + ReflectionRules.floatDrop() : l0;
      final k = kindAt((a.x / ts).floor(), (l / ts).floor());
      if (k == WaterKind.cave || k == WaterKind.none) continue;
      cands.add((x: a.x, y: a.y, moving: a.moving));
      lines.add(l);
      keep.add(a);
    }
    final picked = ReflectionRules.pick(
        cands, view.center.dx, view.center.dy, ReflectionRules.actorCap(high: hi));
    for (final i in picked) {
      final a = keep[i], l = lines[i];
      p
        ..save()
        ..translate(0, (l + a.y).roundToDouble())
        ..scale(1, -1);
      a.draw(p);
      p.restore();
      _fadeBands(p, a.x - 16, 32, l, 48, water);
    }
    lastActors = picked.length;
    // Sky and clouds behind everything (§ 1.3).
    if (sky) _sky(p, view, t, darkness, cover, field);
    _fill.blendMode = BlendMode.srcOver;
    final pic = rec.endRecording();
    final img = _timed(() => pic.toImageSync(iw, ih));
    pic.dispose();
    frames++;
    // --- strips (§ 1.5) ---
    final movers = <(double, double)>[
      for (final a in actors)
        if (a.moving || a.onWater)
          if (view.inflate(32).contains(Offset(a.x, a.y))) (a.x, a.y),
    ];
    if (movers.length > 6) movers.length = 6;
    _n.updateAll((_, __) => 0);
    final top = view.top.floor(), bottom = view.bottom.ceil();
    for (var i = 0; i < _runs.length; i += 4) {
      final kind = WaterKind.values[_runs[i + 3]];
      if (kind == WaterKind.cave) continue;
      final ty = _runs[i];
      final rowTop = (ty * ts).toInt();
      if (rowTop + ts <= top || rowTop >= bottom) continue;
      final rx0 = math.max(_runs[i + 1] * ts, view.left.floorToDouble());
      final rx1 = math.min(_runs[i + 2] * ts, view.right.ceilToDouble());
      if (rx1 <= rx0) continue;
      for (var y = rowTop; y < rowTop + ts; y += sh) {
        if (y + sh <= top || y >= bottom) continue;
        final base = ReflectionRules.wave(y.toDouble(), t);
        var x = rx0;
        // Wake: split the strip where a mover disturbs it.
        for (final (mx, my) in movers) {
          final dy = (y - my).abs();
          final extra = ReflectionRules.wake(dy);
          if (extra <= 0) continue;
          final half = math.sqrt(math.max(0, r.d('reflWakeRadius') *
                      r.d('reflWakeRadius') -
                  dy * dy))
              .floorToDouble();
          final a = math.max(x, mx.floorToDouble() - half);
          final b = math.min(rx1, mx.floorToDouble() + half);
          if (b <= a) continue;
          if (a > x) _strip(kind, x, a, y, sh, base, ox, oy);
          final d = ReflectionRules.wave(y.toDouble(), t * 2.3, extra: extra) *
              ((y ~/ sh).isEven ? 1 : -1);
          _strip(kind, a, b, y, sh, d, ox, oy);
          x = b;
        }
        if (x < rx1) _strip(kind, x, rx1, y, sh, base, ox, oy);
      }
    }
    // Tint toward the water colour (§ 1.5): a colour filter on the strips,
    // no extra pass over the image.
    final tint = r.d('reflTint');
    if (tint != _tintK || water != _tintWater) {
      _tintK = tint;
      _tintWater = water;
      _tintFilter = ColorFilter.mode(
          water.withValues(alpha: tint.clamp(0.0, 1.0)), BlendMode.srcATop);
    }
    _atlas.colorFilter = _tintFilter;
    for (final kind in const [WaterKind.clear, WaterKind.murky]) {
      final n = _n[kind] ?? 0;
      if (n == 0) continue;
      lastStrips += n;
      _atlas.color =
          Color.fromRGBO(255, 255, 255, ReflectionRules.alphaOf(kind));
      c.drawRawAtlas(img, Float32List.sublistView(_xf[kind]!, 0, n * 4),
          Float32List.sublistView(_rc[kind]!, 0, n * 4), null, null, null,
          _atlas);
    }
    _atlas
      ..color = const Color(0xFFFFFFFF)
      ..colorFilter = null;
    img.dispose();
    _wakeFoam(c, movers, t);
  }

  void _strip(WaterKind k, double x0, double x1, int y, int sh, int dx,
      int ox, int oy) {
    final n = _n[k] ?? 0;
    var xf = _xf[k], rc = _rc[k];
    if (xf == null || xf.length < (n + 1) * 4) {
      final cap = math.max(256, (n + 1) * 8);
      final nx = Float32List(cap), nr = Float32List(cap);
      if (xf != null) {
        nx.setRange(0, n * 4, xf);
        nr.setRange(0, n * 4, rc!);
      }
      _xf[k] = xf = nx;
      _rc[k] = rc = nr;
    }
    final o = n * 4;
    xf[o] = 1;
    xf[o + 1] = 0;
    xf[o + 2] = x0;
    xf[o + 3] = y.toDouble();
    final sx = x0 - ox - dx;
    rc![o] = sx;
    rc[o + 1] = (y - oy).toDouble();
    rc[o + 2] = sx + (x1 - x0);
    rc[o + 3] = (y - oy + sh).toDouble();
    _n[k] = n + 1;
  }

  /// Sky veil and mirrored cloud cells, behind what is drawn (dstOver).
  void _sky(Canvas p, Rect view, double t, double darkness, double cover,
      Size field) {
    final r = kTuning[TuningId.regions]!;
    final (sr, sg, sb) = ReflectionRules.sky(darkness);
    final skyCol = Color.fromARGB(255, sr, sg, sb);
    final light = Color.lerp(skyCol, const Color(0xFFFFFFFF), 0.55)!;
    for (final b in _pts) {
      b.clear();
    }
    // The same clouds that shade the land (RegionLightLayer.cloudCells),
    // where they pass over water: a light patch instead of a shadow.
    for (final b in debugCloudCells) {
      b.clear();
    }
    const cell = RegionLightLayer.cloudCell;
    RegionLightLayer.cloudCells(view, t, cover, field.width, field.height,
        (x, y, step) {
      final k = kindAt((x / ts).floor(), (y / ts).floor());
      if (k != WaterKind.clear && k != WaterKind.murky) return;
      debugCloudCells[step - 1]
        ..add(x)
        ..add(y);
    });
    for (var s = 0; s < 3; s++) {
      _pts[s]
        ..clear()
        ..addAll(debugCloudCells[s]);
    }
    _px
      ..strokeWidth = cell
      ..blendMode = BlendMode.dstOver;
    final ca = r.d('reflCloudAlpha') * (1 - darkness * 0.7);
    for (var s = 2; s >= 0; s--) {
      if (_pts[s].isEmpty) continue;
      _px.color = light.withValues(alpha: ca * (s + 1) / 3);
      p.drawRawPoints(
          ui.PointMode.points, Float32List.fromList(_pts[s]), _px);
    }
    _px
      ..strokeWidth = 1
      ..blendMode = BlendMode.srcOver;
    _fill
      ..blendMode = BlendMode.dstOver
      // A warmer, stronger veil around sunset / sunrise.
      ..color = skyCol.withValues(
          alpha: (r.d('reflSkyAlpha') *
                  (1 + 0.8 * (1 - (2 * darkness - 1).abs())))
              .clamp(0.0, 1.0));
    p.drawRect(view.inflate(_pad.toDouble()), _fill);
    _fill.blendMode = BlendMode.srcOver;
  }

  /// 1 px foam behind actors moving on the water (raft wake).
  void _wakeFoam(Canvas c, List<(double, double)> movers, double t) {
    final pts = _pts[0]..clear();
    final ph = (t * 4).floor();
    for (final (mx, my) in movers) {
      for (var k = 1; k <= 3; k++) {
        for (final s in const [-1, 1]) {
          final x = (mx + s * (4 + k * 3)).floorToDouble() + 0.5;
          final y =
              (my + 2 + k * 2 + ((ph + k).isEven ? 1 : 0)).floorToDouble() +
                  0.5;
          if (kindAt((x / ts).floor(), (y / ts).floor()) == WaterKind.none) {
            continue;
          }
          if ((ph + k + s) % 3 == 0) continue;
          pts
            ..add(x)
            ..add(y);
        }
      }
    }
    if (pts.isEmpty) return;
    _px.color = const Color(0x99E8F6FF);
    c.drawRawPoints(ui.PointMode.points, Float32List.fromList(pts), _px);
  }

  /// Night light glows, star glints and the warm dusk surface (§ 1.3-1.4),
  /// after the light layer.
  void drawLights(
    Canvas c,
    Rect view, {
    required List<ReflectedLight> lights,
    required double t,
    required double darkness,
  }) {
    if (level == ReflectionLevel.off || _runs.isEmpty || _key == null) return;
    final r = kTuning[TuningId.regions]!;
    final len = r.i('reflGlowLen');
    final alpha = r.d('reflGlowAlpha');
    // Warm sunset / sunrise on the water surface (§ 1.3).
    final warm = ReflectionRules.duskTint(darkness);
    if (warm > 0) {
      _fill.color = const Color(0xFFFF9C84).withValues(alpha: warm);
      for (var i = 0; i < _runs.length; i += 4) {
        if (_runs[i + 3] == WaterKind.cave.index) continue;
        final rect = Rect.fromLTRB(_runs[i + 1] * ts, _runs[i] * ts,
            _runs[i + 2] * ts, (_runs[i] + 1) * ts);
        if (!rect.overlaps(view)) continue;
        c.drawRect(rect.intersect(view), _fill);
      }
    }
    for (final l in lights) {
      if (l.x < view.left - 8 || l.x > view.right + 8) continue;
      if (l.y < view.top - 48 || l.y > view.bottom) continue;
      final line = ReflectionRules.anchor(l.x, l.y, kindAt);
      if (line == null) continue;
      final cave = kindAt((l.x / ts).floor(), (line / ts).floor()) ==
          WaterKind.cave;
      final k = cave ? 1.0 : ((darkness - 0.25) / 0.5).clamp(0.0, 1.0);
      if (k <= 0) continue;
      for (final b in _pts) {
        b.clear();
      }
      final seed = (l.x * 7 + l.y * 13).floor();
      final cx = l.x.floorToDouble();
      // The mirrored point of the light, a few px under the water line.
      final y0 = line.floorToDouble() + (line - l.y).clamp(1.0, 6.0).floor();
      bool wet(double y) =>
          kindAt((cx / ts).floor(), (y / ts).floor()) != WaterKind.none;
      if (wet(y0)) {
        // A 2 px core.
        _pts[0]
          ..add(cx + 0.5)
          ..add(y0 + 0.5)
          ..add(cx - 0.5)
          ..add(y0 + 0.5);
      }
      for (final (dy, w, step) in ReflectionRules.glowDashes(seed, t)) {
        if (dy >= len) break;
        final y = y0 + dy;
        if (y > view.bottom || !wet(y)) break;
        final dx = ReflectionRules.wave(y, t);
        for (var j = 0; j < w; j++) {
          _pts[step]
            ..add(cx - (w ~/ 2) + j + dx + 0.5)
            ..add(y + 0.5);
        }
      }
      for (var s = 0; s < 3; s++) {
        if (_pts[s].isEmpty) continue;
        _px.color = l.color.withValues(alpha: alpha * k * (3 - s) / 3);
        c.drawRawPoints(
            ui.PointMode.points, Float32List.fromList(_pts[s]), _px);
      }
    }
    // Stars and the moon on open water (night, high quality).
    if (darkness < 0.6 || !high) return;
    final cells = <(int, int)>[];
    final vx0 = (view.left / ts).floor(), vx1 = (view.right / ts).ceil();
    final vy0 = (view.top / ts).floor(), vy1 = (view.bottom / ts).ceil();
    for (var i = 0; i < _runs.length; i += 4) {
      if (_runs[i + 3] == WaterKind.cave.index) continue;
      final y = _runs[i];
      if (y < vy0 || y > vy1) continue;
      for (var x = math.max(_runs[i + 1], vx0);
          x < math.min(_runs[i + 2], vx1);
          x++) {
        cells.add((x, y));
      }
    }
    final stars = ReflectionRules.stars(cells.length, t, high: true);
    final pts = _pts[0]..clear();
    for (final s in stars) {
      final (x, y) = cells[s];
      final h = (x * 31 + y * 17) & 15;
      final sx = x * ts + h + 0.5, sy = y * ts + ((h * 7) & 15) + 0.5;
      pts
        ..add(sx + ReflectionRules.wave(sy, t))
        ..add(sy);
    }
    if (pts.isNotEmpty) {
      _px.color = const Color(0xCCF4F1D8);
      c.drawRawPoints(ui.PointMode.points, Float32List.fromList(pts), _px);
    }
    // Moon glint: a short dash on the water cell nearest the view center.
    if (cells.isNotEmpty) {
      var best = cells.first;
      var bd = double.infinity;
      final cx = view.center.dx, cy = view.top + view.height * 0.35;
      for (final (x, y) in cells) {
        final d = ((x + 0.5) * ts - cx).abs() + ((y + 0.5) * ts - cy).abs();
        if (d < bd) {
          bd = d;
          best = (x, y);
        }
      }
      final (mx, my) = best;
      _fill.color = const Color(0x88E8EEFF);
      for (var i = 0; i < 3; i++) {
        final y = my * ts + 5 + i * 3;
        final w = 6.0 - i * 2;
        final dx = ReflectionRules.wave(y, t);
        c.drawRect(Rect.fromLTWH(mx * ts + 8 - w / 2 + dx, y, w, 1), _fill);
      }
    }
  }
}
