import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/biome_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Mapa de viaje, exterior del Bosque, refuerzos y dificultad por sala
/// (docs/specs/overworld_biomes.md).
void main() {
  GameSession room() {
    final e = sessionEngine(zones: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
    return e.addPlayer(s, 'p1', newProfile('Beto', 'mago'))!.state;
  }

  test('el Bosque: lago, matas, dos entradas y camino al sur', () {
    final m = MapGenerator.bosque();
    expect(m.place, kBosque);
    expect(m.lobby, isTrue);
    expect(m.entrances.map((e) => e.zone), [1, 2]);
    expect(m.rows.join().split(Tile.forage).length - 1,
        BosqueLayout.forage.length);
    expect(m.rows.join().contains(Tile.fishing), isTrue);
    final sp = m.spawn;
    expect(WorldRules.collides(m, sp.x, sp.y), isFalse);
    // Parado en el camino del borde sur: mapa de viaje, no lugares del pueblo.
    expect(WorldRules.townSpot(17 * 16.0, 21 * 16.0 + 4, map: m),
        TownSpot.travel);
    expect(WorldRules.townSpot(4 * 16.0, 4 * 16.0, map: m), isNot(TownSpot.portal));
  });

  test('solo el anfitrión viaja, todos van juntos y la mazmorra vuelve al '
      'pueblo', () {
    final e = sessionEngine(zones: true);
    var s = room();
    expect(e.apply(s, 'p1', const TravelAction(kBosque)), isNull);
    expect(e.apply(s, 'p0', const TravelAction('ruinas')), isNull,
        reason: 'próximamente');
    s = act(e, s, 'p0', const TravelAction(kBosque));
    expect(s.place, kBosque);
    expect(e.mapFor(s).place, kBosque);
    for (final p in s.playerList) {
      expect(WorldRules.distance(p.x, p.y, BosqueLayout.spawn.x,
              BosqueLayout.spawn.y) <
          40, isTrue);
    }
    // El tablero sigue andando: una misión desde el Bosque.
    s = act(e, s, 'p0', const ProposeMissionAction('m1'));
    s = act(e, s, 'p1', const VoteMissionAction(true));
    s = e.tick(s, 0.05).state;
    expect(s.mode, SessionMode.prep);
    expect(e.mapFor(s).place, kBosque);
    s = act(e, s, 'p0', const CancelPrepAction());
    s = act(e, s, 'p0', const TravelAction(kPueblo));
    expect(s.place, isNull);
    expect(e.mapFor(s).place, isNull);
  });

  test('recolectar da el producto, XP de Cultivo y rebrota con el tiempo',
      () {
    final e = sessionEngine(zones: true);
    var s = act(e, room(), 'p0', const TravelAction(kBosque));
    final f = BosqueLayout.forage[0];
    expect(e.apply(s, 'p0', const ForageAction(0)), isNull, reason: 'lejos');
    s = moveTo(e, s, 'p0', (f.x + 0.5) * 16, (f.y + 1.5) * 16);
    final xp0 = s.players['p0']!.profile.life.farm.xp;
    s = act(e, s, 'p0', const ForageAction(0));
    final farm = s.players['p0']!.profile.life.farm;
    expect(farm.cropCount(cropKey(kForageKinds[f.kind].item,
        CropQuality.normal)), 1);
    expect(farm.xp, greaterThan(xp0));
    expect(e.mapFor(s).tileAt(f.x, f.y), Tile.forageUsed);
    expect(e.apply(s, 'p0', const ForageAction(0)), isNull);
    s = wait(e, s, BiomeRules.t.d('forageRespawnSec') + 1);
    expect(e.mapFor(s).tileAt(f.x, f.y), Tile.forage);
    s = act(e, s, 'p0', const ForageAction(0));
  });

  test('las semillas del Bosque salen de recolectar y se plantan', () {
    var n = 0.0;
    double r() => (n += 0.013) % 1;
    final seeds = <String>{};
    for (var i = 0; i < 400; i++) {
      if (BiomeRules.forage(r, 0).seed case final s?) seeds.add(s);
    }
    expect(seeds, isNotEmpty);
    for (final s in seeds) {
      expect(kCrops[s]!.biome, 'bosque');
    }
  });

  test('el lugar y los recolectables viajan y se guardan (protocolo 46)', () {
    final e = sessionEngine(zones: true);
    var s = act(e, room(), 'p0', const TravelAction(kBosque));
    s.town = BiomeRules.pick(s.town, kBosque, 3, s.time);
    final j = SessionJson(e.catalog);
    final back = j.fromJson(j.toJson(s));
    expect(back.place, kBosque);
    expect(back.town.wild, s.town.wild);
    final saved = TownState.fromJson(s.town.toJson());
    expect(saved.wild.keys, contains('bosque:3'));
    // Saves viejos: sin `wild`.
    expect(TownState.fromJson(const {'cycle': 2}).wild, isEmpty);
    // Al cargar, nada espera más que un rebrote.
    final far = s.town.copyWith(wild: {'bosque:1': 999999});
    expect(BiomeRules.rebase(far, 0).wild['bosque:1'],
        BiomeRules.t.d('forageRespawnSec').ceil());
  });

  test('dificultad por sala: cada ausente pesa 0.6', () {
    expect(BiomeRules.roomSize(2, 0), 2);
    expect(BiomeRules.roomSize(2, 2, weight: 0.6), closeTo(3.2, 1e-9));
    expect(BiomeRules.roomSize(0, 1, weight: 0), 1);
  });

  test('el refuerzo entra a la pelea con el turno demorado', () {
    final e = sessionEngine(zones: true);
    var s = inField(e, 'm1');
    final en = s.mission!.enemies.firstWhere((x) => x.floor == 0);
    s = moveTo(e, s, 'p0', en.x, en.y);
    s = wait(e, s, 1, log: null);
    for (var i = 0; i < 200 && s.mode != SessionMode.battle; i++) {
      s = e.tick(s, 0.05).state;
    }
    expect(s.mode, SessionMode.battle);
    s = e.addPlayer(s, 'p9', newProfile('Refuerzo', 'guerrero'))!.state;
    final b = s.battle!.state;
    final c = b.party.firstWhere((x) => x.id == 'p9');
    final iv = e.battles.interval(c);
    expect(c.nextTurn,
        closeTo(b.clock + iv * (1 + BiomeRules.reinforceDelay), 1e-6));
  });
}
