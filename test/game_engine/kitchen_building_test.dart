import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/cooking_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// The town kitchen (docs/specs/farming.md § 17): a CONSTRUIR palette
/// building bought with gold, one per town, with a first-open "!" and
/// host-validated cooking.
(int, int) freeSpot(TownState s, [String id = kKitchenId]) {
  final (ox, oy) = s.origin;
  for (var y = 2; y < 30; y++) {
    for (var x = 2; x < 40; x++) {
      if (TownRules.place(s, id, x + ox, y + oy).town != null) {
        return (x + ox, y + oy);
      }
    }
  }
  throw StateError('no free spot');
}

void main() {
  test('its own catalog entry: 3 × 3, gold, a solid house on the map', () {
    final d = construction(kKitchenId)!;
    expect((d.kind, d.w, d.h), (BuildKind.cocina, 3, 3));
    expect(TownRules.kitchenCost, greaterThan(0));
    const s = TownState();
    final (x, y) = freeSpot(s);
    final t = TownRules.place(s, kKitchenId, x, y).town!;
    final k = t.builds.firstWhere((b) => b.kind == BuildKind.cocina);
    expect(k.id, startsWith('k'));
    expect(TownRules.hasKitchen(t), isTrue);
    final map = MapGenerator.town(t);
    final (ox, oy) = map.townOrigin;
    expect(map.tileAt(k.bounds.x + ox + 1, k.bounds.y + oy + 1), Tile.house);
    // One per town.
    final (x2, y2) = freeSpot(t, kCasaId);
    expect(TownRules.place(t, kKitchenId, x2, y2).town, isNull);
  });

  test('the host charges its gold and refuses a second one', () {
    final e = sessionEngine();
    final rich = newProfile('Ana', 'guerrero')
        .copyWith(credits: TownRules.kitchenCost * 2);
    var s = e.addPlayer(e.create(), 'p0', rich)!.state;
    final (x, y) = freeSpot(s.town);
    final r = e.apply(s, 'p0',
        TownAction(TownOp.place, id: kKitchenId, x: x, y: y));
    expect(r, isNotNull);
    s = r!.state;
    expect(TownRules.hasKitchen(s.town), isTrue);
    expect(s.players['p0']!.profile.credits, TownRules.kitchenCost);
    final (x2, y2) = freeSpot(s.town, kCasaId);
    expect(e.apply(s, 'p0',
        TownAction(TownOp.place, id: kKitchenId, x: x2, y: y2)), isNull);
    // Without the gold the host refuses.
    final poor = e.addPlayer(e.create(), 'p0',
        newProfile('Ana', 'guerrero').copyWith(credits: 0))!.state;
    expect(e.apply(poor, 'p0',
        TownAction(TownOp.place, id: kKitchenId, x: x, y: y)), isNull);
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
