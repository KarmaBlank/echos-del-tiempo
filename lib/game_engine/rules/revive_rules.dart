import 'dart:math' as math;

import '../data/tuning_catalog.dart';
import '../models/attributes.dart';
import '../models/battle_state.dart';

/// Sinergia de las habilidades que reviven con el árbol de pasivas
/// (docs/specs/combat.md § Revivir). Puro; los números salen de
/// `kTuning['consumables']` (Editor → Balance → Apoyo).
///
/// - Vida al revivir: `revive + ESP × espPer + Curación × healScale`,
///   con tope en 100%.
/// - Velo del Retorno: escudo al revivido de `Curación × shieldScale`
///   de su vida máx. (tope `shieldCap`) por `shieldTurns` turnos. Sin
///   Curación (árbol o arma) no hay escudo.
abstract final class ReviveRules {
  static TuningDef get _t => tuning(TuningId.consumables);

  static double get espPer => _t.d('espPer');
  static double get healScale => _t.d('healScale');
  static double get shieldScale => _t.d('shieldScale');
  static double get shieldCap => _t.d('shieldCap');
  static int get shieldTurns => _t.i('shieldTurns');

  /// ESP del lanzador (0 sin build: enemigos e invocaciones).
  static int espOf(Combatant c) => c.build?.attributes[Attribute.esp] ?? 0;

  /// Fracción de la vida máx. con la que revive (base [revive]).
  static double lifeFraction(double revive,
          {required int esp, required double healBonus}) =>
      math.min(
          1.0, revive + esp * espPer + math.max(0.0, healBonus) * healScale);

  /// Fracción de la vida máx. del revivido que absorbe el escudo.
  static double shieldFraction(double healBonus) =>
      math.min(shieldCap, math.max(0.0, healBonus) * shieldScale);

  /// [lifeFraction] para el lanzador [caster].
  static double lifeFor(Combatant caster, double revive) =>
      lifeFraction(revive, esp: espOf(caster), healBonus: caster.healBonus);
}
