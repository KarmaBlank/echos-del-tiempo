import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/branch_ults_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/gear_v2_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/profession_gear_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profession_parity_sim.dart';

/// docs/specs/profession_gear_v2.md.
void main() {
  const loot = LootRules();
  final t = GearV2Rules.t;
  double Function() seeded(int s) {
    final r = math.Random(s);
    return r.nextDouble;
  }

  PlayerProfile smith(int level, Map<String, int> ores, {int gold = 99999}) {
    final p = parityProfile(LifeSkillKind.herreria, level);
    return p.copyWith(
        level: 40, credits: gold, life: p.life.copyWith(ores: ores));
  }

  group('quality and slots (§ 2)', () {
    test('q is clamped and the hand counts', () {
      final m = GearV2Rules.quality(level: 30, materials: 1, manual: true);
      final h = GearV2Rules.quality(level: 30, materials: 1, manual: false);
      expect(m, closeTo(1, 1e-9));
      expect(h, lessThan(m));
      expect(GearV2Rules.quality(level: 0, materials: 0, manual: false),
          greaterThanOrEqualTo(0));
    });

    test('mods stay within the rarity; masterwork adds exactly one', () {
      for (final r in Rarity.values) {
        for (final q in [0.0, 0.5, 1.0]) {
          final n = GearV2Rules.rollMods(seeded(1), r, q);
          expect(n, inInclusiveRange(r.minMods, r.maxMods));
        }
      }
      expect(GearV2Rules.rollMods(seeded(1), Rarity.epico, 0), 5);
      expect(GearV2Rules.rollMods(seeded(1), Rarity.epico, 1), 6);
      expect(GearV2Rules.masterworkFor(Rarity.comun, 1), isFalse);
      expect(GearV2Rules.masterworkFor(Rarity.epico, 1), isTrue);
      expect(GearV2Rules.masterworkFor(Rarity.epico, 0.5), isFalse);
      const mw = ItemInstance(
          uid: 'x', baseId: 'b', rarity: Rarity.epico, masterwork: true);
      expect(mw.modCap, Rarity.epico.maxMods + 1);
    });

    test('rarity by quality', () {
      expect(GearV2Rules.rarityForQ(0), Rarity.comun);
      expect(GearV2Rules.rarityForQ(t.d('forgeQRaro')), Rarity.raro);
      expect(GearV2Rules.rarityForQ(t.d('forgeQEpico')), Rarity.epico);
      expect(GearV2Rules.rarityForQ(1), Rarity.legendario);
    });
  });

  group('affinity and ULT pool (§ 1)', () {
    test('base ingot, setting and other sources', () {
      expect(GearV2Rules.partsAffinity(
              ['ingot_ember', 'ingot_copper', 'ingot_copper']),
          GameElement.fuego);
      expect(
          GearV2Rules.partsAffinity(
              ['ingot_ember', 'ingot_copper', 'ingot_copper', 'rare_rime']),
          GameElement.hielo);
      expect(GearV2Rules.partsAffinity(['living', 'veneno']),
          GameElement.veneno);
      expect(GearV2Rules.livingAffinity({'abono': 3, 'abono_brasa': 1}),
          GameElement.fuego);
      expect(GearV2Rules.livingAffinity({'abono': 3}), GameElement.fisico);
      expect(fishAffinity('pez_invierno'), GameElement.hielo);
    });

    test('pool = existing ULTs of the type with that element', () {
      for (final type in kForgeWeaponTypes) {
        for (final e in GameElement.values) {
          final pool = GearV2Rules.ultPool(type, e, Rarity.epico);
          final matched = pool.every((id) => kBranchUltElement[id] == e);
          if (!matched && ultV2ModsForType(type).isNotEmpty) {
            expect(pool, ultV2ModsForType(type), reason: 'fallback $type $e');
          }
          for (final id in pool) {
            expect(kWeaponUltSkills.containsKey(id) || kUltV2.containsKey(id),
                isTrue);
          }
        }
      }
    });
  });

  group('forge by parts (§ 3)', () {
    final parts = ['ingot_frost', 'ingot_copper', 'ingot_copper'];

    test('rejects a part in the wrong step', () {
      final p = smith(20, {'ingot_frost': 20, 'ingot_copper': 5});
      expect(GearV2Rules.cannotForge(p, 'espada', ['rare_rime', 'a', 'b']),
          PartsBlock.badPart);
      expect(GearV2Rules.cannotForge(p, 'escoba', parts), PartsBlock.badType);
      expect(GearV2Rules.cannotForge(smith(20, {}), 'espada', parts),
          PartsBlock.noMaterials);
    });

    test('pays, marks and colours the weapon', () {
      final p = smith(20, {'ingot_frost': 20, 'ingot_copper': 5});
      final (paid, w) =
          GearV2Rules.forge(loot, seeded(3), p, 'hacha', parts)!;
      expect(paid.life.ore('ingot_frost'), 20 - t.i('partsBaseIngots'));
      expect(paid.life.ore('ingot_copper'), 3);
      expect(GearV2Rules.partsType(w), 'hacha');
      expect(GearRules.professionOf(w), LifeSkillKind.herreria);
      expect(w.parts, parts);
      expect(w.affixes.length, lessThanOrEqualTo(w.modCap));
      if (w.rarity.index >= Rarity.raro.index) {
        expect(w.element, GameElement.hielo);
      }
      expect(const LootRules().items.sanitize(w), w);
    });

    test('rarity capped by the smith level; legendary needs a recipe', () {
      final low = GearV2Rules.plan(smith(1, {}), 'espada', parts)!;
      expect(low.rarity, Rarity.comun);
      final top = smith(30, {'ingot_echo': 20, 'rare_sand': 2});
      final noRecipe = GearV2Rules.plan(
          top, 'espada', ['ingot_echo', 'ingot_echo', 'ingot_echo', 'rare_sand'])!;
      expect(noRecipe.rarity.index, lessThanOrEqualTo(Rarity.epico.index));
      final withRecipe = GearV2Rules.plan(
          smith(30, {'ingot_echo': 20, 'rare_sand': 2, kSchematic: 1}),
          'espada',
          ['ingot_echo', 'ingot_echo', 'ingot_echo', 'rare_sand'])!;
      if (withRecipe.rarity == Rarity.legendario) {
        expect(withRecipe.need[kSchematic], 1);
      }
    });
  });

  group('fish taken apart (§ 4)', () {
    final epic = kFish.values.firstWhere((f) => f.rarity == FishRarity.epico);
    final legend =
        kFish.values.firstWhere((f) => f.rarity == FishRarity.legendario);
    final common =
        kFish.values.firstWhere((f) => f.rarity == FishRarity.comun);

    PlayerProfile fisher(String sp) {
      final p = parityProfile(LifeSkillKind.pesca, 20);
      return p.copyWith(
          credits: 9999, life: p.life.copyWith(bag: {sp: 1}));
    }

    test('epic gives parts only and the fish is gone', () {
      expect(GearRules.fishForgeBlock(fisher(epic.id), epic.id),
          FishForgeBlock.notLegend);
      final p = GearV2Rules.split(fisher(epic.id), epic.id)!;
      expect(p.life.count(epic.id), 0);
      expect(p.life.ore(fishPartId(epic.id, FishPart.scale)),
          t.i('fishScaleEpic'));
      expect(p.credits, 9999 - t.i('fishPartGold'));
    });

    test('legendary: whole or apart; common: neither', () {
      expect(GearRules.fishForgeBlock(fisher(legend.id), legend.id), isNull);
      expect(GearV2Rules.cannotSplit(fisher(legend.id), legend.id), isNull);
      expect(GearV2Rules.split(fisher(legend.id), legend.id)!
              .life
              .ore(fishPartId(legend.id, FishPart.essence)),
          t.i('fishEssenceLegend'));
      expect(GearV2Rules.cannotSplit(fisher(common.id), common.id),
          FishSplitBlock.notMagic);
    });

    test('fish parts fit their forge steps', () {
      expect(GearV2Rules.fits(PartSlot.head, fishPartId(epic.id, FishPart.scale)),
          isTrue);
      expect(GearV2Rules.fits(PartSlot.grip, fishPartId(epic.id, FishPart.bone)),
          isTrue);
      expect(
          GearV2Rules.fits(
              PartSlot.setting, fishPartId(epic.id, FishPart.essence)),
          isTrue);
      expect(GearV2Rules.fits(PartSlot.base, fishPartId(epic.id, FishPart.scale)),
          isFalse);
    });
  });

  group('living weapons (§ 5)', () {
    test('every type but the rifle has a seed', () {
      final types = {
        for (final s in kWeaponSeeds.values) kProfessionGear[s.gear]!.type
      };
      expect(types, containsAll(kLivingWeaponTypes));
      expect(types.contains('rifle'), isFalse);
    });

    test('compost decides the affinity of the harvest', () {
      final farmer = parityProfile(LifeSkillKind.cultivo, 30);
      var plot = GearRules.plant(const FarmPlot(), 'ws_espada', farmer)!;
      plot = GearRules.compost(plot, 'abono_escarcha', farmer)!;
      final w = GearRules.harvest(
          loot, seeded(5), farmer, plot.copyWith(grow: GearRules.growSec))!;
      expect(w.parts, ['living', 'hielo']);
      expect(GearV2Rules.affinityOf(w), GameElement.hielo);
      expect(LifeTreeRules.level(farmer, LifeSkillKind.cultivo), 30);
    });
  });
}
