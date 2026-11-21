import 'dart:convert';

import 'package:echos_del_tiempo/features/admin/domain/admin_index.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_patch.dart';
import 'package:echos_del_tiempo/game_engine/balance/balance_registries.dart';
import 'package:echos_del_tiempo/game_engine/data/achievements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/items_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/ult_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parsea e instala un parche con [overrides]; devuelve su hash.
String _install(Map<String, Object?> overrides) {
  final r = BalancePatch.parse(
      jsonEncode({'schema': 1, 'basedOn': 't', 'overrides': overrides}),
      BalanceBase.standard());
  expect(r.issues.where((i) => i.error), isEmpty, reason: '${r.issues}');
  expect(r.patch.isEmpty, isFalse);
  r.patch.installRegistries();
  return r.patch.hash;
}

void main() {
  tearDown(BalanceRegistries.restore);

  final cases = <String, (Map<String, Object?>, Object? Function())>{
    'ultLevel': ({'perLevel': 0.1}, () => UltRules.levelFactor(5)),
    'ultUpgrade': ({'credits': 50}, () => UltRules.upgradeCost('ult2_ecoFilo', 2)!.credits),
    'ultCharge': ({'enemyPerTurn': 40}, () => BattleEngine.enemyUltPerTurn),
    'condense': ({'cristalCost': 5}, () => CraftRules.condenseRecipe(CraftMaterial.cristal)!.$2),
    'materials': ({'chancePrisma': 0.05, 'upRaroPrismas': 2},
        () => '${LootRules.materialChance[CraftMaterial.prisma]} ${CraftRules.upgradeRarityCost(Rarity.raro)}'),
    'ecoTier': ({'tierQuantity': 0.05}, () => EcoRules.tierQuantity),
    'consumables': ({'aetherMult': 6}, () => kItems[BattleItem.aether]!.price),
  };
  for (final e in cases.entries) {
    test('Ajustes ${e.key}: se parchea, el motor lo lee y se revierte', () {
      final read = e.value.$2;
      final before = read();
      final hash = _install({e.key: {e.key: e.value.$1}});
      expect(hash, isNot(kBaseBalanceHash));
      expect(read(), isNot(before));
      BalanceRegistries.restore();
      expect(read(), before);
    });
  }

  test('recompensa de hazaña: se parchea y se revierte', () {
    final def = kAchievements.first;
    final before = def.reward.credits;
    _install({
      'featReward': {
        def.id: {'credits': before + 777},
      },
    });
    expect(def.reward.credits, before + 777);
    BalanceRegistries.restore();
    expect(def.reward.credits, before);
  });

  test('los Ajustes y las hazañas están en el índice de Balance', () {
    final idx = buildAdminIndex(BalanceBase.standard());
    final kinds = idx.map((e) => e.kind).toSet();
    for (final k in [...kTuningKinds, BalanceKind.featReward]) {
      expect(kinds, contains(k));
    }
  });

  test('un ultCost viejo en el parche se ignora con aviso', () {
    final r = BalancePatch.parse(
        jsonEncode({
          'schema': 1,
          'overrides': {
            'ultimate': {
              'ult2_bucleBreve': {'ultCost': 60},
            },
          },
        }),
        BalanceBase.standard());
    expect(r.issues.where((i) => i.error), isEmpty);
    expect(r.issues, isNotEmpty);
    expect(r.patch.isEmpty, isTrue);
  });
}
