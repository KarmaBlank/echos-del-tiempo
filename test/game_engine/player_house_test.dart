import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/home_furniture_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/home_layout.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/farm_animal.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/home_interior_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/resident_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/sky_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// The player house and sleeping (docs/specs/player_house.md).
/// Head tiles of the beds of the default layout.
final _beds = [
  for (final p in kDefaultHomePieces)
    if (furniture(p.id)?.kind == FurnitureKind.bed) (p.x, p.y)
];

void main() {
  final errors = <String>[];
  setUp(() {
    errors.clear();
    SessionEngine.onRuleError = (rule, e, st) => errors.add('$rule: $e');
  });
  tearDown(() {
    SessionEngine.onRuleError = null;
    expect(errors, isEmpty);
  });
  /// [town] with [id] placed at the first spot where it fits.
  TownState placed(TownState town, String id) {
    for (var y = 2; y < 24; y++) {
      for (var x = 2; x < 34; x++) {
        final t = TownRules.place(town, id, x, y).town;
        if (t != null) return t;
      }
    }
    fail('no spot for $id');
  }

  TownState withNight(TownState t, {bool night = true}) => t.copyWith(
      sky: (t.sky.started ? t.sky : SkyRules.start(() => 0.5)).copyWith(
          clock: night ? SkyRules.daySec + 60 : SkyRules.daySec * 0.3));

  /// Two players inside the house, each next to a bed; [town] is used as
  /// the world town.
  (SessionEngine, GameSession) inside(TownState Function(TownState) town,
      {int players = 2}) {
    final e = sessionEngine();
    var s = e.create();
    for (var i = 0; i < players; i++) {
      s = e.addPlayer(s, 'p$i',
              newProfile('P$i', 'guerrero').copyWith(credits: 9000))!
          .state;
    }
    s.town = placed(town(s.town), kPlayerHouseId);
    s = act(e, s, 'p0', const TravelAction(HomeInteriorRules.place));
    expect(s.place, HomeInteriorRules.place);
    var i = 0;
    for (final p in s.players.values) {
      final (bx, by) = _beds[i++];
      p
        ..x = bx * 16 + 8.0
        ..y = (by + 2) * 16 + 4.0;
    }
    return (e, s);
  }

  test('the house is a palette piece with a gold cost and its own door', () {
    final d = construction(kPlayerHouseId)!;
    expect(d.kind, BuildKind.home);
    expect(HomeInteriorRules.price, greaterThan(0));
    final town = placed(const TownState(), kPlayerHouseId);
    final b = HomeInteriorRules.housesOf(town).single;
    final m = MapGenerator.townOf(town);
    final (dx, dy) = HomeInteriorRules.doorOf(b);
    final (ox, oy) = town.origin;
    expect(m.tileAt(dx + ox, dy + oy), Tile.homeDoor);
    expect(Tile.isWalkable(Tile.homeDoor), isFalse);
    final f = HomeInteriorRules.townFront(town);
    expect(WorldRules.townSpot(f.x, f.y, map: m), TownSpot.home);
  });

  test('building costs gold, only one per town, never over other things', () {
    final e = sessionEngine();
    var s = e.create();
    s = e.addPlayer(s, 'p0', newProfile('Ana', 'guerrero').copyWith(credits: 9000))!
        .state;
    final spot = placed(s.town, kPlayerHouseId);
    final b = HomeInteriorRules.housesOf(spot).single.bounds;
    final (ox, oy) = s.town.origin;
    s = act(e, s, 'p0',
        TownAction(TownOp.place, id: kPlayerHouseId, x: b.x + ox, y: b.y + oy));
    expect(HomeInteriorRules.housesOf(s.town), hasLength(1));
    expect(s.players['p0']!.profile.credits, 9000 - HomeInteriorRules.price);
    // A second one is refused (one per town).
    expect(HomeInteriorRules.cannotBuild(s.players['p0']!.profile, s.town),
        isNotNull);
    // Nothing on top of it.
    expect(TownRules.place(s.town, 'huerta_chica', b.x + ox, b.y + oy).town,
        isNull);
    // Not enough gold.
    final poor = newProfile('Beto', 'maga').copyWith(credits: 0);
    expect(HomeInteriorRules.cannotBuild(poor, const TownState()), isNotNull);
  });

  test('enter and leave the house; the interior has no sky', () {
    final (e, s0) = inside((t) => t);
    final map = e.mapFor(s0);
    expect(map.place, HomeInteriorRules.place);
    expect(SkyRules.outdoor(map.theme, town: map.lobby), isFalse);
    for (final p in s0.players.values) {
      expect(Tile.isWalkable(map.tileAt(p.x ~/ 16, p.y ~/ 16)), isTrue);
    }
    final s = act(e, s0, 'p0', const TravelAction(kPueblo));
    expect(s.place, isNull);
  });

  test('sleeping at night skips to the next morning with the normal step',
      () {
    final (e, s0) = inside((t) {
      var town = withNight(t);
      // A ripe-able crop, planted and watered.
      town = town.copyWith(builds: [
        kBaseFarm.copyWith(plots: {
          plotKey(0, 0): FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!,
        }),
      ]);
      return town;
    });
    final day = s0.town.sky.day;
    final grow0 = s0.town.plots.values.single.grow;
    var s = act(e, s0, 'p0', const SleepAction(true));
    expect(s.players['p0']!.inBed, isTrue);
    // One of two in bed: nothing skips, the wait count shows.
    s = e.tick(s, 0.1).state;
    expect(s.sleepWait, (1, 2));
    expect(SkyRules.isNight(s.town.sky), isTrue);
    s = act(e, s, 'p1', const SleepAction(true));
    final step = e.tick(s, 0.1);
    s = step.state;
    expect(step.events.whereType<SleptEvent>().single.toMorning, isTrue);
    expect(SkyRules.isNight(s.town.sky), isFalse);
    expect(s.town.sky.day, day + 1);
    expect(s.town.sky.clock,
        closeTo(HomeInteriorRules.wakeClock(toMorning: true), 1.5));
    expect(s.players.values.every((p) => !p.inBed), isTrue);
    expect(s.sleepWait, isNull);
    // Crops grew through the skipped night.
    expect(s.town.plots.values.single.grow, greaterThan(grow0 + 100));
  });

  test('by day the bed sleeps until nightfall', () {
    final (e, s0) = inside((t) => withNight(t, night: false), players: 1);
    var s = act(e, s0, 'p0', const SleepAction(true));
    s = e.tick(s, 0.1).state;
    expect(SkyRules.isNight(s.town.sky), isTrue);
    expect(s.town.sky.clock,
        closeTo(HomeInteriorRules.wakeClock(toMorning: false), 1.5));
  });

  test('NPCs match the target hour: residents go home at night', () {
    String? npc;
    final (e, s0) = inside((t) {
      var town = withNight(t, night: false);
      town = ResidentRules.invite(
          town.withResident(const ResidentState('ilda', rep: 3)), 'ilda',
          time: 1)!;
      town = placed(town, kCasaId);
      town = ResidentRules.assign(
          town, 'ilda', ResidentRules.freeHouses(town).single.id)!;
      npc = 'ilda';
      return town;
    }, players: 1);
    bool out(GameSession s) =>
        ResidentRules.position(s.town, npc!, s.time,
            night: SkyRules.isNight(s.town.sky)) !=
        null;
    expect(out(s0), isTrue);
    var s = act(e, s0, 'p0', const SleepAction(true));
    s = e.tick(s, 0.1).state;
    expect(SkyRules.isNight(s.town.sky), isTrue);
    // At night the resident is inside her house (or on her night out,
    // which the same rules decide for that day).
    expect(out(s), ResidentRules.nightOut(s.town, npc!));
  });

  test('animals produce over the skipped night', () {
    final (e, s0) = inside((t) {
      var town = placed(withNight(t), 'gallinero');
      final coop = town.builds.firstWhere((b) => b.kind == BuildKind.gallinero);
      town = town.withBuild(coop.copyWith(animals: [
        FarmAnimal(0, 'gallina', fed: town.sky.day, cycle: 50),
      ]));
      return town;
    }, players: 1);
    var s = act(e, s0, 'p0', const SleepAction(true));
    s = e.tick(s, 0.1).state;
    final a = s.town.builds
        .firstWhere((b) => b.kind == BuildKind.gallinero)
        .animals
        .single;
    expect(a.ready, isNotNull);
  });

  test('co-op across rooms: the skip waits for every player', () {
    final e = sessionEngine(freeMovement: true);
    final we = WorldEngine(e);
    var town = e.create();
    town.town = withNight(placed(town.town, kPlayerHouseId));
    final w = we.create(town);
    we.addPlayer(w, 'p0', newProfile('Ana', 'guerrero'));
    we.addPlayer(w, 'p1', newProfile('Beto', 'maga'));
    expect(we.apply(w, 'p0', const TravelAction(HomeInteriorRules.place)),
        isNotNull);
    final home = w.rooms[HomeInteriorRules.place]!;
    final p0 = home.players['p0']!;
    final (bx, by) = _beds.first;
    p0
      ..x = bx * 16 + 8.0
      ..y = (by + 2) * 16 + 4.0;
    expect(we.apply(w, 'p0', const SleepAction(true)), isNotNull);
    we.tick(w, 0.1);
    // p1 is still in town: the night goes on and p0 sees 1/2.
    expect(SkyRules.isNight(w.town.town.sky), isTrue);
    expect(w.rooms[HomeInteriorRules.place]!.sleepWait, (1, 2));
    // p1 comes in and lies down too: the world skips to the morning.
    expect(we.apply(w, 'p1', const TravelAction(HomeInteriorRules.place)),
        isNotNull);
    final p1 = w.rooms[HomeInteriorRules.place]!.players['p1']!;
    final (cx, cy) = _beds[1];
    p1
      ..x = cx * 16 + 8.0
      ..y = (cy + 2) * 16 + 4.0;
    expect(we.apply(w, 'p1', const SleepAction(true)), isNotNull);
    final step = we.tick(w, 0.1);
    expect(SkyRules.isNight(w.town.town.sky), isFalse);
    expect(w.rooms[HomeInteriorRules.place]!.town.sky.clock,
        w.town.town.sky.clock);
    expect(step.eventsFor('p0').whereType<SleptEvent>(), isNotEmpty);
    expect(
        w.rooms[HomeInteriorRules.place]!.players.values.any((p) => p.inBed),
        isFalse);
  });

  test('in bed and the wait count travel in the snapshot', () {
    final (e, s0) = inside((t) => withNight(t));
    var s = act(e, s0, 'p0', const SleepAction(true));
    s = e.tick(s, 0.1).state;
    const codec = SessionJson();
    final back = codec.fromJson(codec.toJson(s));
    expect(back.players['p0']!.inBed, isTrue);
    expect(back.sleepWait, (1, 2));
  });

  test('walking away from the bed gets the player up', () {
    final (e, s0) = inside((t) => withNight(t));
    var s = act(e, s0, 'p0', const SleepAction(true));
    s.players['p0']!
      ..x = HomeInteriorRules.arrival.x
      ..y = HomeInteriorRules.arrival.y;
    s = e.tick(s, 0.1).state;
    expect(s.players['p0']!.inBed, isFalse);
    // Far from any bed it cannot lie down.
    expect(e.apply(s, 'p0', const SleepAction(true)), isNull);
  });
}
