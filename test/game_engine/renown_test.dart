import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/renown_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/world_events_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/npc_talk_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/renown_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_event_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/npc_data_json.dart';
import 'package:flutter_test/flutter_test.dart';

// docs/specs/renown_town_growth.md § 9.

const _tags = ['es-AR', 'en', 'zh-Hans'];

TownState _town({Set<int> zones = const {}, int residents = 0, int rifts = 0}) {
  final ids = [for (final n in kBiomeNpcs) n.id].take(residents);
  return TownState(
    builds: const [],
    residents: {for (final id in ids) id: ResidentState(id, invited: true)},
    renown: RenownState(zones: zones, rifts: rifts),
  );
}

void main() {
  tearDown(() {
    LocalizedText.tokens = const {};
    kRenown = kRenownDefaults;
  });

  group('renombre desde hitos', () {
    test('suma cada fuente por su peso', () {
      const cfg = RenownConfig(sources: {
        RenownSource.zone: 10,
        RenownSource.biomeBoss: 25,
        RenownSource.rift: 8,
        RenownSource.resident: 6,
        RenownSource.building: 1,
      });
      expect(RenownRules.score(const TownState(builds: []), cfg), 0);
      expect(RenownRules.score(_town(zones: {1}), cfg), 10);
      // The last zone of a biome is a biome boss too.
      final b = kBiomes.firstWhere((b) => b.zones.isNotEmpty);
      final t = _town(zones: {...b.zones}, residents: 2, rifts: 1);
      expect(RenownRules.biomeBosses(t.renown), 1);
      expect(RenownRules.score(t, cfg),
          b.zones.length * 10 + 25 + 8 + 2 * 6);
      final withBuild = t.copyWith(builds: kDefaultBuilds);
      expect(RenownRules.score(withBuild, cfg),
          RenownRules.score(t, cfg) + kDefaultBuilds.length);
    });

    test('ganar una zona anota el jefe y su bioma', () {
      final b = kBiomes.firstWhere((b) => b.zones.isNotEmpty);
      final r = RenownRules.zoneWon(const RenownState(), b.zones.first);
      expect(r.zones, {b.zones.first});
      expect(r.lastBoss, isNotEmpty);
      expect(r.lastBiome, b.id);
      expect(RenownRules.riftWon(r).rifts, 1);
      expect(RenownRules.loreDone(r).lore, 1);
    });
  });

  group('niveles', () {
    final ladder = [
      const RenownTier(0, LocalizedText('a')),
      const RenownTier(30, LocalizedText('b')),
      const RenownTier(90, LocalizedText('c')),
    ];
    test('umbral exacto y fracción hacia el próximo', () {
      expect(RenownRules.ladder(ladder, 0).index, 0);
      expect(RenownRules.ladder(ladder, 29).index, 0);
      expect(RenownRules.ladder(ladder, 30).index, 1);
      expect(RenownRules.ladder(ladder, 60).fraction, closeTo(0.5, 1e-9));
      final top = RenownRules.ladder(ladder, 500);
      expect(top.index, 2);
      expect(top.next, isNull);
      expect(top.fraction, 1);
    });

    test('nivel del pueblo: habitantes, edificios y renombre', () {
      const cfg = RenownConfig(
          sources: {RenownSource.resident: 10},
          town: {
            TownWeight.resident: 4,
            TownWeight.building: 1,
            TownWeight.renown: 0.1
          },
          townTiers: [
            RenownTier(0, LocalizedText('Caserío')),
            RenownTier(15, LocalizedText('Aldea')),
          ]);
      final t = _town(residents: 3);
      // 3×4 + 0 buildings + 30×0.1 = 15.
      expect(RenownRules.townPoints(t, cfg), closeTo(15, 1e-9));
      expect(RenownRules.townTier(t, cfg).tier!.name.source, 'Aldea');
      expect(RenownRules.townTier(_town(residents: 1), cfg).index, 0);
    });
  });

  group('fichas', () {
    test('se reemplazan al mostrarse; las desconocidas quedan', () {
      const t = LocalizedText.of(
          {'es-AR': 'Venciste a {lastBoss} en {townName} {otra}', 'en': ''});
      LocalizedText.tokens = {'lastBoss': 'la Matriarca', 'townName': 'Brumas'};
      expect(t.text, 'Venciste a la Matriarca en Brumas {otra}');
      expect(t.resolve('en'), 'Venciste a la Matriarca en Brumas {otra}');
      // The raw text is kept for the editor.
      expect(t.source, contains('{lastBoss}'));
    });

    test('tokens del mundo', () {
      final b = kBiomes.firstWhere((b) => b.zones.isNotEmpty);
      final t = _town(zones: {b.zones.last}).copyWith(
          renown: RenownRules.zoneWon(const RenownState(), b.zones.last));
      final m = RenownRules.tokens(t, worldName: 'Brumas');
      expect(m['townName'], 'Brumas');
      expect(m['lastBoss'], t.renown.lastBoss);
      expect(m['lastBiome'], b.name);
      expect(m['renownTier'], isNotEmpty);
      expect(m['townTier'], isNotEmpty);
    });
  });

  group('reconocimiento', () {
    test('la frase de mayor renombre alcanzado', () {
      expect(RenownRules.recognition(RecognitionWho.visitor, 0), isNull);
      expect(RenownRules.recognition(RecognitionWho.visitor, 30)!.id,
          'visitor_heard');
      expect(RenownRules.recognition(RecognitionWho.visitor, 500)!.id,
          'visitor_legend');
      expect(RenownRules.recognition('ilda', 30)!.id, 'ilda_heard');
    });

    test('cada habitante que se muda tiene al menos dos', () {
      for (final id in ['ilda', 'velda', 'kael', 'brann', 'oren']) {
        expect(kRenownDefaults.lines.where((l) => l.who == id).length,
            greaterThanOrEqualTo(2),
            reason: id);
      }
    });
  });

  group('condiciones de renombre', () {
    test('un tema con renombre se abre al llegar', () {
      const topic = TalkTopic('fama', LocalizedText('¿Y la fama?'), [],
          renown: 30);
      const low = (talks: 9, orders: 9, rep: 9, renown: 29);
      const high = (talks: 9, orders: 9, rep: 9, renown: 30);
      expect(NpcTalkRules.open(topic, low, inTown: true), isFalse);
      expect(NpcTalkRules.open(topic, high, inTown: true), isTrue);
      // JSON keeps it.
      final back = NpcData.topicFromJson(NpcData.topicToJson(topic));
      expect(back.renown, 30);
    });

    test('un evento con renombre mínimo no sale sin él', () {
      const cfg = WorldEventsConfig(events: [
        WorldEventDef(
            id: 'v', category: WorldEventCategory.visitor, minRenown: 50),
      ]);
      expect(WorldEventRules.roll(1, 5, cfg), isEmpty);
      expect(
          WorldEventRules.roll(1, 5, cfg,
              ctx: const WorldEventContext(renown: 50)),
          isNotEmpty);
      final back = WorldEventDef.fromJson(cfg.events.first.toJson());
      expect(back.minRenown, 50);
    });
  });

  group('eventos del pueblo', () {
    test('proponer, programar, el día llega y vence si no se juega', () {
      final d = kRenownDefaults.event('tourney_kael')!;
      var t = const TownState(
          builds: [],
          residents: {'kael': ResidentState('kael', invited: true)},
          renown: RenownState(zones: {1, 2, 3}));
      expect(RenownRules.cannotPropose(t, d, 1), startsWith('Amistad'));
      t = t.withResident(t.resident('kael').copyWith(rep: d.minRep));
      expect(RenownRules.score(t), greaterThanOrEqualTo(d.minRenown));
      expect(RenownRules.proposals(t, 'kael', 1).map((x) => x.id),
          ['tourney_kael']);
      t = RenownRules.schedule(t, d.id, 1)!;
      expect(t.renown.scheduled[d.id], 1 + d.delay);
      expect(RenownRules.proposals(t, 'kael', 1), isEmpty);
      expect(RenownRules.live(t, 'kael', 1 + d.delay)?.id, d.id);
      final missed = RenownRules.expire(t.renown, 2 + d.delay);
      expect(missed.scheduled, isEmpty);
      expect(missed.held[d.id], 1 + d.delay);
      // Cooldown.
      t = t.copyWith(renown: missed);
      expect(RenownRules.cannotPropose(t, d, 2 + d.delay), startsWith('Faltan'));
      expect(RenownRules.cannotPropose(t, d, 1 + d.delay + d.cooldown), isNull);
    });
  });

  group('JSON', () {
    test('estado ida y vuelta (y viaja en el pueblo)', () {
      const r = RenownState(
          zones: {1, 4},
          rifts: 2,
          lore: 1,
          tourneys: 3,
          lastBoss: 'X',
          lastBiome: 'bosque',
          scheduled: {'a': 7},
          held: {'b': 2});
      expect(RenownState.fromJson(jsonDecode(jsonEncode(r.toJson()))), r);
      const t = TownState(renown: r);
      expect(TownState.fromJson(jsonDecode(jsonEncode(t.farmJson()))).renown, r);
      expect(TownState.fromJson(const {}).renown, const RenownState());
    });

    test('catálogo ida y vuelta', () {
      final j = jsonDecode(jsonEncode(kRenownDefaults.toJson()));
      final back = RenownConfig.fromJson(j);
      expect(jsonEncode(back.toJson()), jsonEncode(kRenownDefaults.toJson()));
    });

    test('el archivo del repo se lee y valida', () {
      final raw = File(RenownConfig.assetPath).readAsStringSync();
      final cfg = RenownConfig.fromJson(jsonDecode(raw));
      expect(
          cfg.validate(_tags,
              residents: {for (final n in kBiomeNpcs) n.id},
              enemies: kEnemies.keys.toSet()),
          isEmpty);
    });
  });

  group('validación del editor', () {
    test('idiomas faltantes, umbrales y torneo incompleto', () {
      const bad = RenownConfig(
        sources: {RenownSource.zone: -1},
        tiers: [
          RenownTier(5, LocalizedText.of({'es-AR': 'a', 'en': 'a'})),
          RenownTier(5, LocalizedText.of(
              {'es-AR': 'b', 'en': 'b', 'zh-Hans': 'b'})),
        ],
        townTiers: [],
        lines: [
          RecognitionLine(id: 'x', who: 'nadie', text: LocalizedText('x')),
        ],
        events: [
          TownEventDef(
              id: 't',
              kind: TownEventKind.tournament,
              proposer: 'kael',
              rounds: [
                ['noexiste']
              ]),
        ],
      );
      final p = bad.validate(_tags,
          residents: {for (final n in kBiomeNpcs) n.id},
          enemies: kEnemies.keys.toSet());
      bool has(String s) => p.any((x) => x.contains(s));
      expect(has('Peso negativo'), isTrue);
      expect(has('empieza en 0'), isTrue);
      expect(has('tienen que subir'), isTrue);
      expect(has('Pueblo: hace falta'), isTrue);
      expect(has('quién desconocido'), isTrue);
      expect(has('3 rondas'), isTrue);
      expect(has('enemigo desconocido'), isTrue);
      expect(has('Falta idioma: tiers.0:zh-Hans'), isTrue);
      expect(kRenownDefaults.validate(_tags,
          residents: {for (final n in kBiomeNpcs) n.id},
          enemies: kEnemies.keys.toSet()), isEmpty);
    });
  });
}
