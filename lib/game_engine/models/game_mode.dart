/// Qué versión del juego arma el composition root (docs/specs/roguelike.md
/// § 9). `features/*` y el motor nunca miran el nombre del flavor: miran
/// esto.
enum GameModeKind {
  /// Overworld libre, misiones, XP (el juego de siempre).
  mundo,

  /// Modo Travesía: run corta y descartable sobre un mapa ramificado.
  travesia,
}
