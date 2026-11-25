import 'package:echos_del_tiempo/features/world/presentation/hud/loot_feed.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/mine_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/goods_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/wild_loot_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Overworld ground loot (docs/specs/loot.md § 4c): chests, shrines and
/// harvests spill on the floor like dungeon chests.
void main() {
  tearDown(() => BiomeRegions.bind(0));

  /// One tick with p0 standing on each of its drops: (state, events).
  (GameSession, List<SessionEvent>) walkOver(SessionEngine e, GameSession s) {
    final log = <SessionEvent>[];
    for (final g in [...s.groundFor('p0')]) {
      s.players['p0']!
        ..x = g.x
        ..y = g.y;
      final step = e.tick(s, 0.05);
      log.addAll(step.events);
      s = step.state;
    }
    return (s, log);
  }

  BiomeLayout bindWithChestAndShrine() {
    for (var seed = 0; seed < 50; seed++) {
      BiomeRegions.bind(seed);
      final lay = bosqueLayout;
      if (lay.chestSpots.isNotEmpty && lay.shrines.isNotEmpty) return lay;
    }
    fail('no layout with a chest and a shrine');
  }

  (double, double) beside(GameMap map, int x, int y) {
    for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
      if (Tile.isWalkable(map.tileAt(x + dx, y + dy))) {
        return ((x + dx + 0.5) * 16, (y + dy + 0.5) * 16);
      }
    }
    fail('no walkable tile next to ($x, $y)');
  }

  test('biome chest: drops on the ground, nothing straight in; pickup adds '
      'and notifies', () {
    final lay = bindWithChestAndShrine();
    final e = sessionEngine(zones: true, groundLoot: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final map = e.mapFor(s);
    final (cx, cy) = lay.chestSpots.first;
    final at = beside(map, cx, cy);
    s = moveTo(e, s, 'p0', at.$1, at.$2);
    final before = s.players['p0']!.profile;
    final step = e.apply(s, 'p0', const WildLootAction(0))!;
    s = step.state;
    final after = s.players['p0']!.profile;
    expect(after.credits, before.credits, reason: 'gold is on the floor');
    final ore = kBiomeOres[kBosque]!.ore;
    expect(after.life.ore(ore), before.life.ore(ore));
    expect(after.items.length, before.items.length);
    final mine = s.groundFor('p0').toList();
    expect(mine.any((g) => g.drop.goods == GoodsRules.gold), isTrue);
    expect(mine.any((g) => g.drop.goods == 'ore:$ore'), isTrue);
    expect(mine.every((g) => g.ownerId == 'p0'), isTrue);
    // Around the chest, not at the player's feet.
    for (final g in mine) {
      expect((g.x - (cx + 0.5) * 16).abs(), lessThanOrEqualTo(16));
    }
    expect(
        step.events.whereType<LootDropEvent>().every((ev) => ev.groundId != null),
        isTrue);
    expect(WildLootRules.taken(s.town, 'Ana', lay.id, 0), isTrue);

    final (s2, log) = walkOver(e, s);
    final p = s2.players['p0']!.profile;
    expect(p.credits, greaterThan(before.credits));
    expect(p.life.ore(ore), before.life.ore(ore) + 2);
    final picked = log.whereType<LootPickedEvent>().toList();
    expect(picked.length, mine.length);
    expect(s2.groundFor('p0'), isEmpty);

    // The left notice: a `+` toast per pickup.
    final feed = LootFeed(
        localId: 'p0',
        playerName: (id) => id,
        itemName: GoodsRules.name,
        verdictFor: (_, __) => null,
        clock: () => 0);
    picked.where((ev) => ev.drop.isGoods).forEach(feed.onEvent);
    expect(feed.toasts.where((t) => t.title == '+').length,
        picked.where((ev) => ev.drop.isGoods).length);
    feed.dispose();
  });

  test('shrine: gold and the rare material drop in front of it', () {
    final lay = bindWithChestAndShrine();
    final e = sessionEngine(zones: true, groundLoot: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final (sx, sy) = lay.shrines.first;
    final at = beside(e.mapFor(s), sx, sy);
    s = moveTo(e, s, 'p0', at.$1, at.$2);
    final gold0 = s.players['p0']!.profile.credits;
    s = act(e, s, 'p0', const WildLootAction(0, shrine: true));
    expect(s.players['p0']!.profile.credits, gold0);
    final drops = s.groundFor('p0').toList();
    final gold = drops.where((g) => g.drop.goods == GoodsRules.gold).single;
    expect(gold.drop.count, WildLootRules.t.i('shrineGold'));
    final rare = kBiomeOres[kBosque]!.rare;
    expect(drops.any((g) => g.drop.goods == 'ore:$rare'), isTrue);
    for (final g in drops) {
      expect(g.y, greaterThan((sy + 0.5) * 16), reason: 'in front (below)');
    }
    final (s2, _) = walkOver(e, s);
    final p = s2.players['p0']!.profile;
    expect(p.credits, gold0 + WildLootRules.t.i('shrineGold'));
    expect(p.life.ore(rare), 1);
  });

  test('mine chest: spills on the ground like a dungeon chest', () {
    for (final lay in kBiomeLayouts.entries) {
      for (var i = 0; i < MiningRules.entrances(lay.value).length; i++) {
        final e = sessionEngine(zones: true, groundLoot: true);
        var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
            .state;
        s = act(e, s, 'p0', TravelAction(lay.key));
        s = act(e, s, 'p0', TravelAction(MiningRules.placeOf(lay.key, i)));
        final place = MiningRules.placeOf(lay.key, i);
        final lvl = MiningRules.level(place, worldId: s.worldId)!;
        final at = lvl.rows.join().indexOf(MineTile.chest);
        if (at < 0) continue;
        final (cx, cy) = lvl.xy(at);
        s.players['p0']!
          ..x = (cx + 0.5) * 16
          ..y = (cy + 1.5) * 16;
        final gold = s.players['p0']!.profile.credits;
        s = act(e, s, 'p0', MineAction(MineOp.use, x: cx, y: cy));
        expect(s.players['p0']!.profile.credits, gold);
        expect(s.groundFor('p0').map((g) => g.drop.goods),
            contains(GoodsRules.gold));
        final (s2, log) = walkOver(e, s);
        expect(s2.players['p0']!.profile.credits, greaterThan(gold));
        expect(log.whereType<LootPickedEvent>(), isNotEmpty);
        return;
      }
    }
    fail('no mine level has a chest');
  });

  test('forage pops out and the magnet picks it up', () {
    final e = sessionEngine(zones: true, groundLoot: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    for (var i = 0; i < 200 && s.town.sky.seed == 0; i++) {
      s = wait(e, s, 0.5);
    }
    e.mapFor(s);
    final lay = bosqueLayout;
    final fi = lay.forage.indexWhere(
        (f) => lay.base.forageKinds.contains(f.kind));
    final f = lay.forage[fi];
    s = moveTo(e, s, 'p0', (f.x + 0.5) * 16, (f.y + 1.5) * 16);
    final key = cropKey(kForageKinds[f.kind].item, CropQuality.normal);
    s = act(e, s, 'p0', ForageAction(fi));
    expect(s.players['p0']!.profile.life.farm.cropCount(key), 0,
        reason: 'it pops out first');
    final drop = s.groundFor('p0').where((g) => g.drop.goods == 'crop:$key');
    expect(drop, hasLength(1));
    // Not on the player, but within the magnet.
    final step = e.tick(s, 0.05);
    expect(step.state.players['p0']!.profile.life.farm.cropCount(key), 1);
    expect(step.events.whereType<LootPickedEvent>(), isNotEmpty);
    expect(step.state.groundFor('p0'), isEmpty);
  });

  test('travelling away returns what was left on the floor', () {
    final lay = bindWithChestAndShrine();
    final e = sessionEngine(zones: true, groundLoot: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final (sx, sy) = lay.shrines.first;
    final at = beside(e.mapFor(s), sx, sy);
    s = moveTo(e, s, 'p0', at.$1, at.$2);
    final gold0 = s.players['p0']!.profile.credits;
    s = act(e, s, 'p0', const WildLootAction(0, shrine: true));
    s = act(e, s, 'p0', const TravelAction(kPueblo));
    expect(s.ground, isEmpty);
    expect(s.players['p0']!.profile.credits,
        gold0 + WildLootRules.t.i('shrineGold'));
  });

  test('goods drops: wire round trip and always fit', () {
    final d = GoodsRules.ore('ore_copper', 3);
    final back = LootDrop.fromJson(d.toJson())!;
    expect((back.goods, back.count), ('ore:ore_copper', 3));
    expect(LootDrop.fromJson(GoodsRules.goldDrop(5).toJson())!.goods,
        GoodsRules.gold);
    final p = newProfile('Ana', 'guerrero');
    expect(GoodsRules.give(p, GoodsRules.goldDrop(5))!.credits, p.credits + 5);
    expect(GoodsRules.give(p, const LootDrop.goods('ore:nope', 1)), isNull);
  });
}
