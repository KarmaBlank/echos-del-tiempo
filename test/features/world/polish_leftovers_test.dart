import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/core/i18n/game_text.dart';
import 'package:echos_del_tiempo/core/i18n/locale_id.dart';
import 'package:echos_del_tiempo/core/i18n/string_tables.dart';
import 'package:echos_del_tiempo/features/inventory/domain/eco_text.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/tracked_quests_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_source_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/npc_data_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tables = StringTables.loadDirectorySync(StringTables.assetRoot)!;
  final zh = LocaleId.fromTag('zh-Hans')!;
  tearDown(() => GameText.current = null);

  test('Eco names render in the active language (3 locales)', () {
    const rules = EcoRules();
    const e = EcoItem(uid: 'u', tier: 3, zone: 2, boss: 2);
    GameText.current = tables.strings(LocaleId.source);
    expect(ecoNameText(rules, e), rules.displayName(e));
    expect(ecoFullText(rules, e), endsWith('· T3'));
    GameText.current = tables.strings(LocaleId.en);
    expect(ecoNameText(rules, e), startsWith('Echo of '));
    GameText.current = tables.strings(zh);
    expect(ecoNameText(rules, e), endsWith('之回响'));
  });

  test('resident item names and quest titles follow the locale', () {
    final id = kSmithMaterials.keys.firstWhere((k) =>
        tables.strings(LocaleId.en).t('data.materials.smith.$k.name') !=
        QuestTrackRules.itemName(k));
    final en = tables.strings(LocaleId.en);
    GameText.current = en;
    expect(residentItemName(id), en.t('data.materials.smith.$id.name'));
    final a = ActiveQuest(
        npc: kBiomeNpcs.first,
        kind: QuestTrackKind.orden,
        title: '2 × ${QuestTrackRules.itemName(id)}',
        step: 0,
        item: id,
        have: 0,
        need: 2,
        tracked: false);
    expect(questTitleText(en, a), '2 × ${residentItemName(id, en)}');
    expect(questTitleText(tables.strings(zh), a), startsWith('2 × '));
  });

  test('Brann and Ilda home lines are editable (home_ambient)', () {
    final raw = File(NpcData.assetPath).readAsStringSync();
    final m = jsonDecode(raw) as Map<String, dynamic>;
    for (final id in ['brann', 'ilda']) {
      expect(raw, contains('home_ambient'));
      final t = kNpcTalks[id]!;
      expect(t.homeAmbient, isNotEmpty, reason: id);
      expect(NpcData.talkToJson(t)['home_ambient'], isNotEmpty, reason: id);
    }
    expect(m, isNotEmpty);
  });

  test('trader and gift items have known sources', () {
    final gifts = {for (final n in kBiomeNpcs) ...ResidentRules.giftables(n)};
    expect(gifts.where((g) => ItemSourceRules.of(g).isNotEmpty), isNotEmpty);
  });
}
