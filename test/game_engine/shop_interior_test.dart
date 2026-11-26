import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/player_stall.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/shop_interior_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Shop interior (docs/specs/player_shop.md § 6).
void main() {
  const fish = 'fish:carpa_musgo';

  PlayerProfile seller(String name) {
    final p = newProfile(name, 'guerrero');
    return p.copyWith(
        credits: 5000,
        life: p.life.copyWith(
            stall: PlayerStall(
                listings: const [StallListing(fish, 3, 10)], earned: 7)));
  }

  (SessionEngine, GameSession) two() {
    final e = sessionEngine();
    var s = e.addPlayer(e.create(), 'p0', seller('Ana'))!.state;
    s = e.addPlayer(s, 'p1', newProfile('Beto', 'maga').copyWith(credits: 5000))!.state;
    return (e, s);
  }

  test('the town has the TIENDA house and no outdoor counter', () {
    expect(TownLayout.landmarks.where((l) => l.spot == TownSpot.stall),
        isEmpty);
    final l = TownLayout.landmark(TownSpot.shop);
    expect((l.w, l.h, l.tile), (3, 3, Tile.shop));
    final m = MapGenerator.townOf(const TownState());
    expect(m.tileAt(l.x + 1, l.y + 1), Tile.shop);
    expect(
        WorldRules.townSpot(l.center.x, (l.y + l.h) * 16 + 4.0, map: m),
        TownSpot.shop);
  });

  test('enter and leave the shop instance', () {
    final (e, s0) = two();
    var s = act(e, s0, 'p0', const TravelAction(ShopInteriorRules.place));
    expect(s.place, ShopInteriorRules.place);
    final map = e.mapFor(s);
    expect(map.place, ShopInteriorRules.place);
    expect(map.lobby, isTrue);
    for (final p in s.players.values) {
      expect(Tile.isWalkable(map.tileAt(p.x ~/ 16, p.y ~/ 16)), isTrue);
      expect((p.y - ShopInteriorRules.arrival.y).abs(), lessThan(1));
    }
    // Only back to town from inside.
    expect(e.apply(s, 'p0', const TravelAction(kBosque)), isNull);
    s = act(e, s, 'p0', const TravelAction(kPueblo));
    expect(s.place, isNull);
    final front = ShopInteriorRules.townFront(TownPlan.landmarksOf(s.town));
    expect((s.players['p0']!.y - front.y).abs(), lessThan(1));
    // Not from a biome.
    s = act(e, s, 'p0', const TravelAction(kBosque));
    expect(e.apply(s, 'p0', const TravelAction(ShopInteriorRules.place)),
        isNull);
  });

  test('one counter per player; another player can buy at it', () {
    final (e, s0) = two();
    var s = act(e, s0, 'p0', const TravelAction(ShopInteriorRules.place));
    final owners = ShopInteriorRules.owners(s.players.values);
    expect(owners, ['p0', 'p1']);
    final (tx, ty) = ShopInteriorRules.counterTiles[0];
    final x = (tx + 1) * 16.0, y = (ty + 1) * 16 + 4.0;
    expect(ShopInteriorRules.counterNear(x, y), 0);
    expect(WorldRules.townSpot(x, y, map: e.mapFor(s)), TownSpot.stall);
    s = act(e, s, 'p1', const StallAction(StallOp.buy, fish, qty: 2, owner: 'p0'));
    expect(s.players['p0']!.profile.life.stall.listing(fish)!.qty, 1);
    expect(s.players['p1']!.profile.life.count('carpa_musgo'), 2);
  });

  test('a saved town with something on the house spot moves it; stall kept',
      () {
    final l = TownLayout.landmark(TownSpot.shop);
    // An old town: a build where the house goes, and the old counter's
    // mark (`@stall`, gone now) still in the save.
    final old = const TownState().copyWith(builds: [
      ...kDefaultBuilds,
      TownBuild('h9', BuildKind.huerta, [TownRect(l.x, l.y, 3, 3)]),
    ], marks: {
      '@stall': (19, 15)
    });
    final town = TownState.fromJson(old.toJson());
    final marks = TownPlan.landmarksOf(town);
    expect(marks.where((m) => m.spot == TownSpot.stall), isEmpty);
    final h = marks.firstWhere((m) => m.spot == TownSpot.shop);
    expect((h.x, h.y), isNot((l.x, l.y)));
    expect(town.build('h9')!.parts.single.overlaps(TownRect(h.x, h.y, 3, 3)),
        isFalse);
    final p = seller('Ana');
    final back = PlayerProfile.fromJson(p.toJson());
    expect(back.life.stall.listing(fish), const StallListing(fish, 3, 10));
    expect(back.life.stall.earned, 7);
  });
}
