import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Forged weapon orders (docs/specs/mining_smithing.md § 2.2).
void main() {
  TuningDef t() => tuning(TuningId.smithing);

  String baseOf(String type) =>
      kWeapons.values.firstWhere((w) => w.type == type).id;

  ItemInstance forged(String uid, String type, Rarity r, int il) =>
      ItemInstance(
          uid: '${CraftRules.forgedPrefix}$uid',
          baseId: baseOf(type),
          rarity: r,
          itemLevel: il);

  /// First (npc, day) with a forged weapon order at Smithing [lv].
  (String, int, String, int) findOrder(int lv) {
    for (var day = 1; day < 400; day++) {
      for (final n in kBiomeNpcs) {
        if (ResidentRules.forgeOrder(n.id, day, lv) case (final o, final q)?) {
          return (n.id, day, o, q);
        }
      }
    }
    throw StateError('no forge order');
  }

  test('deterministic, gated by Smithing level, within the smith reach', () {
    final (npc, day, o, q) = findOrder(20);
    expect(ResidentRules.forgeOrder(npc, day, 20), (o, q));
    expect(ResidentRules.forgeOrder(npc, day, t().i('forgeOrderLevel') - 1),
        isNull);
    expect(ResidentRules.forgeOrder(npc, day, 0), isNull);
    final (type, il) = ResidentRules.parseForgeOrder(o)!;
    expect(ResidentRules.forgeTypes(), contains(type));
    expect(il, greaterThanOrEqualTo(1));
    expect(q, lessThanOrEqualTo(t().i('forgeOrderMaxRarity')));
    // At the gate level the rarity never exceeds what the smith forges.
    for (var d = 1; d < 300; d++) {
      for (final n in kBiomeNpcs) {
        final lv = t().i('forgeOrderLevel');
        if (ResidentRules.forgeOrder(n.id, d, lv) case (_, final q2)?) {
          expect(q2, lessThanOrEqualTo(1));
        }
      }
    }
  });

  test('newOrder: the forged weapon order comes before ingots and meals',
      () {
    final (npc, day, o, q) = findOrder(20);
    final r = ResidentRules.newOrder(ResidentState(npc), day,
        smithLv: 20, farmLv: 30);
    expect(r.order, o);
    expect(r.orderQ, q);
    expect(r.orderN, 1);
  });

  test('matches: forged, type, rarity, level; never the equipped one; '
      'the player picks which one to hand over', () {
    final id = ResidentRules.forgeOrderId('espada', 10);
    final a = forged('a', 'espada', Rarity.raro, 12);
    final b = forged('b', 'espada', Rarity.epico, 20);
    final eq = forged('eq', 'espada', Rarity.epico, 30);
    final low = forged('low', 'espada', Rarity.raro, 5);
    final axe = forged('axe', 'hacha', Rarity.epico, 30);
    final loot = ItemInstance(
        uid: 'loot1', baseId: baseOf('espada'), rarity: Rarity.epico,
        itemLevel: 30);
    var p = newProfile('Ana', 'guerrero');
    p = p.copyWith(
        items: [a, b, eq, low, axe, loot], equipped: eq.uid, credits: 0);
    expect(p.equippedUid, eq.uid);
    expect(
        ResidentRules.forgeOrderMatches(p, id, Rarity.raro.index)
            .map((i) => i.uid),
        [a.uid, b.uid]);
    expect(ResidentRules.orderHave(p, id, Rarity.epico.index), 1);

    var town = const TownState().withResident(ResidentState('ilda',
        order: id, orderN: 1, orderQ: Rarity.raro.index, orderDay: 1));
    expect(ResidentRules.deliverOrder(p, town, 'ilda', 999, pick: eq.uid),
        isNull,
        reason: 'equipped weapons are never consumed');
    expect(ResidentRules.deliverOrder(p, town, 'ilda', 999, pick: loot.uid),
        isNull);
    final r = ResidentRules.deliverOrder(p, town, 'ilda', 999, pick: b.uid)!;
    expect(r.$1.items.map((i) => i.uid), isNot(contains(b.uid)));
    expect(r.$1.items.map((i) => i.uid), contains(a.uid));
    expect(r.$1.equippedUid, eq.uid);
    expect(r.$1.credits, ResidentRules.orderReward(town.resident('ilda')).gold);
    expect(r.$2.resident('ilda').order, isNull);
    town = r.$2;
  });

  test('reward scales with the weapon value; journal names it', () {
    final id = ResidentRules.forgeOrderId('arco', 24);
    final lo = ResidentRules.orderReward(
        ResidentState('ilda', order: id, orderN: 1, orderQ: 0));
    final hi = ResidentRules.orderReward(
        ResidentState('ilda', order: id, orderN: 1, orderQ: 3));
    final small = ResidentRules.orderReward(ResidentState('ilda',
        order: ResidentRules.forgeOrderId('arco', 1), orderN: 1));
    expect(hi.gold, greaterThan(lo.gold));
    expect(lo.gold, greaterThan(small.gold));
    expect(ResidentRules.forgeOrderXp(3), t().i('forgeOrderXp') * 4);
    expect(QuestTrackRules.itemName(id), id, reason: 'the UI localizes it');
  });
}
