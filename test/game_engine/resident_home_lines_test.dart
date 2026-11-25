import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/npc_talk_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/npc_data_json.dart';
import 'package:flutter_test/flutter_test.dart';

bool _pitch(LocalizedText t) =>
    t.text.contains('Llevame a tu pueblo') ||
    t.text.contains('tu pueblo necesita');

void main() {
  // Regression: a resident already living in town (Brann with a house)
  // kept saying the recruit pitch (overworld_biomes.md § 12.1).
  test('in town, no resident says the recruit pitch', () {
    for (final id in ['ilda', 'velda', 'kael', 'brann', 'oren']) {
      final home = NpcTalkRules.ambient(id, inTown: true);
      expect(home, isNotEmpty, reason: id);
      expect(home.where(_pitch), isEmpty, reason: id);
      for (var d = 0; d < 10; d++) {
        final l = NpcTalkRules.dayLine(id, d, inTown: true)!;
        expect(l.contains('Llevame a tu pueblo'), isFalse, reason: '$id $d');
      }
    }
  });

  test('in the biome the pitch is still there', () {
    expect(NpcTalkRules.ambient('brann', inTown: false).where(_pitch),
        isNotEmpty);
  });

  test('home_ambient survives the JSON round trip', () {
    final t = NpcData.talkFromJson(NpcData.talkToJson(npcTalk('brann')!));
    expect(t.homeAmbient.length, npcTalk('brann')!.homeAmbient.length);
  });

  // Regression: "Orden de Brann" showed "5 × ingot_copper".
  test('order item names never show raw smithing ids', () {
    expect(QuestTrackRules.itemName('ingot_copper'), 'Lingote de cobre');
    for (final id in kSmithMaterials.keys) {
      expect(QuestTrackRules.itemName(id), isNot(id), reason: id);
    }
    expect(QuestTrackRules.itemName('pick_copper'), 'Pico de cobre');
    expect(QuestTrackRules.itemName('weird_thing'), 'Weird thing');
  });
}
