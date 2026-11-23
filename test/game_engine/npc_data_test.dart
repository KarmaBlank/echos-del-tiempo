import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_fisher_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/npc_data_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// docs/specs/npc_editor.md § 1: el JSON del repo es lo mismo que el
/// código (migración sin pérdida) y el lector vuelve atrás.
void main() {
  final file = File(NpcData.assetPath);

  test('(re)genera el archivo si se pide', () {
    if (Platform.environment['ECOS_WRITE_NPCS'] == '1') {
      file.writeAsStringSync(NpcData.defaults.encode());
    }
  });

  test('ida y vuelta de los valores del código sin pérdida', () {
    final d = NpcData.defaults;
    final back = NpcData.decode(d.encode());
    expect(back.encode(), d.encode());
    expect(back.talks.keys, kNpcTalksDefaults.keys);
    expect(back.quests.keys, kResidentQuestsDefaults.keys);
  });

  // El dueño edita el archivo: no se compara con el código, solo que sea
  // válido (npc_editor.md § 1).
  test('el archivo del repo se lee, vuelve sin pérdida y usa ids válidos', () {
    final raw = file.readAsStringSync();
    final d = NpcData.decode(raw);
    final again = NpcData.decode(d.encode());
    expect(again.encode(), d.encode());
    expect(NpcData.knownIds, containsAll({...d.talks.keys, ...d.ambient.keys}));
    expect(kResidentQuestsDefaults.keys, containsAll(d.quests.keys));
    for (final MapEntry(key: id, value: t) in d.talks.entries) {
      expect(t.greet, isNotEmpty, reason: id);
      void topics(List<TalkTopic> list) {
        final ids = <String>{};
        for (final x in list) {
          expect(ids.add(x.id), isTrue, reason: '$id: tema repetido ${x.id}');
          expect(x.lines, isNotEmpty, reason: '$id/${x.id}');
          topics(x.sub);
        }
      }

      topics(t.topics);
      if (t.rooted) expect(t.decline, isNotEmpty, reason: id);
    }
    for (final MapEntry(key: id, value: q) in d.quests.entries) {
      for (final st in q) {
        if (st.reward != null) {
          expect(kResidentRelics.containsKey(st.reward), isTrue, reason: id);
        }
      }
    }
  });

  test('instalar pone el archivo encima y restore vuelve', () {
    final d = NpcData.decode(file.readAsStringSync());
    final edited = NpcData(
        talks: {
          ...d.talks,
          'ilda': NpcTalkDef(
              greet: const ['Hola.'], topics: d.talks['ilda']!.topics),
          'nadie': const NpcTalkDef(greet: ['x'], topics: []),
        },
        quests: d.quests,
        ambient: {
          ...d.ambient,
          'pesc_bosque': const ['Agua.']
        });
    expect(edited.install(), ['nadie']);
    expect(npcTalk('ilda')!.greet, ['Hola.']);
    expect(npcTalk('nadie'), isNull);
    expect(kBiomeFishers['bosque']!.lines, ['Agua.']);
    expect(kResidentQuests['ilda']!.length,
        kResidentQuestsDefaults['ilda']!.length);
    NpcData.restore();
    expect(npcTalk('ilda')!.greet, kNpcTalksDefaults['ilda']!.greet);
    expect(
        kBiomeFishers['bosque']!.lines, kBiomeFishersDefaults['bosque']!.lines);
  });

  test('archivo roto lanza FormatException', () {
    expect(() => NpcData.decode('{"npcs": {"ilda": {"topics": [{"x": 1}]}}}'),
        throwsFormatException);
    expect(() => NpcData.decode('[]'), throwsFormatException);
  });
}
