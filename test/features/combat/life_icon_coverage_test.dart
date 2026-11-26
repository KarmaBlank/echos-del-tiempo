import 'dart:io';

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/game_engine/data/bait_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/cooking_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Every shop/bag item resolves to its own sprite (never the generic
/// category icon or an empty cell): seeds, crops, fish, rods, hoes, cans,
/// fertilizers, meals, baits, trade materials and smithing materials
/// (also through the `mat_<id>` cells of the shared material bag).
void main() {
  final items = (loadYaml(
          File('assets/sprites/sprite_manifest.yaml').readAsStringSync())
      as YamlMap)['items'] as YamlMap;

  String? fileFor(String iconId) {
    for (final k in GameSprites.lifeIconKeys(iconId)) {
      final e = items['vida_$k'];
      if (e is YamlMap && e['idle'] is String) return e['idle'] as String;
    }
    return null;
  }

  final ids = <String>[
    for (final c in kCrops.keys) ...['semilla_$c', 'cosecha_$c'],
    ...kFish.keys,
    ...kRods.keys,
    ...kFarmTools.keys,
    ...kFertilizers.keys,
    for (final m in kMeals.keys) 'comida_$m',
    for (final b in kBaits.keys) 'cebo_$b',
    for (final m in kLifeMaterialIds) 'mat_$m',
    // Fish parts (fp_*) draw their fish's icon (profession_gear_v2.md § 4).
    ...kSmithMaterials.keys
        .where((m) => !m.startsWith('fp_') && !m.startsWith('ap_')),
    for (final m in kSmithMaterials.keys)
      if (!m.startsWith('fp_') && !m.startsWith('ap_')) 'mat_$m',
    // Animal parts draw one sprite per species and part (animals.md § 9).
    for (final m in kSmithMaterials.keys)
      if (m.startsWith('ap_')) m.substring(0, m.lastIndexOf('_')),
  ];

  test('every catalog item icon maps to an existing PNG', () {
    final missing = <String>[];
    for (final id in ids) {
      final f = fileFor(id);
      if (f == null || !File('assets/sprites/$f').existsSync()) missing.add(id);
    }
    expect(missing, isEmpty);
  });
}
