import 'dart:io';

import 'package:echos_del_tiempo/features/admin/presentation/editor/vegetation_controller.dart';
import 'package:echos_del_tiempo/features/admin/presentation/editor/vegetation_page.dart';
import 'package:echos_del_tiempo/features/combat/domain/sprite_entry.dart';
import 'package:echos_del_tiempo/game_engine/procedural/vegetation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Store implements VegetationOverrideSource {
  String? saved;
  @override
  Future<String?> readVegetation() async => saved;
  @override
  Future<void> putVegetation(String yaml) async => saved = yaml;
}

VegetationDoc _doc() => VegetationDoc.parse(
    File('assets/sprites/vegetation_presets.yaml').readAsStringSync());

void main() {
  testWidgets('live preview, regenerate and save a preset', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = _Store();
    late VegetationController c;
    await tester.runAsync(() async {
      c = VegetationController(doc: _doc(), store: store);
      await c.refresh();
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VegetationPage(c: c))));
    expect(find.byKey(const ValueKey('veg-preview-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('veg-png-override')), findsNothing);

    final seed = c.preset.seed;
    final before = c.previews.first;
    await tester.tap(find.byKey(const ValueKey('veg-regenerate')));
    await tester.runAsync(() => c.refresh());
    await tester.pump();
    expect(c.preset.seed, isNot(seed));
    expect(c.previews.first, isNot(same(before)));
    expect(c.dirty, isTrue);

    await tester.tap(find.byKey(const ValueKey('veg-save')));
    await tester.runAsync(() async {});
    await tester.pump();
    final again = VegetationDoc.parse(store.saved);
    expect(again.biomes[c.biomeId]!.species[c.species]!.seed, c.preset.seed);
    expect(c.dirty, isFalse);
  });

  testWidgets('switching species and biome; PNG override is flagged',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late VegetationController c;
    await tester.runAsync(() async {
      c = VegetationController(
          doc: _doc(),
          hasOverride: (id) => id == 'tiles.veg_forest_conifer.idle');
      await c.refresh();
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VegetationPage(c: c))));
    c.selectBiome('forest');
    c.selectSpecies(VegetationSpecies.conifer);
    await tester.runAsync(() => c.refresh());
    await tester.pump();
    expect(find.byKey(const ValueKey('veg-png-override')), findsOneWidget);
    expect(c.previews, hasLength(c.preset.variants));
  });
}
