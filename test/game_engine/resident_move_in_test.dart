import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/sky.dart';
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

  test('de noche entra a su casa; el trasnochador a veces sale', () {
    var town = withHouse(invited('ilda'));
    town = ResidentRules.assign(
        town, 'ilda', ResidentRules.freeHouses(town).single.id)!;
    expect(ResidentRules.position(town, 'ilda', 5, night: false), isNotNull);
    expect(ResidentRules.position(town, 'ilda', 5, night: true), isNull);
    expect(biomeNpc('ilda')!.nightOwl, isFalse);

    var oren = withHouse(invited('oren'));
    oren = ResidentRules.assign(
        oren, 'oren', ResidentRules.freeHouses(oren).single.id)!;
    expect(biomeNpc('oren')!.nightOwl, isTrue);
    TownState onDay(int d) => oren.copyWith(sky: SkyState(day: d));
    final out = [
      for (var d = 1; d <= 200; d++)
        if (ResidentRules.nightOut(onDay(d), 'oren')) d
    ];
    // Baja chance: algunas noches sí, la mayoría no.
    expect(out, isNotEmpty);
    expect(out.length, lessThan(100));
    final inDay =
        [for (var d = 1; d <= 200; d++) d].firstWhere((d) => !out.contains(d));
    expect(ResidentRules.position(onDay(out.first), 'oren', 5, night: true),
        isNotNull);
    expect(
        ResidentRules.position(onDay(inDay), 'oren', 5, night: true), isNull);
  });

  test('ida y vuelta JSON del estado de mudanza', () {
    const r = ResidentState('ilda', invited: true, rep: 3, leftAt: 12.5);
    expect(ResidentState.fromJson(r.toJson()), r);
    expect(ResidentState.fromJson(r.copyWith(leftAt: 0).toJson())!.leftAt, 0);
    expect(r.copyWith(leftAt: 0).toJson().containsKey('la'), isFalse);
  });
}
