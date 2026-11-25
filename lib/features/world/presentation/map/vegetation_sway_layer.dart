import 'dart:ui';

import '../../../../core/procedural/vegetation_atlas.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/procedural/vegetation.dart';
import '../../../../game_engine/rules/region_ambience_rules.dart';
import 'map_themes.dart';
import 'tile_painter.dart';

/// Wind sway of grass, forage bushes and tree canopies
/// (docs/specs/biome_regions.md § 7.2.2). The tiles stay in the static
/// cache; this draws, over a fixed subset of the visible vegetation
/// tiles, a small tuft / canopy highlight shifted by
/// [RegionAmbienceRules.sway]. Cheap: one rect or two per swaying tile,
/// fixed paints, nothing allocated per frame.
class VegetationSwayLayer {
  static const ts = 16.0;

  final Paint _tuft = Paint()
    ..color = RegionPalette.swayTuft
    ..isAntiAlias = false;
  final Paint _leaf = Paint()
    ..color = RegionPalette.swayLeaf
    ..isAntiAlias = false;

  final Paint _veg = Paint()..isAntiAlias = false;

  /// Procedural vegetation (procedural_vegetation.md § 4.2): with it,
  /// a tree / bush shifts its own top leaf cluster instead of the generic
  /// canopy highlight. A PNG override does not sway.
  VegetationAtlas? vegetation;

  /// Tiles drawn last frame (perf test / debug).
  int lastDrawn = 0;

  void draw(Canvas c, GameMap map, int x0, int y0, int x1, int y1, double t,
      {bool motion = true, String? themeId}) {
    lastDrawn = 0;
    if (!motion) return;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final ch = map.tileAt(x, y);
        final grass = ch == Tile.grass;
        final tree = ch == Tile.tree;
        final bush = ch == Tile.forage;
        if (!grass && !tree && !bush) continue;
        if (!RegionAmbienceRules.swaysAt(x, y)) continue;
        final dx = RegionAmbienceRules.sway(x, y, t);
        final px = x * ts, py = y * ts;
        final h = (x * 31 + y * 17) & 7;
        if (grass) {
          // A two-pixel blade whose tip leans with the wind.
          c.drawRect(Rect.fromLTWH(px + 4 + h, py + 9, 1, 3), _tuft);
          c.drawRect(Rect.fromLTWH(px + 4 + h + dx, py + 7, 1, 2), _tuft);
        } else if (_procedural(c, tree, themeId, x, y, px, py, dx)) {
          // Drawn from the sprite's own sway cluster.
        } else if (tree) {
          c.drawRect(Rect.fromLTWH(px + 3 + dx, py + 1, 9, 6), _leaf);
        } else {
          c.drawRect(Rect.fromLTWH(px + 4 + dx, py + 4, 8, 3), _leaf);
        }
        lastDrawn++;
      }
    }
  }

  bool _procedural(Canvas c, bool tree, String? themeId, int x, int y,
      double px, double py, double dx) {
    final atlas = vegetation;
    if (atlas == null || themeId == null) return false;
    final h = TilePainter.tileHash(x, y);
    final biome = atlas.doc.biomeOf(themeId);
    if (biome == null) return false;
    VegetationSprite? sp;
    if (tree) {
      final pick = VegetationDoc.pickTree(biome, h);
      if (pick == null) return false;
      if (atlas.isOverridden(biome.id, pick.$1)) return true;
      sp = atlas.sprite(biome.id, pick.$1, pick.$2);
    } else {
      if (atlas.isOverridden(biome.id, VegetationSpecies.bush)) return true;
      sp = atlas.sprite(biome.id, VegetationSpecies.bush, (h >> 9) % 8);
    }
    if (sp == null) return false;
    _veg.color = Color(0xFF000000 | biome.palette.of(VegSlot.light));
    final ox = px + ((ts - sp.width) / 2).floorToDouble() + dx;
    final oy = py + ts - sp.height;
    for (final (sx, sy) in sp.sway) {
      c.drawRect(Rect.fromLTWH(ox + sx, oy + sy, 1, 1), _veg);
    }
    return true;
  }
}
