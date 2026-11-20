import '../models/battle_event.dart';

/// Duración de cada cinemática (ms) por id de animación, tomada de los
/// datos FXA del release (docs/specs/game_editor.md § 4.3). La usa el
/// host para la espera de fin de batalla (`battleCinematicHold`).
///
/// Claves: el `SkillDef.id` de la ULT (`ult_espada`), el `EnemyUltDef.id`
/// (`eult_diluvio`), `duo_<clave del dúo>` o `duo` (genérico).
///
/// Sin datos (tests del motor, flavors que no cargaron fx) se usan los
/// valores históricos: ULT 2.3 s, dúo 1.5 s.
class CinematicDurations {
  const CinematicDurations([this.ms = const {}]);

  final Map<String, int> ms;

  static const legacyUltMs = 2300;
  static const legacyDuoMs = 1500;

  /// La tabla que usa el motor si no le inyectan otra. La pone quien
  /// carga el catálogo de fx (con la duración del asset, nunca la de un
  /// override local: el estado compartido no depende del arte local).
  static CinematicDurations shared = const CinematicDurations();

  int ultMs(String? id) => ms[id] ?? legacyUltMs;
  int duoMs(String? key) => ms['duo_$key'] ?? ms['duo'] ?? legacyDuoMs;

  /// Segundos de cinemática de [ev] (0 si no tiene).
  double holdFor(BattleEvent ev) => switch (ev) {
        ActionEvent(kind: BattleActionKind.ultimate, :final skillId) =>
          ultMs(skillId) / 1000,
        EnemyUltEvent(:final ultId) => ultMs(ultId) / 1000,
        ActionEvent(kind: BattleActionKind.dual, :final skillId) =>
          duoMs(skillId) / 1000,
        _ => 0,
      };
}
