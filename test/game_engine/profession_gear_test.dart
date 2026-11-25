import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/data/cooking_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/profession_gear_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profession_parity_sim.dart';
import 'session_test_helpers.dart';

/// docs/specs/profession_gear.md: living weapons, sunken / fish-forged
/// weapons, forge-only weapons and the life tree sub-path mechanics.
void main() {
  const loot = LootRules();

  FarmPlot ripe(FarmPlot p) => p.copyWith(grow: GearRules.growSec);

  group('living weapons (§ 3)', () {
    final farmer = parityProfile(LifeSkillKind.cultivo, 30);

    test('a weapon seed grows into its living weapon, marked', () {
      var plot = GearRules.plant(const FarmPlot(), 'ws_arco', farmer)!;
      expect(FarmingRules.ripe(plot), isFalse);
      expect(GearRules.harvest(loot, rolls([0.5]), farmer, plot), isNull);
      plot = ripe(plot);
      final w = GearRules.harvest(loot, rolls([0.5]), farmer, plot)!;
      expect(GearRules.defOf(w)?.id, 'vivo_arco');
      expect(GearRules.professionOf(w), LifeSkillKind.cultivo);
      expect(w.rarity.index, greaterThanOrEqualTo(Rarity.raro.index));
    });

    test('the compost type decides the affixes', () {
      var plot = GearRules.plant(const FarmPlot(), 'ws_baston', farmer)!;
      plot = GearRules.compost(plot, 'abono_brasa', farmer)!;
      plot = GearRules.compost(plot, 'abono_miel', farmer)!;
      expect(GearRules.compostMods(plot).map((m) => m.affixId),
          containsAll([kCompostAffix['abono_brasa']!.affixId, kCompostAffix['abono_miel']!.affixId]));
      final w = GearRules.harvest(loot, rolls([0.5]), farmer, ripe(plot))!;
      final ids = w.affixes.map((a) => a.affixId).toSet();
      expect(ids, contains(kCompostAffix['abono_brasa']!.affixId));
    });

    test('composts are capped', () {
      var plot = GearRules.plant(const FarmPlot(), 'ws_baston', farmer)!;
      for (var i = 0; i < GearRules.t.i('livingCompostMax'); i++) {
        plot = GearRules.compost(plot, 'abono', farmer)!;
      }
      expect(GearRules.compost(plot, 'abono', farmer), isNull);
    });

    test('Legendary only on the dedicated path', () {
      FarmPlot cared(String seed) {
        var p = GearRules.plant(const FarmPlot(), seed, farmer)!;
        p = p.copyWith(
            composts: {kTopCompost: GearRules.t.i('livingLegendCompost')},
            waterings: 4,
            wetGrow: GearRules.growSec,
            waterQ: 1);
        return ripe(p);
      }

      final old = cared('ws_lanza_old');
      expect(GearRules.legendPath(farmer, old), isTrue);
      expect(GearRules.quality(farmer, old, 1), CropQuality.legendario);
      final young = cared('ws_lanza');
      expect(GearRules.legendPath(farmer, young), isFalse);
      expect(GearRules.quality(farmer, young, 1),
          isNot(CropQuality.legendario));
      // Without the Madera viva branch: no legend either.
      final novice = newProfile('Bo', 'guerrero');
      expect(GearRules.legendPath(novice, old), isFalse);
    });

    test('replanting levels the weapon up', () {
      final first = GearRules.harvest(loot, rolls([0.5]), farmer,
          ripe(GearRules.plant(const FarmPlot(), 'ws_varita', farmer)!))!;
      final again = GearRules.regrow(const FarmPlot(), first, farmer)!;
      expect(again.held?.uid, first.uid);
      final grown = GearRules.harvest(loot, rolls([0.5]), farmer, ripe(again))!;
      expect(grown.uid, first.uid);
      expect(grown.itemLevel,
          first.itemLevel + GearRules.t.i('livingRegrowLevels'));
      expect(grown.rarity.index, greaterThanOrEqualTo(first.rarity.index));
    });

    test('the seed carousel offers weapon seeds and living weapons', () {
      final w = GearRules.harvest(loot, rolls([0.5]), farmer,
          ripe(GearRules.plant(const FarmPlot(), 'ws_arco', farmer)!))!;
      var p = farmer.copyWith(
          items: [...farmer.items, w],
          life: farmer.life
              .copyWith(farm: farmer.life.farm.addWseed('ws_arco', 2)));
      final have = FarmingRules.plantables(p);
      expect(have, contains('ws_arco'));
      expect(have, contains('$kRegrowItem${w.uid}'));
      p = FarmingRules.selectSeed(p, 'ws_arco')!;
      expect(FarmingRules.activeSeed(p), 'ws_arco');
    });
  });

  group('fishing gear (§ 4)', () {
    final fisher = parityProfile(LifeSkillKind.pesca, 30);
    final legend =
        kFish.values.firstWhere((f) => f.rarity == FishRarity.legendario).id;

    test('sunken rarity: Legendary needs the legendary water gate', () {
      final novice = newProfile('Bo', 'guerrero');
      expect(GearRules.sunkenRarity(rolls([0, 0]), novice),
          isNot(Rarity.legendario));
      expect(GearRules.sunkenRarity(rolls([0.99, 0.99]), novice), Rarity.raro);
    });

    test('sunken chest chance fades with the fishing level', () {
      final low = parityProfile(LifeSkillKind.pesca, 10);
      expect(GearRules.sunkenChestChance(fisher),
          lessThan(GearRules.sunkenChestChance(low)));
    });

    test('Brann forges a legendary fish into a unique weapon', () {
      final gold = GearRules.t.i('fishForgeGold');
      final p = fisher.copyWith(
          credits: gold + 5, life: fisher.life.addFish(legend));
      expect(GearRules.fishForgeBlock(p, legend), isNull);
      final (paid, w) = GearRules.fishForge(loot, rolls([0.5]), p, legend)!;
      expect(paid.credits, 5);
      expect(paid.life.count(legend), 0);
      expect(GearRules.fishOf(w), legend);
      expect(w.rarity.index, greaterThanOrEqualTo(Rarity.epico.index));
      expect(GearRules.fishForgeBlock(paid, legend), FishForgeBlock.noFish);
      final broke = p.copyWith(credits: 0);
      expect(GearRules.fishForgeBlock(broke, legend), FishForgeBlock.gold);
      final common =
          kFish.values.firstWhere((f) => f.rarity == FishRarity.comun).id;
      expect(GearRules.fishForgeBlock(p, common), FishForgeBlock.notLegend);
    });
  });

  group('sub-path mechanics (life_trees_v2.md § 2.1)', () {
    test('no tree, no effect', () {
      final p = newProfile('Bo', 'guerrero');
      expect(GearRules.calmMult(p), 1);
      expect(GearRules.twinChance(p), 0);
      expect(GearRules.veinArea(p), 0);
      expect(GearRules.swingMult(p), 1);
      expect(GearRules.smeltDouble(p), 0);
      expect(GearRules.orderChest(p), 0);
    });

    test('dedicated builds turn their mechanics on', () {
      final smith = parityProfile(LifeSkillKind.herreria, 30);
      expect(LifeTreeRules.smith(smith, LifeFx.rareOre), greaterThan(0));
      expect(GearRules.veinArea(smith), 0); // Veta A not taken (B fork)
      final fish = parityProfile(LifeSkillKind.pesca, 30);
      expect(GearRules.twinChance(fish), greaterThan(0));
    });

    test('every fork has its own effect, named in es-AR', () {
      for (final k in LifeSkillKind.values) {
        for (final n in kLifeTrees[k]!) {
          if (!n.id.endsWith('s') || n.branch == null) continue;
          final main = lifeTreeNode(k, n.id.substring(0, n.id.length - 1))!;
          expect(n.effects.keys.toSet(), isNot(main.effects.keys.toSet()),
              reason: n.id);
          expect(n.name, isNotEmpty);
        }
      }
    });
  });

  group('tree v2 migration (life_trees_v2.md § 6)', () {
    test('tier 4+ nodes are refunded, the rest stays', () {
      final l = LifeSkills.fromJson({
        'rods': ['cana_rama'],
        'rod': 'cana_rama',
        'ft': ['fish_a1', 'fish_a2', 'fish_a3', 'fish_a4', 'fish_a4s'],
        'tv': 1,
      });
      expect(l.fishTree, ['fish_a1', 'fish_a2', 'fish_a3']);
      expect(l.refunded, isTrue);
      final again = LifeSkills.fromJson(l.toJson());
      expect(again.refunded, isTrue);
      expect(again.fishTree, l.fishTree);
    });

    test('a v2 save is left alone', () {
      final l = LifeSkills.fromJson({
        'rods': ['cana_rama'],
        'rod': 'cana_rama',
        'ft': ['fish_a1', 'fish_a2', 'fish_a3', 'fish_a4'],
        'tv': kLifeTreeVersion,
      });
      expect(l.fishTree, contains('fish_a4'));
      expect(l.refunded, isFalse);
    });
  });

  test('meal boosts round-trip in JSON', () {
    final m = MealBuff(kMeals.keys.first, CropQuality.raro, 2,
        boost: 0.25, atkPlus: 0.05);
    expect(MealBuff.fromJson(m.toJson()), m);
  });
}
