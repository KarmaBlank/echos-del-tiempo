import 'dart:math' as math;
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

/// Procedural vegetation (docs/specs/procedural_vegetation.md): trees and
/// bushes drawn as minimalist pixel art from a seed, a species, a few
/// shape knobs and a small per-biome palette. Pure Dart and
/// deterministic: the same [VegetationParams] always give the same
/// pixels. The data lives in `assets/sprites/vegetation_presets.yaml`,
/// which only `SpriteCatalog` reads.

/// Species a biome can grow.
enum VegetationSpecies { deciduous, conifer, dead, bush }

/// Palette slots: every opaque pixel of a generated sprite is one of these.
abstract final class VegSlot {
  static const none = 0, outline = 1, dark = 2, mid = 3, light = 4;
  static const trunk = 5, trunkDark = 6;
  static const count = 7;
}

/// Six colours (`0xRRGGBB`) of a biome, in [VegSlot] order from
/// [VegSlot.outline].
class VegetationPalette {
  const VegetationPalette(this.colors);
  final List<int> colors;

  /// Colour of [slot] (`0` for [VegSlot.none]).
  int of(int slot) => slot <= 0 ? 0 : colors[slot - 1];

  static const fallback = VegetationPalette(
      [0x14101e, 0x24502c, 0x3a7a3a, 0x5fa84a, 0x5a3a20, 0x3a2414]);
}

/// Shape knobs of one generated sprite.
class VegetationParams {
  const VegetationParams({
    required this.species,
    this.seed = 1,
    this.width = 16,
    this.height = 16,
    this.density = 0.6,
    this.trunk = 0.4,
    this.outline = true,
  });

  final VegetationSpecies species;
  final int seed, width, height;

  /// Leaf mass: clusters, tiers or (dead tree) branches. `0..1`.
  final double density;

  /// Trunk height share. `0..1`.
  final double trunk;

  /// Dark one-pixel silhouette outline.
  final bool outline;

  VegetationParams copyWith({
    VegetationSpecies? species,
    int? seed,
    int? width,
    int? height,
    double? density,
    double? trunk,
    bool? outline,
  }) =>
      VegetationParams(
        species: species ?? this.species,
        seed: seed ?? this.seed,
        width: width ?? this.width,
        height: height ?? this.height,
        density: density ?? this.density,
        trunk: trunk ?? this.trunk,
        outline: outline ?? this.outline,
      );
}

/// A generated sprite: palette indices ([VegSlot]) per pixel plus the
/// leaf pixels that the wind sway shifts (one top cluster).
class VegetationSprite {
  VegetationSprite(this.width, this.height, this.slots, this.sway);
  final int width, height;
  final Uint8List slots;

  /// `(x, y)` of the sway cluster's highlight pixels.
  final List<(int, int)> sway;

  int slotAt(int x, int y) => slots[y * width + x];

  /// Straight-alpha RGBA8888 bytes with [palette].
  Uint8List rgba(VegetationPalette palette) {
    final out = Uint8List(width * height * 4);
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s == VegSlot.none) continue;
      final c = palette.of(s);
      out[i * 4] = (c >> 16) & 0xff;
      out[i * 4 + 1] = (c >> 8) & 0xff;
      out[i * 4 + 2] = c & 0xff;
      out[i * 4 + 3] = 255;
    }
    return out;
  }
}

/// Small deterministic RNG (splitmix-style, 32 bits).
class VegRng {
  VegRng(int seed) : _s = (seed * 0x2545f491 + 0x6d2b79f5) & 0xffffffff;
  int _s;

  int next() {
    _s = (_s + 0x9e3779b9) & 0xffffffff;
    var z = _s;
    z = ((z ^ (z >> 16)) * 0x85ebca6b) & 0xffffffff;
    z = ((z ^ (z >> 13)) * 0xc2b2ae35) & 0xffffffff;
    return (z ^ (z >> 16)) & 0xffffffff;
  }

  int below(int n) => n <= 0 ? 0 : next() % n;
  double unit() => next() / 0x100000000;
}

/// Generates [VegetationSprite]s. Stateless; see the spec § 3.
abstract final class VegetationGenerator {
  static VegetationSprite generate(VegetationParams p) {
    final w = p.width.clamp(8, 16), h = p.height.clamp(8, 16);
    final g = Uint8List(w * h);
    final r = VegRng(p.seed ^ (p.species.index * 0x9e37));
    final sway = <(int, int)>[];
    void put(int x, int y, int s) {
      if (x >= 0 && y >= 0 && x < w && y < h) g[y * w + x] = s;
    }

    int at(int x, int y) =>
        x < 0 || y < 0 || x >= w || y >= h ? VegSlot.none : g[y * w + x];
    final density = p.density.clamp(0.0, 1.0);
    final cx = w ~/ 2;

    void trunk(int top, int width) {
      final x0 = cx - width ~/ 2;
      for (var y = top; y < h; y++) {
        for (var x = x0; x < x0 + width; x++) {
          put(x, y, x == x0 + width - 1 ? VegSlot.trunkDark : VegSlot.trunk);
        }
      }
    }

    // A pixel disc of leaves with a lit top-left and a dark bottom-right.
    void blob(int bx, int by, int rad, {bool record = false}) {
      for (var y = -rad; y <= rad; y++) {
        for (var x = -rad; x <= rad; x++) {
          if (x * x + y * y > rad * rad + rad) continue;
          final d = x + y;
          final s = d >= rad
              ? VegSlot.dark
              : d <= -rad
                  ? VegSlot.light
                  : VegSlot.mid;
          final cur = at(bx + x, by + y);
          if (cur == VegSlot.light && s != VegSlot.light) continue;
          put(bx + x, by + y, s);
          if (record && s == VegSlot.light) sway.add((bx + x, by + y));
        }
      }
    }

    switch (p.species) {
      case VegetationSpecies.deciduous:
        final th = (h * (0.2 + 0.25 * p.trunk.clamp(0.0, 1.0))).round();
        trunk(h - th - 1, w >= 14 ? 2 : 1);
        final crown = h - th - 1;
        final rad = math.max(3, (w * 0.25).round());
        final n = 2 + (density * 3).round();
        for (var i = 0; i < n; i++) {
          final ox = r.below(math.max(1, w - rad * 2 - 1)) + rad + 1 - cx;
          final oy = -r.below(math.max(1, crown - rad * 2));
          blob(cx + ox, crown - rad + oy ~/ 2 + 1, rad - r.below(2));
        }
        // The top cluster is the one that sways.
        blob(cx - 1 + r.below(3), math.max(rad, crown - rad * 2 + 1),
            math.max(2, rad - 1), record: true);
      case VegetationSpecies.conifer:
        final th = math.max(1, (h * 0.15 * (0.5 + p.trunk)).round());
        trunk(h - th - 1, w >= 14 ? 2 : 1);
        final tiers = 2 + (density * 2).round();
        final base = h - th - 1;
        final tierH = math.max(3, (base - 1) ~/ tiers + 1);
        for (var t = 0; t < tiers; t++) {
          final bottom = base - t * (tierH - 1);
          final half = math.max(1, ((w ~/ 2 - 1) * (tiers - t) / tiers).round());
          for (var y = 0; y < tierH; y++) {
            final span = (half * y / (tierH - 1)).round();
            final yy = bottom - tierH + 1 + y;
            for (var x = -span; x <= span; x++) {
              final s = x >= span - 1 && y >= tierH - 2
                  ? VegSlot.dark
                  : x < 0 && y < tierH - 1
                      ? VegSlot.light
                      : VegSlot.mid;
              put(cx + x, yy, s);
              if (t == tiers - 1 && s == VegSlot.light) sway.add((cx + x, yy));
            }
          }
        }
      case VegetationSpecies.dead:
        final top = (h * (0.35 - 0.2 * p.trunk.clamp(0.0, 1.0))).round();
        trunk(top, w >= 14 ? 2 : 1);
        final branches = 2 + (density * 3).round();
        for (var b = 0; b < branches; b++) {
          final dir = b.isEven ? -1 : 1;
          var x = cx + (dir > 0 ? 1 : -1) * (w >= 14 ? 1 : 0);
          var y = top + 1 + r.below(math.max(1, (h - top) ~/ 2));
          final len = 2 + r.below(math.max(1, w ~/ 3));
          for (var k = 0; k < len; k++) {
            x += dir;
            if (r.below(2) == 0) y--;
            put(x, y, VegSlot.trunk);
          }
          if (density > 0.5 && r.below(2) == 0) put(x, y - 1, VegSlot.light);
        }
      case VegetationSpecies.bush:
        final rad = math.max(2, (w * 0.22).round());
        final n = 2 + (density * 2).round();
        final ground = h - 2;
        for (var i = 0; i < n; i++) {
          final ox = (i - (n - 1) / 2) * rad * 0.9;
          blob(cx + ox.round(), ground - rad + 1 - r.below(2), rad);
        }
        blob(cx - 1 + r.below(3), ground - rad * 2 + 2, math.max(2, rad - 1),
            record: true);
    }

    if (p.outline) {
      final copy = Uint8List.fromList(g);
      int was(int x, int y) =>
          x < 0 || y < 0 || x >= w || y >= h ? VegSlot.none : copy[y * w + x];
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (was(x, y) != VegSlot.none) continue;
          if (was(x - 1, y) != 0 ||
              was(x + 1, y) != 0 ||
              was(x, y - 1) != 0 ||
              was(x, y + 1) != 0) {
            put(x, y, VegSlot.outline);
          }
        }
      }
    }
    sway.removeWhere((e) => at(e.$1, e.$2) != VegSlot.light);
    return VegetationSprite(w, h, g, List.unmodifiable(sway));
  }
}

/// One species preset of a biome.
class VegetationPreset {
  const VegetationPreset({
    this.weight = 1,
    this.seed = 1,
    this.variants = 3,
    this.width = 16,
    this.height = 16,
    this.density = 0.6,
    this.trunk = 0.4,
    this.outline = true,
  });
  final int weight, seed, variants, width, height;
  final double density, trunk;
  final bool outline;

  VegetationParams params(VegetationSpecies s, int variant) =>
      VegetationParams(
          species: s,
          seed: seed + variant * 7919,
          width: width,
          height: height,
          density: density,
          trunk: trunk,
          outline: outline);

  VegetationPreset copyWith(
          {int? weight,
          int? seed,
          int? variants,
          int? width,
          int? height,
          double? density,
          double? trunk,
          bool? outline}) =>
      VegetationPreset(
          weight: weight ?? this.weight,
          seed: seed ?? this.seed,
          variants: variants ?? this.variants,
          width: width ?? this.width,
          height: height ?? this.height,
          density: density ?? this.density,
          trunk: trunk ?? this.trunk,
          outline: outline ?? this.outline);

  static VegetationPreset fromYaml(Object? v) {
    if (v is! Map) return const VegetationPreset();
    int i(String k, int d) => (v[k] as num?)?.toInt() ?? d;
    double n(String k, double d) => (v[k] as num?)?.toDouble() ?? d;
    final size = v['size'];
    return VegetationPreset(
      weight: i('weight', 1).clamp(0, 100),
      seed: i('seed', 1),
      variants: i('variants', 3).clamp(1, 8),
      width: size is List && size.length == 2
          ? (size[0] as num).toInt().clamp(8, 16)
          : 16,
      height: size is List && size.length == 2
          ? (size[1] as num).toInt().clamp(8, 16)
          : 16,
      density: n('density', 0.6).clamp(0.0, 1.0),
      trunk: n('trunk', 0.4).clamp(0.0, 1.0),
      outline: v['outline'] as bool? ?? true,
    );
  }
}

/// A biome: palette plus its species presets.
class VegetationBiome {
  VegetationBiome(this.id, this.palette, this.species);
  final String id;
  VegetationPalette palette;
  final Map<VegetationSpecies, VegetationPreset> species;

  /// Tree species (not [VegetationSpecies.bush]) that this biome grows,
  /// repeated by weight, in enum order.
  List<VegetationSpecies> get treePool => [
        for (final s in VegetationSpecies.values)
          if (s != VegetationSpecies.bush)
            for (var k = 0; k < (species[s]?.weight ?? 0); k++) s,
      ];
}

/// `vegetation_presets.yaml`: biomes, palettes, presets and which map
/// themes use which biome.
class VegetationDoc {
  VegetationDoc({Map<String, VegetationBiome>? biomes, Map<String, String>? themes})
      : biomes = biomes ?? {},
        themes = themes ?? {};

  final Map<String, VegetationBiome> biomes;

  /// Map theme id → biome id.
  final Map<String, String> themes;

  /// Biome of [themeId], or `null` (the painter keeps its old drawing).
  VegetationBiome? biomeOf(String themeId) => biomes[themes[themeId]];

  /// Manifest key of the PNG override of [biome]/[s]
  /// (`tiles.<key>.idle`).
  static String spriteKey(String biome, VegetationSpecies s) =>
      'veg_${biome}_${s.name}';

  static int parseHex(String s) =>
      int.parse(s.replaceFirst('#', ''), radix: 16) & 0xffffff;
  static String hex(int c) =>
      '#${(c & 0xffffff).toRadixString(16).padLeft(6, '0')}';

  static VegetationDoc parse(String? raw) {
    final doc = VegetationDoc();
    if (raw == null || raw.trim().isEmpty) return doc;
    final y = loadYaml(raw);
    if (y is! Map) return doc;
    final themes = y['themes'];
    if (themes is Map) {
      for (final MapEntry(:key, :value) in themes.entries) {
        doc.themes['$key'] = '$value';
      }
    }
    final biomes = y['biomes'];
    if (biomes is Map) {
      for (final MapEntry(:key, :value) in biomes.entries) {
        if (value is! Map) continue;
        final pal = value['palette'];
        final palette = pal is List && pal.length == 6
            ? VegetationPalette([for (final c in pal) parseHex('$c')])
            : VegetationPalette.fallback;
        final sp = <VegetationSpecies, VegetationPreset>{};
        final raw = value['species'];
        if (raw is Map) {
          for (final s in VegetationSpecies.values) {
            if (raw.containsKey(s.name)) {
              sp[s] = VegetationPreset.fromYaml(raw[s.name]);
            }
          }
        }
        doc.biomes['$key'] = VegetationBiome('$key', palette, sp);
      }
    }
    return doc;
  }

  String encode() {
    final b = StringBuffer()
      ..writeln('# Procedural trees and bushes '
          '(docs/specs/procedural_vegetation.md).')
      ..writeln('# Edited from the Editor: VISUALES > VEGETACION.')
      ..writeln('themes:');
    for (final MapEntry(:key, :value) in themes.entries) {
      b.writeln('  $key: $value');
    }
    b.writeln('biomes:');
    for (final bi in biomes.values) {
      b
        ..writeln('  ${bi.id}:')
        ..writeln("    palette: [${bi.palette.colors.map((c) => "'${hex(c)}'").join(', ')}]")
        ..writeln('    species:');
      for (final MapEntry(:key, :value) in bi.species.entries) {
        b.writeln('      ${key.name}: { weight: ${value.weight}, '
            'seed: ${value.seed}, variants: ${value.variants}, '
            'size: [${value.width}, ${value.height}], '
            'density: ${value.density.toStringAsFixed(2)}, '
            'trunk: ${value.trunk.toStringAsFixed(2)}, '
            'outline: ${value.outline} }');
      }
    }
    return b.toString();
  }

  /// Sprite index for the tile with hash [h]: which tree species of
  /// [biome] and which variant. `null` if the biome grows no trees.
  static (VegetationSpecies, int)? pickTree(VegetationBiome biome, int h) {
    final pool = biome.treePool;
    if (pool.isEmpty) return null;
    final s = pool[(h >> 3) % pool.length];
    final n = biome.species[s]!.variants;
    return (s, (h >> 9) % n);
  }
}
