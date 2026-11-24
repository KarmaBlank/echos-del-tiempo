import 'dart:math' as math;

import '../models/battle_state.dart';

/// Who opens a battle started by field contact (docs/specs/combat.md
/// § "Encounter initiative").
enum EncounterKind {
  /// The player walked into the enemy: the party opens, the touching
  /// character first.
  firstStrike,

  /// The enemy reached a player who was standing still or walking away:
  /// the enemies open, the touching enemy first.
  ambush,
}

/// Pure rules of the encounter initiative (no Flutter, no network).
abstract final class EncounterRules {
  /// Minimum squared length (px²) of a field step for it to count: below
  /// 0.5 px it is the 0.1 px rounding of the sent position, not movement.
  static const minStep2 = 0.25;

  /// The encounter kind on contact. The player at ([px], [py]) last moved
  /// by ([mdx], [mdy]) ([moving] = still walking). FIRST STRIKE when the
  /// player is moving and that step points toward the enemy at
  /// ([ex], [ey]) as seen from where the step started (`p − step`; dot
  /// product > 0), so a step that lands right on the enemy still counts.
  /// Otherwise (still or moving away) it is an AMBUSH.
  static EncounterKind kind({
    required double px,
    required double py,
    required double ex,
    required double ey,
    required double mdx,
    required double mdy,
    required bool moving,
  }) {
    if (!moving || mdx * mdx + mdy * mdy < minStep2) {
      return EncounterKind.ambush;
    }
    final dot = mdx * (ex - (px - mdx)) + mdy * (ey - (py - mdy));
    return dot > 0 ? EncounterKind.firstStrike : EncounterKind.ambush;
  }

  /// Timeline mode: makes [openerId] the earliest `nextTurn` of [state]
  /// (half the earliest of everyone else). Idempotent; a no-op when the
  /// opener is missing or already first.
  static void applyTimelineOpener(BattleState state, String? openerId) {
    if (openerId == null || state.grouped) return;
    final all = [...state.party, ...state.enemies, ...state.summons];
    final opener = all.where((c) => c.id == openerId).firstOrNull;
    if (opener == null) return;
    var minOthers = double.infinity;
    for (final c in all) {
      if (c.id != openerId) minOthers = math.min(minOthers, c.nextTurn);
    }
    if (!minOthers.isFinite) return;
    var target = minOthers * 0.5;
    if (target >= minOthers) target = minOthers - 1e-3;
    opener.nextTurn = math.min(opener.nextTurn, target);
  }
}
