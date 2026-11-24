import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/bait_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Cebos (docs/specs/fishing.md § 14).
void main() {
  PlayerProfile withBaits(Map<String, int> b, {int credits = 0}) {
    final p = newProfile('Ana', 'guerrero');
    var life = p.life;
    b.forEach((id, n) => life = life.addBait(id, n));
    return p.copyWith(life: life, credits: credits);
  }

  test('catalog: five baits, all with tuning numbers', () {
    expect(kBaits.keys, containsAll(
        ['lombriz', 'larva_brillante', 'cebo_escarcha', 'cebo_tormenta',
         'senuelo_eco']));
    for (final id in kBaits.keys) {
      expect(BaitRules.price(id), greaterThan(0), reason: id);
    }
  });

  test('consume spends one and never goes below zero', () {
    var p = withBaits({'lombriz': 2});
    p = BaitRules.consume(p, 'lombriz');
    expect(p.life.baitCount('lombriz'), 1);
    p = BaitRules.consume(BaitRules.consume(p, 'lombriz'), 'lombriz');
    expect(p.life.baitCount('lombriz'), 0);
  });

  test('active: the picked one, else the best owned; cycle and select', () {
    var p = withBaits({'lombriz': 3, 'senuelo_eco': 1});
    expect(BaitRules.active(p), 'senuelo_eco');
    p = BaitRules.select(p, 'lombriz')!;
    expect(BaitRules.active(p), 'lombriz');
    p = BaitRules.cycle(p)!;
    expect(BaitRules.active(p), 'senuelo_eco');
    expect(BaitRules.active(newProfile('Ana', 'guerrero')), isNull);
  });

  test('buy costs gold; not enough gold is refused', () {
    final price = BaitRules.price('lombriz');
    expect(BaitRules.buy(withBaits({}, credits: price - 1), 'lombriz'), isNull);
    final p = BaitRules.buy(withBaits({}, credits: price * 5), 'lombriz', 5)!;
    expect(p.life.baitCount('lombriz'), 5);
    expect(p.credits, 0);
  });

  test('affinity shifts the roll toward the attracted fish', () {
    final table = ['mojarra_claro', 'pez_bruma'];
    expect(BaitRules.attracts('larva_brillante', 'pez_bruma'), isTrue);
    expect(BaitRules.attracts('larva_brillante', 'mojarra_claro'), isFalse);
    final w = BaitRules.weighted(table, 'larva_brillante');
    final share = w.where((f) => f == 'pez_bruma').length / w.length;
    expect(share, greaterThan(0.5));
    expect(BaitRules.weighted(table, null), table);
  });

  test('size bonus pushes the size up', () {
    var i = 0;
    final rolls = [0.0, 0.0, 0.0];
    double rand() => rolls[i++ % rolls.length];
    final lake = ['mojarra_claro'];
    final plain = FishingRules.roll(rand, lake);
    i = 0;
    final big = FishingRules.roll(rand, lake, sizeBonus: 1);
    expect(big.sizeCm, greaterThan(plain.sizeCm));
    expect(big.sizeCm, kFish['mojarra_claro']!.maxCm);
  });

  test('bestFor names a bait for fog and storm fish', () {
    expect(BaitRules.bestFor('pez_bruma'), isNotNull);
    expect(BaitRules.bestFor('raya_relampago'), 'cebo_tormenta');
  });

  test('foundBait (mines / water loot hook) is a known bait', () {
    for (final r in [0.0, 0.3, 0.7, 0.99]) {
      expect(kBaits.containsKey(BaitRules.foundBait(r)), isTrue);
    }
  });

  test('JSON round trip keeps baits and the pick', () {
    final p = BaitRules.select(withBaits({'lombriz': 4, 'cebo_escarcha': 2}),
        'cebo_escarcha')!;
    final back = PlayerProfile.fromJson(p.toJson());
    expect(back.life.baitCount('lombriz'), 4);
    expect(BaitRules.active(back), 'cebo_escarcha');
  });
}
