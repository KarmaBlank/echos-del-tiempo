/// Estados alterados del prototipo (`STATUS`). Ver docs/specs/combat.md
/// § "Estados alterados".
enum StatusKind {
  burn('Quemadura', 1000000000),
  poison('Veneno', 1000000000),
  freeze('Congelación', 5),
  stun('Aturdido', 1),
  holy('Sagrado', 9),
  regen('Regeneración', 3);

  const StatusKind(this.label, this.maxStacks);

  final String label;
  final int maxStacks;
}

/// "Aplicá N stacks de X", opcionalmente con probabilidad (`stc` en el
/// prototipo).
class StatusApplication {
  final StatusKind kind;
  final int stacks;
  final double? chance;

  const StatusApplication(this.kind, this.stacks, {this.chance});
}
