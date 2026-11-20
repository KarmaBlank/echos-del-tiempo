// ignore_for_file: avoid_print
// Medición para docs/specs/materials_economy.md (BORRADOR). No es parte de
// la suite. Correr con
//   flutter test tool/materiales_economia_measure_test.dart
//
// Arma cada misión de zona con el motor real (mismas semillas que
// tool/hazanas_economia_measure_test.dart) y cuenta sus fuentes de loot
// por piso: grupos que pide el objetivo, élites del mapa, jefe, cofres por
// calidad, misión opcional y el botín de fin (rango A). Después tira esas
// fuentes R veces con `LootRules.rollDrops` (armas reales) y con una copia
// parametrizable de `rollMaterials` / `salvageYield` (para poder simular
// la propuesta con el mismo código). Es el techo de una misión limpia, 1
// jugador, todos los cofres abiertos y todas las armas desarmadas.
import 'dart:math' as math;

import 'package:echos_del_tiempo/game_engine/data/achievements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/exploration_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/game_engine/session_test_helpers.dart';

const _e = CraftMaterial.esquirla, _c = CraftMaterial.cristal, _p = CraftMaterial.prisma;

/// Parámetros de economía (hoy = valores del motor).
class Rates {
  const Rates({
    required this.name,
    required this.chance,
    required this.salvage,
    required this.questPrisma,
    required this.prismToEpic,
    required this.cristalToEpic,
    required this.skillMats,
    this.tierQuantity = 0,
    this.conv = const {},
  });
  final String name;
  final Map<CraftMaterial, double> chance;

  /// Desarme por rareza: seguro + chance de prisma.
  final Map<Rarity, (Map<CraftMaterial, int>, double)> salvage;
  final double questPrisma;
  final int prismToEpic, cristalToEpic;

  /// Materiales para traer una habilidad a un Épico.
  final Map<CraftMaterial, int> skillMats;

  /// + cantidad por tier de Eco por encima de T1.
  final double tierQuantity;

  /// Conversión: material → (cuántos del inferior, créditos).
  final Map<CraftMaterial, (int, int)> conv;
}

const today = Rates(
  name: 'HOY',
  chance: {_e: 0.10, _c: 0.04, _p: 0.015},
  salvage: {
    Rarity.comun: ({_e: 1}, 0),
    Rarity.magico: ({_e: 2}, 0), // + 25% cristal (abajo)
    Rarity.raro: ({_c: 1, _e: 1}, 0.10),
    Rarity.epico: ({_c: 2}, 0.35),
    Rarity.legendario: ({_p: 1, _c: 2}, 0),
  },
  questPrisma: 1,
  prismToEpic: 7, // 1 + 2 + 4
  cristalToEpic: 1, // del 5.º al 6.º mod
  skillMats: {},
);

const proposal = Rates(
  name: 'PROPUESTA',
  chance: {_e: 0.08, _c: 0.025, _p: 0.006},
  salvage: {
    Rarity.comun: ({_e: 1}, 0),
    Rarity.magico: ({_e: 2}, 0),
    Rarity.raro: ({_e: 2}, 0.05), // cristal pasa a 50% (abajo)
    Rarity.epico: ({_c: 1}, 0.15),
    Rarity.legendario: ({_p: 1, _c: 2}, 0),
  },
  questPrisma: 0.5,
  prismToEpic: 10, // 1 + 3 + 6
  cristalToEpic: 1,
  skillMats: {_c: 2},
  tierQuantity: 0.03,
  conv: {_c: (10, 100), _p: (10, 500)},
);

class Tally {
  final m = <CraftMaterial, double>{_e: 0, _c: 0, _p: 0};
  final w = <Rarity, double>{for (final r in Rarity.values) r: 0};
  void add(CraftMaterial k, double n) => m[k] = m[k]! + n;
  void scale(double k) {
    for (final x in m.keys) {
      m[x] = m[x]! * k;
    }
    for (final x in w.keys) {
      w[x] = w[x]! * k;
    }
  }
}

const loot = LootRules();

void _roll(Rates r, math.Random rng, Tally t, int zone, LootSource src,
    {double? chance, double extraBonus = 0, double q = 0}) {
  final reps = 1 + q;
  var n = reps.floor() + (rng.nextDouble() < reps - reps.floor() ? 1 : 0);
  for (var k = 0; k < n; k++) {
    for (final d in loot.rollDrops(rng.nextDouble,
        zoneLevel: zone, source: src, chance: chance, extraBonus: extraBonus)) {
      if (d.item != null) t.w[d.item!.rarity] = t.w[d.item!.rarity]! + 1;
    }
    final mult = LootRules.materialMultiplier(src) * (1 + LootRules.zoneBonus(zone));
    for (final e in r.chance.entries) {
      if (rng.nextDouble() < math.min(0.95, e.value * mult)) t.add(e.key, 1);
    }
    if (src == LootSource.boss) t.add(_e, 1);
  }
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

/// Lo que deja una misión (promedio por corrida), sin desarmar y desarmando.
(Tally drops, Map<CraftMaterial, double> salvaged) _mission(
    Rates r, Sources src, {int zone = 0, double q = 0, int runs = 400}) {
  final z = zone == 0 ? src.level : zone;
  final rng = math.Random(src.id.hashCode ^ z ^ (q * 1000).round());
  final t = Tally();
  int fl(double x) => x.floor() + (rng.nextDouble() < x - x.floor() ? 1 : 0);
  for (var run = 0; run < runs; run++) {
    for (var i = 0; i < fl(src.battles); i++) {
      _roll(r, rng, t, z, LootSource.battle, q: q);
    }
    for (var i = 0; i < fl(src.elites); i++) {
      _roll(r, rng, t, z, LootSource.elite, q: q);
    }
    for (var i = 0; i < fl(src.boss); i++) {
      _roll(r, rng, t, z, LootSource.boss, q: q);
    }
    for (final e in src.chests.entries) {
      final d = kChestTiers[e.key]!;
      for (var i = 0; i < fl(e.value); i++) {
        _roll(r, rng, t, z, LootSource.chest,
            chance: d.weaponChance, extraBonus: d.rarityBonus, q: q);
        for (var k = 0; k < d.extraMaterialRolls; k++) {
          _roll(r, rng, t, z, LootSource.chest, chance: 0, q: q);
        }
        t.add(_e, d.esquirlas.toDouble());
      }
    }
    // Fin de misión, rango A.
    _roll(r, rng, t, z, LootSource.mission, chance: 0.7, extraBonus: 0.5, q: q);
    // Misión opcional (una por misión).
    t.add(_e, kQuestEsquirlas.toDouble());
    t.add(_c, kQuestCristales.toDouble());
    if (z >= kQuestPrismaLevel) t.add(_p, r.questPrisma);
    final armaW = kQuestRewardWeights.values.first /
        kQuestRewardWeights.values.reduce((a, b) => a + b);
    if (rng.nextDouble() < armaW) {
      final rr = rng.nextDouble() < kQuestEpicChance ? Rarity.epico : Rarity.raro;
      t.w[rr] = t.w[rr]! + 1;
    }
  }
  t.scale(1 / runs);
  final sv = <CraftMaterial, double>{_e: 0, _c: 0, _p: 0};
  for (final e in t.w.entries) {
    if (e.key == Rarity.legendario) continue; // los legendarios no se desarman
    final (safe, pc) = r.salvage[e.key]!;
    final hi = z >= 25 ? 1 : 0;
    for (final s in safe.entries) {
      final extra = s.key == _e && e.key != Rarity.epico ? hi : 0;
      sv[s.key] = sv[s.key]! + e.value * (s.value + extra);
    }
    if (e.key == Rarity.epico) sv[_c] = sv[_c]! + e.value * hi;
    sv[_p] = sv[_p]! + e.value * pc;
    if (e.key == Rarity.magico) sv[_c] = sv[_c]! + e.value * 0.25;
    if (e.key == Rarity.raro && r.name != 'HOY') sv[_c] = sv[_c]! + e.value * 0.5;
  }
  return (t, sv);
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
    for (final r in [today, proposal]) {
      print('\n===== ${r.name} =====');
      print('mis  nv | bat eli cof | esq cri pri (drop) | esq cri pri (desarme) | Rar Épi Leg');
      final cum = {_e: 0.0, _c: 0.0, _p: 0.0};
      final perMission = <List<double>>[];
      for (final s in ms) {
        final (t, sv) = _mission(r, s);
        final tot = {for (final k in cum.keys) k: t.m[k]! + sv[k]!};
        for (final k in cum.keys) {
          cum[k] = cum[k]! + tot[k]!;
        }
        perMission.add([tot[_e]!, tot[_c]!, tot[_p]!, t.w[Rarity.legendario]!, t.w[Rarity.epico]!]);
        final ch = s.chests.values.reduce((a, b) => a + b);
        print('${s.id.padRight(4)} ${s.level.toString().padLeft(2)} | '
            '${_f(s.battles)} ${_f(s.elites)} ${_f(ch)} | '
            '${_f(t.m[_e]!)} ${_f(t.m[_c]!)} ${_f(t.m[_p]!)} | '
            '${_f(sv[_e]!)} ${_f(sv[_c]!)} ${_f(sv[_p]!)} | '
            '${_f(t.w[Rarity.raro]!)} ${_f(t.w[Rarity.epico]!)} ${_f(t.w[Rarity.legendario]!)}');
      }
      print('campaña completa (1 vez cada misión): '
          'esq ${_f(cum[_e]!)} cri ${_f(cum[_c]!)} pri ${_f(cum[_p]!)} '
          '(+ hazañas esq ${ach.esquirlas} cri ${ach.cristales} pri ${ach.prismas})');
      // Hitos: misiones de su zona para juntar un Épico desde Común.
      for (final band in [
        ('temprano', 0, ms.length ~/ 3),
        ('medio', ms.length ~/ 3, 2 * ms.length ~/ 3),
        ('tardío', 2 * ms.length ~/ 3, ms.length),
      ]) {
        final sl = perMission.sublist(band.$2, band.$3);
        double av(int i) => sl.map((x) => x[i]).reduce((a, b) => a + b) / sl.length;
        final pri = av(2), cri = av(1), esq = av(0);
        final epic = r.prismToEpic / pri;
        // Techo con conversión: todo lo bajo pasa a Prisma (menos una
        // reserva de 10 Esquirlas y 2 Cristales por misión para usar).
        var conv = '';
        if (r.conv.isNotEmpty) {
          final cn = r.conv[_c]!.$1, pn = r.conv[_p]!.$1;
          final eff = pri +
              math.max(0, esq - 10) / (cn * pn) +
              math.max(0, cri - 2) / pn;
          conv = ' | con conversión ≈ ${_f(r.prismToEpic / eff)} misiones';
        }
        print('  ${band.$1}: por misión esq ${_f(esq)} cri ${_f(cri)} pri ${_f(pri)} '
            '→ Épico (${r.prismToEpic} pri) ≈ ${_f(epic)} misiones; '
            'leg/misión ${_f(av(3))} (≈ ${_f(1 / math.max(1e-6, av(3)))} misiones)'
            '; Épicos que caen/misión ${_f(av(4))}$conv');
      }
      // Endgame: zona 10 a nivel 50 como Eco, con cantidad de mods y tier.
      final last = ms.last;
      for (final (label, mods, tier) in [
        ('Eco T1 común (0 mods)', 0.0, 1),
        ('Eco T1 raro (~2.5 mods)', 0.16, 1),
        ('Eco T8 raro', 0.16, 8),
        ('Eco T16 legendario (~4.5 mods)', 0.29, 16),
      ]) {
        final q = mods + r.tierQuantity * (tier - 1);
        final (t, sv) = _mission(r, last, zone: 50, q: q, runs: 300);
        final pri = t.m[_p]! + sv[_p]!;
        print('  $label q=+${(q * 100).round()}%: esq ${_f(t.m[_e]! + sv[_e]!)} '
            'cri ${_f(t.m[_c]! + sv[_c]!)} pri ${_f(pri)} leg ${_f(t.w[Rarity.legendario]!)} '
            '→ Épico ≈ ${_f(r.prismToEpic / pri)} Ecos, '
            'Legendario ≈ ${_f(1 / math.max(1e-6, t.w[Rarity.legendario]!))} Ecos');
      }
      // Conversión: cuántos prismas extra salen de lo que sobra.
      if (r.conv.isNotEmpty) {
        final (cn, cc) = r.conv[_c]!;
        final (pn, pc) = r.conv[_p]!;
        print('  conversión: $cn esq + ₵$cc → 1 cri; $pn cri + ₵$pc → 1 pri '
            '(1 pri = ${cn * pn} esq + ₵${cc * pn + pc})');
      }
    }
  });
}
