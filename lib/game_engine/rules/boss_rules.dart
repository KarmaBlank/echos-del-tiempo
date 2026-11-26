// Zone boss rules (docs/specs/bosses.md § v0.50): co-op scaling, the
// optional Eco re-fight and the boss material. Pure Dart; every number
// lives in `kTuning[TuningId.bosses]`.

import 'dart:math' as math;

import '../data/tuning_catalog.dart';
import '../data/zone_bosses_catalog.dart';
import '../models/battle_state.dart';
import '../models/item.dart';
import 'js_math.dart';

abstract final class BossRules {
  static TuningDef get t => tuning(TuningId.bosses);

  /// [enemyId] is a phased zone boss.
  static bool phased(String? enemyId) => zoneBossOf(enemyId) != null;

  /// Index (0-based) of the phase a boss at [hpFrac] of its life is in.
  static int phaseAt(String enemyId, double hpFrac) {
    final d = zoneBossOf(enemyId);
    if (d == null) return 0;
    var i = 0;
    for (var k = 1; k < d.phases.length; k++) {
      if (hpFrac <= d.phases[k].gate) i = k;
    }
    return i;
  }

  /// Extra life and break of a phased boss for [players] (on top of the
  /// group scaling every battle has).
  static double partyHp(int players) =>
      1 + t.d('partyHpPer') * math.max(0, players - 1);

  /// Scales the boss of [state] (its first enemy): party size for phased
  /// bosses and the Eco tier for any zone boss.
  static void applyBattle(BattleState state,
      {required int players, bool eco = false}) {
    final boss = state.enemies.firstOrNull;
    if (boss == null || !boss.boss) return;
    // Mundo's zone fight turns the phases on (bosses.md § v0.50).
    if (phased(boss.enemyType)) boss.phase = 1;
    var hp = phased(boss.enemyType) ? partyHp(players) : 1.0;
    var atk = 1.0;
    if (eco) {
      hp *= t.d('ecoHp');
      atk *= t.d('ecoAtk');
    }
    if (hp != 1) {
      boss
        ..maxHp = math.max(1, jsRound(boss.maxHp * hp))
        ..hp = boss.maxHp
        ..breakBase =
            boss.hasBreak ? math.max(1.0, boss.breakBase * hp) : boss.breakBase;
    }
    if (atk != 1) boss.attack = math.max(1, jsRound(boss.attack * atk));
  }

  /// Cost of the Eco offering: the normal one × `ecoCostMult`.
  static Map<CraftMaterial, int> ecoCost(Map<CraftMaterial, int> normal) => {
        for (final e in normal.entries)
          e.key: math.max(1, (e.value * t.d('ecoCostMult')).ceil()),
      };

  /// Boss material of [enemyId] and how many each player gets.
  static (String, int)? material(String? enemyId, {bool eco = false}) {
    final id = kBossMaterials[enemyId];
    if (id == null) return null;
    final n = t.i(eco ? 'ecoMat' : 'bossMat');
    return n <= 0 ? null : (id, n);
  }

  /// Extra boss loot rolls of the Eco tier.
  static int extraRolls({bool eco = false}) =>
      eco ? math.max(0, t.i('ecoLootRolls')) : 0;

  /// Legendary chance with the Eco bonus.
  static double legendaryChance(double base, {bool eco = false}) =>
      eco ? base + t.d('ecoLegendBonus') : base;
}
