import 'dart:ui' as ui;

import '../../game_engine/procedural/vegetation.dart';

/// Cached images of the procedural vegetation
/// (docs/specs/procedural_vegetation.md § 4): every biome × species ×
/// variant generated ONCE into a `ui.Image`, or the PNG override of that
/// species when there is one. The map never generates while drawing.
class VegetationAtlas {
  VegetationAtlas(this.doc);

  final VegetationDoc doc;
  final Map<String, List<ui.Image>> _images = {};
  final Map<String, List<VegetationSprite>> _sprites = {};
  final Set<String> _overridden = {};

  static String _key(String biome, VegetationSpecies s) => '$biome/${s.name}';

  /// Builds the atlas. [override] returns the PNG override image of a
  /// manifest key ([VegetationDoc.spriteKey]) or `null`; an override wins
  /// over the generator for every variant of that species.
  static Future<VegetationAtlas> build(VegetationDoc doc,
      {Future<ui.Image?> Function(String spriteKey)? override,
      required Future<ui.Image> Function(VegetationSprite, VegetationPalette)
          toImage}) async {
    final a = VegetationAtlas(doc);
    for (final b in doc.biomes.values) {
      for (final MapEntry(key: s, value: p) in b.species.entries) {
        final k = _key(b.id, s);
        ui.Image? png;
        try {
          png = await override?.call(VegetationDoc.spriteKey(b.id, s));
        } catch (_) {}
        if (png != null) {
          a._images[k] = [png];
          a._overridden.add(k);
          continue;
        }
        final sprites = [
          for (var v = 0; v < p.variants; v++)
            VegetationGenerator.generate(p.params(s, v)),
        ];
        a._sprites[k] = sprites;
        a._images[k] = [for (final sp in sprites) await toImage(sp, b.palette)];
      }
    }
    return a;
  }

  /// `true` if [biome]/[s] uses a PNG override.
  bool isOverridden(String biome, VegetationSpecies s) =>
      _overridden.contains(_key(biome, s));

  ui.Image? image(String biome, VegetationSpecies s, int variant) {
    final l = _images[_key(biome, s)];
    if (l == null || l.isEmpty) return null;
    return l[variant % l.length];
  }

  /// Generated sprite (sway pixels); `null` when overridden by a PNG.
  VegetationSprite? sprite(String biome, VegetationSpecies s, int variant) {
    final l = _sprites[_key(biome, s)];
    if (l == null || l.isEmpty) return null;
    return l[variant % l.length];
  }

  /// Tree image of the tile with hash [h] in [themeId], or `null`.
  (ui.Image, VegetationSprite?, VegetationBiome)? tree(String themeId, int h) {
    final b = doc.biomeOf(themeId);
    if (b == null) return null;
    final pick = VegetationDoc.pickTree(b, h);
    if (pick == null) return null;
    final im = image(b.id, pick.$1, pick.$2);
    if (im == null) return null;
    return (im, sprite(b.id, pick.$1, pick.$2), b);
  }

  /// Bush image of the tile with hash [h] in [themeId], or `null`.
  ui.Image? bush(String themeId, int h) {
    final b = doc.biomeOf(themeId);
    if (b == null || !b.species.containsKey(VegetationSpecies.bush)) return null;
    return image(b.id, VegetationSpecies.bush, (h >> 9) % 8);
  }
}
