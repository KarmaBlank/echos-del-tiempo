import 'dart:collection';

import 'battle_state.dart';
import 'item.dart';
import 'loot.dart';
import 'player_profile.dart';

/// Modo de la sesión (`S.mode` del prototipo).
enum SessionMode { lobby, prep, field, battle, levelUp, result }

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
  });

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
      );
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
  });

  final int id;
  final MissionItemKind kind;
  final double x, y;
  bool done;

  MissionItem copy() => MissionItem(id: id, kind: kind, x: x, y: y, done: done);
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
  }) : eliteDrops = eliteDrops ?? [];

  final String missionId;
  final int seed;

  /// Nivel de zona del loot (`LootRules.zoneLevel`, fijado al empezar).
  final int zoneLevel;

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
  });

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

  /// Le toca a un jugador y la sesión espera su `BattleAction`.
  bool get waitingForPlayer {
    final cur = state.current;
    return endTimer == null && wait <= 0 && cur != null && cur.isPlayer;
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
      );
}

/// Votación de misión en el lobby (`S.vote`).
class MissionVote {
  MissionVote(this.missionId, this.proposedBy, Set<String> yes) : yes = {...yes};
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
  });

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
  })  : players = players ?? LinkedHashMap(),
        ground = ground ?? [];

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

  /// Loot en el piso del mapa actual (instanciado por dueño, o
  /// compartido si lo soltó un jugador). Se vacía al cambiar de mapa.
  /// Ver loot.md § 4 y netcode.md § "Loot instanciado".
  final List<GroundLoot> ground;

  /// Contador para ids de [ground].
  int groundSeq;

  /// El loot del piso que ve [playerId] (el suyo y el compartido).
  Iterable<GroundLoot> groundFor(String playerId) =>
      ground.where((g) => g.visibleTo(playerId));

  Iterable<SessionPlayer> get playerList => players.values;

  double get graceLeft => graceUntil > time ? graceUntil - time : 0;

  bool get gateOpen => mission?.open ?? false;

  /// Tienda, herrería, fusión y equipar (`canShop`).
  bool get canShop => mode == SessionMode.lobby || mode == SessionMode.prep;

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
      );
}
