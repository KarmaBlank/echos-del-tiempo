import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_flags.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/persistence/ecos_log.dart';
import '../../../core/persistence/exit_guard.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/atlas_store.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../../game_engine/models/build_wants.dart';
import '../../../game_engine/models/loot_filter.dart' show FilterVerdict;
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/battle_event.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/game_map.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/inventory_sort.dart';
import '../../../game_engine/models/party_store.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/profile_store.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/models/session_event.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/models/tutorial_store.dart';
import '../../../game_engine/rules/abyss_rules.dart';
import '../../../game_engine/rules/atlas_rules.dart';
import '../../../game_engine/rules/companion_ai.dart';
import '../../../game_engine/rules/consumable_rules.dart';
import '../../../game_engine/rules/exploration_rules.dart';
import '../../../game_engine/rules/session_engine.dart';
import '../../../game_engine/rules/tutorial_rules.dart';
import '../../../game_engine/rules/world_rules.dart';
import '../../../game_engine/rules/zone_rules.dart';
import '../../../netcode/contracts/net_session.dart';
import '../../../netcode/contracts/net_session_factory.dart';
import '../../ascension/domain/ascension_text.dart';
import '../../characters/data/account_repository.dart';
import '../../characters/domain/stash.dart';
import '../../characters/presentation/characters_providers.dart';
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

final profileStoreProvider =
    Provider<ProfileStore>((ref) => sl<ProfileStore>());

/// El Atlas de la cuenta (docs/specs/ecos_atlas.md § 5); sin registro
/// (tests), uno en memoria.
final atlasStoreProvider = Provider<AtlasStore>((ref) =>
    sl.isRegistered<AtlasStore>() ? sl<AtlasStore>() : InMemoryAtlasStore());

/// El bestiario de la cuenta (docs/specs/bestiary.md § 2); sin registro
/// (tests), uno en memoria.
final bestiaryStoreProvider = Provider<BestiaryStore>((ref) =>
    sl.isRegistered<BestiaryStore>()
        ? sl<BestiaryStore>()
        : InMemoryBestiaryStore());

/// Los compañeros de la party jugando solo (docs/specs/solo_party.md
/// § 5); sin registro (tests), sobre la cuenta de
/// [accountRepositoryProvider].
final partyStoreProvider = Provider<PartyStore>((ref) =>
    sl.isRegistered<PartyStore>()
        ? sl<PartyStore>()
        : AccountPartyStore(ref.watch(accountRepositoryProvider)));

/// La bandera del TUTORIAL de la cuenta (docs/specs/combat_tutorial.md
/// § 2); sin registro (tests), una en memoria ya completada (los tests de
/// siempre no quedan bloqueados por el sello).
final tutorialStoreProvider = Provider<TutorialStore>((ref) =>
    sl.isRegistered<TutorialStore>()
        ? sl<TutorialStore>()
        : InMemoryTutorialStore(kTutorialVersion));

/// El alijo de la cuenta en partida (characters.md § 3.2); sin registro
/// (tests), sobre [accountRepositoryProvider].
final stashStoreProvider = Provider<StashStore>((ref) =>
    sl.isRegistered<StashStore>()
        ? sl<StashStore>()
        : AccountStashStore(ref.watch(accountRepositoryProvider)));

final sessionClockProvider =
    Provider<SessionClock>((ref) => const SessionClock());

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
    bestiaryStore: ref.watch(bestiaryStoreProvider),
    tutorialStore: ref.watch(tutorialStoreProvider),
    stashStore: ref.watch(stashStoreProvider),
    clock: ref.watch(sessionClockProvider),
    net: ref.read(activeNetSessionProvider),
    turnTimer: ref.read(gameSettingsProvider).turnTimer,
    // Sin FeatureFlags.soloParty no hay compañeros (solo_party.md § 0).
    party: FeatureFlags.instance.soloParty
        ? ref.read(partyStoreProvider)
        : null,
  );
  // Tiempo de turno (accessibility.md § 7): el ajuste local manda en la
  // sala si este dispositivo corre el motor (solo o anfitrión).
  ref.listen(gameSettingsProvider.select((s) => s.turnTimer),
      (_, t) => c.setTurnTimer(t));
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
    BestiaryStore? bestiaryStore,
    TutorialStore? tutorialStore,
    TurnTimer turnTimer = TurnTimer.normal,
    this.party,
    this.stashStore,
  })  : localId = net?.localId ?? localId,
        _turnTimer = turnTimer,
        atlasStore = atlasStore ?? InMemoryAtlasStore(),
        bestiaryStore = bestiaryStore ?? InMemoryBestiaryStore(),
        tutorialStore = tutorialStore ?? InMemoryTutorialStore(kTutorialVersion),
        super(null);

  /// Compañeros de la party jugando solo (docs/specs/solo_party.md);
  /// `null` = sin party. Con red no se usa (en salas no hay compañeros).
  final PartyStore? party;

  /// El alijo de la cuenta (characters.md § 3.2); `null` = sin alijo.
  final StashStore? stashStore;

  /// Compañeros en la sala: id de jugador → ranura de la cuenta, en orden.
  final _companions = <String, String>{};

  /// Compañeros con AUTO prendido (ids de jugador).
  final _auto = <String>{};

  /// Plan de build de cada compañero (para ver su filtro en la UI).
  final _companionWants = <String, BuildWants?>{};

  /// El último perfil de cada compañero mandado a guardar.
  final _companionSaved = <String, PlayerProfile>{};

  static const _ai = CompanionAi();

  /// Segundos de juego que espera un compañero con AUTO antes de actuar.
  static const autoDelay = 0.5;

  /// Id de jugador del compañero de la ranura [slotId] (`local-c2`).
  String companionIdFor(String slotId) => '$localId-$slotId';

  /// Los compañeros en la sala, en orden (ids de jugador).
  List<String> get companionIds => List.unmodifiable(_companions.keys);

  /// La ranura de la cuenta del compañero [playerId] (o `null`).
  String? slotOf(String playerId) => _companions[playerId];

  /// Este dispositivo actúa como [playerId]: el local o un compañero.
  bool controls(String? playerId) =>
      playerId == localId || _companions.containsKey(playerId);

  bool isAuto(String playerId) => _auto.contains(playerId);

  /// Miembro activo elegido en el selector (solo_party.md § 6); `null` =
  /// el jugador local.
  String? _acting;

  /// Sobre quién actúan las acciones de personaje, inventario y tiendas:
  /// el compañero elegido si sigue en la sala, si no el jugador local.
  String get actingId {
    final a = _acting;
    return a != null &&
            _companions.containsKey(a) &&
            (_s?.players.containsKey(a) ?? false)
        ? a
        : localId;
  }

  /// Los miembros de la party de este dispositivo en orden: el local y
  /// sus compañeros.
  List<String> get members => [localId, ..._companions.keys];

  /// Elige el miembro activo (el local o uno de sus compañeros). No se
  /// puede mientras el líder reparte su subida de nivel.
  bool setActing(String playerId) {
    final s = _s;
    if (s == null || !controls(playerId) || s.mustAllocate(localId)) {
      return false;
    }
    final next = playerId == localId ? null : playerId;
    if (next == _acting) return true;
    _acting = next;
    _emit();
    return true;
  }

  /// Miembro anterior (`-1`) / siguiente (`+1`), en círculo (`Ctrl+←/→`).
  bool cycleActing(int delta) {
    final list = members;
    if (list.length < 2) return false;
    final i = list.indexOf(actingId);
    return setActing(list[(i + delta) % list.length]);
  }

  /// Prende / apaga el AUTO de un compañero (se recuerda en la cuenta).
  void setAuto(String playerId, bool on) {
    final slot = _companions[playerId];
    if (slot == null || isAuto(playerId) == on) return;
    on ? _auto.add(playerId) : _auto.remove(playerId);
    final ps = party;
    if (ps != null) {
      unawaited(ps.setAuto(slot, on).catchError((Object e) {
        EcosLog.error('Guardado de la party', e);
      }));
    }
    _emit();
  }

  /// Se puede cambiar la party ahora: solo, en el pueblo, sin votación
  /// ni preparación (solo_party.md § 2.3).
  bool get canEditParty {
    final s = _s;
    return net == null &&
        party != null &&
        s != null &&
        SessionEngine.canChangeParty(s);
  }

  /// Carga la party de la cuenta (al empezar, jugando solo).
  Future<void> _loadParty() async {
    final ps = party;
    if (ps == null || net != null) return;
    List<CompanionSlot> list;
    try {
      list = await ps.load();
    } catch (e) {
      EcosLog.error('Carga de la party', e);
      return;
    }
    if (!mounted) return;
    for (final c in list) {
      _addCompanion(c);
    }
    _save(force: true);
  }

  bool _addCompanion(CompanionSlot c) {
    final s = _s;
    if (s == null) return false;
    final id = companionIdFor(c.slotId);
    // Jefes del Abismo vencidos por la cuenta, como el líder.
    final step = engine.addCompanion(
        s, id, AbyssRules.withAccount(c.profile, atlas),
        leaderId: localId);
    if (step == null) return false;
    _companions[id] = c.slotId;
    if (c.auto) _auto.add(id);
    _companionWants[id] = c.wants;
    _step(step);
    if (c.wants case final w?) _applyFor(id, SetBuildWantsAction(w));
    return true;
  }

  /// Cambia la party en el pueblo (ids de ranura, en orden, hasta 3):
  /// los que salen se guardan y dejan la sala, los que entran cargan su
  /// perfil de la cuenta. Devuelve si se pudo.
  Future<bool> setParty(List<String> slotIds) async {
    final ps = party;
    if (ps == null || !canEditParty) return false;
    for (final id in [..._companions.keys]) {
      if (slotIds.contains(_companions[id])) continue;
      await _saveCompanionNow(id);
      final s = _s;
      final step = s == null ? null : engine.removeCompanion(s, id);
      if (step == null) continue;
      _companions.remove(id);
      if (_acting == id) _acting = null;
      _auto.remove(id);
      _companionWants.remove(id);
      _companionSaved.remove(id);
      _step(step);
    }
    try {
      await ps.setCompanions(slotIds);
    } catch (e) {
      _saveFailed(e);
    }
    List<CompanionSlot> list;
    try {
      list = await ps.load();
    } catch (e) {
      EcosLog.error('Carga de la party', e);
      list = const [];
    }
    if (!mounted) return false;
    for (final c in list) {
      if (!_companions.containsValue(c.slotId)) _addCompanion(c);
    }
    _save(force: true);
    _emit();
    return true;
  }

  /// El bestiario de la cuenta de este dispositivo (bestiary.md § 2): se
  /// actualiza solo con lo que este jugador ve ganar (eventos y estado de
  /// la batalla), también como cliente; no viaja por la red.
  final BestiaryStore bestiaryStore;

  /// La bandera `tutV` de la cuenta (docs/specs/combat_tutorial.md § 2).
  final TutorialStore tutorialStore;

  /// `tutV` de esta cuenta (cargada al empezar).
  int _tutorialVersion = 0;
  int get tutorialVersion => _tutorialVersion;

  /// Las reglas del TUTORIAL de la sala (las del motor).
  TutorialRules get tutorialRules => engine.tutorials;

  /// Se completó el TUTORIAL con este jugador adentro: marca la cuenta.
  void _onTutorialDone(int version) {
    if (version <= _tutorialVersion) return;
    _tutorialVersion = version;
    unawaited(tutorialStore.save(version).catchError((Object e) {
      EcosLog.error('Guardado del tutorial', e);
      _saveFailed(e);
    }));
  }

  /// Empieza el TUTORIAL desde el sello (§ 1): en grupo (host, entran
  /// todos), solo, o solo con los compañeros de la party.
  bool startTutorial({bool companions = true}) =>
      _apply(StartTutorialAction(companions: companions));

  /// SIGUIENTE ("Leí y entendí", ESPACIO / Enter): el voto de este
  /// jugador para cerrar el cartel del tutorial. El host avanza cuando
  /// votaron todos los humanos de la sala.
  bool ackTutorial() => _apply(const TutorialAckAction());

  /// El cartel del tutorial abierto (espera la votación).
  TutorialCard? get tutorialCard => _s?.tutorial?.card;

  /// Este jugador ya votó SIGUIENTE en el cartel abierto.
  bool get tutorialVoted => _s?.tutorial?.votes.contains(localId) ?? false;
  /// Menú de pausa del tutorial: Repetir, Repetir etapa, Salir.
  bool tutorialControl(TutorialControl op) =>
      _apply(TutorialControlAction(op));

  /// Voto en las votaciones del final del tutorial (Repetir con otros
  /// roles / ENTRENAR / Salir, el rol elegido, Reiniciar).
  bool tutorialPick(String choice) => _apply(TutorialChoiceAction(choice));
  BestiaryProgress? _bestiary;

  /// La última batalla vista (para saber a quiénes se venció cuando
  /// llega `BattleFinishedEvent`, que puede venir ya sin batalla).
  BattleState? _lastBattle;

  /// Lo que desbloqueó la última victoria (para el aviso del chat).
  Set<String> lastUnlocked = const {};

  /// El bestiario local (vacío hasta cargarlo).
  BestiaryProgress get bestiary => _bestiary ?? BestiaryProgress.empty;

  /// El Atlas de la cuenta de este dispositivo (ecos_atlas.md § 5).
  final AtlasStore atlasStore;
  AtlasProgress? _atlas;
  AtlasGain? _atlasGain;
  static const _atlasRules = AtlasRules();

  /// Tiempo de turno local (ajuste JUEGO → TIEMPO DE TURNO). Solo vale
  /// en la sala si este dispositivo corre el motor; un cliente ve el del
  /// anfitrión en `session.turnTimer`.
  TurnTimer _turnTimer;
  TurnTimer get turnTimer => _turnTimer;

  /// Cambia el tiempo de turno local; jugando solo o como anfitrión, lo
  /// aplica a la sala (docs/specs/accessibility.md § 7).
  void setTurnTimer(TurnTimer t) {
    _turnTimer = t;
    final s = _s;
    if (isClient || s == null || !mounted) return;
    _s = engine.setTurnTimer(s, t).state;
    _emit();
  }

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
    // Cerrar la ventana (o actualizar) a mitad de partida guarda antes.
    ExitGuard.register(this, saveNow);
    final n = net;
    if (isClient) {
      // Antes del primer snapshot: un Eco completado tiene que sumar al
      // Atlas de la cuenta, no a uno vacío que lo pisaría.
      await _loadAtlas();
      if (!mounted) return;
      try {
        _tutorialVersion = await tutorialStore.load();
      } catch (_) {}
      if (!mounted) return;
      await _loadStash();
      if (!mounted) return;
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
    await _loadStash();
    if (!mounted) return;
    await _loadAtlas();
    if (!mounted) return;
    // Jefes del Abismo vencidos por la cuenta (abyss_bosses.md § 1.3).
    profile = AbyssRules.withAccount(profile, atlas);
    // El Atlas del anfitrión vale para toda la sala (ecos_atlas.md § 5.2).
    // Y su tiempo de turno (accessibility.md § 7).
    final room = engine.setTurnTimer(
        engine.setAtlas(engine.create(), atlas.nodes).state, _turnTimer);
    try {
      _tutorialVersion = await tutorialStore.load();
    } catch (_) {
      _tutorialVersion = 0; // sin disco: el sello pide el tutorial
    }
    if (!mounted) return;
    var step = engine.addPlayer(room.state, localId, profile,
        tutorialVersion: _tutorialVersion)!;
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
    _syncWants();
    _save(force: true);
    // Party jugando solo (solo_party.md § 2): las otras ranuras elegidas.
    await _loadParty();
    if (!mounted) return;
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
    try {
      _bestiary = await bestiaryStore.load();
    } catch (_) {
      _bestiary = BestiaryProgress(); // ídem con el bestiario
    }
  }

  /// Batalla ganada con este jugador adentro: suma las muertes al
  /// bestiario de SU cuenta (bestiary.md § 2.2). Solo, anfitrión o
  /// cliente: sale del estado que ya llega a este dispositivo.
  void _onBattleWon() {
    final b = _lastBattle;
    _lastBattle = null;
    if (b == null || !b.party.any((p) => p.id == localId)) return;
    final kills = bestiaryKills(b);
    if (kills.isEmpty) return;
    final before = bestiary;
    final next = before.record(kills);
    lastUnlocked = before.newIn(kills);
    _bestiary = next;
    for (final t in lastUnlocked) {
      final name = engine.battles.catalog.enemies[t]?.name ?? t;
      _addChat(ChatLine.system('Bestiario: $name agregado'));
    }
    unawaited(bestiaryStore.save(next).catchError((Object e) {
      EcosLog.error('Guardado del bestiario', e);
      _saveFailed(e);
    }));
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
    claimAchievement('atlas_node');
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
    unawaited(atlasStore.save(next).catchError((Object e) {
      EcosLog.error('Guardado del Atlas', e);
      _saveFailed(e);
    }));
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
    final g =
        _atlasRules.complete(atlas, tier: e.tier, zone: e.zone, boss: e.boss);
    _atlasGain = g;
    if (g.points > 0) _setAtlas(g.progress, emit: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _broadcastTimer?.cancel();
    unawaited(_netSub?.cancel());
    _save(force: true);
    ExitGuard.unregister(this);
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
    _retryStash(dt);
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
        if (isClient) {
          _step(SessionStep(session, events));
          _syncWants();
        }
      case PeerJoinedEvent(:final peerId, :final profile, :final tutorialVersion):
        if (s == null || isClient) return;
        final step = engine.addPlayer(s, peerId, profile,
            tutorialVersion: tutorialVersion);
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
        _dropStashOp('Se perdió la conexión: no se movió nada');
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
    _autoTurn();
    _save();
  }

  /// Turno de un compañero con AUTO (solo_party.md § 4.1).
  void _autoTurn() {
    final s = _s;
    final b = s?.battle;
    if (s == null || b == null || s.paused || !b.waitingForPlayer) return;
    final cur = b.state.currentId;
    if (cur == null || !_auto.contains(cur) || b.turnTime < autoDelay) {
      return;
    }
    final pick = _ai.choose(b.state, cur);
    for (final c in [if (pick != null) pick, ...CompanionAi.fallbacks]) {
      if (_applyFor(cur, BattleAction(c))) return;
    }
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
        canMove: _canMove(s, me),
        gateOpen: s.gateOpen,
        // Viento del Eco (worldgen.md § 11.3).
        speedMult: s.mode == SessionMode.field
            ? ExplorationRules.speedMult(s.mission, s.time)
            : 1);
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
    for (final id in [..._companions.keys]) {
      await _saveCompanionNow(id);
    }
    final p = _s?.players[localId]?.profile;
    if (p == null) return;
    _lastSaved = p;
    try {
      await store.save(p);
      _saveOk(p);
    } catch (e) {
      // Queda marcado para reintentar; el HUD avisa.
      if (identical(_lastSaved, p)) _lastSaved = null;
      _saveFailed(e);
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

  /// Frente a la Estatua del Tiempo (ascension.md § 1).
  bool get nearStatue =>
      _s?.mode == SessionMode.lobby && WorldRules.nearStatue(local.x, local.y);

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

  /// El punto de interés del piso actual que el jugador local puede usar
  /// con E (worldgen.md § 11.3), o `null`.
  MapPoi? get nearPoi {
    final s = _s;
    final m = s?.mission;
    if (s == null || m == null || s.mode != SessionMode.field) return null;
    final f = engine.mapFor(s).floor(m.floor);
    if (f == null) return null;
    final p = ExplorationRules.usable(f, m, local.x, local.y);
    if (p == null) return null;
    return p;
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
      } else if (nearStatue) {
        openPanel(WorldPanel.ascension);
      } else if (nearEntrance case final e?) {
        enterZone(e);
      }
    } else if (s.mode == SessionMode.field) {
      final seal = nearSeal;
      if (seal != null) {
        _apply(ActivateSealAction(seal.id));
      } else if (nearPoi case final p?) {
        _apply(InteractPoiAction(p.id));
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
    if (key == LogicalKeyboardKey.keyM && s.mode != SessionMode.battle) {
      toggleMap();
      return true;
    }
    if (key == LogicalKeyboardKey.keyI && s.mode != SessionMode.battle) {
      toggleInventory();
      return true;
    }
    if (key == LogicalKeyboardKey.keyB && s.mode != SessionMode.battle) {
      toggleStash();
      return true;
    }
    // Atajos de pociones fuera de batalla (exploration.md): 1 vida, 2 maná.
    if (s.mode != SessionMode.battle &&
        _panel == null &&
        (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.digit2)) {
      useItem(key == LogicalKeyboardKey.digit1
          ? BattleItem.potion
          : BattleItem.ether);
      return true;
    }
    if (key == LogicalKeyboardKey.keyP && canEditParty) {
      toggleParty();
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

  /// Hay mapa para abrir en grande (tecla M): en un piso de misión o en
  /// el mapa del mundo (lo mismo que muestra el minimapa).
  bool get mapAvailable {
    final s = _s;
    if (s == null) return false;
    final m = engine.mapFor(s);
    return switch (s.mode) {
      SessionMode.field => !m.lobby && s.mission != null,
      SessionMode.lobby => m.entrances.isNotEmpty,
      _ => false,
    };
  }

  /// Tecla M: abre / cierra el mapa en grande (v0.8.1).
  void toggleMap() {
    if (_panel == WorldPanel.map) {
      closePanel();
    } else if (_panel == null && mapAvailable) {
      openPanel(WorldPanel.map);
    }
  }

  /// Tecla P / botón `PARTY`: el panel de la party (solo, en el pueblo).
  void toggleParty() {
    if (_panel == WorldPanel.party) {
      closePanel();
    } else if (_panel == null && canEditParty) {
      openPanel(WorldPanel.party);
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

  bool changeClass(String classId) =>
      _applyFor(actingId, ChangeClassAction(classId));

  bool allocate(Map<Attribute, int> add) =>
      _applyFor(actingId, AllocateStatsAction(add));

  /// El comando de quien tiene el turno si lo controla este dispositivo
  /// (el local o un compañero; solo_party.md § 4); si no, del local.
  bool battleCommand(BattleCommand command) {
    final cur = _s?.battle?.state.currentId;
    return _applyFor(
        _companions.containsKey(cur) ? cur! : localId, BattleAction(command));
  }

  /// Comando de batalla de [actorId] (el local o un compañero).
  bool battleCommandFor(String actorId, BattleCommand command) =>
      _applyFor(actorId, BattleAction(command));

  bool backToLobby() => _apply(const BackToLobbyAction());

  /// "Reiniciar puntos".
  bool respec() => _applyFor(actingId, const RespecAction());

  bool equip(String weaponId) => _applyFor(actingId, EquipAction(weaponId));

  bool buyWeapon(String weaponId) =>
      _applyFor(actingId, BuyWeaponAction(weaponId));

  bool buyItem(BattleItem item) => _applyFor(actingId, BuyItemAction(item));

  /// Motivo por el que la poción [item] no se puede usar fuera de batalla
  /// ahora ("Vida llena", "No te quedan"...), o `null` (loot.md § 17.5).
  String? useItemBlock(BattleItem item) {
    final s = _s;
    final p = s?.players[actingId];
    if (s == null || p == null) return 'Sin partida';
    return ConsumableRules.blockReason(s, p, item);
  }

  /// Usa una poción fuera de batalla; el host valida y consume.
  bool useItem(BattleItem item) {
    if (useItemBlock(item) != null) return false;
    return _applyFor(actingId, UseItemAction(item));
  }

  bool upgrade(String weaponId, UpgradeStat stat) =>
      _applyFor(actingId, UpgradeAction(weaponId, stat));

  bool fuse(String baseWeaponId, String sacrificeWeaponId, String skillId) =>
      _applyFor(actingId, FuseAction(baseWeaponId, sacrificeWeaponId, skillId));

  // ---- loot v2 (loot.md § 19): el host valida todo ----

  /// Forja y fusión libre (solo lobby / preparación).
  bool craft(CraftAction a) => _applyFor(actingId, a);

  /// Dar [count] de [token] (`uid`, `pot`, `eter`, `mat:<material>`) a
  /// otro jugador de la sala.
  bool give(String toPlayerId, String token, {int count = 1}) =>
      _applyFor(actingId, GiveItemAction(toPlayerId, token, count: count));

  /// Soltar al piso (compartido).
  bool dropItem(String token, {int count = 1}) =>
      _applyFor(actingId, DropItemAction(token, count: count));

  /// Levantar del piso (E).
  bool pickUp(int groundId) => _apply(PickUpAction(groundId));

  /// Intercambiar dos casillas del inventario.
  bool moveInventory(int from, int to) =>
      _applyFor(actingId, MoveInventoryAction(from, to));

  /// ORDENAR el inventario (v0.5.1, loot.md § 17.2).
  bool sortInventory(InventorySortKey key) =>
      _applyFor(actingId, SortInventoryAction(key));

  /// Sacar la marca NUEVO (v0.9.7, loot.md § 17.4).
  bool markSeen(List<String> uids) =>
      _applyFor(actingId, SeenItemsAction(uids));

  /// Hazaña que detecta este dispositivo (achievements.md § 5.2): se le
  /// avisa al host, que la paga una sola vez. Sin efecto si ya estaba o
  /// si no es de las que puede avisar el cliente.
  bool claimAchievement(String id) {
    final me = _s?.players[localId];
    if (me == null ||
        !kClientClaimableAchievements.contains(id) ||
        me.profile.achievements.isDone(id) ||
        !_claimed.add(id)) {
      return false;
    }
    return _apply(ClaimAchievementAction(id));
  }

  final _claimed = <String>{};

  /// Hazañas logradas por este dispositivo (el jugador o sus compañeros)
  /// en la sesión, en orden: el toast las muestra (§ 7).
  final achievementLog = <AchievementUnlockedEvent>[];

  /// Elegir la ULT activa (`null` = automática; ultimates_v2.md § 2.1).
  bool selectUlt(String? id) => _applyFor(actingId, SelectUltAction(id));

  /// Subir un nivel la ULT [id] del repertorio (§ 2.4).
  bool upgradeUlt(String id) => _applyFor(actingId, UpgradeUltAction(id));

  /// Guardar el filtro de loot (`null` = el por defecto).
  bool setLootFilter(String? text) =>
      _applyFor(actingId, SetLootFilterAction(text));

  // ---- plan de build → filtro de loot (build_planner.md § 6) ----

  BuildWants? _localWants;
  bool _wantsSynced = true;

  /// Resumen del plan de build local (`null` = sin plan). Para evaluar
  /// el filtro del jugador local en la UI; nunca el de un compañero.
  BuildWants? get localWants => _localWants;

  /// Cambia el plan local: se manda al host (o se aplica, si somos el
  /// host) al entrar a la sala y cada vez que cambia.
  void setBuildWants(BuildWants? wants) {
    final next = wants == null || wants.isEmpty ? null : wants;
    if (next == _localWants) return;
    _localWants = next;
    _wantsSynced = false;
    _syncWants();
  }

  /// Manda el resumen pendiente cuando ya hay sala (cliente: tras el
  /// primer snapshot).
  void _syncWants() {
    if (_wantsSynced || _s == null || !mounted) return;
    _wantsSynced = true;
    _apply(SetBuildWantsAction(_localWants));
  }

  /// Cambia el plan de build de [playerId] (el local o un compañero; la
  /// pestaña BUILD con el selector de miembro, solo_party.md § 6.2).
  void setMemberWants(String playerId, BuildWants? wants) {
    if (playerId == localId) return setBuildWants(wants);
    if (!_companions.containsKey(playerId)) return;
    final next = wants == null || wants.isEmpty ? null : wants;
    if (next == _companionWants[playerId]) return;
    _companionWants[playerId] = next;
    _applyFor(playerId, SetBuildWantsAction(next));
  }

  /// Cómo ve el jugador [playerId] un drop: con el plan local solo si es
  /// el jugador local (un compañero se evalúa sin plan: no lo conocemos).
  FilterVerdict? lootVerdictFor(String playerId, LootDrop d) {
    final p = _s?.players[playerId]?.profile;
    if (p == null) return null;
    return engine.lootVerdict(p, d,
        wants: playerId == localId
            ? _localWants
            : _companionWants[playerId]);
  }

  bool takeNode(String nodeId) => _applyFor(actingId, TakeNodeAction(nodeId));

  /// Camino en un clic (progression_v2.md § 4).
  bool untakeNode(String nodeId) =>
      _applyFor(actingId, UntakeNodeAction(nodeId));

  bool takeNodes(List<String> ids) =>
      _applyFor(actingId, TakeNodesAction(ids));

  /// Hito del nivel [milestone] (progression_v2.md § 5).
  bool chooseMilestone(int milestone, String keystoneId) =>
      _applyFor(actingId, ChooseMilestoneAction(milestone, keystoneId));

  bool resetTree() => _applyFor(actingId, const ResetTreeAction());

  // ---- endgame (docs/specs/ecos_atlas.md) ----

  /// Abrir un Eco propio (propone la misión del Eco).
  bool proposeEco(String uid) => _apply(ProposeEcoAction(uid));

  /// Abrir el Jefe del Abismo [n] (docs/specs/abyss_bosses.md § 1.2).
  bool proposeAbyss(int n) => _apply(ProposeAbyssAction(n));

  /// Solo desarrollo: Fragmentos (`frag`) o los 4 vencidos (`kills`).
  bool devAbyss(String kind) => _apply(DevAbyssAction(kind));

  /// El último Jefe del Abismo vencido con este jugador y los puntos de
  /// Atlas que dio (para el resultado).
  (int, int)? lastAbyss;

  /// Jefe del Abismo vencido: si este jugador estaba, lo anota en el
  /// Atlas de SU cuenta (`x<n>`, 2–3 puntos la primera vez).
  void _onAbyssDefeated(AbyssDefeatedEvent e) {
    if (!e.playerIds.contains(localId)) return;
    final g = AbyssRules(catalog: engine.catalog).recordAccount(atlas, e.boss);
    lastAbyss = (e.boss, g.points);
    if (g.points > 0) _setAtlas(g.progress, emit: false);
  }

  /// Craftear un Eco del inventario.
  bool ecoCraft(String uid, EcoCraftOp op) =>
      _applyFor(actingId, EcoCraftAction(uid, op));

  /// Solo desarrollo: un Eco Raro de [tier] (el motor la rechaza sin
  /// `devTools`).
  bool devGrantEco(int tier) => _apply(DevGrantEcoAction(tier));

  // ---- ascensión (docs/specs/ascension.md) ----

  /// Proponer la Prueba del Tiempo [n] (cierra la estatua si se aceptó).
  bool proposeTrial(int n) => _apply(ProposeTrialAction(n));

  bool chooseAscension(String id) =>
      _applyFor(actingId, ChooseAscensionAction(id));

  bool takeAscensionNode(String nodeId) =>
      _applyFor(actingId, TakeAscensionNodeAction(nodeId));

  /// Reinicio gratis de los nodos; con [full] además vuelve a la clase base.
  bool resetAscension({bool full = false}) =>
      _applyFor(actingId, ResetAscensionAction(full: full));

  /// La última Prueba completada en esta misión y si el jugador local
  /// ganó sus puntos (para el resultado); `null` si no hubo.
  (int, bool)? lastTrial;

  /// Solo desarrollo: Pruebas 1..[n] superadas.
  bool devGrantTrial(int n) => _apply(DevGrantTrialAction(n));

  /// Abre el panel de la estatua en la pestaña ASCENSIÓN (botón del
  /// resultado de una Prueba).
  bool get canOpenAscension =>
      _s?.mode == SessionMode.lobby || _s?.mode == SessionMode.prep;

  // ------------------------------------------------------------------
  // Alijo en partida (docs/specs/characters.md § 3.2)
  // ------------------------------------------------------------------

  Stash? _stash;
  _StashOp? _stashOp;
  int _stashSeq = 0;
  String? _stashNotice;

  /// Cada cuánto (s de juego) un cliente reenvía la operación sin
  /// confirmar, y cuántas veces antes de darla por perdida.
  static const stashRetryEvery = 1.0;
  static const stashRetries = 5;

  /// El alijo local de la cuenta (`null` = sin alijo o cargando).
  Stash? get stash => _stash;

  /// Hay una operación esperando la confirmación del anfitrión.
  bool get stashBusy => _stashOp != null;

  /// Última línea de resultado (`Movidos N · Quedaron M: ...`).
  String? get stashNotice => _stashNotice;

  StashRules get stashRules =>
      StashRules(inventory: engine.progression.inventory);

  /// Motivo por el que el alijo no se abre ahora, o `null`.
  String? get stashBlock {
    final s = _s;
    if (s == null || _stash == null) return 'Sin alijo';
    if (s.mode != SessionMode.lobby && s.mode != SessionMode.field) {
      return 'Solo en el lobby o en misión, fuera de batalla';
    }
    return null;
  }

  Future<void> _loadStash() async {
    final st = stashStore;
    if (st == null) return;
    try {
      _stash = await st.load();
    } catch (e) {
      EcosLog.error('Alijo', e);
    }
  }

  /// Tecla B / botón ALIJO [B].
  void toggleStash() {
    if (_panel == WorldPanel.stash) {
      closePanel();
    } else {
      openStash();
    }
  }

  bool openStash() {
    if (stashBlock != null) return false;
    _panel = WorldPanel.stash;
    _emit();
    return true;
  }

  String _newStashOpId() =>
      '$localId-${_stashSeq++}-${DateTime.now().microsecondsSinceEpoch}';

  /// Guarda [tokens] del inventario del jugador local en el alijo (uno,
  /// los elegidos o MOVER TODO: una sola operación). Devuelve el motivo
  /// si no se pudo mandar.
  String? stashPut(List<String> tokens, {int tab = 0}) {
    final why = _stashReady();
    if (why != null) return why;
    final me = _s!.players[localId]!;
    final dry = stashRules.depositMany(me.profile, _stash!, tokens, tab: tab);
    if (dry.moved.isEmpty) {
      _emit();
      return _stashNotice = dry.reason ?? 'Nada para mover';
    }
    final id = _newStashOpId();
    return _sendStash(_StashOp(
      id,
      StashPutAction(id, [
        for (final m in dry.moved)
          StashPutItem(m.token!,
              count: m.drop.stack == null ? 1 : m.drop.count),
      ]),
      put: true,
      tab: tab,
      left: dry.left,
      reason: dry.reason,
      cells: const [],
    ));
  }

  /// Saca las casillas [cells] del alijo al inventario del jugador local.
  String? stashTake(List<int> cells) {
    final why = _stashReady();
    if (why != null) return why;
    final me = _s!.players[localId]!;
    final dry = stashRules.withdrawMany(me.profile, _stash!, cells);
    if (dry.moved.isEmpty) {
      _emit();
      return _stashNotice = dry.reason ?? 'Nada para sacar';
    }
    final id = _newStashOpId();
    return _sendStash(_StashOp(
      id,
      StashTakeAction(id, [for (final m in dry.moved) m.drop]),
      put: false,
      tab: 0,
      left: dry.left,
      reason: dry.reason,
      cells: [for (final m in dry.moved) m.cell!],
    ));
  }

  /// Reordena el alijo (solo local: no pasa por el anfitrión).
  bool stashMove(int from, int to) {
    final s = _stash, st = stashStore;
    final me = _s?.players[localId];
    if (s == null || st == null || me == null || _stashOp != null) {
      return false;
    }
    final next = StashRules.move(s, from, to);
    if (next == null) return false;
    _stash = next;
    unawaited(st.commit(next, me.profile).catchError(_saveFailed));
    _emit();
    return true;
  }

  /// Motivo por el que [token] no se puede guardar ahora en el alijo
  /// (menú del inventario), o `null`.
  String? stashPutReason(String token) {
    final why = _stashReady();
    if (why != null) return why;
    if (actingId != localId) return 'El alijo es de tu personaje';
    return stashRules
        .deposit(_s!.players[localId]!.profile, _stash!, token)
        .error;
  }

  String? _stashReady() {
    final why = stashBlock;
    if (why != null) return why;
    if (_stashOp != null) return 'Esperando al anfitrión...';
    if (_s!.players[localId] == null) return 'Sin personaje';
    return null;
  }

  String? _sendStash(_StashOp op) {
    _stashOp = op;
    _stashNotice = null;
    if (!_apply(op.action)) {
      _stashOp = null;
      _stashNotice = 'El anfitrión no lo aceptó';
      _emit();
      return _stashNotice;
    }
    _emit();
    return null;
  }

  void _dropStashOp(String notice) {
    if (_stashOp == null) return;
    _stashOp = null;
    _stashNotice = notice;
  }

  /// Cliente: reenvía la operación sin confirmar (mismo id: el host no
  /// la aplica dos veces).
  void _retryStash(double dt) {
    final op = _stashOp;
    if (op == null || !isClient) return;
    op.wait += dt;
    if (op.wait < stashRetryEvery) return;
    op.wait = 0;
    if (++op.tries > stashRetries) {
      _dropStashOp('El anfitrión no confirmó: no se movió nada');
      _emit();
      return;
    }
    net!.sendAction(op.action);
  }

  /// Con la confirmación en el estado (y el perfil ya cambiado en el mismo
  /// snapshot) recién se escribe el alijo: alijo + perfil en una escritura.
  void _settleStash() {
    final op = _stashOp, me = _s?.players[localId], st = _stash;
    final store = stashStore;
    if (op == null || me == null || st == null || store == null) return;
    final ack = me.stashAcks[op.id];
    if (ack == null) return;
    _stashOp = null;
    var s = st;
    var moved = 0;
    for (var i = 0; i < ack.drops.length; i++) {
      final d = ack.drops[i];
      if (d == null) continue;
      final next = op.put
          ? StashRules.store(s, d, tab: op.tab)
          : i < op.cells.length
              ? StashRules.unstore(s, op.cells[i], d)
              : null;
      if (next == null) {
        EcosLog.error('Alijo: pieza sin lugar en ${op.id}');
        continue;
      }
      s = next;
      moved++;
    }
    _stash = s;
    final left = op.left + ack.drops.length - moved;
    _stashNotice = left == 0
        ? 'Movidos $moved'
        : 'Movidos $moved · Quedaron $left: '
            '${(op.reason ?? 'rechazados').toLowerCase()}';
    final p = me.profile;
    _lastSaved = p;
    unawaited(store.commit(s, p).then((_) => _saveOk(p),
        onError: (Object e) => _saveFailed(e)));
  }

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

  /// Como [_apply] pero actuando como [actorId] (un compañero; el motor
  /// valida que este dispositivo lo controle).
  bool _applyFor(String actorId, SessionAction action) {
    if (actorId == localId) return _apply(action);
    final s = _s;
    if (s == null || isClient) return false;
    final step = engine.applyFor(s, localId, actorId, action);
    if (step == null) return false;
    _step(step);
    return true;
  }

  // ------------------------------------------------------------------
  // Estado
  // ------------------------------------------------------------------

  void _step(SessionStep step) {
    _s = step.state;
    if (step.state.battle case final b?) _lastBattle = b.state;
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
        case ChatMessageEvent(:final playerId, :final from, :final text):
          // Título de la ascensión en el chat: "Ana, Cronomante" (§ 5).
          final prof = _s!.players[playerId]?.profile;
          _addChat(ChatLine(
              prof == null
                  ? from
                  : heroTitle(from, prof.classId, prof.ascension.id),
              text));
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
          lastTrial = null;
          lastAbyss = null;
        case EcoCompletedEvent():
          _onEcoCompleted(e);
        case TutorialDoneEvent(:final playerIds, :final version)
            when playerIds.contains(localId):
          _onTutorialDone(version);
        case AbyssDefeatedEvent():
          _onAbyssDefeated(e);
        case TrialCompletedEvent(:final trial, :final playerIds):
          lastTrial = (trial, playerIds.contains(localId));
        case LootDropEvent(:final playerId, :final drop)
            when playerId == localId:
          _missionLoot.add(drop);
        case BattleFinishedEvent(victory: true):
          _onBattleWon();
        // Hazañas (achievements.md § 5.1): la recompensa ya está en el
        // perfil de sesión; se guarda enseguida en la cuenta.
        case AchievementUnlockedEvent(:final playerId, :final id)
            when controls(playerId):
          achievementLog.add(e);
          final name = kAchievementsById[id]?.name ?? id;
          _addChat(ChatLine.system('Hazaña: $name'));
          forceSave = true;
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
    // Antes de cualquier guardado: alijo + perfil van juntos.
    _settleStash();
    if (forceSave) _save(force: true);
    _emit();
  }

  void _addChat(ChatLine line) {
    _chat.add(line);
    if (_chat.length > maxMessages) _chat.removeAt(0);
  }

  /// Aviso de sistema **solo de este dispositivo** (no viaja por la red):
  /// lo usan los avisos del plan de build (docs/specs/build_planner.md
  /// § 5). Va al registro y al chat.
  void addLocalNotice(String text) {
    if (!mounted) return;
    _messages.add(text);
    if (_messages.length > maxMessages) _messages.removeAt(0);
    _addChat(ChatLine.system(text));
    _emit();
  }

  /// Guarda a cada miembro que cambió (el local y sus compañeros, cada
  /// uno en su ranura): cada [saveEvery] s o ya con [force].
  void _save({bool force = false}) {
    if (!force && _sinceSave < saveEvery) return;
    for (final id in _companions.keys) {
      if (_saveCompanion(id)) _sinceSave = 0;
    }
    _saveLocal();
  }

  /// El compañero [id] si cambió; devuelve si mandó a escribir.
  bool _saveCompanion(String id) {
    final slot = _companions[id], ps = party;
    final p = _s?.players[id]?.profile;
    final last = _companionSaved[id];
    if (slot == null || ps == null || p == null || identical(p, last)) {
      return false;
    }
    _companionSaved[id] = p;
    if (last != null && jsonEncode(last.toJson()) == jsonEncode(p.toJson())) {
      return false;
    }
    // Igual que el local: si falla no queda como guardado y se reintenta.
    unawaited(ps.save(slot, p).then((_) => _companionSaveOk(id, p),
        onError: (Object e) {
      if (identical(_companionSaved[id], p)) _companionSaved.remove(id);
      _saveFailed(e);
    }));
    return true;
  }

  /// Guarda ya al compañero [id] (al sacarlo de la party, al salir).
  Future<void> _saveCompanionNow(String id) async {
    final slot = _companions[id], ps = party;
    final p = _s?.players[id]?.profile;
    if (slot == null || ps == null || p == null) return;
    _companionSaved[id] = p;
    try {
      await ps.save(slot, p);
      _companionSaveOk(id, p);
    } catch (e) {
      if (identical(_companionSaved[id], p)) _companionSaved.remove(id);
      _saveFailed(e);
    }
  }

  void _companionSaveOk(String id, PlayerProfile p) {
    // El aviso se va solo si el local tampoco tiene nada pendiente.
    if (_saveError == null ||
        !identical(_companionSaved[id], p) ||
        _lastSaved == null) {
      return;
    }
    if (_companions.keys.any((c) => !_companionSaved.containsKey(c))) return;
    _saveError = null;
    _emit();
  }

  void _saveLocal() {
    final p = _s?.players[localId]?.profile;
    if (p == null || identical(p, _lastSaved)) return;
    final last = _lastSaved;
    _lastSaved = p;
    // El cliente recibe un perfil nuevo (otro objeto) en cada snapshot:
    // solo se guarda si cambió de verdad.
    if (last != null && jsonEncode(last.toJson()) == jsonEncode(p.toJson())) {
      return;
    }
    _sinceSave = 0;
    // `_lastSaved` ya es [p] (para no repetir mientras se escribe); si
    // falla vuelve a `null` y el próximo intento (2 s) lo reintenta.
    unawaited(store.save(p).then((_) => _saveOk(p), onError: (Object e) {
      if (identical(_lastSaved, p)) _lastSaved = null;
      _saveFailed(e);
    }));
  }

  /// El progreso no llegó a disco (se reintenta solo). `null` = guardado.
  String? _saveError;

  void _saveOk(PlayerProfile p) {
    if (_saveError == null || !identical(_lastSaved, p)) return;
    _saveError = null;
    _emit();
  }

  void _saveFailed(Object e) {
    EcosLog.error('Guardado del personaje', e);
    _saveError = 'No se pudo guardar';
    _emit();
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
    // El reparto de la subida de nivel es del líder (solo_party.md § 6.1).
    if (must || !_companions.containsKey(_acting)) _acting = null;
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
            _panel == WorldPanel.ecoPortal ||
            _panel == WorldPanel.ascension) &&
        mode != SessionMode.lobby) {
      _panel = null;
    }
    if (_panel == WorldPanel.party && !canEditParty) _panel = null;
    if (_panel == WorldPanel.stash && stashBlock != null) _panel = null;
    if (must && _panel != WorldPanel.character) {
      _panel = WorldPanel.character;
      _autoChar = true;
    }
    if (_autoChar && !must) {
      _autoChar = false;
      if (_panel == WorldPanel.character) _panel = null;
    }
    if (mode == SessionMode.battle || mode == SessionMode.result) _panel = null;
    // El mapa en grande solo vale donde hay minimapa (campo / mundo).
    if (_panel == WorldPanel.map && !mapAvailable) _panel = null;

    final (prompt, promptText) = _prompt();
    final prev = state;
    state = SessionView(
      session: s,
      localId: localId,
      map: engine.mapFor(s),
      panel: _panel,
      prompt: prompt,
      promptText: promptText,
      // Mismas listas si no cambiaron: el HUD compara por identidad y no
      // reconstruye el chat (exploration.md § "Rendimiento").
      messages: _keep(prev?.messages, _messages),
      chat: _keep(prev?.chat, _chat),
      battleEvents: _battleEvents,
      battleEventSeq: _battleSeq,
      roomCode: net?.roomCode,
      disconnected: _disconnected,
      missionLoot: _keep(prev?.missionLoot, _missionLoot),
      atlas: _atlas,
      atlasGain: _atlasGain,
      bestiary: _bestiary,
      saveError: _saveError,
      companions: _keep(prev?.companions, [..._companions.keys]),
      auto: prev != null && setEquals(prev.auto, _auto)
          ? prev.auto
          : Set.unmodifiable(_auto),
      actingId: _acting,
    );
  }

  /// [prev] si tiene los mismos elementos que [now] (idénticos o `==`);
  /// si no, una copia inmodificable de [now].
  static List<T> _keep<T>(List<T>? prev, List<T> now) {
    if (prev != null && prev.length == now.length) {
      var same = true;
      for (var i = 0; i < now.length && same; i++) {
        same = identical(prev[i], now[i]) || prev[i] == now[i];
      }
      if (same) return prev;
    }
    return List.unmodifiable(now);
  }

  (WorldPrompt?, String?) _prompt() {
    if (_panel != null) return (null, null);
    if (nearArmory) return (WorldPrompt.armory, null);
    if (nearPortal) return (WorldPrompt.ecoPortal, null);
    if (nearStatue) return (WorldPrompt.statue, null);
    if (nearCounter) return (WorldPrompt.missionBoard, null);
    if (nearSeal != null) return (WorldPrompt.seal, null);
    if (nearPoi case final p?) {
      final s = _s!;
      final m = s.mission!;
      return (
        WorldPrompt.poi,
        poiPromptText(p, m, engine.mapFor(s).floor(m.floor)!, s.time),
      );
    }
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

/// Una operación del alijo esperando confirmación.
class _StashOp {
  _StashOp(this.id, this.action,
      {required this.put,
      required this.tab,
      required this.left,
      required this.reason,
      required this.cells});

  final String id;
  final SessionAction action;
  final bool put;
  final int tab;
  final int left;
  final String? reason;
  final List<int> cells;
  double wait = 0;
  int tries = 0;
}
