import 'attributes.dart';
import 'battle_command.dart';
import 'upgrade_stat.dart';

/// Lo que un jugador le pide al host (`onMsg` del prototipo, un caso por
/// tipo de mensaje). `SessionEngine.apply` decide si es válida; si no lo
/// es, el estado no cambia. Ver docs/specs/missions.md y progression.md.
///
/// La traducción desde/hacia los DTO de red (`netcode/contracts`) es
/// trabajo de la capa de red, no de `game_engine`.
sealed class SessionAction {
  const SessionAction();
}

/// `pos`: el cliente informa su posición (se confía en ella).
class MoveAction extends SessionAction {
  final double x, y;
  final int dir;
  final bool moving;

  /// Época de posición que el cliente adoptó del último snapshot.
  final int epoch;
  const MoveAction(this.x, this.y,
      {required this.epoch, this.dir = 1, this.moving = false});
}

/// `propose`.
class ProposeMissionAction extends SessionAction {
  final String missionId;
  const ProposeMissionAction(this.missionId);
}

/// `vote`.
class VoteMissionAction extends SessionAction {
  final bool yes;
  const VoteMissionAction(this.yes);
}

/// `ready`.
class ReadyAction extends SessionAction {
  final bool ready;
  const ReadyAction(this.ready);
}

/// `cancelPrep`.
class CancelPrepAction extends SessionAction {
  const CancelPrepAction();
}

/// `seal`.
class ActivateSealAction extends SessionAction {
  final int itemId;
  const ActivateSealAction(this.itemId);
}

/// `cls`.
class ChangeClassAction extends SessionAction {
  final String classId;
  const ChangeClassAction(this.classId);
}

/// `respec`.
class RespecAction extends SessionAction {
  const RespecAction();
}

/// `stats`.
class AllocateStatsAction extends SessionAction {
  final Map<Attribute, int> add;
  const AllocateStatsAction(this.add);
}

/// `equip`.
class EquipAction extends SessionAction {
  final String weaponId;
  const EquipAction(this.weaponId);
}

/// `node`.
class TakeNodeAction extends SessionAction {
  final String nodeId;
  const TakeNodeAction(this.nodeId);
}

/// `treeReset`.
class ResetTreeAction extends SessionAction {
  const ResetTreeAction();
}

/// `fuse`.
class FuseAction extends SessionAction {
  final String baseWeaponId;
  final String sacrificeWeaponId;
  final String skillId;
  const FuseAction(this.baseWeaponId, this.sacrificeWeaponId, this.skillId);
}

/// `up`.
class UpgradeAction extends SessionAction {
  final String weaponId;
  final UpgradeStat stat;
  const UpgradeAction(this.weaponId, this.stat);
}

/// `buyItem`.
class BuyItemAction extends SessionAction {
  final BattleItem item;
  const BuyItemAction(this.item);
}

/// `buy`.
class BuyWeaponAction extends SessionAction {
  final String weaponId;
  const BuyWeaponAction(this.weaponId);
}

/// `cmd`: un comando de batalla en el turno del jugador.
class BattleAction extends SessionAction {
  final BattleCommand command;
  const BattleAction(this.command);
}

/// `back`: salir de la pantalla de resultados.
class BackToLobbyAction extends SessionAction {
  const BackToLobbyAction();
}
