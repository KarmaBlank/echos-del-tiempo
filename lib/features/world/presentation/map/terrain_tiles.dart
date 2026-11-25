part of 'tile_painter.dart';

/// Four-step colour ramp of a terrain colour (tile_detail.md § 2): the
/// same deep / shade / base / mid / lit steps the cave palette spells out
/// by hand, derived from the theme colours so the theme stays the only
/// knob.
class TerrainRamp {
  TerrainRamp._(this.base, Color alt)
      : deep = Color.lerp(base, const Color(0xFF000000), 0.45)!,
        shade = Color.lerp(base, const Color(0xFF000000), 0.22)!,
        mid = alt,
        lit = Color.lerp(alt, const Color(0xFFFFFFFF), 0.32)!;

  final Color deep, shade, base, mid, lit;

  static final _cache = <(int, int), TerrainRamp>{};

  /// Cached: water is redrawn every frame.
  static TerrainRamp of(Color base, Color alt) => _cache.putIfAbsent(
      (base.toARGB32(), alt.toARGB32()), () => TerrainRamp._(base, alt));
}

/// Themes whose open terrain gets the cave-level detail: the outdoor
/// maps (town, world map, biome exteriors). tile_detail.md § 1.
bool terrainDetailTheme(String themeId) =>
    themeId == 'pueblo' || themeId == 'mundo' || themeId.endsWith('_ext');

extension _TerrainTiles on TilePainter {
  static const _ts = TilePainter.ts;

  /// Non-negative hash bits: every offset stays inside the cell.
  static int _b(int h, int shift, int m) => ((h >> shift) & 0xffff) % m;

  /// A pebble: lit pixel up-left, mid top, shadow under it.
  void _pebble(Canvas c, TerrainRamp r, double x, double y, double w) {
    _rect(c, r.deep, x, y + 1, w, 1);
    _rect(c, r.mid, x, y, w, 1);
    _rect(c, r.lit, x, y, 1, 1);
  }

  /// Irregular bumps along one side (0 top, 1 right, 2 bottom, 3 left)
  /// toward a neighbour of another terrain: the silhouette is never a
  /// straight tile edge (tile_detail.md § 3).
  void _edgeBumps(Canvas c, Color col, double px, double py, int h, int shift,
      {required int side, int maxDepth = 3}) {
    for (var i = 0; i < 4; i++) {
      final d = _b(h, shift + i * 2, maxDepth + 1).toDouble();
      if (d == 0) continue;
      switch (side) {
        case 0:
          _rect(c, col, px + i * 4, py, 4, d);
        case 1:
          _rect(c, col, px + _ts - d, py + i * 4, d, 4);
        case 2:
          _rect(c, col, px + i * 4, py + _ts - d, 4, d);
        default:
          _rect(c, col, px, py + i * 4, d, 4);
      }
    }
  }

  /// A clump [s] px wide (2-4): deep base, mid body, lit top edge and a
  /// lit pixel up-left — the cave boulder at grass scale.
  void _clump(Canvas c, TerrainRamp r, double x, double y, int s) {
    final w = s.toDouble();
    _rect(c, r.deep, x - 1, y + w - 1, w + 2, 1);
    _rect(c, r.mid, x, y, w, w - 1);
    _rect(c, r.lit, x, y, w - 1, 1);
    _rect(c, r.lit, x, y + 1, 1, 1);
  }

  /// A small stone in the mountain colours: deep foot, body, lit top.
  void _stone(Canvas c, MapTheme th, double x, double y, int s) {
    final w = s.toDouble();
    _rect(
        c, Color.lerp(th.rock, const Color(0xFF000000), 0.4)!, x, y + 2, w, 1);
    _rect(c, th.rock, x, y, w, 2);
    _rect(c, th.rock2, x, y, w - 1, 1);
  }

  /// A darker patch of 6-9 px with a deep lower rim.
  void _patchOf(Canvas c, TerrainRamp r, double px, double py, int h) {
    final w = 6.0 + _b(h, 9, 4),
        x = px + _b(h, 2, 17 - w.toInt()),
        y = py + 1 + _b(h, 6, 9);
    _rect(c, r.shade, x + 1, y, w - 2, 5);
    _rect(c, r.shade, x, y + 1, w, 3);
    _rect(c, r.deep, x + 1, y + 5, w - 2, 1);
  }

  /// Grass: base, a darker patch, 1-2 clumps (2-4 px), a blade tuft, a
  /// small stone, a rare flower; shade under the mountain, lip by water.
  void _grassDetail(Canvas c, MapTheme th, double px, double py, int tx, int ty,
      int h, TileAt? at) {
    final r = TerrainRamp.of(th.grass, th.grass2);
    _rect(c, r.base, px, py, _ts, _ts);
    if (h % 3 == 0) _patchOf(c, r, px, py, h);
    for (var k = 0; k < 1 + (h >> 20) % 2; k++) {
      final s = 2 + _b(h, 3 + k * 7, 3);
      _clump(c, r, px + 1 + _b(h, 5 + k * 6, 14 - s),
          py + 1 + _b(h, 11 + k * 6, 14 - s), s);
    }
    if (h % 2 == 1) {
      final x = px + 2 + _b(h, 13, 11), y = py + 3 + _b(h, 17, 10);
      _rect(c, r.deep, x, y + 2, 3, 1);
      _rect(c, r.mid, x, y, 1, 2);
      _rect(c, r.lit, x + 2, y - 1, 1, 3);
    }
    if (h % 11 == 3) {
      _stone(c, th, px + 2 + _b(h, 7, 10), py + 2 + _b(h, 15, 10),
          2 + _b(h, 4, 2));
    }
    if (h % 17 == 0) {
      final x = px + 2 + _b(h, 5, 11), y = py + 2 + _b(h, 13, 11);
      _rect(c, r.deep, x, y + 2, 2, 1);
      _rect(c, h % 2 == 0 ? const Color(0xFFFFD166) : const Color(0xFFFF8FA3),
          x, y, 2, 2);
    }
    if (at == null) return;
    if (at(tx, ty - 1) == Tile.rock) _rect(c, r.deep, px, py, _ts, 2);
    final below = at(tx, ty + 1);
    if (below == Tile.water || below == Tile.fishing) {
      _edgeBumps(c, r.deep, px, py, h, 3, side: 2, maxDepth: 2);
    }
  }

  /// Open ground: a darker patch, 1-2 clumps of earth, small stones, a
  /// crack, a lit speck.
  void _groundDetail(Canvas c, MapTheme th, double px, double py, int h) {
    final r = TerrainRamp.of(th.ground, th.ground2);
    _rect(c, r.base, px, py, _ts, _ts);
    if (h % 3 == 1) _patchOf(c, r, px, py, h);
    for (var k = 0; k < 1 + (h >> 21) % 2; k++) {
      final s = 2 + _b(h, 4 + k * 7, 2);
      _clump(c, r, px + 1 + _b(h, 5 + k * 6, 14 - s),
          py + 1 + _b(h, 9 + k * 6, 14 - s), s);
    }
    if (h % 4 == 2) {
      _pebble(c, r, px + 1 + _b(h, 12, 12), py + 1 + _b(h, 16, 13), 2);
    }
    if (h % 5 == 1) {
      final x = px + 3 + _b(h, 11, 9), y = py + 3 + _b(h, 14, 8);
      _rect(c, r.deep, x, y, 1, 2);
      _rect(c, r.deep, x + 1, y + 2, 2, 1);
    }
    if (h % 9 == 4) {
      _rect(c, r.lit, px + _b(h, 2, 15), py + _b(h, 17, 15), 1, 1);
    }
  }

  /// Path / road: worn base, a rut, gravel with lit tops, grass bumps
  /// eating in from grass neighbours and the shadow they cast.
  void _pathDetail(Canvas c, MapTheme th, double px, double py, int tx, int ty,
      int h, TileAt? at) {
    final r = TerrainRamp.of(th.path, th.path2);
    _rect(c, r.base, px, py, _ts, _ts);
    if (h % 3 == 0) {
      _rect(c, r.mid, px + _b(h, 4, 9), py + _b(h, 8, 12), 6, 2);
    }
    for (var k = 0; k < 2 + h % 2; k++) {
      final x = px + 1 + _b(h, 3 + k * 5, 13),
          y = py + 1 + _b(h, 7 + k * 5, 13);
      _rect(c, r.deep, x, y + 1, 2, 1);
      _rect(c, r.lit, x, y, 1, 1);
    }
    if (at == null) return;
    final g = TerrainRamp.of(th.grass, th.grass2);
    bool soft(String? t) => t == Tile.grass || t == Tile.tree || t == Tile.rock;
    if (soft(at(tx, ty - 1))) {
      _rect(c, r.shade, px, py, _ts, 3);
      _edgeBumps(c, g.base, px, py, h, 1, side: 0, maxDepth: 2);
    }
    if (soft(at(tx - 1, ty))) {
      _edgeBumps(c, g.base, px, py, h, 5, side: 3, maxDepth: 2);
    }
    if (soft(at(tx + 1, ty))) {
      _edgeBumps(c, g.base, px, py, h, 9, side: 1, maxDepth: 2);
    }
    if (soft(at(tx, ty + 1))) {
      _edgeBumps(c, g.base, px, py, h, 13, side: 2, maxDepth: 2);
    }
  }

  /// Static part of water: a shaded body, ripples with a lit crest, a lit
  /// shore band with foam bumps along land neighbours.
  void _waterDetail(Canvas c, MapTheme th, double px, double py, int tx, int ty,
      int h, TileAt? at) {
    final w = th.water;
    final r = TerrainRamp.of(w, Color.lerp(w, const Color(0xFFFFFFFF), 0.14)!);
    _rect(c, r.shade, px, py, _ts, _ts);
    final x = px + 1 + _b(h, 3, 9), y = py + 2 + _b(h, 7, 11);
    _rect(c, r.deep, x, y + 1, 5, 1);
    _rect(c, r.base, x + 1, y, 3, 1);
    if (h % 2 == 0) {
      final x2 = px + 2 + _b(h, 11, 9), y2 = py + 3 + _b(h, 13, 10);
      _rect(c, r.deep, x2, y2 + 1, 4, 1);
      _rect(c, r.base, x2, y2, 3, 1);
    }
    if (at == null) return;
    bool land(String? t) =>
        t != null && t != Tile.water && t != Tile.fishing && t != Tile.bridge;
    if (land(at(tx, ty - 1))) _shore(c, r, px, py, h, 0);
    if (land(at(tx + 1, ty))) _shore(c, r, px, py, h, 1);
    if (land(at(tx, ty + 1))) _shore(c, r, px, py, h, 2);
    if (land(at(tx - 1, ty))) _shore(c, r, px, py, h, 3);
  }

  void _shore(Canvas c, TerrainRamp r, double px, double py, int h, int s) {
    _edgeBumps(c, r.mid, px, py, h, 2 + s * 3, side: s, maxDepth: 3);
    _edgeBumps(c, r.lit, px, py, h, 5 + s * 3, side: s, maxDepth: 1);
  }

  /// Mountain (tile_detail.md § 3.1): one of four peak shapes by hash
  /// (tall, low and wide, double, shoulder), a lit left face and a shaded
  /// right face, optional snow; joined to rock neighbours as one mass
  /// (a body fill toward rock sides, no foot line inside the range) and
  /// boulders at the foot of the range.
  void _rockDetail(Canvas c, MapTheme th, double px, double py, int tx, int ty,
      int h, TileAt? at) {
    bool rk(int dx, int dy) => at?.call(tx + dx, ty + dy) == Tile.rock;
    final up = rk(0, -1), lf = rk(-1, 0), rt = rk(1, 0), dn = rk(0, 1);
    const black = Color(0xFF000000), white = Color(0xFFFFFFFF);
    final lit = th.rock2,
        shaded = th.rock,
        hi = Color.lerp(th.rock2, white, 0.35)!,
        body = Color.lerp(th.rock, black, 0.25)!,
        deep = Color.lerp(th.rock, black, 0.5)!;
    // The mass: a body fill toward rock neighbours.
    if (up) {
      _rect(c, body, px, py, _ts, _ts);
      _rect(c, deep, px + 2 + _b(h, 3, 9), py + 3 + _b(h, 7, 4), 4, 1);
    } else if (lf || rt) {
      final x0 = lf ? px : px + 3, x1 = rt ? px + _ts : px + 13;
      _rect(c, body, x0, py + 9, x1 - x0, 7);
    }
    if (dn && (lf || rt || up)) {
      final x0 = lf ? px : px + 2, x1 = rt ? px + _ts : px + 14;
      _rect(c, body, x0, py + 12, x1 - x0, 4);
    }
    void peak(double ax, double top, double slope, {required bool snow}) {
      for (var y = top; y < py + _ts; y++) {
        final half = ((y - top) * slope + 0.6).roundToDouble();
        final l = math.max(ax - half, px), rr = math.min(ax + half, px + _ts);
        if (ax > l) _rect(c, lit, l, y, ax - l, 1);
        if (rr > ax) _rect(c, shaded, ax, y, rr - ax, 1);
        if (((y - top) % 3) == 1 && ax - half >= px) {
          _rect(c, hi, l, y, 1, 1);
        }
        if (ax + half <= px + _ts && rr > ax) {
          _rect(c, deep, rr - 1, y, 1, 1);
        }
      }
      // Strata on the shaded face.
      final sy = top + ((py + _ts - top) * 0.55).roundToDouble();
      _rect(c, deep, ax + 1, sy, 2, 1);
      _rect(c, hi, ax - 3 >= px ? ax - 3 : px, sy + 2, 2, 1);
      if (snow) {
        _rect(c, white.withValues(alpha: 0.92), ax - 1, top, 2, 2);
        _rect(c, white.withValues(alpha: 0.92), ax - 2, top + 2, 2, 1);
        _rect(c, const Color(0xFFB8C4D8), ax, top + 2, 2, 1);
        _rect(c, const Color(0xFFB8C4D8), ax + 1, top + 3, 1, 1);
      }
    }

    final snowy = !up && h % 3 != 0;
    switch (h % 4) {
      case 0: // tall
        peak(px + 6 + _b(h, 3, 5), py + _b(h, 6, 2), 0.55, snow: snowy);
      case 1: // low and wide
        peak(px + 7 + _b(h, 3, 3), py + 5 + _b(h, 6, 3), 0.95, snow: false);
      case 2: // double
        peak(px + 4 + _b(h, 3, 2), py + 1 + _b(h, 6, 2), 0.6, snow: snowy);
        peak(px + 11 + _b(h, 8, 2), py + 4 + _b(h, 10, 3), 0.6, snow: false);
      default: // shoulder: offset apex
        final left = h & 16 == 0;
        peak(left ? px + 4 : px + 12, py + 2 + _b(h, 6, 2), 0.75, snow: snowy);
    }
    if (!dn) {
      // Boulders at the foot, dark contact line.
      for (var k = 0; k < 1 + h % 2; k++) {
        final x = px + 1 + _b(h, 12 + k * 5, 11), y = py + 12.0;
        _rect(c, shaded, x, y, 4, 2);
        _rect(c, lit, x, y, 3, 1);
        _rect(c, hi, x, y, 1, 1);
        _rect(c, deep, x, y + 2, 4, 1);
      }
      _rect(c, deep, px, py + 15, _ts, 1);
    }
  }

  /// Tilled soil: clods with a lit top and a dark underside.
  void _soilDetail(Canvas c, double px, double py, int h) {
    final r = TerrainRamp.of(FarmPalette.soil, FarmPalette.soilDark);
    _rect(c, r.base, px, py, _ts, _ts);
    for (var k = 0; k < 3 + h % 2; k++) {
      final x = px + 1 + _b(h, 2 + k * 4, 12),
          y = py + 1 + _b(h, 6 + k * 4, 13);
      _rect(c, r.deep, x, y + 1, 3, 1);
      _rect(c, Color.lerp(r.base, const Color(0xFFFFFFFF), 0.12)!, x, y, 2, 1);
    }
    if (h % 4 == 1) _rect(c, r.mid, px + 9, py + 11, 3, 1);
  }
}
