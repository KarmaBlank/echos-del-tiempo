import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/shop_interior_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Trees never block a door (docs/specs/town_editor.md § 4.5) and the
// landing safety net (docs/specs/player_shop.md § 6.4).
void main() {
  // A saved town whose owner moved the TIENDA so its door row falls on
  // the base tree at (3, 9): the v0.49.30 bug (stuck on leaving the shop).
  const moved = TownState(marks: {'@shop': (2, 6)});

  // An expanded town (base town offset inside the map).
  const expanded = TownState(sides: {TownSide.oeste: 1, TownSide.norte: 1});

  test('the reproduced town really has a base tree in front of the door', () {
    final l = TownPlan.landmarkOf(moved, TownSpot.shop);
    expect((l.x, l.y, l.w, l.h), (2, 6, 3, 3));
    expect(TownLayout.trees, contains((3, 9)));
    expect(TownPlan.doorClearance(moved), contains((3, 9)));
  });

  for (final (name, town) in [
    ('base town', const TownState()),
    ('moved shop', moved),
    ('expanded', expanded),
  ]) {
    test('$name: no tree on any door row or exit landing', () {
      final map = MapGenerator.town(town);
      final (ox, oy) = map.townOrigin;
      for (final (x, y) in TownPlan.doorClearance(town)) {
        final mx = x + ox, my = y + oy;
        // The forest border around the map is not decor.
        if (mx <= 1 || my <= 0 || mx >= map.width - 2 || my >= map.height - 1) {
          continue;
        }
        expect(map.tileAt(mx, my), isNot(Tile.tree), reason: '($x, $y)');
      }
      final p =
          ShopInteriorRules.townFront(TownPlan.landmarksOf(town), town.origin);
      expect(WorldRules.collides(map, p.x, p.y), isFalse);
    });
  }

  test('safeLanding keeps a free point and moves a blocked one', () {
    final map = GameMap(
      width: 5,
      height: 5,
      rows: const ['#####', '#.T.#', '#...#', '#...#', '#####'],
      theme: TownLayout.theme,
      spawn: const WorldPoint(40, 40),
      lobby: true,
    );
    const free = WorldPoint(2 * 16 + 8.0, 3 * 16 + 8.0);
    expect(WorldRules.safeLanding(map, free), free);
    const onTree = WorldPoint(2 * 16 + 8.0, 1 * 16 + 8.0);
    expect(WorldRules.collides(map, onTree.x, onTree.y), isTrue);
    final out = WorldRules.safeLanding(map, onTree);
    expect(WorldRules.collides(map, out.x, out.y), isFalse);
    expect((out.x - onTree.x).abs() + (out.y - onTree.y).abs(),
        lessThanOrEqualTo(32));
  });

  test('landing back in town and inside the shop is always walkable', () {
    for (final town in [const TownState(), moved, expanded]) {
      final map = MapGenerator.town(town);
      final f =
          ShopInteriorRules.townFront(TownPlan.landmarksOf(town), town.origin);
      final p = ShopInteriorRules.safeLanding('pueblo', town, f);
      expect(WorldRules.collides(map, p.x, p.y), isFalse);
    }
    final inside = ShopInteriorRules.safeLanding(
        ShopInteriorRules.place, const TownState(), ShopInteriorRules.arrival);
    expect(inside, ShopInteriorRules.arrival);
  });
}
