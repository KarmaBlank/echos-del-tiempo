import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// overworld_biomes.md § 9.1.1: what a resident sells depends on its trade.
BiomeNpcDef _npc(String id) => kBiomeNpcs.firstWhere((n) => n.id == id);

void main() {
  test('el forjador vende materiales según la relación; los demás semillas',
      () {
    final brann = _npc('brann');
    final low = ResidentRules.stock(brann, 0);
    expect(low.keys, containsAll(['ingot_copper', 'mine_torch']));
    expect(low.containsKey('ingot_frost'), isFalse);
    // Seeds stay.
    expect(low.keys.any((k) => brann.seeds.containsKey(k)), isTrue);
    final high = ResidentRules.stock(brann, 3);
    expect(
        high.keys, containsAll(['ingot_bronze', 'ingot_frost', 'ingot_ember']));
    // Home biome: its own ore regardless of tier.
    expect(ResidentRules.stock(brann, 0, home: true).containsKey('ore_ember'),
        isTrue);
    for (final id in ['ilda', 'velda', 'kael', 'oren']) {
      final s = ResidentRules.stock(_npc(id), 5);
      expect(s.keys.every((k) => !kSmithMaterials.containsKey(k)), isTrue,
          reason: id);
    }
  });

  test('un lingote cuesta más que lo que paga el comerciante', () {
    final markup = ResidentRules.t.d('resWareMarkup');
    expect(ResidentRules.warePrice('ingot_copper'),
        (SmithCraftRules.sellPrice('ingot_copper') * markup).ceil());
    expect(ResidentRules.warePrice('ingot_copper'),
        greaterThan(SmithCraftRules.sellPrice('ingot_copper')));
    expect(
        ResidentRules.warePrice('mine_torch'), MiningRules.price('mine_torch'));
    expect(ResidentRules.warePrice('nabo_claro'), 0);
  });

  test('comprar un lingote a Brann en su bioma va a los materiales', () {
    final e = sessionEngine();
    final prof = PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 5000);
    var s = e.addPlayer(e.create(), 'p0', prof)!.state;
    s.place = kGrieta;
    final price = ResidentRules.warePrice('ingot_copper');
    s = act(e, s, 'p0',
        const FarmShopAction(FarmShopOp.buySeed, id: 'ingot_copper', n: 2));
    final p = s.players['p0']!.profile;
    expect(p.life.ore('ingot_copper'), 2);
    expect(p.credits, 5000 - price * 2);
    // Not in stock yet (relationship tier): rejected.
    expect(
        e.apply(s, 'p0',
            const FarmShopAction(FarmShopOp.buySeed, id: 'ingot_frost')),
        isNull);
  });
}
