import 'dart:collection';

import 'battle_state.dart';
import 'build_wants.dart';
import 'combat_mode.dart';
import 'eco.dart';
import 'exploration.dart';
import 'fish_line.dart';
import 'game_map.dart' show WorldPoint;
import 'item.dart';
import 'loot.dart';
import 'player_profile.dart';
import 'run_state.dart';
import 'turn_timer.dart';
import 'world_save.dart' show TownState;
import 'tutorial.dart';

export 'exploration.dart';
export 'turn_timer.dart';
export 'run_state.dart';

/// Modo de la sesión (`S.mode` del prototipo).
///
/// `run`: la Travesía fuera de batalla (mapa, recompensa, tienda / armería
/// / descanso, fin; ver `RunState.phase` y docs/specs/roguelike.md).
enum SessionMode { lobby, prep, field, battle, levelUp, result, run }

/// Objetivo de una misión (`OBJN`).
enum ObjectiveKind {
  kills('Grupos derrotados'),
  fragments('Fragmentos de tiempo'),
  seals('Sellos activados'),
  elite('Élite derrotado');

  const ObjectiveKind(this.label);
  final String label;
}

/// Objeto del campo (`S.items`).
enum MissionItemKind { fragment, seal, chest }

/// Rango final de una misión.
enum MissionRank { s, a, b, d }

/// A dónde se va al terminar la pausa de subida de nivel (`S.after`).
enum AfterLevelUp { field, result }

// ----------------------------------------------------------------------
// Todas las clases de este archivo son mutables a propósito, igual que
// `BattleState`: `SessionEngine` siempre trabaja sobre una copia
// (`GameSession.copy`) y devuelve el estado nuevo, así que desde afuera
// la sesión es inmutable. Quien la recibe (UI, red) solo debe leerla.
// ----------------------------------------------------------------------

/// Un jugador dentro de la sesión: su perfil persistente + lo que solo
/// existe mientras juega (posición, vida actual...).
class SessionPlayer {
  SessionPlayer({
    required this.id,
    required this.profile,
    required this.x,
    required this.y,
    required this.hp,
    required this.mp,
    required this.maxHp,
    required this.maxMp,
    this.dir = 1,
    this.epoch = 1,
    this.moving = false,
    this.ult = 0,
    this.levelUpPending = false,
    this.spikeReady = 0,
    this.buildWants,
    this.leaderId,
    List<WorldPoint>? trail,
    this.trailEpoch = 0,
    this.tutorialVersion = 0,
    Map<String, StashAck>? stashAcks,
    this.fishLine,
  })  : trail = trail ?? const [],
        stashAcks = stashAcks ?? {};

  /// Confirmaciones de `stashPut` / `stashTake` (id de operación → qué se
  /// movió), en orden; las últimas [StashAck.keep]. Viajan en el snapshot
  /// (`sk`) junto al perfil ya cambiado: el cliente escribe su alijo local
  /// recién al verlas (docs/specs/characters.md § 3.2).
  final Map<String, StashAck> stashAcks;

  /// Caña, línea y boya a la vista de todos (`fl`, fishing.md § 7); `null`
  /// = no está pescando. Lo manda el propio jugador (`fLn`) y el host lo
  /// valida y lo borra si camina.
  FishLine? fishLine;

  /// Anota [ack] como [opId] (descarta las más viejas).
  void addStashAck(String opId, StashAck ack) {
    stashAcks[opId] = ack;
    while (stashAcks.length > StashAck.keep) {
      stashAcks.remove(stashAcks.keys.first);
    }
  }

  /// Compañero de la party de un jugador solo (docs/specs/solo_party.md
  /// § 3): el id del líder que lo controla; `null` = un humano. Solo lo
  /// usa el host: **no** viaja en el snapshot (en una sala no hay
  /// compañeros).
  final String? leaderId;

  /// Es un compañero ([leaderId] no es `null`).
  bool get isCompanion => leaderId != null;

  /// Rastro del líder (el más nuevo primero) que siguen sus compañeros
  /// en fila (solo_party.md § 3.5). Solo host.
  List<WorldPoint> trail;

  /// Última versión del TUTORIAL que completó su cuenta (`tutV`, llega
  /// en el `hello`; combat_tutorial.md § 2). 0 = nunca.
  int tutorialVersion;

  /// `epoch` del líder cuando se armó [trail] (otro = se teletransportó).
  int trailEpoch;

  /// Resumen del plan de build del jugador (`SetBuildWantsAction`) para la
  /// condición `Build` de su filtro de loot. Solo lo usa el host: **no**
  /// viaja en el snapshot ni se guarda (build_planner.md § 6).
  BuildWants? buildWants;

  /// Reloj de la sala desde el que las púas de la Prueba vuelven a dañar
  /// a este jugador (ascension.md § 1.1). Solo lo usa el host.
  double spikeReady;

  final String id;

  /// Progreso persistente: lo que la UI debe guardar con `ProfileStore`.
  PlayerProfile profile;
  double x, y;

  /// 1 mira a la derecha, -1 a la izquierda.
  int dir;

  /// Época de posición (`ep`): sube cada vez que el host teletransporta
  /// al jugador; el cliente debe adoptar la posición del snapshot y
  /// mandar sus `MoveAction` con esta época.
  int epoch;
  bool moving;

  /// Vida y maná actuales. Fraccionarios en el campo (regeneran por
  /// segundo); la UI muestra `ceil(hp)`.
  double hp;
  double mp;

  /// Máximos con el build actual (cache de `ProgressionRules.derivedStats`).
  int maxHp;
  int maxMp;
  double ult;

  /// Subió de nivel en esta misión y todavía no repartió (`lvup`).
  bool levelUpPending;

  String get name => profile.name;
  bool get alive => hp > 0;

  SessionPlayer copy() => SessionPlayer(
        id: id,
        profile: profile,
        x: x,
        y: y,
        hp: hp,
        mp: mp,
        maxHp: maxHp,
        maxMp: maxMp,
        dir: dir,
        epoch: epoch,
        moving: moving,
        ult: ult,
        levelUpPending: levelUpPending,
        spikeReady: spikeReady,
        buildWants: buildWants,
        leaderId: leaderId,
        trail: trail,
        trailEpoch: trailEpoch,
        tutorialVersion: tutorialVersion,
        stashAcks: {...stashAcks},
        fishLine: fishLine,
      );
}

/// Lo que el host confirmó de una operación del alijo: [put] = salió del
/// perfil hacia el alijo; si no, entró al perfil desde el alijo. [drop] es
/// lo que se movió.
class StashAck {
  const StashAck({required this.put, required this.drops, this.box = false});

  final bool put;

  /// Recuperado que el filtro del dueño oculta: va directo a Objetos sin
  /// recoger, sin ocupar el alijo (loot.md § 4b.1, protocolo 37).
  final bool box;

  /// Una por pieza pedida, en el mismo orden: lo que se movió, o `null`
  /// si esa pieza se rechazó.
  final List<LootDrop?> drops;

  /// Cuántas confirmaciones se guardan por jugador.
  static const keep = 32;

  /// Prefijo de las confirmaciones que genera el host solo: loot propio
  /// recuperado del piso (o que no entró en el inventario) que el
  /// cliente guarda en su alijo o en Objetos sin recoger (loot.md § 4b).
  static const recoverPrefix = 'rec:';

  static bool isRecover(String opId) => opId.startsWith(recoverPrefix);
}

/// Un grupo de enemigos en el campo (`S.fe`).
class FieldEnemy {
  FieldEnemy({
    required this.id,
    required this.x,
    required this.y,
    required this.homeX,
    required this.homeY,
    required this.group,
    this.boss = false,
    this.elite = false,
    this.alive = true,
    this.timer = 0,
    this.vx = 0,
    this.vy = 0,
    this.dir = -1,
    this.aggro = false,
    this.floor = 0,
  });

  final int id;
  double x, y;
  final double homeX, homeY;

  /// Tipos de enemigo del grupo (el primero es el élite / jefe).
  final List<String> group;
  final bool boss;
  final bool elite;
  bool alive;

  /// Temporizador del deambular (`tm`).
  double timer;
  double vx, vy;
  int dir;
  bool aggro;

  /// Piso de la zona donde está (0 en misiones de un solo mapa).
  final int floor;

  FieldEnemy copy() => FieldEnemy(
        id: id,
        x: x,
        y: y,
        homeX: homeX,
        homeY: homeY,
        group: group,
        boss: boss,
        elite: elite,
        alive: alive,
        timer: timer,
        vx: vx,
        vy: vy,
        dir: dir,
        aggro: aggro,
        floor: floor,
      );
}

/// Fragmento, sello o cofre del campo.
class MissionItem {
  MissionItem({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.done = false,
    this.floor = 0,
    this.tier = ChestTier.madera,
    this.guard,
    this.secret,
  });

  final int id;
  final MissionItemKind kind;
  final double x, y;
  bool done;

  /// Piso de la zona donde está.
  final int floor;

  /// Calidad del cofre (worldgen.md § 11, loot.md § 23).
  final ChestTier tier;

  /// Grupo élite que lo custodia (no se abre mientras viva).
  final int? guard;

  /// PdI de la sala secreta donde está.
  final int? secret;

  MissionItem copy() => MissionItem(
      id: id,
      kind: kind,
      x: x,
      y: y,
      done: done,
      floor: floor,
      tier: tier,
      guard: guard,
      secret: secret);
}

class MissionObjective {
  MissionObjective(this.kind, this.goal, {this.count = 0});

  final ObjectiveKind kind;
  final int goal;
  int count;

  bool get done => count >= goal;

  MissionObjective copy() => MissionObjective(kind, goal, count: count);
}

/// Un arma ganada (élite, fin de misión o cofre). [weaponId] es la base;
/// [uid] y [rarity], la instancia (loot v2; `null` en resultados viejos).
class WeaponDrop {
  final String playerId;
  final String weaponId;
  final String? uid;
  final Rarity? rarity;
  const WeaponDrop(this.playerId, this.weaponId, {this.uid, this.rarity});
}

/// La misión en curso (`S.mission` + `S.fe` + `S.items`).
class MissionRun {
  MissionRun({
    required this.missionId,
    required this.seed,
    required this.goal,
    required this.objectives,
    required this.enemies,
    required this.items,
    this.kills = 0,
    this.elapsed = 0,
    this.kos = 0,
    this.xp = 0,
    this.credits = 0,
    this.open = false,
    this.elites = 0,
    List<WeaponDrop>? eliteDrops,
    this.zoneLevel = 1,
    this.zone = 0,
    this.floor = 0,
    this.floors = 1,
    List<int>? floorGoals,
    List<int>? levels,
    Set<int>? opened,
    Set<int>? poiUsed,
    Set<int>? poiSeen,
    Set<int>? questsDone,
    Set<int>? questsFailed,
    this.blessing,
    this.windUntil = 0,
  })  : eliteDrops = eliteDrops ?? [],
        floorGoals = List.unmodifiable(floorGoals ?? const <int>[]),
        levels = List.unmodifiable(levels ?? const <int>[]),
        opened = {...?opened},
        poiUsed = {...?poiUsed},
        poiSeen = {...?poiSeen},
        questsDone = {...?questsDone},
        questsFailed = {...?questsFailed};

  // ---- exploración v0.6 (worldgen.md § 11) ----

  /// PdI usados: salas abiertas, santuarios, piedras activadas, atajos,
  /// braseros encendidos, reliquias levantadas.
  final Set<int> poiUsed;

  /// PdI descubiertos (el minimapa los muestra).
  final Set<int> poiSeen;

  /// Misiones opcionales cumplidas / falladas.
  final Set<int> questsDone;
  final Set<int> questsFailed;

  /// Bendición de santuario activa (una por misión).
  BlessingKind? blessing;

  /// Viento del Eco activo para el grupo hasta este `GameSession.time`.
  double windUntil;

  final String missionId;
  final int seed;

  /// Nivel de zona del loot: en misiones de zona, el del piso actual
  /// (worldgen.md § 6.3); en las viejas, `LootRules.zoneLevel` fijo.
  int zoneLevel;

  /// Zona de la misión (0 = misión de un solo mapa).
  final int zone;

  /// Piso actual (desde 0) y cantidad de pisos.
  int floor;
  final int floors;

  /// Grupos normales a vencer en cada piso para abrir su barrera.
  final List<int> floorGoals;

  /// Nivel de los enemigos de cada piso (vacío = sin escalado).
  final List<int> levels;

  /// Pisos (no el último) con la barrera de la escalera abierta.
  final Set<int> opened;

  bool get isLastFloor => floor >= floors - 1;

  Iterable<FieldEnemy> enemiesOn(int f) => enemies.where((e) => e.floor == f);
  Iterable<MissionItem> itemsOn(int f) => items.where((i) => i.floor == f);

  /// Grupos normales vencidos en el piso [f].
  int floorKills(int f) =>
      enemiesOn(f).where((e) => !e.alive && !e.boss && !e.elite).length;

  /// Cuota de grupos y fragmentos/sellos del piso [f] cumplidos.
  bool floorCleared(int f) =>
      floorKills(f) >= (f < floorGoals.length ? floorGoals[f] : 0) &&
      itemsOn(f).every((i) => i.kind == MissionItemKind.chest || i.done);

  /// La barrera del piso [f] está abierta (escalera o jefe).
  bool floorOpen(int f) => f >= floors - 1 ? open : opened.contains(f);

  /// Grupos normales a derrotar (`min(goal, grupos ubicados)`).
  final int goal;
  int kills;

  /// Segundos jugados (solo cuentan campo y batalla).
  double elapsed;

  /// K.O. de jugadores en toda la misión.
  int kos;

  /// XP y créditos ganados en batallas (por jugador).
  int xp;
  int credits;
  final List<MissionObjective> objectives;

  /// La barrera del jefe está abierta.
  bool open;
  int elites;
  final List<WeaponDrop> eliteDrops;
  final List<FieldEnemy> enemies;
  final List<MissionItem> items;

  MissionObjective? objective(ObjectiveKind k) {
    for (final o in objectives) {
      if (o.kind == k) return o;
    }
    return null;
  }

  FieldEnemy? enemy(int id) {
    for (final e in enemies) {
      if (e.id == id) return e;
    }
    return null;
  }

  MissionRun copy() => MissionRun(
        missionId: missionId,
        seed: seed,
        goal: goal,
        objectives: [for (final o in objectives) o.copy()],
        enemies: [for (final e in enemies) e.copy()],
        items: [for (final i in items) i.copy()],
        kills: kills,
        elapsed: elapsed,
        kos: kos,
        xp: xp,
        credits: credits,
        open: open,
        elites: elites,
        eliteDrops: [...eliteDrops],
        zoneLevel: zoneLevel,
        zone: zone,
        floor: floor,
        floors: floors,
        floorGoals: floorGoals,
        levels: levels,
        opened: opened,
        poiUsed: poiUsed,
        poiSeen: poiSeen,
        questsDone: questsDone,
        questsFailed: questsFailed,
        blessing: blessing,
        windUntil: windUntil,
      );
}

/// Una batalla dentro de la sesión: el estado del `BattleEngine` + el
/// ritmo del host (`battleTick`).
class SessionBattle {
  SessionBattle({
    required this.id,
    required this.state,
    required this.fieldEnemyId,
    required this.boss,
    required this.elite,
    this.wait = 1.0,
    this.turnTime = 0,
    this.endTimer,
    this.endHold = 0,
    this.level = 0,
  });

  /// Nivel de los enemigos (worldgen.md § 6.3); 0 = sin escalar.
  final int level;

  /// Sube con cada batalla (`bid`): la UI lo usa para saber que es otra.
  final int id;
  BattleState state;
  final int fieldEnemyId;
  final bool boss;
  final bool elite;

  /// Pausa restante antes del próximo paso (s).
  double wait;

  /// Tiempo que lleva el jugador de turno sin actuar (s).
  double turnTime;

  /// Pausa final antes de `finishBattle`; `null` mientras se pelea.
  double? endTimer;

  /// Parte de [endTimer] que todavía ocupa la cinemática del golpe final
  /// (ULT, dúo, ULT enemiga): mientras sea > 0 la presentación no muestra
  /// el desenlace (battle_presentation.md § "Fin de batalla").
  double endHold;

  /// El desenlace ya se puede presentar (jingle, pieza de fondo, cartel):
  /// terminó la reproducción del golpe que cerró la batalla.
  bool get outcomeShown => state.outcome != null && endHold <= 0;

  /// Le toca a un jugador y la sesión espera su `BattleAction`.
  bool get waitingForPlayer {
    final cur = state.current;
    return endTimer == null &&
        wait <= 0 &&
        ((cur != null && cur.isPlayer) || state.awaitingGroup);
  }

  SessionBattle copy() => SessionBattle(
        id: id,
        state: state.copy(),
        fieldEnemyId: fieldEnemyId,
        boss: boss,
        elite: elite,
        wait: wait,
        turnTime: turnTime,
        endTimer: endTimer,
        endHold: endHold,
        level: level,
      );
}

/// Votación de misión en el lobby (`S.vote`).
class MissionVote {
  MissionVote(this.missionId, this.proposedBy, Set<String> yes)
      : yes = {...yes};
  final String missionId;
  final String proposedBy; // nombre
  final Set<String> yes;

  MissionVote copy() => MissionVote(missionId, proposedBy, yes);
}

/// Fase de preparación (`S.prep`).
class MissionPrep {
  MissionPrep(this.missionId, [Map<String, bool>? ready]) : ready = {...?ready};
  final String missionId;
  final Map<String, bool> ready;

  MissionPrep copy() => MissionPrep(missionId, ready);
}

/// Pantalla de resultados (`S.result`).
class MissionResult {
  MissionResult({
    required this.id,
    required this.missionId,
    required this.missionName,
    required this.success,
    required this.rank,
    required this.time,
    required this.xp,
    required this.credits,
    required this.bonus,
    required this.bonusPercent,
    required this.kos,
    required this.elites,
    required this.eliteDrops,
    required this.drops,
    this.timeLeft = 25,
    this.zone = 0,
    this.unlocked = const {},
  });

  /// Zona de la misión (0 = sin zona).
  final int zone;

  /// Zona nueva desbloqueada por jugador (worldgen.md § 6.4).
  final Map<String, int> unlocked;

  final int id;
  final String missionId;
  final String missionName;
  final bool success;
  final MissionRank rank;
  final double time;
  final int xp;
  final int credits;
  final int bonus;
  final double bonusPercent;
  final int kos;
  final int elites;
  final List<WeaponDrop> eliteDrops;

  /// Arma de fin de misión por jugador.
  final Map<String, String> drops;

  /// Segundos hasta volver solos al lobby.
  double timeLeft;

  MissionResult copy() => MissionResult(
        id: id,
        missionId: missionId,
        missionName: missionName,
        success: success,
        rank: rank,
        time: time,
        xp: xp,
        credits: credits,
        bonus: bonus,
        bonusPercent: bonusPercent,
        kos: kos,
        elites: elites,
        eliteDrops: eliteDrops,
        drops: drops,
        timeLeft: timeLeft,
        zone: zone,
        unlocked: unlocked,
      );
}

/// Estado autoritativo de una sala (`S` del host). Ver
/// docs/specs/missions.md.
class GameSession {
  GameSession({
    this.mode = SessionMode.lobby,
    LinkedHashMap<String, SessionPlayer>? players,
    this.mission,
    this.battle,
    this.vote,
    this.prep,
    this.result,
    this.time = 0,
    this.graceUntil = 0,
    this.afterLevelUp,
    this.seq = 0,
    List<GroundLoot>? ground,
    this.groundSeq = 0,
    this.pausedBy,
    this.pausedName,
    this.eco,
    this.ecoOwner,
    List<String>? atlas,
    this.trial,
    this.turnTimer = TurnTimer.normal,
    this.combatMode,
    this.abyss,
    this.abyssOwner,
    this.tutorial,
    this.tutorialRuns = 0,
    this.run,
    Set<String>? leaveReady,
    List<GroundLoot>? lostLoot,
    this.worldId,
    this.worldName,
    this.town = const TownState(),
  })  : players = players ?? LinkedHashMap(),
        ground = ground ?? [],
        leaveReady = leaveReady ?? {},
        lostLoot = lostLoot ?? [],
        atlas = List.unmodifiable(atlas ?? const <String>[]);

  SessionMode mode;

  /// En orden de llegada (decide spawn, orden en batalla y desempates).
  final LinkedHashMap<String, SessionPlayer> players;
  MissionRun? mission;
  SessionBattle? battle;
  MissionVote? vote;
  MissionPrep? prep;
  MissionResult? result;

  /// Reloj de la sesión en segundos (avanza con `tick`).
  double time;

  /// Hasta cuándo dura la gracia del campo (enemigos calmos).
  double graceUntil;
  AfterLevelUp? afterLevelUp;

  /// Contador para ids de batallas y resultados.
  int seq;

  /// Loot en el suelo del mapa actual (instanciado por dueño, o
  /// compartido si lo soltó un jugador), de todos los pisos de la
  /// misión: cada uno queda en el piso donde cayó ([GroundLoot.floor]) y
  /// solo se ve y se levanta ahí ([groundFor]). Se vacía al cambiar de
  /// mapa (empezar misión / volver al pueblo). Ver loot.md § 4 y
  /// netcode.md § "Loot instanciado".
  final List<GroundLoot> ground;

  /// Contador para ids de [ground].
  int groundSeq;

  /// Tras la victoria (v0.20.22, missions.md § "Fin de misión"): quién
  /// tocó LISTO para volver al pueblo.
  final Set<String> leaveReady;

  /// Pozo Loot perdido de la sala (missions.md § "Loot perdido"): lo
  /// que quedó en el piso al volver al pueblo. Lo toma cualquiera; se
  /// vacía al empezar la próxima misión. Sin posición ni dueño.
  final List<GroundLoot> lostLoot;

  /// Se venció al jefe y el grupo sigue en el mapa juntando el botín
  /// hasta que todos tocan LISTO.
  bool get victoryLap => mode == SessionMode.field && result != null;

  /// Quién pausó la sala (`null` = corriendo). Mientras está pausada el
  /// host no avanza nada (docs/specs/settings.md § "Pausa"). Si ese
  /// jugador se va, sigue pausada: cualquiera reanuda.
  String? pausedBy;

  /// Su nombre cuando pausó (para el cartel aunque ya no esté).
  String? pausedName;

  /// El Eco que se vota, se prepara o se juega (docs/specs/ecos_atlas.md
  /// § 4), con los modificadores gratis del Atlas ya agregados al empezar.
  EcoItem? eco;

  /// Quien abrió el Eco (se le consume al empezar).
  String? ecoOwner;

  /// Nodos del Atlas del anfitrión (§ 5.2): sus efectos valen para toda
  /// la sala.
  List<String> atlas;

  /// La Prueba del Tiempo (1..3) que se vota, prepara o juega
  /// (docs/specs/ascension.md § 1).
  int? trial;

  /// El Jefe del Abismo (1..5) que se vota, prepara o juega
  /// (docs/specs/abyss_bosses.md § 1.2).
  int? abyss;

  /// Quien lo abrió (se le consumen los Fragmentos al empezar).
  String? abyssOwner;

  /// El guion del TUTORIAL en curso (docs/specs/combat_tutorial.md § 4.1):
  /// viaja en el snapshot. `null` = no se está jugando.
  TutorialState? tutorial;

  /// Tutoriales empezados en esta sala: el próximo intento rota los roles
  /// (§ 4.3).
  int tutorialRuns;

  /// La Travesía en curso (docs/specs/roguelike.md); `null` en el Mundo.
  RunState? run;

  /// Se juega el TUTORIAL.
  bool get inTutorial => tutorial != null;

  /// Tiempo de turno de la sala: el ajuste del anfitrión (o el local
  /// jugando solo). Ver [TurnTimer].
  TurnTimer turnTimer;

  /// El mundo de la sala (town_loop.md § 11c, protocolo 41): el que eligió
  /// el anfitrión. `null` = sin mundo (Travesía, tests viejos).
  String? worldId;
  String? worldName;

  /// El pueblo del mundo que se ve en la sala (protocolo 44): ampliaciones,
  /// zonas, parcelas, lago y ayudante (farming.md § 10). Inmutable: el
  /// host lo reemplaza.
  TownState town;

  /// Modo de combate elegido por el anfitrión (turn_modes.md § 1);
  /// `null` = el de por defecto según haya uno o varios jugadores.
  CombatMode? combatMode;

  /// El modo que rige la próxima pelea del RPG.
  CombatMode get effectiveCombatMode =>
      combatMode ??
      CombatMode.defaultFor(
          coop: players.values.where((p) => !p.isCompanion).length > 1);

  /// Segundos del turno de un jugador; `null` = sin límite.
  double? get turnLimit => turnTimer.seconds;

  /// Se vota, prepara o juega un Eco.
  bool get inEco => eco != null;

  bool get paused => pausedBy != null;

  /// Piso en el que está el grupo (0 sin misión o en mapas de un piso).
  int get groundFloor => mission?.floor ?? 0;

  /// El loot del piso actual ([groundFloor]): el de otros pisos sigue
  /// guardado pero no se ve ni se levanta hasta volver ahí.
  Iterable<GroundLoot> get groundHere {
    final f = groundFloor;
    return ground.where((g) => g.floor == f);
  }

  /// El loot del piso actual que ve [playerId] (el suyo y el compartido).
  Iterable<GroundLoot> groundFor(String playerId) =>
      groundHere.where((g) => g.visibleTo(playerId));

  Iterable<SessionPlayer> get playerList => players.values;

  double get graceLeft => graceUntil > time ? graceUntil - time : 0;

  /// La barrera del piso actual (escalera o jefe) está abierta.
  bool get gateOpen {
    final m = mission;
    return m != null && m.floorOpen(m.floor);
  }

  /// Tienda, herrería, fusión y equipar (`canShop`).
  bool get canShop =>
      mode == SessionMode.lobby ||
      mode == SessionMode.prep ||
      // Travesía: equipar y el inventario fuera de batalla; comprar y
      // craftear los acota el motor al nodo de tienda / armería.
      (mode == SessionMode.run && run != null && run!.phase != RunPhase.over);

  /// Desarmar o vender (también en lote, "Limpiar inventario"): además
  /// del pueblo, en la aventura fuera de batalla (loot.md § 21).
  bool get canDiscard => canShop || mode == SessionMode.field;

  /// `mustAlloc`: la UI debe obligar a [playerId] a repartir sus puntos.
  bool mustAllocate(String playerId) {
    final p = players[playerId];
    return mode == SessionMode.levelUp &&
        p != null &&
        p.levelUpPending &&
        p.profile.points > 0;
  }

  GameSession copy() => GameSession(
        mode: mode,
        players: LinkedHashMap.fromEntries(
            players.entries.map((e) => MapEntry(e.key, e.value.copy()))),
        mission: mission?.copy(),
        battle: battle?.copy(),
        vote: vote?.copy(),
        prep: prep?.copy(),
        result: result?.copy(),
        time: time,
        graceUntil: graceUntil,
        afterLevelUp: afterLevelUp,
        seq: seq,
        ground: [...ground],
        groundSeq: groundSeq,
        pausedBy: pausedBy,
        pausedName: pausedName,
        eco: eco,
        ecoOwner: ecoOwner,
        atlas: atlas,
        trial: trial,
        turnTimer: turnTimer,
        combatMode: combatMode,
        abyss: abyss,
        abyssOwner: abyssOwner,
        tutorial: tutorial?.copy(),
        tutorialRuns: tutorialRuns,
        run: run?.copy(),
        leaveReady: {...leaveReady},
        lostLoot: [...lostLoot],
        worldId: worldId,
        worldName: worldName,
        town: town,
      );
}
