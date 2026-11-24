import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/resident.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mine_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Minería y herrería (docs/specs/mining_smithing.md).
void main() {
  TuningDef t() => tuning(TuningId.smithing);

  /// Smith XP for level [lv].
  int xpFor(int lv) {
    var xp = 0;
    for (var l = 1; l < lv; l++) {
      xp += SmithRules.xpNeed(l);
    }
    return xp;
  }

  PlayerProfile smith(int lv, {int level = 40, Map<String, int> ores = const {}}) {
    final p = newProfile('Ana', 'guerrero');
    return p.copyWith(
        level: level,
        credits: 100000,
        life: p.life.copyWith(smithXp: xpFor(lv), ores: ores));
  }

  group('minas', () {
    test('generación determinista y conectada', () {
      final a = MineGenerator.generate(kBosque, 0, 1234);
      final b = MineGenerator.generate(kBosque, 0, 1234);
      final c = MineGenerator.generate(kBosque, 0, 999);
      expect(a.rows, b.rows);
      expect(a.nodes, b.nodes);
      expect(a.npc, b.npc);
      expect(a.rows, isNot(c.rows));
      expect(a.nodes, isNotEmpty);
      // Every walkable tile is reachable from the spawn (veins cut nothing).
      final open = <(int, int)>{};
      final todo = [a.spawn];
      while (todo.isNotEmpty) {
        final (x, y) = todo.removeLast();
        if (!open.add((x, y))) continue;
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final ch = a.rows[y + dy][x + dx];
          if (Tile.isWalkable(ch) && !open.contains((x + dx, y + dy))) {
            todo.add((x + dx, y + dy));
          }
        }
      }
      for (var y = 0; y < a.height; y++) {
        for (var x = 0; x < a.width; x++) {
          if (Tile.isWalkable(a.rows[y][x]) && a.rows[y][x] != Tile.stairsUp) {
            expect(open.contains((x, y)), isTrue, reason: '($x, $y)');
          }
        }
      }
      for (final (x, y) in a.nodes) {
        expect(a.rows[y][x], Tile.ore);
      }
    });

    test('cada bioma tiene bocas de mina en su exterior', () {
      for (final lay in kBiomeLayouts.values) {
        expect(lay.mines, isNotEmpty);
        final rows = lay.rows(const {});
        for (final (x, y) in lay.mines) {
          expect(rows[y][x], Tile.mineEntrance);
        }
      }
    });

    test('sin enemigos: entrar, picar y salir', () {
      final e = sessionEngine(zones: true);
      var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
          .state;
      s = act(e, s, 'p0', const TravelAction(kBosque));
      // Not from the town nor to another biome's mine.
      expect(e.apply(s, 'p0', TravelAction(MiningRules.placeOf(kRuinas, 0))),
          isNull);
      final place = MiningRules.placeOf(kBosque, 0);
      s = act(e, s, 'p0', TravelAction(place));
      expect(s.place, place);
      expect(s.mode, SessionMode.lobby);
      expect(s.mission, isNull);
      expect(s.battle, isNull);
      final map = e.mapFor(s);
      expect(map.lobby, isTrue);
      expect(map.theme, 'mina_$kBosque');
      // Walk around a while: never a battle.
      for (var i = 0; i < 40; i++) {
        s = e.tick(s, 0.1).state;
      }
      expect(s.battle, isNull);
      expect(s.mission, isNull);
      // Mine the first vein from next to it.
      final lay = MiningRules.layout(place, worldId: s.worldId, day: s.town.sky.day)!;
      final (vx, vy) = lay.nodes.first;
      s.players['p0']!
        ..x = (vx + 1.5) * 16
        ..y = (vy + 0.5) * 16;
      s = act(e, s, 'p0', const MineAction(0));
      final ore = kBiomeOres[kBosque]!.ore;
      final p = s.players['p0']!.profile;
      expect(p.life.ore(ore), greaterThanOrEqualTo(t().i('mineOreMin')));
      expect(p.life.oreLog[ore]!.source, 'mine:$kBosque');
      expect(p.life.smithXp, greaterThan(0));
      // Spent: not again until it regrows.
      expect(e.apply(s, 'p0', const MineAction(0)), isNull);
      expect(e.mapFor(s).rows[vy][vx], Tile.oreUsed);
      // Leave: back to the forest, in front of the entrance.
      s = act(e, s, 'p0', const TravelAction(kBosque));
      expect(s.place, kBosque);
      final (mx, my) = bosqueLayout.mines.first;
      expect((s.players['p0']!.y / 16).floor(), my + 1);
      expect((s.players['p0']!.x / 16).floor(), mx);
    });

    test('las vetas dan menas de su bioma', () {
      var i = 0;
      double r() => (i++ % 10) / 10;
      for (final b in kBiomeOres.values) {
        final got = MiningRules.veinYield(r, b.biome);
        expect(got.keys.where((k) => k != b.rare), [b.ore]);
      }
      final d = MiningRules.dungeonYield(() => 0.0, 7);
      expect(d.containsKey(kBiomeOres[biomeOfZone(7)]!.rare), isTrue);
      expect(d[kSchematic], 1);
    });
  });

  group('herrería', () {
    test('fundir', () {
      final p = smith(1, ores: {'ore_copper': 7});
      expect(SmithCraftRules.smeltMax(p, 'ore_copper'), 2);
      expect(SmithCraftRules.cannotSmelt(p, 'ore_copper', 3), SmithBlock.noOre);
      expect(SmithCraftRules.cannotSmelt(p, 'ingot_copper', 1),
          SmithBlock.notOre);
      final q = SmithCraftRules.smelt(p, 'ore_copper', 2, day: 3)!;
      expect(q.life.ore('ore_copper'), 1);
      expect(q.life.ore('ingot_copper'), 2);
      expect(q.credits, p.credits - 2 * t().i('smeltGoldPerTier'));
      expect(q.life.oreLog['ingot_copper'], const OreFind(3, 'smelt', 2));
    });

    test('forjar: nivel de Herrería y rareza', () {
      final e = sessionEngine();
      final base = e.catalog.weapons.values.firstWhere((w) => w.level <= 5);
      final ores = {'ingot_frost': 50, 'rare_rime': 10};
      for (final (lv, r, ok) in [
        (1, Rarity.comun, true),
        (1, Rarity.magico, false),
        (t().i('lvMagico'), Rarity.magico, true),
        (t().i('lvRaro') - 1, Rarity.raro, false),
        (t().i('lvRaro'), Rarity.raro, true),
        (t().i('lvEpico'), Rarity.epico, true),
        (t().i('lvEpico'), Rarity.legendario, false),
      ]) {
        final p = smith(lv, ores: ores);
        expect(SmithRules.level(p), lv);
        final why = SmithCraftRules.cannotForge(p, base, 'ingot_frost', r,
            maxRarity: SmithCraftRules.maxRarity(lv));
        expect(why == null, ok, reason: '$lv $r $why');
      }
      // Crafted weapons stay below the character (loot keeps the top).
      final c = SmithCraftRules.cost(40, 'ingot_frost', Rarity.epico)!;
      expect(c.itemLevel, lessThan(40));
      expect(c.itemLevel,
          lessThanOrEqualTo(t().i('ingotIlPerTier') * 3));
      expect(c.ingots * t().i('smeltOre'),
          greaterThanOrEqualTo(t().i('ingotsEpico') * t().i('smeltOre')));
      // The session forges it at the town forge.
      var s = e.addPlayer(e.create(), 'p0', smith(t().i('lvRaro'), ores: ores))!
          .state;
      s = act(e, s, 'p0',
          SmithAction(SmithOp.forge, 'ingot_frost',
              base: base.id, rarity: Rarity.raro.index));
      final p = s.players['p0']!.profile;
      expect(p.items.any((i) => i.baseId == base.id && i.rarity == Rarity.raro),
          isTrue);
      expect(p.life.ore('ingot_frost'), 50 - t().i('ingotsRaro'));
      expect(p.life.ore('rare_rime'), 10 - t().i('rareRaro'));
    });

    test('legendario: pide Plano antiguo o Núcleo de guardián', () {
      final e = sessionEngine();
      final base = e.catalog.weapons.values.firstWhere((w) => w.level <= 5);
      final ores = {'ingot_echo': 50, 'rare_sand': 10};
      final lv = t().i('lvLegend');
      final cap = SmithCraftRules.maxRarity(lv);
      expect(cap, Rarity.legendario);
      final p = smith(lv, ores: ores);
      expect(
          SmithCraftRules.cannotForge(p, base, 'ingot_echo', Rarity.legendario,
              maxRarity: cap),
          SmithBlock.noRecipe);
      for (final key in [kSchematic, kGuardianCore]) {
        final q = smith(lv, ores: {...ores, key: 1});
        expect(
            SmithCraftRules.cannotForge(
                q, base, 'ingot_echo', Rarity.legendario,
                maxRarity: cap),
            isNull);
        final paid = SmithCraftRules.pay(q, 'ingot_echo', Rarity.legendario)!;
        expect(paid.life.ore(key), 0);
      }
    });

    test('encargo a Brann: con Brann en casa, por oro, rareza de su encargo',
        () {
      final e = sessionEngine();
      final base = e.catalog.weapons.values.firstWhere((w) => w.level <= 5);
      final prof = smith(1, ores: {'ingot_copper': 10});
      var s = e.addPlayer(e.create(), 'p0', prof)!.state;
      const a = SmithAction(SmithOp.brann, 'ingot_copper',
          base: null, rarity: 1);
      final withBase = SmithAction(SmithOp.brann, 'ingot_copper',
          base: base.id, rarity: a.rarity);
      expect(e.apply(s, 'p0', withBase), isNull, reason: 'Brann no vive acá');
      s.town = s.town.withResident(const ResidentState('brann',
          invited: true, house: 1));
      // Smith level 1 cannot forge Mágico alone, Brann can.
      expect(
          e.apply(s, 'p0',
              SmithAction(SmithOp.forge, 'ingot_copper',
                  base: base.id, rarity: 1)),
          isNull);
      s = act(e, s, 'p0', withBase);
      final p = s.players['p0']!.profile;
      final c = SmithCraftRules.cost(prof.level, 'ingot_copper', Rarity.magico,
          brann: true)!;
      expect(p.credits, prof.credits - c.gold);
      expect(c.gold, t().i('brannGoldPerIl') * c.itemLevel);
      expect(p.items.any((i) => i.baseId == base.id), isTrue);
    });
  });

  group('colección y guardado', () {
    test('JSON ida y vuelta de materiales y colección', () {
      final life = LifeSkills.initial
          .addOres({'ore_copper': 4, 'schematic': 1, 'basura': 3})
          .logOres({'ore_copper': 4}, 'mine:$kBosque', 2)
          .logOres({'ore_copper': 1}, 'dungeon:3', 5);
      expect(life.ore('basura'), 0);
      expect(life.oreLog['ore_copper'], const OreFind(2, 'mine:$kBosque', 5));
      final back = LifeSkills.fromJson(life.toJson());
      expect(back, life);
      expect(back.ores, {'ore_copper': 4, 'schematic': 1});
      for (final a in [
        const MineAction(3),
        const SmithAction(SmithOp.smelt, 'ore_copper', n: 5),
        const SmithAction(SmithOp.brann, 'ingot_echo',
            base: 'espada', rarity: 4),
      ]) {
        final j = ActionJson.toJson(a);
        expect(ActionJson.toJson(ActionJson.fromJson(j)), j);
      }
    });

    test('entradas de la colección: descubiertos y "?"', () {
      var p = newProfile('Ana', 'guerrero');
      p = MiningRules.give(p, {'ore_copper': 2},
          source: MiningRules.mineSource(kBosque), day: 4);
      final all = SmithCollection.entries(p);
      expect(all.length, kSmithMaterials.length);
      final cu = all.firstWhere((x) => x.id == 'ore_copper');
      expect(cu.discovered, isTrue);
      expect(cu.icon, 'vida_ore_copper');
      expect(cu.rows.map((r) => r.$1), contains('ui.inventory.smith.col.use.smelt'));
      expect(cu.rows.first.$2['source'], 'mine:$kBosque');
      final hidden = all.firstWhere((x) => x.id == 'rare_sand');
      expect(hidden.discovered, isFalse);
      expect(hidden.rows, isEmpty);
      for (final id in kSmithMaterials.keys) {
        expect(SmithCollection.usesOf(id), isNotEmpty, reason: id);
      }
    });
  });
}
