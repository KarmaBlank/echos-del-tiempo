import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/path_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart' show Tile;
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/renown.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/autotile.dart';
import 'package:echos_del_tiempo/game_engine/rules/path_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Town paths (town_editor.md § 4.1, § 4.6): auto-routing from every
// door, hand-drawn paths, their costs and locks, and the host op.

/// A town whose level is [level] (1 Caserío, 2 Aldea, 3 Pueblo).
TownState _town(int level) => TownState(
    renown: RenownState(lore: switch (level) { 1 => 0, 2 => 12, _ => 30 }));

/// The first spot (scanning rows) where a house fits with its door
/// tile free and away from any path (map coordinates).
TownState _withHouse(TownState t) {
  for (var y = 2; y < 20; y++) {
    for (var x = 4; x < 30; x++) {
      final r = TownRules.place(t, kCasaId, x, y);
      final n = r.town;
      if (n == null) continue;
      final (dx, dy) = TownPlan.doorOf(n.build(r.id!)!.bounds);
      final (ox, oy) = n.origin;
      final before = TownPlan.of(t);
      if (before.at(dx + ox, dy + oy) != Tile.grass) continue;
      if (TownPlan.of(n).routed.length < 2) continue;
      return n;
    }
  }
  fail('no spot for a house');
}

/// The first free grass tile (base-town coordinates) for a path.
(int, int) _grass(TownState t) {
  final (ox, oy) = t.origin;
  for (var y = 2; y < 20; y++) {
    for (var x = 3; x < 31; x++) {
      if (TownPlan.of(t).at(x + ox, y + oy) == Tile.grass &&
          PathRules.tileError(t, x, y) == null) {
        return (x, y);
      }
    }
  }
  fail('no grass');
}

/// Path tiles connected to the fixed network (map coordinates).
Set<(int, int)> _net(TownPlan p, TownState s) {
  final (ox, oy) = s.origin;
  final seen = <(int, int)>{};
  final stack = [
    for (final r in TownPlan.fixedPaths(s)) (r.x + ox, r.y + oy),
  ];
  while (stack.isNotEmpty) {
    final (x, y) = stack.removeLast();
    if (p.at(x, y) != Tile.path || !seen.add((x, y))) continue;
    stack.addAll([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]);
  }
  return seen;
}

PlayerProfile _rich({int gold = 1000, int bronze = 10}) =>
    PlayerProfile(name: 'Ana', classId: 'guerrero', credits: gold).copyWith(
        life: LifeSkills(ores: {'ore_bronze': bronze, 'ore_copper': 10}));

void main() {
  group('auto paths', () {
    test('a placed house gets a path from its door to the square', () {
      final t = _withHouse(const TownState());
      final house = t.builds.firstWhere((b) => b.kind == BuildKind.casa);
      final plan = TownPlan.of(t);
      final (ox, oy) = t.origin;
      final (dx, dy) = TownPlan.doorOf(house.bounds);
      expect(plan.at(dx + ox, dy + oy), Tile.path);
      expect(_net(plan, t).contains((dx + ox, dy + oy)), isTrue);
      expect(plan.unreached, isEmpty);
      expect(plan.routed, isNotEmpty);
    });

    test('moving the house re-routes its path (deterministic)', () {
      final t = _withHouse(const TownState());
      final house = t.builds.firstWhere((b) => b.kind == BuildKind.casa);
      final (ox, oy) = t.origin;
      TownState? moved;
      for (var dx = 3; dx < 12 && moved == null; dx++) {
        moved = TownRules.move(t, house.id, house.anchor.$1 + ox + dx,
                house.anchor.$2 + oy)
            .town;
      }
      expect(moved, isNotNull);
      final a = TownPlan.of(moved!), b = TownPlan.of(t);
      expect(a.routed, isNot(equals(b.routed)));
      final h2 = moved.build(house.id)!;
      final (dx, dy) = TownPlan.doorOf(h2.bounds);
      expect(_net(a, moved).contains((dx + ox, dy + oy)), isTrue);
      // Same state, same plan: the router has no randomness.
      TownPlan.of(const TownState()); // evict nothing, just touch the cache
      expect(TownPlan.of(TownState.fromJson(moved.toJson())).routed,
          equals(a.routed));
    });

    test('the router reuses a hand-drawn path instead of a new one', () {
      final t = _withHouse(const TownState());
      final house = t.builds.firstWhere((b) => b.kind == BuildKind.casa);
      final auto = TownPlan.of(t).routed;
      // Hand-draw the very same tiles: the router lays nothing new.
      final (ox, oy) = t.origin;
      final hand = t.copyWith(paths: {
        for (final (x, y) in auto) (x - ox, y - oy): 'stone',
      });
      final p = TownPlan.of(hand);
      expect(p.routed, isEmpty);
      final (dx, dy) = TownPlan.doorOf(house.bounds);
      expect(_net(p, hand).contains((dx + ox, dy + oy)), isTrue);
      expect(p.materialAt(dx + ox, dy + oy), 'stone');
    });

    test('a hand path under a building is hidden, not lost', () {
      const t = TownState();
      final lake = t.builds.firstWhere((b) => b.id == 'l0');
      final (lx, ly) = lake.anchor;
      final s = t.copyWith(paths: {(lx + 1, ly + 1): 'dirt'});
      final (ox, oy) = s.origin;
      expect(TownPlan.of(s).hand.containsKey((lx + 1 + ox, ly + 1 + oy)),
          isFalse);
      expect(s.paths, hasLength(1));
    });
  });

  group('materials, costs and locks', () {
    test('dirt is the default and always unlocked', () {
      expect(kTownPaths.first.id, kDefaultPath);
      expect(PathRules.cost(kTownPaths.first).level, 1);
      expect(PathRules.lock(_rich(), _town(1), kTownPaths.first), isNull);
    });

    test('stone needs town level 2, runic cobble level 3 and ore', () {
      final stone = townPath('stone')!, rune = townPath('rune')!;
      expect(PathRules.townLevel(_town(1)), 1);
      expect(PathRules.townLevel(_town(2)), 2);
      expect(PathRules.townLevel(_town(3)), 3);
      final l = PathRules.lock(_rich(), _town(1), stone)!;
      expect((l.kind, l.need, l.have), (PathLockKind.level, 2, 1));
      expect(PathRules.lock(_rich(), _town(2), stone), isNull);
      expect(PathRules.lock(_rich(), _town(2), rune)!.kind,
          PathLockKind.level);
      expect(PathRules.lock(_rich(), _town(3), rune), isNull);
      final ore = PathRules.lock(_rich(bronze: 0), _town(3), rune)!;
      expect((ore.kind, ore.item, ore.have, ore.need),
          (PathLockKind.ore, 'ore_bronze', 0, 1));
      final gold = PathRules.lock(_rich(gold: 1), _town(3), rune)!;
      expect(gold.kind, PathLockKind.gold);
    });

    test('the CAMINOS tool starts on the best material unlocked', () {
      expect(PathRules.bestUnlocked(_town(1)).id, 'dirt');
      expect(PathRules.bestUnlocked(_town(2)).id, 'stone');
      expect(PathRules.bestUnlocked(_town(3)).id, 'rune');
    });

    test('painting pays per tile; erasing only hand-drawn tiles', () {
      final t = _town(3);
      final (ox, oy) = t.origin;
      final at = _grass(t);
      final c = PathRules.cost(townPath('rune')!);
      final r = PathRules.paint(_rich(), t, 'rune', at.$1 + ox, at.$2 + oy)!;
      expect(r.$1.credits, 1000 - c.gold);
      expect(r.$1.life.ore('ore_bronze'), 10 - c.ore);
      expect(r.$2.paths[at], 'rune');
      // Same material again: nothing to pay.
      expect(PathRules.paint(r.$1, r.$2, 'rune', at.$1 + ox, at.$2 + oy),
          isNull);
      expect(TownPlan.of(r.$2).materialAt(at.$1 + ox, at.$2 + oy), 'rune');
      final e = PathRules.erase(r.$2, at.$1 + ox, at.$2 + oy)!;
      expect(e.paths, isEmpty);
      // A fixed path is the town's.
      final f = TownPlan.fixedPaths(t).first;
      expect(PathRules.eraseError(t, f.x + ox, f.y + oy), isNotNull);
      // Not on a place nor out of the town.
      final lake = t.builds.first;
      expect(PathRules.tileError(t, lake.anchor.$1, lake.anchor.$2), isNotNull);
      expect(PathRules.tileError(t, -ox, -oy), isNotNull);
    });

    test('pieces autotile per material', () {
      final t = _town(3);
      final (ox, oy) = t.origin;
      final s = t.copyWith(paths: {
        (5, 4): 'stone',
        (6, 4): 'stone',
        (7, 4): 'rune',
      });
      final p = TownPlan.of(s);
      expect(PathRules.mask(p, 6 + ox, 4 + oy), Autotile.w);
      expect(PathRules.mask(p, 7 + ox, 4 + oy), 0);
      // No path: no piece.
      expect(PathRules.mask(p, 6 + ox, 3 + oy), 0);
      expect(townPath('stone')!.sprite(5), 'path_stone_5');
    });

    test('saves: pth round-trips; old stone_path decor becomes stone', () {
      final s = const TownState().copyWith(paths: {(5, 24): 'rune'});
      expect(TownState.fromJson(s.toJson()).paths, {(5, 24): 'rune'});
      final old = TownState.fromJson({
        'dc': [
          ['stone_path', 3, 22],
          ['fence', 4, 22],
        ],
      });
      expect(old.paths, {(3, 22): 'stone'});
      expect(old.decor, [('fence', 4, 22)]);
    });
  });

  test('host: paintPath / erasePath need the lock and the level', () {
    final e = sessionEngine();
    var s = e
        .addPlayer(e.create(), 'p0',
            newProfile('Ana', 'guerrero').copyWith(credits: 500))!
        .state;
    s = e.addPlayer(s, 'p1', newProfile('Beto', 'maga'))!.state;
    final (ox, oy) = s.town.origin;
    final at = _grass(s.town);
    final mx = at.$1 + ox, my = at.$2 + oy;
    s = act(e, s, 'p0', const TownAction(TownOp.lock));
    // Someone else holds the lock: refused.
    expect(
        e.apply(s, 'p1',
            TownAction(TownOp.paintPath, id: 'dirt', x: mx, y: my)),
        isNull);
    // Level 1 town: stone is locked.
    expect(
        e.apply(s, 'p0',
            TownAction(TownOp.paintPath, id: 'stone', x: mx, y: my)),
        isNull);
    s = act(e, s, 'p0', TownAction(TownOp.paintPath, id: 'dirt', x: mx, y: my));
    expect(s.town.paths[at], 'dirt');
    expect(s.players['p0']!.profile.credits,
        500 - PathRules.cost(townPath('dirt')!).gold);
    s = act(e, s, 'p0', TownAction(TownOp.erasePath, x: mx, y: my));
    expect(s.town.paths, isEmpty);
  });
}
