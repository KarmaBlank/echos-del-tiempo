import '../models/battle_state.dart';
import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart';

/// Precondiciones, Pulso y MP de una habilidad (combo_balance.md § 5.2).
/// La misma regla la usan el host (valida el comando), la UI (botón
/// desactivado con "Necesita: …") y la IA de compañeros.
class SkillRequirements {
  const SkillRequirements._();

  /// Si [req] se cumple para [user] contra [target]. En las habilidades a
  /// todos, una precondición del objetivo vale si la cumple algún enemigo
  /// de [foes].
  static bool met(SkillReq req, SkillDef sk, Combatant user,
      Combatant? target, Iterable<Combatant> foes) {
    if (!req.onTarget) return _check(req, user, null);
    if (sk.allTargets) return foes.any((f) => f.alive && _check(req, user, f));
    return target != null && _check(req, user, target);
  }

  static bool _check(SkillReq req, Combatant user, Combatant? t) =>
      switch (req.kind) {
        SkillReqKind.targetStacks => t!.stacks(req.status!) >= req.amount,
        SkillReqKind.targetFissured => t!.fissured,
        SkillReqKind.targetMarked => t!.effectTotal(BuffStat.damageTaken) > 0,
        SkillReqKind.selfHpBelow =>
          user.maxHp > 0 && user.hp / user.maxHp < req.fraction,
      };

  /// Lo que le falta a [user] para usar [sk] contra [target] (vacío =
  /// puede): MP, Pulso y cada precondición que no se cumple.
  static List<String> missing(SkillDef sk, Combatant user, Combatant? target,
      {Iterable<Combatant> foes = const []}) {
    return [
      if (user.mp < sk.mp) '${sk.mp} MP',
      if (user.pulse < sk.pulse) 'Pulso ${sk.pulse}',
      for (final r in sk.requires)
        if (!met(r, sk, user, target, foes)) r.label,
    ];
  }

  /// Tooltip del botón desactivado: "Necesita: objetivo Fisurado · Pulso 2".
  /// Una línea por condición que falta, para el detalle del menú:
  /// `Falta: 3 MP (tenés 1)`, `Falta: Pulso 2 (tenés 1)`,
  /// `Necesita: objetivo Fisurado`. Vacío = se puede usar.
  static List<String> missingLines(SkillDef sk, Combatant user,
          Combatant? target,
          {Iterable<Combatant> foes = const []}) =>
      [
        if (user.mp < sk.mp) 'Falta: ${sk.mp} MP (tenés ${user.mp})',
        if (user.pulse < sk.pulse)
          'Falta: Pulso ${sk.pulse} (tenés ${user.pulse})',
        for (final r in sk.requires)
          if (!met(r, sk, user, target, foes)) 'Necesita: ${r.label}',
      ];

  static String? needsText(List<String> missing) =>
      missing.isEmpty ? null : 'Necesita: ${missing.join(' · ')}';
}
