import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/cooking_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// The town kitchen (docs/specs/farming.md § 17): a base-town landmark,
/// never behind a tree, with a first-open "!" and host-validated cooking.
void main() {
  test('the kitchen is part of the base town, free, at its spot', () {
    const s = TownState();
    final k = TownPlan.landmarkOf(s, TownSpot.kitchen);
    expect((k.x, k.y, k.w, k.h, k.tile), (28, 16, 3, 3, Tile.shop));
    expect(TownLayout.lateSpots, contains(TownSpot.kitchen));
    final map = MapGenerator.town(s);
    final (ox, oy) = map.townOrigin;
    expect(map.tileAt(k.x + ox + 1, k.y + oy + 1), Tile.shop);
    // E in front of its door finds the kitchen.
    final front = ((k.x + 1.5) * 16 + ox * 16, (k.y + k.h + 0.5) * 16 + oy * 16);
    expect(WorldRules.townSpot(front.$1, front.$2, map: map), TownSpot.kitchen);
  });

  test('no tree on its door row or exit landing (TownPlan.doorClearance)', () {
    for (final s in [
      const TownState(),
      const TownState(sides: {TownSide.este: 1, TownSide.sur: 1}),
    ]) {
      final k = TownPlan.landmarkOf(s, TownSpot.kitchen);
      final clear = TownPlan.doorClearance(s);
      for (var x = k.x - 1; x <= k.x + k.w; x++) {
        expect(clear, contains((x, k.y + k.h)));
      }
      expect(clear, contains((k.x + 1, k.y + k.h + 1)));
      final map = MapGenerator.town(s);
      final (ox, oy) = map.townOrigin;
      // The base tree at (27, 19) sits on its door row: never planted.
      expect(TownLayout.trees, contains((27, 19)));
      for (final (x, y) in clear) {
        if (x < k.x - 1 || x > k.x + k.w || y < k.y + k.h) continue;
        expect(map.tileAt(x + ox, y + oy), isNot(Tile.tree), reason: '($x, $y)');
      }
    }
  });

  test('an old town with a build on the spot gets a free kitchen nearby', () {
    // A farm saved before the kitchen existed, right where it goes.
    const s = TownState(builds: [
      TownBuild('h9', BuildKind.huerta, [TownRect(28, 16, 3, 3)]),
    ]);
    final k = TownPlan.landmarkOf(s, TownSpot.kitchen);
    expect((k.x, k.y), isNot((28, 16)));
    expect(s.builds.single.parts.single.inflate(2).overlaps(
        TownRect(k.x, k.y, k.w, k.h)), isFalse);
    final map = MapGenerator.town(s);
    final (ox, oy) = map.townOrigin;
    expect(map.tileAt(k.x + ox + 1, k.y + oy + 1), Tile.shop);
    for (final (x, y) in TownPlan.doorClearance(s)) {
      final mx = x + ox, my = y + oy;
      if (mx <= 1 || my <= 0 || mx >= map.width - 2 || my >= map.height - 1) {
        continue;
      }
      expect(map.tileAt(mx, my), isNot(Tile.tree), reason: '($x, $y)');
    }
  });

  test('first-open alert: unseen until opened, saved per profile', () {
    final p = newProfile('Ana', 'guerrero');
    expect(QuestTrackRules.seenKitchen(p), isFalse);
    final seen =
        QuestTrackRules.markSeen(p, const TownState(), QuestTrackRules.kitchenKey)!;
    expect(QuestTrackRules.seenKitchen(seen), isTrue);
    // Separate from the fountain one, and a second mark is a no-op.
    expect(QuestTrackRules.seenFountain(seen), isFalse);
    expect(QuestTrackRules.markSeen(seen, const TownState(),
        QuestTrackRules.kitchenKey), isNull);
    expect(QuestTrackRules.seenKitchen(
        newProfile('Ana', 'guerrero').copyWith(npcSeen: seen.npcSeen)), isTrue);
  });

  test('the host stores the first open of any co-op player', () {
    final e = sessionEngine();
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
    s = e.addPlayer(s, 'p1', newProfile('Beto', 'mago'))!.state;
    final r = e.apply(
        s, 'p1', const TownAction(TownOp.seen, id: QuestTrackRules.kitchenKey));
    expect(r, isNotNull);
    expect(QuestTrackRules.seenKitchen(r!.state.players['p1']!.profile), isTrue);
    expect(QuestTrackRules.seenKitchen(r.state.players['p0']!.profile), isFalse);
  });

  test('cooking from the kitchen is host-validated for every player', () {
    final e = sessionEngine();
    final cook = newProfile('Beto', 'mago');
    final stocked = cook.copyWith(
        life: cook.life.copyWith(
            farm: cook.life.farm
                .addCrop(cropKey('nabo_claro', CropQuality.normal), 3)));
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
    s = e.addPlayer(s, 'p1', stocked)!.state;
    const act = FarmShopAction(FarmShopOp.cook, id: 'sopa_nabo', n: 0);
    final r = e.apply(s, 'p1', act);
    expect(r, isNotNull);
    final f = r!.state.players['p1']!.profile.life.farm;
    expect(f.mealCount(mealKey('sopa_nabo', CropQuality.normal)), 1);
    // Without the crops the host refuses.
    expect(e.apply(s, 'p0', act), isNull);
  });
}
