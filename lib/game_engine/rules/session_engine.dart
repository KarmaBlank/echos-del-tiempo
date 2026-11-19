import 'dart:math' as math;

import '../data/ascension_catalog.dart';
import '../data/exploration_catalog.dart';
import '../data/game_catalog.dart';
import '../data/items_catalog.dart';
import '../data/trials_catalog.dart';
import '../data/uniques_catalog.dart';
import '../models/battle_command.dart';
import '../models/battle_event.dart';
import '../models/atlas.dart';
import '../models/battle_state.dart';
import '../models/build_wants.dart';
import '../models/eco.dart';
import '../models/game_map.dart';
import '../models/game_session.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/loot_filter.dart';
import '../models/mission_def.dart';
import '../models/player_profile.dart';
import '../models/session_action.dart';
import '../models/session_event.dart';
import '../models/zone_def.dart';
import '../data/abyss_catalog.dart';
import 'abyss_rules.dart';
import 'atlas_rules.dart';
import 'battle_engine.dart';
import 'eco_rules.dart';
import 'exploration_rules.dart';
import 'inventory_rules.dart';
import 'js_math.dart';
import 'loot_filter_rules.dart';
import 'loot_rules.dart';
import 'map_generator.dart';
import 'mulberry32.dart';
import 'progression_rules.dart';
import 'trial_rules.dart';
import 'tutorial_rules.dart';
import 'companion_ai.dart';
import 'world_rules.dart';
import 'zone_rules.dart';

part 'session_engine_tutorial.dart';

/// Genera la semilla de cada misión (`(Math.random() * 1e9) | 0`).
typedef SeedSource = int Function();

/// Resultado de un paso de la sesión: el estado nuevo y lo que pasó.
class SessionStep {
  final GameSession state;
  final List<SessionEvent> events;
  const SessionStep(this.state, this.events);
}

/// Reglas del host — puerto de `onMsg`, `addPlayer`, `hostTick`,
/// `fieldTick`, `battleTick`, `startMission`, `openChest`, `updateOpen`,
/// `calmEnemies`, `finishBattle`, `missionEnd` y `toLobby` del prototipo.
/// Specs: docs/specs/missions.md, world.md y progression.md.
///
/// Sin estado de juego propio (solo un caché de mapas, que son función
/// pura de la semilla): cada método recibe un [GameSession], trabaja
/// sobre una copia y devuelve un [SessionStep]. Orden de uso:
/// 1. [create] la sala y [addPlayer] por cada jugador que entra.
/// 2. [apply] con cada acción que llega de un jugador (`null` = rechazada).
/// 3. [tick] a ritmo fijo (el prototipo usa 50 ms) para avanzar el mundo,
///    la batalla y las transiciones de modo.
class SessionEngine {
  SessionEngine({
    required this.battles,
    required this.progression,
    RandomSource? random,
    SeedSource? seeds,
    this.groundLoot = false,
    RandomSource? ecoRandom,
    this.devTools = false,
    this.atlasRules = const AtlasRules(),
    RandomSource? abyssRandom,
    TutorialRules? tutorials,
  })  : tutorials = tutorials ?? TutorialRules(catalog: progression.catalog),
        _random = random ?? math.Random().nextDouble,
        _ecoRandom = ecoRandom ?? math.Random().nextDouble,
        _abyssRandom = abyssRandom ?? math.Random().nextDouble,
        _seeds = seeds ?? (() => math.Random().nextInt(1000000000));

  /// Azar propio de los Jefes del Abismo (Fragmentos y recompensas
  /// exclusivas, docs/specs/abyss_bosses.md § 1.1): no mueve ninguna
  /// tirada de antes.
  final RandomSource _abyssRandom;

  /// El TUTORIAL: Ecos de práctica (docs/specs/combat_tutorial.md).
  final TutorialRules tutorials;

  /// Reglas de los Jefes del Abismo.
  AbyssRules get abyssRules => AbyssRules(catalog: catalog);

  /// La pelea de un Jefe del Abismo: el mapa de su zona base, 1 piso.
  GameMap _abyssMap(AbyssBossDef d, int seed) {
    final key = 'abyss:${d.number}:$seed';
    final hit = _maps[key];
    if (hit != null) return hit;
    if (_maps.length > 8) _maps.clear();
    return _maps[key] = MapGenerator.zone(abyssRules.zoneDef(d), seed);
  }

  /// Azar propio de los Ecos (drops de Ecos y Anclas, mods gratis): así
  /// las tiradas de siempre no cambian de orden (ecos_atlas.md § 3).
  final RandomSource _ecoRandom;

  /// Acepta `DevGrantEcoAction` (solo el flavor de desarrollo).
  final bool devTools;
  final AtlasRules atlasRules;

  EcoRules get ecoRules => progression.ecos;

  /// Efectos del Atlas de la sala (el del anfitrión).
  AtlasEffects atlasOf(GameSession s) => atlasRules.effects(s.atlas);

  /// La misión [id] en la sala [s]: la del Eco si es `eco` y hay uno.
  MissionDef? missionOf(GameSession s, String id) {
    if (id == EcoRules.missionId) {
      final eco = s.eco;
      return eco == null ? null : ecoRules.missionDef(eco);
    }
    if (id == TrialRules.missionId) {
      final t = trialDef(s.trial);
      return t == null ? null : trialRules.missionDef(t);
    }
    if (id == AbyssRules.missionId) {
      final d = abyssRules.def(s.abyss);
      return d == null ? null : abyssRules.missionDef(d);
    }
    return catalog.mission(id);
  }

  /// Reglas de las Pruebas del Tiempo (docs/specs/ascension.md § 1).
  TrialRules get trialRules => progression.trials;

  /// La mazmorra de una Prueba: función pura de su número y la semilla.
  GameMap _trialMap(TrialDef t, int seed) {
    final key = 'trial:${t.number}:$seed';
    final hit = _maps[key];
    if (hit != null) return hit;
    if (_maps.length > 8) _maps.clear();
    return _maps[key] = trialRules.map(t, seed);
  }

  /// El anfitrión fija su Atlas para la sala (al crearla y cada vez que
  /// lo cambia en el pueblo). Los nodos inválidos se ignoran al usarlos.
  SessionStep setAtlas(GameSession session, List<String> nodes) {
    final s = session.copy()..atlas = List.unmodifiable(nodes);
    return SessionStep(s, const []);
  }

  /// El anfitrión (o el jugador solo) fija el tiempo de turno de la sala
  /// (docs/specs/accessibility.md § 7): al crearla y cada vez que lo
  /// cambia en CONFIGURACIÓN. Un turno en curso sigue con lo que lleva;
  /// con [TurnTimer.unlimited] nunca se pasa por tiempo.
  SessionStep setTurnTimer(GameSession session, TurnTimer timer) {
    if (session.turnTimer == timer) return SessionStep(session, const []);
    final s = session.copy()..turnTimer = timer;
    return SessionStep(s, const []);
  }

  final BattleEngine battles;
  final ProgressionRules progression;
  final RandomSource _random;
  final SeedSource _seeds;

  /// Loot v2: con `true` el loot cae al piso del mapa (instanciado por
  /// jugador) y se levanta caminando encima o con E (`PickUpAction`).
  /// Con `false` (hoy, hasta que la UI dibuje el loot en el mapa) va
  /// directo al inventario y solo cae al piso si no hay lugar. Ver
  /// loot.md § 4.
  final bool groundLoot;

  GameCatalog get catalog => progression.catalog;

  final _filters = <String?, LootFilter>{};

  /// El filtro de loot de un perfil (texto → filtro, con caché).
  LootFilter filterOf(PlayerProfile p) => _filters.putIfAbsent(
      p.lootFilter,
      // Con el mismo catálogo que la vista previa del editor (`Base`).
      () => LootFilterRules(catalog: catalog).fromProfileText(p.lootFilter));

  /// Cómo ve [p] un drop según su filtro (para la UI y el auto-levantar).
  /// [wants]: el resumen del plan de build de ese jugador (condición
  /// `Build` y la ★); el host usa `SessionPlayer.buildWants`, la UI el
  /// plan local y solo para el jugador local (build_planner.md § 6).
  FilterVerdict lootVerdict(PlayerProfile p, LootDrop d, {BuildWants? wants}) =>
      LootFilterRules(catalog: catalog).evaluate(filterOf(p), d,
          FilterContext(
              level: p.level,
              attributes: p.attributes,
              classId: p.classId,
              wants: wants));

  // ---- constantes del prototipo ----
  static const maxPlayers = 4;

  /// Compañeros de un jugador solo (docs/specs/solo_party.md § 2).
  static const maxCompanions = 3;

  /// Fila detrás del líder: px de camino entre cada miembro, cada cuánto
  /// se anota un punto del rastro y cuántos se guardan (§ 3.5).
  static const followGap = 18.0;
  static const trailStep = 4.0;
  static const trailMax = 96;

  /// Lo que un compañero puede hacer (solo_party.md § 3.2): pelear, su
  /// loot y, desde v0.8.3, todo lo de **su personaje** (puntos, árbol,
  /// ascensión, inventario, tiendas). Cada acción pasa por las mismas
  /// reglas que para el líder. Lo de grupo (moverse, votar, proponer,
  /// interactuar, levantar, pausa, chat, dev) sigue siendo del líder.
  static bool companionAction(SessionAction a) => switch (a) {
        BattleAction() ||
        SetBuildWantsAction() ||
        SetLootFilterAction() ||
        // Personaje.
        AllocateStatsAction() ||
        RespecAction() ||
        ChangeClassAction() ||
        TakeNodeAction() ||
        ResetTreeAction() ||
        ChooseAscensionAction() ||
        TakeAscensionNodeAction() ||
        ResetAscensionAction() ||
        // Inventario y tiendas.
        EquipAction() ||
        MoveInventoryAction() ||
        SortInventoryAction() ||
        CraftAction() ||
        FuseAction() ||
        UpgradeAction() ||
        BuyWeaponAction() ||
        BuyItemAction() ||
        EcoCraftAction() ||
        GiveItemAction() ||
        DropItemAction() =>
          true,
        _ => false,
      };
  static const missionStartGrace = 2.5;
  static const battleGrace = 3.5; // GRACE_MS
  static const leash = 110.0; // LEASH
  static const aggroRange = 64.0;
  static const chaseSpeed = 34.0;
  static const returnSpeed = 36.0;
  static const wanderSpeed = 18.0;
  static const contactRange = 14.0;
  static const bossContactRange = 26.0;
  static const pickupRange = 14.0;

  /// Probabilidad (por jugador) de que el jefe suelte además su legendario
  /// propio (`EnemyDef.legendaryId`; worldgen.md § 8.1).
  static const bossLegendaryChance = 0.10;
  static const sealRange = 30.0;
  static const calmRange = 120.0;

  /// `TURN_LIMIT` del prototipo: el tiempo de turno NORMAL. El de la
  /// sala es `GameSession.turnLimit` ([TurnTimer]).
  static const turnLimit = 30.0; // TURN_LIMIT
  static const resultSeconds = 25.0;

  /// Tocar la escalera de bajada (a menos de esto, px) baja al grupo.
  static const stairsTouch = 10.0;

  /// Distancia para levantar con E (`PickUpAction`).
  static const pickReach = 24.0;

  /// Tope de objetos en el piso (se pierden los más viejos).
  static const maxGround = 80;

  final Map<String, GameMap> _maps = {};

  // ------------------------------------------------------------------
  // API pública
  // ------------------------------------------------------------------

  /// Una sala vacía en el lobby.
  GameSession create() => GameSession();

  /// El mapa donde está la sesión (`mapFor`): el de la misión si hay
  /// una en curso (el atlas de pisos en misiones de zona), si no el mapa
  /// del mundo con el pueblo. Determinístico por semilla.
  GameMap mapFor(GameSession s) {
    final base = _baseMapFor(s);
    // v0.6: PdI usados (salas abiertas, atajos...; worldgen.md § 11.3).
    final m = s.mode == SessionMode.lobby ? null : s.mission;
    final st = ExplorationRules.stateKey(m);
    if (st.isEmpty) return base;
    final hit = _stated[base];
    if (hit != null && hit.$1 == st) return hit.$2;
    final out = ExplorationRules.withState(base, m);
    _stated[base] = (st, out);
    return out;
  }

  /// Último mapa con estado de cada mapa base (caché de [mapFor]).
  final _stated = Expando<(String, GameMap)>('mapa con estado');

  GameMap _baseMapFor(GameSession s) {
    final m = s.mission;
    if (m == null || s.mode == SessionMode.lobby) {
      return MapGenerator.overworld();
    }
    final eco = s.eco;
    if (m.missionId == EcoRules.missionId && eco != null) {
      return _ecoMap(eco);
    }
    final trial = trialDef(s.trial);
    if (m.missionId == TrialRules.missionId && trial != null) {
      return _trialMap(trial, m.seed);
    }
    final abyss = abyssRules.def(s.abyss);
    if (m.missionId == AbyssRules.missionId && abyss != null) {
      return _abyssMap(abyss, m.seed);
    }
    return _missionMap(catalog.mission(m.missionId)!, m.seed);
  }

  /// La mazmorra de un Eco: función pura de su zona, pisos y semilla.
  GameMap _ecoMap(EcoItem eco) {
    final key = 'eco:${eco.zone}:${eco.floors}:${eco.tier}:${eco.seed}';
    final hit = _maps[key];
    if (hit != null) return hit;
    if (_maps.length > 8) _maps.clear();
    return _maps[key] = MapGenerator.zone(ecoRules.zoneDef(eco), eco.seed);
  }

  GameMap _missionMap(MissionDef def, int seed) {
    final key = '${def.id}:$seed';
    final hit = _maps[key];
    if (hit != null) return hit;
    if (_maps.length > 8) _maps.clear();
    return _maps[key] = def.zone == 0
        ? MapGenerator.generate(def, seed)
        : MapGenerator.zone(catalog.zone(def.zone)!, seed);
  }

  /// `addPlayer`: entra un jugador con su perfil (se valida con
  /// `ProgressionRules.normalize`). `null` si la sala está llena o el id
  /// ya existe.
  ///
  /// [tutorialVersion]: la `tutV` de su cuenta (combat_tutorial.md § 2,
  /// llega en el `hello`). Por defecto, vigente: quien llama sin saberla
  /// (tests, herramientas) no queda bloqueado por el sello.
  SessionStep? addPlayer(GameSession session, String id, PlayerProfile profile,
      {int tutorialVersion = kTutorialVersion}) {
    if (session.players.length >= maxPlayers ||
        session.players.containsKey(id)) {
      return null;
    }
    final op = _Op(this, session.copy());
    op.addPlayer(id, profile, tutorialVersion: tutorialVersion);
    return op.result;
  }

  /// La party de un jugador solo se arma o cambia solo en el pueblo, sin
  /// votación ni preparación (solo_party.md § 2.3).
  static bool canChangeParty(GameSession s) =>
      s.mode == SessionMode.lobby && s.vote == null && s.prep == null;

  /// Entra [id] como compañero de [leaderId] (solo_party.md § 3.1).
  /// `null` si la sala está llena, el id existe, el líder no está (o es
  /// un compañero) o no se puede cambiar la party ahora.
  SessionStep? addCompanion(
      GameSession session, String id, PlayerProfile profile,
      {required String leaderId}) {
    final leader = session.players[leaderId];
    if (leader == null ||
        leader.isCompanion ||
        !canChangeParty(session) ||
        session.players.length >= maxPlayers ||
        session.players.containsKey(id) ||
        session.playerList.where((p) => p.leaderId == leaderId).length >=
            maxCompanions) {
      return null;
    }
    final op = _Op(this, session.copy());
    op.addPlayer(id, profile, leaderId: leaderId);
    return op.result;
  }

  /// Saca al compañero [id] (mismo control que [addCompanion]).
  SessionStep? removeCompanion(GameSession session, String id) {
    final p = session.players[id];
    if (p == null || !p.isCompanion || !canChangeParty(session)) return null;
    final op = _Op(this, session.copy());
    op.removePlayer(id);
    return op.result;
  }

  /// [senderId] actúa como [actorId]: él mismo o un compañero suyo
  /// (solo_party.md § 3.2). `null` si no lo controla o no es válida.
  SessionStep? applyFor(GameSession session, String senderId, String actorId,
      SessionAction action) {
    if (actorId == senderId) return apply(session, senderId, action);
    final a = session.players[actorId];
    if (a == null ||
        a.leaderId != senderId ||
        !session.players.containsKey(senderId)) {
      return null;
    }
    return apply(session, actorId, action);
  }

  /// Un jugador se va de la sala. `null` si no estaba.
  SessionStep? removePlayer(GameSession session, String id) {
    if (!session.players.containsKey(id)) return null;
    final op = _Op(this, session.copy());
    op.removePlayer(id);
    return op.result;
  }

  /// `onMsg`: aplica la acción de [playerId]. `null` si no es válida en
  /// este momento (el estado no cambia).
  SessionStep? apply(GameSession session, String playerId, SessionAction action) {
    final actor = session.players[playerId];
    if (actor == null) return null;
    // Un compañero solo pelea y maneja su personaje; el resto es del líder.
    if (actor.isCompanion && !companionAction(action)) return null;
    // Pausada: solo reanudar, chatear y lo que no toca el mundo (filtro de
    // loot, ordenar el inventario). Ver docs/specs/settings.md § "Pausa".
    if (session.paused &&
        action is! PauseAction &&
        action is! ChatAction &&
        action is! SetLootFilterAction &&
        action is! SetBuildWantsAction &&
        action is! MoveInventoryAction &&
        action is! SortInventoryAction &&
        // Menú de pausa del TUTORIAL (combat_tutorial.md § 4.3).
        action is! TutorialControlAction) {
      return null;
    }
    final op = _Op(this, session.copy());
    return op.apply(op.s.players[playerId]!, action) ? op.result : null;
  }

  /// `hostTick`: avanza [dt] segundos. Con la sala pausada no avanza
  /// nada (ni reloj, ni misión, ni campo, ni turnos).
  SessionStep tick(GameSession session, double dt) {
    if (session.paused) return SessionStep(session, const []);
    final op = _Op(this, session.copy());
    op.tick(dt);
    return op.result;
  }

  /// La entrada de un jugador al `BattleEngine` (vida en el campo
  /// redondeada hacia arriba, como la muestra el HUD).
  /// [blessing]: bendición de santuario activa (worldgen.md § 11.4).
  BattlePartyMember partyMember(SessionPlayer p, {BlessingKind? blessing}) {
    final build = ExplorationRules.blessedBuild(
        progression.buildOf(p.profile), blessing);
    return BattlePartyMember(
      id: p.id,
      name: p.name,
      build: build,
      hp: p.hp.ceil(),
      mp: p.mp,
      ult: p.ult,
      potions: p.profile.potions,
      ethers: p.profile.ethers,
    );
  }
}

/// Un paso de la sesión sobre una copia del estado (como `_Turn` en
/// `BattleEngine`).
class _Op {
  _Op(this.e, this.s);

  final SessionEngine e;
  final GameSession s;
  final events = <SessionEvent>[];

  SessionStep get result => SessionStep(s, List.unmodifiable(events));

  ProgressionRules get rules => e.progression;
  GameCatalog get catalog => e.catalog;
  double _rand() => e._random();
  double _ecoRand() => e._ecoRandom();
  EcoRules get ecos => e.ecoRules;

  /// El Eco que se está jugando (`null` fuera de una misión de Eco).
  EcoItem? get _eco =>
      s.mission?.missionId == EcoRules.missionId ? s.eco : null;

  /// La Prueba que se está jugando (`null` fuera de una).
  TrialDef? get _trial => s.mission?.missionId == TrialRules.missionId
      ? trialDef(s.trial)
      : null;

  /// El Jefe del Abismo que se está peleando (`null` fuera de uno).
  AbyssBossDef? get _abyss => s.mission?.missionId == AbyssRules.missionId
      ? e.abyssRules.def(s.abyss)
      : null;
  double _abyssRand() => e._abyssRandom();

  AtlasEffects get _atlas => e.atlasOf(s);
  Iterable<SessionPlayer> get players => s.players.values;

  /// Los humanos (sin compañeros): votan, se preparan y reparten puntos
  /// (solo_party.md § 3.3).
  Iterable<SessionPlayer> get humans => players.where((p) => !p.isCompanion);

  void say(String text) => events.add(SystemMessageEvent(text));

  static double _dist(double ax, double ay, double bx, double by) =>
      WorldRules.distance(ax, ay, bx, by);

  // ---------------- jugadores ----------------

  WorldPoint spawnPos(int i) {
    final map = e.mapFor(s);
    final m = s.mission;
    final f = m == null ? null : map.floor(m.floor);
    return _around(f?.spawn ?? map.spawn, i);
  }

  static WorldPoint _around(WorldPoint sp, int i) =>
      WorldPoint(sp.x + (i % 2) * 14 - 7, sp.y + (i ~/ 2) * 14 - 7);

  /// `stats(p)`: recalcula máximos. Con [gain], la vida y el maná actuales
  /// suben lo que subió el máximo; siempre se recortan al máximo nuevo.
  void refresh(SessionPlayer p, {bool gain = false}) {
    final oh = p.maxHp, om = p.maxMp;
    final d = rules.derivedStats(p.profile);
    p.maxHp = d.maxHp;
    p.maxMp = d.maxMp;
    p.hp = math.min(p.hp, d.maxHp.toDouble());
    p.mp = math.min(p.mp, d.maxMp.toDouble());
    if (gain) {
      p.hp += math.max(0, d.maxHp - oh);
      p.mp += math.max(0, d.maxMp - om);
    }
  }

  void fill(SessionPlayer p) {
    p.hp = p.maxHp.toDouble();
    p.mp = p.maxMp.toDouble();
  }

  void addPlayer(String id, PlayerProfile raw,
      {String? leaderId, int tutorialVersion = kTutorialVersion}) {
    var profile = rules.normalize(raw);
    if (profile.name.isEmpty) profile = profile.copyWith(name: 'Héroe');
    final d = rules.derivedStats(profile);
    final sp = spawnPos(s.players.length);
    final p = SessionPlayer(
      id: id,
      profile: profile,
      x: sp.x,
      y: sp.y,
      hp: d.maxHp.toDouble(),
      mp: d.maxMp.toDouble(),
      maxHp: d.maxHp,
      maxMp: d.maxMp,
      leaderId: leaderId,
      tutorialVersion: tutorialVersion,
    );
    final b = s.battle;
    if (s.mode == SessionMode.battle && b != null) {
      b.state = e.battles.join(b.state, e.partyMember(p, blessing: s.mission?.blessing)).state;
      // En la pelea de práctica nadie cae y nadie trae su build: kit de
      // práctica (combat_tutorial.md § 3).
      if (s.tutorial case final t?) e.tutorials.applyKit(b.state, t, id);
    }
    s.players[id] = p;
    events.add(PlayerJoinedEvent(id));
    say(leaderId == null
        ? '${profile.name} se unió a la sala.'
        : '${profile.name} se unió a la party.');
    if (raw.treeRefunded > 0) {
      // Migración del árbol (passive_tree_v2.md § 6): aviso único.
      say('${profile.name}: el árbol de pasivas cambió; se reinició gratis '
          'y recuperaste ${raw.treeRefunded} '
          'punto${raw.treeRefunded == 1 ? '' : 's'}.');
    }
  }

  void removePlayer(String id) {
    final p = s.players.remove(id)!;
    final b = s.battle;
    if (b != null) b.state = e.battles.leave(b.state, id).state;
    events.add(PlayerLeftEvent(id));
    say(p.isCompanion
        ? '${p.name} dejó la party.'
        : '${p.name} salió de la sala.');
    // Se fue quien abrió el Eco antes de empezar: se cancela (no se
    // consumió nada).
    if (s.ecoOwner == id && s.mission == null) {
      if (s.vote != null || s.prep != null) {
        say('Se canceló el Eco: ${p.name} salió.');
      }
      _clearEcoVote();
    }
    if (s.abyssOwner == id && s.mission == null) {
      if (s.vote != null || s.prep != null) {
        say('Se canceló el Jefe del Abismo: ${p.name} salió.');
      }
      _clearAbyssVote();
    }
  }

  /// Saca la votación / preparación de un Jefe del Abismo (sin consumir).
  void _clearAbyssVote() {
    if (s.vote?.missionId == AbyssRules.missionId) s.vote = null;
    if (s.prep?.missionId == AbyssRules.missionId) {
      s.prep = null;
      if (s.mode == SessionMode.prep) s.mode = SessionMode.lobby;
    }
    s
      ..abyss = null
      ..abyssOwner = null;
  }

  /// Saca la votación / preparación del Eco (sin consumirlo).
  void _clearEcoVote() {
    if (s.vote?.missionId == EcoRules.missionId) s.vote = null;
    if (s.prep?.missionId == EcoRules.missionId) {
      s.prep = null;
      if (s.mode == SessionMode.prep) s.mode = SessionMode.lobby;
    }
    s
      ..eco = null
      ..ecoOwner = null;
  }

  // ---------------- acciones (`onMsg`) ----------------

  bool apply(SessionPlayer p, SessionAction a) {
    switch (a) {
      case MoveAction():
        if (a.epoch != p.epoch ||
            !(s.mode == SessionMode.lobby || s.mode == SessionMode.field) ||
            !p.alive) {
          return false;
        }
        if (a.x.isFinite && a.x != 0) p.x = a.x;
        if (a.y.isFinite && a.y != 0) p.y = a.y;
        p.dir = a.dir > 0 ? 1 : -1;
        p.moving = a.moving;
        return true;

      case ProposeMissionAction():
        final m = catalog.mission(a.missionId);
        if (s.mode != SessionMode.lobby ||
            s.vote != null ||
            m == null ||
            !ZoneRules.canPropose(catalog, p.profile, m.id) ||
            tutorialLocked) {
          return false;
        }
        s.vote = MissionVote(m.id, p.name, {p.id});
        say('${p.name} propone: ${m.name}. ¡Voten!');
        return true;

      case VoteMissionAction():
        final v = s.vote;
        if (s.mode != SessionMode.lobby || v == null) return false;
        if (a.yes) {
          v.yes.add(p.id);
        } else {
          say('${p.name} rechazó la misión.');
          s.vote = null;
          if (v.missionId == EcoRules.missionId) _clearEcoVote();
          if (v.missionId == TrialRules.missionId) s.trial = null;
          if (v.missionId == AbyssRules.missionId) _clearAbyssVote();
        }
        return true;

      case ReadyAction():
        final prep = s.prep;
        if (s.mode != SessionMode.prep || prep == null) return false;
        prep.ready[p.id] = a.ready;
        return true;

      case CancelPrepAction():
        if (s.mode != SessionMode.prep) return false;
        s.prep = null;
        s.mode = SessionMode.lobby;
        say('${p.name} canceló la preparación.');
        _clearEcoVote();
        _clearAbyssVote();
        s.trial = null;
        return true;

      case ActivateSealAction():
        return _activateSeal(p, a.itemId);

      case ChangeClassAction():
        if (s.mode != SessionMode.lobby) return false;
        return _profileChange(p, rules.changeClass(p.profile, a.classId),
            refill: true);

      case RespecAction():
        if (!rules.canRespec(s.mode)) return false;
        // Fuera del lobby / preparación no llena vida y maná.
        return _profileChange(p, rules.resetBuild(p.profile),
            refill: s.canShop);

      case AllocateStatsAction():
        if (s.mode == SessionMode.battle) return false;
        if (!_profileChange(p, rules.allocate(p.profile, a.add), gain: true)) {
          return false;
        }
        if (p.profile.points == 0) p.levelUpPending = false;
        return true;

      case EquipAction():
        if (!s.canShop) return false;
        return _profileChange(p, rules.equip(p.profile, a.weaponId));

      case TakeNodeAction():
        if (s.mode == SessionMode.battle) return false;
        if (!_profileChange(p, rules.takeNode(p.profile, a.nodeId),
            gain: true)) {
          return false;
        }
        final node = rules.treeRules.catalog.nodes[a.nodeId]!;
        if (node.kind == 'k') say('${p.name} tomó la keystone ${node.name}');
        return true;

      case ResetTreeAction():
        if (!rules.canRespec(s.mode)) return false;
        return _profileChange(p, rules.resetTree(p.profile));

      case FuseAction():
        if (!s.canShop) return false;
        final before = p.profile;
        if (!_profileChange(
            p,
            rules.fuse(p.profile, a.baseWeaponId, a.sacrificeWeaponId,
                a.skillId))) {
          return false;
        }
        say('${p.name} fusionó '
            '${rules.weaponDisplayName(before, a.sacrificeWeaponId)} en '
            '${rules.weaponDisplayName(before, a.baseWeaponId)}: hereda '
            '${catalog.skills[a.skillId]!.name}');
        return true;

      case UpgradeAction():
        if (!s.canShop) return false;
        if (!_profileChange(p, rules.upgrade(p.profile, a.weaponId, a.stat))) {
          return false;
        }
        say('${p.name} mejoró ${a.stat.label} de '
            '${rules.weaponDisplayName(p.profile, a.weaponId)}');
        return true;

      case CraftAction():
        return _craft(p, a);

      case GiveItemAction():
        return _give(p, a);

      case DropItemAction():
        return _drop(p, a);

      case PickUpAction():
        return _pickUp(p, a.groundId);

      case MoveInventoryAction():
        return _profileChange(
            p, InventoryRules.move(p.profile, a.from, a.to));

      case SortInventoryAction():
        return _profileChange(p, rules.inventory.sort(p.profile, a.key));

      case SetLootFilterAction():
        final t = a.text;
        if (t != null && t.length > SetLootFilterAction.maxLength) {
          return false;
        }
        p.profile = p.profile.copyWith(lootFilter: t, clearLootFilter: t == null);
        return true;

      case SetBuildWantsAction(:final wants):
        p.buildWants = wants == null || wants.isEmpty ? null : wants;
        return true;

      case BuyItemAction():
        if (!s.canShop) return false;
        return _profileChange(p, rules.buyItem(p.profile, a.item));

      case BuyWeaponAction():
        if (!s.canShop) return false;
        if (!_profileChange(p, rules.buyWeapon(p.profile, a.weaponId))) {
          return false;
        }
        say('${p.name} compró ${catalog.weapons[a.weaponId]!.name}');
        return true;

      case BattleAction():
        return _battleCommand(p, a.command);

      case PauseAction():
        // Pausa de grupo: cualquiera pausa, cualquiera reanuda.
        if (a.paused == s.paused) return false;
        if (a.paused) {
          s.pausedBy = p.id;
          s.pausedName = p.name;
          events.add(PausedEvent(p.id, p.name));
        } else {
          s.pausedBy = null;
          s.pausedName = null;
          events.add(ResumedEvent(p.id, p.name));
        }
        return true;

      case ChatAction():
        // `case 'chat'`: en cualquier modo; el estado no cambia.
        final text = a.text.trim();
        if (text.isEmpty) return false;
        events.add(ChatMessageEvent(
            p.id,
            p.name,
            text.length > ChatAction.maxLength
                ? text.substring(0, ChatAction.maxLength)
                : text));
        return true;

      case BackToLobbyAction():
        if (s.mode != SessionMode.result) return false;
        toLobby();
        return true;

      case UseStairsAction():
        return _useStairs(p, a.down);

      case InteractPoiAction():
        return _interactPoi(p, a.poiId);

      case ProposeEcoAction():
        return !tutorialLocked && _proposeEco(p, a.uid);

      case EcoCraftAction():
        return _ecoCraft(p, a);

      case DevGrantEcoAction():
        if (!e.devTools) return false;
        final eco = ecos.generate(_ecoRand,
            tier: a.tier, rarity: Rarity.raro, atlas: _atlas);
        final next = rules.grant(
            p.profile.copyWith(ecosUnlocked: true), LootDrop.eco(eco));
        if (next == null) return false;
        p.profile = next;
        say('[DEV] ${p.name} recibió ${ecos.fullName(eco)}');
        return true;

      // ---- ascensión (docs/specs/ascension.md) ----
      case ProposeTrialAction():
        return !tutorialLocked && _proposeTrial(p, a.trial);

      case ChooseAscensionAction():
        if (s.mode != SessionMode.lobby &&
            s.mode != SessionMode.prep &&
            s.mode != SessionMode.result) {
          return false;
        }
        if (!_profileChange(
            p, rules.ascensions.choose(p.profile, a.ascensionId),
            gain: true)) {
          return false;
        }
        events.add(AscensionChosenEvent(p.id, a.ascensionId));
        say('¡${p.name} ascendió: ${kAscensions[a.ascensionId]!.name}!');
        return true;

      case TakeAscensionNodeAction():
        if (s.mode == SessionMode.battle) return false;
        if (!_profileChange(p, rules.ascensions.take(p.profile, a.nodeId),
            gain: true)) {
          return false;
        }
        final node = rules.ascensions.of(p.profile)?.node(a.nodeId);
        if (node != null && node.major) {
          say('${p.name} despertó ${node.name}');
        }
        return true;

      case ResetAscensionAction():
        // Reiniciar nodos: como el árbol. Sacar la ascensión: solo pueblo.
        if (!rules.canRespec(s.mode) ||
            (a.full && !s.canShop) ||
            (p.profile.ascension.id == null)) {
          return false;
        }
        if (!a.full && p.profile.ascension.nodes.isEmpty) return false;
        _profileChange(p, rules.ascensions.reset(p.profile, full: a.full));
        if (a.full) say('${p.name} volvió a su clase base.');
        return true;

      case DevGrantTrialAction():
        if (!e.devTools) return false;
        final t = trialDef(a.trial);
        if (t == null) return false;
        var prof = p.profile;
        if (prof.level < t.level) {
          final g = rules.gainXp(
              prof,
              ProgressionRules.totalXpTo(t.level) -
                  ProgressionRules.totalXpTo(prof.level) -
                  prof.xp);
          prof = g.profile;
        }
        for (var n = 1; n <= t.number; n++) {
          prof = e.trialRules.complete(prof, n);
        }
        _profileChange(p, prof, gain: true);
        say('[DEV] ${p.name}: Pruebas hasta la ${t.roman} superadas '
            '(nivel ${prof.level}).');
        return true;

      // ---- Jefes del Abismo v0.8 (abyss_bosses.md) ----
      case ProposeAbyssAction():
        return !tutorialLocked && _proposeAbyss(p, a.boss);

      // TUTORIAL (combat_tutorial.md).
      case StartTutorialAction():
        return startTutorial(p, a);
      case TutorialAckAction():
        return ackTutorial(p);
      case TutorialControlAction():
        return controlTutorial(p, a.op);
      case TutorialChoiceAction():
        return pickTutorial(p, a.choice);

      case DevAbyssAction():
        if (!e.devTools || !s.canShop) return false;
        switch (a.kind) {
          case DevAbyssAction.fragments:
            var prof = p.profile.copyWith(ecosUnlocked: true);
            for (final f in kFragments) {
              prof = prof.copyWith(materials: {
                ...prof.materials,
                f: math.min(CraftMaterial.maxStack, prof.material(f) + 5),
              });
            }
            prof = prof.copyWith(materials: {
              ...prof.materials,
              CraftMaterial.esencia: math.min(CraftMaterial.maxStack,
                  prof.material(CraftMaterial.esencia) + 3),
            });
            _profileChange(p, prof);
            say('[DEV] ${p.name}: +5 de cada Fragmento y +3 Esencias.');
            return true;
          case DevAbyssAction.kills:
            _profileChange(
                p,
                p.profile.copyWith(
                    ecosUnlocked: true,
                    abyssKills: {...p.profile.abyssKills, 1, 2, 3, 4}));
            say('[DEV] ${p.name}: los 4 Jefes del Abismo, vencidos.');
            return true;
        }
        return false;
    }
  }

  // ---------------- Jefes del Abismo (abyss_bosses.md § 1–3) ------------

  /// `ProposeAbyssAction`: en el pueblo, sin votación, con el costo.
  bool _proposeAbyss(SessionPlayer p, int n) {
    final d = e.abyssRules.def(n);
    if (s.mode != SessionMode.lobby ||
        s.vote != null ||
        d == null ||
        e.abyssRules.cannotOpen(p.profile, d) != null) {
      return false;
    }
    s
      ..abyss = n
      ..abyssOwner = p.id
      ..vote = MissionVote(AbyssRules.missionId, p.name, {p.id});
    say('${p.name} abre ${d.name} (${e.abyssRules.costText(d)}). ¡Voten!');
    return true;
  }

  /// Empieza la pelea votada: consume el costo de quien la abrió y entra
  /// directo a la batalla con el jefe (sin mazmorra).
  void _startAbyss() {
    final d = e.abyssRules.def(s.abyss);
    final owner = s.players[s.abyssOwner];
    final paid = d == null || owner == null
        ? null
        : e.abyssRules.consume(owner.profile, d);
    if (d == null || owner == null || paid == null) {
      say('Faltan los Fragmentos: se canceló el Jefe del Abismo.');
      _clearAbyssVote();
      s.mode = SessionMode.lobby;
      return;
    }
    owner.profile = paid;
    final seed = e._seeds();
    final map = e._abyssMap(d, seed);
    final def = e.abyssRules.missionDef(d);
    final sp = map.floors.first.spawn;
    final boss = FieldEnemy(
      id: 0,
      x: sp.x + 24,
      y: sp.y,
      homeX: sp.x + 24,
      homeY: sp.y,
      group: [d.enemyId],
      boss: true,
    );
    s.mission = MissionRun(
      missionId: def.id,
      seed: seed,
      goal: 0,
      objectives: [],
      enemies: [boss],
      items: [],
      open: true,
      zoneLevel: d.level,
      zone: def.zone,
      floors: 1,
      levels: [d.level],
    );
    _enterField(def, seed);
    final first = players.firstOrNull;
    if (first != null) startBattle(boss, first);
  }

  /// Jefe del Abismo vencido: cada jugador recibe su exclusivo (seguro la
  /// primera vez) y sus Esencias, y queda anotado en su perfil; el
  /// evento lo anota en la cuenta de cada uno.
  void _abyssCompleted(AbyssBossDef d) {
    for (final p in players) {
      final drops =
          e.abyssRules.rewards(_abyssRand, d, p.profile, rules.loot);
      p.profile = p.profile
          .copyWith(abyssKills: {...p.profile.abyssKills, d.number});
      _deliver(p, drops, LootSource.mission, p.x, p.y);
    }
    events.add(AbyssDefeatedEvent(d.number, [for (final p in players) p.id]));
    say('¡${d.name} vencido!');
  }

  // ---------------- Pruebas del Tiempo (ascension.md § 1) ----------------

  /// `ProposeTrialAction`: en el pueblo, con el nivel y la anterior.
  bool _proposeTrial(SessionPlayer p, int n) {
    final t = trialDef(n);
    if (s.mode != SessionMode.lobby ||
        s.vote != null ||
        t == null ||
        e.trialRules.cannotPropose(p.profile, n) != null) {
      return false;
    }
    s
      ..trial = n
      ..vote = MissionVote(TrialRules.missionId, p.name, {p.id});
    final boss = catalog.zone(t.bossZone)?.bossName ?? '?';
    say('${p.name} propone la ${t.fullName} (jefe: $boss). ¡Voten!');
    return true;
  }

  /// Empieza la Prueba votada: su mazmorra con trampas.
  void _startTrial() {
    final t = trialDef(s.trial);
    if (t == null) {
      s.mode = SessionMode.lobby;
      return;
    }
    final seed = e._seeds();
    _startZoneMission(e.trialRules.missionDef(t), e.trialRules.zoneDef(t),
        seed: seed, atlasMap: e._trialMap(t, seed));
    say('Cuidado con las púas y los Pulsos del Tiempo (violeta): '
        'cuando brillan te devuelven al inicio del piso.');
  }

  /// Trampas de la Prueba bajo cada jugador (§ 1.1).
  void _traps(GameMap map, MissionRun m) {
    final t = trialDef(s.trial);
    final f = map.floor(m.floor);
    if (t == null || f == null) return;
    final active = TrialRules.pulseActive(s.time);
    var i = 0;
    for (final p in players) {
      if (!p.alive) continue;
      final tx = (p.x / WorldRules.tileSize).floor();
      final ty = (p.y / WorldRules.tileSize).floor();
      if (!map.contains(tx, ty)) continue;
      switch (TrialRules.trapAt(map.tileAt(tx, ty))) {
        case TrapKind.spikes when s.time >= p.spikeReady:
          p.spikeReady = s.time + TrialRules.spikeEvery;
          final dmg = math.min(
              (p.hp - 1).floor(), jsRound(p.maxHp * t.spikeDamage));
          if (dmg <= 0) continue;
          p.hp -= dmg;
          events.add(TrapTriggeredEvent(p.id, TrapKind.spikes, dmg));
        case TrapKind.pulse when active:
          final pos = _around(f.spawn, i++);
          p
            ..x = pos.x
            ..y = pos.y
            ..epoch += 1
            ..moving = false;
          events.add(TrapTriggeredEvent(p.id, TrapKind.pulse, 0));
          say('${p.name} fue devuelto por un Pulso del Tiempo.');
        default:
          break;
      }
    }
  }

  /// Prueba completada: cada jugador que cumple gana sus puntos.
  void _trialCompleted(TrialDef t) {
    final winners = <String>[];
    for (final p in players) {
      if (!e.trialRules.earnsPoints(p.profile, t.number)) continue;
      p.profile = e.trialRules.complete(p.profile, t.number);
      winners.add(p.id);
      say('${p.name} superó la ${t.fullName}: +${TrialRules.points} puntos '
          'de ascensión.');
      if (p.profile.ascension.id == null) {
        say('${p.name}: elegí tu ascensión en la Estatua del Tiempo.');
      }
    }
    events.add(TrialCompletedEvent(t.number, winners));
  }

  // ---------------- Ecos (docs/specs/ecos_atlas.md § 4) ----------------

  /// `ProposeEcoAction`: en el pueblo, con el portal activado y el Eco en
  /// el inventario. No se consume hasta empezar.
  bool _proposeEco(SessionPlayer p, String uid) {
    final eco = p.profile.ecoByUid(uid);
    if (s.mode != SessionMode.lobby ||
        s.vote != null ||
        !p.profile.ecosUnlocked ||
        eco == null) {
      return false;
    }
    s
      ..eco = eco
      ..ecoOwner = p.id
      ..vote = MissionVote(EcoRules.missionId, p.name, {p.id});
    say('${p.name} abre ${ecos.fullName(eco)} (jefe: ${ecos.bossName(eco)}). '
        '¡Voten!');
    return true;
  }

  bool _ecoCraft(SessionPlayer p, EcoCraftAction a) {
    if (!s.canShop) return false;
    // El Eco que se vota o prepara no se toca.
    if (s.ecoOwner == p.id && s.eco?.uid == a.uid) return false;
    final r = ecos.craft(p.profile, a.uid, a.op, _rand);
    if (!_profileChange(p, r.profile)) return false;
    say('${p.name}: ${ecos.fullName(r.after!)} (${_ecoVerb(a.op)})');
    return true;
  }

  static String _ecoVerb(EcoCraftOp op) => switch (op) {
        EcoCraftOp.reroll => 'Esquirla del Eco: modificadores nuevos',
        EcoCraftOp.addMod => 'Cristal de Era: modificador nuevo',
        EcoCraftOp.rarity => 'Prisma Roto: rareza mejorada',
        EcoCraftOp.tier => 'Ancla Temporal: tier +1',
      };

  bool _profileChange(SessionPlayer p, PlayerProfile? next,
      {bool gain = false, bool refill = false}) {
    if (next == null) return false;
    p.profile = next;
    refresh(p, gain: gain);
    if (refill) fill(p);
    return true;
  }

  // ---------------- loot v2: forja, inventario y piso ----------------

  /// El Eco que [p] abrió y todavía se vota / prepara: no se suelta ni
  /// se da.
  bool _ecoLocked(SessionPlayer p, String token) =>
      s.mission == null && s.ecoOwner == p.id && s.eco?.uid == token;

  String _dropText(LootDrop d) {
    final eco = d.eco;
    if (eco != null) {
      return '${ecos.fullName(eco)} (${eco.rarity.label})';
    }
    final it = d.item;
    if (it == null) return '${d.count} ${d.stack!.label}';
    return '${rules.items.displayName(it)} (${it.rarity.label})';
  }

  bool _craft(SessionPlayer p, CraftAction a) {
    if (!(a.op.destroys ? s.canDiscard : s.canShop)) return false;
    final before = p.profile;
    final r = rules.crafting.apply(before, a.op, a.targetUid,
        sourceUid: a.sourceUid,
        index: a.index,
        skillId: a.skillId,
        replaceSkillId: a.replaceSkillId,
        uids: a.uids,
        random: _rand);
    if (!_profileChange(p, r.profile)) return false;
    events.add(CraftedEvent(p.id, a.op, a.targetUid));
    final after = r.after;
    if (after != null) {
      say('${p.name}: ${rules.items.displayName(after)} '
          '(${_craftVerb(a.op)})');
    }
    return true;
  }

  static String _craftVerb(CraftOp op) => switch (op) {
        CraftOp.transferAffix => 'afijo trasladado',
        CraftOp.transferPassive => 'pasiva trasladada',
        CraftOp.transferSkill => 'habilidad trasladada',
        CraftOp.removeAffix => 'afijo quitado',
        CraftOp.addAffix => 'Cristal de Era: afijo nuevo',
        CraftOp.reroll => 'Esquirla del Eco: valores nuevos',
        CraftOp.upgradeRarity => 'Prisma Roto: rareza mejorada',
        CraftOp.reforge => 'base reforjada',
        CraftOp.essence => 'Esencia del Abismo: mods fijos mejorados',
        _ => 'desarmada / vendida', // destruyen: sin `after`, no se anuncia
      };

  /// `GiveItemAction`: fuera de batalla, a otro jugador de la sala con
  /// lugar. El host valida todo; si no se puede, nada cambia.
  bool _give(SessionPlayer p, GiveItemAction a) {
    if (s.mode == SessionMode.battle) return false;
    final to = s.players[a.toPlayerId];
    if (to == null || to.id == p.id || _ecoLocked(p, a.token)) return false;
    final t = rules.inventory.take(p.profile, a.token, count: a.count);
    final drop = t.drop;
    if (drop == null) return false;
    final got = rules.grant(to.profile, drop);
    if (got == null) return false;
    _profileChange(p, t.profile);
    _profileChange(to, got);
    events.add(ItemGivenEvent(p.id, to.id, drop));
    say('${p.name} le dio ${_dropText(drop)} a ${to.name}');
    return true;
  }

  bool get _onMap =>
      s.mode == SessionMode.lobby || s.mode == SessionMode.field;

  /// `DropItemAction`: al piso, compartido, donde está el jugador.
  bool _drop(SessionPlayer p, DropItemAction a) {
    if (!_onMap || !p.alive || _ecoLocked(p, a.token)) return false;
    final t = rules.inventory.take(p.profile, a.token, count: a.count);
    final drop = t.drop;
    if (drop == null) return false;
    _profileChange(p, t.profile);
    _toGround(drop, p.x, p.y);
    say('${p.name} soltó ${_dropText(drop)}');
    return true;
  }

  /// `PickUpAction` (E): propio o compartido, del piso actual, cerca y
  /// con lugar.
  bool _pickUp(SessionPlayer p, int groundId) {
    if (!_onMap || !p.alive) return false;
    final g = s.groundHere.where((x) => x.id == groundId).firstOrNull;
    if (g == null ||
        !g.visibleTo(p.id) ||
        _dist(p.x, p.y, g.x, g.y) > SessionEngine.pickReach) {
      return false;
    }
    return _take(p, g);
  }

  /// Loot propio: como `grant`, pero un material con la pila al tope se
  /// toma igual y lo que sobra se descarta (loot.md § 14.2), así no
  /// quedan pilas imposibles de levantar en el piso.
  PlayerProfile? _grantLoot(PlayerProfile p, LootDrop d) {
    final next = rules.grant(p, d);
    if (next != null) return next;
    final st = d.stack;
    if (st == null || st.material == null) return null;
    final max = InventoryRules.stackMax(st);
    final have = InventoryRules.stackCount(p, st);
    return have >= max ? p : InventoryRules.withStack(p, st, max);
  }

  bool _take(SessionPlayer p, GroundLoot g) {
    // Lo que otro soltó (compartido) no se descarta: si no entra, queda.
    final next = g.ownerId == p.id
        ? _grantLoot(p.profile, g.drop)
        : rules.grant(p.profile, g.drop);
    if (next == null) return false;
    _profileChange(p, next);
    s.ground.remove(g);
    events.add(LootPickedEvent(p.id, g.id, g.drop));
    return true;
  }

  /// Deja [d] en el piso actual cerca de ([x], [y]); [owner] = loot
  /// instanciado.
  GroundLoot _toGround(LootDrop d, double x, double y, {String? owner}) {
    final id = ++s.groundSeq;
    // Desparramado en espiral, sin azar (determinístico).
    final ang = id * 2.4;
    final r = 6.0 + (id % 3) * 4;
    final g = GroundLoot(
      id: id,
      drop: d,
      x: x + math.cos(ang) * r,
      y: y + math.sin(ang) * r,
      ownerId: owner,
      floor: s.groundFloor,
    );
    s.ground.add(g);
    if (s.ground.length > SessionEngine.maxGround) s.ground.removeAt(0);
    return g;
  }

  /// Entrega el loot de [p] (instanciado). Con `groundLoot` todo cae al
  /// piso; sin él va al inventario lo que su filtro muestra (lo oculto
  /// queda en el piso, invisible, y se pierde al cambiar de mapa) y lo
  /// que no entra cae al piso. El de fin de misión va siempre al
  /// inventario (el mapa se cierra). Un mensaje por jugador con lo visible.
  void _deliver(SessionPlayer p, List<LootDrop> drops, LootSource src,
      double x, double y) {
    if (drops.isEmpty) return;
    var full = false;
    final capped = <String>{};
    final shown = <LootDrop>[];
    for (final d in drops) {
      final mission = src == LootSource.mission;
      final visible = mission ||
          e.lootVerdict(p.profile, d, wants: p.buildWants).visible;
      if (visible) shown.add(d);
      // Material con la pila llena: nunca al piso (loot.md § 14.2).
      final st = d.stack;
      final atCap = st?.material != null && rules.grant(p.profile, d) == null;
      if (atCap && !visible) continue; // oculto por el filtro: se descarta
      if (atCap) capped.add(st!.label);
      // Un compañero no camina el piso: lo suyo va directo al inventario
      // (solo_party.md § 3.6).
      if (((!e.groundLoot || mission || p.isCompanion) && visible) || atCap) {
        final next = _grantLoot(p.profile, d);
        if (next != null) {
          p.profile = next;
          events.add(LootDropEvent(p.id, d, src,
              uid: d.isItem
                  ? next.items.last.uid
                  : d.isEco
                      ? next.ecos.last.uid
                      : null));
          continue;
        }
        full = true;
      }
      final g = _toGround(d, x, y, owner: p.id);
      events.add(LootDropEvent(p.id, d, src, groundId: g.id));
    }
    if (shown.isEmpty) return;
    say('${p.name} obtuvo: ${shown.map(_dropText).join(', ')}'
        '${full ? ' (inventario lleno: quedó en el piso)' : ''}'
        '${capped.isEmpty ? '' : ' (${capped.join(', ')} al tope de '
            '${CraftMaterial.maxStack}: lo que sobra se descarta)'}');
  }

  /// Tira y entrega el loot de [src] a cada jugador (loot por jugador),
  /// en ([x], [y]) o, sin posición, donde está cada uno. Devuelve la
  /// primera arma de cada uno (para los resultados).
  Map<String, LootDrop> _lootAll(LootSource src, double? x, double? y,
      {double? chance, double extraBonus = 0, int? level}) {
    final firsts = <String, LootDrop>{};
    final zone = level ?? s.mission?.zoneLevel ?? 1;
    for (final p in players) {
      final drops = _rollFor(p, src, zone, chance: chance, extraBonus: extraBonus);
      final w = drops.where((d) => d.isItem).firstOrNull;
      if (w != null) firsts[p.id] = w;
      _deliver(p, drops, src, x ?? p.x, y ?? p.y);
    }
    return firsts;
  }

  /// Las tiradas de loot de [p] para [src] a nivel [zone]. Dentro de un
  /// Eco cada tirada se repite según la cantidad y suma la rareza de los
  /// mods y del Atlas (ecos_atlas.md § 2.2); desde nivel 45 pueden caer
  /// Ecos (§ 3).
  List<LootDrop> _rollFor(SessionPlayer p, LootSource src, int zone,
      {double? chance, double extraBonus = 0}) {
    final eco = _eco;
    final atlas = _atlas;
    final bonus = eco == null
        ? null
        : EcoRules.lootBonus(eco, atlas: atlas, players: s.players.length);
    final drops = <LootDrop>[];
    var repeats =
        bonus == null ? 1 : EcoRules.rollRepeats(_rand, bonus.quantity);
    // Bendición de Fortuna (worldgen.md § 11.4).
    final fortune = s.mission?.blessing == BlessingKind.fortuna;
    if (fortune && _rand() < kFortuneExtraRoll) repeats++;
    for (var i = 0; i < repeats; i++) {
      drops.addAll(rules.loot.rollDrops(_rand,
          zoneLevel: zone,
          source: src,
          family: p.profile.classId,
          chance: chance,
          extraBonus: extraBonus +
              (bonus?.rarity ?? 0) +
              (fortune ? kFortuneRarity : 0),
          legendaryMult: eco == null ? 1 : 1 + atlas.legendary,
          levelCap: _lootCap()));
    }
    if (eco != null) drops.addAll(_ecoExtras(p, src, zone, bonus!, atlas));
    // Fragmentos del Abismo: Ecos de tier 10+ (abyss_bosses.md § 1.1).
    if (eco != null) {
      final f = e.abyssRules.rollFragment(_abyssRand, eco, src);
      if (f != null) drops.add(LootDrop.stack(StackKind.of(f), 1));
    }
    final ecoDrop = ecos.rollDrop(_ecoRand,
        level: zone, source: src, current: eco, atlas: atlas);
    if (ecoDrop != null) drops.add(LootDrop.eco(ecoDrop));
    return drops;
  }

  /// Lo extra de una fuente dentro de un Eco: armas del Atlas (Trofeo,
  /// Élites Codiciosas), Eco del Jefe y Ancla Temporal.
  List<LootDrop> _ecoExtras(SessionPlayer p, LootSource src, int zone,
      EcoBonus bonus, AtlasEffects atlas) {
    final out = <LootDrop>[];
    final weapons = switch (src) {
      LootSource.boss => atlas.bossWeapons,
      LootSource.elite => atlas.eliteWeapons,
      _ => 0,
    };
    for (var i = 0; i < weapons; i++) {
      out.add(LootDrop.item(rules.loot.generate(_rand,
          itemLevel: LootRules.itemLevelFor(zone, src, cap: _lootCap()),
          family: p.profile.classId,
          source: src,
          extraBonus: bonus.rarity,
          legendaryMult: 1 + atlas.legendary)));
    }
    if (src == LootSource.boss) {
      for (var i = 0; i < atlas.bossEcos; i++) {
        out.add(LootDrop.eco(ecos.generate(_ecoRand,
            tier: EcoRules.dropTier(_ecoRand, _eco),
            source: src,
            atlas: atlas)));
      }
    }
    if (EcoRules.rollAnchor(_ecoRand, src, atlas: atlas)) {
      out.add(const LootDrop.stack(StackKind.ancla, 1));
    }
    return out;
  }

  /// El legendario propio del jefe de [b] (si tiene): a cada jugador con
  /// `SessionEngine.bossLegendaryChance`, al nivel de la batalla.
  void _bossLegendary(SessionBattle b, double x, double y, int? level) {
    final type = b.state.enemies.firstOrNull?.enemyType;
    final id = type == null ? null : catalog.enemies[type]?.legendaryId;
    final u = id == null ? null : kUniques[id];
    if (u == null || !catalog.weapons.containsKey(u.baseId)) return;
    final cap = _lootCap();
    final lv = level ?? s.mission?.zoneLevel ?? 1;
    final il = cap == null ? lv : math.min(lv, cap);
    final chance = SessionEngine.bossLegendaryChance +
        (_eco == null ? 0 : _atlas.bossUnique);
    for (final p in players) {
      if (_rand() >= chance) continue;
      final item = rules.loot.generateUnique(_rand, u, il);
      _deliver(p, [LootDrop.item(item)], LootSource.boss, x, y);
    }
  }

  /// Auto-levantar: cada jugador levanta su loot (no el compartido) al
  /// pasar encima, si su filtro lo muestra y tiene lugar (solo el del
  /// piso actual).
  void _autoPickup() {
    if (s.ground.isEmpty) return;
    for (final g in [...s.groundHere]) {
      final owner = g.ownerId == null ? null : s.players[g.ownerId];
      // Lo de un compañero lo levanta también su líder al pasar.
      final lead = owner?.leaderId == null ? null : s.players[owner!.leaderId];
      if (owner == null ||
          !owner.alive ||
          (_dist(owner.x, owner.y, g.x, g.y) >= SessionEngine.pickupRange &&
              (lead == null ||
                  _dist(lead.x, lead.y, g.x, g.y) >=
                      SessionEngine.pickupRange)) ||
          !e.lootVerdict(owner.profile, g.drop, wants: owner.buildWants)
              .visible) {
        continue;
      }
      _take(owner, g);
    }
  }

  bool _activateSeal(SessionPlayer p, int itemId) {
    final m = s.mission;
    if (s.mode != SessionMode.field || m == null) return false;
    final it = m.items
        .where((i) => i.id == itemId && i.kind == MissionItemKind.seal)
        .firstOrNull;
    if (it == null ||
        it.done ||
        _dist(p.x, p.y, it.x, it.y) >= SessionEngine.sealRange) {
      return false;
    }
    it.done = true;
    final o = _bump(ObjectiveKind.seals);
    say('${p.name} activó un sello (${o?.count ?? 0}/2)');
    updateOpen();
    return true;
  }

  // ---------------- pisos (worldgen.md § 6.7) ----------------

  bool _useStairs(SessionPlayer p, bool down) {
    final m = s.mission;
    if (s.mode != SessionMode.field || m == null || !p.alive) return false;
    final f = e.mapFor(s).floor(m.floor);
    final at = f == null ? null : (down ? f.stairsDown : f.stairsUp);
    if (at == null ||
        _dist(p.x, p.y, at.x, at.y) >= WorldRules.stairsRange) {
      return false;
    }
    changeFloor(m.floor + (down ? 1 : -1), down: down);
    return true;
  }

  /// Todo el grupo pasa al piso [to].
  void changeFloor(int to, {required bool down}) {
    final m = s.mission!;
    final f = e.mapFor(s).floor(to);
    if (f == null) return;
    final from = m.floor;
    final left = _unclaimedHere();
    m.floor = to;
    if (to < m.levels.length) m.zoneLevel = m.levels[to];
    final base = down ? f.spawn : (f.returnPoint ?? f.spawn);
    var i = 0;
    for (final p in players) {
      final pos = _around(base, i++);
      p
        ..x = pos.x
        ..y = pos.y
        ..epoch += 1
        ..moving = false;
      if (p.hp <= 0) p.hp = 1;
    }
    s.graceUntil = s.time + SessionEngine.missionStartGrace;
    events.add(FloorChangedEvent(to, down: down));
    final verb = down ? 'Bajaron' : 'Subieron';
    final boss = to == m.floors - 1 ? ' El jefe espera tras la barrera.' : '';
    say('$verb al piso ${to + 1}/${m.floors}.$boss');
    // El loot no viaja: queda en su piso (loot.md § 14.1). Aviso por
    // jugador de lo que su filtro muestra y dejó atrás.
    final solo = s.players.length == 1;
    for (final MapEntry(key: p, value: n) in left.entries) {
      final what = n == 1 ? 'Queda 1 objeto' : 'Quedan $n objetos';
      final whose = solo ? '' : ' de $p';
      say('$what$whose en el piso ${from + 1}.');
    }
    // Misión opcional `guardian`: bajar con la élite viva la falla.
    if (down) _guardianEscaped(from);
  }

  /// Por jugador (nombre): cuánto loot del piso actual que ve (suyo o
  /// compartido) muestra su filtro. Solo los que tienen algo.
  Map<String, int> _unclaimedHere() {
    final out = <String, int>{};
    if (s.ground.isEmpty) return out;
    for (final p in players) {
      final n = s
          .groundFor(p.id)
          .where((g) =>
              e.lootVerdict(p.profile, g.drop, wants: p.buildWants).visible)
          .length;
      if (n > 0) out[p.name] = n;
    }
    return out;
  }

  /// Nivel tope del loot de la misión actual (combo_balance.md § 2): el
  /// nivel máximo de su zona (o el del Abismo). `null` = sin zona.
  int? _lootCap() {
    final abyss = _abyss;
    if (abyss != null) return abyss.level;
    return _zoneDef()?.maxLevel;
  }

  ZoneDef? _zoneDef() {
    final m = s.mission;
    final eco = _eco;
    final trial = _trial;
    return eco != null
        ? ecos.zoneDef(eco)
        : trial != null
            ? e.trialRules.zoneDef(trial)
            : m == null || m.zone == 0
                ? null
                : catalog.zone(m.zone);
  }

  /// Nivel de los enemigos de [en] (0 = misión sin zona).
  int _levelFor(FieldEnemy en) {
    final abyss = _abyss;
    if (abyss != null) return abyss.level;
    final z = _zoneDef();
    if (z == null) return 0;
    if (en.boss) return ZoneRules.bossLevel(z);
    if (en.elite) return ZoneRules.eliteLevel(z, en.floor);
    return ZoneRules.floorLevel(z, en.floor);
  }

  MissionObjective? _bump(ObjectiveKind k) {
    final o = s.mission?.objective(k);
    if (o != null) {
      o.count++;
      events.add(ObjectiveProgressEvent(k, o.count, o.goal));
    }
    return o;
  }

  // ---------------- tick (`hostTick`) ----------------

  void tick(double dt) {
    s.time += dt;
    final m = s.mission;
    if (m != null &&
        (s.mode == SessionMode.field || s.mode == SessionMode.battle)) {
      m.elapsed += dt;
    }
    switch (s.mode) {
      case SessionMode.field:
        fieldTick(dt);
      case SessionMode.battle:
        if (s.tutorial != null) {
          tutorialTick(dt);
        } else {
          battleTick(dt);
        }
      case SessionMode.result:
        final r = s.result!;
        r.timeLeft -= dt;
        if (r.timeLeft <= 0) toLobby();
      case SessionMode.lobby:
        final v = s.vote;
        _followLeaders();
        if (v != null &&
            humans.isNotEmpty &&
            humans.every((p) => v.yes.contains(p.id))) {
          s.prep = MissionPrep(v.missionId);
          s.vote = null;
          s.mode = SessionMode.prep;
          say('¡Misión aceptada! Fase de preparación: compren, mejoren y '
              'equípense. Empieza cuando todos estén listos.');
        }
      case SessionMode.prep:
        final prep = s.prep!;
        if (humans.isNotEmpty &&
            humans.every((p) => prep.ready[p.id] ?? false)) {
          s.prep = null;
          startMission(prep.missionId);
        }
      case SessionMode.levelUp:
        if (humans
            .every((p) => !p.levelUpPending || p.profile.points <= 0)) {
          for (final p in players) {
            p.levelUpPending = false;
          }
          if (s.afterLevelUp == AfterLevelUp.result) {
            missionEnd(true);
          } else {
            _backToField();
          }
        }
    }
  }

  void _backToField() {
    s.mode = SessionMode.field;
    s.graceUntil = s.time + SessionEngine.battleGrace;
    calmEnemies();
  }

  // ---------------- misiones ----------------

  void startMission(String missionId) {
    s.vote = null;
    if (missionId == EcoRules.missionId) {
      _startEco();
      return;
    }
    if (missionId == TrialRules.missionId) {
      _startTrial();
      return;
    }
    if (missionId == AbyssRules.missionId) {
      _startAbyss();
      return;
    }
    final m = catalog.mission(missionId);
    if (m == null) return;
    final z = m.zone == 0 ? null : catalog.zone(m.zone);
    if (z != null) {
      _startZoneMission(m, z);
      return;
    }
    final seed = e._seeds();
    final map = e._missionMap(m, seed);
    final r = mulberry32(seed + 7);
    int pick(int n) => (r() * n).floor();
    bool solid(int tx, int ty) => WorldRules.isSolid(map, tx, ty);
    final spots = map.spots;

    final enemies = <FieldEnemy>[];
    var id = 0;
    for (var i = 0; i < m.goal + 9; i++) {
      for (var tries = 0; tries < 90; tries++) {
        if (spots.isEmpty) break;
        final (tx, ty) = spots[pick(spots.length)];
        final x = tx * 16 + 8.0, y = ty * 16 + 8.0;
        final minD = tries < 40
            ? 96
            : tries < 70
                ? 64
                : 40;
        if (!solid(tx, ty) &&
            !solid(tx, ty + 1) &&
            !solid(tx + 1, ty) &&
            !solid(tx - 1, ty) &&
            !enemies.any((o) => _dist(o.x, o.y, x, y) < minD)) {
          enemies.add(FieldEnemy(
            id: id++,
            x: x,
            y: y,
            homeX: x,
            homeY: y,
            group: m.groups[pick(m.groups.length)],
          ));
          break;
        }
      }
    }
    final goal = math.min(m.goal, enemies.length);
    final boss = map.boss!;
    enemies.add(FieldEnemy(
      id: id++,
      x: boss.x,
      y: boss.y,
      homeX: boss.x,
      homeY: boss.y,
      group: m.boss,
      boss: true,
    ));

    final pool = ['frag', 'seal', 'elite'];
    final extras = <String>[];
    while (extras.length < m.extra) {
      extras.add(pool.removeAt(pick(pool.length)));
    }

    final items = <MissionItem>[];
    final sp = map.spawn;
    WorldPoint freeSpot(double minD) {
      for (var t = 0; t < 200; t++) {
        final (tx, ty) = spots[pick(spots.length)];
        final x = tx * 16 + 8.0, y = ty * 16 + 8.0;
        if (solid(tx, ty) || _dist(x, y, sp.x, sp.y) < 120) continue;
        if (items.any((it) => _dist(it.x, it.y, x, y) < minD) ||
            enemies.any((o) => _dist(o.x, o.y, x, y) < 40)) {
          continue;
        }
        return WorldPoint(x, y);
      }
      final (tx, ty) = spots[pick(spots.length)];
      return WorldPoint(tx * 16 + 8.0, ty * 16 + 8.0);
    }

    var iid = 0;
    void place(MissionItemKind k, int n, double minD) {
      for (var i = 0; i < n; i++) {
        final q = freeSpot(minD);
        items.add(MissionItem(id: iid++, kind: k, x: q.x, y: q.y));
      }
    }

    final objectives = [MissionObjective(ObjectiveKind.kills, goal)];
    if (extras.contains('frag')) {
      place(MissionItemKind.fragment, 3, 90);
      objectives.add(MissionObjective(ObjectiveKind.fragments, 3));
    }
    if (extras.contains('seal')) {
      place(MissionItemKind.seal, 2, 140);
      objectives.add(MissionObjective(ObjectiveKind.seals, 2));
    }
    final nElite = extras.contains('elite') ? 2 : 1;
    for (var i = 0; i < nElite; i++) {
      final q = freeSpot(80);
      enemies.add(FieldEnemy(
        id: id++,
        x: q.x,
        y: q.y,
        homeX: q.x,
        homeY: q.y,
        group: [m.elite, m.groups[pick(m.groups.length)].first],
        elite: true,
      ));
    }
    if (extras.contains('elite')) {
      objectives.add(MissionObjective(ObjectiveKind.elite, 1));
    }
    place(MissionItemKind.chest, 2 + pick(3), 70);

    s.mission = MissionRun(
      missionId: m.id,
      seed: seed,
      goal: goal,
      objectives: objectives,
      enemies: enemies,
      items: items,
      zoneLevel: LootRules.zoneLevel(m, [for (final p in players) p.profile.level]),
    );
    _enterField(m, seed);
  }

  /// `startMission` de una misión de zona: todos los pisos del atlas se
  /// pueblan al empezar (worldgen.md § 6.7).
  void _startZoneMission(MissionDef m, ZoneDef z,
      {int? seed, GameMap? atlasMap, int extraChests = 0}) {
    seed ??= e._seeds();
    final map = atlasMap ?? e._missionMap(m, seed);
    final r = mulberry32(seed + 7);
    int pick(int n) => (r() * n).floor();
    bool solid(int tx, int ty) =>
        WorldRules.isSolid(map, tx, ty, blockVoid: true);
    List<String> res(List<String> g) => ZoneRules.resolveGroup(g, catalog);
    WorldPoint px((int, int) t) => WorldPoint(t.$1 * 16 + 8.0, t.$2 * 16 + 8.0);

    final enemies = <FieldEnemy>[];
    final goals = <int>[];
    var id = 0;
    for (final fl in map.floors) {
      final spots = fl.spots;
      final groups = m.groupsFor(fl.index);
      var placed = 0;
      for (var i = 0; i < m.floorGoal + 3; i++) {
        for (var tries = 0; tries < 90; tries++) {
          if (spots.isEmpty) break;
          final (tx, ty) = spots[pick(spots.length)];
          final x = tx * 16 + 8.0, y = ty * 16 + 8.0;
          final minD = tries < 40
              ? 96
              : tries < 70
                  ? 64
                  : 40;
          if (!solid(tx, ty) &&
              !solid(tx, ty + 1) &&
              !solid(tx + 1, ty) &&
              !solid(tx - 1, ty) &&
              !enemies.any((o) => _dist(o.x, o.y, x, y) < minD)) {
            enemies.add(FieldEnemy(
              id: id++,
              x: x,
              y: y,
              homeX: x,
              homeY: y,
              group: res(groups[pick(groups.length)]),
              floor: fl.index,
            ));
            placed++;
            break;
          }
        }
      }
      goals.add(math.min(m.floorGoal, placed));
    }
    final last = map.floors.last;
    final boss = last.boss!;
    enemies.add(FieldEnemy(
      id: id++,
      x: boss.x,
      y: boss.y,
      homeX: boss.x,
      homeY: boss.y,
      group: res(m.boss),
      boss: true,
      floor: last.index,
    ));

    final pool = ['frag', 'seal', 'elite'];
    final extras = <String>[];
    while (extras.length < m.extra) {
      extras.add(pool.removeAt(pick(pool.length)));
    }

    final items = <MissionItem>[];
    WorldPoint freeSpot(MapFloor fl, double minD) {
      final spots =
          fl.spots.isEmpty ? [(fl.bounds.cx, fl.bounds.cy)] : fl.spots;
      final sp = fl.spawn;
      for (var t = 0; t < 200; t++) {
        final q = px(spots[pick(spots.length)]);
        if (solid((q.x / 16).floor(), (q.y / 16).floor()) ||
            _dist(q.x, q.y, sp.x, sp.y) < 120) {
          continue;
        }
        if (items.any((it) => _dist(it.x, it.y, q.x, q.y) < minD) ||
            enemies.any((o) => _dist(o.x, o.y, q.x, q.y) < 40)) {
          continue;
        }
        return q;
      }
      return px(spots[pick(spots.length)]);
    }

    var iid = 0;
    void place(MissionItemKind k, int n, double minD) {
      for (var i = 0; i < n; i++) {
        final fl = map.floors[i % map.floors.length];
        final q = freeSpot(fl, minD);
        items.add(
            MissionItem(id: iid++, kind: k, x: q.x, y: q.y, floor: fl.index));
      }
    }

    final goal = goals.fold(0, (a, b) => a + b);
    final objectives = [MissionObjective(ObjectiveKind.kills, goal)];
    if (extras.contains('frag')) {
      place(MissionItemKind.fragment, 3, 90);
      objectives.add(MissionObjective(ObjectiveKind.fragments, 3));
    }
    if (extras.contains('seal')) {
      place(MissionItemKind.seal, 2, 140);
      objectives.add(MissionObjective(ObjectiveKind.seals, 2));
    }
    // Élites: uno opcional por piso (en la marca `e` de un vault si hay)
    // y otro en el último piso si salió el objetivo `elite`.
    FieldEnemy elite(MapFloor fl, int mark) {
      final q = mark < fl.eliteMarks.length
          ? px(fl.eliteMarks[mark])
          : freeSpot(fl, 80);
      final groups = m.groupsFor(fl.index);
      final en = FieldEnemy(
        id: id++,
        x: q.x,
        y: q.y,
        homeX: q.x,
        homeY: q.y,
        group: res([m.elite, groups[pick(groups.length)].first]),
        elite: true,
        floor: fl.index,
      );
      enemies.add(en);
      return en;
    }

    final guards = [for (final fl in map.floors) elite(fl, 0)];
    if (extras.contains('elite')) {
      elite(last, 1);
      objectives.add(MissionObjective(ObjectiveKind.elite, 1));
    }
    // Zonas C (combo_balance.md § 1): más élites, 1 de cada `eliteEveryC`
    // grupos. Azar propio para no mover las tiradas de siempre; no
    // reemplaza comunes (el objetivo de bajas no cambia).
    final curve = catalog.curve;
    final er = mulberry32(seed + 29);
    for (final fl in map.floors) {
      if (m.elite.isEmpty ||
          !curve.isZoneC(ZoneRules.floorLevel(z, fl.index))) {
        continue;
      }
      final commons = enemies
          .where((x) => x.floor == fl.index && !x.elite && !x.boss)
          .length;
      final have =
          enemies.where((x) => x.floor == fl.index && x.elite).length;
      final want = curve.eliteEveryC <= 1
          ? commons
          : (commons / (curve.eliteEveryC - 1)).ceil();
      final spots = fl.spots;
      if (spots.isEmpty) continue;
      final groups = m.groupsFor(fl.index);
      for (var k = have; k < want; k++) {
        WorldPoint? q;
        for (var t = 0; t < 120 && q == null; t++) {
          final c = px(spots[(er() * spots.length).floor() % spots.length]);
          if (solid((c.x / 16).floor(), (c.y / 16).floor()) ||
              _dist(c.x, c.y, fl.spawn.x, fl.spawn.y) < 120 ||
              enemies.any((o) => _dist(o.x, o.y, c.x, c.y) < 64)) {
            continue;
          }
          q = c;
        }
        if (q == null) break;
        enemies.add(FieldEnemy(
          id: id++,
          x: q.x,
          y: q.y,
          homeX: q.x,
          homeY: q.y,
          group: res([
            m.elite,
            groups[(er() * groups.length).floor() % groups.length].first,
          ]),
          elite: true,
          floor: fl.index,
        ));
      }
    }
    // Cofres (worldgen.md § 11.2 y § 11.5, loot.md § 23): calidad con
    // su propio azar para no mover las tiradas de siempre.
    final cr = mulberry32(seed + 13);
    ChestTier tierRoll() {
      final total =
          kChestTiers.values.fold(0.0, (a, d) => a + d.weight);
      var x = cr() * total;
      for (final d in kChestTiers.values) {
        x -= d.weight;
        if (x < 0) return d.tier;
      }
      return ChestTier.madera;
    }

    void chest(MapFloor fl, WorldPoint q,
        {ChestTier tier = ChestTier.madera, int? guard, int? secret}) {
      items.add(MissionItem(
          id: iid++,
          kind: MissionItemKind.chest,
          x: q.x,
          y: q.y,
          floor: fl.index,
          tier: tier,
          guard: guard,
          secret: secret));
    }

    for (final fl in map.floors) {
      final g = guards[fl.index];
      final gt = (
        (g.homeX / 16).floor(),
        (g.homeY / 16).floor(),
      );
      final gv = fl.eliteMarks.isEmpty
          ? null
          : fl.vaults
              .where((v) =>
                  gt.$1 >= v.x &&
                  gt.$2 >= v.y &&
                  gt.$1 < v.x + v.w &&
                  gt.$2 < v.y + v.h)
              .firstOrNull;
      var guarded = false;
      for (final c in fl.chestMarks) {
        final inGuardVault = gv != null &&
            c.$1 >= gv.x &&
            c.$2 >= gv.y &&
            c.$1 < gv.x + gv.w &&
            c.$2 < gv.y + gv.h;
        guarded |= inGuardVault;
        chest(fl, px(c),
            tier: inGuardVault ? ChestTier.oro : ChestTier.plata,
            guard: inGuardVault ? g.id : null);
      }
      if (!guarded) {
        // Tesoro del guardián: un cofre dorado a 1–2 tiles de su lugar.
        WorldPoint? at;
        for (final (dx, dy) in const [
          (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2),
          (1, 1), (-1, 1), (1, -1), (-1, -1),
        ]) {
          final tx = gt.$1 + dx, ty = gt.$2 + dy;
          if (solid(tx, ty) || !fl.containsTile(tx, ty)) continue;
          at = px((tx, ty));
          break;
        }
        if (at != null) chest(fl, at, tier: ChestTier.oro, guard: g.id);
      }
      for (final c in fl.chestSpots) {
        chest(fl, px(c), tier: tierRoll());
      }
      for (var i = 0; i < extraChests; i++) {
        chest(fl, freeSpot(fl, 70), tier: tierRoll());
      }
      for (final poi in fl.pois) {
        final c = poi.chest;
        if (poi.kind != PoiKind.secret || c == null) continue;
        chest(fl, px(c),
            tier: cr() < kSecretGoldChance ? ChestTier.oro : ChestTier.plata,
            secret: poi.id);
      }
    }

    s.mission = MissionRun(
      missionId: m.id,
      seed: seed,
      goal: goal,
      objectives: objectives,
      enemies: enemies,
      items: items,
      zoneLevel: map.floors.first.level,
      zone: z.index,
      floors: map.floors.length,
      floorGoals: goals,
      levels: [for (final fl in map.floors) fl.level],
    );
    _enterField(m, seed);
  }

  /// Empieza el Eco votado: se consume del inventario de quien lo abrió,
  /// se le suman los mods gratis del Atlas y se arma su mazmorra
  /// (ecos_atlas.md § 4).
  void _startEco() {
    final eco = s.eco;
    final owner = s.players[s.ecoOwner];
    final have = eco == null ? null : owner?.profile.ecoByUid(eco.uid);
    if (have == null || owner == null) {
      say('El Eco ya no está en el inventario: se canceló.');
      _clearEcoVote();
      s.mode = SessionMode.lobby;
      return;
    }
    owner.profile = InventoryRules.removeEco(owner.profile, have.uid);
    final run = EcoRules.withFreeMods(_ecoRand, have, _atlas.freeMods);
    s.eco = run;
    _startZoneMission(ecos.missionDef(run), ecos.zoneDef(run),
        seed: run.seed, atlasMap: e._ecoMap(run), extraChests: _atlas.chests);
    if (run.mods.length > have.mods.length) {
      say('Atlas: +${run.mods.length - have.mods.length} modificador'
          '${run.mods.length - have.mods.length == 1 ? '' : 'es'} gratis.');
    }
  }

  /// Fin común de `startMission`: jugadores al spawn, gracia y avisos.
  void _enterField(MissionDef m, int seed) {
    s.ground.clear();
    s.mode = SessionMode.field;
    var i = 0;
    for (final p in players) {
      final pos = spawnPos(i++);
      p
        ..x = pos.x
        ..y = pos.y
        ..epoch += 1
        ..ult = 0
        ..moving = false;
      fill(p);
    }
    s.graceUntil = s.time + SessionEngine.missionStartGrace;
    events.add(MissionStartedEvent(m.id, seed));
    say('¡Todos listos! Misión: ${m.name} [${m.type}]');
  }

  /// `updateOpen`: abre la barrera de cada piso despejado (escalera) y la
  /// del jefe cuando se cumplen todos los objetivos.
  void updateOpen() {
    final m = s.mission;
    if (m == null) return;
    for (var f = 0; f < m.floors - 1; f++) {
      if (m.opened.contains(f) || !m.floorCleared(f)) continue;
      m.opened.add(f);
      events
        ..add(StairsOpenedEvent(f))
        ..add(const GateOpenedEvent());
      say('¡Piso ${f + 1} despejado! Se abrió el paso a la escalera.');
    }
    if (m.open) return;
    final k = m.objective(ObjectiveKind.kills);
    if (k != null) k.count = m.kills;
    if (m.objectives.every((o) => o.done)) {
      m.open = true;
      events.add(const GateOpenedEvent());
      say('¡Objetivos cumplidos! La barrera del jefe se abrió.');
    }
  }

  MissionDef get _missionDef => e.missionOf(s, s.mission!.missionId)!;

  /// `openChest` (v0.6, loot.md § 23): lo abre [p] y **cada jugador**
  /// recibe su propia tirada según la calidad del cofre: créditos,
  /// consumible a veces, armas (dorado: Rara o mejor segura, a veces de
  /// una base temática de la zona), materiales y, en el endgame, Ecos.
  void openChest(SessionPlayer p, MissionItem chest) {
    final def = kChestTiers[chest.tier]!;
    final zone = s.mission!.zoneLevel;
    final mtier = _missionDef.chestTier;
    say('${p.name} abrió ${def.name}.');
    for (final q in players) {
      final cr =
          ((20 + (_rand() * 31).floor() + mtier * 10) * def.creditMult).round();
      var prof = q.profile.copyWith(credits: q.profile.credits + cr);
      var msg = '${q.name}: +$cr créditos';
      BattleItem? item;
      if (_rand() < def.consumableChance) {
        if (_rand() < 0.6) {
          prof = prof.copyWith(
              potions: math.min(ProgressionRules.maxItems, prof.potions + 1));
          item = BattleItem.potion;
        } else {
          prof = prof.copyWith(
              ethers: math.min(ProgressionRules.maxItems, prof.ethers + 1));
          item = BattleItem.ether;
        }
      }
      if (item != null) msg += ' · +1 ${kItems[item]!.name}';
      q.profile = InventoryRules.relayout(prof);
      final drops = _chestDrops(q, def, zone);
      if (q.id == p.id) {
        final weapon = drops.where((d) => d.isItem).firstOrNull?.item;
        events.add(ChestOpenedEvent(p.id, cr,
            item: item, weaponId: weapon?.baseId, tier: chest.tier));
      }
      say(msg);
      _deliver(q, drops, LootSource.chest, chest.x, chest.y);
    }
  }

  /// Las tiradas de un cofre de calidad [def] para [q].
  List<LootDrop> _chestDrops(SessionPlayer q, ChestTierDef def, int zone) {
    final drops = <LootDrop>[];
    final il = LootRules.itemLevelFor(zone, LootSource.chest, cap: _lootCap());
    if (def.guaranteedRare) {
      drops.add(LootDrop.item(_rareWeapon(q, il,
          source: LootSource.chest,
          extraBonus: def.rarityBonus,
          themeChance: def.themeChance)));
    } else if (def.themeChance > 0 && _rand() < def.themeChance * def.weaponChance) {
      drops.add(LootDrop.item(_themed(q, il,
          extraBonus: def.rarityBonus, source: LootSource.chest)));
    }
    drops.addAll(_rollFor(q, LootSource.chest, zone,
        // Dorado: la segura + `weaponChance` de otra. Reforzado: la mitad
        // de su chance va a la base temática (arriba) y la otra mitad acá.
        chance: !def.guaranteedRare && def.themeChance > 0
            ? def.weaponChance * (1 - def.themeChance)
            : def.weaponChance,
        extraBonus: def.rarityBonus));
    final mats = <CraftMaterial, int>{};
    for (var i = 0; i < def.extraMaterialRolls; i++) {
      for (final e in rules.loot
          .rollMaterials(_rand, zone, LootSource.chest)
          .entries) {
        mats[e.key] = (mats[e.key] ?? 0) + e.value;
      }
    }
    if (def.esquirlas > 0) {
      mats[CraftMaterial.esquirla] =
          (mats[CraftMaterial.esquirla] ?? 0) + def.esquirlas;
    }
    for (final e in mats.entries) {
      drops.add(LootDrop.stack(StackKind.of(e.key), e.value));
    }
    if (zone >= kChestEcoMinLevel && _ecoRand() < def.ecoChance) {
      drops.add(LootDrop.eco(ecos.generate(_ecoRand,
          tier: EcoRules.dropTier(_ecoRand, _eco),
          source: LootSource.chest,
          atlas: _eco == null ? AtlasEffects.none : _atlas)));
    }
    if (_eco != null && _ecoRand() < def.anchorChance) {
      drops.add(const LootDrop.stack(StackKind.ancla, 1));
    }
    return drops;
  }

  /// Un arma de [q] a nivel [il] con base temática de la zona si hay
  /// (worldgen.md § 11, `kThemeBaseWords`).
  ItemInstance _themed(SessionPlayer q, int il,
      {Rarity? rarity, double extraBonus = 0, LootSource source = LootSource.chest}) {
    final r = rarity ??
        rules.loot.rollRarity(_rand, il, source, extraBonus: extraBonus);
    String? base;
    if (r != Rarity.legendario) {
      final gen = _zoneGen;
      final words = gen == null ? const <String>[] : kThemeBaseWords[gen]!;
      final pool = [
        for (final w in catalog.weapons.values)
          if (w.level <= il && words.any(w.id.contains)) w,
      ];
      base = LootRules.pickWeighted(
              _rand,
              pool,
              (w) =>
                  (w.level >= il - 10 ? 3.0 : 1.0) *
                  (w.family == q.profile.classId ? 2.0 : 1.0))
          ?.id;
    }
    return rules.loot.generate(_rand,
        itemLevel: il,
        rarity: r,
        baseId: base,
        family: q.profile.classId,
        source: source,
        extraBonus: extraBonus);
  }

  /// Un arma Rara o mejor (cofre dorado).
  ItemInstance _rareWeapon(SessionPlayer q, int il,
      {required LootSource source,
      double extraBonus = 0,
      double themeChance = 0}) {
    var r = rules.loot.rollRarity(_rand, il, source, extraBonus: extraBonus);
    if (r.index < Rarity.raro.index) r = Rarity.raro;
    if (_rand() < themeChance) {
      return _themed(q, il, rarity: r, source: source);
    }
    return rules.loot.generate(_rand,
        itemLevel: il, rarity: r, family: q.profile.classId, source: source);
  }

  /// Generador de la zona de la misión (o del Eco / la Prueba).
  ZoneGen? get _zoneGen {
    final eco = _eco, trial = _trial, m = s.mission;
    if (eco != null) return ecos.zoneDef(eco).gen;
    if (trial != null) return e.trialRules.zoneDef(trial).gen;
    return m == null ? null : catalog.zone(m.zone)?.gen;
  }

  // ---------------- exploración v0.6 (worldgen.md § 11) ----------------

  /// `InteractPoiAction`: E frente a un punto de interés del piso.
  bool _interactPoi(SessionPlayer p, int poiId) {
    final m = s.mission;
    if (s.mode != SessionMode.field || m == null || !p.alive) return false;
    final f = e.mapFor(s).floor(m.floor);
    final poi = f?.poi(poiId);
    if (f == null || poi == null) return false;
    if (!identical(ExplorationRules.usable(f, m, p.x, p.y), poi)) {
      return false;
    }
    switch (poi.kind) {
      case PoiKind.secret:
        m.poiUsed.add(poi.id);
        say('¡${p.name} encontró una sala secreta!');
      case PoiKind.shortcut:
        m.poiUsed.add(poi.id);
        say('${p.name} abrió un atajo.');
      case PoiKind.brazier:
        m.poiUsed.add(poi.id);
        final q = f.quests.where((q) => q.id == poi.quest).firstOrNull;
        final (a, b) = q == null
            ? (0, 0)
            : ExplorationRules.questProgress(q, m, f);
        say('${p.name} encendió un brasero ($a/$b).');
      case PoiKind.shrine:
        m.poiUsed.add(poi.id);
        _bless(BlessingKind.values[poi.variant % BlessingKind.values.length],
            by: p.name);
      case PoiKind.wind:
        m.windUntil = s.time + kWindSeconds;
        say('${p.name} invocó el Viento del Eco: '
            '+${((kWindSpeed - 1) * 100).round()}% de velocidad por '
            '${kWindSeconds.round()} s.');
      case PoiKind.waystone:
        if (!m.poiUsed.contains(poi.id)) {
          m.poiUsed.add(poi.id);
          say('${p.name} activó una piedra de paso.');
        } else {
          final to = ExplorationRules.nextWaystone(f, m, poi);
          if (to == null) return false;
          // Viaje rápido: solo quien la usa (worldgen.md § 11.3).
          final pos = _besideTile(e.mapFor(s), to.tx, to.ty);
          p
            ..x = pos.x
            ..y = pos.y
            ..epoch += 1
            ..moving = false;
          events.add(PoiUsedEvent(p.id, poi.id, poi.kind, toPoi: to.id));
          return true;
        }
      case PoiKind.relic:
        return false;
    }
    events.add(PoiUsedEvent(p.id, poi.id, poi.kind,
        blessing: poi.kind == PoiKind.shrine ? m.blessing : null));
    _checkQuests();
    return true;
  }

  /// El centro de un tile caminable junto a ([tx], [ty]) (abajo primero).
  WorldPoint _besideTile(GameMap map, int tx, int ty) {
    for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
      final x = (tx + dx) * 16 + 8.0, y = (ty + dy) * 16 + 8.0;
      if (!WorldRules.collides(map, x, y, blockVoid: true)) {
        return WorldPoint(x, y);
      }
    }
    return WorldPoint(tx * 16 + 8.0, (ty + 1) * 16 + 8.0);
  }

  /// Activa la bendición [k] para el grupo (reemplaza la anterior).
  void _bless(BlessingKind k, {String? by}) {
    final m = s.mission!;
    m.blessing = k;
    final def = kBlessings[k]!;
    if (k == BlessingKind.vigor) {
      for (final q in players) {
        if (!q.alive) continue;
        q
          ..hp = q.maxHp.toDouble()
          ..mp = q.maxMp.toDouble();
      }
    }
    say(by == null
        ? '${def.name}: ${def.effect} hasta el final de la misión.'
        : '$by activó un santuario. ${def.name}: ${def.effect} '
            'hasta el final de la misión.');
  }

  /// Cada tick de campo: descubrir PdI, levantar reliquias, cofres
  /// custodiados y misiones opcionales.
  void _explorationTick(GameMap map, MissionRun m) {
    final f = map.floor(m.floor);
    if (f == null) return;
    for (final poi in f.pois) {
      final c = poi.center;
      if (!m.poiSeen.contains(poi.id) &&
          _touching(c.x, c.y, ExplorationRules.discoverRange) != null) {
        m.poiSeen.add(poi.id);
      }
      if (poi.kind == PoiKind.relic && !m.poiUsed.contains(poi.id)) {
        final pl = _touching(c.x, c.y, ExplorationRules.relicRange);
        if (pl != null) {
          m.poiUsed.add(poi.id);
          events.add(PoiUsedEvent(pl.id, poi.id, poi.kind));
          say('${pl.name} encontró la reliquia perdida.');
        }
      }
    }
    _checkQuests();
  }

  /// Cumple las misiones opcionales del piso actual que llegaron a su
  /// meta y entrega los premios (cada jugador el suyo).
  void _checkQuests() {
    final m = s.mission;
    final f = m == null ? null : e.mapFor(s).floor(m.floor);
    if (m == null || f == null) return;
    for (final q in f.quests) {
      if (m.questsDone.contains(q.id) || m.questsFailed.contains(q.id)) {
        continue;
      }
      if (!ExplorationRules.questComplete(q, m, f)) continue;
      m.questsDone.add(q.id);
      events.add(QuestDoneEvent(q.id, f.index, q.kind));
      say('¡Misión opcional cumplida: ${questText(q.kind)}!');
      _questReward(q, f);
    }
  }

  /// La misión `guardian` del piso [floor] falla si se baja con la élite
  /// viva.
  void _guardianEscaped(int floor) {
    final m = s.mission!;
    final f = e.mapFor(s).floor(floor);
    if (f == null) return;
    for (final q in f.quests) {
      if (q.kind != QuestKind.guardian ||
          m.questsDone.contains(q.id) ||
          m.questsFailed.contains(q.id)) {
        continue;
      }
      if (ExplorationRules.questComplete(q, m, f)) continue;
      m.questsFailed.add(q.id);
      say('Misión opcional fallida: ${questText(q.kind)}.');
    }
  }

  /// Premio de una misión opcional (loot.md § 23.3): para cada jugador,
  /// el premio principal (arma Rara/Épica sesgada a su plan de build, un
  /// Eco o una bendición), un paquete de materiales y créditos.
  void _questReward(FloorQuest q, MapFloor f) {
    final m = s.mission!;
    final level = f.level;
    var reward = q.reward;
    if (reward == QuestReward.eco && level < kQuestEcoMinLevel) {
      reward = QuestReward.arma;
    }
    if (reward == QuestReward.bendicion) {
      final others = [
        for (final k in BlessingKind.values)
          if (k != m.blessing) k,
      ];
      _bless(others[(_rand() * others.length).floor() % others.length]);
    }
    final il = LootRules.itemLevelFor(level, LootSource.elite, cap: _lootCap());
    for (final p in players) {
      final drops = <LootDrop>[];
      if (reward == QuestReward.arma || reward == QuestReward.bendicion) {
        if (reward == QuestReward.arma) {
          drops.add(LootDrop.item(_questWeapon(p, il)));
        }
      }
      if (reward == QuestReward.eco) {
        drops.add(LootDrop.eco(ecos.generate(_ecoRand,
            tier: EcoRules.dropTier(_ecoRand, _eco),
            source: LootSource.elite,
            atlas: _eco == null ? AtlasEffects.none : _atlas)));
      }
      drops
        ..add(const LootDrop.stack(StackKind.esquirla, kQuestEsquirlas))
        ..add(const LootDrop.stack(StackKind.cristal, kQuestCristales));
      if (level >= kQuestPrismaLevel) {
        drops.add(const LootDrop.stack(StackKind.prisma, 1));
      }
      if (_eco != null) drops.add(const LootDrop.stack(StackKind.ancla, 1));
      final cr = kQuestCreditsBase + kQuestCreditsPerLevel * level;
      p.profile = p.profile.copyWith(credits: p.profile.credits + cr);
      say('${p.name}: +$cr créditos (misión opcional)');
      // Siempre al inventario: es un premio, no algo que se deja en el piso.
      _deliver(p, drops, LootSource.mission, p.x, p.y);
    }
  }

  /// Arma de premio: Rara (o Épica), con 60% de una base o tipo del plan
  /// de build del jugador si tiene uno.
  ItemInstance _questWeapon(SessionPlayer p, int il) {
    final r = _rand() < kQuestEpicChance ? Rarity.epico : Rarity.raro;
    final wants = p.buildWants;
    String? base;
    if (wants != null && _rand() < kQuestBuildChance) {
      final pool = [
        for (final w in catalog.weapons.values)
          if (w.level <= il &&
              (wants.weaponBases.contains(w.id) ||
                  wants.weaponTypes.contains(w.type)))
            w,
      ];
      base = LootRules.pickWeighted(
              _rand, pool, (w) => wants.weaponBases.contains(w.id) ? 3.0 : 1.0)
          ?.id;
    }
    if (base == null) return _themed(p, il, rarity: r, source: LootSource.elite);
    return rules.loot.generate(_rand,
        itemLevel: il,
        rarity: r,
        baseId: base,
        family: p.profile.classId,
        source: LootSource.elite);
  }

  /// `calmEnemies`.
  void calmEnemies() {
    final m = s.mission;
    if (m == null) return;
    for (final en in m.enemies) {
      if (!en.alive || en.boss || en.floor != m.floor) continue;
      if (players.any((p) =>
          _dist(p.x, p.y, en.x, en.y) < SessionEngine.calmRange)) {
        en
          ..x = en.homeX
          ..y = en.homeY
          ..vx = 0
          ..vy = 0
          ..timer = 1.5;
      }
    }
  }

  // ---------------- campo (`fieldTick`) ----------------

  /// El primer jugador vivo a menos de [range]. Las interacciones
  /// (objetos, escaleras, PdI) son del líder: los compañeros no cuentan
  /// salvo con [any] (contacto con enemigos; solo_party.md § 3.5).
  SessionPlayer? _touching(double x, double y, double range,
          {bool any = false}) =>
      players
          .where((p) =>
              p.alive &&
              (any || !p.isCompanion) &&
              _dist(p.x, p.y, x, y) < range)
          .firstOrNull;

  /// Fila detrás del líder (solo_party.md § 3.5): el host anota el rastro
  /// del líder y pone a cada compañero k a `k × followGap` px de camino.
  void _followLeaders() {
    for (final l in players) {
      if (l.isCompanion) continue;
      final crew = [
        for (final c in players)
          if (c.leaderId == l.id) c
      ];
      if (crew.isEmpty) continue;
      if (l.trailEpoch != l.epoch) {
        l
          ..trail = const []
          ..trailEpoch = l.epoch;
      }
      final head = l.trail.firstOrNull;
      if (head == null ||
          _dist(head.x, head.y, l.x, l.y) >= SessionEngine.trailStep) {
        l.trail = List.unmodifiable([
          WorldPoint(l.x, l.y),
          ...l.trail.take(SessionEngine.trailMax - 1),
        ]);
      }
      for (var k = 0; k < crew.length; k++) {
        final c = crew[k];
        final at = _alongTrail(l, (k + 1) * SessionEngine.followGap);
        if (at == null) {
          c.moving = false;
          continue;
        }
        final dx = at.x - c.x, dy = at.y - c.y;
        c.moving = dx.abs() > 0.01 || dy.abs() > 0.01;
        if (dx.abs() > 0.5) c.dir = dx > 0 ? 1 : -1;
        c
          ..x = at.x
          ..y = at.y;
      }
    }
  }

  /// El punto a [d] px de camino detrás de [l] por su rastro (`null` si
  /// el rastro es más corto).
  static WorldPoint? _alongTrail(SessionPlayer l, double d) {
    var px = l.x, py = l.y, left = d;
    for (final q in l.trail) {
      final seg = _dist(px, py, q.x, q.y);
      if (seg > 0 && seg >= left) {
        final t = left / seg;
        return WorldPoint(px + (q.x - px) * t, py + (q.y - py) * t);
      }
      left -= seg;
      px = q.x;
      py = q.y;
    }
    return null;
  }

  void fieldTick(double dt) {
    final m = s.mission!;
    _followLeaders();
    for (final it in m.items) {
      if (it.done ||
          it.kind != MissionItemKind.fragment ||
          it.floor != m.floor) {
        continue;
      }
      final pl = _touching(it.x, it.y, SessionEngine.pickupRange);
      if (pl == null) continue;
      it.done = true;
      final o = _bump(ObjectiveKind.fragments);
      say('${pl.name} recogió un Fragmento de tiempo (${o?.count ?? 0}/3)');
      updateOpen();
    }
    for (final it in m.items) {
      if (it.done || it.kind != MissionItemKind.chest || it.floor != m.floor) {
        continue;
      }
      // Custodiado: no se abre mientras su guardián viva (§ 11.5).
      if (it.guard case final g? when m.enemy(g)?.alive ?? false) continue;
      final pl = _touching(it.x, it.y, SessionEngine.pickupRange);
      if (pl == null) continue;
      it.done = true;
      openChest(pl, it);
    }
    _autoPickup();

    final map = e.mapFor(s);
    _explorationTick(map, m);
    _voidFalls(map, m);
    if (_trial != null) _traps(map, m);
    // Escalera de bajada: tocarla baja a todo el grupo.
    final down = map.floor(m.floor)?.stairsDown;
    if (down != null &&
        _touching(down.x, down.y, SessionEngine.stairsTouch) != null) {
      changeFloor(m.floor + 1, down: true);
      return;
    }
    // Modificador `sequia` del Eco: sin regeneración en el campo.
    final regen = !(_eco != null && EcoRules.noRegen(_eco!));
    // Bendición de Vigor: regeneración ×3 (worldgen.md § 11.4).
    final rk = m.blessing == BlessingKind.vigor ? kVigorFieldRegen : 1.0;
    for (final p in regen ? players : const <SessionPlayer>[]) {
      p.mp = math.min(p.maxMp.toDouble(), p.mp + dt * 0.4 * rk);
      p.hp = math.min(p.maxHp.toDouble(), p.hp + p.maxHp * 0.008 * dt * rk);
    }
    for (final en in m.enemies) {
      if (!en.alive || en.floor != m.floor) continue;
      if (!en.boss) _enemyAi(en, map, dt);
      if (s.time > s.graceUntil) {
        final range =
            en.boss ? SessionEngine.bossContactRange : SessionEngine.contactRange;
        final p = _touching(en.x, en.y, range, any: true);
        if (p != null) {
          startBattle(en, p);
          return;
        }
      }
    }
  }

  /// Abismo (worldgen.md § 9.3): quien pisa el vacío vuelve al spawn del
  /// piso actual, sin daño.
  void _voidFalls(GameMap map, MissionRun m) {
    final f = map.floor(m.floor);
    if (f == null) return;
    var i = 0;
    for (final p in players) {
      if (!p.alive || !WorldRules.overVoid(map, p.x, p.y)) continue;
      final pos = _around(f.spawn, i++);
      p
        ..x = pos.x
        ..y = pos.y
        ..epoch += 1
        ..moving = false;
      events.add(FellIntoVoidEvent(p.id, m.floor));
      say('${p.name} cayó al vacío.');
    }
  }

  void _enemyAi(FieldEnemy en, GameMap map, double dt) {
    final calm = s.time < s.graceUntil;
    final dh = _dist(en.x, en.y, en.homeX, en.homeY);
    SessionPlayer? near;
    var nd = double.infinity;
    for (final p in players) {
      if (!p.alive) continue;
      final d = _dist(p.x, p.y, en.x, en.y);
      if (d < nd) {
        nd = d;
        near = p;
      }
    }
    en.aggro = !calm &&
        near != null &&
        nd < SessionEngine.aggroRange &&
        _dist(near.x, near.y, en.homeX, en.homeY) < SessionEngine.leash;
    if (en.aggro) {
      final a = math.atan2(near!.y - en.y, near.x - en.x);
      en.vx = math.cos(a) * SessionEngine.chaseSpeed;
      en.vy = math.sin(a) * SessionEngine.chaseSpeed;
    } else if (dh > SessionEngine.leash * 0.6) {
      final a = math.atan2(en.homeY - en.y, en.homeX - en.x);
      en.vx = math.cos(a) * SessionEngine.returnSpeed;
      en.vy = math.sin(a) * SessionEngine.returnSpeed;
    } else {
      en.timer -= dt;
      if (en.timer <= 0) {
        en.timer = 1 + _rand() * 1.5;
        if (_rand() < 0.4) {
          en.vx = 0;
          en.vy = 0;
        } else {
          final a = _rand() * math.pi * 2;
          en.vx = math.cos(a) * SessionEngine.wanderSpeed;
          en.vy = math.sin(a) * SessionEngine.wanderSpeed;
        }
      }
    }
    final pos = WorldRules.move(map, en.x, en.y, en.vx * dt, en.vy * dt,
        blockVoid: true);
    en
      ..x = pos.x
      ..y = pos.y;
    if (en.vx.abs() > 1) en.dir = en.vx > 0 ? 1 : -1;
  }

  // ---------------- batalla ----------------

  void startBattle(FieldEnemy en, SessionPlayer trigger) {
    s.seq++;
    final step = e.battles.start(
      party: [for (final p in players) e.partyMember(p, blessing: s.mission?.blessing)],
      enemyTypes: en.group,
      elite: en.elite,
      triggeredBy: trigger.id,
    );
    final level = _levelFor(en);
    ZoneRules.scaleBattle(step.state, level, curve: catalog.curve);
    final eco = _eco;
    if (eco != null) {
      EcoRules.applyBattle(step.state, eco, atlas: _atlas, boss: en.boss);
    }
    s.battle = SessionBattle(
      id: s.seq,
      state: step.state,
      fieldEnemyId: en.id,
      boss: en.boss,
      elite: en.elite,
      level: level,
    );
    for (final p in players) {
      p
        ..epoch += 1
        ..moving = false;
    }
    s.mode = SessionMode.battle;
    events.add(BattleStartedEvent(s.seq, en.id, boss: en.boss, elite: en.elite));
  }

  bool _battleCommand(SessionPlayer p, BattleCommand cmd) {
    final b = s.battle;
    if (s.mode != SessionMode.battle ||
        b == null ||
        b.endTimer != null ||
        b.wait > 0) {
      return false;
    }
    // TUTORIAL: el host valida contra el paso (combat_tutorial.md § 6).
    if (tutorialAllows(p, cmd) == false) return false;
    final before = b.state;
    final step = e.battles.command(b.state, p.id, cmd);
    if (step == null) return false;
    if (s.tutorial != null) {
      _applyTutorialStep(b, step);
      afterTutorialCommand(p, cmd, before, step.events);
    } else {
      _applyBattleStep(b, step);
    }
    // Dúo (v0.8.3): su cinemática dura ~1.6 s (battle_presentation.md
    // § "Dúos"); el próximo paso espera a que termine la descarga.
    if (b.endTimer == null) {
      b.wait = cmd is UltimateCommand
          ? 2.3
          : cmd is DualCommand
              ? 1.5
              : 0.8;
    }
    return true;
  }

  /// Guarda el paso del motor, cuenta K.O. y detecta el fin.
  void _applyBattleStep(SessionBattle b, BattleStep step) {
    var evs = step.events;
    final won = step.state.outcome;
    if (b.level > 0 && won != null && won.victory && b.endTimer == null) {
      // XP por nivel de zona (worldgen.md § 6.3).
      // Maestro del Eco (Atlas): +XP dentro de los Ecos.
      final xpBonus = _eco == null ? 0.0 : _atlas.xp;
      final xp = jsRound(ZoneRules.battleXp(won.xp, b.level) * (1 + xpBonus));
      step.state
        ..outcome = BattleOutcome(victory: true, xp: xp, credits: won.credits)
        ..log = '¡Victoria! +$xp XP · +${won.credits} créditos para cada uno';
      evs = [
        for (final ev in evs)
          ev is BattleEndedEvent && ev.victory
              ? BattleEndedEvent(true, xp, won.credits)
              : ev,
      ];
    }
    b.state = step.state;
    if (evs.isNotEmpty) events.add(BattleStepEvent(evs));
    final m = s.mission;
    final partyIds = {for (final c in step.state.party) c.id};
    for (final ev in step.events) {
      if (ev is KnockedOutEvent && partyIds.contains(ev.targetId) && m != null) {
        m.kos++;
      }
    }
    final outcome = step.state.outcome;
    if (outcome != null && b.endTimer == null) _onBattleOver(b, outcome);
  }

  /// `checkEnd`: reparto inmediato de XP/créditos y subida de nivel.
  void _onBattleOver(SessionBattle b, BattleOutcome outcome) {
    b.endTimer = outcome.victory ? 2.0 : 2.2;
    // Lo que cambió en la batalla vuelve a cada jugador.
    for (final p in players) {
      final c = b.state.party.where((c) => c.id == p.id).firstOrNull;
      if (c == null) continue;
      p
        ..hp = c.hp.toDouble()
        ..mp = c.mp
        ..ult = c.ult
        ..profile = p.profile.copyWith(potions: c.potions, ethers: c.ethers);
    }
    if (!outcome.victory) return;
    final m = s.mission;
    if (m != null) {
      m.xp += outcome.xp;
      m.credits += outcome.credits;
    }
    for (final p in players) {
      final g = rules.gainXp(
          p.profile.copyWith(credits: p.profile.credits + outcome.credits),
          outcome.xp);
      final oldLevel = p.profile.level;
      p.profile = g.profile;
      if (g.levelsGained > 0) {
        p.levelUpPending = true;
        refresh(p, gain: true);
        for (var l = oldLevel + 1; l <= g.profile.level; l++) {
          events.add(LevelUpEvent(p.id, l));
        }
      }
      // Maestría (ecos_atlas.md § 6): +2 puntos de árbol (v0.8), sin pausar.
      if (g.masteryGained > 0) {
        final m = g.profile.mastery;
        for (var k = m - g.masteryGained + 1; k <= m; k++) {
          events.add(MasteryUpEvent(p.id, k));
        }
        say('${p.name} alcanzó Maestría $m: +${g.masteryGained} punto'
            '${g.masteryGained == 1 ? '' : 's'} de árbol.');
      }
    }
  }

  /// `battleTick`.
  void battleTick(double dt) {
    final b = s.battle!;
    final end = b.endTimer;
    if (end != null) {
      b.endTimer = end - dt;
      if (b.endTimer! <= 0) finishBattle();
      return;
    }
    if (b.wait > 0) {
      b.wait -= dt;
      return;
    }
    final cur = b.state.current;
    if (cur != null && cur.isPlayer && !cur.alive) b.state.currentId = null;

    if (b.state.currentId == null) {
      final step = e.battles.nextTurn(b.state);
      _applyBattleStep(b, step);
      if (b.endTimer != null) return;
      b.turnTime = 0;
      final statusText = step.events.any((ev) =>
          (ev is DamageEvent && ev.fromStatus) ||
          ev is HealEvent ||
          ev is TurnSkippedEvent);
      if (statusText) b.wait = 0.9;
      final next = b.state.current;
      if (step.events.isNotEmpty && next == null) b.wait = 1.1;
      if (next != null && !next.isPlayer) b.wait = math.max(b.wait, 0.35);
      return;
    }

    if (!b.state.current!.isPlayer) {
      final step = e.battles.enemyTurn(b.state);
      if (step != null) _applyBattleStep(b, step);
      // ULT enemiga: la pausa de una ULT (cinemática); aviso: tiempo para
      // leer el cartel (docs/specs/break_and_enemy_ults.md § 2).
      final evs = step?.events ?? const <BattleEvent>[];
      if (b.endTimer == null) {
        b.wait = evs.any((ev) => ev is EnemyUltEvent)
            ? 2.3
            : evs.any((ev) => ev is EnemyUltWarningEvent)
                ? 1.4
                : 0.8;
      }
      return;
    }

    b.turnTime += dt;
    final limit = s.turnLimit;
    if (limit != null && b.turnTime > limit) {
      final step = e.battles.timeout(b.state);
      if (step != null) _applyBattleStep(b, step);
      if (b.endTimer == null) b.wait = 0.8;
    }
  }

  /// `finishBattle`.
  void finishBattle() {
    final b = s.battle!;
    final victory = b.state.outcome?.victory ?? false;
    events.add(BattleFinishedEvent(victory));
    if (!victory) {
      missionEnd(false);
      return;
    }
    final m = s.mission!;
    final fe = m.enemy(b.fieldEnemyId);
    fe?.alive = false;
    final lx = fe?.x ?? 0, ly = fe?.y ?? 0;
    final lootLevel = b.level > 0 ? b.level : null;
    if (b.elite) {
      m.elites++;
      _bump(ObjectiveKind.elite);
      final firsts = _lootAll(LootSource.elite, lx, ly, level: lootLevel);
      for (final d in firsts.entries) {
        final it = d.value.item!;
        m.eliteDrops.add(WeaponDrop(d.key, it.baseId, rarity: it.rarity));
        events.add(WeaponDropEvent(d.key, it.baseId, 'elite'));
      }
    } else if (b.boss) {
      _lootAll(LootSource.boss, lx, ly, level: lootLevel);
      _bossLegendary(b, lx, ly, lootLevel);
    } else {
      m.kills++;
      final k = m.objective(ObjectiveKind.kills);
      if (k != null) {
        events.add(ObjectiveProgressEvent(ObjectiveKind.kills, m.kills, k.goal));
      }
      _lootAll(LootSource.battle, lx, ly, level: lootLevel);
    }
    updateOpen();
    for (final p in players) {
      p.epoch++;
      if (p.hp <= 0) p.hp = 1;
      refresh(p);
    }
    s.battle = null;

    final pending = humans
        .where((p) => p.levelUpPending && p.profile.points > 0)
        .toList();
    if (pending.isNotEmpty) {
      s.mode = SessionMode.levelUp;
      s.afterLevelUp = b.boss ? AfterLevelUp.result : AfterLevelUp.field;
      say('¡Subida de nivel! Esperando a: '
          '${pending.map((p) => p.name).join(', ')}');
      return;
    }
    for (final p in players) {
      p.levelUpPending = false;
    }
    if (b.boss) {
      missionEnd(true);
      return;
    }
    _backToField();
  }

  /// `missionEnd`.
  void missionEnd(bool ok) {
    final def = _missionDef;
    final m = s.mission!;
    final t = m.elapsed;
    var rank = MissionRank.d;
    if (ok) {
      rank = t <= def.sTime && m.kos == 0
          ? MissionRank.s
          : t <= def.sTime * 1.5
              ? MissionRank.a
              : MissionRank.b;
    }
    const bonusPct = {
      MissionRank.s: 0.5,
      MissionRank.a: 0.25,
      MissionRank.b: 0.0,
      MissionRank.d: 0.0,
    };
    const dropChance = {MissionRank.s: 0.9, MissionRank.a: 0.7, MissionRank.b: 0.5};
    // Bonus de rareza del arma de fin de misión según el rango.
    const rankBonus = {MissionRank.s: 1.0, MissionRank.a: 0.5};
    final pct = bonusPct[rank]!;
    final bonus = jsRound(m.credits * pct);
    final drops = <String, String>{};
    for (final p in players) {
      p.profile = p.profile.copyWith(credits: p.profile.credits + bonus);
      if (p.hp <= 0) p.hp = 1;
    }
    final eco = _eco;
    final trial = _trial;
    final abyss = _abyss;
    // Un Eco, una Prueba o un Jefe del Abismo usan el tipo de zona solo
    // para el mapa: no desbloquean zonas.
    final zone = eco != null || trial != null || abyss != null || def.zone == 0
        ? null
        : catalog.zone(def.zone);
    final unlocked = <String, int>{};
    if (ok) {
      final firsts = _lootAll(LootSource.mission, null, null,
          chance: dropChance[rank] ?? 0,
          extraBonus: rankBonus[rank] ?? 0,
          level: eco?.monsterLevel ??
              trial?.monsterLevel ??
              abyss?.level ??
              zone?.maxLevel);
      if (eco != null) _ecoCompleted(eco);
      if (trial != null) _trialCompleted(trial);
      if (abyss != null) _abyssCompleted(abyss);
      // El jefe final activa el Portal del Eco (ecos_atlas.md § 1).
      if (zone != null && zone.index == ZoneRules.maxZone) _unlockEcos();
      for (final d in firsts.entries) {
        drops[d.key] = d.value.item!.baseId;
        events.add(WeaponDropEvent(d.key, d.value.item!.baseId, 'mission'));
      }
      // Desbloqueo de la zona siguiente (worldgen.md § 6.4).
      if (zone != null && zone.index < ZoneRules.maxZone) {
        final next = catalog.zone(zone.index + 1);
        for (final p in players) {
          if (ZoneRules.unlockedZone(p.profile) != zone.index) continue;
          p.profile = p.profile.copyWith(unlockedZone: zone.index + 1);
          unlocked[p.id] = zone.index + 1;
          events.add(ZoneUnlockedEvent(p.id, zone.index + 1));
          if (next != null) {
            final soon = next.playable ? '' : ' · Próximamente';
            say('${p.name} desbloqueó ${next.name} (${next.levelText})$soon');
          }
        }
      }
    }
    s.seq++;
    final result = MissionResult(
      id: s.seq,
      missionId: def.id,
      missionName: def.name,
      success: ok,
      rank: rank,
      time: t,
      xp: m.xp,
      credits: m.credits,
      bonus: bonus,
      bonusPercent: pct,
      kos: m.kos,
      elites: m.elites,
      eliteDrops: List.unmodifiable(m.eliteDrops),
      drops: Map.unmodifiable(drops),
      timeLeft: SessionEngine.resultSeconds,
      zone: def.zone,
      unlocked: Map.unmodifiable(unlocked),
    );
    s
      ..result = result
      ..battle = null
      ..mode = SessionMode.result;
    events.add(MissionEndedEvent(result));
  }

  /// Eco completado: evento para el Atlas de cada jugador y el loot de
  /// fin (1 Eco por jugador y, con Resonancia, chance de otro).
  void _ecoCompleted(EcoItem eco) {
    events.add(EcoCompletedEvent([for (final p in players) p.id],
        tier: eco.tier, zone: eco.zone, boss: eco.boss));
    say('¡Eco completado! ${ecos.fullName(eco)}');
    for (final p in players) {
      final drops = ecos.completionDrops(_ecoRand, eco, atlas: _atlas);
      _deliver(p, [for (final d in drops) LootDrop.eco(d)], LootSource.mission,
          p.x, p.y);
    }
  }

  /// Activa el Portal del Eco de quien no lo tenía y le da un Eco de
  /// tier 1 (Mágico) para empezar.
  void _unlockEcos() {
    for (final p in players) {
      if (p.profile.ecosUnlocked) continue;
      p.profile = p.profile.copyWith(ecosUnlocked: true);
      events.add(EcosUnlockedEvent(p.id));
      say('${p.name} activó el Portal del Eco en el pueblo.');
      final first = ecos.generate(_ecoRand,
          tier: 1, rarity: Rarity.magico, atlas: _atlas);
      _deliver(p, [LootDrop.eco(first)], LootSource.mission, p.x, p.y);
    }
  }

  /// `toLobby`.
  void toLobby() {
    s
      ..eco = null
      ..ecoOwner = null
      ..trial = null
      ..abyss = null
      ..abyssOwner = null
      ..mode = SessionMode.lobby
      ..mission = null
      ..result = null
      ..battle = null
      ..vote = null
      ..prep = null
      ..afterLevelUp = null;
    s.ground.clear();
    var i = 0;
    for (final p in players) {
      final pos = spawnPos(i++);
      p
        ..levelUpPending = false
        ..x = pos.x
        ..y = pos.y
        ..epoch += 1;
      fill(p);
    }
    events.add(const ReturnedToLobbyEvent());
  }
}
