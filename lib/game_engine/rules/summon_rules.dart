import 'dart:math' as math;

import '../data/affixes_catalog.dart';
import '../data/summoner_catalog.dart';
import '../models/item.dart';
import '../models/player_state.dart';
import 'js_math.dart';

/// Stats de una invocación al aparecer (docs/specs/summoner.md § 2).
class SummonStats {
  const SummonStats({
    required this.hp,
    required this.attack,
    required this.speed,
    required this.crit,
    required this.turns,
    required this.scale,
  });
  final int hp;

  /// Daño base de sus golpes (el motor lo trata como su ATQ).
  final int attack;
  final double speed;
  final double crit;

  /// Turnos propios que dura ([kSummonForever] = hasta caer).
  final int turns;

  /// Multiplicador total de stats (rareza, forja, árbol, Legión).
  final double scale;
}

/// Duración "para siempre" (keystone Pacto Eterno).
const kSummonForever = 99;

/// Escalado y progresión de las invocaciones. Dart puro: lo usan el
/// motor (al invocar) y la UI (tooltips, Grimorio).
class SummonRules {
  const SummonRules._();

  /// Suma de las mecánicas del cluster Invocador de tipo [m] en [ids]
  /// (mecánicas + keystones del invocador).
  static double mod(Iterable<String> ids, SummonMod m) {
    var t = 0.0;
    for (final id in ids.toSet()) {
      if (kSummonerModOf[id] == m) t += kSummonerModValue[id] ?? 0;
    }
    return t;
  }

  static bool has(Iterable<String> ids, SummonMod m) => mod(ids, m) > 0;

  /// Puntos de [stat] del arma de [b]: implícito de la base + afijos.
  static int affix(PlayerBuild? b, ModStat stat) {
    if (b == null) return 0;
    var t = 0;
    for (final m in b.equippedWeapon.implicit) {
      if (m.stat == stat) t += m.value;
    }
    for (final a in b.item?.affixes ?? const <AffixRoll>[]) {
      if (kAffixes[a.affixId]?.stat == stat) t += a.value;
    }
    return t;
  }

  /// Máximo de invocaciones activas.
  static int maxActive(Iterable<String> ids) =>
      has(ids, SummonMod.legion) ? kSummonMaxLegion : kSummonMax;

  /// Bono de stats del tomo: rareza + niveles de forja "Poder".
  static double gearBonus(PlayerBuild? b) {
    if (b == null) return 0;
    return (kSummonRarityBonus[b.item?.rarity ?? Rarity.comun] ?? 0) +
        b.forge.pow * kSummonForgePerPow;
  }

  /// Stats de [d] invocada por alguien con [magic], [maxHp], [speed],
  /// [crit] y [level], con el arma de [build] y las mecánicas [ids].
  static SummonStats stats(
    SummonDef d, {
    required int magic,
    required int maxHp,
    required double speed,
    required double crit,
    required int level,
    PlayerBuild? build,
    Iterable<String> ids = const [],
  }) {
    var scale = 1 + gearBonus(build) + mod(ids, SummonMod.stats);
    if (has(ids, SummonMod.legion)) scale *= 1 - kLegionPenalty;
    final elemental = d.role == SummonRole.elemental;
    final dmg = 1 +
        affix(build, ModStat.summonDamage) * ModStat.summonDamage.scale +
        (elemental ? mod(ids, SummonMod.elementalDamage) : 0);
    final hp = jsRound((magic * 1.5 + level * 6 + maxHp * 0.15) * d.hp * scale);
    final atk = jsRound(magic * d.atk * scale * dmg);
    final turns = has(ids, SummonMod.pact)
        ? kSummonForever
        : kSummonTurns +
            mod(ids, SummonMod.turns).round() +
            affix(build, ModStat.summonTurns);
    return SummonStats(
      hp: math.max(1, hp),
      attack: math.max(1, atk),
      speed: speed * d.speed,
      crit: 0.05 + crit * mod(ids, SummonMod.critInherit),
      turns: turns,
      scale: scale * dmg,
    );
  }

  /// Bono de daño por muertes (Festín Arcano): +10% por muerte, tope 50%.
  static double killBonus(Iterable<String> ids, int kills) =>
      math.min(0.5, kills * mod(ids, SummonMod.killGrowth));
}
