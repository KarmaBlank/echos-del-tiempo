import '../data/elements_catalog.dart';
import '../data/game_catalog.dart';
import '../models/battle_command.dart';
import '../models/battle_state.dart';
import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart';
import '../models/status.dart';
import 'skill_requirements.dart';

/// Elecciones de combo compartidas por la IA de compañeros
/// (solo_party.md § 4.1) y el simulador de balance (combo_balance.md
/// § 5.2): quebrar a un Fisurado, detonar una Convergencia preparada y
/// preparar sin detonar antes de tiempo. Determinística y Dart puro; solo
/// propone comandos que pasan [SkillRequirements] (MP, Pulso y
/// precondiciones), así el host no los rechaza.
class ComboPlanner {
  const ComboPlanner([this.catalog = GameCatalog.standard]);

  final GameCatalog catalog;

  /// Stacks desde los que conviene detonar una Convergencia.
  static const detonateAt = 5;

  static const _primers = [StatusKind.burn, StatusKind.poison];

  Iterable<SkillDef> _usable(Combatant me) sync* {
    for (final id in me.skillIds) {
      final sk = catalog.skills[id];
      if (sk != null) yield sk;
    }
  }

  bool _ok(SkillDef sk, Combatant me, Combatant t, List<Combatant> foes) =>
      SkillRequirements.missing(sk, me, t, foes: foes).isEmpty;

  /// Convergencia que detona un golpe de [sk] sobre [t] y sus stacks.
  (ReactionKind, int)? _convergence(SkillDef sk, Combatant t) {
    if (!sk.dealsDamage || kPrimeOnlySkills.contains(sk.id)) return null;
    final el = elementOf(sk.id);
    for (final st in _primers) {
      final rk = reactionOf(st, el);
      if (rk != null && rk.convergence && t.stacks(st) > 0) {
        return (rk, t.stacks(st));
      }
    }
    return null;
  }

  /// Una habilidad con Quebrar sobre un enemigo Fisurado.
  SkillCommand? quebrar(Combatant me, List<Combatant> foes) {
    for (final t in foes) {
      if (!t.alive || !t.fissured) continue;
      for (final sk in _usable(me)) {
        if (sk.breaks && _ok(sk, me, t, foes)) {
          return SkillCommand(sk.id, targetId: t.id);
        }
      }
    }
    return null;
  }

  /// Detona la Convergencia con más stacks (desde [detonateAt]).
  SkillCommand? detonate(Combatant me, List<Combatant> foes) {
    SkillCommand? best;
    var top = -1;
    for (final t in foes) {
      if (!t.alive) continue;
      for (final sk in _usable(me)) {
        if (sk.allTargets) continue;
        final c = _convergence(sk, t);
        if (c == null || c.$2 < detonateAt || !_ok(sk, me, t, foes)) continue;
        // Más stacks primero; entre iguales, la que pide la precondición
        // (el detonador de la clase, que pega más fuerte).
        final score = c.$2 * 2 + (sk.requires.isEmpty ? 0 : 1);
        if (score <= top) continue;
        top = score;
        best = SkillCommand(sk.id, targetId: t.id);
      }
    }
    return best;
  }

  /// Prepara: aplica Quemadura o Veneno donde ya hay más del mismo (sin
  /// detonar los stacks del otro) o, si no, pone Marca. Con
  /// [instantOnly], solo habilidades Instante (no gastan el turno).
  SkillCommand? prepare(Combatant me, List<Combatant> foes,
      {bool instantOnly = false}) {
    SkillCommand? mark;
    for (final sk in _usable(me)) {
      if (instantOnly && !sk.instant) continue;
      if (sk.allTargets || sk.breaks) continue;
      final adds = [if (sk.status != null) sk.status!, ...sk.extraStatuses]
          .where((a) => _primers.contains(a.kind) && a.chance == null)
          .map((a) => a.kind)
          .toSet();
      if (adds.isNotEmpty) {
        Combatant? pick;
        for (final t in foes) {
          if (!t.alive || _convergence(sk, t) != null) continue;
          if (!_ok(sk, me, t, foes)) continue;
          final n = adds.fold<int>(0, (a, k) => a + t.stacks(k));
          if (pick == null ||
              n > adds.fold<int>(0, (a, k) => a + pick!.stacks(k))) {
            pick = t;
          }
        }
        if (pick != null) return SkillCommand(sk.id, targetId: pick.id);
        continue;
      }
      if (mark == null &&
          sk.debuffs.any((d) => d.stat == BuffStat.damageTaken)) {
        for (final t in foes) {
          if (t.alive &&
              t.effectTotal(BuffStat.damageTaken) <= 0 &&
              _ok(sk, me, t, foes)) {
            mark = SkillCommand(sk.id, targetId: t.id);
            break;
          }
        }
      }
    }
    return mark;
  }
}
