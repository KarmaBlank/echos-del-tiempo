part of 'tile_painter.dart';

/// Tiles the mine painter draws itself in `mina_*` themes
/// (mining_smithing.md § 1.2). Static: they go to the cached chunks.
const mineTiles = {
  Tile.wall,
  Tile.floor,
  Tile.ore,
  Tile.stairsUp,
  Tile.stairsDown,
  Tile.water,
  MineTile.bedrock,
  MineTile.rich,
  MineTile.deep,
  MineTile.gem,
  MineTile.crystal,
  MineTile.torch,
  MineTile.wallTorch,
  MineTile.chest,
  MineTile.relic,
  MineTile.chestOpen,
  MineTile.mushroom,
  MineTile.lore,
  MineTile.station,
};

extension _MineTiles on TilePainter {
  static bool _solidRock(String? c) =>
      c == null ||
      c == Tile.wall ||
      c == MineTile.bedrock ||
      MineTile.veins.contains(c) ||
      c == MineTile.crystal ||
      c == MineTile.wallTorch;

  /// Cave floor: two tones by hash, pebbles, darker next to the rock.
  void _caveFloor(double px, double py, int h, TileAt? at, int tx, int ty,
      Canvas c) {
    _rect(c, h % 4 == 0 ? MinePalette.caveFloor2 : MinePalette.caveFloor, px,
        py, TilePainter.ts, TilePainter.ts);
    if (h % 3 == 0) {
      _rect(c, MinePalette.rock, px + (h >> 3) % 12 + 1, py + (h >> 7) % 12 + 1,
          2, 1);
    }
    if (h % 7 == 1) {
      _rect(c, MinePalette.rockLight, px + (h >> 5) % 13, py + (h >> 9) % 13,
          1, 1);
    }
    // Ambient shade under the rock above.
    if (at != null && _solidRock(at(tx, ty - 1))) {
      _rect(c, MinePalette.rockDark, px, py, TilePainter.ts, 3);
    }
  }

  /// Natural rock with auto-tiled faces: a lit top lip where the rock
  /// meets open floor below, darker rims on the sides; three textures by
  /// hash.
  void _rockBlock(Canvas c, double px, double py, int h, TileAt? at, int tx,
      int ty, {bool bedrock = false}) {
    const ts = TilePainter.ts;
    final base = bedrock ? MinePalette.bedrock : MinePalette.rock;
    final light = bedrock ? MinePalette.bedrockLight : MinePalette.rockLight;
    _rect(c, base, px, py, ts, ts);
    // Texture: a few strata and chips per hash.
    switch (h % 3) {
      case 0:
        _rect(c, light, px + 2, py + 4, 5, 1);
        _rect(c, light, px + 9, py + 10, 4, 1);
      case 1:
        _rect(c, MinePalette.rockDark, px + 3, py + 8, 6, 2);
        _rect(c, light, px + 10, py + 3, 2, 2);
      default:
        _rect(c, light, px + 6, py + 6, 3, 1);
        _rect(c, MinePalette.rockDark, px + 11, py + 12, 3, 2);
    }
    if (at == null) return;
    bool open(int dx, int dy) => !_solidRock(at(tx + dx, ty + dy));
    // Front face toward the floor below: a lit lip and a darker face.
    if (open(0, 1)) {
      _rect(c, MinePalette.rockDark, px, py + ts - 5, ts, 5);
      _rect(c, light, px, py + ts - 6, ts, 1);
    }
    if (open(0, -1)) _rect(c, MinePalette.rockTop, px, py, ts, 2);
    if (open(-1, 0)) _rect(c, MinePalette.rockDark, px, py, 2, ts);
    if (open(1, 0)) _rect(c, MinePalette.rockDark, px + ts - 2, py, 2, ts);
  }

  bool _mineTile(Canvas c, String ch, String themeId, double px, double py,
      int tx, int ty, int h, TileAt? at) {
    const ts = TilePainter.ts;
    final vein = MinePalette.vein(themeId);
    switch (ch) {
      case Tile.floor:
        _caveFloor(px, py, h, at, tx, ty, c);
      case Tile.wall:
        _rockBlock(c, px, py, h, at, tx, ty);
      case MineTile.bedrock:
        _rockBlock(c, px, py, h, at, tx, ty, bedrock: true);
      case Tile.ore || MineTile.rich || MineTile.deep || MineTile.gem:
        _rockBlock(c, px, py, h, at, tx, ty);
        final col = switch (ch) {
          MineTile.gem => MinePalette.crystal,
          MineTile.deep => MinePalette.chestBand,
          _ => vein,
        };
        final n = ch == MineTile.rich ? 7 : 4;
        for (var k = 0; k < n; k++) {
          final fx = 2 + ((h >> (k * 3)) % 11), fy = 2 + ((h >> (k * 3 + 1)) % 9);
          _rect(c, col, px + fx, py + fy, 2, 2);
          _rect(c, MinePalette.spark.withValues(alpha: 0.5), px + fx, py + fy,
              1, 1);
        }
        if (ch == MineTile.gem) {
          _rect(c, MinePalette.crystal, px + 6, py + 4, 4, 6);
        }
      case MineTile.crystal:
        _rockBlock(c, px, py, h, at, tx, ty);
        _rect(c, MinePalette.crystal, px + 4, py + 5, 3, 8);
        _rect(c, MinePalette.crystal, px + 8, py + 2, 3, 11);
        _rect(c, MinePalette.label, px + 9, py + 3, 1, 4);
      case MineTile.torch:
        _caveFloor(px, py, h, at, tx, ty, c);
        _rect(c, MinePalette.timber, px + 7, py + 6, 2, 9);
        _rect(c, MinePalette.flame, px + 6, py + 3, 4, 4);
        _rect(c, MinePalette.spark, px + 7, py + 4, 2, 2);
      case MineTile.wallTorch:
        _rockBlock(c, px, py, h, at, tx, ty);
        _rect(c, MinePalette.timber, px + 7, py + 8, 2, 6);
        _rect(c, MinePalette.flame, px + 6, py + 5, 4, 4);
        _rect(c, MinePalette.spark, px + 7, py + 6, 2, 2);
      case MineTile.chest || MineTile.relic || MineTile.chestOpen:
        _caveFloor(px, py, h, at, tx, ty, c);
        final relic = ch == MineTile.relic;
        _rect(c, relic ? MinePalette.lore : MinePalette.chestWood, px + 2,
            py + 6, 12, 8);
        _rect(c, relic ? MinePalette.relic : MinePalette.chestBand, px + 2,
            py + 9, 12, 1);
        if (ch == MineTile.chestOpen) {
          _rect(c, MinePalette.cartDark, px + 3, py + 4, 10, 3);
        } else {
          _rect(c, relic ? MinePalette.relic : MinePalette.chestBand, px + 7,
              py + 8, 2, 3);
        }
      case MineTile.mushroom:
        _caveFloor(px, py, h, at, tx, ty, c);
        for (final (mx, my) in const [(3, 8), (9, 6), (7, 11)]) {
          _rect(c, MinePalette.label, px + mx + 1, py + my + 2, 1, 3);
          _rect(c, MinePalette.mushroom, px + mx, py + my, 3, 2);
        }
      case MineTile.lore:
        _caveFloor(px, py, h, at, tx, ty, c);
        _rect(c, MinePalette.lore, px + 3, py + 3, 10, 12);
        _rect(c, MinePalette.relic, px + 5, py + 6, 6, 1);
        _rect(c, MinePalette.relic, px + 5, py + 9, 4, 1);
      case MineTile.station:
        // Plain floor: the rails come from MineLayer.drawTrack.
        _caveFloor(px, py, h, at, tx, ty, c);
      case Tile.stairsUp:
        _caveFloor(px, py, h, at, tx, ty, c);
        _rect(c, MinePalette.spark.withValues(alpha: 0.25), px + 2, py, 12, ts);
        for (var k = 0; k < 4; k++) {
          _rect(c, MinePalette.timber, px + 3, py + 2 + k * 4, 10, 1);
        }
        _rect(c, MinePalette.timber, px + 3, py, 1, ts);
        _rect(c, MinePalette.timber, px + 12, py, 1, ts);
      case Tile.stairsDown:
        _caveFloor(px, py, h, at, tx, ty, c);
        _rect(c, MinePalette.mouth, px + 2, py + 2, 12, 12);
        _rect(c, MinePalette.timber, px + 2, py + 2, 12, 1);
        _rect(c, MinePalette.timber, px + 5, py + 3, 1, 10);
        _rect(c, MinePalette.timber, px + 10, py + 3, 1, 10);
      case Tile.water:
        _rect(c, const Color(0xFF1D3A55), px, py, ts, ts);
        _rect(c, const Color(0xFF2C5A80), px + (h % 8), py + 5, 5, 1);
        _rect(c, const Color(0xFF2C5A80), px + (h >> 4) % 8, py + 11, 4, 1);
      default:
        return false;
    }
    return true;
  }
}
