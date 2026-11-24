// Enemy Convergences (docs/specs/combo_balance.md § "Convergencias
// enemigas"): what enemies need to know to prime and detonate a
// Convergence on a player, and what the HUD needs to warn about it.
// Pure Dart: the battle engine uses it for the enemy AI and the combat
// HUD for the "ready Convergence" warning.

import '../data/elements_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/battle_state.dart';
import '../models/enemy_def.dart';
import '../models/status.dart';

/// Tuning of enemy Convergences (group `combatLimits`, editable in
/// Balance).
abstract final class EnemyComboTuning {
  static TuningDef get _t => tuning(TuningId.combatLimits);

  /// Enemy Convergence AI on.
  static bool get on => _t.i('eConvOn') == 1;

  /// Cap of a Convergence against a player (fraction of its max HP).
  static double get playerCap => _t.d('eConvCapPlayer');

  /// Group: chance a primer / detonator focuses the primed player.
  static double get focus => _t.d('eComboFocus');

  /// Group: primer stacks the detonator waits for.
  static int get minStacks => _t.i('eComboMinStacks');

  /// Lone enemy (only if its own kit has both elements): chance per hit
  /// to go for its primed player.
  static double get soloChance => _t.d('eSoloChance');

  /// Lone enemy: primer stacks it waits for before detonating.
  static int get soloMinStacks => _t.i('eSoloMinStacks');
}

/// The element that detonates a Convergence primed with [primer]
/// (Veneno → Fuego, Quemadura → Veneno), or `null`.
GameElement? convergenceDetonator(StatusKind primer) {
  for (final r in kReactionTable) {
    if (r.kind.convergence && r.primer == primer) return r.detonator;
  }
  return null;
}

/// The Convergence an [el] hit detonates on [t], or `null`.
ReactionRule? convergenceFor(Combatant t, GameElement el) {
  for (final r in kReactionTable) {
    if (r.kind.convergence && r.detonator == el && t.stacks(r.primer) > 0) {
      return r;
    }
  }
  return null;
}

/// The status [e]'s next normal hit leaves (its cycle, if it has one).
StatusApplication? enemyNextInflict(Combatant e, EnemyDef? d) {
  final cyc = d?.inflictCycle ?? const <StatusApplication>[];
  if (cyc.isEmpty) return e.inflicts;
  return cyc[e.actions % cyc.length];
}

/// The element of [e]'s next normal hit.
GameElement enemyNextElement(Combatant e, EnemyDef? d) =>
    enemyAttackElement(d, enemyNextInflict(e, d));

/// Every element [e]'s normal hits really carry (its own element, its
/// status and its status cycle). Nothing is ever added for a combo.
Set<GameElement> enemyKitElements(Combatant e, EnemyDef? d) => {
      for (final inf in [
        e.inflicts,
        ...?d?.inflictCycle,
      ])
        enemyAttackElement(d, inf),
      if (d?.inflictCycle.isEmpty ?? true) enemyAttackElement(d, e.inflicts),
    };

/// [e] alone can both prime and detonate some Convergence with its own
/// kit (e.g. a Quemadura / Veneno cycle).
bool enemySoloConvergence(Combatant e, EnemyDef? d) {
  final kit = enemyKitElements(e, d);
  final primers = {
    for (final inf in [e.inflicts, ...?d?.inflictCycle])
      if (inf != null) inf.kind,
  };
  return primers.any((st) => kit.contains(convergenceDetonator(st)));
}

/// A Convergence that an enemy can detonate on a player with its next
/// normal hit.
class ConvergenceThreat {
  const ConvergenceThreat(
      this.playerId, this.enemyId, this.kind, this.stacks);

  final String playerId;
  final String enemyId;
  final ReactionKind kind;

  /// Primer stacks on the player right now.
  final int stacks;
}

/// Every ready Convergence against the party of [s] (HUD warning): a
/// living, acting enemy whose next normal hit detonates a primer the
/// player carries. [enemies]: the enemy catalog.
List<ConvergenceThreat> convergenceThreats(
    BattleState s, Map<String, EnemyDef> enemies) {
  if (!EnemyComboTuning.on) return const [];
  final out = <ConvergenceThreat>[];
  for (final p in s.party) {
    if (!p.alive) continue;
    for (final e in s.enemies) {
      if (!e.alive || e.isPlayer) continue;
      final d = enemies[e.enemyType];
      if (d?.passive ?? false) continue;
      final r = convergenceFor(p, enemyNextElement(e, d));
      if (r != null) {
        out.add(ConvergenceThreat(p.id, e.id, r.kind, p.stacks(r.primer)));
      }
    }
  }
  return out;
}
