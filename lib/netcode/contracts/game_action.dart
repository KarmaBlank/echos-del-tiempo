/// Una acción que un jugador envía a la sesión de red. Es un DTO puro,
/// sin lógica: el host (o el servidor dedicado, en una impl futura) es
/// quien decide si es válida y la aplica al estado autoritativo.
///
/// `features/*` solo construye y envía estas acciones; nunca conoce el
/// transporte (WebRTC, WebSocket, lo que sea).
sealed class GameAction {
  const GameAction();
}

class AllocateStatsAction extends GameAction {
  final Map<String, int> points;
  const AllocateStatsAction(this.points);
}

class TakePassiveNodeAction extends GameAction {
  final String nodeId;
  const TakePassiveNodeAction(this.nodeId);
}

class ResetPassiveTreeAction extends GameAction {
  const ResetPassiveTreeAction();
}

class BattleCommandAction extends GameAction {
  final String kind; // 'atk' | 'tech' | 'ult' | 'item' | 'def'
  final String? skillId;
  final String? targetId;
  final String? itemTarget; // a quién se le tira la poción
  const BattleCommandAction({
    required this.kind,
    this.skillId,
    this.targetId,
    this.itemTarget,
  });
}

class ProposeMissionAction extends GameAction {
  final String missionId;
  const ProposeMissionAction(this.missionId);
}

class VoteMissionAction extends GameAction {
  final bool yes;
  const VoteMissionAction(this.yes);
}

class UpgradeWeaponAction extends GameAction {
  final String weaponId;
  final String stat; // 'pow' | 'crit' | 'spd' | 'def'
  const UpgradeWeaponAction(this.weaponId, this.stat);
}
