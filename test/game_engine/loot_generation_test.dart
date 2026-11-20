import 'package:echos_del_tiempo/game_engine/data/affixes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/missions_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapon_passives.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:flutter_test/flutter_test.dart';

const _loot = LootRules();
const _items = ItemRules();

/// Comprueba que [i] respeta cupos, tipo, nivel y rangos.
void _valid(ItemInstance i) {
  final w = kWeapons[i.baseId]!;
  final r = i.rarity;
  expect(w.level, lessThanOrEqualTo(i.itemLevel), reason: 'nivel de base');
  expect(i.affixes.length, lessThanOrEqualTo(r.maxMods));
  final ids = i.affixes.map((a) => a.affixId).toSet();
  expect(ids, hasLength(i.affixes.length), reason: 'sin afijos repetidos');
  var pre = 0, suf = 0;
  for (final a in i.affixes) {
    final def = kAffixes[a.affixId]!;
    expect(def.allows(w.type), isTrue, reason: '${def.id} en ${w.type}');
    if (def.slot == AffixSlot.prefix) {
      pre++;
    } else {
      suf++;
    }
    if (!a.fixed) {
      final t = def.tier(a.tier)!;
      expect(t.minLevel, lessThanOrEqualTo(i.itemLevel),
          reason: '${def.id} T${a.tier} en nivel ${i.itemLevel}');
      expect(a.value, inInclusiveRange(t.min, t.max));
    }
  }
  expect(pre, lessThanOrEqualTo(r.affixSideCap));
  expect(suf, lessThanOrEqualTo(r.affixSideCap));
  expect(_items.sanitize(i), i, reason: 'lo generado ya es válido');
}

void main() {
  test('rareza: probabilidades base 60 / 27 / 10 / 2.7 / 0.3', () {
    final odds = LootRules.rarityOdds(1, LootSource.battle, eco: true);
    expect(odds[Rarity.comun], closeTo(0.60, 1e-9));
    expect(odds[Rarity.magico], closeTo(0.27, 1e-9));
    expect(odds[Rarity.raro], closeTo(0.10, 1e-9));
    expect(odds[Rarity.epico], closeTo(0.027, 1e-9));
    expect(odds[Rarity.legendario], closeTo(0.003, 1e-9));
    // Fuera de un Eco el Épico pesa 1.5 (materials_economy.md § 4.1).
    final zone = LootRules.rarityOdds(1, LootSource.battle);
    expect(zone[Rarity.epico], closeTo(1.5 / 98.8, 1e-9));
    expect(zone[Rarity.epico]!, lessThan(odds[Rarity.epico]!));
    // Zona, élites y jefes mejoran la rareza.
    final boss = LootRules.rarityOdds(50, LootSource.boss);
    expect(boss[Rarity.legendario]!, greaterThan(0.01));
    expect(boss[Rarity.comun]!, lessThan(0.40));
    expect(LootRules.rarityOdds(25, LootSource.elite)[Rarity.raro]!,
        greaterThan(odds[Rarity.raro]!));
  });

  test('rareza sobre muchas semillas ≈ las probabilidades', () {
    final count = {for (final r in Rarity.values) r: 0};
    const n = 30000;
    final rng = mulberry32(777);
    for (var i = 0; i < n; i++) {
      final r = _loot.rollRarity(rng, 1, LootSource.battle, eco: true);
      count[r] = count[r]! + 1;
    }
    expect(count[Rarity.comun]! / n, closeTo(0.60, 0.015));
    expect(count[Rarity.magico]! / n, closeTo(0.27, 0.015));
    expect(count[Rarity.raro]! / n, closeTo(0.10, 0.01));
    expect(count[Rarity.epico]! / n, closeTo(0.027, 0.005));
    expect(count[Rarity.legendario]! / n, closeTo(0.003, 0.002));
  });

  test('generación: cupos, tipo, tiers por nivel y valores en rango', () {
    for (var seed = 1; seed <= 400; seed++) {
      final rng = mulberry32(seed);
      final il = 1 + seed % 50;
      final r = Rarity.values[seed % 5];
      final i = _loot.generate(rng, itemLevel: il, rarity: r);
      _valid(i);
      switch (i.rarity) {
        case Rarity.comun:
          expect(i.affixes, isEmpty);
        case Rarity.magico:
          expect(i.affixes.length, inInclusiveRange(1, 2));
        case Rarity.raro:
          expect(i.affixes.length, inInclusiveRange(3, 4));
          expect(i.name, isNotNull);
        case Rarity.epico:
          expect(i.affixes.length, inInclusiveRange(5, 6));
          expect(weaponPassivePool(kWeapons[i.baseId]!.type)
              .map((p) => p.id), contains(i.passiveId));
        case Rarity.legendario:
          final u = kUniques[i.uniqueId]!;
          expect(i.baseId, u.baseId);
          expect(i.passiveId, u.passiveId);
          expect(i.affixes.where((a) => a.fixed), hasLength(u.fixed.length));
          expect(i.affixes.where((a) => !a.fixed).length,
              inInclusiveRange(u.randomMin, u.randomMax));
      }
    }
  });

  test('nivel bajo: solo T5 y bases de nivel ≤; nivel alto: aparecen T1', () {
    final tiersLow = <int>{}, tiersHigh = <int>{};
    for (var seed = 0; seed < 200; seed++) {
      final lo = _loot.generate(mulberry32(seed), itemLevel: 5, rarity: Rarity.epico);
      final hi = _loot.generate(mulberry32(seed), itemLevel: 50, rarity: Rarity.epico);
      tiersLow.addAll(lo.affixes.map((a) => a.tier));
      tiersHigh.addAll(hi.affixes.map((a) => a.tier));
      expect(kWeapons[lo.baseId]!.level, lessThanOrEqualTo(5));
    }
    // Nivel 5: los T5 y el T4 de robo de vida (desde 5); nunca T1–T3.
    expect(tiersLow, {4, 5});
    expect(tiersHigh, containsAll([1, 2, 3, 4, 5]));
  });

  test('determinística: misma semilla → misma arma', () {
    final a = _loot.generate(mulberry32(42), itemLevel: 30, rarity: Rarity.epico);
    final b = _loot.generate(mulberry32(42), itemLevel: 30, rarity: Rarity.epico);
    expect(a, b);
    expect(a.toJson(), b.toJson());
  });

  test('azar constante (0 o 0.99) no se cuelga y respeta los cupos', () {
    for (final v in [0.0, 0.5, 0.999999]) {
      for (final r in Rarity.values) {
        _valid(_loot.generate(() => v, itemLevel: 50, rarity: r));
      }
    }
  });

  test('legendario sin único posible sale Épico', () {
    // Ningún único tiene base de nivel 1.
    final i = _loot.generate(() => 0.0, itemLevel: 1, rarity: Rarity.legendario);
    expect(i.rarity, Rarity.epico);
    expect(i.passiveId, isNotNull);
  });

  test('nivel de zona y de objeto', () {
    final m1 = kPrototypeMissions[0], m3 = kPrototypeMissions[2];
    expect(LootRules.zoneLevel(m1, [1]), 1);
    expect(LootRules.zoneLevel(m3, [1, 1]), 9); // 7 + rango A
    expect(LootRules.zoneLevel(m1, [20, 30]), 25);
    expect(LootRules.zoneLevel(m1, [99]), 50);
    expect(LootRules.itemLevelFor(10, LootSource.battle), 10);
    expect(LootRules.itemLevelFor(10, LootSource.elite), 11);
    expect(LootRules.itemLevelFor(10, LootSource.boss), 12);
    expect(LootRules.itemLevelFor(50, LootSource.boss), 50);
  });

  test('drops por fuente: jefe 2 armas, élite 1–2, materiales', () {
    final boss = _loot.rollDrops(() => 0.0, zoneLevel: 10, source: LootSource.boss);
    expect(boss.where((d) => d.isItem), hasLength(2));
    expect(boss.where((d) => d.stack == StackKind.esquirla).single.count, 2);
    final elite = _loot.rollDrops(() => 0.0, zoneLevel: 10, source: LootSource.elite);
    expect(elite.where((d) => d.isItem), hasLength(2));
    final none = _loot.rollDrops(() => 0.99, zoneLevel: 10, source: LootSource.battle);
    expect(none, isEmpty);
    // Muchas batallas: ~30% de armas, ~10% de Esquirlas en la zona 1.
    final rng = mulberry32(99);
    var weapons = 0, shards = 0;
    const n = 5000;
    for (var i = 0; i < n; i++) {
      final d = _loot.rollDrops(rng, zoneLevel: 1, source: LootSource.battle);
      weapons += d.where((x) => x.isItem).length;
      shards += d.where((x) => x.stack == StackKind.esquirla).length;
    }
    expect(weapons / n, closeTo(0.30, 0.03));
    expect(shards / n, closeTo(0.10, 0.02));
  });

  test('sesgo de familia: más bases de la clase del jugador', () {
    final rng = mulberry32(5);
    var mine = 0;
    const n = 2000;
    for (var i = 0; i < n; i++) {
      if (_loot.pickBase(rng, 50, family: 'maga').classId == 'maga') mine++;
    }
    // 2× de peso → ~40% (contra 25% sin sesgo).
    // v0.8.1: la Maga tiene 4 tomos más (Invocador), sube un poco.
    expect(mine / n, inInclusiveRange(0.33, 0.52));
  });
}
