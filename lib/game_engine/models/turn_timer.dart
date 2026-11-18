/// "Tiempo de turno" (accesibilidad, docs/specs/accessibility.md § 7 y
/// docs/specs/settings.md § 4): cuánto espera el host a que el jugador de
/// turno elija antes de pasarlo (`timeout`). Jugando solo vale el ajuste
/// local; en co-op, el del anfitrión (lo fija en la sala y viaja en el
/// snapshot como `tt`).
enum TurnTimer {
  /// 30 s (`TURN_LIMIT` del prototipo).
  normal(30),

  /// El doble: 60 s.
  long(60),

  /// Sin límite: el turno espera hasta que el jugador elija.
  unlimited(null);

  const TurnTimer(this.seconds);

  /// Segundos del turno; `null` = sin límite.
  final double? seconds;

  /// Texto corto para la UI (`Turnos: sin límite`).
  String get label => switch (this) {
        TurnTimer.normal => 'normales (30 s)',
        TurnTimer.long => 'largos (60 s)',
        TurnTimer.unlimited => 'sin límite',
      };

  static TurnTimer fromName(Object? v, [TurnTimer def = TurnTimer.normal]) =>
      values.firstWhere((m) => m.name == v, orElse: () => def);
}
