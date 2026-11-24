import 'run_state.dart';
import 'attributes.dart';
import 'battle_command.dart';
import 'build_wants.dart';
import 'eco.dart' show EcoCraftOp;
import 'fish_line.dart';
import 'inventory_sort.dart';
import 'item.dart' show CraftOp, Rarity;
import 'loot.dart' show LootDrop;
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

/// `travel` (protocolo 48): el anfitrión lleva al grupo al lugar [place]
/// del mapa de viaje (`pueblo`, `bosque`; overworld_biomes.md § 4).
class TravelAction extends SessionAction {
  final String place;

  /// Protocolo 59 (ecos_zone.md § 5): deja al jugador frente al portal de
  /// Ecos de esa zona (que tiene que estar en [place]). Con esto se puede
  /// "viajar" al exterior donde ya está, solo para acercarse al portal.
  final int? ecoZone;
  const TravelAction(this.place, {this.ecoZone});
}

/// `leaveD` (protocolo 57, free_movement.md § 2.4): salir solo de la
/// mazmorra, caminando a la entrada del piso 1 o desde una piedra de paso
/// activada ([poiId]). Los demás siguen adentro.
class LeaveDungeonAction extends SessionAction {
  final int? poiId;
  const LeaveDungeonAction({this.poiId});
}

/// `joinP` (protocolo 63, free_movement.md § 2.5): IR CON otro jugador,
/// a su instancia (pueblo, bioma o mazmorra) y a su posición.
class JoinPlayerAction extends SessionAction {
  final String targetId;
  const JoinPlayerAction(this.targetId);
}

/// `offer` (protocolo 58, persistent_dungeons.md § 4): pagar la Ofrenda
/// en el altar del jefe vencido de una mazmorra de zona para revivirlo.
class OfferBossAction extends SessionAction {
  const OfferBossAction();
}

/// `forage` (protocolo 48): recolectar el punto [spot] del exterior
/// (índice de `BosqueLayout.forage`; overworld_biomes.md § 3.2).
class ForageAction extends SessionAction {
  final int spot;
  const ForageAction(this.spot);
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

/// What [GatherAction] does with the open gathering.
enum GatherOp { join, leave, go, cancel }

/// `gather` (protocol 63, free_movement.md § 2.1): join / leave the open
/// gathering, or (its proposer) IR / cancel. Only the world routes it.
class GatherAction extends SessionAction {
  final GatherOp op;
  const GatherAction(this.op);
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

/// `untake` (v0.12): quita un nodo tomado; el host valida que el resto
/// siga conectado al inicio (progression_v2.md § 6.1).
class UntakeNodeAction extends SessionAction {
  final String nodeId;
  const UntakeNodeAction(this.nodeId);
}

/// `nodes` (v0.10): camino en un clic; el host los toma en orden hasta
/// el primero que falle (progression_v2.md § 4).
class TakeNodesAction extends SessionAction {
  final List<String> nodeIds;
  const TakeNodesAction(this.nodeIds);
}

/// `milestone` (v0.10): elige la keystone del hito 10 o 20
/// (progression_v2.md § 5).
class ChooseMilestoneAction extends SessionAction {
  final int milestone;
  final String keystoneId;
  const ChooseMilestoneAction(this.milestone, this.keystoneId);
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

/// `useItem`: poción de vida / maná fuera de batalla (loot.md § 17.5).
class UseItemAction extends SessionAction {
  final BattleItem item;
  const UseItemAction(this.item);
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

/// `leave` (v0.20.22): tras la victoria, LISTO para volver al pueblo
/// ([ready] `false` lo saca). Ver missions.md § "Fin de misión".
class LeaveReadyAction extends SessionAction {
  final bool ready;
  const LeaveReadyAction(this.ready);
}

/// `lost` (v0.20.22): tomar del pozo Loot perdido del pueblo la pieza
/// [lostId]. Ver missions.md § "Loot perdido".
class TakeLostLootAction extends SessionAction {
  final int lostId;
  const TakeLostLootAction(this.lostId);
}

/// `stairs`: usar la escalera del piso con E (bajar en `>`, subir en
/// `<`). Mueve a todo el grupo. Ver docs/specs/worldgen.md § 6.7.
class UseStairsAction extends SessionAction {
  final bool down;
  const UseStairsAction({required this.down});
}

/// E frente a un punto de interés del piso (worldgen.md § 11.3).
/// En una piedra de paso activada, [toPoi] elige la piedra de destino
/// (mapa en grande en modo "elegir destino", § 11.4); sin [toPoi] viaja a
/// la siguiente activada.
class InteractPoiAction extends SessionAction {
  final int poiId;
  final int? toPoi;
  const InteractPoiAction(this.poiId, {this.toPoi});
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

  /// Trasladar habilidad: cuál de las trasladadas del destino se
  /// reemplaza (obligatoria con los cupos llenos; loot.md § 16.2).
  final String? replaceSkillId;

  /// Armas elegidas a mano ([CraftOp.salvageSelected] /
  /// [CraftOp.sellSelected], v0.5.1); vacía en las demás operaciones.
  final List<String> uids;
  const CraftAction(this.op, this.targetUid,
      {this.sourceUid,
      this.index = 0,
      this.skillId,
      this.replaceSkillId,
      this.uids = const []});

  /// Desarmar ([CraftOp.salvageSelected]) o vender
  /// ([CraftOp.sellSelected]) las armas [uids] elegidas en LIMPIAR
  /// INVENTARIO (loot.md § 21.5).
  CraftAction.selected(CraftOp op, List<String> uids)
      : this(op, '*', uids: List.unmodifiable(uids));

  /// Reforjar [uid] a la base [baseId] (loot.md § 21.3).
  const CraftAction.reforge(String uid, String baseId)
      : this(CraftOp.reforge, uid, sourceUid: baseId);

  /// Desarmar ([CraftOp.salvageAll]) o vender ([CraftOp.sellAll]) todas
  /// las armas de rareza [r] que no estén equipadas ni protegidas.
  CraftAction.batch(CraftOp op, Rarity r) : this(op, '*', index: r.index);
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

/// Una pieza de un `stashPut`: [token] (`uid` de arma / Eco o
/// `mat:<m>`) y cuántos ([count], solo pilas).
class StashPutItem {
  final String token;
  final int count;
  const StashPutItem(this.token, {this.count = 1});
}

/// `stashPut` (v0.11.1, protocolo 21): sacar del perfil en la sesión
/// [items] (uno o un lote) para guardarlos en el alijo **local** de la
/// cuenta. El host valida cada pieza del lado del perfil y anota [opId]
/// en `SessionPlayer.stashAcks` con lo que salió; el cliente recién con
/// esa confirmación escribe su alijo. Repetir [opId] no hace nada
/// (docs/specs/characters.md § 3.2).
class StashPutAction extends SessionAction {
  final String opId;
  final List<StashPutItem> items;
  const StashPutAction(this.opId, this.items);

  /// Como mucho tantas piezas por operación.
  static const maxItems = 160;
}

/// `stashTake` (v0.11.1): sumar al perfil en la sesión [drops], que el
/// cliente tiene en su alijo local (los saca de ahí recién con la
/// confirmación [opId], solo los aceptados). Ver [StashPutAction].
class StashTakeAction extends SessionAction {
  final String opId;
  final List<LootDrop> drops;
  const StashTakeAction(this.opId, this.drops);
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

/// `invSort` (v0.5.1): ordenar la grilla del inventario por [key]
/// (`InventoryRules.sort`; la equipada sigue en su casilla).
class SortInventoryAction extends SessionAction {
  final InventorySortKey key;
  const SortInventoryAction(this.key);
}

/// `seen` (v0.9.7): sacar la marca NUEVO de armas / Ecos del inventario
/// (al pasar el mouse; loot.md § 17.4).
class SeenItemsAction extends SessionAction {
  final List<String> uids;
  const SeenItemsAction(this.uids);
}

/// `filter`: guardar el filtro de loot (texto; `null` = el por defecto).
/// `ultSel` (v0.17, ultimates_v2.md § 2.1): elige la ULT activa fuera
/// de combate. `null` = volver al orden de siempre. El host rechaza un id
/// que el jugador no tiene.
class SelectUltAction extends SessionAction {
  final String? ultId;
  const SelectUltAction(this.ultId);
}

/// `ultUp` (v0.17, ultimates_v2.md § 2.4): sube un nivel la ULT [ultId]
/// del repertorio pagando su costo. El host valida que la tenga y que
/// alcancen los créditos y materiales.
class UpgradeUltAction extends SessionAction {
  final String ultId;
  const UpgradeUltAction(this.ultId);
}

class SetLootFilterAction extends SessionAction {
  final String? text;
  const SetLootFilterAction(this.text);

  /// Tope de largo del texto.
  static const maxLength = 8000;
}

/// `wants` (v0.5.1, protocolo 6): el resumen del plan de build del
/// jugador ([BuildWants]; `null` = sin plan) para la condición `Build`
/// del filtro de loot. El host lo guarda en la sesión solo para evaluar
/// los drops de ese jugador; no se difunde. Docs/specs/build_planner.md § 6.
class SetBuildWantsAction extends SessionAction {
  final BuildWants? wants;
  const SetBuildWantsAction(this.wants);
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

// ---------------- Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md) -----

/// Abrir el Jefe del Abismo [boss] (1..5) en el Portal: lo propone al
/// grupo; su costo se consume al empezar.
class ProposeAbyssAction extends SessionAction {
  final int boss;
  const ProposeAbyssAction(this.boss);
}

/// Solo desarrollo (`FeatureFlags.devTools`): [kind] `frag` da 5 de cada
/// Fragmento y 3 Esencias; `kills` marca los 4 jefes como vencidos.
class DevAbyssAction extends SessionAction {
  final String kind;
  const DevAbyssAction(this.kind);

  static const fragments = 'frag';
  static const kills = 'kills';
}

// ---------------- TUTORIAL v0.9 (docs/specs/combat_tutorial.md) ----------

/// Empezar el TUTORIAL: Ecos de práctica desde el sello (§ 1). En una
/// sala con más humanos solo el host puede, y entran todos. Jugando solo,
/// [companions] decide si entran los compañeros de la party.
class StartTutorialAction extends SessionAction {
  final bool companions;
  const StartTutorialAction({this.companions = true});
}

/// Cerrar el cartel de efecto (ESPACIO, clic): el paso avanza cuando lo
/// cierra quien actuó (§ 4.1).
class TutorialAckAction extends SessionAction {
  const TutorialAckAction();
}

/// Menú de pausa del tutorial (§ 4.3).
enum TutorialControl {
  /// Empieza de nuevo con los roles rotados.
  repeat,

  /// Vuelve al principio de la etapa actual.
  repeatStage,

  /// Sale sin completarlo.
  exit,
}

/// Voto en las votaciones del final del TUTORIAL (§ 4.4): `roles`,
/// `train`, `exit`, `restart` o `role:<rol>`.
class TutorialChoiceAction extends SessionAction {
  final String choice;
  const TutorialChoiceAction(this.choice);
}

class TutorialControlAction extends SessionAction {
  final TutorialControl op;
  const TutorialControlAction(this.op);
}

/// `ach` (docs/specs/achievements.md § 5.2): el cliente avisa una hazaña
/// que solo él ve (buscador, MOVER TODO, Atlas de la cuenta, plan de
/// BUILD). El host acepta solo las de `kClientClaimableAchievements` y
/// paga una sola vez, como las demás.
class ClaimAchievementAction extends SessionAction {
  final String id;
  const ClaimAchievementAction(this.id);
}

// ---------------- Travesía (docs/specs/roguelike.md) ----------------

/// Empezar una Travesía desde la sala (o una nueva al terminar).
class RunStartAction extends SessionAction {
  /// Del progreso del anfitrión (§ 8, protocolo Travesía 3): zonas
  /// desbloqueadas además de las del arranque, dificultad elegida y
  /// victorias contra cada élite.
  final int zones;
  final int difficulty;
  final Map<String, int> eliteWins;
  const RunStartAction(
      {this.zones = 0, this.difficulty = 0, this.eliteWins = const {}});
}

/// Lo que cada jugador trae de su progreso entre runs (§ 8.1): loadout y
/// bonos del árbol de afuera. Se manda en la sala, antes de empezar.
class RunPrepAction extends SessionAction {
  final RunPrep prep;
  const RunPrepAction(this.prep);
}

/// Marcar el próximo nodo del mapa (§ 3: votación).
class RunVoteAction extends SessionAction {
  final int nodeId;
  const RunVoteAction(this.nodeId);
}

/// Elegir la recompensa: un índice por fila o `null` para saltarla.
class RunRewardAction extends SessionAction {
  final int? tree;
  final int? weapon;
  final int? extra;

  /// Fila ULT (Travesía v0.1.1, protocolo 2).
  final int? ult;

  /// Habilidad libre que se sacrifica si la nueva no entra (§ 12.2).
  final String? drop;
  const RunRewardAction(
      {this.tree, this.weapon, this.extra, this.ult, this.drop});
}

/// LISTO en tienda / armería / descanso.
class RunReadyAction extends SessionAction {
  const RunReadyAction();
}

/// Travesía: equipar ([equip]) o guardar una habilidad libre propia
/// (§ 12.2). Equipar respeta el tope de habilidades.
class RunSkillAction extends SessionAction {
  final String skillId;
  final bool equip;
  const RunSkillAction(this.skillId, {required this.equip});
}

/// Travesía: mejorar una habilidad libre en la armería (§ 12.2).
class RunUpgradeSkillAction extends SessionAction {
  final String skillId;
  const RunUpgradeSkillAction(this.skillId);
}

/// Travesía: comprar una ULT de la tienda del nodo (roguelike.md § 12.2).
class RunBuyUltAction extends SessionAction {
  final String ultId;
  const RunBuyUltAction(this.ultId);
}

// ---- Pesca y agropecuario (v0.22.0, docs/specs/fishing.md § 6) ----

/// `fBite`: picada clavada en un punto de pesca. El host tira el pez
/// (con [power], la carga del lance 0..1) y lo manda en `FishBiteEvent`.
class FishBiteAction extends SessionAction {
  final double power;
  const FishBiteAction(this.power);
}

/// `fRes`: el minijuego local terminó; el cliente solo dice si lo sacó.
class FishResultAction extends SessionAction {
  final bool success;
  const FishResultAction(this.success);
}

/// `fLn`: lo que se ve de la pesca del jugador en el mapa (caña, línea,
/// boya; v0.22.2). [line] `null` = guardó la caña.
class FishLineAction extends SessionAction {
  final FishLine? line;
  const FishLineAction(this.line);
}

/// `wisp`: prender / apagar la Llama errante (lighting.md § 3.1.1).
class WispAction extends SessionAction {
  final bool on;
  const WispAction(this.on);
}

/// `fSell`: vender en el agropecuario. [species] `null` = Vender todo
/// (menos legendarios). [materials]: cobrar en Esquirlas.
class SellFishAction extends SessionAction {
  final String? species;
  final bool materials;
  const SellFishAction({this.species, this.materials = false});
}

/// `fSwap`: canjear un pez legendario por materiales raros.
class ExchangeFishAction extends SessionAction {
  final String species;
  const ExchangeFishAction(this.species);
}

/// `rodBuy`: comprar una caña.
class BuyRodAction extends SessionAction {
  final String rodId;
  const BuyRodAction(this.rodId);
}

// ---- Cultivo, pueblo y oficios (v0.23.0, protocolo 44; farming.md § 10) ----

/// Labor sobre un tile de la huerta.
enum FarmOp { till, plant, water, fert, harvest }

/// `farm`: una labor en el tile ([tx], [ty]); [seed] al plantar.
class FarmTileAction extends SessionAction {
  final FarmOp op;
  final int tx, ty;
  final String? seed;
  const FarmTileAction(this.op, this.tx, this.ty, {this.seed});
}

/// Compra, venta y equipo de la huerta en el agropecuario.
enum FarmShopOp {
  buySeed,
  buyTool,
  equipTool,
  buyAbono,
  sell,
  sellAll,
  exchange,
  selectSeed
}

/// `farmShop`: [id] = cultivo, herramienta o clave de cosecha.
class FarmShopAction extends SessionAction {
  final FarmShopOp op;
  final String? id;
  final int n;
  final bool materials;
  const FarmShopAction(this.op, {this.id, this.n = 1, this.materials = false});
}

/// Mejoras del pueblo en la fuente rúnica.
enum TownOp {
  expand,
  place,
  move,
  remove,
  stock,
  hireHelper,
  fireHelper,
  helperTasks,
  giveSeeds,
  takeSeeds,
  collectChest,

  /// v0.27.0: mejora [id] (`HelperUpgrade`) del ayudante [x] de [target].
  helperUpgrade,

  /// v0.28.0 (protocolo 50): pedir / soltar el candado de la edición
  /// del pueblo (town_editor.md § 1.3).
  lock,
  unlock,

  /// v0.30.2 (protocolo 52, roles.md § 8): SEGUIR / dejar de seguir el
  /// encargo [target] (`<tipo>:<habitante>`) y marcar como visto lo que
  /// [id] tiene para decir. Solo tocan el perfil de quien lo pide.
  track,
  seen,

  /// v0.30.0 (protocolo 51): habitantes (overworld_biomes.md § 10), con
  /// [TownAction.id] = habitante. `assign`: [TownAction.target] = casa;
  /// `gift`: [TownAction.target] = producto.
  invite,
  assign,
  gift,
  turnIn,
  fulfil,
  invest,
  order,

  /// Encargo de forja de Brann (roles.md § 4): un arma de tu clase.
  commission,

  /// v0.31.0 (protocolo 52): entregar el pedido del pescador nativo del
  /// bioma (fishing.md § 12), [TownAction.id] = bioma.
  fisherReq,

  /// v0.32.6 (protocolo 56, overworld_biomes.md § 12): `talk` cuenta una
  /// charla con [TownAction.id] (habitante o `pesc_<bioma>`), una por día;
  /// `nativeInvite` invita al arraigado del bioma [TownAction.id] (dice
  /// que no y da su regalo); `nativeTrade` le compra ([TownAction.x] = 1)
  /// o le vende [TownAction.n] de [TownAction.target].
  talk,
  nativeInvite,
  nativeTrade
}

/// `town` (town_editor.md § 8): [id] = lado al ampliar (`n`/`s`/`e`/`o`),
/// construcción del catálogo al poner o especie al soltar un pez;
/// [target] = la construcción a mover, borrar o el lago donde soltar;
/// ([x], [y]) = tile del mapa de la esquina al poner o mover.
/// Ayudantes (v0.25.5): `hireHelper` / `fireHelper` / `collectChest` con
/// [target]; `giveSeeds` / `takeSeeds` con [target], [id] = cultivo y
/// [n] = cantidad (0 = todas); `helperTasks` con [target], [x] = el
/// granjero y [n] = bits de `HelperTask`.
class TownAction extends SessionAction {
  final TownOp op;
  final String? id;
  final String? target;
  final int? x, y;
  final int n;
  const TownAction(this.op,
      {this.id, this.target, this.x, this.y, this.n = 1});
}

/// `lifeTree`: tomar un nodo ([node]) o reiniciar ([node] `null`) del
/// árbol de un oficio (life_skill_trees.md).
class LifeTreeAction extends SessionAction {
  final String skill;
  final String? node;
  const LifeTreeAction(this.skill, this.node);
}

/// `rodEq`: equipar una caña propia (espacio de herramienta).
class EquipRodAction extends SessionAction {
  final String rodId;
  const EquipRodAction(this.rodId);
}
