part of 'battle_engine.dart';

// Enemy Convergences (docs/specs/combo_balance.md § "Convergencias
// enemigas"): the enemy AI primes a player with Quemadura / Veneno and
// an enemy whose own hit carries the detonator element finishes it. The
// reaction itself is the same one players use (`_react`); here lives
// only the target choice. Enemies use only the elements they really
// have: a lone enemy combos only if its own kit covers both halves.
// Turn order is the active mode's: this runs only when the enemy acts.

extension _EnemyCombo on _Turn {
  /// Living, acting enemies.
  List<Combatant> get _actingFoes =>
      [for (final c in state.enemies) if (c.alive && !_passive(c)) c];

  /// The player [e] goes for to prime or detonate a Convergence, or
  /// `null` (random target as always). [el]: the element of the hit;
  /// [inf]: the status it leaves.
  Combatant? _comboPick(Combatant e, List<Combatant> alive, GameElement el,
      StatusApplication? inf) {
    if (!EnemyComboTuning.on || alive.isEmpty) return null;
    final foes = _actingFoes;
    final lone = foes.length == 1;
    final d = engine.catalog.enemies[e.enemyType];
    if (lone && !enemySoloConvergence(e, d)) return null;
    final chance = lone ? EnemyComboTuning.soloChance : EnemyComboTuning.focus;
    final min =
        lone ? EnemyComboTuning.soloMinStacks : EnemyComboTuning.minStacks;
    // Detonate: someone carries enough of what this hit detonates.
    final ready = _mostPrimed(alive, el, min);
    if (ready != null) return _rand() < chance ? ready : null;
    // Prime: stack the player already primed, if someone (itself when
    // alone) really has the element that detonates it.
    final st = inf?.kind;
    final det = st == null ? null : convergenceDetonator(st);
    if (st == null || det == null) return null;
    final partner = foes.any((c) =>
        (lone || c != e) &&
        enemyKitElements(c, engine.catalog.enemies[c.enemyType])
            .contains(det));
    if (!partner) return null;
    Combatant? best;
    for (final p in alive) {
      if (p.stacks(st) > 0 &&
          (best == null || p.stacks(st) > best.stacks(st))) {
        best = p;
      }
    }
    if (best == null) return null;
    return _rand() < chance ? best : null;
  }

  /// The living player with the most primer stacks (≥ [min]) that an [el]
  /// hit turns into a Convergence, or `null`.
  Combatant? _mostPrimed(List<Combatant> alive, GameElement el, int min) {
    Combatant? best;
    var most = 0;
    for (final p in alive) {
      final r = convergenceFor(p, el);
      if (r == null) continue;
      final n = p.stacks(r.primer);
      if (n >= min && n > most) {
        best = p;
        most = n;
      }
    }
    return best;
  }
}
