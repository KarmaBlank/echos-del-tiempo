import 'package:echos_del_tiempo/game_engine/data/eco_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Ecos: generación, nivel, modificadores, loot, drops y crafteo
/// (docs/specs/ecos_atlas.md § 2–4).
const rules = EcoRules();

EcoItem eco({
  int tier = 1,
  int zone = 1,
  int boss = 1,
  Rarity rarity = Rarity.magico,
  List<EcoModRoll> mods = const [EcoModRoll('vida', 30)],
  int floors = 2,
}) =>
    EcoItem(
        uid: 'e1',
        tier: tier,
        zone: zone,
        boss: boss,
        rarity: rarity,
        mods: mods,
        floors: floors,
        seed: 4242);

Combatant enemy({bool boss = false}) => Combatant(
    id: 'x',
    name: 'x',
    isPlayer: false,
    hp: 1000,
    maxHp: 1000,
    speed: 10,
    attack: 100,
    critChance: 0,
    breakBase: 50,
    boss: boss);

Combatant player() => Combatant(
    id: 'p',
    name: 'p',
    isPlayer: true,
    hp: 500,
    maxHp: 500,
    speed: 10,
    attack: 50,
    critChance: 0);

void main() {
  group('generación', () {
    test('determinística por semilla y en rango', () {
      final a = rules.generate(mulberry32(7), tier: 5);
      final b = rules.generate(mulberry32(7), tier: 5);
      expect(a, b);
      expect(a.tier, 5);
      for (var s = 0; s < 200; s++) {
        final e = rules.generate(mulberry32(s), tier: 3);
        expect(e.zone, inInclusiveRange(1, 10));
        expect(e.boss, inInclusiveRange(1, 10));
        expect(e.floors, inInclusiveRange(1, 3));
        expect(e.mods.length, ecoModRange(e.rarity).$1);
        expect(e.mods.map((m) => m.id).toSet(), hasLength(e.mods.length),
            reason: 'sin mods repetidos');
        for (final m in e.mods) {
          final d = kEcoMods[m.id]!;
          expect(m.value, inInclusiveRange(d.min, d.max));
        }
        expect(e.name != null, e.rarity.index >= Rarity.raro.index);
      }
    });

    test('tier 1–16 → monstruos nivel 50–80', () {
      expect(EcoItem.monsterLevelFor(1), 50);
      expect(EcoItem.monsterLevelFor(8), 64);
      expect(EcoItem.monsterLevelFor(16), 80);
      expect(rules.generate(mulberry32(1), tier: 40).tier, 16);
      final z = rules.zoneDef(eco(tier: 16, zone: 4, boss: 10, floors: 3));
      expect(z.floors, 3);
      expect(z.gen, rules.catalog.zone(4)!.gen);
      expect(z.minLevel, 80);
      expect(z.maxLevel, 80);
      expect(z.bossName, 'Devorador de Eras');
    });

    test('las zonas del Atlas pesan ×3', () {
      const fx = AtlasEffects(zones: {3});
      var hits = 0, base = 0;
      for (var s = 0; s < 3000; s++) {
        if (rules.rollZone(mulberry32(s), atlas: fx) == 3) hits++;
        if (rules.rollZone(mulberry32(s)) == 3) base++;
      }
      expect(base / 3000, closeTo(0.10, 0.025));
      expect(hits / 3000, closeTo(3 / 12, 0.03));
    });
  });

  group('mazmorra', () {
    test('misión: grupos de la zona, jefe de su zona, horda suma grupos', () {
      final e = eco(zone: 2, boss: 3, mods: const [EcoModRoll('horda', 2)]);
      final m = rules.missionDef(e);
      expect(m.id, EcoRules.missionId);
      expect(m.zone, 2);
      expect(m.floors, 2);
      expect(m.floorGoal, 6);
      expect(m.boss.first, 'golemReloj');
      expect(m.groups.expand((g) => g).toSet(), containsAll(['arana', 'lobo']));
      expect(m.name, 'Eco de Bosque Hondo · T1');
    });

    test('mismo Eco → misma mazmorra; los pisos son los del Eco', () {
      final e = eco(zone: 6, floors: 3);
      final a = MapGenerator.zone(rules.zoneDef(e), e.seed);
      final b = MapGenerator.zone(rules.zoneDef(e), e.seed);
      expect(a.rows, b.rows);
      expect(a.floors, hasLength(3));
      expect(a.floors.every((f) => f.level == 50), isTrue);
      expect(a.floors.last.boss, isNotNull);
    });
  });

  group('modificadores en batalla', () {
    BattleState battle({bool boss = false}) =>
        BattleState(party: [player()], enemies: [enemy(boss: boss)]);

    test('vida, ATQ, velocidad, quiebre, Quemadura y curación', () {
      final s = battle();
      EcoRules.applyBattle(
          s,
          eco(mods: const [
            EcoModRoll('vida', 30),
            EcoModRoll('furia', 20),
            EcoModRoll('prisa', 10),
            EcoModRoll('coraza', 50),
            EcoModRoll('brasas', 2),
            EcoModRoll('herida', 25),
          ]));
      final en = s.enemies.single;
      expect(en.maxHp, 1300);
      expect(en.hp, 1300);
      expect(en.attack, 120);
      expect(en.speed, closeTo(11, 1e-9));
      expect(en.breakBase, closeTo(75, 1e-9));
      expect(en.inflicts?.kind, StatusKind.burn);
      expect(en.inflicts?.stacks, 2);
      expect(s.party.single.healReceived, closeTo(-0.25, 1e-9));
    });

    test('tirano solo al jefe; Templado baja la dificultad 25%', () {
      final e = eco(mods: const [EcoModRoll('tirano', 40)]);
      final normal = battle();
      EcoRules.applyBattle(normal, e);
      expect(normal.enemies.single.maxHp, 1000);
      final boss = battle(boss: true);
      EcoRules.applyBattle(boss, e, boss: true);
      expect(boss.enemies.single.maxHp, 1400);
      final soft = battle(boss: true);
      EcoRules.applyBattle(soft, e,
          atlas: const AtlasEffects(tempered: 0.25), boss: true);
      expect(soft.enemies.single.maxHp, 1300);
    });

    test('sequía apaga la regeneración', () {
      expect(
          EcoRules.noRegen(eco(mods: const [EcoModRoll('sequia', 1)])), isTrue);
      expect(EcoRules.noRegen(eco()), isFalse);
    });
  });

  group('bonus de loot', () {
    test('cada mod suma cantidad y rareza; Potencia los sube', () {
      final e =
          eco(mods: const [EcoModRoll('vida', 20), EcoModRoll('furia', 10)]);
      final b = EcoRules.modBonus(e);
      expect(b.quantity, closeTo(0.16, 1e-9));
      expect(b.rarity, closeTo(0.08, 1e-9));
      final p = EcoRules.modBonus(e, modPower: 0.2);
      expect(p.quantity, closeTo(0.192, 1e-9));
    });

    test('co-op: +10% de cantidad por jugador extra; Atlas suma', () {
      final e = eco(mods: const []);
      expect(EcoRules.lootBonus(e).quantity, 0);
      expect(EcoRules.lootBonus(e, players: 4).quantity, closeTo(0.30, 1e-9));
      final fx = EcoRules.lootBonus(e,
          players: 2, atlas: const AtlasEffects(quantity: 0.2, rarity: 0.16));
      expect(fx.quantity, closeTo(0.30, 1e-9));
      expect(fx.rarity, closeTo(0.16, 1e-9));
    });

    test('repeticiones: ⌊1+q⌋ y una más con frac', () {
      expect(EcoRules.rollRepeats(() => 0.0, 0), 1);
      expect(EcoRules.rollRepeats(() => 0.2, 0.34), 2);
      expect(EcoRules.rollRepeats(() => 0.5, 0.34), 1);
      expect(EcoRules.rollRepeats(() => 0.9, 1.0), 2);
      expect(EcoRules.rollRepeats(() => 0.1, 1.5), 3);
    });
  });

  group('drops', () {
    test('nada por debajo de nivel 45 (sin tirar el azar)', () {
      var calls = 0;
      double r() {
        calls++;
        return 0;
      }

      expect(rules.rollDrop(r, level: 44, source: LootSource.boss), isNull);
      expect(calls, 0);
      expect(rules.rollDrop(r, level: 45, source: LootSource.boss)?.tier, 1);
      expect(
          rules.rollDrop(() => 0.5, level: 50, source: LootSource.boss), isNull,
          reason: 'jefe 30%');
      expect(EcoRules.dropChance(LootSource.battle), 0.02);
      expect(EcoRules.dropChance(LootSource.mission), 0);
    });

    test('Rutas del Eco sube la chance', () {
      expect(
          rules.rollDrop(() => 0.35,
              level: 50,
              source: LootSource.boss,
              atlas: const AtlasEffects(ecoDrop: 0.25)),
          isNotNull);
    });

    test('dentro de un Eco: 70% mismo tier, 20% +1, 10% −1', () {
      final cur = eco(tier: 5);
      expect(EcoRules.dropTier(() => 0.1, cur), 5);
      expect(EcoRules.dropTier(() => 0.8, cur), 6);
      expect(EcoRules.dropTier(() => 0.95, cur), 4);
      expect(EcoRules.dropTier(() => 0.95, eco(tier: 1)), 1);
      expect(EcoRules.dropTier(() => 0.8, eco(tier: 16)), 16);
      expect(EcoRules.dropTier(() => 0.8, null), 1);
    });

    test('fin del Eco: 1 Eco del mismo tier o +1; Resonancia otro', () {
      final done = eco(tier: 7);
      final same = rules.completionDrops(() => 0.9, done);
      expect(same, hasLength(1));
      expect(same.single.tier, 7);
      final up = rules.completionDrops(() => 0.1, done);
      expect(up.single.tier, 8);
      final res = rules.completionDrops(() => 0.1, done,
          atlas: const AtlasEffects(extraEco: 0.3));
      expect(res, hasLength(2));
    });

    test('Ancla: por fuente y con el Atlas', () {
      expect(EcoRules.rollAnchor(() => 0.39, LootSource.boss), isTrue);
      expect(EcoRules.rollAnchor(() => 0.41, LootSource.boss), isFalse);
      expect(
          EcoRules.rollAnchor(() => 0.5, LootSource.boss,
              atlas: const AtlasEffects(anchor: 0.5)),
          isTrue);
    });

    test('mods gratis del Atlas: distintos a los que ya tiene', () {
      final e = eco(mods: const [EcoModRoll('vida', 30)]);
      final f = EcoRules.withFreeMods(mulberry32(3), e, 2);
      expect(f.mods, hasLength(3));
      expect(f.mods.map((m) => m.id).toSet(), hasLength(3));
      expect(EcoRules.withFreeMods(mulberry32(3), e, 0), same(e));
    });

    test('sanitize: mods desconocidos, repetidos, fuera de rango y tope', () {
      final s = EcoRules.sanitize(eco(rarity: Rarity.magico, mods: const [
        EcoModRoll('nada', 1),
        EcoModRoll('vida', 999),
        EcoModRoll('vida', 30),
        EcoModRoll('furia', 1),
        EcoModRoll('prisa', 15),
      ]));
      expect(s.mods, const [EcoModRoll('vida', 40), EcoModRoll('furia', 10)]);
    });
  });

  group('crafteo', () {
    PlayerProfile withEco(EcoItem e, Map<CraftMaterial, int> mats) {
      final p = newProfile('Ana', 'guerrero').copyWith(materials: mats);
      return InventoryRules.addEco(p, e).$1;
    }

    test('Esquirla: mods nuevos, misma cantidad', () {
      final p = withEco(
          eco(rarity: Rarity.raro, mods: const [
            EcoModRoll('vida', 20),
            EcoModRoll('furia', 10),
          ]),
          {CraftMaterial.esquirla: 2});
      final uid = p.ecos.single.uid;
      final r = rules.craft(p, uid, EcoCraftOp.reroll, mulberry32(9));
      expect(r.ok, isTrue);
      expect(r.after!.mods, hasLength(2));
      expect(r.profile!.material(CraftMaterial.esquirla), 1);
      expect(r.profile!.ecoByUid(uid), r.after);
    });

    test('Cristal: +1 mod hasta el tope de la rareza', () {
      final p = withEco(eco(rarity: Rarity.magico), {CraftMaterial.cristal: 2});
      final uid = p.ecos.single.uid;
      final r = rules.craft(p, uid, EcoCraftOp.addMod, mulberry32(1));
      expect(r.after!.mods, hasLength(2));
      expect(EcoRules.cannotCraft(r.profile!, uid, EcoCraftOp.addMod),
          'Máximo de modificadores');
    });

    test('Prisma: rareza +1 (hasta Épico) con los mods del mínimo', () {
      final p = withEco(eco(rarity: Rarity.comun, mods: const []),
          {CraftMaterial.prisma: 10});
      final uid = p.ecos.single.uid;
      var q = p;
      for (final want in [Rarity.magico, Rarity.raro, Rarity.epico]) {
        final r = rules.craft(q, uid, EcoCraftOp.rarity, mulberry32(2));
        expect(r.ok, isTrue, reason: r.error);
        expect(r.after!.rarity, want);
        expect(r.after!.mods.length, ecoModRange(want).$1);
        q = r.profile!;
      }
      expect(q.material(CraftMaterial.prisma), 10 - 1 - 2 - 3);
      expect(EcoRules.cannotCraft(q, uid, EcoCraftOp.rarity),
          'Rareza máxima (Épico)');
    });

    test('Ancla: tier +1 hasta 16; sin material no se puede', () {
      final p = withEco(eco(tier: 15), {CraftMaterial.ancla: 1});
      final uid = p.ecos.single.uid;
      final r = rules.craft(p, uid, EcoCraftOp.tier, mulberry32(2));
      expect(r.after!.tier, 16);
      expect(r.after!.mods, eco().mods, reason: 'conserva los mods');
      expect(EcoRules.cannotCraft(r.profile!, uid, EcoCraftOp.tier),
          'Tier máximo (16)');
      final none = withEco(eco(tier: 3), const {});
      expect(EcoRules.cannotCraft(none, none.ecos.single.uid, EcoCraftOp.tier),
          'Falta Ancla Temporal');
      expect(EcoRules.cannotCraft(none, 'x', EcoCraftOp.tier),
          'No tienes ese Eco');
    });
  });

  group('inventario', () {
    test('ocupa una casilla, se da y se tira como un objeto', () {
      final p = newProfile('Ana', 'guerrero');
      final used = InventoryRules.cellsUsed(p);
      final (q, uid) = InventoryRules.addEco(p, eco());
      expect(uid, startsWith('eco'));
      expect(InventoryRules.cellsUsed(q), used + 1);
      expect(InventoryRules.layout(q).cells, contains(uid));
      final t = const InventoryRules().take(q, uid);
      expect(t.drop?.eco?.tier, 1);
      expect(t.profile!.ecos, isEmpty);
      expect(InventoryRules.receive(t.profile!, t.drop!)!.ecos, hasLength(1));
    });
  });
}
