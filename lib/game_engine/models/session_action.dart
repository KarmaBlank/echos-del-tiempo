import 'attributes.dart';
import 'battle_command.dart';
import 'eco.dart' show EcoCraftOp;
import 'item.dart' show CraftOp, Rarity;
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

/// Pausa de grupo (docs/specs/settings.md § "Pausa"): cualquier jugador
/// pausa ([paused] `true`) o reanuda (`false`) la sala entera.
class PauseAction extends SessionAction {
  final bool paused;
  const PauseAction(this.paused);
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

/// `chat`: un mensaje de texto para la sala. El host lo recorta (espacios
/// y [maxLength] caracteres) y rechaza los vacíos.
class ChatAction extends SessionAction {
  final String text;
  const ChatAction(this.text);

  /// `maxlength` del `#chatin` y `slice(0,120)` del host.
  static const maxLength = 120;
}

/// `back`: salir de la pantalla de resultados.
class BackToLobbyAction extends SessionAction {
  const BackToLobbyAction();
}

/// `stairs`: usar la escalera del piso con E (bajar en `>`, subir en
/// `<`). Mueve a todo el grupo. Ver docs/specs/worldgen.md § 6.7.
class UseStairsAction extends SessionAction {
  final bool down;
  const UseStairsAction({required this.down});
}

// ---------------- loot v2 (docs/specs/loot.md) ----------------

/// `craft`: una operación de la forja / mesa de fusión sobre el arma
/// [targetUid] (`CraftRules`). [sourceUid] es el arma que se sacrifica
/// (traslados) o la base nueva (reforjar), [index] el afijo elegido (o la
/// rareza en los lotes) y [skillId] la habilidad.
class CraftAction extends SessionAction {
  final CraftOp op;
  final String targetUid;
  final String? sourceUid;
  final int index;
  final String? skillId;
  const CraftAction(this.op, this.targetUid,
      {this.sourceUid, this.index = 0, this.skillId});

  /// Reforjar [uid] a la base [baseId] (loot.md § 21.3).
  const CraftAction.reforge(String uid, String baseId)
      : this(CraftOp.reforge, uid, sourceUid: baseId);

  /// Desarmar ([CraftOp.salvageAll]) o vender ([CraftOp.sellAll]) todas
  /// las armas de rareza [r] que no estén equipadas ni protegidas.
  CraftAction.batch(CraftOp op, Rarity r)
      : this(op, '*', index: r.index);
}

/// `give`: dar un arma (`uid`) o [count] de una pila (`pot`, `eter`,
/// `mat:<material>`) a otro jugador de la sala. Fuera de batalla; llega
/// al instante si el otro tiene lugar.
class GiveItemAction extends SessionAction {
  final String toPlayerId;
  final String token;
  final int count;
  const GiveItemAction(this.toPlayerId, this.token, {this.count = 1});
}

/// `drop`: soltar al piso (compartido) un arma o [count] de una pila.
class DropItemAction extends SessionAction {
  final String token;
  final int count;
  const DropItemAction(this.token, {this.count = 1});
}

/// `pick`: levantar un objeto del piso (tecla E), propio o compartido.
class PickUpAction extends SessionAction {
  final int groundId;
  const PickUpAction(this.groundId);
}

/// `invMove`: mover / intercambiar dos casillas del inventario.
class MoveInventoryAction extends SessionAction {
  final int from;
  final int to;
  const MoveInventoryAction(this.from, this.to);
}

/// `filter`: guardar el filtro de loot (texto; `null` = el por defecto).
class SetLootFilterAction extends SessionAction {
  final String? text;
  const SetLootFilterAction(this.text);

  /// Tope de largo del texto.
  static const maxLength = 8000;
}

// ---------------- endgame v0.4 (docs/specs/ecos_atlas.md) ----------------

/// Abrir un Eco propio en el Portal (propone la misión del Eco).
class ProposeEcoAction extends SessionAction {
  final String uid;
  const ProposeEcoAction(this.uid);
}

/// Craftear un Eco del inventario (Esquirla, Cristal, Prisma, Ancla).
class EcoCraftAction extends SessionAction {
  final String uid;
  final EcoCraftOp op;
  const EcoCraftAction(this.uid, this.op);
}

/// Solo desarrollo (`FeatureFlags.devTools`): activa el portal y da un
/// Eco Raro de [tier]. El motor la rechaza si no tiene `devTools`.
class DevGrantEcoAction extends SessionAction {
  final int tier;
  const DevGrantEcoAction(this.tier);
}

// ---------------- ascensión v0.5 (docs/specs/ascension.md) ----------------

/// Proponer la Prueba del Tiempo [trial] (1..3) en la Estatua.
class ProposeTrialAction extends SessionAction {
  final int trial;
  const ProposeTrialAction(this.trial);
}

/// Elegir la ascensión [ascensionId] (con la Prueba I superada).
class ChooseAscensionAction extends SessionAction {
  final String ascensionId;
  const ChooseAscensionAction(this.ascensionId);
}

/// Tomar un nodo del mini-árbol de la ascensión.
class TakeAscensionNodeAction extends SessionAction {
  final String nodeId;
  const TakeAscensionNodeAction(this.nodeId);
}

/// Reinicio gratis de los nodos; con [full] además saca la ascensión.
class ResetAscensionAction extends SessionAction {
  final bool full;
  const ResetAscensionAction({this.full = false});
}

/// Solo desarrollo (`FeatureFlags.devTools`): marca las Pruebas 1..[trial]
/// como superadas (y sube al nivel de la Prueba si faltaba).
class DevGrantTrialAction extends SessionAction {
  final int trial;
  const DevGrantTrialAction(this.trial);
}
