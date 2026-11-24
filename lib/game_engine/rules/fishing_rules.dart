import 'dart:math' as math;

import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/item.dart' show CraftMaterial;
import '../models/player_profile.dart';
import 'life_tree_rules.dart';

/// Un pez sacado (o por sacar): especie, tamaño y rareza.
class FishCatch {
  const FishCatch(this.species, this.sizeCm);
  final String species;
  final int sizeCm;
  FishDef get def => kFish[species]!;
  FishRarity get rarity => def.rarity;

  @override
  bool operator ==(Object other) =>
      other is FishCatch && other.species == species && other.sizeCm == sizeCm;
  @override
  int get hashCode => Object.hash(species, sizeCm);
}

/// Qué sale del agua en una captura (fishing.md § 8).
enum WaterLootKind { fish, basura, materiales, cofre, arma }

/// Resultado de vender en el agropecuario.
typedef FishSale = ({PlayerProfile profile, int credits, int esquirlas, int sold});

/// Reglas de Pesca y del agropecuario (docs/specs/fishing.md). Puras: los
/// números salen de `kTuning[TuningId.fishing]` (Editor → Balance → Pesca).
abstract final class FishingRules {
  static TuningDef get t => tuning(TuningId.fishing);

  // ---------------- nivel ----------------

  static int get maxLevel => t.i('maxLevel');

  /// XP para pasar del nivel [l] al siguiente.
  static int xpNeed(int l) =>
      math.max(1, (t.d('xpBase') * math.pow(l, t.d('xpExp'))).round());

  /// Nivel de Pesca con [xp] total.
  static int levelFor(int xp) {
    var l = 1, rest = xp;
    while (l < maxLevel && rest >= xpNeed(l)) {
      rest -= xpNeed(l);
      l++;
    }
    return l;
  }

  static int level(PlayerProfile p) => levelFor(p.life.fishXp);

  /// XP dentro del nivel actual y la que falta (para la barra).
  static (int, int) progress(int xp) {
    var l = 1, rest = xp;
    while (l < maxLevel && rest >= xpNeed(l)) {
      rest -= xpNeed(l);
      l++;
    }
    return l >= maxLevel ? (0, 0) : (rest, xpNeed(l));
  }

  // ---------------- cañas ----------------

  /// `ratio = clamp(nivel / requerido, 0, 1)`;
  /// `efectividad = piso + (1 − piso) × ratio^curva` (town_loop.md § 11c).
  static double effectiveness(int level, int reqLevel) {
    final ratio = (level / math.max(1, reqLevel)).clamp(0.0, 1.0);
    final floor = t.d('bonusFloor').clamp(0.0, 1.0);
    return floor + (1 - floor) * math.pow(ratio, t.d('bonusCurve'));
  }

  /// Bonus efectivos de la caña equipada de [p].
  static ({double bite, double zone, double rare}) rodBonus(PlayerProfile p) {
    final r = kRods[p.life.rod] ?? kRods[kStarterRod]!;
    final k = effectiveness(level(p), r.reqLevel);
    // Árbol de Pesca (life_skill_trees.md § 2).
    return (
      bite: r.biteSpeed * k + LifeTreeRules.fish(p, LifeFx.bite),
      zone: r.zoneBonus * k + LifeTreeRules.fish(p, LifeFx.zone),
      rare: r.rareBonus * k + LifeTreeRules.fish(p, LifeFx.legend),
    );
  }

  // ---------------- tiradas ----------------

  /// Rareza: pesos del Balance; los no comunes × (1 + [rareBonus]).
  /// [auto] / [noLegend]: nunca legendario (ni pity). [pity] alcanzado:
  /// legendario seguro. [epicMult]: × peso del épico (auto-pesca, § 6).
  static FishRarity rollRarity(double roll,
      {double rareBonus = 0,
      bool auto = false,
      bool noLegend = false,
      double epicMult = 1,
      int pity = 0}) {
    final noLeg = auto || noLegend;
    final after = t.i('pityAfter');
    if (!noLeg && after > 0 && pity >= after) return FishRarity.legendario;
    final w = {
      for (final r in FishRarity.values)
        r: r == FishRarity.legendario && noLeg
            ? 0.0
            : t.d('weight${r.key}') *
                (r == FishRarity.comun ? 1 : 1 + math.max(0, rareBonus)) *
                (r == FishRarity.epico ? math.max(0.0, epicMult) : 1),
    };
    final total = w.values.fold(0.0, (a, b) => a + b);
    var x = roll.clamp(0.0, 0.999999) * total;
    for (final r in FishRarity.values) {
      if (x < w[r]!) return r;
      x -= w[r]!;
    }
    return FishRarity.comun;
  }

  /// El pez completo (rareza, especie del lago y tamaño). Si el lago no
  /// tiene especies de esa rareza baja a la de abajo.
  static FishCatch roll(double Function() rand, List<String> lake,
      {double rareBonus = 0,
      bool auto = false,
      bool noLegend = false,
      double epicMult = 1,
      int pity = 0}) {
    var r = rollRarity(rand(),
        rareBonus: rareBonus,
        auto: auto,
        noLegend: noLegend,
        epicMult: epicMult,
        pity: pity);
    final pool = [for (final id in lake) if (kFish[id] != null) kFish[id]!];
    if (pool.isEmpty) return const FishCatch('mojarra_claro', 10);
    while (true) {
      final of = [for (final f in pool) if (f.rarity == r) f];
      if (of.isNotEmpty) {
        final f = of[(rand() * of.length).floor().clamp(0, of.length - 1)];
        // Tamaño: auto-pesca saca los chicos (mitad baja del rango).
        final span = f.maxCm - f.minCm;
        final u = rand() * (auto ? 0.5 : 1);
        return FishCatch(f.id, f.minCm + (u * span).round());
      }
      if (r == FishRarity.comun) return FishCatch(pool.first.id, pool.first.minCm);
      r = FishRarity.values[r.index - 1];
    }
  }

  // ---------------- botín del agua (§ 8) ----------------

  /// Qué sale esta vez: un pez casi siempre; a veces basura, materiales,
  /// un cofre hundido o (poco) un arma. El nivel de Pesca y [luck] (la
  /// rareza de la caña) mejoran la chance y los tipos buenos. Pity: tras
  /// `lootPityAfter` capturas sin cofre ni arma, cofre (o arma) seguro.
  static WaterLootKind rollLoot(double Function() rand, PlayerProfile p,
      {double luck = 0}) {
    final after = t.i('lootPityAfter');
    if (after > 0 && p.life.dry >= after) {
      return rand() < 0.8 ? WaterLootKind.cofre : WaterLootKind.arma;
    }
    final lv = t.d('lootLevelBonus') * (level(p) - 1);
    final good = 1 + lv + math.max(0, luck);
    final tree = 1 + LifeTreeRules.fish(p, LifeFx.loot);
    if (rand() >= t.d('lootChance') * (1 + lv) * tree) return WaterLootKind.fish;
    final w = {
      WaterLootKind.basura: t.d('lootBasura'),
      WaterLootKind.materiales: t.d('lootMateriales') * good,
      WaterLootKind.cofre: t.d('lootCofre') * good,
      WaterLootKind.arma: t.d('lootArma') * good,
    };
    final total = w.values.fold(0.0, (a, b) => a + b);
    var x = rand().clamp(0.0, 0.999999) * total;
    for (final e in w.entries) {
      if (x < e.value) return e.key;
      x -= e.value;
    }
    return WaterLootKind.basura;
  }

  /// Puede sacar uno de los legendarios del agua (nivel y caña mínimos).
  static bool legendEligible(PlayerProfile p) =>
      level(p) >= t.i('lootLegendLevel') &&
      (kRods[p.life.rod]?.rarity.index ?? 0) >= t.i('lootLegendRod');

  /// Anota la captura en el pity del botín: cofre o arma lo reinician.
  static PlayerProfile markDry(PlayerProfile p, WaterLootKind k) =>
      p.copyWith(
          life: p.life.copyWith(
              dry: k == WaterLootKind.cofre || k == WaterLootKind.arma
                  ? 0
                  : p.life.dry + 1));

  /// Segundos de espera hasta la picada real con el bonus de la caña.
  static double biteDelay(double roll, double biteBonus) {
    final lo = t.d('biteMinSec'), hi = math.max(lo, t.d('biteMaxSec'));
    return (lo + (hi - lo) * roll) * (1 - biteBonus.clamp(0.0, 0.8));
  }

  // ---------------- XP ----------------

  /// XP de Pesca: base × rareza × tamaño relativo (× auto).
  static int fishXp(FishCatch c, {bool auto = false}) {
    final d = c.def;
    final size = (c.sizeCm / d.avgCm).clamp(0.5, 1.6);
    return math.max(1,
        (d.xp * t.d('xp${d.rarity.key}') * size * (auto ? t.d('autoMult') : 1))
            .round());
  }

  /// XP de personaje por la captura (antes del tope de la estadía).
  static int charXp(FishCatch c, {bool auto = false}) =>
      (t.d('charXp${c.rarity.key}') * (auto ? t.d('autoMult') : 1)).round();

  /// Suma la captura a [p]: bolsa, XP de Pesca y pity. [keepPity]: no
  /// toca el pity (auto-pesca, § 6); [xpMult] × la XP de Pesca y
  /// [treeMult] × el bonus de XP del árbol.
  static PlayerProfile addCatch(PlayerProfile p, FishCatch c,
      {bool auto = false,
      bool keepPity = false,
      double xpMult = 1,
      double treeMult = 1}) {
    final l = p.life;
    return p.copyWith(
        life: l.addFish(c.species).copyWith(
            fishXp: l.fishXp +
                (fishXp(c, auto: auto) *
                        xpMult *
                        (1 + LifeTreeRules.fish(p, LifeFx.xp) * treeMult))
                    .round(),
            pity: auto || keepPity
                ? l.pity
                : c.rarity == FishRarity.legendario
                    ? 0
                    : l.pity + 1));
  }

  // ---------------- agropecuario ----------------

  /// Vende [n] de [species] (todos con `null`), o con `species == null`
  /// toda la bolsa menos los legendarios ("Vender todo"). En oro o en
  /// materiales (Esquirlas; lo que no llega a una se paga en oro).
  static FishSale? sell(PlayerProfile p,
      {String? species, int? n, bool materials = false}) {
    final bag = {...p.life.bag};
    var value = 0, sold = 0;
    void take(String id, int k) {
      final f = kFish[id];
      if (f == null || k <= 0) return;
      bag[id] = (bag[id] ?? 0) - k;
      value += f.price * k;
      sold += k;
    }

    if (species == null) {
      for (final e in p.life.bag.entries) {
        if (kFish[e.key]?.rarity != FishRarity.legendario) take(e.key, e.value);
      }
    } else {
      final have = p.life.count(species);
      final k = n ?? have;
      if (k <= 0 || k > have) return null;
      take(species, k);
    }
    if (sold == 0) return null;
    value = (value * (1 + LifeTreeRules.fish(p, LifeFx.sell))).round();
    var credits = value, esq = 0;
    if (materials) {
      final v = (value * t.d('matRate')).round();
      final per = math.max(1, t.i('matValue'));
      esq = v ~/ per;
      credits = v - esq * per;
    }
    final mats = {...p.materials};
    if (esq > 0) {
      mats[CraftMaterial.esquirla] = (mats[CraftMaterial.esquirla] ?? 0) + esq;
    }
    return (
      profile: p.copyWith(
          credits: p.credits + credits,
          materials: mats,
          life: p.life.copyWith(bag: bag)),
      credits: credits,
      esquirlas: esq,
      sold: sold,
    );
  }

  /// Canje de un legendario: Cristales de Era y Prismas Rotos.
  static PlayerProfile? exchangeLegendary(PlayerProfile p, String species) {
    if (kFish[species]?.rarity != FishRarity.legendario ||
        p.life.count(species) < 1) {
      return null;
    }
    final mats = {...p.materials};
    mats[CraftMaterial.cristal] =
        (mats[CraftMaterial.cristal] ?? 0) + t.i('legendCristales');
    mats[CraftMaterial.prisma] =
        (mats[CraftMaterial.prisma] ?? 0) + t.i('legendPrismas');
    return p.copyWith(
        materials: mats,
        life: p.life.copyWith(bag: {...p.life.bag, species: p.life.count(species) - 1}));
  }

  static PlayerProfile? buyRod(PlayerProfile p, String rodId) {
    final r = kRods[rodId];
    if (r == null || r.price <= 0 || p.life.rods.contains(rodId) ||
        p.credits < r.price) {
      return null;
    }
    return p.copyWith(
        credits: p.credits - r.price,
        life: p.life.copyWith(rods: [...p.life.rods, rodId]));
  }

  static PlayerProfile? equipRod(PlayerProfile p, String rodId) {
    if (!p.life.rods.contains(rodId) || p.life.rod == rodId) return null;
    return p.copyWith(life: p.life.copyWith(rod: rodId));
  }

  /// Plausibilidad (host): la caña equipada existe y el nivel está en rango.
  static bool plausible(PlayerProfile p) =>
      kRods.containsKey(p.life.rod) && p.life.rods.contains(p.life.rod);
}
