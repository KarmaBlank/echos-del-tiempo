import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:echos_del_tiempo/game_engine/procedural/vegetation.dart';

void main() {
  final doc = VegetationDoc.parse(
      File('assets/sprites/vegetation_presets.yaml').readAsStringSync());

  test('the repo presets parse: biomes, palettes and theme mapping', () {
    expect(doc.biomes, isNotEmpty);
    for (final b in doc.biomes.values) {
      expect(b.palette.colors, hasLength(6), reason: b.id);
      expect(b.treePool, isNotEmpty, reason: b.id);
    }
    for (final biome in doc.themes.values) {
      expect(doc.biomes, contains(biome));
    }
  });

  test('the generator is deterministic by seed', () {
    for (final s in VegetationSpecies.values) {
      final p = VegetationParams(species: s, seed: 42);
      expect(VegetationGenerator.generate(p).slots,
          VegetationGenerator.generate(p).slots);
      expect(VegetationGenerator.generate(p).sway,
          VegetationGenerator.generate(p).sway);
    }
  });

  test('different seeds give different trees', () {
    final a = VegetationGenerator.generate(
        const VegetationParams(species: VegetationSpecies.deciduous, seed: 1));
    final b = VegetationGenerator.generate(
        const VegetationParams(species: VegetationSpecies.deciduous, seed: 2));
    expect(a.slots, isNot(b.slots));
  });

  test('every pixel stays within the biome palette (palette bounds)', () {
    for (final b in doc.biomes.values) {
      final allowed = {0, ...b.palette.colors};
      for (final MapEntry(key: s, value: p) in b.species.entries) {
        for (var v = 0; v < p.variants; v++) {
          final sp = VegetationGenerator.generate(p.params(s, v));
          expect(sp.slots.every((e) => e < VegSlot.count), isTrue);
          final px = sp.rgba(b.palette);
          for (var i = 0; i < px.length; i += 4) {
            if (px[i + 3] == 0) continue;
            final c = (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
            expect(allowed, contains(c), reason: '${b.id}/${s.name}');
          }
        }
      }
    }
  });

  test('sprites fit one tile and have a readable silhouette', () {
    for (final s in VegetationSpecies.values) {
      for (var seed = 0; seed < 20; seed++) {
        final sp = VegetationGenerator.generate(VegetationParams(
            species: s, seed: seed, width: 40, height: 40));
        expect(sp.width, lessThanOrEqualTo(16));
        expect(sp.height, lessThanOrEqualTo(16));
        final filled = sp.slots.where((e) => e != VegSlot.none).length;
        expect(filled, greaterThan(12), reason: '${s.name} $seed');
        // Minimalist: few colours.
        expect(sp.slots.toSet().length, lessThanOrEqualTo(VegSlot.count));
      }
    }
  });

  test('sway pixels are leaf highlights of trees with leaves', () {
    final sp = VegetationGenerator.generate(
        const VegetationParams(species: VegetationSpecies.deciduous, seed: 5));
    expect(sp.sway, isNotEmpty);
    for (final (x, y) in sp.sway) {
      expect(sp.slotAt(x, y), VegSlot.light);
    }
  });

  test('encode / parse round trip', () {
    final again = VegetationDoc.parse(doc.encode());
    expect(again.themes, doc.themes);
    for (final b in doc.biomes.values) {
      final o = again.biomes[b.id]!;
      expect(o.palette.colors, b.palette.colors);
      for (final MapEntry(key: s, value: p) in b.species.entries) {
        expect(o.species[s]!.seed, p.seed);
        expect(o.species[s]!.density, closeTo(p.density, 0.01));
      }
    }
  });

  test('pickTree only picks tree species the biome grows', () {
    final b = doc.biomes.values.first;
    for (var h = 0; h < 500; h++) {
      final (s, v) = VegetationDoc.pickTree(b, h * 7919)!;
      expect(s, isNot(VegetationSpecies.bush));
      expect(b.species, contains(s));
      expect(v, lessThan(b.species[s]!.variants));
    }
  });

  test('every biome species has a PNG override slot in the manifest', () {
    final manifest =
        File('assets/sprites/sprite_manifest.yaml').readAsStringSync();
    for (final b in doc.biomes.values) {
      for (final s in b.species.keys) {
        expect(manifest, contains('${VegetationDoc.spriteKey(b.id, s)}:'));
      }
    }
  });
}
