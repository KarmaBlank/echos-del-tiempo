// Procedural vegetation atlas (docs/specs/procedural_vegetation.md § 4):
// cached images, PNG override precedence. With VEG_PREVIEW=1 writes
// docs/preview/trees_sheet.png (every biome × species × variant, 6×).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echos_del_tiempo/core/procedural/vegetation_atlas.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/game_engine/procedural/vegetation.dart';

void main() {
  final doc = VegetationDoc.parse(
      File('assets/sprites/vegetation_presets.yaml').readAsStringSync());

  testWidgets('generated images are built once and cached', (tester) async {
    await tester.runAsync(() async {
      var made = 0;
      final atlas = await VegetationAtlas.build(doc, toImage: (s, p) {
        made++;
        return SpriteCatalog.vegetationImage(s, p);
      });
      final expected = doc.biomes.values
          .expand((b) => b.species.values)
          .fold<int>(0, (a, p) => a + p.variants);
      expect(made, expected);
      for (var h = 0; h < 200; h++) {
        expect(atlas.tree('pradera', h * 104729), isNotNull);
      }
      expect(made, expected, reason: 'drawing never generates');
      expect(atlas.tree('no_such_theme', 1), isNull);
    });
  });

  testWidgets('a PNG override wins over the generator', (tester) async {
    await tester.runAsync(() async {
      final png = await SpriteCatalog.vegetationImage(
          VegetationGenerator.generate(
              const VegetationParams(species: VegetationSpecies.bush, width: 9, height: 9)),
          VegetationPalette.fallback);
      final key = VegetationDoc.spriteKey('meadow', VegetationSpecies.bush);
      final atlas = await VegetationAtlas.build(doc,
          override: (k) async => k == key ? png : null,
          toImage: SpriteCatalog.vegetationImage);
      expect(atlas.isOverridden('meadow', VegetationSpecies.bush), isTrue);
      expect(atlas.bush('pradera', 12345), same(png));
      expect(atlas.sprite('meadow', VegetationSpecies.bush, 0), isNull);
      // Others stay procedural.
      expect(atlas.isOverridden('meadow', VegetationSpecies.deciduous), isFalse);
      expect(atlas.image('meadow', VegetationSpecies.deciduous, 0)!.width, 16);
    });
  });

  testWidgets('preview sheet (VEG_PREVIEW=1)', (tester) async {
    if (Platform.environment['VEG_PREVIEW'] != '1') return;
    await tester.runAsync(() async {
      const k = 6.0, cell = 16 * k + 8;
      final biomes = doc.biomes.values.toList();
      const cols = 4 * 3;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final w = cols * cell + 8, h = biomes.length * cell + 8;
      c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF3F8A3E));
      for (var r = 0; r < biomes.length; r++) {
        final b = biomes[r];
        var col = 0;
        for (final s in VegetationSpecies.values) {
          final p = b.species[s];
          for (var v = 0; v < 3; v++, col++) {
            if (p == null || v >= p.variants) continue;
            final im = await SpriteCatalog.vegetationImage(
                VegetationGenerator.generate(p.params(s, v)), b.palette);
            c.drawImageRect(
                im,
                const Rect.fromLTWH(0, 0, 16, 16),
                Rect.fromLTWH(8 + col * cell, 8 + r * cell, 16 * k, 16 * k),
                Paint()..filterQuality = FilterQuality.none);
          }
        }
      }
      final out = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      File('docs/preview/trees_sheet.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
