import 'package:echos_del_tiempo/features/world/presentation/hud/loot_feed.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/farm_plot.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/goods_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Quiet loot (docs/specs/loot.md § 4c / 4d): no loot-filter toast in the
/// town or for anything farming yields; harvests go straight in.
/// Dungeons and the overworld keep their ground loot and toasts.
void main() {
  tearDown(() => BiomeRegions.bind(0));

  LootFeed feed() => LootFeed(
      localId: 'p0',
      playerName: (id) => id,
      itemName: (d) => d.goods ?? 'x',
      verdictFor: (_, __) => null,
      clock: () => 0);

  test('the shared rule', () {
    expect(GoodsRules.quiet(town: true, farming: false), isTrue);
    expect(GoodsRules.quiet(town: false, farming: true), isTrue);
    expect(GoodsRules.quiet(town: false, farming: false), isFalse);
    const sword = LootDrop.item(ItemInstance(
        uid: 'a', baseId: 'espada_ignea', rarity: Rarity.raro, itemLevel: 2));
    expect(GoodsRules.toast(sword, quiet: true, onGround: false), isFalse);
    expect(GoodsRules.toast(sword, quiet: false, onGround: false), isTrue);
  });

  test('harvest in town: straight into the bags, log line only', () {
    final e = sessionEngine(groundLoot: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    const bf = TownLayout.baseFarm;
    final tx = bf.x + 1, ty = bf.y + 1;
    s = moveTo(e, s, 'p0', (tx + 0.5) * 16, (ty + 0.5) * 16);
    SessionStep? step;
    String? crop;
    for (final id in kCrops.keys) {
      s.town = s.town.copyWith(plots: {
        ...s.town.plots,
        plotKey(tx, ty): FarmPlot(seed: id, grow: 1e9),
      });
      step = e.apply(s, 'p0', FarmTileAction(FarmOp.harvest, tx, ty));
      if (step != null) {
        crop = id;
        break;
      }
    }
    expect(step, isNotNull, reason: 'some crop is harvestable now');
    s = step!.state;
    final h = step.events.whereType<CropHarvestedEvent>().single;
    expect(h.crop, crop);
    expect(s.groundFor('p0'), isEmpty, reason: 'no ground loot');
    final farm = s.players['p0']!.profile.life.farm;
    expect(farm.crops.values.fold(0, (a, b) => a + b), h.count);
    final drops = step.events.whereType<LootDropEvent>().toList();
    expect(drops, isNotEmpty);
    expect(drops.every((d) => d.groundId == null && d.quiet), isTrue);
    // Same on every client: the flag travels.
    for (final d in drops) {
      const ev = EventJson();
      final back = ev.fromJson(ev.toJson(d)) as LootDropEvent;
      expect(back.quiet, isTrue);
    }
    final f = feed();
    drops.forEach(f.onEvent);
    expect(f.toasts, isEmpty);
    expect(f.lines, hasLength(drops.length));
    f.dispose();
  });

  test('an eco from farming: inventory, no popup', () {
    const eco = LootDrop.eco(EcoItem(
        uid: 'e1', tier: 1, zone: 1, boss: 1, rarity: Rarity.legendario));
    final f = feed();
    f.onEvent(const LootDropEvent('p0', eco, LootSource.mission, quiet: true));
    expect(f.toasts, isEmpty, reason: 'not even the legendary toast');
    expect(f.lines, hasLength(1));
    f.onEvent(const LootDropEvent('p0', eco, LootSource.mission));
    expect(f.toasts, hasLength(1), reason: 'outside town and farming');
    f.dispose();
  });

  test('a dungeon drop: still ground loot with its popup', () {
    final e = sessionEngine(zones: true);
    var s = inField(e, 'm1');
    final p = s.players['p0']!;
    s.ground.add(GroundLoot(
        id: 900,
        drop: const LootDrop.item(ItemInstance(
            uid: 'a',
            baseId: 'espada_ignea',
            rarity: Rarity.raro,
            itemLevel: 2)),
        x: p.x,
        y: p.y,
        ownerId: 'p0'));
    final step = e.tick(s, 0.05);
    final picked = step.events.whereType<LootPickedEvent>().single;
    expect(picked.quiet, isFalse);
    final f = feed();
    f.onEvent(picked);
    expect(f.toasts.single.title, '+');
    f.dispose();
  });

  test('an overworld drop: unchanged ground loot, not quiet', () {
    BiomeLayout? lay;
    for (var seed = 0; seed < 50 && lay == null; seed++) {
      BiomeRegions.bind(seed);
      if (bosqueLayout.shrines.isNotEmpty) lay = bosqueLayout;
    }
    final e = sessionEngine(zones: true, groundLoot: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final map = e.mapFor(s);
    final (sx, sy) = lay!.shrines.first;
    (double, double)? at;
    for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
      if (Tile.isWalkable(map.tileAt(sx + dx, sy + dy))) {
        at = ((sx + dx + 0.5) * 16, (sy + dy + 0.5) * 16);
        break;
      }
    }
    s = moveTo(e, s, 'p0', at!.$1, at.$2);
    final step = e.apply(s, 'p0', const WildLootAction(0, shrine: true))!;
    final drops = step.events.whereType<LootDropEvent>().toList();
    expect(drops, isNotEmpty);
    expect(drops.every((d) => d.groundId != null && !d.quiet), isTrue);
    expect(step.state.groundFor('p0'), isNotEmpty);
  });
}
