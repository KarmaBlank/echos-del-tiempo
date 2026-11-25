import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/cozy_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/cozy_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/wild_loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Cozy life (docs/specs/cozy_life.md).
void main() {
  final t = kTuningDefaults[TuningId.regions]!;

  group('hold to gather (§ 3)', () {
    test('faster with Cultivo level, never under the floor', () {
      final l1 = CozyRules.gatherHoldSec(1);
      final l10 = CozyRules.gatherHoldSec(10);
      expect(l1, closeTo(t.d('gatherHoldSec'), 1e-9));
      expect(l10, lessThan(l1));
      expect(CozyRules.gatherHoldSec(999), t.d('gatherHoldMinSec'));
    });
  });

  group('tree search (§ 3)', () {
    test('key carries the layout version under the wilds prefix', () {
      final k = CozyRules.searchKey('Ana', 'bosque', 4, 9, 3);
      expect(k, startsWith(WildLootRules.prefix));
      expect(k, contains(':v${BiomeLayout.version}:'));
      expect(k, contains('t4.9'));
      // Layout migration drops them with the rest of the wilds keys.
      expect(WildLootRules.dropLoot({k: 1, 'other': 2}), {'other': 2});
    });

    test('roll bands follow the tuning and leave room for nothing', () {
      expect(CozyRules.searchRoll(0), SearchFind.recipe);
      final r = t.d('searchRecipeChance');
      expect(CozyRules.searchRoll(r + 1e-6), SearchFind.nest);
      expect(CozyRules.searchRoll(0.999), SearchFind.nothing);
    });

    test('new recipe skips the known ones; null when all known', () {
      final all = kCompostRecipes.keys.toSet();
      expect(CozyRules.newRecipe(all, 0.5), isNull);
      final one = {all.first};
      expect(one.contains(CozyRules.newRecipe(one, 0.0)), isFalse);
    });

    test('host: search once a day per tree, in reach, gives Cultivo XP', () {
      late BiomeLayout lay;
      final e = sessionEngine(zones: true);
      var s =
          e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
      s = act(e, s, 'p0', const TravelAction(kBosque));
      lay = biomeLayout(s.place)!;
      final map = e.mapFor(s);
      (int, int, double, double)? spot;
      for (var y = 1; y < map.height - 1 && spot == null; y++) {
        for (var x = 1; x < map.width - 1 && spot == null; x++) {
          if (map.tileAt(x, y) != Tile.tree) continue;
          if (Tile.isWalkable(map.tileAt(x, y + 1))) {
            spot = (x, y, (x + 0.5) * 16, (y + 1.5) * 16);
          }
        }
      }
      final (tx, ty, px, py) = spot!;
      expect(e.apply(s, 'p0', CozyAction(CozyOp.search, x: tx, y: ty)), isNull,
          reason: 'far');
      s = moveTo(e, s, 'p0', px, py);
      final xp0 = s.players['p0']!.profile.life.farm.xp;
      s = act(e, s, 'p0', CozyAction(CozyOp.search, x: tx, y: ty));
      expect(s.players['p0']!.profile.life.farm.xp, xp0 + t.i('searchXp'));
      expect(CozyRules.searched(s.town, 'Ana', lay.id, tx, ty), isTrue);
      expect(e.apply(s, 'p0', CozyAction(CozyOp.search, x: tx, y: ty)), isNull,
          reason: 'once a day');
      // Not a tree: refused.
      expect(e.apply(s, 'p0', CozyAction(CozyOp.search, x: tx, y: ty + 1)),
          isNull);
    });
  });

  group('raft decorations (§ 1)', () {
    test('buy shows it; a second tap hides it; paints swap', () {
      var p = newProfile('Ana', 'guerrero').copyWith(credits: 1000);
      p = CozyRules.raftDeco(p, 'lantern')!;
      expect(p.credits, 1000 - t.i('raftLanternCost'));
      expect(CozyRules.hasLantern(p.life), isTrue);
      final paid = p.credits;
      p = CozyRules.raftDeco(p, 'lantern')!;
      expect(CozyRules.hasLantern(p.life), isFalse);
      expect(p.credits, paid, reason: 'owned: free toggle');
      p = CozyRules.raftDeco(p, 'paint_red')!;
      p = CozyRules.raftDeco(p, 'paint_blue')!;
      expect(CozyRules.paintOf(p.life), kRaftDecos['paint_blue']!.paint);
      expect(p.life.raftOn.where((d) => d.startsWith('paint')).length, 1);
    });

    test('no gold, unknown id: refused', () {
      final p = newProfile('Ana', 'guerrero').copyWith(credits: 0);
      expect(CozyRules.raftDeco(p, 'roof'), isNull);
      expect(CozyRules.raftDeco(p, 'yacht'), isNull);
    });

    test('profile JSON round trip keeps decorations and fish finds', () {
      final l = LifeSkills(
          raftDecos: const {'roof', 'lantern'},
          raftOn: const {'roof'},
          fishFinds: const {}).logFishFind('trucha_cobre', 'bosque', 4);
      final back = LifeSkills.fromJson(l.toJson());
      expect(back.raftDecos, {'roof', 'lantern'});
      expect(back.raftOn, {'roof'});
      expect(back, l);
    });
  });

  group('farm decorations (§ 2)', () {
    test('place, block the tile, move and remove', () {
      var p = newProfile('Ana', 'guerrero').copyWith(credits: 500);
      var town = const TownState();
      final (ox, oy) = town.origin;
      // Find a grass tile that takes a lighthouse.
      (int, int)? free;
      for (var y = 3; y < 30 && free == null; y++) {
        for (var x = 3; x < 30 && free == null; x++) {
          if (CozyRules.decorError(town, x, y) == null) free = (x, y);
        }
      }
      final (fx, fy) = free!;
      final r = CozyRules.placeDecor(p, town, 'scarecrow', fx + ox, fy + oy)!;
      (p, town) = r;
      expect(p.credits, 500 - t.i('decorScarecrowCost'));
      expect(town.decor.single, ('scarecrow', fx, fy));
      expect(CozyRules.placeDecor(p, town, 'pot', fx + ox, fy + oy), isNull,
          reason: 'occupied');
      // JSON keeps them.
      expect(TownState.fromJson(town.toJson()).decor, town.decor);
      // The scarecrow helps nearby plots only.
      expect(CozyRules.scarecrowBias(town, fx + ox + 1, fy + oy),
          t.d('scarecrowQualityBias'));
      expect(CozyRules.scarecrowBias(town, fx + ox + 40, fy + oy), 0);
      final id = TownState.decorId(fx, fy);
      expect(CozyRules.removeDecor(town, id)!.decor, isEmpty);
    });

    test('scarecrow bias raises the harvest score', () {
      final p = newProfile('Ana', 'guerrero');
      const plot = FarmPlot(seed: 'nabo_claro', grow: 10, wetGrow: 10);
      expect(FarmingRules.score(p, plot, bias: 0.5),
          greaterThan(FarmingRules.score(p, plot)));
    });
  });

  group('compost (§ 3)', () {
    test('needs the recipe and the harvest; gives fertilizer', () {
      final r = kCompostRecipes['leaf_mulch']!;
      var f =
          FarmSkills(crops: {for (final e in r.inputs.entries) e.key: e.value});
      expect(CozyRules.compost(f, r.id), isNull, reason: 'unknown recipe');
      f = f.copyWith(recipes: {r.id});
      final out = CozyRules.compost(f, r.id)!;
      expect(out.fertCount(r.fert), r.makes);
      for (final e in r.inputs.entries) {
        expect(out.cropCount(e.key), 0);
      }
      expect(CozyRules.compost(out, r.id), isNull, reason: 'used up');
      expect(FarmSkills.fromJson(f.toJson()).recipes, {r.id});
    });
  });

  group('journals (§ 4)', () {
    test('only professions with something done', () {
      expect(CozyRules.journals(LifeSkills()), isEmpty);
      final l = LifeSkills(fishXp: 5, farm: FarmSkills(xp: 3));
      expect(CozyRules.journals(l),
          [ProfessionJournal.fishing, ProfessionJournal.farming]);
    });

    test('fish finds count catches and keep the first place/day', () {
      var l = LifeSkills().logFishFind('trucha_cobre', 'bosque', 2);
      l = l.logFishFind('trucha_cobre', 'pueblo', 9);
      final f = l.fishFinds['trucha_cobre']!;
      expect((f.day, f.source, f.count), (2, 'bosque', 2));
    });
  });

  group('ambience (§ 1-2)', () {
    test('water, rain, day and night', () {
      expect(CozyRules.sounds(night: false, water: true),
          [CozySound.water, CozySound.bird]);
      expect(CozyRules.sounds(night: true, rain: true),
          [CozySound.rain, CozySound.cricket]);
      final gap = CozyRules.nextGapSec(0.5);
      expect(gap,
          inInclusiveRange(t.d('cozyAmbGapMinSec'), t.d('cozyAmbGapMaxSec')));
    });
  });

  test('cozy action wire round trip', () {
    for (final a in const [
      CozyAction(CozyOp.search, x: 3, y: 4),
      CozyAction(CozyOp.raftDeco, id: 'roof'),
      CozyAction(CozyOp.compost, id: 'leaf_mulch'),
    ]) {
      final back = ActionJson.fromJson(ActionJson.toJson(a)) as CozyAction;
      expect((back.op, back.id, back.x, back.y), (a.op, a.id, a.x, a.y));
    }
  });

  test('fish ids used by the tests exist', () {
    expect(kCrops.containsKey('nabo_claro'), isTrue);
  });
}
