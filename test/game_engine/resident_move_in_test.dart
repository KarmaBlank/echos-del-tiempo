import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mudanza de un habitante al pueblo (overworld_biomes.md § 10.1).
void main() {
  TownState invited(String npc, {double time = 100}) => ResidentRules.invite(
      const TownState().withResident(ResidentState(npc, rep: 3)), npc,
      time: time)!;

  TownState withHouse(TownState town) {
    for (var y = 2; y < 20; y++) {
      for (var x = 2; x < 30; x++) {
        final t = TownRules.place(town, kCasaId, x, y).town;
        if (t != null) return t;
      }
    }
    fail('no house spot');
  }

  test('invitar persiste y aparece en el pueblo aunque no tenga casa', () {
    final town = invited('ilda');
    final back = TownState.fromJson(town.toJson());
    expect(back.resident('ilda').invited, isTrue);
    expect(back.houseOf('ilda'), isNull);
    // Antes del arreglo no tenía posición sin casa y desaparecía.
    expect(ResidentRules.position(back, 'ilda', 5, night: false), isNotNull);
    expect(ResidentRules.position(back, 'ilda', 5, night: true), isNotNull);
    expect(ResidentRules.living(back).map((n) => n.id), contains('ilda'));
  });

  test('sale caminando por el camino del sur y se desvanece en el borde', () {
    final town = invited('ilda', time: 100);
    final n = biomeNpc('ilda')!;
    final r = town.resident('ilda');
    expect(r.leftAt, 100);
    final a = ResidentRules.departure(n, r, 100.5)!;
    final b = ResidentRules.departure(n, r, 103)!;
    expect(b.y, greaterThanOrEqualTo(a.y));
    expect(a.alpha, 1);
    // Al final ya no está y el anfitrión limpia la marca.
    expect(ResidentRules.departure(n, r, 200), isNull);
    expect(ResidentRules.settleDepartures(town, 101).resident('ilda').leftAt,
        100);
    expect(
        ResidentRules.settleDepartures(town, 200).resident('ilda').leftAt, 0);
    // Reloj de otra sesión (volvió atrás): también se limpia.
    expect(ResidentRules.settleDepartures(town, 3).resident('ilda').leftAt, 0);
  });

  test('marca de pendiente mientras no tiene casa', () {
    final town = invited('ilda');
    final n = biomeNpc('ilda')!;
    final p = PlayerProfile(name: 'P', classId: 'guerrero', level: 1);
    expect(ResidentRules.homeless(town, 'ilda'), isTrue);
    expect(QuestTrackRules.mark(p, town, n), NpcMark.news);
    expect(ResidentRules.cannotAssignFree(town, 'ilda'), isNotNull);
  });

  test('asignar una casa libre', () {
    var town = withHouse(invited('ilda'));
    expect(ResidentRules.freeHouses(town), hasLength(1));
    expect(ResidentRules.cannotAssignFree(town, 'ilda'), isNull);
    final casa = ResidentRules.freeHouses(town).single;
    town = ResidentRules.assign(town, 'ilda', casa.id)!;
    expect(town.houseOf('ilda')?.id, casa.id);
    expect(ResidentRules.homeless(town, 'ilda'), isFalse);
    expect(ResidentRules.freeHouses(town), isEmpty);
    expect(ResidentRules.cannotAssignFree(town, 'ilda'), 'Ya tiene casa');
    final back = TownState.fromJson(town.toJson());
    expect(back.houseOf('ilda')?.id, casa.id);
    expect(back.resident('ilda'), town.resident('ilda'));
  });

  TownState housed(String npc) {
    final town = withHouse(invited(npc));
    return ResidentRules.assign(
        town, npc, ResidentRules.freeHouses(town).single.id)!;
  }

  test('de noche entra a su casa salvo la noche que sale', () {
    final town = housed('ilda');
    expect(ResidentRules.position(town, 'ilda', 5, night: false), isNotNull);
    TownState onDay(int d) => town.copyWith(sky: SkyState(day: d));
    final out = [
      for (var d = 1; d <= 300; d++)
        if (ResidentRules.nightOut(onDay(d), 'ilda')) d
    ];
    expect(out, isNotEmpty);
    expect(out.length, lessThan(150));
    final inDay =
        [for (var d = 1; d <= 300; d++) d].firstWhere((d) => !out.contains(d));
    expect(ResidentRules.position(onDay(out.first), 'ilda', 5, night: true),
        isNotNull);
    expect(
        ResidentRules.position(onDay(inDay), 'ilda', 5, night: true), isNull);
  });

  test('salida nocturna: determinista por habitante y día', () {
    for (final n in kBiomeNpcs) {
      for (var d = 1; d <= 60; d++) {
        final s = TownState(sky: SkyState(day: d));
        final a = ResidentRules.nightOuting(s, n.id);
        final b = ResidentRules.nightOuting(
            TownState.fromJson(s.toJson()), n.id);
        expect(a?.key, b?.key, reason: '${n.id} día $d');
      }
    }
  });

  test('todo habitante puede salir y elige un motivo propio', () {
    for (final n in kBiomeNpcs) {
      expect(n.nightOutings, isNotEmpty, reason: n.id);
      expect(ResidentRules.nightOutChance(n.id), greaterThan(0));
      final keys = <String>{};
      for (var d = 1; d <= 400; d++) {
        final o = ResidentRules.nightOuting(
            TownState(sky: SkyState(day: d)), n.id);
        if (o == null) continue;
        expect(n.nightOutings, contains(o));
        expect(o.key, startsWith('ui.town.npc.night.${n.id}_'));
        keys.add(o.key);
      }
      // Con 400 noches salen todos sus motivos.
      expect(keys, {for (final o in n.nightOutings) o.key}, reason: n.id);
    }
  });

  test('tuning: Oren sale más que la base y la chance manda', () {
    final t = ResidentRules.t;
    expect(t.d('resNightOutOren'), greaterThan(t.d('resNightOutBase')));
    expect(ResidentRules.nightOutChance('oren'), t.d('resNightOutOren'));
    expect(ResidentRules.nightOutChance('ilda'), t.d('resNightOutIlda'));
    // Sin clave propia: la base.
    expect(ResidentRules.nightOutChance('nadie'), t.d('resNightOutBase'));
    int count(String npc) => [
          for (var d = 1; d <= 1000; d++)
            if (ResidentRules.nightOut(TownState(sky: SkyState(day: d)), npc))
              d
        ].length;
    for (final n in kBiomeNpcs) {
      final want = ResidentRules.nightOutChance(n.id) * 1000;
      expect(count(n.id), inInclusiveRange(want * 0.6, want * 1.4),
          reason: n.id);
    }
    expect(count('oren'), greaterThan(count('ilda')));
  });

  test('de noche fuera: queda cerca del lugar de su motivo', () {
    final town = housed('brann');
    final day = [
      for (var d = 1; d <= 400; d++)
        if (ResidentRules.nightOuting(
                town.copyWith(sky: SkyState(day: d)), 'brann')
            ?.spot ==
            TownSpot.forge)
          d
    ].first;
    final s = town.copyWith(sky: SkyState(day: day));
    final o = ResidentRules.nightOuting(s, 'brann')!;
    final (cx, cy) = ResidentRules.nightTarget(s, 'brann', o);
    for (final time in [0.0, 3.0, 11.0, 40.0]) {
      final (x, y) = ResidentRules.position(s, 'brann', time, night: true)!;
      expect((x - cx).abs(), lessThanOrEqualTo(12.001));
      expect(y, cy);
    }
  });

  test('ida y vuelta JSON del estado de mudanza', () {
    const r = ResidentState('ilda', invited: true, rep: 3, leftAt: 12.5);
    expect(ResidentState.fromJson(r.toJson()), r);
    expect(ResidentState.fromJson(r.copyWith(leftAt: 0).toJson())!.leftAt, 0);
    expect(r.copyWith(leftAt: 0).toJson().containsKey('la'), isFalse);
  });
}
