import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/atlas_store.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/game_map.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/profile_store.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/models/session_event.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/rules/atlas_rules.dart';
import '../../../game_engine/rules/session_engine.dart';
import '../../../game_engine/rules/world_rules.dart';
import '../../../game_engine/rules/zone_rules.dart';
import '../../../netcode/contracts/net_session.dart';
import '../../../netcode/contracts/net_session_factory.dart';
import 'local_player.dart';
import 'session_view.dart';
import 'world_text.dart';

/// Ritmo del host local. El prototipo corre `hostTick` cada 50 ms; los
/// tests suben [timeScale] (más segundos de juego por tick) o apagan el
/// timer con [autoStart] = false y avanzan con
/// `SessionController.advance`.
class SessionClock {
  const SessionClock({
    this.interval = const Duration(milliseconds: 50),
    this.timeScale = 1,
    this.autoStart = true,
  });

  final Duration interval;
  final double timeScale;
  final bool autoStart;

  /// Segundos de juego que avanza cada tick.
  double get dt => interval.inMicroseconds / 1e6 * timeScale;
}

final sessionEngineProvider =
    Provider<SessionEngine>((ref) => sl<SessionEngine>());

final profileStoreProvider = Provider<ProfileStore>((ref) => sl<ProfileStore>());

/// El Atlas de la cuenta (docs/specs/ecos_atlas.md § 5); sin registro
/// (tests), uno en memoria.
final atlasStoreProvider = Provider<AtlasStore>((ref) =>
    sl.isRegistered<AtlasStore>() ? sl<AtlasStore>() : InMemoryAtlasStore());

final sessionClockProvider = Provider<SessionClock>((ref) => const SessionClock());

/// La sala de red con la que se abre `WorldScreen` (la llena el título
/// al crear o unirse; `null` = sesión local de un jugador).
final activeNetSessionProvider = StateProvider<NetSession?>((ref) => null);

/// La red que registró el composition root (`null` = este build no
/// tiene multijugador). El título la usa para crear / unirse a salas.
final netSessionFactoryProvider = Provider<NetSessionFactory?>((ref) =>
    sl.isRegistered<NetSessionFactory>() ? sl<NetSessionFactory>() : null);

/// La sesión de juego. `null` mientras carga el perfil (o, en un
/// cliente, hasta el primer snapshot). Se descarta (y guarda) al salir
/// de `WorldScreen`.
final sessionControllerProvider =
    StateNotifierProvider.autoDispose<SessionController, SessionView?>((ref) {
  final c = SessionController(
    engine: ref.watch(sessionEngineProvider),
    store: ref.watch(profileStoreProvider),
    atlasStore: ref.watch(atlasStoreProvider),
    clock: ref.watch(sessionClockProvider),
    net: ref.read(activeNetSessionProvider),
  );
  unawaited(c.start());
  return c;
});

/// Rol de este dispositivo en la sala.
enum SessionRole {
  /// Un jugador, sin red: corre el motor.
  local,

  /// Creó la sala: corre el motor y difunde el estado.
  host,

  /// Se unió a una sala: nunca corre reglas, aplica snapshots.
  client,
}

/// La sesión de juego de este dispositivo. Según [net] es local (sin
/// red), host (dueño del `SessionEngine`, agrega a los jugadores remotos,
/// aplica sus acciones y difunde el estado) o cliente (aplica snapshots,
/// predice solo su movimiento y manda acciones). En los tres casos
/// traduce la entrada en `SessionAction` y expone la misma
/// [SessionView] + eventos a la UI. Ver docs/specs/exploration.md
/// § "Controlador de sesión" y docs/specs/netcode.md.
class SessionController extends StateNotifier<SessionView?> {
  SessionController({
    required this.engine,
    required this.store,
    this.clock = const SessionClock(),
    this.net,
    String localId = 'local',
    AtlasStore? atlasStore,
  })  : localId = net?.localId ?? localId,
        atlasStore = atlasStore ?? InMemoryAtlasStore(),
        super(null);

  /// El Atlas de la cuenta de este dispositivo (ecos_atlas.md § 5).
  final AtlasStore atlasStore;
  AtlasProgress? _atlas;
  AtlasGain? _atlasGain;
  static const _atlasRules = AtlasRules();

  /// El Atlas local (vacío hasta cargarlo).
  AtlasProgress get atlas => _atlas ?? AtlasProgress.empty;

  final SessionEngine engine;
  final ProfileStore store;
  final SessionClock clock;

  /// La sala de red; `null` = sesión local.
  final NetSession? net;

  /// Id del jugador de este dispositivo: el de la [net] (`h`, `p1`...) o
  /// `local` sin red.
  final String localId;

  SessionRole get role => net == null
      ? SessionRole.local
      : net!.isHost
          ? SessionRole.host
          : SessionRole.client;

  bool get isClient => role == SessionRole.client;

  /// Cada cuánto el host difunde el estado (`setInterval(broadcast, 66)`).
  static const broadcastInterval = Duration(milliseconds: 66);

  /// Nombre y clase del perfil nuevo cuando no hay uno guardado.
  static const defaultName = 'Héroe';
  static const defaultClass = 'guerrero';

  /// Mensajes de sistema que se conservan.
  static const maxMessages = 50;

  /// Cada cuánto se guarda el perfil si cambió (`lastSave`, 2 s).
  static const saveEvery = 2.0;

  final local = LocalPlayer();
  final _events = StreamController<SessionEvent>.broadcast();
  GameSession? _s;
  Timer? _timer;
  Timer? _broadcastTimer;
  StreamSubscription<NetEvent>? _netSub;

  /// Eventos del host que todavía no se difundieron.
  final _unsent = <SessionEvent>[];

  /// Motivo de la desconexión, si se perdió la sala.
  String? _disconnected;
  bool _started = false;

  WorldPanel? _panel;
  bool _autoChar = false;
  SessionMode? _lastMode;
  final _messages = <String>[];

  /// Drops del jugador local en la misión actual (`SessionView.missionLoot`).
  final _missionLoot = <LootDrop>[];
  final _chat = <ChatLine>[];
  List<BattleEvent> _battleEvents = const [];
  int _battleSeq = 0;

  PlayerProfile? _lastSaved;
  double _sinceSave = 0;

  /// Todo lo que pasa en la sesión, en orden (sonido, animaciones).
  Stream<SessionEvent> get events => _events.stream;

  GameSession? get session => _s;

  /// La última vista emitida (para quien dibuja por frame, como Flame,
  /// sin suscribirse).
  SessionView? get view => state;

  GameMap get map => engine.mapFor(_s ?? engine.create());

  // ------------------------------------------------------------------
  // Ciclo de vida
  // ------------------------------------------------------------------

  /// Local / host: carga el perfil, crea la sala y entra el jugador
  /// local. Cliente: empieza a escuchar snapshots y a mandar su posición.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final n = net;
    if (isClient) {
      unawaited(_loadAtlas());
      _netSub = n!.events.listen(_onNet);
      if (clock.autoStart) {
        _timer = Timer.periodic(clock.interval, (_) => _clientTick(clock.dt));
      }
      return;
    }
    PlayerProfile? profile;
    try {
      profile = await store.load();
    } catch (_) {
      profile = null;
    }
    if (!mounted) return;
    profile ??= PlayerProfile(name: defaultName, classId: defaultClass);
    await _loadAtlas();
    if (!mounted) return;
    // El Atlas del anfitrión vale para toda la sala (ecos_atlas.md § 5.2).
    var step = engine.addPlayer(
        engine.setAtlas(engine.create(), atlas.nodes).state, localId, profile)!;
    final code = n?.roomCode;
    if (code != null) {
      // `sysChat('Sala creada. Comparte el código ...')` del prototipo.
      step = SessionStep(step.state, [
        ...step.events,
        SystemMessageEvent(
            'Sala creada. Comparte el código $code con tus amigos.'),
      ]);
    }
    _lastSaved = null;
    _step(step);
    _save(force: true);
    // Recién con la sala creada: los que se unieron mientras cargaba el
    // perfil quedaron guardados en el stream de la red.
    if (n != null) _netSub = n.events.listen(_onNet);
    if (clock.autoStart) {
      _timer = Timer.periodic(clock.interval, (_) => _hostTick(clock.dt));
      if (n != null) {
        _broadcastTimer =
            Timer.periodic(broadcastInterval, (_) => _broadcast());
      }
    }
  }

  Future<void> _loadAtlas() async {
    try {
      _atlas = await atlasStore.load();
    } catch (_) {
      _atlas = AtlasProgress(); // sin disco: un Atlas vacío esta vez
    }
  }

  // ------------------------------------------------------------------
  // Atlas del Tiempo (docs/specs/ecos_atlas.md § 5)
  // ------------------------------------------------------------------

  /// Se edita solo en el pueblo.
  bool get canEditAtlas => _s?.mode == SessionMode.lobby;

  /// Toma un nodo del Atlas de la cuenta. Devuelve si se pudo.
  bool takeAtlasNode(String id) {
    if (!canEditAtlas) return false;
    final next = _atlasRules.take(atlas, id);
    if (next == null) return false;
    _setAtlas(next);
    return true;
  }

  /// Reinicio gratis (conserva las primeras veces).
  bool resetAtlas() {
    if (!canEditAtlas || atlas.nodes.isEmpty) return false;
    _setAtlas(_atlasRules.reset(atlas));
    return true;
  }

  void _setAtlas(AtlasProgress next, {bool emit = true}) {
    _atlas = next;
    unawaited(atlasStore.save(next).catchError((Object _) {}));
    // Local / anfitrión: la sala usa este Atlas (los clientes, el del host).
    final s = _s;
    if (!isClient && s != null) {
      _s = engine.setAtlas(s, next.nodes).state;
    }
    if (emit) _emit();
  }

  /// Eco completado: si este jugador estaba, anota las primeras veces en
  /// el Atlas de SU cuenta (§ 5.1).
  void _onEcoCompleted(EcoCompletedEvent e) {
    if (!e.playerIds.contains(localId)) return;
    final g = _atlasRules.complete(atlas,
        tier: e.tier, zone: e.zone, boss: e.boss);
    _atlasGain = g;
    if (g.points > 0) _setAtlas(g.progress, emit: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _broadcastTimer?.cancel();
    unawaited(_netSub?.cancel());
    _save(force: true);
    unawaited(_events.close());
    unawaited(net?.disconnect());
    super.dispose();
  }

  /// Avanza [seconds] de juego en ticks de 50 ms (tests y depuración).
  /// El host difunde el estado después de cada tick; el cliente solo
  /// manda su posición (no corre reglas).
  void advance(double seconds) {
    for (var t = 0.0; t < seconds - 1e-9; t += 0.05) {
      final dt = math.min(0.05, seconds - t);
      if (isClient) {
        _clientTick(dt);
      } else {
        _hostTick(dt);
        _broadcast();
      }
    }
  }

  /// Host: manda el estado y los eventos pendientes a los clientes.
  void _broadcast() {
    final n = net, s = _s;
    if (n == null || !n.isHost || s == null || !mounted) return;
    final events = List<SessionEvent>.of(_unsent);
    _unsent.clear();
    n.broadcast(s, events);
  }

  /// Cliente: el `send({t:'pos'})` cada 50 ms.
  void _clientTick(double dt) {
    if (_s == null || !mounted) return;
    _sendPosition();
    _sinceSave += dt;
    _save();
  }

  // ------------------------------------------------------------------
  // Red
  // ------------------------------------------------------------------

  void _onNet(NetEvent e) {
    if (!mounted) return;
    final s = _s;
    switch (e) {
      case SnapshotEvent(:final session, :final events):
        if (isClient) _step(SessionStep(session, events));
      case PeerJoinedEvent(:final peerId, :final profile):
        if (s == null || isClient) return;
        final step = engine.addPlayer(s, peerId, profile);
        if (step != null) _step(step);
      case PeerActionEvent(:final peerId, :final action):
        if (s == null || isClient) return;
        final step = engine.apply(s, peerId, action);
        if (step == null) return;
        // Las posiciones (20 por segundo por cliente) no traen eventos:
        // se aplican sin emitir una vista nueva; la emite el próximo tick.
        if (action is MoveAction && step.events.isEmpty) {
          _s = step.state;
        } else {
          _step(step);
        }
      case PeerLeftEvent(:final peerId):
        if (s == null || isClient) return;
        final step = engine.removePlayer(s, peerId);
        if (step != null) _step(step);
      case ConnectionLostEvent(:final reason):
        _disconnected = reason;
        _timer?.cancel();
        _broadcastTimer?.cancel();
        _emit();
    }
  }

  void _hostTick(double dt) {
    final s = _s;
    if (s == null || !mounted) return;
    _sendPosition();
    _sinceSave += dt;
    _step(engine.tick(_s!, dt));
    _save();
  }

  // ------------------------------------------------------------------
  // Jugador local
  // ------------------------------------------------------------------

  /// `updateMe`: mueve al jugador local con la entrada [ix], [iy]
  /// (-1..1). Lo llama el juego Flame en cada frame.
  void updateLocal(double dt, double ix, double iy) {
    final s = _s;
    final me = s?.players[localId];
    if (s == null || me == null) return;
    local.sync(me);
    // Escribiendo en el chat las teclas son texto, no movimiento; con el
    // menú de pausa abierto tampoco se camina.
    if (typing || menuOpen || s.paused) ix = iy = 0;
    local.step(engine.mapFor(s), ix, iy, dt,
        canMove: _canMove(s, me), gateOpen: s.gateOpen);
  }

  /// El campo de chat tiene el foco: no hay movimiento ni atajos.
  bool typing = false;

  /// El menú de pausa está abierto: el jugador local no se mueve. Con
  /// red el mundo sigue salvo que alguien pause al grupo
  /// ([pauseGroup]). Ver docs/specs/settings.md § "Pausa".
  bool menuOpen = false;

  /// La sala está pausada (pausa de grupo; jugando solo, la del menú):
  /// el host no avanza nada.
  bool get paused => _s?.paused ?? false;

  /// Pausa ([on]) o reanuda la sala entera (`PauseAction`). Cualquier
  /// jugador puede hacer las dos cosas.
  bool pauseGroup(bool on) => _apply(PauseAction(on));

  /// Guarda el perfil ya (antes de cerrar la aplicación).
  Future<void> saveNow() async {
    final p = _s?.players[localId]?.profile;
    if (p == null) return;
    _lastSaved = p;
    try {
      await store.save(p);
    } catch (_) {
      // Sin disco: nada que hacer.
    }
  }

  bool _canMove(GameSession s, SessionPlayer me) =>
      (s.mode == SessionMode.lobby || s.mode == SessionMode.field) &&
      me.alive &&
      _panel == null;

  /// `send({t:'pos'})`: la posición local al host (redondeada a 0.1).
  void _sendPosition() {
    final s = _s!;
    final me = s.players[localId];
    if (me == null) return;
    local.sync(me);
    if (!_canMove(s, me)) {
      local.moving = false;
      return;
    }
    final move = MoveAction((local.x * 10).roundToDouble() / 10,
        (local.y * 10).roundToDouble() / 10,
        epoch: local.epoch, dir: local.dir, moving: local.moving);
    if (isClient) {
      net!.sendAction(move);
      return;
    }
    final step = engine.apply(s, localId, move);
    if (step != null) _s = step.state;
  }

  /// Pone al jugador local en (x, y) y se lo informa al host.
  @visibleForTesting
  void teleport(double x, double y) {
    final s = _s;
    final me = s?.players[localId];
    if (s == null || me == null) return;
    local
      ..sync(me)
      ..x = x
      ..y = y;
    _apply(MoveAction(x, y, epoch: local.epoch, dir: local.dir));
  }

  // ------------------------------------------------------------------
  // Interacción
  // ------------------------------------------------------------------

  bool get nearCounter =>
      _s?.mode == SessionMode.lobby && WorldRules.nearCounter(local.x, local.y);

  bool get nearArmory =>
      _s?.mode == SessionMode.lobby && WorldRules.nearArmory(local.x, local.y);

  /// Frente al Portal del Eco del pueblo (ecos_atlas.md § 1).
  bool get nearPortal =>
      _s?.mode == SessionMode.lobby && WorldRules.nearPortal(local.x, local.y);

  /// `nearSeal`: el sello sin activar más cercano a menos de 26 px.
  MissionItem? get nearSeal {
    final s = _s;
    if (s == null || s.mode != SessionMode.field) return null;
    for (final it in s.mission?.items ?? const <MissionItem>[]) {
      if (it.kind == MissionItemKind.seal &&
          !it.done &&
          WorldRules.distance(local.x, local.y, it.x, it.y) <
              WorldRules.sealPromptRange) {
        return it;
      }
    }
    return null;
  }

  /// `nearMerchant` (el prototipo nunca genera mercader).
  bool get nearMerchant {
    final s = _s;
    if (s == null || s.mode != SessionMode.field) return false;
    final m = engine.mapFor(s).merchant;
    return m != null && WorldRules.distance(local.x, local.y, m.x, m.y) < 40;
  }

  /// La entrada de zona frente al jugador local (mapa del mundo).
  ZoneEntrance? get nearEntrance {
    final s = _s;
    if (s == null || s.mode != SessionMode.lobby) return null;
    return WorldRules.nearEntrance(engine.mapFor(s), local.x, local.y);
  }

  /// La escalera del piso actual bajo el jugador local (campo).
  StairsKind? get nearStairs {
    final s = _s;
    if (s == null || s.mode != SessionMode.field || s.mission == null) {
      return null;
    }
    return WorldRules.nearStairs(engine.mapFor(s), local.x, local.y);
  }

  /// Las 10 zonas con su estado para el jugador local.
  List<ZoneStatus> get zones {
    final me = _s?.players[localId];
    if (me == null) return const [];
    return ZoneRules.zoneList(engine.catalog, me.profile);
  }

  /// La zona [index] con su estado para el jugador local.
  ZoneStatus? zoneStatus(int index) {
    for (final z in zones) {
      if (z.zone.index == index) return z;
    }
    return null;
  }

  /// E frente a la entrada [e]: propone la misión de la zona o vota que
  /// sí si ya hay votación por ella. Devuelve si mandó algo.
  bool enterZone(ZoneEntrance e) {
    final s = _s;
    final z = zoneStatus(e.zone);
    if (s == null || z == null) return false;
    return switch (entranceAction(z, s.vote, localId)) {
      EntranceAction.propose => proposeMission(z.mission!.id),
      EntranceAction.voteYes => vote(true),
      EntranceAction.none => false,
    };
  }

  /// E / Espacio.
  void interact() {
    final s = _s;
    if (s == null || _panel != null) return;
    if (s.mode == SessionMode.lobby) {
      if (nearCounter) {
        openPanel(WorldPanel.missionBoard);
      } else if (nearArmory) {
        openPanel(WorldPanel.armory);
      } else if (nearPortal) {
        openPanel(WorldPanel.ecoPortal);
      } else if (nearEntrance case final e?) {
        enterZone(e);
      }
    } else if (s.mode == SessionMode.field) {
      final seal = nearSeal;
      if (seal != null) {
        _apply(ActivateSealAction(seal.id));
      } else if (nearStairs case final k?) {
        useStairs(down: k == StairsKind.down);
      }
    }
  }

  /// Teclas del mapa (no de batalla). Devuelve si la tecla es del juego
  /// (para que no mueva el foco entre botones). Ver la tabla del spec.
  bool handleKey(LogicalKeyboardKey key) {
    final s = _s;
    if (s == null) return false;
    if (key == LogicalKeyboardKey.keyE || key == LogicalKeyboardKey.space) {
      interact();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      closePanel();
      return true;
    }
    if (key == LogicalKeyboardKey.keyC && s.mode != SessionMode.battle) {
      toggleCharacter();
      return true;
    }
    if (key == LogicalKeyboardKey.keyI && s.mode != SessionMode.battle) {
      toggleInventory();
      return true;
    }
    final v = s.vote;
    if (s.mode == SessionMode.lobby &&
        v != null &&
        !v.yes.contains(localId) &&
        (key == LogicalKeyboardKey.keyY || key == LogicalKeyboardKey.keyN)) {
      vote(key == LogicalKeyboardKey.keyY);
      return true;
    }
    return movementKeys.contains(key) || key == LogicalKeyboardKey.tab;
  }

  /// Teclas que se leen del estado del teclado en cada frame.
  static final movementKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  // ------------------------------------------------------------------
  // Paneles
  // ------------------------------------------------------------------

  void openPanel(WorldPanel panel) {
    if (_s == null) return;
    _panel = panel;
    _emit();
  }

  /// `closePanel`: no cierra si hay que repartir puntos; en preparación
  /// vuelve al panel de preparación.
  void closePanel() {
    final s = _s;
    if (s == null || _panel == null || s.mustAllocate(localId)) return;
    if (s.mode == SessionMode.prep) {
      if (_panel == WorldPanel.prep) return;
      _panel = WorldPanel.prep;
    } else {
      _panel = null;
    }
    _emit();
  }

  void toggleCharacter() {
    if (_panel == WorldPanel.character) {
      closePanel();
    } else {
      openPanel(WorldPanel.character);
    }
  }

  /// Tecla I: el personaje en la pestaña INVENTARIO.
  void toggleInventory() {
    if (_panel == WorldPanel.inventory) {
      closePanel();
    } else {
      openPanel(WorldPanel.inventory);
    }
  }

  // ------------------------------------------------------------------
  // Acciones (cada una devuelve si el host la aceptó)
  // ------------------------------------------------------------------

  bool proposeMission(String missionId) =>
      _apply(ProposeMissionAction(missionId));

  bool vote(bool yes) => _apply(VoteMissionAction(yes));

  /// Bajar (`>`) o subir (`<`) de piso con todo el grupo.
  bool useStairs({required bool down}) => _apply(UseStairsAction(down: down));

  bool setReady(bool ready) => _apply(ReadyAction(ready));

  bool cancelPrep() => _apply(const CancelPrepAction());

  bool changeClass(String classId) => _apply(ChangeClassAction(classId));

  bool allocate(Map<Attribute, int> add) => _apply(AllocateStatsAction(add));

  bool battleCommand(BattleCommand command) => _apply(BattleAction(command));

  bool backToLobby() => _apply(const BackToLobbyAction());

  /// "Reiniciar puntos".
  bool respec() => _apply(const RespecAction());

  bool equip(String weaponId) => _apply(EquipAction(weaponId));

  bool buyWeapon(String weaponId) => _apply(BuyWeaponAction(weaponId));

  bool buyItem(BattleItem item) => _apply(BuyItemAction(item));

  bool upgrade(String weaponId, UpgradeStat stat) =>
      _apply(UpgradeAction(weaponId, stat));

  bool fuse(String baseWeaponId, String sacrificeWeaponId, String skillId) =>
      _apply(FuseAction(baseWeaponId, sacrificeWeaponId, skillId));

  // ---- loot v2 (loot.md § 19): el host valida todo ----

  /// Forja y fusión libre (solo lobby / preparación).
  bool craft(CraftAction a) => _apply(a);

  /// Dar [count] de [token] (`uid`, `pot`, `eter`, `mat:<material>`) a
  /// otro jugador de la sala.
  bool give(String toPlayerId, String token, {int count = 1}) =>
      _apply(GiveItemAction(toPlayerId, token, count: count));

  /// Soltar al piso (compartido).
  bool dropItem(String token, {int count = 1}) =>
      _apply(DropItemAction(token, count: count));

  /// Levantar del piso (E).
  bool pickUp(int groundId) => _apply(PickUpAction(groundId));

  /// Intercambiar dos casillas del inventario.
  bool moveInventory(int from, int to) =>
      _apply(MoveInventoryAction(from, to));

  /// Guardar el filtro de loot (`null` = el por defecto).
  bool setLootFilter(String? text) => _apply(SetLootFilterAction(text));

  bool takeNode(String nodeId) => _apply(TakeNodeAction(nodeId));

  bool resetTree() => _apply(const ResetTreeAction());

  // ---- endgame (docs/specs/ecos_atlas.md) ----

  /// Abrir un Eco propio (propone la misión del Eco).
  bool proposeEco(String uid) => _apply(ProposeEcoAction(uid));

  /// Craftear un Eco del inventario.
  bool ecoCraft(String uid, EcoCraftOp op) => _apply(EcoCraftAction(uid, op));

  /// Solo desarrollo: un Eco Raro de [tier] (el motor la rechaza sin
  /// `devTools`).
  bool devGrantEco(int tier) => _apply(DevGrantEcoAction(tier));

  /// Enter en el campo de chat (`send({t:'chat'})`).
  bool sendChat(String text) => _apply(ChatAction(text));

  /// Local / host: aplica la acción y devuelve si el motor la aceptó.
  /// Cliente: la manda al host y devuelve `true` (enviada); el resultado
  /// llega con un snapshot.
  bool _apply(SessionAction action) {
    final s = _s;
    if (s == null) return false;
    if (isClient) {
      net!.sendAction(action);
      return true;
    }
    final step = engine.apply(s, localId, action);
    if (step == null) return false;
    _step(step);
    return true;
  }

  // ------------------------------------------------------------------
  // Estado
  // ------------------------------------------------------------------

  void _step(SessionStep step) {
    _s = step.state;
    if (role == SessionRole.host) _unsent.addAll(step.events);
    var forceSave = false;
    // Un mismo tick puede traer varios pasos de batalla (p. ej. el turno
    // del enemigo y el inicio del siguiente): se juntan todos para que la
    // UI anime cada uno, en orden.
    List<BattleEvent>? stepBattleEvents;
    for (final e in step.events) {
      switch (e) {
        case SystemMessageEvent(:final text):
          _messages.add(text);
          if (_messages.length > maxMessages) _messages.removeAt(0);
          _addChat(ChatLine.system(text));
        case ChatMessageEvent(:final from, :final text):
          _addChat(ChatLine(from, text));
        // Pausa de grupo: aviso en el chat (jugando solo no hace falta).
        case PausedEvent(:final name) when net != null:
          _addChat(ChatLine.system('$name pausó el juego'));
        case ResumedEvent(:final name) when net != null:
          _addChat(ChatLine.system('$name reanudó el juego'));
        case BattleStepEvent(:final events):
          (stepBattleEvents ??= []).addAll(events);
        case BattleStartedEvent():
          _battleEvents = const [];
          stepBattleEvents = null;
        case MissionStartedEvent():
          _missionLoot.clear();
          _atlasGain = null;
        case EcoCompletedEvent():
          _onEcoCompleted(e);
        case LootDropEvent(:final playerId, :final drop)
            when playerId == localId:
          _missionLoot.add(drop);
        case MissionEndedEvent() || ReturnedToLobbyEvent():
          forceSave = true;
        default:
          break;
      }
      if (!_events.isClosed) _events.add(e);
    }
    if (stepBattleEvents != null) {
      _battleEvents = List.unmodifiable(stepBattleEvents);
      _battleSeq++;
    }
    final me = _s!.players[localId];
    if (me != null) local.sync(me);
    if (forceSave) _save(force: true);
    _emit();
  }

  void _addChat(ChatLine line) {
    _chat.add(line);
    if (_chat.length > maxMessages) _chat.removeAt(0);
  }

  void _save({bool force = false}) {
    final p = _s?.players[localId]?.profile;
    if (p == null || identical(p, _lastSaved)) return;
    if (!force && _sinceSave < saveEvery) return;
    final last = _lastSaved;
    _lastSaved = p;
    // El cliente recibe un perfil nuevo (otro objeto) en cada snapshot:
    // solo se guarda si cambió de verdad.
    if (last != null && jsonEncode(last.toJson()) == jsonEncode(p.toJson())) {
      return;
    }
    _sinceSave = 0;
    unawaited(store.save(p).catchError((Object _) {}));
  }

  /// Reglas automáticas de paneles de `hud()` + avisos, y emite la vista.
  void _emit() {
    if (!mounted) return;
    final s = _s;
    if (s == null) {
      // Un cliente puede perder la sala antes del primer snapshot.
      if (_disconnected != null) {
        final empty = engine.create();
        state = SessionView(
          session: empty,
          localId: localId,
          map: engine.mapFor(empty),
          disconnected: _disconnected,
        );
      }
      return;
    }
    final mode = s.mode;
    final must = s.mustAllocate(localId);
    if (mode == SessionMode.prep &&
        (_panel == null ||
            _panel == WorldPanel.missionBoard ||
            _panel == WorldPanel.armory)) {
      _panel = WorldPanel.prep;
    }
    if (_panel == WorldPanel.prep && mode != SessionMode.prep) _panel = null;
    if ((_panel == WorldPanel.character || _panel == WorldPanel.inventory) &&
        mode == SessionMode.field &&
        _lastMode == SessionMode.prep) {
      _panel = null;
    }
    _lastMode = mode;
    if ((_panel == WorldPanel.missionBoard ||
            _panel == WorldPanel.armory ||
            _panel == WorldPanel.ecoPortal) &&
        mode != SessionMode.lobby) {
      _panel = null;
    }
    if (must && _panel != WorldPanel.character) {
      _panel = WorldPanel.character;
      _autoChar = true;
    }
    if (_autoChar && !must) {
      _autoChar = false;
      if (_panel == WorldPanel.character) _panel = null;
    }
    if (mode == SessionMode.battle || mode == SessionMode.result) _panel = null;

    final (prompt, promptText) = _prompt();
    state = SessionView(
      session: s,
      localId: localId,
      map: engine.mapFor(s),
      panel: _panel,
      prompt: prompt,
      promptText: promptText,
      messages: List.unmodifiable(_messages),
      chat: List.unmodifiable(_chat),
      battleEvents: _battleEvents,
      battleEventSeq: _battleSeq,
      roomCode: net?.roomCode,
      disconnected: _disconnected,
      missionLoot: List.unmodifiable(_missionLoot),
      atlas: _atlas,
      atlasGain: _atlasGain,
    );
  }

  (WorldPrompt?, String?) _prompt() {
    if (_panel != null) return (null, null);
    if (nearArmory) return (WorldPrompt.armory, null);
    if (nearPortal) return (WorldPrompt.ecoPortal, null);
    if (nearCounter) return (WorldPrompt.missionBoard, null);
    if (nearSeal != null) return (WorldPrompt.seal, null);
    if (nearStairs case final k?) {
      return (WorldPrompt.stairs, stairsPromptText(k, _s!.mission!.floor));
    }
    if (nearEntrance case final e?) {
      final z = zoneStatus(e.zone);
      if (z != null) {
        return (
          WorldPrompt.entrance,
          entrancePromptText(z, _s!.vote, localId),
        );
      }
    }
    if (nearMerchant) return (WorldPrompt.merchant, null);
    return (null, null);
  }
}
