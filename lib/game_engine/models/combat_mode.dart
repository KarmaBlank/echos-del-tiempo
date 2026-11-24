import '../data/tuning_catalog.dart';
import 'battle_state.dart';

/// Modo de combate de la sala del RPG (docs/specs/turn_modes.md § 1). Lo
/// elige el anfitrión; rige desde la próxima pelea.
enum CombatMode {
  timeline(TurnRule.velocidad, 'Línea de tiempo',
      'En prueba: el más rápido juega más seguido; más táctico pero menos '
          'parejo en cooperativo.'),
  rounds(TurnRule.porRonda, 'Por rondas (recomendado)',
      'Todos actúan una vez por ronda; la velocidad decide quién va primero.'),
  phases(TurnRule.porFases, 'Por fases',
      'En prueba: todos los enemigos y después todos ustedes; más simple, '
          'la velocidad pesa menos.');

  const CombatMode(this.turnRule, this.label, this.tip);

  final TurnRule turnRule;
  final String label;

  /// Ayuda de una línea (tooltip de la sala).
  final String tip;

  static CombatMode? fromName(Object? v) {
    for (final m in values) {
      if (m.name == v) return m;
    }
    return null;
  }

  /// El de por defecto (Balance → Límites de combate, `modeCoop` /
  /// `modeSolo`).
  static CombatMode defaultFor({required bool coop}) {
    final i = tuning(TuningId.combatLimits).i(coop ? 'modeCoop' : 'modeSolo');
    return values[i.clamp(0, values.length - 1)];
  }

  /// Pausa de planificación de Por fases, en segundos.
  static double get planPause =>
      tuning(TuningId.combatLimits).d('planPause');
}
