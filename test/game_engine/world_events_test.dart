import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/world_events_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/localized_text.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_event_rules.dart';

const _tags = ['es-AR', 'en', 'zh-Hans'];

LocalizedText _all(String s) =>
    LocalizedText.of({for (final t in _tags) t: s});

WorldEventDef _def(String id,
        {WorldEventCategory cat = WorldEventCategory.visitor,
        int weight = 1,
        int duration = 3}) =>
    WorldEventDef(
        id: id,
        category: cat,
        weight: weight,
        duration: duration,
        title: _all(id),
        notice: _all(id),
        body: _all(id));

void main() {
  final allResidents = {for (final n in kBiomeNpcs) n.id};
  final ctx = WorldEventContext(residents: allResidents);

  group('tirada', () {
    test('misma semilla y dÃ­a = mismos eventos', () {
      for (var day = 5; day <= 60; day += 5) {
        final a = WorldEventRules.roll(1234, day, kWorldEventsDefaults, ctx: ctx);
        final b = WorldEventRules.roll(1234, day, kWorldEventsDefaults, ctx: ctx);
        expect(a, b);
      }
    });

    test('otra semilla cambia algo', () {
      final a = [
        for (var d = 5; d <= 100; d += 5)
          ...WorldEventRules.roll(1, d, kWorldEventsDefaults, ctx: ctx)
      ];
      final b = [
        for (var d = 5; d <= 100; d += 5)
          ...WorldEventRules.roll(2, d, kWorldEventsDefaults, ctx: ctx)
      ];
      expect(a, isNot(b));
    });

    test('respeta el intervalo', () {
      const cfg = WorldEventsConfig(interval: 5);
      var s = const WorldEventsState(seed: 7);
      expect(WorldEventRules.due(s, 4, cfg), isFalse);
      expect(WorldEventRules.due(s, 5, cfg), isTrue);
      s = s.copyWith(last: 5);
      expect(WorldEventRules.due(s, 9, cfg), isFalse);
      expect(WorldEventRules.due(s, 10, cfg), isTrue);
    });

    test('onDay tira solo cuando toca', () {
      final cfg = WorldEventsConfig(
          interval: 3,
          minPerRoll: 1,
          maxPerRoll: 1,
          events: [_def('a', duration: 1)]);
      var s = const WorldEventsState(seed: 9);
      final rolls = <int>[];
      for (var d = 1; d <= 12; d++) {
        final (n, started) = WorldEventRules.onDay(s, d, cfg);
        if (started.isNotEmpty) rolls.add(d);
        s = n;
      }
      expect(rolls, [3, 6, 9, 12]);
    });

    test('min/max por tirada', () {
      final cfg = WorldEventsConfig(
          minPerRoll: 2,
          maxPerRoll: 3,
          events: [for (var i = 0; i < 6; i++) _def('e$i')]);
      for (var d = 1; d < 50; d++) {
        final r = WorldEventRules.roll(42, d, cfg);
        expect(r.length, inInclusiveRange(2, 3));
        expect({for (final a in r) a.def}.length, r.length);
      }
    });

    test('los pesos se respetan (peso 0 nunca sale)', () {
      final cfg = WorldEventsConfig(
          minPerRoll: 1,
          maxPerRoll: 1,
          events: [
            _def('pesado', weight: 9),
            _def('liviano', weight: 1),
            _def('nunca', weight: 0),
          ]);
      final count = <String, int>{};
      for (var d = 1; d <= 2000; d++) {
        for (final a in WorldEventRules.roll(5, d, cfg)) {
          count[a.def] = (count[a.def] ?? 0) + 1;
        }
      }
      expect(count['nunca'], isNull);
      expect(count['pesado']!, greaterThan(count['liviano']! * 5));
    });

    test('chance 0 = nada', () {
      final cfg = WorldEventsConfig(chance: 0, events: [_def('a')]);
      expect(WorldEventRules.roll(1, 5, cfg), isEmpty);
    });

    test('historia requiere al habitante y sale una sola vez', () {
      final lore = kWorldEventsDefaults.def('lore_ilda_roots')!;
      final cfg = WorldEventsConfig(
          minPerRoll: 1, maxPerRoll: 1, interval: 1, events: [lore]);
      expect(WorldEventRules.roll(1, 5, cfg), isEmpty);
      var s = const WorldEventsState(seed: 3);
      var (n, started) = WorldEventRules.onDay(s, 1, cfg,
          ctx: const WorldEventContext(residents: {'ilda'}));
      expect(started.single.biome, biomeNpc('ilda')!.biome);
      expect(n.seen, contains('lore_ilda_roots'));
      s = WorldEventRules.expire(n, 100);
      (n, started) = WorldEventRules.onDay(s, 100, cfg,
          ctx: const WorldEventContext(residents: {'ilda'}));
      expect(started, isEmpty);
    });

    test('gancho de condiciÃ³n extra', () {
      final cfg = WorldEventsConfig(events: [_def('a')]);
      final r = WorldEventRules.roll(1, 5, cfg,
          ctx: WorldEventContext(extraCondition: (_) => false));
      expect(r, isEmpty);
    });
  });

  test('vencimiento', () {
    const s = WorldEventsState(active: [
      ActiveWorldEvent('a', biome: 'pueblo', start: 5, end: 8),
      ActiveWorldEvent('b', biome: 'bosque', start: 5, end: 10),
    ]);
    expect(WorldEventRules.expire(s, 7).active.length, 2);
    expect(WorldEventRules.expire(s, 8).active.map((a) => a.def), ['b']);
    expect(WorldEventRules.expire(s, 10).active, isEmpty);
  });

  test('grieta de eco: jefe del bioma escalado', () {
    final d = kWorldEventsDefaults.def('echo_rift')!;
    final r = WorldEventRules.rift(d, kBosque)!;
    final zone = kZones.firstWhere((z) => z.index == biomeDef(kBosque)!.zones.last);
    expect(r.bossId, zone.bossId);
    expect(r.missionId, zone.missionId);
    expect(r.hpMult, 1.6);
    expect(r.rewardMult, greaterThan(1));
    final (hp, atk) = r.scale(100, 10);
    expect(hp, 160);
    expect(atk, 13);
    expect(WorldEventRules.rift(d, kPueblo), isNull);
  });

  test('nunca dos grietas en el mismo bioma', () {
    final rift = kWorldEventsDefaults.def('echo_rift')!;
    final cfg = WorldEventsConfig(events: [rift]);
    final s = WorldEventsState(active: [
      for (final b in kBiomes)
        if (b.id != kPueblo)
          ActiveWorldEvent('otra', biome: b.id, start: 1, end: 9)
    ]);
    final cfg2 = WorldEventsConfig(events: [
      rift,
      const WorldEventDef(id: 'otra', category: WorldEventCategory.echoPortal)
    ]);
    expect(WorldEventRules.roll(1, 5, cfg2, state: s), isEmpty);
    expect(WorldEventRules.roll(1, 5, cfg), isNotEmpty);
  });

  test('historia crea una misiÃ³n que no es de traer cosas', () {
    for (final d in kWorldEventsDefaults.events) {
      if (d.category != WorldEventCategory.lore) continue;
      final q = WorldEventRules.loreQuest(d)!;
      expect(q.isFetch, isFalse);
      expect(LoreObjective.values, contains(q.objective));
      expect(q.npc, d.resident);
      expect(q.gold, greaterThan(0));
    }
    expect(
        WorldEventRules.loreQuest(kWorldEventsDefaults.def('echo_rift')!),
        isNull);
  });

  group('JSON', () {
    test('catÃ¡logo ida y vuelta', () {
      final j = jsonEncode(kWorldEventsDefaults.toJson());
      final back = WorldEventsConfig.fromJson(jsonDecode(j));
      expect(jsonEncode(back.toJson()), j);
    });

    test('estado ida y vuelta en el pueblo', () {
      const ev = WorldEventsState(
          seed: 99,
          last: 10,
          active: [ActiveWorldEvent('echo_rift', biome: 'ruinas', start: 10, end: 13)],
          seen: {'lore_kael_guardian'});
      const town = TownState(events: ev);
      final back = TownState.fromJson(jsonDecode(jsonEncode(town.toJson())));
      expect(back.events, ev);
      final wire = TownState.fromJson(jsonDecode(jsonEncode(town.farmJson())));
      expect(wire.events, ev);
      expect(TownState.fromJson(const {}).events.isEmpty, isTrue);
    });

    test('el archivo de datos lee y valida', () {
      final raw = File(WorldEventsConfig.assetPath).readAsStringSync();
      final cfg = WorldEventsConfig.fromJson(jsonDecode(raw));
      expect(
          cfg.validate(_tags,
              biomes: {for (final b in kBiomes) b.id},
              residents: {for (final n in kBiomeNpcs) n.id},
              enemies: kEnemies.keys.toSet()),
          isEmpty);
    });
  });

  group('validaciÃ³n del editor', () {
    test('falta un idioma', () {
      final cfg = WorldEventsConfig(events: [
        WorldEventDef(
            id: 'x',
            category: WorldEventCategory.visitor,
            title: const LocalizedText.of({'es-AR': 'Hola', 'en': 'Hi', 'zh-Hans': ''}),
            notice: _all('n'),
            body: _all('b')),
      ]);
      expect(cfg.missingLocales(_tags), ['x.title:zh-Hans']);
      expect(cfg.validate(_tags), isNotEmpty);
    });

    test('min > max, intervalo 0 e historia sin objetivo', () {
      final cfg = WorldEventsConfig(
          interval: 0,
          minPerRoll: 3,
          maxPerRoll: 1,
          events: [_def('l', cat: WorldEventCategory.lore)]);
      final p = cfg.validate(_tags);
      expect(p.length, greaterThanOrEqualTo(4));
    });

    test('los de cÃ³digo son vÃ¡lidos', () {
      expect(kWorldEventsDefaults.validate(_tags), isEmpty);
    });
  });
}
