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

  /// Qué dúo (v0.8.3): la clave de `GameCatalog.duals` (`claseA+claseB`
  /// o `w_...` de un dúo de armas). `null` = el dúo de clase del par
  /// (como en v0.8.2).
  final String? dualId;
  const DualCommand(this.partnerId, {this.dualId});
}

/// `ether` es la Poción de maná (clave `eter`, histórica); `aether` es
/// el Éter que revive con toda la vida (loot.md § 17.6).
enum BattleItem { potion, ether, aether }

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
