// ignore_for_file: avoid_print
// Medición para docs/specs/materials_economy.md. No es parte de la suite.
// Correr con
//   flutter test tool/materiales_economia_measure_test.dart
//
// Arma cada misión de zona con el motor real (mismas semillas que
// tool/hazanas_economia_measure_test.dart) y cuenta sus fuentes de loot
// por piso: grupos que pide el objetivo, élites del mapa, jefe, cofres por
// calidad, misión opcional y el botín de fin (rango A). Después tira esas
// fuentes R veces con las fórmulas reales: `LootRules.rollDrops` (armas y
// materiales), `LootRules.rollMaterials` (tiradas extra de cofre),
// `CraftRules.salvageYield` (desarme de cada arma que cayó),
// `CraftRules.upgradeRarityCost`, `CraftRules.condenseRecipe`,
// `EcoRules.rollRepeats` / `EcoRules.tierQuantity` y `kQuestPrismaChance`.
// Es el techo de una misión limpia, 1 jugador, la mitad de los cofres
// abiertos y todas las armas no legendarias desarmadas.
import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/achievements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/exploration_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/eco_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/game_engine/session_test_helpers.dart';

const _e = CraftMaterial.esquirla, _c = CraftMaterial.cristal, _p = CraftMaterial.prisma;

class Tally {
  final m = <CraftMaterial, double>{_e: 0, _c: 0, _p: 0};
  final w = <Rarity, double>{for (final r in Rarity.values) r: 0};

  /// Lo que da desarmar todo lo que cayó (valor esperado).
  final sv = <CraftMaterial, double>{_e: 0, _c: 0, _p: 0};

  void add(CraftMaterial k, double n) {
    if (m.containsKey(k)) m[k] = m[k]! + n;
  }

  void item(ItemInstance i) {
    w[i.rarity] = w[i.rarity]! + 1;
    if (i.rarity == Rarity.legendario) return; // no se desarman
    final y = CraftRules.salvageYield(i);
    y.guaranteed.forEach((k, n) {
      if (sv.containsKey(k)) sv[k] = sv[k]! + n;
    });
    for (final c in y.chances) {
      if (sv.containsKey(c.material)) {
        sv[c.material] = sv[c.material]! + c.chance * c.count;
      }
    }
  }

  void scale(double k) {
    for (final x in m.keys) {
      m[x] = m[x]! * k;
      sv[x] = sv[x]! * k;
    }
    for (final x in w.keys) {
      w[x] = w[x]! * k;
    }
  }
}

const loot = LootRules();

/// Prismas de Común a Épico (`CraftRules.upgradeRarityCost`).
final int prismToEpic = [Rarity.comun, Rarity.magico, Rarity.raro]
    .fold(0, (a, r) => a + CraftRules.upgradeRarityCost(r)!.$1);

void _roll(math.Random rng, Tally t, int zone, LootSource src,
    {double? chance, double extraBonus = 0, double q = 0, bool eco = false}) {
  final n = EcoRules.rollRepeats(rng.nextDouble, q);
  for (var k = 0; k < n; k++) {
    for (final d in loot.rollDrops(rng.nextDouble,
        zoneLevel: zone,
        source: src,
        chance: chance,
        extraBonus: extraBonus,
        eco: eco)) {
      if (d.item != null) t.item(d.item!);
      if (d.stack?.material case final mat?) t.add(mat, d.count.toDouble());
    }
  }
}

/// Lo que deja una misión (promedio por corrida): drops y desarme.
Tally _mission(Sources src,
    {int zone = 0, double q = 0, int runs = 400, bool eco = false}) {
  final z = zone == 0 ? src.level : zone;
  final rng = math.Random(src.id.hashCode ^ z ^ (q * 1000).round());
  final t = Tally();
  int fl(double x) => x.floor() + (rng.nextDouble() < x - x.floor() ? 1 : 0);
  for (var run = 0; run < runs; run++) {
    for (var i = 0; i < fl(src.battles); i++) {
      _roll(rng, t, z, LootSource.battle, q: q, eco: eco);
    }
    for (var i = 0; i < fl(src.elites); i++) {
      _roll(rng, t, z, LootSource.elite, q: q, eco: eco);
    }
    for (var i = 0; i < fl(src.boss); i++) {
      _roll(rng, t, z, LootSource.boss, q: q, eco: eco);
    }
    for (final e in src.chests.entries) {
      final d = kChestTiers[e.key]!;
      for (var i = 0; i < fl(e.value); i++) {
        _roll(rng, t, z, LootSource.chest,
            chance: d.weaponChance, extraBonus: d.rarityBonus, q: q, eco: eco);
        for (var k = 0; k < d.extraMaterialRolls; k++) {
          for (final m
              in loot.rollMaterials(rng.nextDouble, z, LootSource.chest).entries) {
            t.add(m.key, m.value.toDouble());
          }
        }
        t.add(_e, d.esquirlas.toDouble());
      }
    }
    // Fin de misión, rango A.
    _roll(rng, t, z, LootSource.mission,
        chance: 0.7, extraBonus: 0.5, q: q, eco: eco);
    // Misión opcional (una por misión).
    t.add(_e, kQuestEsquirlas.toDouble());
    t.add(_c, kQuestCristales.toDouble());
    if (z >= kQuestPrismaLevel) t.add(_p, kQuestPrismaChance);
    final armaW = kQuestRewardWeights.values.first /
        kQuestRewardWeights.values.reduce((a, b) => a + b);
    if (rng.nextDouble() < armaW) {
      final rr = rng.nextDouble() < kQuestEpicChance ? Rarity.epico : Rarity.raro;
      t.item(loot.generate(rng.nextDouble, itemLevel: z, rarity: rr));
    }
  }
  t.scale(1 / runs);
  return t;
}

/// Fuentes de una misión (por misión, sumando pisos).
class Sources {
  Sources(this.id, this.level, this.battles, this.elites, this.boss, this.chests);
  final String id;
  final int level;
  final double battles, elites, boss;
  final Map<ChestTier, double> chests;
}

List<Sources> _missions() {
  final out = <Sources>[];
  for (final def in kZoneMissions) {
    final s = <Sources>[];
    for (var seed = 1; seed <= 5; seed++) {
      final e = sessionEngine(zones: true, seed: seed * 7919);
      final prof = zoneProgression.normalize(PlayerProfile(
          name: 'Ana', classId: 'guerrero', level: def.recommendedLevel, unlockedZone: 10));
      GameSession g;
      try {
        g = inField(e, def.id, profiles: [prof]);
      } catch (_) {
        continue;
      }
      final m = g.mission!;
      // `m.enemies` / `m.items` ya traen todos los pisos. Se pelean solo
      // los grupos del objetivo (con la proporción de élites del mapa) y
      // se abre la mitad de los cofres (como hazanas_economia).
      var elites = 0.0, normal = 0.0, boss = 0.0;
      for (final f in m.enemies) {
        if (f.boss) {
          boss++;
        } else {
          normal++;
          if (f.elite) elites++;
        }
      }
      final goal = def.floorGoal > 0 ? def.floorGoal * def.floors : def.goal;
      final eliteShare = normal == 0 ? 0.0 : elites / normal;
      final chests = <ChestTier, double>{};
      for (final it in m.items) {
        if (it.kind != MissionItemKind.chest) continue;
        chests[it.tier] = (chests[it.tier] ?? 0) + 0.5;
      }
      s.add(Sources(def.id, m.zoneLevel, goal * (1 - eliteShare),
          goal * eliteShare, math.max(1, boss), chests));
    }
    if (s.isEmpty) continue;
    double avg(double Function(Sources) f) => s.map(f).reduce((a, b) => a + b) / s.length;
    out.add(Sources(def.id, s.first.level, avg((x) => x.battles), avg((x) => x.elites),
        avg((x) => x.boss), {
      for (final t in ChestTier.values) t: avg((x) => x.chests[t] ?? 0),
    }));
  }
  return out;
}


String _f(double x) => x.toStringAsFixed(x < 10 ? 2 : 1);

void main() {
  test('economía de materiales', () {
    final ms = _missions();
    var ach = const AchievementReward();
    for (final a in kAchievements) {
      ach += a.reward;
    }
    print('hazañas: esq ${ach.esquirlas} cri ${ach.cristales} pri ${ach.prismas}');
    print('Común → Épico: $prismToEpic Prismas');
    print('mis  nv | bat eli cof | esq cri pri (drop) | esq cri pri (desarme) | Rar Épi Leg');
    final cum = {_e: 0.0, _c: 0.0, _p: 0.0};
    final perMission = <List<double>>[];
    for (final s in ms) {
      final t = _mission(s);
      final tot = {for (final k in cum.keys) k: t.m[k]! + t.sv[k]!};
      for (final k in cum.keys) {
        cum[k] = cum[k]! + tot[k]!;
      }
      perMission.add([tot[_e]!, tot[_c]!, tot[_p]!, t.w[Rarity.legendario]!, t.w[Rarity.epico]!]);
      final ch = s.chests.values.reduce((a, b) => a + b);
      print('${s.id.padRight(4)} ${s.level.toString().padLeft(2)} | '
          '${_f(s.battles)} ${_f(s.elites)} ${_f(ch)} | '
          '${_f(t.m[_e]!)} ${_f(t.m[_c]!)} ${_f(t.m[_p]!)} | '
          '${_f(t.sv[_e]!)} ${_f(t.sv[_c]!)} ${_f(t.sv[_p]!)} | '
          '${_f(t.w[Rarity.raro]!)} ${_f(t.w[Rarity.epico]!)} ${_f(t.w[Rarity.legendario]!)}');
    }
    print('campaña completa (1 vez cada misión): '
        'esq ${_f(cum[_e]!)} cri ${_f(cum[_c]!)} pri ${_f(cum[_p]!)} '
        '(+ hazañas esq ${ach.esquirlas} cri ${ach.cristales} pri ${ach.prismas})');
    final (_, cn, cc) = CraftRules.condenseRecipe(_c)!;
    final (_, pn, pc) = CraftRules.condenseRecipe(_p)!;
    // Techo con conversión: todo lo bajo pasa a Prisma (menos una reserva
    // de 10 Esquirlas y 2 Cristales por misión para usar).
    double withConv(double esq, double cri, double pri) =>
        pri + math.max(0, esq - 10) / (cn * pn) + math.max(0, cri - 2) / pn;
    for (final band in [
      ('temprano', 0, ms.length ~/ 3),
      ('medio', ms.length ~/ 3, 2 * ms.length ~/ 3),
      ('tardío', 2 * ms.length ~/ 3, ms.length),
    ]) {
      final sl = perMission.sublist(band.$2, band.$3);
      double av(int i) => sl.map((x) => x[i]).reduce((a, b) => a + b) / sl.length;
      final pri = av(2), cri = av(1), esq = av(0);
      print('  ${band.$1}: por misión esq ${_f(esq)} cri ${_f(cri)} pri ${_f(pri)} '
          '→ Épico ≈ ${_f(prismToEpic / pri)} misiones '
          '(con conversión ≈ ${_f(prismToEpic / withConv(esq, cri, pri))}); '
          'leg/misión ${_f(av(3))} (≈ ${_f(1 / math.max(1e-6, av(3)))} misiones)'
          '; Épicos que caen/misión ${_f(av(4))}');
    }
    // Endgame: zona 10 a nivel 50 como Eco, con cantidad de mods y tier.
    final last = ms.last;
    for (final (label, mods, tier) in [
      ('Eco T1 común (0 mods)', 0.0, 1),
      ('Eco T1 raro (~2.5 mods)', 0.16, 1),
      ('Eco T8 raro', 0.16, 8),
      ('Eco T16 legendario (~4.5 mods)', 0.29, 16),
    ]) {
      final q = mods + EcoRules.tierQuantity * (tier - 1);
      final t = _mission(last, zone: 50, q: q, runs: 300, eco: true);
      final esq = t.m[_e]! + t.sv[_e]!, cri = t.m[_c]! + t.sv[_c]!;
      final pri = t.m[_p]! + t.sv[_p]!;
      print('  $label q=+${(q * 100).round()}%: esq ${_f(esq)} '
          'cri ${_f(cri)} pri ${_f(pri)} épi ${_f(t.w[Rarity.epico]!)} '
          'leg ${_f(t.w[Rarity.legendario]!)} '
          '→ Épico ≈ ${_f(prismToEpic / pri)} Ecos '
          '(con conversión ≈ ${_f(prismToEpic / withConv(esq, cri, pri))}), '
          'Legendario ≈ ${_f(1 / math.max(1e-6, t.w[Rarity.legendario]!))} Ecos');
    }
    print('  conversión: $cn esq + ₵$cc → 1 cri; $pn cri + ₵$pc → 1 pri '
        '(1 pri = ${cn * pn} esq + ₵${cc * pn + pc})');
  });
}
