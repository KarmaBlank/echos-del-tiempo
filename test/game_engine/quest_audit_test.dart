import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart'
    show residentItemName;
import 'package:echos_del_tiempo/features/world/domain/quest_text.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/cooking_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/renown_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_fisher_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/npc_data_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Quest audit (docs/specs/quest_audit.md § 7): every quest, order, town
// event and talk action must be completable and fully localized.

const _locales = ['es-AR', 'en', 'zh-Hans'];

Map<String, String> _strings(String loc) {
  final out = <String, String>{};
  for (final f in Directory('assets/i18n/$loc').listSync()) {
    if (f is File && f.path.endsWith('.json')) {
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      m.forEach((k, v) => out[k] = '$v');
    }
  }
  return out;
}

/// Everything that can end up in the bag, with how it gets there.
Map<String, String> _sources() {
  final s = <String, String>{};
  for (final b in kBiomeBases.values) {
    for (final f in b.fish) {
      s[f] = 'lake ${b.id}';
    }
    for (final c in b.seeds.keys) {
      s[c] = 'seed ${b.id}';
    }
    for (final k in b.forageKinds) {
      if (kForageKinds[k].item.isNotEmpty) s[kForageKinds[k].item] = 'forage';
    }
    for (final c in b.npc.seeds.keys) {
      s.putIfAbsent(c, () => 'seed shop ${b.npc.id}');
    }
  }
  for (final f in kForageKinds) {
    if (f.item.isNotEmpty) s.putIfAbsent(f.item, () => 'forage');
  }
  for (final c in kSeasonalForage) {
    s.putIfAbsent(c, () => 'seasonal forage');
  }
  for (final c in kCrops.values) {
    // Crops whose seed the town trader sells.
    // Town crops: the trader's seeds and the rare / legendary seeds.
    if (c.biome == kFarmStartBiome) s.putIfAbsent(c.id, () => 'town seed');
    if (c.rarity == FishRarity.legendario) {
      s.putIfAbsent(c.id, () => 'legendary seed');
    }
  }
  for (final f in kFish.values) {
    // The town lake starts with these species.
    if (f.biome == kTownStartBiome) s.putIfAbsent(f.id, () => 'town lake');
  }
  for (final m in kSmithMaterials.values) {
    if (m.kind == SmithMatKind.ingot) s[m.id] = 'smelt';
  }
  return s;
}

/// Problems with an item a quest asks for.
List<String> _itemProblems(String id, Map<String, String> src) => [
      if (!kFish.containsKey(id) &&
          !kCrops.containsKey(id) &&
          !kMeals.containsKey(id) &&
          !kSmithMaterials.containsKey(id))
        '$id: not in any catalog',
      if (kMeals[id] case final m?) ...[
        for (final c in [...m.crops.keys, ...m.fish.keys])
          if (!src.containsKey(c)) '$id: ingredient $c has no source',
      ] else if (!src.containsKey(id))
        '$id: no known source',
      if (residentItemName(id) == id) '$id: name shows the raw id',
      if (QuestTrackRules.itemName(id) == id)
        '$id: tracked name shows the raw id',
    ];

void main() {
  final src = _sources();
  final strings = {for (final l in _locales) l: _strings(l)};

  test('npcs.json quest chains match the code defaults', () {
    final raw = jsonDecode(
        File('assets/data/npcs/npcs.json').readAsStringSync()) as Map;
    final data = NpcData.fromJson(raw);
    for (final MapEntry(key: id, value: chain) in data.quests.entries) {
      final def = kResidentQuestsDefaults[id];
      expect(def, isNotNull, reason: 'quests for unknown npc $id');
      expect(chain.length, def!.length, reason: id);
      for (var i = 0; i < chain.length; i++) {
        expect('${chain[i].kind}|${chain[i].target}|${chain[i].n}',
            '${def[i].kind}|${def[i].target}|${def[i].n}',
            reason: '$id step ${i + 1}');
      }
    }
  });

  test('every resident quest step is completable', () {
    final bad = <String>[];
    for (final MapEntry(key: npc, value: chain)
        in kResidentQuestsDefaults.entries) {
      if (biomeNpc(npc) == null) bad.add('$npc: not a resident');
      for (final (i, q) in chain.indexed) {
        final at = '$npc #${i + 1}';
        if (q.n <= 0) bad.add('$at: n=${q.n}');
        if (q.gold <= 0) bad.add('$at: no gold reward');
        if (q.rep <= 0) bad.add('$at: no rep reward');
        if (q.text.trim().isEmpty) bad.add('$at: empty text');
        switch (q.kind) {
          case QuestKind.pescar:
            if (!kFish.containsKey(q.target)) bad.add('$at: not a fish');
            bad.addAll(_itemProblems(q.target, src).map((e) => '$at: $e'));
          case QuestKind.recolectar || QuestKind.cultivar:
            if (!kCrops.containsKey(q.target)) bad.add('$at: not a crop');
            bad.addAll(_itemProblems(q.target, src).map((e) => '$at: $e'));
          case QuestKind.mazmorra || QuestKind.elite:
            final z = int.tryParse(q.target);
            if (z == null || z < 1 || z > kZones.length) {
              bad.add('$at: bad zone ${q.target}');
            } else if (!kZones[z - 1].playable) {
              bad.add('$at: zone $z not playable');
            }
        }
        if (q.reward case final r? when !kResidentRelics.containsKey(r)) {
          bad.add('$at: unknown relic $r');
        }
      }
      // The relic comes at the end of the chain, once.
      final relics = [for (final q in chain) if (q.reward != null) q];
      if (relics.length != 1 || chain.last.reward == null) {
        bad.add('$npc: relic must be the last step only');
      }
    }
    expect(bad, isEmpty);
  });

  test('every delivery order an NPC can ask for is completable', () {
    final bad = <String>{};
    for (final n in kBiomeNpcs) {
      for (final fish in [true, false]) {
        for (var lv = 1; lv <= 60; lv++) {
          for (final id in ResidentRules.orderPool(n, fish: fish, lv: lv)) {
            bad.addAll(_itemProblems(id, src).map((e) => '${n.id}: $e'));
          }
        }
      }
      for (var day = 0; day < 200; day++) {
        for (final lv in [1, 5, 10, 20, 40]) {
          if (ResidentRules.smithOrder(n.id, day, lv) case (final o, final c)?) {
            if (c <= 0) bad.add('${n.id}: smith order of $c');
            bad.addAll(_itemProblems(o, src).map((e) => '${n.id}: $e'));
          }
          if (ResidentRules.mealOrder(n.id, day, lv)
              case (final o, final c, _)?) {
            if (c <= 0) bad.add('${n.id}: meal order of $c');
            bad.addAll(_itemProblems(o, src).map((e) => '${n.id}: $e'));
          }
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('every native fisher request is a fish of its lake', () {
    final bad = <String>{};
    for (final b in kBiomeBases.values) {
      for (var day = 0; day < 30; day++) {
        for (final lv in [1, 10, 30]) {
          final r = BiomeFisherRules.request(b.id, day, lv);
          if (r == null) continue;
          if (!b.fish.contains(r.species)) bad.add('${b.id}: ${r.species}');
          if (r.n <= 0) bad.add('${b.id}: n=${r.n}');
          bad.addAll(_itemProblems(r.species, src));
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('every town event is completable and localized', () {
    final bad = <String>[];
    for (final e in kRenown.events) {
      if (biomeNpc(e.proposer) == null) bad.add('${e.id}: bad proposer');
      if (e.delay < 1) bad.add('${e.id}: delay < 1');
      if (e.prize <= 0) bad.add('${e.id}: no prize');
      for (final r in e.rounds) {
        if (r.isEmpty) bad.add('${e.id}: empty round');
        for (final en in r) {
          if (!kEnemies.containsKey(en)) bad.add('${e.id}: enemy $en');
        }
      }
      for (final (k, t) in e.texts) {
        if (t.missing(_locales).isNotEmpty) {
          bad.add('${e.id}.$k: missing ${t.missing(_locales)}');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('every NPC talk topic is reachable and localized', () {
    final bad = <String>[];
    // What the game reads: assets/data/npcs/npcs.json over the code.
    final talks = NpcData.fromJson(jsonDecode(
            File('assets/data/npcs/npcs.json').readAsStringSync()))
        .talks;
    void walk(String npc, TalkTopic t) {
      for (final l in [t.label, ...t.lines]) {
        if (l.missing(_locales).isNotEmpty) {
          bad.add('$npc/${t.id}: missing ${l.missing(_locales)}');
        }
      }
      if (t.action == TalkAction.house && talks[npc]!.rooted) {
        bad.add('$npc/${t.id}: rooted NPC cannot get a house');
      }
      if (t.action == TalkAction.invite && !talks[npc]!.rooted) {
        bad.add('$npc/${t.id}: invite on a non-rooted NPC');
      }
      for (final s in t.sub) {
        walk(npc, s);
      }
    }

    expect(talks.keys, containsAll(kNpcTalksDefaults.keys));
    for (final MapEntry(key: npc, value: d) in talks.entries) {
      if (biomeNpc(npc) == null && !(npc.startsWith('pesc_') && kBiomeBases.containsKey(npc.substring(5)))) {
        bad.add('$npc: talk for an unknown NPC');
      }
      for (final t in d.topics) {
        walk(npc, t);
      }
      for (final g in d.greet) {
        if (g.missing(_locales).isNotEmpty) bad.add('$npc greet: missing');
      }
    }
    expect(bad, isEmpty);
  });

  test('quest texts, kinds and relics have keys in every locale', () {
    final keys = <String>[
      for (final k in QuestKind.values) 'ui.town.npc.kind.${k.name}',
      for (final k in QuestTrackKind.values) 'ui.town.track.kind.${k.name}',
      for (final MapEntry(key: npc, value: chain)
          in kResidentQuestsDefaults.entries)
        for (var i = 0; i < chain.length; i++) questTextKey(npc, i),
      for (final r in kResidentRelics.keys) ...[
        'ui.town.relic.$r.name',
        'ui.town.relic.$r.lore',
      ],
    ];
    final bad = [
      for (final l in _locales)
        for (final k in keys)
          if ((strings[l]![k] ?? '').trim().isEmpty) '$l: $k'
    ];
    expect(bad, isEmpty);
  });

  test('every key the quest menus use exists in every locale', () {
    final files = [
      'lib/features/world/presentation/panels/biome_npc_panel.dart',
      'lib/features/world/presentation/panels/quest_log_panel.dart',
      'lib/features/world/presentation/panels/biome_fisher_panel.dart',
      'lib/features/world/presentation/panels/world_event_cells.dart',
      'lib/features/world/presentation/hud/tracked_quests_hud.dart',
    ];
    final re = RegExp(r"""\.t\(\s*'((?:ui|data)\.[a-z0-9_.]+)'""");
    final bad = <String>[];
    for (final f in files) {
      for (final m in re.allMatches(File(f).readAsStringSync())) {
        for (final l in _locales) {
          if (!strings[l]!.containsKey(m[1])) bad.add('$l: ${m[1]} ($f)');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('quest menus never show a raw zone id or engine label', () {
    LocalizedText.activeTag = 'en';
    addTearDown(() => LocalizedText.activeTag = LocalizedText.sourceTag);
    for (final chain in kResidentQuestsDefaults.values) {
      for (final q in chain) {
        if (q.kind == QuestKind.mazmorra || q.kind == QuestKind.elite) {
          final z = questZoneName(q);
          expect(z, isNot(q.target));
          expect(int.tryParse(z), isNull);
        }
      }
    }
  });
}
