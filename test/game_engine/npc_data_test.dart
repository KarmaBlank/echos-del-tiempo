import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:echos_del_tiempo/core/i18n/locale_id.dart';
import 'package:echos_del_tiempo/core/i18n/locale_registry.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/npc_talk_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/sky_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/npc_data_json.dart';
import 'package:flutter_test/flutter_test.dart';

/// docs/specs/npc_editor.md § 1: el JSON del repo, el formato por idioma
/// (y el viejo de strings sueltos), el validador y el respaldo a es-AR.
void main() {
  final file = File(NpcData.assetPath);
  final locales = [
    for (final l in LocaleId.values)
      if (LocaleRegistry.parse(
              File('assets/i18n/locales.json').readAsStringSync())
          .status
          .containsKey(l))
        l.tag,
  ];

  tearDown(() {
    NpcData.restore();
    LocalizedText.activeTag = LocalizedText.sourceTag;
  });

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

  test('formato nuevo: ida y vuelta con todos los campos', () {
    const t = NpcTalkDef(
      greet: [
        LocalizedText.of({'es-AR': 'Hola.', 'en': 'Hi.', 'zh-Hans': '你好。'})
      ],
      topics: [
        TalkTopic('a', LocalizedText.of({'es-AR': 'A', 'en': 'A'}),
            [LocalizedText('Línea.')],
            time: TalkTime.night,
            sub: [
              TalkTopic('b', LocalizedText('B'), [LocalizedText('x')])
            ]),
        TalkTopic('shop', LocalizedText('Comerciar'), [],
            action: TalkAction.trade),
      ],
      ambient: [LocalizedText('Frase.')],
      night: {'ilda_dew': LocalizedText('Rocío.')},
      inviteAccept: LocalizedText('Sí.'),
      thanksDay: LocalizedText('Gracias.'),
      thanksNight: LocalizedText('Gracias, noche.'),
    );
    const d = NpcData(talks: {'ilda': t}, quests: {});
    final back = NpcData.decode(d.encode());
    expect(back.encode(), d.encode());
    final b = back.talks['ilda']!;
    expect(b.greet.single.resolve('zh-Hans'), '你好。');
    expect(b.topics.first.time, TalkTime.night);
    expect(b.topics.last.action, TalkAction.trade);
    expect(b.night['ilda_dew']!.source, 'Rocío.');
    expect(b.thanksNight.source, 'Gracias, noche.');
    final raw = jsonDecode(d.encode()) as Map;
    expect(raw['version'], 2);
    expect(((raw['npcs'] as Map)['ilda'] as Map)['greet'], [
      {'es-AR': 'Hola.', 'en': 'Hi.', 'zh-Hans': '你好。'}
    ]);
  });

  test('formato viejo (strings sueltos) se lee como es-AR y vuelve', () {
    const old = '''
{"version": 1, "npcs": {"pesc_bosque": {
  "greet": ["Shh."], "rooted": true, "decline": ["No."], "gift": "Anzuelo",
  "topics": [{"id": "o", "label": "¿Qué?", "lines": ["Peces."],
              "where": "biome", "sub": [{"id": "s", "label": "¿Y?", "lines": ["Eso."]}]}],
  "ambient": ["Agua."]}}}''';
    final d = NpcData.decode(old);
    final t = d.talks['pesc_bosque']!;
    expect(t.greet.single.byLocale, {'es-AR': 'Shh.'});
    expect(t.topics.single.label.source, '¿Qué?');
    expect(t.topics.single.sub.single.lines.single.source, 'Eso.');
    expect(t.ambient.single.source, 'Agua.');
    expect(t.decline.single.resolve('en'), 'No.');
    final again = NpcData.decode(d.encode());
    expect(again.encode(), d.encode());
    // The old file lacks every other language: the validator says so.
    expect(d.missingLocales(locales), isNotEmpty);
  });

  test('the shipped npcs.json has every locale filled', () {
    final shipped = NpcData.decode(file.readAsStringSync());
    expect(shipped.missingLocales(locales), isEmpty);
  });

  test('el validador bloquea un idioma faltante (y uno nuevo)', () {
    LocalizedText full(String s) =>
        LocalizedText.of({for (final l in locales) l: s});
    final ok = NpcData(talks: {
      'ilda': NpcTalkDef(
        greet: [full('Hola')],
        topics: [
          TalkTopic('a', full('A'), [full('x')])
        ],
        ambient: [full('y')],
        night: {'ilda_dew': full('z')},
        inviteAccept: full('Sí'),
        thanksDay: full('G'),
        thanksNight: full('N'),
      ),
    }, quests: const {});
    expect(ok.missingLocales(locales), isEmpty);
    // zh-Hans (hidden) is asked for too.
    final noZh = NpcData(talks: {
      'ilda': NpcTalkDef(
        greet: [full('Hola').withLocale('zh-Hans', '')],
        topics: const [],
      ),
    }, quests: const {});
    final miss = noZh.missingLocales(locales);
    expect(miss, isNotEmpty);
    expect(miss.first, contains('zh-Hans'));
    expect(locales, contains('zh-Hans'));
    // A locale added later: every text lacks it.
    final more = ok.missingLocales([...locales, 'pt-BR']);
    expect(more.length, 8);
    expect(more.every((m) => m.endsWith('pt-BR')), isTrue);
  });

  test('el juego cae a es-AR si el idioma está vacío', () {
    const t = LocalizedText.of({'es-AR': 'Hola.', 'en': '', 'zh-Hans': '  '});
    expect(t.resolve('en'), 'Hola.');
    expect(t.resolve('zh-Hans'), 'Hola.');
    expect(t.resolve('fr'), 'Hola.');
    LocalizedText.activeTag = 'en';
    expect(t.text, 'Hola.');
    expect(const LocalizedText.of({'es-AR': 'Hola.', 'en': 'Hi.'}).text, 'Hi.');
    // Through the rules too: greeting, night line and invite accept.
    NpcData(talks: {
      ...kNpcTalks,
      'ilda': const NpcTalkDef(
          greet: [t],
          topics: [],
          inviteAccept: t,
          night: {'ilda_dew': t}),
    }, quests: const {}).install();
    expect(NpcTalkRules.greeting('ilda', Random0()), 'Hola.');
    expect(NpcTalkRules.inviteAccept('ilda'), 'Hola.');
    expect(NpcTalkRules.nightLine('ilda', 'ilda_dew'), 'Hola.');
  });

  test('la condición de hora filtra temas con el reloj del mundo', () {
    NpcData(talks: {
      ...kNpcTalks,
      'ilda': const NpcTalkDef(greet: [
        LocalizedText('Hola')
      ], topics: [
        TalkTopic('siempre', LocalizedText('S'), [LocalizedText('s')]),
        TalkTopic('dia', LocalizedText('D'), [LocalizedText('d')],
            time: TalkTime.day),
        TalkTopic('noche', LocalizedText('N'), [LocalizedText('n')],
            time: TalkTime.night),
      ]),
    }, quests: const {}).install();
    List<String> ids(TownState s) =>
        [for (final t in NpcTalkRules.topics(s, 'ilda', inTown: true)) t.id];
    final noon = TownState(sky: SkyState(day: 1, clock: SkyRules.daySec / 2));
    final midnight = TownState(
        sky: SkyState(day: 1, clock: (SkyRules.daySec + SkyRules.length) / 2));
    expect(ids(noon), ['siempre', 'dia']);
    expect(ids(midnight), ['siempre', 'noche']);
    expect(NpcTalkRules.locked(noon, 'ilda', inTown: true), 0);
  });

  // El dueño edita el archivo: no se compara con el código, solo que sea
  // válido (npc_editor.md § 1).
  test('el archivo migrado se lee, vuelve sin pérdida y usa ids válidos', () {
    final raw = file.readAsStringSync();
    expect((jsonDecode(raw) as Map)['version'], NpcData.version);
    final d = NpcData.decode(raw);
    final again = NpcData.decode(d.encode());
    expect(again.encode(), d.encode());
    expect(NpcData.knownIds, containsAll(d.talks.keys));
    expect(kResidentQuestsDefaults.keys, containsAll(d.quests.keys));
    for (final MapEntry(key: id, value: t) in d.talks.entries) {
      expect(t.greet, isNotEmpty, reason: id);
      expect(t.greet.every((g) => g.source.isNotEmpty), isTrue, reason: id);
      void topics(List<TalkTopic> list) {
        final ids = <String>{};
        for (final x in list) {
          expect(ids.add(x.id), isTrue, reason: '$id: tema repetido ${x.id}');
          if (x.action == TalkAction.none) {
            expect(x.lines, isNotEmpty, reason: '$id/${x.id}');
          }
          topics(x.sub);
        }
      }

      topics(t.topics);
      if (t.rooted) expect(t.decline, isNotEmpty, reason: id);
      expect(t.ambient, isNotEmpty, reason: id);
    }
    // Residents: every night outing has its line, plus invite and house.
    for (final n in kBiomeNpcs) {
      final t = d.talks[n.id]!;
      for (final o in n.nightOutings) {
        expect(t.night[o.id]?.source, isNotEmpty, reason: '${n.id}/${o.id}');
      }
      expect(t.inviteAccept.source, isNotEmpty, reason: n.id);
      expect(t.thanksDay.source, isNotEmpty, reason: n.id);
      expect(t.thanksNight.source, isNotEmpty, reason: n.id);
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
    final edited = NpcData(talks: {
      ...d.talks,
      'ilda': NpcTalkDef(
          greet: const [LocalizedText('Hola.')],
          topics: d.talks['ilda']!.topics),
      'nadie': const NpcTalkDef(greet: [LocalizedText('x')], topics: []),
    }, quests: d.quests);
    expect(edited.install(), ['nadie']);
    expect(npcTalk('ilda')!.greet.single.text, 'Hola.');
    expect(npcTalk('nadie'), isNull);
    expect(kResidentQuests['ilda']!.length,
        kResidentQuestsDefaults['ilda']!.length);
    NpcData.restore();
    expect(npcTalk('ilda')!.greet, kNpcTalksDefaults['ilda']!.greet);
  });

  test('archivo roto lanza FormatException', () {
    expect(() => NpcData.decode('{"npcs": {"ilda": {"topics": [{"x": 1}]}}}'),
        throwsFormatException);
    expect(() => NpcData.decode('[]'), throwsFormatException);
  });
}

/// A deterministic random that always picks the first item.
class Random0 implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}
