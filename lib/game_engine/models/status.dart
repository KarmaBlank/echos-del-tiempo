/// Estados alterados del prototipo (`STATUS`). Ver docs/specs/combat.md
/// § "Estados alterados".
enum StatusKind {
  burn('Quemadura', 1000000000),
  poison('Veneno', 1000000000),
  freeze('Congelación', 5),
  stun('Aturdido', 1),
  holy('Sagrado', 9),
  regen('Regeneración', 3),

  // ---- v0.7 (docs/specs/elemental_reactions.md) ----

  /// Agua: no hace daño; dura `ElementStatusDef.turns` turnos propios
  /// (2). Lo detonan Electro (Electrocución) y Hielo (Congelación
  /// súbita).
  wet('Mojado', 2),

  /// Electro: no hace daño; dura 1 turno propio. Lo detona Agua
  /// (Cortocircuito).
  charged('Cargado', 1);

  const StatusKind(this.label, this.maxStacks);

  final String label;
  final int maxStacks;

  /// Mojado / Cargado: su valor son turnos que quedan (no se acumulan,
  /// se renuevan) y no hacen daño.
  bool get timed => this == wet || this == charged;

  /// Id del ícono del estado (contrato § 8: `status_wet`...).
  String get iconId => 'status_$name';
}

/// "Aplicá N stacks de X", opcionalmente con probabilidad (`stc` en el
/// prototipo).
class StatusApplication {
  final StatusKind kind;
  final int stacks;
  final double? chance;

  const StatusApplication(this.kind, this.stacks, {this.chance});
}
