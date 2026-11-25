import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/fish_line.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart' show RandomSource;
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_time_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/raft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Lake rafts and open water (docs/specs/fishing.md § 15).
void main() {
  tearDown(() => BiomeRegions.bind(0));

  /// A world seed whose Forest has a giant lake with a raft dock.
  int forestSeed() {
    for (var seed = 0; seed < 60; seed++) {
      BiomeRegions.bind(seed);
      if (biomeLayout(kBosque)!.raftDocks.isNotEmpty) return seed;
    }
    fail('no forest raft dock in 60 seeds');
  }

  (SessionEngine, GameSession, BiomeLayout) inForest(
      {RandomSource? random, int players = 1}) {
    final seed = forestSeed();
    final e = random == null
        ? sessionEngine(zones: true, seed: seed)
        : SessionEngine(
            battles: sessionEngine().battles,
            progression: zoneProgression,
            random: random,
            seeds: () => seed,
            ecoRandom: () => 0.999);
    var s = e.create();
    s = s.copy()
      ..town = s.town.copyWith(sky: s.town.sky.copyWith(seed: seed, day: 1));
    for (var i = 0; i < players; i++) {
      s = e.addPlayer(s, 'p$i', newProfile('J$i', 'guerrero'))!.state;
    }
    for (var i = 0; i < players; i++) {
      if (s.place == kBosque) continue;
      s = act(e, s, 'p$i', const TravelAction(kBosque));
    }
    expect(s.town.sky.seed, seed);
    BiomeRegions.bind(seed);
    return (e, s, biomeLayout(kBosque)!);
  }

  GameSession toDock(SessionEngine e, GameSession s, RaftDock d, String id) =>
      moveTo(e, s, id, (d.x + 0.5) * 16, (d.y + 0.5) * 16);

  /// The deepest water tile of the dock's lake (center px) and its depth.
  ((double, double), int) deepest(GameMap m, BiomeLayout lay, RaftDock d) {
    var best = (0.0, 0.0);
    var bd = -1;
    for (final (x, y) in RaftRules.lakeTiles(lay, lay.lakes[d.lake])) {
      final v = RaftRules.depth(m, x, y);
      if (v > bd) (bd, best) = (v, ((x + 0.5) * 16, (y + 0.5) * 16));
    }
    return (best, bd);
  }

  test('every giant lake gets one deterministic dock; small lakes none', () {
    for (var seed = 0; seed < 20; seed++) {
      BiomeRegions.bind(seed);
      for (final lay in kBiomeLayouts.values) {
        final giants = [
          for (var i = 0; i < lay.lakes.length; i++)
            if (lay.lakes[i].giant) i
        ];
        final docks = lay.raftDocks;
        expect([for (final d in docks) d.lake], containsAll(giants),
            reason: '$seed ${lay.id}');
        for (final d in docks) {
          final area =
              RaftRules.lakeTiles(lay, lay.lakes[d.lake]).length;
          expect(RaftRules.isBig(lay.lakes[d.lake], area), isTrue);
          expect(Tile.isWalkable(lay.baseTile(d.x, d.y)), isTrue);
          expect(lay.baseTile(d.wx, d.wy), Tile.water);
          expect((d.x - d.wx).abs() + (d.y - d.wy).abs(), 1);
        }
        // Same seed, same docks (a fresh layout).
        BiomeRegions.bind(seed + 1000);
        BiomeRegions.bind(seed);
        expect(biomeLayout(lay.id)!.raftDocks, docks);
      }
    }
  });

  test('E at the dock boards; raft steers on water only; E at shore gets off',
      () {
    var (e, s, lay) = inForest();
    final d = lay.raftDocks.first;
    final m = MapGenerator.biome(lay, const {});
    // Away from the dock: nothing.
    expect(e.apply(s, 'p0', const RaftAction(true)), isNull);
    s = toDock(e, s, d, 'p0');
    final ep = s.players['p0']!.epoch;
    s = act(e, s, 'p0', const RaftAction(true));
    final p = s.players['p0']!;
    expect(p.rafting, isTrue);
    expect(p.epoch, ep + 1);
    expect((p.x, p.y), (RaftRules.launch(d).x, RaftRules.launch(d).y));
    // Boarding twice does nothing.
    expect(e.apply(s, 'p0', const RaftAction(true)), isNull);

    // Steering toward the dock (onto land) never leaves the water.
    var x = p.x, y = p.y;
    for (var i = 0; i < 120; i++) {
      final n = RaftRules.step(m, x, y, (d.x - d.wx).toDouble(),
          (d.y - d.wy).toDouble(), 1 / 30);
      x = n.x;
      y = n.y;
      expect(RaftRules.collides(m, x, y), isFalse);
    }
    // Raft speed is the tunable × walking speed.
    final far = RaftRules.step(m, p.x, p.y, (d.wx - d.x).toDouble(),
        (d.wy - d.y).toDouble(), 0.1);
    expect(WorldRules.distance(p.x, p.y, far.x, far.y),
        closeTo(WorldRules.playerSpeed * RaftRules.speedMult * 0.1, 0.01));

    // The host rejects a raft position on land.
    expect(
        e.apply(s, 'p0',
            MoveAction((d.x + 0.5) * 16, (d.y + 0.5) * 16, epoch: ep + 1)),
        isNull);

    // Out in the middle: too far to get off.
    final ((mx, my), depth) = deepest(m, lay, d);
    expect(depth, greaterThanOrEqualTo(4));
    s = moveTo(e, s, 'p0', mx, my);
    expect(s.players['p0']!.rafting, isTrue);
    expect(e.apply(s, 'p0', const RaftAction(false)), isNull);

    // Back by the dock: off onto the nearest free land tile.
    s = moveTo(e, s, 'p0', RaftRules.launch(d).x, RaftRules.launch(d).y);
    s = act(e, s, 'p0', const RaftAction(false));
    final off = s.players['p0']!;
    expect(off.rafting, isFalse);
    expect(off.raftEpoch, 0);
    expect(WorldRules.collides(m, off.x, off.y), isFalse);
    expect(WorldRules.distance(off.x, off.y, RaftRules.launch(d).x,
            RaftRules.launch(d).y),
        lessThan(24));
  });

  test('two players raft at once; a teleport leaves the raft', () {
    var (e, s, lay) = inForest(players: 2);
    final d = lay.raftDocks.first;
    for (final id in ['p0', 'p1']) {
      s = toDock(e, s, d, id);
      s = act(e, s, id, const RaftAction(true));
    }
    expect(s.players.values.every((p) => p.rafting), isTrue);
    // Snapshot round trip keeps the raft.
    const js = SessionJson();
    final back = js.fromJson(js.toJson(s));
    expect(back.players['p1']!.rafting, isTrue);
    // Travel home: new epoch, no raft.
    s = act(e, s, 'p0', const TravelAction(kPueblo));
    expect(s.players.values.any((p) => p.rafting), isFalse);
  });

  test('action JSON round trip', () {
    for (final on in [true, false]) {
      final a = ActionJson.fromJson(ActionJson.toJson(RaftAction(on)));
      expect((a as RaftAction).on, on);
    }
  });

  test('depth gates the open-water species and adds rarity / size', () {
    expect(deepFishOf(kBosque, 3), isEmpty);
    expect(deepFishOf(kBosque, 4), ['lucio_hondo']);
    expect(deepFishOf(kBosque, 9), ['lucio_hondo', 'carpa_olvido']);
    for (final b in kBiomeBases.keys) {
      expect(deepFishOf(b, 9), hasLength(2), reason: b);
      for (final id in deepFishOf(b, 9)) {
        expect(b == kBosque || !kBiomeBases[b]!.fish.contains(id), isTrue);
      }
    }
    expect(RaftRules.depthRare(1), 0);
    expect(RaftRules.depthRare(4), greaterThan(RaftRules.depthRare(2)));
    expect(RaftRules.depthRare(99), RaftRules.t.d('deepRareMax'));
    expect(RaftRules.depthSize(99), RaftRules.t.d('deepSizeMax'));
  });

  test('fishing from the raft in deep water catches open-water species', () {
    final rng = math.Random(7);
    var (e, s, lay) = inForest(random: rng.nextDouble);
    final d = lay.raftDocks.first;
    final m = MapGenerator.biome(lay, const {});
    s = toDock(e, s, d, 'p0');
    s = act(e, s, 'p0', const RaftAction(true));
    final ((mx, my), _) = deepest(m, lay, d);
    s = moveTo(e, s, 'p0', mx, my);
    s = act(e, s, 'p0',
        FishLineAction(FishLine(FishLineStage.line, bx: mx, by: my)));
    // A time of day when the open-water pike bites (fishing.md § 13).
    var sky = s.town.sky;
    for (var c = 0.0; c < 4000; c += 20) {
      sky = s.town.sky.copyWith(clock: c);
      if (LifeTimeRules.fishActive('lucio_hondo', sky)) break;
    }
    final deep = {...deepFishOf(kBosque, 99)};
    final seen = <String>{};
    for (var i = 0; i < 300; i++) {
      s = wait(e, s, 2.1);
      s = s.copy()..town = s.town.copyWith(sky: sky);
      final r = e.apply(s, 'p0', const FishBiteAction(1));
      if (r == null) continue;
      s = r.state;
      for (final ev in r.events.whereType<FishBiteEvent>()) {
        seen.add(ev.species);
      }
    }
    expect(seen.intersection(deep), isNotEmpty, reason: '$seen');
  });
}
