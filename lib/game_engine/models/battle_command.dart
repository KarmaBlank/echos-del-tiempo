/// Lo que un jugador puede hacer en su turno (`d.a` en `battleCmd`).
/// `targetId` es el id de un enemigo; si es `null` o ya cayó, se usa el
/// primer enemigo vivo.
sealed class BattleCommand {
  const BattleCommand();
}

class AttackCommand extends BattleCommand {
  final String? targetId;
  const AttackCommand({this.targetId});
}

class SkillCommand extends BattleCommand {
  final String skillId;
  final String? targetId;
  const SkillCommand(this.skillId, {this.targetId});
}

class UltimateCommand extends BattleCommand {
  final String? targetId;
  const UltimateCommand({this.targetId});
}

class DualCommand extends BattleCommand {
  final String partnerId;
  const DualCommand(this.partnerId);
}

enum BattleItem { potion, ether }

class ItemCommand extends BattleCommand {
  final BattleItem item;

  /// Id del aliado; `null` = el que más lo necesita.
  final String? targetPlayerId;
  const ItemCommand(this.item, {this.targetPlayerId});
}

class DefendCommand extends BattleCommand {
  const DefendCommand();
}

/// Pasar turno (v0.8.3, docs/specs/combat.md § "Pasar turno"): termina
/// el turno sin actuar; el próximo llega en IV × 0.5. Sin carga de ULT ni
/// defensa. En la red viaja como `def` + `ps: true` (un host v0.8.2 lo
/// lee como Defender).
class PassCommand extends BattleCommand {
  const PassCommand();
}
