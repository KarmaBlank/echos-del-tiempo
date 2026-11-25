import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/gear_v2_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/profession_gear_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// profession_gear_v2.md § 7–8: save fields, migration of v1 weapons and
/// the protocol 93 actions.
void main() {
  String baseOf(String type) => prototypeCatalog.weapons.values
      .firstWhere((w) => w.type == type)
      .id;

  PlayerProfile withItems(List<ItemInstance> items) => progression.normalize(
      PlayerProfile(name: 'Ana', classId: 'guerrero', level: 30, items: items));

  test('a v1 living legendary keeps its rarity and gets its affinity', () {
    final v1 = ItemInstance(
        uid: GearRules.uidFor('vivo_baston'),
        baseId: baseOf('báculo'),
        rarity: Rarity.legendario,
        itemLevel: 20,
        passiveId: null,
        affixes: const [AffixRoll('de_la_vida', 0, 50)]);
    final p = withItems([v1]);
    final it = p.items.firstWhere((i) => i.uid == v1.uid);
    expect(it.rarity, Rarity.legendario);
    expect(it.parts, ['v1', GameElement.sagrado.name]);
    expect(it.affixes.map((a) => a.affixId), contains('de_la_vida'));
    // Idempotent: a second load changes nothing.
    expect(withItems([it]).items.firstWhere((i) => i.uid == v1.uid), it);
  });

  test('a v1 fish-forged weapon takes the species affinity', () {
    final v1 = ItemInstance(
        uid: GearRules.uidFor(fishForgeGearId('pez_invierno')),
        baseId: baseOf(fishForgeType('pez_invierno')),
        rarity: Rarity.epico,
        itemLevel: 20);
    expect(GearV2Rules.migrate(v1).parts, ['v1', 'hielo']);
  });

  test('v2 fields survive the save round trip', () {
    final w = ItemInstance(
        uid: GearRules.uidFor('parts_hacha'),
        baseId: baseOf('hacha'),
        rarity: Rarity.epico,
        itemLevel: 20,
        element: GameElement.fuego,
        masterwork: true,
        parts: const ['ingot_ember', 'ingot_copper', 'ingot_copper', 'rare_magma']);
    final back = ItemInstance.fromJson(jsonDecode(jsonEncode(w.toJson())))!;
    expect(back, w);
    final p = withItems([w]);
    final again = PlayerProfile.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>);
    final it = again.items.firstWhere((i) => i.uid == w.uid);
    expect(it.parts, w.parts);
    expect(it.masterwork, isTrue);
    // An old save without the fields reads as v1 (not v2).
    final old = Map<String, Object?>.from(w.toJson())
      ..remove('pt')
      ..remove('mw');
    final o = ItemInstance.fromJson(old)!;
    expect([o.parts, o.masterwork], [isEmpty, false]);
  });

  test('protocol 93 smith actions round-trip', () {
    for (final a in [
      const SmithAction(SmithOp.forgeParts, 'ingot_frost',
          base: 'espada', parts: ['ingot_copper', 'fp_pez_paradoja_bone']),
      const SmithAction(SmithOp.fishSplit, 'pez_paradoja'),
    ]) {
      final back = ActionJson.fromJson(
          jsonDecode(jsonEncode(ActionJson.toJson(a))) as Map<String, Object?>)
          as SmithAction;
      expect([back.op, back.material, back.base, back.parts],
          [a.op, a.material, a.base, a.parts]);
    }
  });
}
