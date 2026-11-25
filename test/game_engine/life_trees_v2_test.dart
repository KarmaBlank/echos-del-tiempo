import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/cooking_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// docs/specs/life_trees_v2.md: shape, rules, every effect and reward,
/// migration.
void main() {
  int xpFor(int Function(int) need, int level) {
    var xp = 0;
    for (var l = 1; l < level; l++) {
      xp += need(l);
    }
    return xp;
  }

  PlayerProfile at(int level, {String classId = 'guerrero'}) {
    final b = newProfile('Ana', classId);
    return b.copyWith(
        life: b.life.copyWith(
            fishXp: xpFor(FishingRules.xpNeed, level),
            smithXp: xpFor(SmithRules.xpNeed, level),
            farm: b.life.farm.copyWith(xp: xpFor(FarmingRules.xpNeed, level))));
  }

  /// Takes the chain from the root up to [n] (inclusive).
  /// Shortest route root → [n] (root excluded, [n] included).
  List<String> route(LifeSkillKind k, LifeTreeNode n) {
    final root = kLifeTrees[k]!.first.id;
    final from = <String, String>{root: ''};
    final todo = [root];
    while (todo.isNotEmpty) {
      final id = todo.removeAt(0);
      for (final l in lifeTreeNode(k, id)!.links) {
        if (from.containsKey(l)) continue;
        from[l] = id;
        todo.add(l);
      }
    }
    final out = <String>[];
    for (var id = n.id; id != root; id = from[id]!) {
      out.insert(0, id);
    }
    return out;
  }

  PlayerProfile chain(PlayerProfile p, LifeSkillKind k, LifeTreeNode n) {
    for (final id in route(k, n)) {
      final next = LifeTreeRules.take(p, k, id);
      expect(next, isNotNull,
          reason: '$id: ${LifeTreeRules.cannotTake(p, k, id)}');
      p = next!;
    }
    return p;
  }

  group('shape', () {
    for (final k in LifeSkillKind.values) {
      test('${k.name}: root + 5 forking branches × 10 tiers, one capstone group', () {
        final nodes = kLifeTrees[k]!;
        const forks = kLifeForkTo - kLifeForkFrom + 1;
        expect(nodes.length, 1 + kLifeBranches.length * (kLifeTiers + forks));
        expect(nodes.where((n) => n.root).length, 1);
        for (final b in kLifeBranches) {
          final br = nodes.where((n) => n.branch == b).toList();
          // Every tier present; the fork tiers offer two sibling nodes.
          for (var t = 1; t <= kLifeTiers; t++) {
            final at = br.where((n) => n.tier == t).length;
            expect(at, t >= kLifeForkFrom && t <= kLifeForkTo ? 2 : 1,
                reason: '$b$t');
          }
          final caps = br.where((n) => n.capstone).toList();
          expect(caps.length, 1);
          expect(caps.single.exclusive, 'cap');
          // Both sub-paths rejoin at a major node before the capstone.
          final join = br.singleWhere((n) => n.tier == kLifeForkTo + 1);
          expect(join.major, isTrue);
          expect(join.links.where((l) => lifeTreeNode(k, l)!.tier == kLifeForkTo)
              .length, 2);
        }
        // Links are symmetric and everything is reachable from the root.
        for (final n in nodes) {
          for (final l in n.links) {
            expect(lifeTreeNode(k, l)!.links, contains(n.id),
                reason: '${n.id} ↔ $l');
          }
        }
        final seen = <String>{nodes.first.id};
        final todo = [nodes.first.id];
        while (todo.isNotEmpty) {
          for (final l in lifeTreeNode(k, todo.removeLast())!.links) {
            if (seen.add(l)) todo.add(l);
          }
        }
        expect(seen.length, nodes.length);
        // Fork nodes carry a real effect.
        for (final n in nodes.where(isLifeFork)) {
          expect(n.effects, isNotEmpty, reason: n.id);
        }
        final keys = tuning(TuningId.lifeTree).values;
        for (final n in nodes) {
          expect(n.effects.isNotEmpty || n.grants.isNotEmpty, isTrue,
              reason: n.id);
          for (final v in [...n.effects.values, ...n.grants.values]) {
            expect(keys.containsKey(v), isTrue, reason: v);
          }
          for (final l in n.links) {
            expect(lifeTreeNode(k, l), isNotNull, reason: '${n.id} → $l');
          }
        }
      });
    }
  });

  group('forks', () {
    test('either sub-path leads to the capstone; old saves stay valid', () {
      var p = at(30);
      const k = LifeSkillKind.pesca;
      for (final id in ['fish_a1', 'fish_a2', 'fish_a3', 'fish_a4s',
          'fish_a5s', 'fish_a6s', 'fish_a7s', 'fish_a8', 'fish_a9',
          'fish_a10']) {
        expect(LifeTreeRules.cannotTake(p, k, id), isNull, reason: id);
        p = LifeTreeRules.take(p, k, id)!;
      }
      // The main path is still a full route (v0.49 saves keep their nodes).
      var q = at(30);
      for (var t = 1; t <= kLifeTiers; t++) {
        q = LifeTreeRules.take(q, k, 'fish_b$t')!;
      }
      expect(LifeTreeRules.taken(q, k).length, kLifeTiers);
    });
  });

  group('rules', () {
    test('tiers are gated by the profession level', () {
      var p = at(4);
      p = LifeTreeRules.take(p, LifeSkillKind.pesca, 'fish_a1')!;
      p = LifeTreeRules.take(p, LifeSkillKind.pesca, 'fish_a2')!;
      expect(LifeTreeRules.cannotTake(p, LifeSkillKind.pesca, 'fish_a3'),
          'Pide nivel 7');
      final b = LifeTreeRules.block(p, LifeSkillKind.pesca, 'fish_a3')!;
      expect(b.kind, LifeBlockKind.level);
      expect(b.need, 7);
      expect(b.key, 'ui.town.trades.block.level');
    });

    test('chain: a tier needs the one below in the same branch', () {
      final p = at(30);
      expect(LifeTreeRules.cannotTake(p, LifeSkillKind.cultivo, 'farm_c2'),
          'No está conectado');
      expect(
          LifeTreeRules.cannotTake(p, LifeSkillKind.cultivo, 'farm_c1'), isNull);
    });

    test('only one capstone per tree; costs 1/2/3', () {
      var p = at(30);
      final a10 = lifeTreeNode(LifeSkillKind.pesca, 'fish_a10')!;
      p = chain(p, LifeSkillKind.pesca, a10);
      expect(LifeTreeRules.spent(p, LifeSkillKind.pesca), 6 + 6 + 3);
      p = chain(p, LifeSkillKind.pesca,
          lifeTreeNode(LifeSkillKind.pesca, 'fish_b9')!);
      expect(LifeTreeRules.cannotTake(p, LifeSkillKind.pesca, 'fish_b10'),
          isNotNull);
    });

    test('reset refunds every point and never grants twice', () {
      var p = at(30);
      final gold0 = p.credits;
      p = chain(p, LifeSkillKind.cultivo,
          lifeTreeNode(LifeSkillKind.cultivo, 'farm_b4')!);
      final gold1 = p.credits;
      expect(gold1, greaterThan(gold0));
      p = LifeTreeRules.reset(p, LifeSkillKind.cultivo)!;
      expect(LifeTreeRules.free(p, LifeSkillKind.cultivo),
          LifeTreeRules.earned(p, LifeSkillKind.cultivo));
      p = chain(p, LifeSkillKind.cultivo,
          lifeTreeNode(LifeSkillKind.cultivo, 'farm_b4')!);
      expect(p.credits, gold1);
      expect(LifeTreeRules.claimed(p, 'farm_b4'), isTrue);
    });

    test('sanitize keeps valid nodes and grants nothing', () {
      var p = at(30);
      p = chain(p, LifeSkillKind.herreria,
          lifeTreeNode(LifeSkillKind.herreria, 'smith_e3')!);
      final clean = p.copyWith(life: p.life.copyWith(claimed: const {}));
      final out = LifeTreeRules.sanitize(clean);
      expect(out.life.smithTree, p.life.smithTree);
      expect(out.credits, clean.credits);
    });
  });

  group('every node effect is applied', () {
    for (final k in LifeSkillKind.values) {
      for (final n in kLifeTrees[k]!) {
        if (n.effects.isEmpty || n.root) continue;
        test('${n.id} adds its effects', () {
          final before = at(30);
          final after = chain(before, k, n);
          final r = route(k, n);
          final prev = r.length == 1
              ? before
              : chain(before, k, lifeTreeNode(k, r[r.length - 2])!);
          for (final e in n.effects.entries) {
            expect(
                LifeTreeRules.fx(after, k, e.key) -
                    LifeTreeRules.fx(prev, k, e.key),
                closeTo(LifeTreeRules.t.d(e.value), 1e-9),
                reason: '${n.id} ${e.key}');
          }
        });
      }
    }

    test('hooks: zone, grow, forge, power and meal reach their rules', () {
      var p = at(30);
      final zone0 = FishingRules.rodBonus(p).zone;
      p = LifeTreeRules.take(p, LifeSkillKind.pesca, 'fish_a1')!;
      expect(FishingRules.rodBonus(p).zone, greaterThan(zone0));
      final f0 = SmithRules.forgeDiscount(p);
      p = LifeTreeRules.take(p, LifeSkillKind.herreria, 'smith_a1')!;
      expect(SmithRules.forgeDiscount(p), greaterThan(f0));
      p = LifeTreeRules.take(p, LifeSkillKind.cultivo, 'farm_d1')!;
      expect(LifeTreeRules.power(p, LifeFx.hp), greaterThan(0));
      // meal: farm_e4 = +1 mission on every meal eaten.
      p = chain(p, LifeSkillKind.cultivo,
          lifeTreeNode(LifeSkillKind.cultivo, 'farm_e4')!);
      final key = mealKey('sopa_nabo', CropQuality.normal);
      final eaten = CookingRules.eat(p, key)!;
      expect(eaten.life.farm.meal!.left,
          CookingRules.missionsFor(kMeals['sopa_nabo']!) + 1);
    });
  });

  group('every reward is delivered once', () {
    for (final k in LifeSkillKind.values) {
      for (final n in kLifeTrees[k]!) {
        if (n.grants.isEmpty) continue;
        test('${n.id} delivers ${n.grants.keys.join(', ')}', () {
          final before = n.tier == 1
              ? at(30)
              : chain(at(30), k,
                  lifeTreeNode(k, n.id.replaceFirst(RegExp(r'\d+$'), '${n.tier - 1}'))!);
          final after = LifeTreeRules.take(before, k, n.id)!;
          expect(LifeTreeRules.claimed(after, n.id), isTrue);
          for (final e in n.grants.entries) {
            final parts = e.key.split(':');
            final id = parts.length > 1 ? parts[1] : '';
            final amt = LifeTreeRules.amount(e.value);
            switch (parts.first) {
              case 'gold':
                expect(after.credits - before.credits, amt);
              case 'mat':
                final m = CraftMaterial.values.byName(id);
                expect((after.materials[m] ?? 0) - (before.materials[m] ?? 0),
                    amt);
              case 'ore':
                expect(after.life.ore(id) - before.life.ore(id), amt);
              case 'craft':
                expect(after.life.craft(id) - before.life.craft(id), amt);
              case 'bait':
                expect((after.life.baits[id] ?? 0) - (before.life.baits[id] ?? 0),
                    amt);
              case 'rod':
                expect(after.life.rods, contains(id));
              case 'meal':
                final q = CropQuality.values[int.parse(parts[2])];
                final key = mealKey(id, q);
                expect(
                    after.life.farm.mealCount(key) -
                        before.life.farm.mealCount(key),
                    amt);
              case 'weapon':
                expect(after.items.length - before.items.length, amt);
                final w = after.items.last;
                expect(w.baseId, LifeTreeRules.weaponFor(before, n)!.baseId);
              default:
                fail('unknown grant ${e.key}');
            }
          }
        });
      }
    }
  });

  group('migration', () {
    test('v1 ids are dropped on load: every point back', () {
      final p = at(10);
      final json = p.life.toJson()
        ..['ft'] = ['p_a1', 'p_b1', 'fish_a1']
        ..['st'] = ['h_a1'];
      (json['farm'] as Map)['tree'] = ['c_b1', 'c_m'];
      final life = LifeSkills.fromJson(json);
      expect(life.fishTree, ['fish_a1']);
      expect(life.smithTree, isEmpty);
      expect(life.farm.tree, isEmpty);
      final q = p.copyWith(life: life);
      expect(LifeTreeRules.free(q, LifeSkillKind.cultivo),
          LifeTreeRules.earned(q, LifeSkillKind.cultivo));
    });

    test('claimed rewards round-trip in JSON', () {
      var p = at(30);
      p = LifeTreeRules.take(p, LifeSkillKind.herreria, 'smith_b1')!;
      final back = LifeSkills.fromJson(p.life.toJson());
      expect(back.claimed, {'smith_b1'});
      expect(back, p.life);
    });
  });
}
