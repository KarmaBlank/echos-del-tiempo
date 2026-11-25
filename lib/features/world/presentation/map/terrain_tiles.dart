part of 'tile_painter.dart';

/// Four-step colour ramp of a terrain colour (tile_detail.md § 2): the
/// same deep / shade / base / mid / lit steps the cave palette spells out
/// by hand, derived from the theme colours so the theme stays the only
/// knob.
class TerrainRamp {
  TerrainRamp._(this.base, Color alt)
      : deep = Color.lerp(base, const Color(0xFF000000), 0.34)!,
        shade = Color.lerp(base, const Color(0xFF000000), 0.16)!,
        mid = alt,
        lit = Color.lerp(alt, const Color(0xFFFFFFFF), 0.22)!;

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

  /// Grass: base, a shaded patch, tufts with dark root and lit tip, lit
  /// specks, a rare flower; shade under the mountain, lip toward water.
  void _grassDetail(Canvas c, MapTheme th, double px, double py, int tx, int ty,
      int h, TileAt? at) {
    final r = TerrainRamp.of(th.grass, th.grass2);
    _rect(c, r.base, px, py, _ts, _ts);
    if (h % 3 == 0) {
      final x = px + _b(h, 2, 9), y = py + _b(h, 6, 9);
      _rect(c, r.shade, x, y + 1, 7, 4);
      _rect(c, r.shade, x + 1, y, 5, 6);
    }
    for (var k = 0; k < 2 + h % 2; k++) {
      final x = px + 1 + _b(h, 4 + k * 5, 12),
          y = py + 3 + _b(h, 8 + k * 5, 11);
      _rect(c, r.deep, x, y + 2, 3, 1);
      _rect(c, r.mid, x, y, 1, 2);
      _rect(c, r.mid, x + 2, y - 1, 1, 3);
      _rect(c, r.lit, x + 2, y - 1, 1, 1);
    }
    if (h % 7 == 2) {
      _rect(c, r.lit, px + _b(h, 12, 14), py + _b(h, 15, 14), 1, 1);
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

  /// Open ground: two tones, faceted pebbles, a crack, a lit speck.
  void _groundDetail(Canvas c, MapTheme th, double px, double py, int h) {
    final r = TerrainRamp.of(th.ground, th.ground2);
    _rect(c, r.base, px, py, _ts, _ts);
    if (h % 4 == 0) {
      _rect(c, r.shade, px + _b(h, 3, 10), py + _b(h, 7, 11), 6, 4);
    }
    for (var k = 0; k < 1 + h % 3; k++) {
      _pebble(c, r, px + 1 + _b(h, 5 + k * 4, 12),
          py + 1 + _b(h, 9 + k * 4, 13), 2 + (k % 2).toDouble());
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

  /// Mountain: a stepped pixel peak with a lit and a shaded face, strata,
  /// a crack, a shaded snow cap and a dark foot — the cave boulder's
  /// facets at peak scale.
  void _rockDetail(Canvas c, MapTheme th, double px, double py, int h) {
    final r = TerrainRamp.of(th.rock2, th.rock);
    final apex = px + 8 + (h % 3 - 1);
    for (var row = 0; row < 15; row++) {
      final half = ((row + 1) * 8 / 15).roundToDouble();
      // Clamped to the cell: the peak never leaves its 16 px.
      final l = math.max(apex - half, px);
      final rt = math.min(apex + half, px + _ts);
      _rect(c, r.base, l, py + row, apex - l, 1);
      _rect(c, th.rock, apex, py + row, rt - apex, 1);
      if (row % 3 == 2) _rect(c, r.lit, l, py + row, 1, 1);
    }
    _rect(c, r.deep, apex + 1, py + 8, 3, 1);
    _rect(c, r.shade, apex - 5, py + 11, 3, 1);
    if (h % 2 == 0) {
      _rect(c, r.deep, apex + 2, py + 5 + h % 3, 1, 3);
      _rect(c, r.deep, apex + 3, py + 8 + h % 3, 1, 2);
    }
    const snow = Color(0xFFE8F0FF), snowShade = Color(0xFFB8C4D8);
    _rect(c, snow, apex - 1, py, 2, 2);
    _rect(c, snow, apex - 2, py + 2, 3, 1);
    _rect(c, snowShade, apex + 1, py + 2, 1, 1);
    _rect(c, snowShade, apex - 3, py + 3, 1, 1);
    _rect(c, snowShade, apex + 1, py + 3, 1, 1);
    _rect(c, r.deep, px, py + 15, _ts, 1);
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
