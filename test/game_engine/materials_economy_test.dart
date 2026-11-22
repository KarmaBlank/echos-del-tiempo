import 'package:echos_del_tiempo/game_engine/data/exploration_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Economía de materiales v0.15 (docs/specs/materials_economy.md).

final _craft = progression.crafting;

PlayerProfile _p({int credits = 5000, Map<CraftMaterial, int> mats = const {}}) =>
    progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: credits,
      materials: mats,
      items: const [
        ItemInstance(uid: 'c', baseId: 'espada_bronce'),
        ItemInstance(uid: 'c2', baseId: 'espada_bronce'),
        ItemInstance(
            uid: 'r', baseId: 'espada_ignea', rarity: Rarity.raro, itemLevel: 12),
        ItemInstance(
            uid: 'm', baseId: 'espada_ignea', rarity: Rarity.magico, itemLevel: 12),
      ],
      equipped: 'c',
    ));

void main() {
  group('tasas (§ 4.1)', () {
    test('drop de materiales, Prisma de la misión opcional y Épico en zonas', () {
      expect(LootRules.materialChance, {
        CraftMaterial.esquirla: 0.08,
        CraftMaterial.cristal: 0.025,
        CraftMaterial.prisma: 0.006,
      });
      expect(kQuestPrismaChance, 0.5);
      expect(LootRules.zoneEpicWeight, 1.5);
      final zone = LootRules.rarityOdds(40, LootSource.boss);
      final eco = LootRules.rarityOdds(40, LootSource.boss, eco: true);
      expect(zone[Rarity.epico]!, lessThan(eco[Rarity.epico]! * 0.65));
      // El resto casi no cambia (solo la normalización).
      expect(zone[Rarity.legendario]!,
          closeTo(eco[Rarity.legendario]!, eco[Rarity.legendario]! * 0.1));
    });

    test('desarme: Raro y Épico nuevos; Común, Mágico y Legendario igual', () {
      SalvageYield y(Rarity r, {int level = 10}) => CraftRules.salvageYield(
          ItemInstance(uid: 'x', baseId: 'espada_bronce', rarity: r, itemLevel: level));
      expect(y(Rarity.raro).guaranteed, {CraftMaterial.esquirla: 2});
      expect([for (final c in y(Rarity.raro).chances) (c.material, c.chance)],
          [(CraftMaterial.cristal, 0.5), (CraftMaterial.prisma, 0.05)]);
      expect(y(Rarity.epico).guaranteed, {CraftMaterial.cristal: 1});
      expect(y(Rarity.epico, level: 30).guaranteed, {CraftMaterial.cristal: 2});
      expect([for (final c in y(Rarity.epico).chances) (c.material, c.chance)],
          [(CraftMaterial.prisma, 0.15)]);
      expect(y(Rarity.legendario).guaranteed,
          {CraftMaterial.prisma: 1, CraftMaterial.cristal: 2});
    });
  });

  group('costos (§ 4.2)', () {
    test('rareza 1 / 3 / 6 (10 a Épico); Ecos 1 / 2 / 4', () {
      final arma = [Rarity.comun, Rarity.magico, Rarity.raro]
          .map((r) => CraftRules.upgradeRarityCost(r)!.$1)
          .toList();
      expect(arma, [1, 3, 6]);
      expect(CraftRules.upgradeRarityCost(Rarity.epico), isNull);
      expect(
          [Rarity.comun, Rarity.magico, Rarity.raro].map(EcoRules.prismCost),
          [1, 2, 4]);
    });

    test('traer habilidad: 2 Cristales hacia Raro o mejor', () {
      expect(CraftRules.transferSkillMaterials(Rarity.comun), isEmpty);
      expect(CraftRules.transferSkillMaterials(Rarity.magico), isEmpty);
      for (final r in [Rarity.raro, Rarity.epico, Rarity.legendario]) {
        expect(CraftRules.transferSkillMaterials(r), {CraftMaterial.cristal: 2});
      }
      final none = _p();
      expect(_craft.transferSkill(none, 'r', 'c2', 'giro').error,
          'Falta Cristal de Era');
      final ok = _craft.transferSkill(
          _p(mats: const {CraftMaterial.cristal: 3}), 'r', 'c2', 'giro');
      expect(ok.ok, isTrue);
      expect(ok.materials, {CraftMaterial.cristal: 2});
      expect(ok.profile!.material(CraftMaterial.cristal), 1);
      // A un Mágico solo créditos.
      expect(_craft.transferSkill(none, 'm', 'c2', 'giro').ok, isTrue);
    });
  });

  group('condensar (§ 4.3)', () {
    test('recetas, máximo y resultado sin azar', () {
      expect(CraftRules.condenseRecipe(CraftMaterial.cristal),
          (CraftMaterial.esquirla, 20, 100));
      expect(CraftRules.condenseRecipe(CraftMaterial.prisma),
          (CraftMaterial.cristal, 8, 500));
      expect(CraftRules.condenseRecipe(CraftMaterial.ancla), isNull);
      expect(CraftRules.condenseRecipe(CraftMaterial.esquirla), isNull);
      final p = _p(credits: 350, mats: const {CraftMaterial.esquirla: 85});
      expect(CraftRules.condenseMax(p, CraftMaterial.cristal), 3,
          reason: 'créditos para 3 (85 Esquirlas darían 4)');
      final r = _craft.condense(p, CraftMaterial.cristal, 3);
      expect(r.ok, isTrue);
      expect(r.profile!.material(CraftMaterial.esquirla), 25);
      expect(r.profile!.material(CraftMaterial.cristal), 3);
      expect(r.profile!.credits, 50);
      expect(r.gainedMaterials, {CraftMaterial.cristal: 3});
    });

    test('fondos, tope de 99 y materiales que no se condensan', () {
      final p = _p(credits: 5000, mats: const {CraftMaterial.esquirla: 35});
      expect(_craft.condense(p, CraftMaterial.cristal, 2).error,
          'Falta Esquirla del Eco');
      expect(_craft.condense(_p(credits: 50, mats: const {CraftMaterial.esquirla: 40}),
              CraftMaterial.cristal, 1).error,
          startsWith('Faltan'));
      expect(_craft.condense(p, CraftMaterial.cristal, 0).error, 'Elige cuántos');
      expect(_craft.condense(p, CraftMaterial.ancla, 1).ok, isFalse);
      final full = _p(mats: const {
        CraftMaterial.cristal: 98,
        CraftMaterial.esquirla: 99,
      });
      expect(CraftRules.condenseMax(full, CraftMaterial.cristal), 1);
      expect(_craft.condense(full, CraftMaterial.cristal, 2).error,
          startsWith('Pila llena'));
    });

    test('en la sesión: el host valida y aplica a cada jugador (co-op)', () {
      final e = sessionEngine();
      var s = e.addPlayer(e.create(), 'p0',
              _p(credits: 1000, mats: const {CraftMaterial.cristal: 16}))!
          .state;
      s = e.addPlayer(s, 'p1', _p(credits: 100))!.state;
      const a = CraftAction(CraftOp.condense, 'prisma', index: 2);
      // Viaja por la red con el mismo formato que el resto de la mesa.
      final wire = ActionJson.fromJson(ActionJson.toJson(a)) as CraftAction;
      expect([wire.op, wire.targetUid, wire.index], [CraftOp.condense, 'prisma', 2]);
      final step = e.apply(s, 'p0', wire)!;
      final p0 = step.state.players['p0']!.profile;
      expect(p0.material(CraftMaterial.prisma), 2);
      expect(p0.material(CraftMaterial.cristal), 0);
      expect(p0.credits, 0);
      // El invitado sin fondos: el host lo rechaza y nada cambia.
      expect(e.apply(step.state, 'p1', wire), isNull);
      expect(e.apply(s, 'p0',
              const CraftAction(CraftOp.condense, 'nada', index: 1)),
          isNull);
    });
  });

  group('Ecos (§ 4.4)', () {
    test('+3% de cantidad por tier sobre T1', () {
      EcoItem eco(int t) => EcoItem(uid: 'e', tier: t, zone: 1, boss: 1);
      expect(EcoRules.tierBonus(eco(1)), 0);
      expect(EcoRules.tierBonus(eco(8)), closeTo(0.21, 1e-9));
      expect(EcoRules.tierBonus(eco(16)), closeTo(0.45, 1e-9));
      expect(EcoRules.lootBonus(eco(16)).quantity, closeTo(0.45, 1e-9));
      expect(EcoRules.lootBonus(eco(16), players: 2).quantity,
          closeTo(0.55, 1e-9));
    });
  });
}
