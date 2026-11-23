import '../../../game_engine/models/combat_mode.dart';
import '../../../game_engine/models/fog_of_war.dart';
import '../data/fog_store.dart';
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
import '../../../game_engine/models/run_save.dart';
import '../../../game_engine/models/travesia_meta.dart';
import '../../../game_engine/rules/meta_progress_rules.dart';
import '../../../game_engine/rules/run_rules.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/atlas_store.dart';
import '../../../game_engine/models/game_mode.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/data/town_layout.dart';
import '../../../game_engine/data/biomes_catalog.dart';
import '../../../game_engine/rules/biome_rules.dart';
import '../../../game_engine/rules/eco_portal_rules.dart';
import '../../../game_engine/rules/town_plan.dart';
import '../../../game_engine/models/world_save.dart';
import '../../../game_engine/data/construction_catalog.dart' show kFaroId;
import '../../../game_engine/rules/helper_rules.dart';
import '../../../game_engine/rules/sky_rules.dart';
import '../../../game_engine/rules/resident_rules.dart';
import '../../../game_engine/rules/biome_fisher_rules.dart';
import '../../../game_engine/rules/town_rules.dart';
import 'town_edit.dart';

export 'town_edit.dart';
import '../../../game_engine/serialization/json_read.dart';
import '../../../game_engine/serialization/session_json.dart';
import '../../lobby/presentation/worlds_providers.dart';
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
import '../../../game_engine/rules/world_engine.dart';
import '../../../game_engine/rules/world_rules.dart';
import '../../../game_engine/rules/zone_rules.dart';
import '../../../netcode/contracts/net_session.dart';
import '../../../netcode/contracts/net_session_factory.dart';
import '../../ascension/domain/ascension_text.dart';
import '../../characters/data/account_repository.dart';
import '../../characters/domain/stash.dart';
import '../../characters/presentation/characters_providers.dart';
import '../../../game_engine/data/fishing_catalog.dart';
import '../../../game_engine/rules/fishing_rules.dart';
import '../../../game_engine/rules/fishing_minigame.dart';
import '../../../game_engine/rules/map_fishing.dart';
import '../../../game_engine/rules/farming_rules.dart';
import '../../../game_engine/rules/life_tree_rules.dart';
import '../../../game_engine/models/fish_line.dart';
import '../../../core/audio/sfx_catalog.dart';
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

/// La run guardada de la Travesía (roguelike.md § 8.5); `null` en el
/// Mundo.
final runSaveStoreProvider = Provider<RunSaveStore?>(
    (ref) => sl.isRegistered<RunSaveStore>() ? sl<RunSaveStore>() : null);

/// El progreso entre runs de la Travesía (roguelike.md § 8); `null` en
/// el Mundo.
final travesiaMetaStoreProvider = Provider<TravesiaMetaStore?>((ref) =>
    sl.isRegistered<TravesiaMetaStore>() ? sl<TravesiaMetaStore>() : null);

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
  final books = ref.read(worldBookProvider.notifier);
  final c = SessionController(
    engine: ref.watch(sessionEngineProvider),
    store: ref.watch(profileStoreProvider),
    atlasStore: ref.watch(atlasStoreProvider),
    bestiaryStore: ref.watch(bestiaryStoreProvider),
    tutorialStore: ref.watch(tutorialStoreProvider),
    stashStore: ref.watch(stashStoreProvider),
    runSaveStore: ref.watch(runSaveStoreProvider),
    metaStore: ref.watch(travesiaMetaStoreProvider),
    clock: ref.watch(sessionClockProvider),
    net: ref.read(activeNetSessionProvider),
    turnTimer: ref.read(gameSettingsProvider).turnTimer,
    combatMode: CombatMode.fromName(ref.read(gameSettingsProvider).combatMode),
    // Sin FeatureFlags.soloParty no hay compañeros (solo_party.md § 0).
    party:
        FeatureFlags.instance.soloParty ? ref.read(partyStoreProvider) : null,
    // Mundo elegido en el título (town_loop.md § 11c).
    world: ref.read(worldBookProvider)?.selected,
    onWorldTown: books.saveTown,
    fogStore: FogStore.forPlatform(),
  );
  // Tiempo de turno (accessibility.md § 7): el ajuste local manda en la
  // sala si este dispositivo corre el motor (solo o anfitrión).
  ref.listen(gameSettingsProvider.select((s) => s.turnTimer),
      (_, t) => c.setTurnTimer(t));
  // Modo de combate (turn_modes.md § 1): la elección del anfitrión.
  ref.listen(gameSettingsProvider.select((s) => s.combatMode),
      (_, m) => c.setCombatMode(CombatMode.fromName(m)));
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
    CombatMode? combatMode,
    this.party,
    this.stashStore,
    this.runSaveStore,
    this.metaStore,
    this.world,
    this.onWorldTown,
    this.fogStore,
  })  : localId = net?.localId ?? localId,
        _turnTimer = turnTimer,
        _combatMode = combatMode,
        atlasStore = atlasStore ?? InMemoryAtlasStore(),
        bestiaryStore = bestiaryStore ?? InMemoryBestiaryStore(),
        tutorialStore =
            tutorialStore ?? InMemoryTutorialStore(kTutorialVersion),
        super(null);

  /// Compañeros de la party jugando solo (docs/specs/solo_party.md);
  /// `null` = sin party. Con red no se usa (en salas no hay compañeros).
  final PartyStore? party;

  /// El alijo de la cuenta (characters.md § 3.2); `null` = sin alijo.
  final StashStore? stashStore;

  /// Travesía: dónde se guarda la run en curso (roguelike.md § 8.5).
  /// Solo la usa quien corre el motor (local o anfitrión).
  final RunSaveStore? runSaveStore;

  /// El mundo elegido (town_loop.md § 11c): solo lo usa quien corre el
  /// motor (solo o anfitrión); es el mundo de la sala. `null` = sin mundo.
  final WorldSave? world;

  /// Guarda el pueblo del mundo jugado (pozo del Loot perdido, ciclo).
  final void Function(String worldId, TownState town)? onWorldTown;
  int _worldCycle = 0;

  /// Niebla explorada de las mazmorras (persistent_dungeons.md § 2.2).
  final FogStore? fogStore;
  bool _fogLoaded = false;

  /// Carga una vez lo explorado guardado en el disco.
  void _loadFog() {
    if (_fogLoaded) return;
    _fogLoaded = true;
    fog.archive.addAll(fogStore?.load() ?? const {});
  }

  void _saveFog() {
    final st = fogStore;
    if (st == null || !fog.dirty) return;
    fog.dirty = false;
    st.save(fog.archive);
  }

  /// Travesía: progreso entre runs de este dispositivo (§ 8).
  final TravesiaMetaStore? metaStore;
  TravesiaMeta _meta = TravesiaMeta.empty;
  TravesiaMeta get meta => _meta;
  bool _metaLoaded = false;
  bool _prepSent = false;

  MetaProgressRules get metaRules => MetaProgressRules(catalog: engine.catalog);

  /// Clave del personaje local en el progreso (`nombre|clase`).
  String? get metaKey {
    final p = _s?.players[localId]?.profile;
    return p == null ? null : TravesiaMeta.keyOf(p.name, p.classId);
  }

  /// Habilidades del arma inicial de la clase local (fuera del pool).
  List<String> get startSkills {
    final p = _s?.players[localId]?.profile;
    if (p == null) return const [];
    return engine.progression
        .weaponSkills(RunRules.runProfile(engine.progression, p));
  }

  /// El pool de loadout del personaje local.
  List<String> get loadoutPool {
    final p = _s?.players[localId]?.profile;
    return p == null ? const [] : metaRules.loadoutPool(p.classId, startSkills);
  }

  Future<void> _loadMeta() async {
    final store = metaStore;
    if (store == null || !isRun) return;
    try {
      _meta = await store.load();
    } catch (_) {
      _meta = TravesiaMeta.empty;
    }
    _metaLoaded = true;
  }

  void _setMeta(TravesiaMeta m) {
    _meta = m;
    unawaited(metaStore?.save(m).catchError((_) {}));
    _prepSent = false;
    _sendPrep();
    _emit();
  }

  /// Compra un nodo del árbol de afuera.
  bool buyMetaNode(String id) {
    final key = metaKey;
    if (key == null) return false;
    final next = MetaProgressRules.buy(_meta, key, id);
    if (next == null) return false;
    _setMeta(next);
    return true;
  }

  /// Elige las habilidades de arranque.
  bool setLoadout(List<String> skills) {
    final key = metaKey, p = _s?.players[localId]?.profile;
    if (key == null || p == null) return false;
    final next =
        metaRules.setLoadout(_meta, key, p.classId, startSkills, skills);
    if (next == null) return false;
    _setMeta(next);
    return true;
  }

  /// Elige la dificultad (hasta la desbloqueada).
  void setDifficulty(int d) {
    if (d < 0 || d > _meta.difficultyUnlocked) return;
    _setMeta(_meta.copyWith(difficulty: d));
  }

  /// Manda el loadout y los bonos al anfitrión (en la sala o al terminar).
  void _sendPrep() {
    final s = _s, key = metaKey, p = _s?.players[localId]?.profile;
    if (!isRun ||
        !_metaLoaded ||
        _prepSent ||
        s == null ||
        key == null ||
        p == null) {
      return;
    }
    final canPrep = s.mode == SessionMode.lobby ||
        (s.mode == SessionMode.run && s.run?.phase == RunPhase.over);
    if (!canPrep) return;
    _prepSent = true;
    _apply(RunPrepAction(metaRules.prepOf(_meta, key, p.classId, startSkills)));
  }

  /// Cobra la run terminada en el progreso de este dispositivo (una vez).
  void _settleRun() {
    final r = _s?.run;
    if (!isRun || !_metaLoaded || r == null || r.phase != RunPhase.over) {
      return;
    }
    if (_meta.lastSeed == r.seed) return;
    final next = MetaProgressRules.settle(_meta, r,
        playableZones:
            RunRules(catalog: engine.catalog).playableZones().length);
    _setMeta(next);
  }

  /// La run guardada que se puede retomar (en la sala, antes de empezar).
  RunSave? _runSave;
  bool get hasRunSave => _runSave != null && !isClient;
  String? _runSaveKey;

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
    _commit(step);
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
      _commit(step);
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
    if (!_persist) return;
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
  bool tutorialControl(TutorialControl op) => _apply(TutorialControlAction(op));

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
    _setAll((x) => engine.setTurnTimer(x, t).state);
    _emit();
  }

  /// Modo de combate local (turn_modes.md § 1): como anfitrión o solo, lo
  /// aplica a la sala; un cliente ve el del anfitrión.
  CombatMode? _combatMode;
  CombatMode? get combatMode => _combatMode;

  void setCombatMode(CombatMode? m) {
    _combatMode = m;
    final s = _s;
    if (isClient || s == null || !mounted) return;
    _setAll((x) => engine.setCombatMode(x, m).state);
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

  /// Niebla de exploración del jugador local en mazmorras oscuras
  /// (lighting.md § 5.4). Solo del cliente: no viaja ni se guarda.
  final fog = FogOfWar();

  /// La niebla con lo explorado del disco ya cargado (una vez).
  FogOfWar get fogLoaded {
    _loadFog();
    return fog;
  }
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

  /// Al aire libre la Llama errante va sola (lighting.md § 3.1.1).
  bool _wispOutdoor() {
    final m = map;
    return SkyRules.outdoor(m.theme, town: m.lobby);
  }

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
      await _loadMeta();
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
    final room = engine.setCombatMode(
        engine
            .setTurnTimer(
                engine.setAtlas(engine.create(), atlas.nodes).state, _turnTimer)
            .state,
        _combatMode);
    var room0 = room.state;
    // El mundo del anfitrión es el de la sala (town_loop.md § 11c).
    if (world case final w? when !isRun) {
      _worldCycle = w.town.cycle;
      final lost = <GroundLoot>[];
      final codec = SessionJson(engine.catalog);
      for (final raw in w.town.lostLoot) {
        try {
          lost.add(codec.groundFromJson(asJson(raw)));
        } catch (_) {}
      }
      room0 = engine
          .setWorld(room0, w.id, w.name, lostLoot: lost, town: w.town)
          .state;
    }
    try {
      _tutorialVersion = await tutorialStore.load();
    } catch (_) {
      _tutorialVersion = 0; // sin disco: el sello pide el tutorial
    }
    if (!mounted) return;
    // Movimiento libre (free_movement.md): el anfitrión maneja las
    // instancias; esta vista es la del jugador local.
    final w = _w = _we.create(room0);
    final ws = _we.addPlayer(w, localId, profile,
        tutorialVersion: _tutorialVersion)!;
    var step = SessionStep(w.town, ws.eventsFor(localId));
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
    await _loadRunSave();
    await _loadMeta();
    if (!mounted) return;
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
    if (!_persist) return;
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
    if (!_persist) return;
    unawaited(atlasStore.save(next).catchError((Object e) {
      EcosLog.error('Guardado del Atlas', e);
      _saveFailed(e);
    }));
    // Local / anfitrión: la sala usa este Atlas (los clientes, el del host).
    final s = _s;
    if (!isClient && s != null) {
      _setAll((x) => engine.setAtlas(x, next.nodes).state);
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
    _saveWorld();
    fog.reset();
    _saveFog();
    _timer?.cancel();
    _broadcastTimer?.cancel();
    unawaited(_netSub?.cancel());
    _recoverLocalGround();
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
    final w = _w;
    if (w == null) {
      final events = List<SessionEvent>.of(_unsent);
      _unsent.clear();
      n.broadcast(s, events);
      return;
    }
    // Cada cliente recibe su instancia (free_movement.md § 3); los que
    // tienen los mismos eventos van en un solo envío.
    for (final room in w.rooms.values) {
      final groups = <(List<SessionEvent>, Set<String>)>[];
      for (final pid in room.players.keys) {
        if (pid == localId) continue;
        final evs = _unsentBy.remove(pid) ?? const <SessionEvent>[];
        final g = groups.where((g) => _sameEvents(g.$1, evs)).firstOrNull;
        if (g != null) {
          g.$2.add(pid);
        } else {
          groups.add((evs, {pid}));
        }
      }
      for (final (evs, ids) in groups) {
        n.broadcast(room, evs, only: ids);
      }
    }
  }

  static bool _sameEvents(List<SessionEvent> a, List<SessionEvent> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
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
      case PeerJoinedEvent(
          :final peerId,
          :final profile,
          :final tutorialVersion
        ):
        final w = _w;
        if (s == null || isClient || w == null) return;
        final ws = _we.addPlayer(w, peerId, profile,
            tutorialVersion: tutorialVersion);
        if (ws != null) _world(ws);
      case PeerActionEvent(:final peerId, :final action):
        final w = _w;
        if (s == null || isClient || w == null) return;
        final ws = _we.apply(w, peerId, action);
        if (ws == null) return;
        // Las posiciones (20 por segundo por cliente) no traen eventos:
        // se aplican sin emitir una vista nueva; la emite el próximo tick.
        if (action is MoveAction && ws.events.isEmpty) {
          _s = w.sessionOf(localId) ?? w.town;
        } else {
          _world(ws);
        }
      case PeerLeftEvent(:final peerId):
        final w = _w;
        if (s == null || isClient || w == null) return;
        _unsentBy.remove(peerId);
        final ws = _we.removePlayer(w, peerId);
        if (ws != null) _world(ws);
      case ConnectionLostEvent(:final reason):
        _disconnected = reason;
        _recoverLocalGround();
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
    _world(_we.tick(_w!, dt));
    _autoTurn();
    _save();
  }

  /// Turno de un compañero con AUTO (solo_party.md § 4.1).
  void _autoTurn() {
    final s = _s;
    final b = s?.battle;
    if (s == null || b == null || s.paused || !b.waitingForPlayer) return;
    // porBando: en el turno del grupo, el primer compañero con AUTO que
    // falta (roguelike.md § 6).
    final cur = b.state.currentId ??
        b.state.pendingGroup.map((p) => p.id).where(_auto.contains).firstOrNull;
    if (cur == null || !_auto.contains(cur) || b.turnTime < autoDelay) {
      return;
    }
    final pick = _ai.choose(
        b.state.currentId == null ? (b.state.copy()..currentId = cur) : b.state,
        cur);
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
    if (_fishing case final f?) {
      // Caminar, salir del pueblo o abrir un panel guarda la caña.
      if (ix != 0 || iy != 0 || s.mode != SessionMode.lobby || _panel != null) {
        stopFishing();
      } else {
        _tickFishing(f, dt);
      }
    }
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
    if (!_persist) return;
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
      !isRun &&
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
    final w = _w;
    if (w == null) return;
    final ws = _we.apply(w, localId, move);
    if (ws == null) return;
    if (ws.events.isEmpty) {
      _s = w.sessionOf(localId) ?? w.town;
    } else {
      _world(ws);
    }
  }

  /// Cambia el pueblo del anfitrión (capturas: cielo, faros).
  @visibleForTesting
  void debugTown(TownState Function(TownState) f) {
    final s = _s;
    if (s == null || isClient) return;
    _setAll((x) => x.copy()..town = f(x.town));
    _emit();
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

  /// El lugar del pueblo frente al jugador local (town_loop.md § 2.1).
  TownSpot? get townSpot => _s?.mode == SessionMode.lobby
      ? WorldRules.townSpot(local.x, local.y, map: engine.mapFor(_s!))
      : null;

  /// Frente al tablero de encargos (la fuente rúnica tiene su panel, que
  /// también lo abre; v0.23.0).
  bool get nearCounter => townSpot == TownSpot.board;

  bool get nearArmory => townSpot == TownSpot.armory;

  /// Frente a la FORJA (v0.32.3: su propio panel).
  bool get nearForge => townSpot == TownSpot.forge;

  /// Frente al TALLER DE OFICIOS (town_loop.md § 2.1, v0.32.3).
  bool get nearWorkshop => townSpot == TownSpot.workshop;

  /// Frente al Portal del Eco del pueblo (ecos_atlas.md § 1).
  bool get nearPortal => townSpot == TownSpot.portal;

  /// La zona del portal de Ecos frente al jugador (en el exterior de su
  /// bioma; ecos_zone.md § 4), o `null`.
  int? get nearEcoPortal {
    final s = _s;
    if (s == null || s.mode != SessionMode.lobby) return null;
    return EcoPortalRules.near(s.place, local.x, local.y);
  }

  /// La zona del portal de Ecos abierto (panel `ecoZone`).
  int? ecoZone;

  /// El tier elegido en el centro de viaje antes de ir (lo toma el panel
  /// del portal al abrirse).
  int? ecoTier;

  /// Viajar al exterior de [zone] y quedar frente a su portal de Ecos
  /// (ecos_zone.md § 5). Sirve también estando ya en ese exterior.
  bool travelToEcoPortal(int zone, {int? tier}) {
    final spot = EcoPortalRules.of(zone);
    if (spot == null || cannotTravel != null) return false;
    ecoTier = tier;
    if (travelLocked(spot.biome) != null) return false;
    closePanel();
    stopFishing();
    return _apply(TravelAction(spot.biome, ecoZone: zone));
  }

  /// Por qué no se puede ir al portal de Ecos de [zone], o `null`.
  String? ecoTravelBlocked(int zone) {
    final spot = EcoPortalRules.of(zone);
    if (spot == null) return 'Sin portal';
    return cannotTravel ?? travelLocked(spot.biome);
  }

  /// Frente a la Estatua del Tiempo (ascension.md § 1).
  bool get nearStatue => townSpot == TownSpot.statue;

  /// Frente a la torre del Loot perdido (missions.md § "Loot perdido").
  bool get nearLostLoot => townSpot == TownSpot.lostLoot;

  /// Frente a un punto de pesca, al puesto o al cartel del lago.
  bool get nearFishing => townSpot == TownSpot.fishing;
  bool get nearTrader => townSpot == TownSpot.trader;
  bool get nearSign => townSpot == TownSpot.sign;

  /// Lo que dice el cartel del lago: especies y tu nivel de Pesca.
  String get signText {
    final p = _s?.players[localId]?.profile;
    final lake = TownRules.lakeNear(town, local.x, local.y);
    return '${lake == null ? 'Sin lago' : TownRules.lakeSignText(town, lake)}. '
        'Pesca nivel ${p == null ? 1 : FishingRules.level(p)}. Acercate a '
        'la orilla o a un muelle y tocá E.';
  }

  // ---- Pesca y agropecuario (fishing.md § 6): el host valida ----

  bool fishBite(double power) => _apply(FishBiteAction(power));
  bool fishResult(bool ok) => _apply(FishResultAction(ok));

  bool sellFish({String? species, bool materials = false}) =>
      _apply(SellFishAction(species: species, materials: materials));
  bool exchangeFish(String species) => _apply(ExchangeFishAction(species));
  bool buyRod(String id) => _apply(BuyRodAction(id));
  bool equipRod(String id) => _apply(EquipRodAction(id));

  // ---- Huerta, pueblo y oficios (farming.md § 4 y § 10, v0.23.0) ----

  /// Frente a la fuente rúnica: mejoras del pueblo y el tablero.
  bool get nearFountain => townSpot == TownSpot.fountain;

  // ---- Mapa de viaje y exteriores (overworld_biomes.md) ----

  /// En el camino del borde sur: E abre el mapa de viaje.
  bool get nearTravel => townSpot == TownSpot.travel;

  /// Dónde está el grupo: `pueblo` o el id del bioma.
  String get place => _s?.place ?? kPueblo;

  /// Viajar: cada uno por su cuenta (free_movement.md § 2.2).
  String? get cannotTravel {
    final s = _s;
    if (s == null || s.mode != SessionMode.lobby) return 'Solo fuera de misión';
    if (isRun) return 'Solo en el Mundo';
    return null;
  }

  /// Por qué el bioma [id] sigue cerrado para el dueño del mundo.
  /// (Lo valida el anfitrión con su perfil; acá se mira el propio.)
  String? travelLocked(String id) =>
      BiomeRules.lockedReason(
          id, _s?.players[localId]?.profile.unlockedZone ?? 1);

  /// El habitante con el que se abrió la pantalla (los del pueblo
  /// caminan: la pantalla sigue con él aunque se aleje).
  BiomeNpcDef? talkNpc;

  /// El habitante del exterior frente al jugador local (§ 9), o `null`.
  BiomeNpcDef? get nearNpc {
    final s = _s;
    final lay = biomeLayout(s?.place);
    if (s == null || s.mode != SessionMode.lobby) return null;
    if (lay == null) {
      // En el pueblo: el habitante que camina frente a su casa (§ 10.1).
      if (s.place != null || editingTown) return null;
      final night = SkyRules.isNight(s.town.sky);
      for (final n in ResidentRules.living(s.town)) {
        final pos = ResidentRules.position(s.town, n.id, s.time, night: night);
        if (pos == null) continue;
        if (WorldRules.distance(local.x, local.y, pos.$1, pos.$2) < 26) {
          return n;
        }
      }
      return null;
    }
    // Ya vive en el pueblo: no está más en su bioma (§ 10.1).
    if (s.town.resident(lay.npc.id).invited) return null;
    final (nx, ny) = lay.npc.tile;
    return WorldRules.distance(
                local.x, local.y, (nx + 0.5) * 16, (ny + 0.5) * 16) <
            26
        ? lay.npc
        : null;
  }

  /// El habitante parado sobre el tile ([tx], [ty]) del mapa (o el de al
  /// lado), para abrir su pantalla con un clic (§ 10).
  BiomeNpcDef? residentAt(int tx, int ty) {
    final s = _s;
    if (s == null || s.mode != SessionMode.lobby || editingTown) return null;
    bool near(double x, double y) =>
        ((x / 16).floor() - tx).abs() <= 1 &&
        ((y / 16).floor() - ty).abs() <= 1;
    final lay = biomeLayout(s.place);
    if (lay == null) {
      if (s.place != null) return null;
      final night = SkyRules.isNight(s.town.sky);
      for (final n in ResidentRules.living(s.town)) {
        final pos = ResidentRules.position(s.town, n.id, s.time, night: night);
        if (pos != null && near(pos.$1, pos.$2)) return n;
      }
      return null;
    }
    if (s.town.resident(lay.npc.id).invited) return null;
    final (nx, ny) = lay.npc.tile;
    return near((nx + 0.5) * 16, (ny + 0.5) * 16) ? lay.npc : null;
  }

  /// Abre la pantalla de [n] (clic o E).
  void openResident(BiomeNpcDef n) {
    talkNpc = n;
    openPanel(WorldPanel.biomeNpc);
  }

  /// El pescador nativo cerca del jugador local (fishing.md § 12).
  BiomeFisherDef? get nearFisher {
    final s = _s;
    final lay = biomeLayout(s?.place);
    if (s == null || s.mode != SessionMode.lobby || lay == null) return null;
    final f = kBiomeFishers[lay.id];
    if (f == null) return null;
    final (x, y) = BiomeFisherRules.position(lay, s.time);
    return WorldRules.distance(local.x, local.y, x, y) < 26 ? f : null;
  }

  /// ¿El pescador nativo está en el tile ([tx], [ty]) o al lado?
  bool fisherAt(int tx, int ty) {
    final s = _s;
    final lay = biomeLayout(s?.place);
    if (s == null || lay == null || kBiomeFishers[lay.id] == null) {
      return false;
    }
    final (x, y) = BiomeFisherRules.position(lay, s.time);
    return ((x / 16).floor() - tx).abs() <= 1 &&
        ((y / 16).floor() - ty).abs() <= 1;
  }

  bool fisherDeliver() {
    final b = place;
    return _apply(TownAction(TownOp.fisherReq, id: b));
  }

  /// Frase del habitante (cambia con el día del mundo).
  String npcLine(BiomeNpcDef n) =>
      n.lines[town.sky.day % n.lines.length];

  bool travelPlace(String id) {
    if (cannotTravel != null || id == place) return false;
    if (travelLocked(id) != null) return false;
    closePanel();
    stopFishing();
    return _apply(TravelAction(id));
  }

  /// La mata del exterior frente al jugador local (índice), o `null`.
  int? get nearForage {
    final s = _s;
    final lay = biomeLayout(s?.place);
    if (s == null || s.mode != SessionMode.lobby || lay == null) {
      return null;
    }
    for (var i = 0; i < lay.forage.length; i++) {
      final f = lay.forage[i];
      if (WorldRules.distance(local.x, local.y, (f.x + 0.5) * 16,
              (f.y + 0.5) * 16) <
          24) {
        return i;
      }
    }
    return null;
  }

  String forageHint(int i) {
    final lay = biomeLayout(_s?.place) ?? bosqueLayout;
    final k = kForageKinds[lay.forage[i].kind];
    final left = BiomeRules.regrowIn(town, lay.id, i, _s?.time ?? 0).ceil();
    return left > 0
        ? '${k.name}: vuelven a crecer en ${left}s'
        : '[E] Recolectar ${k.name.toLowerCase()}';
  }

  bool forage() {
    final i = nearForage;
    return i != null && _apply(ForageAction(i));
  }

  /// El pueblo de la sala (huerta, ampliaciones, lago).
  TownState get town => _s?.town ?? const TownState();

  /// Soy el dueño del mundo (el anfitrión o el que juega solo).
  bool get isWorldOwner =>
      (_s?.ownerId ??
          _s?.playerList.where((p) => !p.isCompanion).firstOrNull?.id) ==
      localId;

  bool _isSoil(int x, int y) {
    final s = _s;
    if (s == null) return false;
    final m = engine.mapFor(s);
    return x >= 0 &&
        y >= 0 &&
        x < m.width &&
        y < m.height &&
        m.tileAt(x, y) == Tile.soil;
  }

  /// El tile de tierra con que trabaja el jugador local: el de enfrente
  /// (a 10 px) o el que pisa. `null` = no está en la huerta.
  (int, int)? get farmTile {
    if (!_townFree()) return null;
    final fx = local.fx, fy = local.fy;
    final ax = ((local.x + fx * 10) / 16).floor();
    final ay = ((local.y + fy * 10) / 16).floor();
    if (_isSoil(ax, ay)) return (ax, ay);
    final tx = (local.x / 16).floor(), ty = (local.y / 16).floor();
    if (_isSoil(tx, ty)) return (tx, ty);
    return null;
  }

  FarmPlot? plotAt(int x, int y) => town.plots[plotKey(x, y)];

  /// A 2 tiles o menos de cualquier tierra de huerta (todas las zonas,
  /// también las que suma ampliar el pueblo): sale la azada equipada.
  bool get nearFarm => _townFree() && nearSoilAt(local.x, local.y);

  /// Hay tierra de huerta a 2 tiles o menos de (x, y) px. Sirve también
  /// para saber si otro jugador tiene la herramienta de huerta en la mano.
  bool nearSoilAt(double x, double y) {
    final tx = (x / 16).floor(), ty = (y / 16).floor();
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        if (_isSoil(tx + dx, ty + dy)) return true;
      }
    }
    return false;
  }

  /// La herramienta que el jugador tiene en la mano en el mapa (solo en
  /// el pueblo; nunca en misiones). La caña manda cerca del agua.
  ActiveTool? get activeTool {
    if (!_townFree()) return null;
    if (_fishing != null || canFish) return ActiveTool.rod;
    if (nearFarm) return ActiveTool.hoe;
    return null;
  }

  /// Aviso compacto sobre las pociones (farming.md § 4, fishing.md § 4).
  String? get toolPrompt {
    if (_fishing case final f?) return fishingHint(f);
    // Junto a un ayudante, su pantalla primero (antes que "Sin semillas…").
    if (nearHelper != null) return WorldPrompt.helper.label;
    if (farmHint() case final h?) return h;
    if (canFish) return WorldPrompt.fishing.label;
    return null;
  }

  /// Carrusel: la semilla anterior.
  bool prevSeedPick() {
    final p = _s?.players[localId]?.profile;
    if (p == null) return false;
    final prev = FarmingRules.prevSeed(p);
    if (prev == null) return false;
    return _apply(FarmShopAction(FarmShopOp.selectSeed, id: prev));
  }

  FarmHand? _hand;
  bool _handManual = false;

  /// Lo que pide el estado de la parcela de enfrente (sugerencia).
  FarmHand? get _suggestedHand {
    final t = farmTile;
    if (t == null) return null;
    final pl = plotAt(t.$1, t.$2);
    if (pl == null) return FarmHand.hoe;
    if (!pl.planted) return FarmHand.seed;
    if (FarmingRules.ripe(pl)) return null;
    return FarmHand.can;
  }

  /// La herramienta de huerta en la mano (farming.md § 2.5). Mientras no
  /// elijas a mano, sigue lo que pide la parcela de enfrente; una elección
  /// manual se respeta hasta alejarte de la huerta.
  FarmHand get farmHand {
    if (!nearFarm) {
      _handManual = false;
      _hand = null;
    }
    if (!_handManual) _hand = _suggestedHand ?? _hand ?? FarmHand.hoe;
    return _hand ?? FarmHand.hoe;
  }

  /// Si la elección actual fue manual.
  bool get farmHandManual => farmHand == _hand && _handManual;

  /// Clic en un casillero del HUD: lo deja en la mano (no hace la labor).
  void selectFarmHand(FarmHand h) {
    _hand = h;
    _handManual = true;
    _emit();
  }

  /// Tab / rueda: la herramienta siguiente (o la anterior).
  void cycleFarmHand([int step = 1]) {
    const all = FarmHand.values;
    final i = all.indexOf(farmHand) + step;
    selectFarmHand(all[i % all.length]);
  }

  /// Los tiles que tocaría el próximo E / clic (con el área de la azada o
  /// la regadera) y si la herramienta elegida sirve ahí. `null` = lejos.
  ({List<(int, int)> tiles, bool ok})? get farmTarget {
    final t = farmTile;
    final p = _s?.players[localId]?.profile;
    if (t == null || p == null) return null;
    final op = farmOp;
    final tool = switch (op) {
      FarmOp.till => FarmingRules.hoeOf(p),
      FarmOp.water => FarmingRules.canOf(p),
      _ => null,
    };
    final area = tool == null ? 0 : FarmingRules.toolBonus(p, tool).area;
    final tiles = [
      for (final xy in FarmingRules.areaTiles(t.$1, t.$2, area))
        if (_isSoil(xy.$1, xy.$2)) xy,
    ];
    return (tiles: tiles, ok: op != null);
  }

  /// Por qué la herramienta elegida no sirve en la parcela de enfrente
  /// (`null` = sirve, está madura o no hay parcela).
  String? get farmBlockReason {
    final t = farmTile;
    final p = _s?.players[localId]?.profile;
    if (t == null || p == null) return null;
    final pl = plotAt(t.$1, t.$2);
    if (pl != null && pl.planted && FarmingRules.ripe(pl)) return null;
    return switch (farmHand) {
      FarmHand.hoe => pl == null ? null : 'Ya está arada',
      FarmHand.seed => pl == null
          ? 'Primero arala'
          : pl.planted
              ? 'Ya está plantada'
              : p.life.farm.activeSeed == null
                  ? 'Sin semillas: comprá en el agropecuario'
                  : null,
      FarmHand.can => pl == null
          ? 'Primero arala'
          : !pl.planted
              ? 'Primero plantá'
              : null,
      FarmHand.fert => pl == null
          ? 'Primero arala'
          : !pl.planted
              ? 'Primero plantá'
              : pl.fert != null
                  ? 'Ya tiene abono'
                  : farmFert == null
                      ? 'Sin abono: comprá en el agropecuario'
                      : null,
    };
  }

  /// Clic en la caña del HUD: la siguiente caña propia.
  bool cycleRod() {
    final life = _s?.players[localId]?.profile.life;
    if (life == null || life.rods.length < 2) return false;
    final i = life.rods.indexOf(life.rod);
    return equipRod(life.rods[(i + 1) % life.rods.length]);
  }

  /// Qué hace E en la huerta ahora (`null` = nada).
  FarmOp? get farmOp {
    final t = farmTile;
    final p = _s?.players[localId]?.profile;
    if (t == null || p == null) return null;
    final pl = plotAt(t.$1, t.$2);
    // Madura: se cosecha con cualquier herramienta en la mano.
    if (pl != null && pl.planted && FarmingRules.ripe(pl)) {
      return FarmOp.harvest;
    }
    if (farmBlockReason != null) return null;
    return switch (farmHand) {
      FarmHand.hoe => FarmOp.till,
      FarmHand.seed => FarmOp.plant,
      FarmHand.can => FarmOp.water,
      FarmHand.fert => FarmOp.fert,
    };
  }

  /// E en la huerta: arar, plantar, regar o cosechar.
  bool farmWork() {
    final t = farmTile;
    final op = farmOp;
    if (t == null || op == null) return false;
    final p = _s!.players[localId]!.profile;
    final ok = _apply(FarmTileAction(op, t.$1, t.$2,
        seed: op == FarmOp.plant
            ? p.life.farm.activeSeed
            : op == FarmOp.fert
                ? farmFert
                : null));
    if (ok) {
      fishSfx?.call(switch (op) {
        FarmOp.till => Sfx.whump,
        FarmOp.plant => Sfx.turnTick,
        FarmOp.water => Sfx.potion,
        FarmOp.fert => Sfx.potion,
        FarmOp.harvest => Sfx.lootPickup,
      });
    }
    return ok;
  }

  /// F: abonar la parcela de enfrente con el mejor abono que tengas.
  bool farmFertilize() {
    final t = farmTile;
    if (t == null) return false;
    final pl = plotAt(t.$1, t.$2);
    final fid = farmFert;
    if (pl == null || !pl.planted || pl.fert != null || fid == null) {
      return false;
    }
    return _apply(FarmTileAction(FarmOp.fert, t.$1, t.$2, seed: fid));
  }

  String? _fert;

  /// Abonos propios, de peor a mejor (orden del catálogo).
  List<String> get ownedFerts {
    final f = _s?.players[localId]?.profile.life.farm;
    if (f == null) return const [];
    return [
      for (final id in kFertilizers.keys)
        if (f.fertCount(id) > 0) id
    ];
  }

  /// El abono para E / F (farming.md § 2.5): el elegido si te queda; si
  /// no, el mejor que tengas.
  String? get farmFert {
    final own = ownedFerts;
    if (own.isEmpty) return null;
    return own.contains(_fert) ? _fert : own.last;
  }

  /// Selector del casillero ABONO: el siguiente abono propio.
  bool cycleFert() {
    final own = ownedFerts;
    if (own.length < 2) return false;
    final i = own.indexOf(farmFert!);
    _fert = own[(i + 1) % own.length];
    _emit();
    return true;
  }

  /// Q: la semilla siguiente.
  bool cycleSeed() {
    final p = _s?.players[localId]?.profile;
    if (p == null) return false;
    final next = FarmingRules.nextSeed(p);
    if (next == null) return false;
    return _apply(FarmShopAction(FarmShopOp.selectSeed, id: next));
  }

  static String _pct(double v) =>
      v >= 0.1 ? '${(v * 100).round()} %' : '${(v * 100).toStringAsFixed(1)} %';

  /// Lo que se sabe de una parcela (aviso y tooltip): quién plantó, quién
  /// regó, el abono y las chances si la cosechás vos.
  String plotInfo(int x, int y) {
    final pl = plotAt(x, y);
    final me = _s?.players[localId]?.profile;
    if (pl == null) return 'Tierra sin arar.';
    if (!pl.planted) return 'Parcela arada y vacía.';
    final c = kCrops[pl.seed]!;
    final r = FarmingRules.ratio(pl);
    final parts = <String>[
      '${c.name} · ${r >= 1 ? 'madura' : '${(r * 100).round()} %'}'
          '${pl.watered ? ' · regada' : ' · seca'}',
      if (pl.planter != null) 'Plantó ${pl.planter}',
      if (pl.waterer != null) 'Regó ${pl.waterer} (${pl.waterings})',
      if (kFertilizers[pl.fert] case final f?)
        '${f.name}${pl.fertBy == null ? '' : ' de ${pl.fertBy}'}',
    ];
    if (me != null) {
      final o = FarmingRules.odds(me, pl);
      parts.add('Si la cosechás vos: '
          '${_pct(o[CropQuality.epico]!)} épica · '
          '${_pct(o[CropQuality.legendario]!)} legendaria');
    }
    return parts.join('\n');
  }

  /// Texto del aviso de la huerta (sobre las pociones).
  String? farmHint() {
    final t = farmTile;
    final p = _s?.players[localId]?.profile;
    if (t == null || p == null) return null;
    final pl = plotAt(t.$1, t.$2);
    final seed = p.life.farm.activeSeed;
    final fert = pl != null &&
            pl.planted &&
            pl.fert == null &&
            farmFert != null &&
            farmHand != FarmHand.fert
        ? ' · [F] Abonar'
        : '';
    // Corto (una línea): el detalle completo está en el tooltip del mouse.
    if (pl != null && pl.planted && FarmingRules.ripe(pl)) {
      final o = FarmingRules.odds(p, pl);
      return '[E o clic] Cosechar · ${_pct(o[CropQuality.legendario]!)} legendaria';
    }
    if (farmBlockReason case final r?) return r;
    if (farmHand == FarmHand.fert && pl != null && pl.planted) {
      return '[E o clic] Abonar con ${kFertilizers[farmFert]?.name ?? 'abono'}';
    }
    if (pl == null) return '[E o clic] Arar';
    if (!pl.planted) return '[E o clic] Plantar ${kCrops[seed]!.name}';
    final r = (FarmingRules.ratio(pl) * 100).round();
    return '[E o clic] Regar · $r %$fert';
  }

  bool buySeed(String id, [int n = 1]) =>
      _apply(FarmShopAction(FarmShopOp.buySeed, id: id, n: n));

  // Habitantes (overworld_biomes.md § 10): todo lo valida el anfitrión.
  bool residentOp(TownOp op, String npc, {String? target}) =>
      _apply(TownAction(op, id: npc, target: target));

  /// El pueblo de la sala (habitantes, casas).
  TownState get townState => _s?.town ?? const TownState();
  bool buyFarmTool(String id) =>
      _apply(FarmShopAction(FarmShopOp.buyTool, id: id));
  bool equipFarmTool(String id) =>
      _apply(FarmShopAction(FarmShopOp.equipTool, id: id));
  bool buyFert(String id, [int n = 1]) =>
      _apply(FarmShopAction(FarmShopOp.buyAbono, id: id, n: n));
  bool sellCrop(String? key, {bool materials = false}) =>
      _apply(FarmShopAction(key == null ? FarmShopOp.sellAll : FarmShopOp.sell,
          id: key, materials: materials));
  bool exchangeCrop(String key) =>
      _apply(FarmShopAction(FarmShopOp.exchange, id: key));

  bool selectSeed(String id) =>
      _apply(FarmShopAction(FarmShopOp.selectSeed, id: id));
  bool stockFish(String species, [String? lakeId]) =>
      _apply(TownAction(TownOp.stock, id: species, target: lakeId));
  // ---- Ayudantes (farming.md § 8, v0.25.5) ----

  bool hireHelper(String buildId) =>
      _apply(TownAction(TownOp.hireHelper, target: buildId));
  bool fireHelper(String buildId) =>
      _apply(TownAction(TownOp.fireHelper, target: buildId));
  bool giveSeeds(String buildId, String seed, int n) =>
      _apply(TownAction(TownOp.giveSeeds, target: buildId, id: seed, n: n));
  bool takeSeeds(String buildId, String seed, int n) =>
      _apply(TownAction(TownOp.takeSeeds, target: buildId, id: seed, n: n));
  bool collectChest(String buildId) =>
      _apply(TownAction(TownOp.collectChest, target: buildId));
  bool setHelperTasks(String buildId, int index, int mask) => _apply(
      TownAction(TownOp.helperTasks, target: buildId, x: index, n: mask));

  double get sessionTime => _s?.time ?? 0;

  /// Segundos hasta la próxima vuelta de los ayudantes.
  double get helperRoundIn => TownRules.nextRoundIn(
      sessionTime, _s?.playerList.where((p) => !p.isCompanion).map((p) => p.profile) ?? const []);

  /// El ayudante al lado del jugador local (tecla G).
  ({TownBuild build, int index})? get nearHelper =>
      _s?.mode == SessionMode.lobby && !isRun && _s?.place == null
          ? TownRules.helperNear(town, local.x, local.y, sessionTime, r: 18)
          : null;

  /// El cofre al lado del jugador local (E: recoger).
  TownBuild? get nearChest => _s?.mode == SessionMode.lobby && !isRun && _s?.place == null
      ? TownRules.chestNear(town, local.x, local.y)
      : null;

  /// El cofre de oficio en el tile [tx], [ty] del mapa (tooltip).
  TownBuild? chestAt(int tx, int ty) {
    if (_s?.mode != SessionMode.lobby || isRun || _s?.place != null) {
      return null;
    }
    final (ox, oy) = town.origin;
    for (final b in town.builds) {
      if (b.kind == BuildKind.casa) continue;
      if (TownRules.chestOf(town, b) == (tx - ox, ty - oy)) return b;
    }
    return null;
  }

  /// El ayudante bajo el mouse (tile del mapa): resalta su área.
  ({TownBuild build, int index})? hoverHelper;

  ({TownBuild build, int index})? helperAt(int tx, int ty) =>
      TownRules.helperNear(town, tx * 16 + 8.0, ty * 16 + 8.0, sessionTime,
          r: 12);

  /// La pantalla del ayudante abierta (construcción, índice).
  (String, int)? helperPanel;

  void openHelper(String buildId, int index) {
    helperPanel = (buildId, index);
    openPanel(WorldPanel.helper);
  }

  /// Mejora [u] del ayudante [i] de [buildId] (farming.md § 8.5).
  bool upgradeHelper(String buildId, int i, HelperUpgrade u) =>
      _apply(TownAction(TownOp.helperUpgrade, target: buildId, x: i, id: u.name));

  /// El cielo del mundo (day_night_weather.md).
  SkyState get sky => town.sky;

  /// Tooltip del ayudante [i] de [b]: título y líneas.
  (String, List<String>) helperInfo(TownBuild b, int i) {
    final farm = b.kind == BuildKind.huerta;
    final secs = helperRoundIn.ceil();
    if (!farm) {
      return (
        'PESCADOR ${i + 1} · NIVEL ${HelperRules.level(b.stat(i))}',
        [
          'Pesca en la orilla del lago y guarda en el cofre.',
          '${TownRules.t.i('fisherCatch') + HelperRules.extraFish(b, i)} peces '
              'por vuelta · sin legendarios',
          'Cofre ${b.chestTotal} · próxima vuelta en $secs s',
        ]
      );
    }
    final next = TownRules.farmerNext(b, i);
    final mask = b.taskMask(i);
    final on = [
      for (final t in HelperTask.values)
        if (mask & t.bit != 0) t.label
    ];
    return (
      'GRANJERO ${i + 1} · NIVEL ${HelperRules.level(b.stat(i))}',
      [
        'Atiende ${TownRules.helperArea(b, i).length} parcelas (resaltadas).',
        'Semillas de la huerta: ${b.seedTotal}',
        'Tareas: ${on.isEmpty ? 'ninguna' : on.join(', ')}',
        'Próximo ciclo: ${next?.label.toLowerCase() ?? 'descansa'} · $secs s',
      ]
    );
  }

  // ---- Edición del pueblo (town_editor.md § 1) ----

  TownEdit? _edit;

  /// La edición en curso (`null` = jugando). Cualquiera de la sala, de
  /// a uno (town_editor.md § 1.3): si el candado del anfitrión es de otro,
  /// la edición se cierra.
  TownEdit? get townEdit {
    final ed = _s?.townEditor;
    return _edit != null &&
            _s?.mode == SessionMode.lobby &&
            _s?.place == null &&
            (ed == null || ed == localId)
        ? _edit
        : null;
  }

  bool get editingTown => townEdit != null;

  /// Por qué no se puede entrar a EDITAR PUEBLO (o `null`): otro jugador
  /// tiene el candado.
  String? get cannotEditTown {
    final ed = _s?.townEditor;
    if (ed == null || ed == localId) return null;
    return 'Está editando ${_s?.players[ed]?.name ?? 'otro jugador'}';
  }

  bool enterTownEdit() {
    if (cannotEditTown != null || _s?.mode != SessionMode.lobby) return false;
    if (!_apply(const TownAction(TownOp.lock))) return false;
    _panel = null;
    _edit = TownEdit();
    stopFishing();
    _emit();
    return true;
  }

  /// Por qué no se puede elegir dónde contratar un ayudante de [kind]
  /// (o `null`): solo el dueño, y tiene que haber alguna huerta o lago.
  String? cannotPickHire(BuildKind kind) {
    if (cannotEditTown case final why?) return why;
    if (!town.builds.any((b) => b.kind == kind)) {
      return kind == BuildKind.huerta
          ? 'No hay huertas en el pueblo'
          : 'No hay lagos en el pueblo';
    }
    return null;
  }

  /// CONTRATAR GRANJERO / PESCADOR de la fuente: cámara libre de la
  /// edición y clic en la huerta o el lago (farming.md § 8).
  bool enterHirePick(BuildKind kind) {
    if (cannotPickHire(kind) != null || !enterTownEdit()) return false;
    _edit!
      ..hire = kind
      ..center = true;
    _emit();
    return true;
  }

  /// Por qué no se puede contratar en [b] en el modo de elegir (o `null`).
  String? hireWhy(TownBuild b) {
    final p = _s?.players[localId]?.profile;
    if (p == null) return 'Sin personaje';
    return TownRules.cannotHire(p, town, b.id);
  }

  void exitTownEdit() {
    if (_edit == null) return;
    _edit = null;
    if (_s?.townEditor == localId || isClient) {
      _apply(const TownAction(TownOp.unlock));
    }
    _emit();
  }

  /// Esc en la edición: primero cierra el menú o cancela el paso.
  void editBack() {
    final e = _edit;
    if (e == null) return;
    if (e.step == TownEditStep.browse || e.hire != null) {
      return exitTownEdit();
    }
    e.reset();
    _emit();
  }

  /// El lado del pueblo cuya franja fantasma ocupa el tile ([tx], [ty]).
  TownSide? editSideAt(int tx, int ty) {
    final m = _s == null ? null : engine.mapFor(_s!);
    if (m == null) return null;
    final inX = tx >= 0 && tx < m.width, inY = ty >= 0 && ty < m.height;
    if (inX && ty < 0 && ty >= -kTownStrip) return TownSide.norte;
    if (inX && ty >= m.height && ty < m.height + kTownStrip) {
      return TownSide.sur;
    }
    if (inY && tx < 0 && tx >= -kTownStrip) return TownSide.oeste;
    if (inY && tx >= m.width && tx < m.width + kTownStrip) {
      return TownSide.este;
    }
    return null;
  }

  /// Por qué no se puede ampliar hacia [side] ahora (o `null`).
  String? cannotExpandTown(TownSide side) {
    final p = _s?.players[localId]?.profile;
    if (p == null) return 'Sin personaje';
    return TownRules.cannotExpand(p, town, side);
  }

  bool expandTown(TownSide side) {
    final before = town.origin;
    if (!_apply(TownAction(TownOp.expand, id: side.code))) return false;
    // La cámara de la edición acompaña al pueblo si se corrió el origen.
    final after = town.origin;
    _edit?.shift =
        ((after.$1 - before.$1) * 16.0, (after.$2 - before.$2) * 16.0);
    _emit();
    return true;
  }

  /// Mouse sobre el tile ([tx], [ty]) en la edición: el fantasma de lo
  /// que se mueve o se pone lo sigue; si no, anota la franja o la
  /// construcción bajo el mouse para el panel de info.
  void editHover(int tx, int ty) {
    final e = _edit;
    if (e == null) return;
    if (e.step != TownEditStep.moving && e.step != TownEditStep.placing) {
      final side = editSideAt(tx, ty);
      final light = TownRules.lightAt(town, tx, ty);
      final b = side != null
          ? null
          : light != null
              ? TownState.lightId(light)
              : (TownRules.buildAt(town, tx, ty) ??
                          TownRules.buildAtSign(town, tx, ty))
                      ?.id ??
                  TownRules.landmarkAt(town, tx, ty)?.id;
      if (side == e.hoverSide && b == e.hoverBuild) return;
      e
        ..hoverSide = side
        ..hoverBuild = b;
      _emit();
      return;
    }
    if (e.ghost == (tx, ty)) return;
    e.ghost = (tx, ty);
    _emit();
  }

  /// Por qué el fantasma no se puede dejar donde está (o `null`).
  String? get editGhostError {
    final e = _edit;
    final g = e?.ghost;
    if (e == null || g == null) return null;
    final (ox, oy) = town.origin;
    if (e.step == TownEditStep.placing && e.placeDef == kFaroId) {
      final p = _s?.players[localId]?.profile;
      if (p != null && p.credits < TownRules.faroCost) {
        return 'Falta oro (${p.credits}/${TownRules.faroCost})';
      }
      return TownRules.lightError(town, g.$1 - ox, g.$2 - oy);
    }
    if (e.step == TownEditStep.placing) {
      return TownRules.place(town, e.placeDef!, g.$1, g.$2).error;
    }
    final from = TownState.parseLightId(e.selected);
    if (e.step == TownEditStep.moving && from != null) {
      return TownRules.lightError(town, g.$1 - ox, g.$2 - oy, ignore: from);
    }
    if (e.step == TownEditStep.moving) {
      return TownRules.move(town, e.selected!, g.$1, g.$2).error;
    }
    return null;
  }

  /// Clic en el tile ([tx], [ty]) en la edición (town_editor.md § 1.2).
  void editClick(int tx, int ty) {
    final e = _edit;
    if (e == null) return;
    if (e.hire case final kind?) {
      final b = TownRules.buildAt(town, tx, ty) ??
          TownRules.buildAtSign(town, tx, ty);
      if (b != null && b.kind == kind && hireWhy(b) == null) {
        if (hireHelper(b.id)) return exitTownEdit();
      }
      return;
    }
    switch (e.step) {
      case TownEditStep.moving || TownEditStep.placing:
        e.ghost = (tx, ty);
        if (editGhostError == null) {
          final ok = e.step == TownEditStep.placing
              ? _apply(TownAction(TownOp.place, id: e.placeDef, x: tx, y: ty))
              : _apply(
                  TownAction(TownOp.move, target: e.selected, x: tx, y: ty));
          if (ok) e.reset();
        }
      default:
        final side = editSideAt(tx, ty);
        final light = TownRules.lightAt(town, tx, ty);
        final b = light != null
            ? null
            : TownRules.buildAt(town, tx, ty) ??
                TownRules.buildAtSign(town, tx, ty);
        final l = b == null && light == null
            ? TownRules.landmarkAt(town, tx, ty)
            : null;
        e.reset();
        // Franja de un lado al tope: gris, no se elige (town_editor.md § 1.3).
        if (light != null) {
          e
            ..step = TownEditStep.options
            ..selected = TownState.lightId(light);
        } else if (side != null && TownRules.sideFull(town, side) != null) {
          // nada
        } else if (side != null) {
          e
            ..step = TownEditStep.side
            ..side = side;
        } else if ((b?.id ?? l?.id) case final id?) {
          e
            ..step = TownEditStep.options
            ..selected = id;
        } else if (_freeTile(tx, ty)) {
          e
            ..step = TownEditStep.choose
            ..tile = (tx, ty);
        }
    }
    _emit();
  }

  bool _freeTile(int tx, int ty) {
    final s = _s;
    if (s == null) return false;
    final m = engine.mapFor(s);
    if (tx < 2 || ty < 2 || tx >= m.width - 2 || ty >= m.height - 2) {
      return false;
    }
    final c = m.tileAt(tx, ty);
    return c == Tile.grass || c == Tile.tree;
  }

  /// Elegir qué construir en el tile libre (paso `choose`).
  void editChoose(String defId) {
    final e = _edit;
    if (e == null || e.tile == null) return;
    e
      ..step = TownEditStep.placing
      ..placeDef = defId
      ..ghost = e.tile;
    _emit();
  }

  void editStartMove() {
    final e = _edit;
    final b = e?.selected == null ? null : town.build(e!.selected!);
    final l = editLandmark;
    final f = TownState.parseLightId(e?.selected);
    if (e == null || (b == null && l == null && f == null)) return;
    final (ox, oy) = town.origin;
    final (ax, ay) = f ?? b?.anchor ?? (l!.x, l.y);
    e
      ..step = TownEditStep.moving
      ..ghost = (ax + ox, ay + oy);
    _emit();
  }

  /// El lugar fijo elegido en la edición (town_editor.md § 3.3).
  TownLandmark? get editLandmark {
    final id = _edit?.selected;
    if (id == null || TownLayout.byId(id) == null) return null;
    return TownPlan.landmarksOf(town).firstWhere((l) => l.id == id);
  }

  void editStep(TownEditStep step) {
    final e = _edit;
    if (e == null) return;
    e.step = step;
    _emit();
  }

  bool editRemove() {
    final e = _edit;
    final id = e?.selected;
    if (e == null || id == null) return false;
    final ok = _apply(TownAction(TownOp.remove, target: id));
    if (ok) e.reset();
    _emit();
    return ok;
  }

  /// La construcción elegida en la edición.
  TownBuild? get editSelected {
    final id = _edit?.selected;
    return id == null ? null : town.build(id);
  }

  /// Cartel bajo el tile ([tx], [ty]) del mapa: título y texto (§ 6).
  (String, String)? signAt(int tx, int ty) {
    final b = TownRules.buildAtSign(town, tx, ty);
    if (b == null) return null;
    return switch (b.kind) {
      BuildKind.lago => ('LAGO', TownRules.lakeSignText(town, b)),
      BuildKind.huerta => ('HUERTA', TownRules.farmSignText(b)),
      BuildKind.casa => (
          'CASA',
          'Nivel ${b.level}'
              '${b.resident == null ? ' · vacía' : ' · vive ${biomeNpcName(b.resident!)}'}'
        ),
    };
  }

  bool takeLifeNode(LifeSkillKind k, String node) =>
      _apply(LifeTreeAction(k.name, node));
  bool resetLifeTree(LifeSkillKind k) => _apply(LifeTreeAction(k.name, null));

  // ---- Pesca en el mapa (fishing.md § 4, v0.22.2) ----

  MapFishing? _fishing;
  FishPhase _fishPrev = FishPhase.idle;
  FishLine? _fishSentLine;
  bool _fishSent = false;
  bool _fishNibble = false;
  final _fishRand = math.Random();

  /// Sonidos de la pesca (los conecta `sessionSfxProvider`).
  void Function(String sfxId)? fishSfx;

  /// La pesca del jugador local en el mapa (`null` = sin caña afuera).
  MapFishing? get mapFishing => _fishing;
  bool get isFishing => _fishing != null;

  bool _townFree() {
    final s = _s;
    return s != null &&
        !isRun &&
        s.mode == SessionMode.lobby &&
        _panel == null &&
        s.players[localId] != null;
  }

  /// Mira al agua (o a un muelle) justo enfrente.
  bool get facingWater =>
      _townFree() &&
      FishingCast.facingWater(
          engine.mapFor(_s!), local.x, local.y, local.fx, local.fy);

  /// Hay orilla del lago al lado (en cualquier dirección).
  bool get canFish =>
      _townFree() &&
      FishingCast.castDir(
              engine.mapFor(_s!), local.x, local.y, local.fx, local.fy) !=
          null;

  /// Saca la caña (E en la orilla). Devuelve si pudo.
  bool startFishing() {
    if (!canFish || _fishing != null) return false;
    final s = _s!;
    final p = s.players[localId]!.profile;
    if (!FishingRules.plausible(p)) return false;
    final b = FishingRules.rodBonus(p);
    final f = MapFishing.start(
        engine.mapFor(s), local.x, local.y, local.fx, local.fy,
        rand: _fishRand.nextDouble,
        biteBonus: b.bite,
        zoneBonus: b.zone,
        biteChance: SkyRules.biteChance(s.town.sky));
    if (f == null) return false;
    _fishing = f;
    _fishPrev = f.phase;
    _fishSentLine = null;
    _fishSent = false;
    _syncFishLine(f);
    fishSfx?.call(Sfx.whump);
    _emit();
    return true;
  }

  /// Mantener E / clic: cargar, clavar, subir la zona.
  void fishPress() {
    final f = _fishing;
    if (f == null) return;
    f.press();
    _fishFx(f);
    _emit();
  }

  /// Soltar E / clic: tirar el lance, bajar la zona.
  void fishRelease() {
    final f = _fishing;
    if (f == null) return;
    f.release();
    _fishFx(f);
    _emit();
  }

  /// Guarda la caña (caminar o Esc). En plena pelea cuenta como escapado.
  void stopFishing() {
    final f = _fishing;
    if (f == null) return;
    if (f.phase == FishPhase.reel && !_fishSent) {
      _fishSent = true;
      fishResult(false);
    }
    f.cancel();
    _fishing = null;
    _fishSentLine = null;
    if (_s?.players[localId]?.fishLine != null) {
      _apply(const FishLineAction(null));
    }
    _emit();
  }

  void _tickFishing(MapFishing f, double dt) {
    f.tick(dt);
    // Clavado sin respuesta del anfitrión: se escapa.
    if (f.phase == FishPhase.hooking && f.game.phaseTime > 3) f.game.cancel();
    final nib = f.game.nibbling;
    if (nib && !_fishNibble) fishSfx?.call(Sfx.turnTick);
    _fishNibble = nib;
    _fishFx(f);
  }

  /// Efectos de cada cambio de fase: sonidos, `fBite` / `fRes` y la línea.
  void _fishFx(MapFishing f) {
    final ph = f.phase;
    if (ph != _fishPrev) {
      final prev = _fishPrev;
      _fishPrev = ph;
      switch (ph) {
        case FishPhase.flying:
          fishSfx?.call(Sfx.frenzyWhoosh);
        case FishPhase.waiting:
          fishSfx?.call(Sfx.potion);
        case FishPhase.bite:
          fishSfx?.call(Sfx.bell);
        case FishPhase.hooking:
          _fishSent = false;
          fishSfx?.call(Sfx.whump);
          fishBite(f.game.power);
        case FishPhase.reel:
          fishSfx?.call(Sfx.clang);
        case FishPhase.won:
          fishSfx?.call(Sfx.lootPickup);
          if (!_fishSent) {
            _fishSent = true;
            fishResult(true);
          }
        case FishPhase.lost:
          fishSfx?.call(Sfx.thaw);
          if (prev == FishPhase.reel && !_fishSent) {
            _fishSent = true;
            fishResult(false);
          }
        default:
          break;
      }
      _emit();
    }
    _syncFishLine(f);
  }

  /// Manda `fLn` solo cuando cambia lo que ven los demás.
  void _syncFishLine(MapFishing f) {
    final l = f.line;
    if (l == _fishSentLine) return;
    _fishSentLine = l;
    _apply(FishLineAction(l));
  }

  /// Texto del aviso de abajo mientras pesca.
  String fishingHint(MapFishing f) => switch (f.phase) {
        FishPhase.idle =>
          '[E o clic] mantené para cargar y soltá para tirar · Esc guarda',
        FishPhase.charging => 'Cargando… soltá para tirar',
        FishPhase.flying => 'La boya vuela…',
        FishPhase.waiting => f.game.nibbling
            ? 'Tantea… todavía no'
            : 'Esperá la picada; si tirás antes, se va',
        FishPhase.bite => '¡PICÓ! [E o clic] ya',
        FishPhase.hooking => 'Clavado…',
        FishPhase.reel =>
          'Mantené [E o clic] para subir la zona; tené al pez adentro',
        FishPhase.won =>
          'Sacaste ${f.fish?.def.name ?? 'un pez'} · [E o clic] para tirar de nuevo',
        FishPhase.lost =>
          '${f.game.lostReason ?? 'Se escapó.'} [E o clic] para tirar de nuevo',
      };

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

  /// La piedra de paso activada junto al jugador local (origen del modo
  /// "elegir destino" del mapa en grande, worldgen.md § 11.4), o `null`.
  MapPoi? get travelOrigin {
    final p = nearPoi;
    final m = _s?.mission;
    if (p == null || m == null || p.kind != PoiKind.waystone) return null;
    return m.poiUsed.contains(p.id) ? p : null;
  }

  /// Puede salir solo de la mazmorra ahora (free_movement.md § 2.4): en la
  /// entrada del piso 1 o junto a una piedra de paso activada. El host lo
  /// vuelve a validar.
  bool get canLeaveDungeon {
    final s = _s;
    if (s == null || isRun || !engine.freeMovement) return false;
    final me = s.players[localId];
    if (me == null) return false;
    final probe = s.copy();
    probe.players[localId]!
      ..x = local.x
      ..y = local.y;
    return engine.canLeave(probe, localId, poiId: travelOrigin?.id);
  }

  /// Junto al altar de la Ofrenda del jefe vencido (persistent_dungeons.md
  /// § 4). El host lo vuelve a validar.
  bool get nearOffering {
    final s = _s;
    if (s == null || isRun || s.players[localId] == null) return false;
    final probe = s.copy();
    probe.players[localId]!
      ..x = local.x
      ..y = local.y;
    return engine.canOffer(probe, localId);
  }

  /// OFRENDAR: paga los materiales y revive al jefe.
  bool offerBoss() {
    if (!nearOffering) return false;
    closePanel();
    return _apply(const OfferBossAction());
  }

  /// SALIR DE LA MAZMORRA: vuelve solo al exterior de la entrada.
  bool leaveDungeon() {
    if (!canLeaveDungeon) return false;
    closePanel();
    return _apply(LeaveDungeonAction(poiId: travelOrigin?.id));
  }

  /// Las piedras a las que se puede viajar desde [travelOrigin].
  List<MapPoi> get travelDestinations {
    final from = travelOrigin;
    final s = _s;
    if (from == null || s == null) return const [];
    final f = engine.mapFor(s).floor(s.mission!.floor);
    return f == null
        ? const []
        : ExplorationRules.waystoneDestinations(f, s.mission!, from);
  }

  /// Viajar a la piedra [toPoi] desde [travelOrigin] (lo valida el host)
  /// y cerrar el mapa.
  bool travelTo(int toPoi) {
    final from = travelOrigin;
    if (from == null || !travelDestinations.any((p) => p.id == toPoi)) {
      return false;
    }
    closePanel();
    _apply(InteractPoiAction(from.id, toPoi: toPoi));
    return true;
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
      } else if (nearForge) {
        openPanel(WorldPanel.forge);
      } else if (nearWorkshop) {
        openPanel(WorldPanel.workshop);
      } else if (nearPortal) {
        openPanel(WorldPanel.ecoPortal);
      } else if (nearEcoPortal case final z?) {
        ecoZone = z;
        openPanel(WorldPanel.ecoZone);
      } else if (nearStatue) {
        openPanel(WorldPanel.ascension);
      } else if (nearLostLoot) {
        openPanel(WorldPanel.lostLoot);
      } else if (nearFountain) {
        openPanel(WorldPanel.fountain);
      } else if (nearTravel) {
        openPanel(WorldPanel.travel);
      } else if (nearNpc case final n?) {
        talkNpc = n;
        openPanel(WorldPanel.biomeNpc);
      } else if (nearFisher != null) {
        openPanel(WorldPanel.biomeFisher);
      } else if (nearForage != null) {
        forage();
      } else if (nearChest case final b? when b.chest.isNotEmpty) {
        collectChest(b.id);
      } else if (farmTile != null) {
        farmWork();
      } else if (facingWater) {
        startFishing();
      } else if (nearTrader) {
        openPanel(WorldPanel.trader);
      } else if (canFish) {
        startFishing();
      } else if (nearEntrance case final e?) {
        enterZone(e);
      }
    } else if (s.mode == SessionMode.field) {
      final seal = nearSeal;
      if (seal != null) {
        _apply(ActivateSealAction(seal.id));
      } else if (nearOffering) {
        openPanel(WorldPanel.offering);
      } else if (nearPoi case final p?) {
        // Piedra activada con destinos: mapa en modo "elegir destino".
        if (travelDestinations.isNotEmpty) {
          openPanel(WorldPanel.map);
        } else {
          _apply(InteractPoiAction(p.id));
        }
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
    // Edición del pueblo: Esc vuelve un paso o sale; el resto no juega.
    if (editingTown) {
      if (key == LogicalKeyboardKey.escape) editBack();
      return key == LogicalKeyboardKey.escape;
    }
    // Travesía: no hay pueblo ni campo; solo cerrar y abrir el personaje.
    if (isRun) {
      if (key == LogicalKeyboardKey.escape) {
        closePanel();
        return true;
      }
      if (s.mode == SessionMode.battle) return false;
      if (key == LogicalKeyboardKey.tab || key == LogicalKeyboardKey.keyC) {
        toggleCharacter();
        return true;
      }
      if (key == LogicalKeyboardKey.keyI) {
        toggleInventory();
        return true;
      }
      return false;
    }
    // Pesca en el mapa (fishing.md § 4): E / Espacio mantenido, Esc
    // guarda la caña.
    if (_fishing != null) {
      if (key == LogicalKeyboardKey.keyE || key == LogicalKeyboardKey.space) {
        fishPress();
        return true;
      }
      if (key == LogicalKeyboardKey.escape) {
        stopFishing();
        return true;
      }
    }
    // G: hablar con el ayudante de al lado (E queda para la huerta).
    if (key == LogicalKeyboardKey.keyG && _panel == null) {
      if (nearHelper case final h?) {
        openHelper(h.build.id, h.index);
        return true;
      }
    }
    if (key == LogicalKeyboardKey.keyE || key == LogicalKeyboardKey.space) {
      interact();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      closePanel();
      return true;
    }
    // Huerta (farming.md § 4): Q otra semilla, F abonar.
    if (_panel == null && farmTile != null) {
      if (key == LogicalKeyboardKey.keyQ ||
          key == LogicalKeyboardKey.bracketRight) {
        cycleSeed();
        return true;
      }
      if (key == LogicalKeyboardKey.bracketLeft) {
        prevSeedPick();
        return true;
      }
    }
    // R: otra mano en la huerta (Tab abre PERSONAJE desde v0.32.4).
    if (_panel == null && nearFarm && key == LogicalKeyboardKey.keyR) {
      cycleFarmHand(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
      return true;
    }
    if (_panel == null && farmTile != null) {
      if (key == LogicalKeyboardKey.keyF) {
        farmFertilize();
        return true;
      }
    }
    // Tab (y C, de alias): abre / cierra PERSONAJE.
    if ((key == LogicalKeyboardKey.tab || key == LogicalKeyboardKey.keyC) &&
        s.mode != SessionMode.battle) {
      if (HardwareKeyboard.instance.isShiftPressed &&
          key == LogicalKeyboardKey.tab) {
        return true;
      }
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
    // L: Llama errante (lighting.md § 3.1.1). Al aire libre va sola de
    // noche: L solo cuenta en mazmorras.
    if (key == LogicalKeyboardKey.keyL &&
        s.mode != SessionMode.battle &&
        !_wispOutdoor()) {
      _apply(WispAction(!(s.players[localId]?.wisp ?? false)));
      return true;
    }
    // J: DIARIO de encargos, en el pueblo o en el campo (roles.md § 8.1).
    if (key == LogicalKeyboardKey.keyJ && s.mode != SessionMode.battle) {
      toggleJournal();
      return true;
    }
    if (key == LogicalKeyboardKey.keyB && s.mode != SessionMode.battle) {
      toggleStash();
      return true;
    }
    // Atajos de pociones fuera de batalla (exploration.md): 1 vida, 2 maná.
    if (s.mode != SessionMode.battle &&
        _panel == null &&
        (key == LogicalKeyboardKey.digit1 ||
            key == LogicalKeyboardKey.digit2)) {
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

  /// Travesía: el grupo está parado en una tienda o una armería del mapa
  /// (ahí la ARMERÍA queda abierta aunque el modo no sea el pueblo).
  static bool _runShopOpen(GameSession s) {
    final r = s.run;
    if (s.mode != SessionMode.run ||
        r == null ||
        r.phase != RunPhase.stop ||
        r.node == null) {
      return false;
    }
    final t = RunRules.floorOf(r).node(r.node!).type;
    return t == RunNodeType.tienda || t == RunNodeType.armeria;
  }

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

  // ---------------- tras la victoria / Loot perdido (v0.20.22) ----------

  /// LISTO para volver al pueblo tras la victoria (missions.md).
  bool setLeaveReady(bool ready) => _apply(LeaveReadyAction(ready));

  /// Toma la pieza [id] del pozo Loot perdido.
  bool takeLostLoot(int id) => _apply(TakeLostLootAction(id));

  int? _closedResult;

  /// El jugador local cerró la ventana de victoria (solo local).
  bool get resultClosed {
    final r = _s?.result;
    return r != null && r.id == _closedResult;
  }

  /// Cierra la ventana de victoria; tras una derrota vuelve al lobby.
  void closeResult() {
    final s = _s;
    final r = s?.result;
    if (s == null || r == null) return;
    if (!s.victoryLap) {
      backToLobby();
      return;
    }
    _closedResult = r.id;
    _emit();
  }

  // ---------------- Travesía (docs/specs/roguelike.md) ----------------

  bool startRun() {
    final m = _meta;
    final ok = _apply(RunStartAction(
        zones: m.zones,
        difficulty: m.difficulty.clamp(0, m.difficultyUnlocked),
        eliteWins: m.eliteWins));
    if (ok) _prepSent = false;
    if (ok && _runSave != null) {
      _runSave = null;
      _emit();
    }
    return ok;
  }

  /// CONTINUAR TRAVESÍA: retoma la run guardada.
  bool continueRun() {
    final s = _s, save = _runSave;
    if (s == null || save == null || isClient) return false;
    final step = engine.resumeRun(s, save);
    _runSave = null;
    if (step == null) {
      _emit();
      return false;
    }
    _commit(step);
    return true;
  }

  /// ABANDONAR: borra la run guardada.
  void abandonRun() {
    _runSave = null;
    unawaited(runSaveStore?.clear().catchError((_) {}));
    _emit();
  }

  Future<void> _loadRunSave() async {
    final store = runSaveStore;
    if (store == null || !isRun) return;
    try {
      _runSave = await store.load();
    } catch (_) {
      _runSave = null;
    }
  }

  /// Guarda la run al entrar a un nodo y al volver al mapa; la borra al
  /// terminar (roguelike.md § 8.5).
  void _saveRun() {
    final store = runSaveStore;
    final r = _s?.run;
    if (store == null || !isRun || isClient || r == null) return;
    final key = '${r.floor}/${r.node}/${r.phase.name}';
    if (key == _runSaveKey) return;
    _runSaveKey = key;
    if (r.phase == RunPhase.over) {
      unawaited(store.clear().catchError((_) {}));
      return;
    }
    if (r.phase == RunPhase.reward) return;
    final save = engine.runSaveOf(_s!);
    if (save != null) unawaited(store.save(save).catchError((_) {}));
  }

  bool voteRunNode(int nodeId) => _apply(RunVoteAction(nodeId));

  bool chooseRunReward(
          {int? tree, int? weapon, int? extra, int? ult, String? drop}) =>
      _apply(RunRewardAction(
          tree: tree, weapon: weapon, extra: extra, ult: ult, drop: drop));

  bool runReady() => _apply(const RunReadyAction());

  /// Travesía: compra una ULT del surtido de la tienda.
  bool buyRunUlt(String ultId) => _apply(RunBuyUltAction(ultId));

  /// Travesía: equipa / guarda una habilidad libre.
  bool setRunSkill(String skillId, {required bool equip}) =>
      _apply(RunSkillAction(skillId, equip: equip));

  /// Travesía: mejora una habilidad libre (armería).
  bool upgradeRunSkill(String skillId) =>
      _apply(RunUpgradeSkillAction(skillId));

  bool cancelPrep() => _apply(const CancelPrepAction());

  bool changeClass(String classId) =>
      _applyFor(actingId, ChangeClassAction(classId));

  bool allocate(Map<Attribute, int> add) =>
      _applyFor(actingId, AllocateStatsAction(add));

  /// El comando de quien tiene el turno si lo controla este dispositivo
  /// (el local o un compañero; solo_party.md § 4); si no, del local.
  bool battleCommand(BattleCommand command) {
    // porBando: en el turno del grupo, el que muestra la vista.
    final cur = _s?.battle?.state.currentId ?? view?.groupActor;
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
        wants: playerId == localId ? _localWants : _companionWants[playerId]);
  }

  bool takeNode(String nodeId) => _applyFor(actingId, TakeNodeAction(nodeId));

  /// Camino en un clic (progression_v2.md § 4).
  bool untakeNode(String nodeId) =>
      _applyFor(actingId, UntakeNodeAction(nodeId));

  bool takeNodes(List<String> ids) => _applyFor(actingId, TakeNodesAction(ids));

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
    if (st == null || !_persist) return;
    try {
      _stash = await st.load();
    } catch (e) {
      EcosLog.error('Alijo', e);
    }
  }

  /// Tecla B / botón ALIJO [B].
  /// Abre / cierra el DIARIO de encargos (roles.md § 8.1).
  void toggleJournal() {
    if (_panel == WorldPanel.questLog) {
      closePanel();
    } else {
      openPanel(WorldPanel.questLog);
    }
  }

  /// SEGUIR / dejar de seguir un encargo (`QuestTrackRules.trackKey`).
  bool trackQuest(String npc, String key) =>
      residentOp(TownOp.track, npc, target: key);

  /// Marca como visto lo que [npc] tiene para decir (diálogo).
  bool markNpcSeen(String npc) => residentOp(TownOp.seen, npc);

  /// Cuenta una charla con [npc] (una por día; overworld_biomes.md § 12).
  bool npcTalked(String npc) => residentOp(TownOp.talk, npc);

  /// Invita al arraigado del bioma actual (dice que no y da su regalo).
  bool nativeInvite() => _apply(TownAction(TownOp.nativeInvite, id: place));

  /// Compra ([buy]) o vende [n] de [species] al arraigado del bioma.
  bool nativeTrade(String species, int n, {required bool buy}) => _apply(
      TownAction(TownOp.nativeTrade,
          id: place, target: species, n: n, x: buy ? 1 : 0));

  void toggleStash() {
    if (isRun) return; // la Travesía no tiene alijo
    if (_panel == WorldPanel.stash) {
      closePanel();
    } else {
      openStash();
    }
  }

  bool openStash() {
    if (isRun || stashBlock != null) return false;
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

  /// TOMAR de Objetos sin recoger (loot.md § 4b): la posición [i] al
  /// inventario del jugador local, por el anfitrión.
  String? unclaimedTake(int i) {
    final why = _stashReady();
    if (why != null) return why;
    final me = _s!.players[localId]!;
    final dry = stashRules.claim(me.profile, _stash!, i);
    if (!dry.ok) {
      _emit();
      return _stashNotice = dry.error;
    }
    final id = _newStashOpId();
    return _sendStash(_StashOp(
      id,
      StashTakeAction(id, [dry.drop!]),
      put: false,
      tab: 0,
      left: 0,
      reason: null,
      cells: const [],
      box: i,
    ));
  }

  /// DESCARTAR de Objetos sin recoger (solo local).
  bool unclaimedDiscard(int i) {
    final s = _stash, st = stashStore;
    final me = _s?.players[localId];
    if (s == null || st == null || me == null || _stashOp != null) {
      return false;
    }
    final next = StashRules.dropUnclaimed(s, i);
    if (next == null) return false;
    _stash = next;
    _stashNotice = 'Descartado';
    unawaited(st.commit(next, me.profile).catchError(_saveFailed));
    _emit();
    return true;
  }

  /// Confirmaciones `rec:N` del host ya guardadas (por jugador).
  final _recApplied = <String>{};

  /// Loot recuperado por el host (`rec:N`, loot.md § 4b) del jugador
  /// local y sus compañeros: al alijo de la cuenta o, si no entra, a
  /// Objetos sin recoger. Un aviso local por pieza.
  void _settleRecovered() {
    final s = _s, st = _stash, store = stashStore;
    final me = s?.players[localId];
    if (s == null || st == null || store == null || me == null) return;
    var next = st;
    final notes = <String>[];
    for (final p in s.players.values) {
      if (!controls(p.id)) continue;
      for (final MapEntry(key: id, value: a) in p.stashAcks.entries) {
        if (!StashAck.isRecover(id) || !_recApplied.add('${p.id}/$id')) {
          continue;
        }
        for (final d in a.drops) {
          if (d == null) continue;
          final r = StashRules.recover(next, d, box: a.box);
          next = r.stash;
          notes.add('${_recoverName(d)} se guardó '
              '${r.toBox ? 'en Objetos sin recoger' : 'en el alijo'}');
        }
      }
    }
    if (identical(next, st)) return;
    _stash = next;
    for (final n in notes) {
      _messages.add(n);
      if (_messages.length > maxMessages) _messages.removeAt(0);
      _addChat(ChatLine.system(n));
    }
    final prof = me.profile;
    unawaited(store.commit(next, prof).catchError(_saveFailed));
  }

  /// Al salir (desconexión o cerrar): lo propio que quedó en el piso del
  /// último estado vuelve a la cuenta (el host lo saca del piso al ver la
  /// salida). En la Travesía no hay piso ni alijo.
  void _recoverLocalGround() {
    final s = _s, st = _stash, store = stashStore;
    final me = s?.players[localId];
    if (s == null || st == null || store == null || me == null) return;
    if (s.run != null || s.ground.isEmpty) return;
    var next = st;
    final left = <GroundLoot>[];
    for (final g in s.ground) {
      final to = s.players[g.recoverTo];
      if (to == null || !controls(to.id)) continue;
      // Lo que el filtro oculta también vuelve, a Objetos sin recoger.
      final hidden = g.ownerId != null &&
          !engine.lootVerdict(to.profile, g.drop, wants: to.buildWants).visible;
      next = StashRules.recover(next, g.drop, box: hidden).stash;
      left.add(g);
    }
    if (left.isEmpty) return;
    s.ground.removeWhere(left.contains);
    _stash = next;
    unawaited(store.commit(next, me.profile).catchError(_saveFailed));
  }

  String _recoverName(LootDrop d) {
    final it = d.item;
    if (it != null) return engine.progression.items.displayName(it);
    if (d.eco != null) return 'Eco';
    return '${d.count} ${d.stack!.label}';
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
          : op.box != null
              ? StashRules.untakeBox(s, op.box!, d)
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
    unawaited(store
        .commit(s, p)
        .then((_) => _saveOk(p), onError: (Object e) => _saveFailed(e)));
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
    final w = _w;
    if (w == null) return false;
    final ws = _we.apply(w, localId, action);
    if (ws == null) return false;
    _world(ws);
    return true;
  }

  /// Como [_apply] pero actuando como [actorId] (un compañero; el motor
  /// valida que este dispositivo lo controle).
  bool _applyFor(String actorId, SessionAction action) {
    if (actorId == localId) return _apply(action);
    final s = _s;
    if (s == null || isClient) return false;
    final w = _w;
    if (w == null) return false;
    final ws = _we.apply(w, localId, action, actorId: actorId);
    if (ws == null) return false;
    _world(ws);
    return true;
  }

  /// Host / local: las instancias de la sala (free_movement.md § 2).
  SessionWorld? _w;
  late final WorldEngine _we = WorldEngine(engine);

  /// Eventos sin difundir por cliente (cada uno, los de su instancia).
  final _unsentBy = <String, List<SessionEvent>>{};

  /// Host: aplica un paso del mundo; la vista es la instancia local.
  void _world(WorldStep ws) {
    final w = _w!;
    for (final e in ws.events.entries) {
      if (e.key == localId) continue;
      _unsentBy.putIfAbsent(e.key, () => []).addAll(e.value);
    }
    _step(SessionStep(w.sessionOf(localId) ?? w.town, ws.eventsFor(localId)));
  }

  /// Host: un paso calculado sobre la instancia local (compañeros,
  /// Travesía retomada).
  void _commit(SessionStep step) {
    final w = _w;
    final key = w?.roomOf(localId);
    if (w == null || key == null || isClient) {
      _step(step);
      return;
    }
    _world(_we.commit(w, key, step));
  }

  /// Cambia lo común en todas las instancias (o en la sala sola).
  void _setAll(GameSession Function(GameSession) f) {
    final w = _w;
    if (w == null) {
      if (_s case final s?) _s = f(s);
      return;
    }
    _we.setAll(w, f);
    _s = w.sessionOf(localId) ?? w.town;
  }

  // ------------------------------------------------------------------
  // Estado
  // ------------------------------------------------------------------

  void _step(SessionStep step) {
    _s = step.state;
    _saveRun();
    _settleRun();
    _sendPrep();
    if (step.state.battle case final b?) _lastBattle = b.state;
    if (role == SessionRole.host && _w == null) _unsent.addAll(step.events);
    var forceSave = false;
    var worldSave = false;
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
        // Pesca en el mapa: el pez que tiró el anfitrión y el aviso.
        case FishBiteEvent(:final playerId, :final species, :final sizeCm)
            when playerId == localId:
          _fishing?.game.hook(FishCatch(species, sizeCm));
        case WaterLootEvent(:final playerId, :final label)
            when playerId == localId:
          _messages.add('Pescaste $label');
          if (_messages.length > maxMessages) _messages.removeAt(0);
        case LightningEvent():
          fishSfx?.call(Sfx.impactBolt);
        case FishCaughtEvent(:final playerId, :final species, :final sizeCm)
            when playerId == localId:
          final name = kFish[species]?.name ?? species;
          _messages.add('Pescaste $name ($sizeCm cm)');
          if (_messages.length > maxMessages) _messages.removeAt(0);
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
        case MissionEndedEvent(:final result):
          forceSave = true;
          if (result.success) _worldCycle++;
          worldSave = true;
        case ReturnedToLobbyEvent():
          forceSave = true;
          worldSave = true;
          _saveFog();
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
    _settleRecovered();
    if (forceSave) _save(force: true);
    if (worldSave) _saveWorld();
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
  /// La Travesía no guarda nada de la cuenta: el personaje de la run es
  /// descartable (docs/specs/roguelike.md § 8.5).
  bool get _persist => engine.gameMode != GameModeKind.travesia;

  /// El pueblo del mundo jugado a disco (lo llama al volver de misión y
  /// al salir). Solo quien corre el motor.
  void _saveWorld() {
    final w = world, cb = onWorldTown, s = _s;
    if (w == null || cb == null || s == null || isClient || isRun) return;
    final codec = SessionJson(engine.catalog);
    // Con las mazmorras de zona abiertas guardadas (persistent_dungeons.md).
    final town = _w == null ? s.town : _we.savedTown(_w!);
    cb(
        w.id,
        town.copyWith(
            upgrades: w.town.upgrades,
            lostLoot: [for (final g in s.lostLoot) codec.groundToJson(g)],
            cycle: _worldCycle));
  }

  /// Se juega la Travesía (la UI arma sus pantallas en vez del pueblo).
  bool get isRun => engine.gameMode == GameModeKind.travesia;

  void _save({bool force = false}) {
    if (!_persist) return;
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
    if (!_persist) return;
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
            _panel == WorldPanel.armory ||
            _panel == WorldPanel.forge)) {
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
            _panel == WorldPanel.workshop ||
            _panel == WorldPanel.forge ||
            _panel == WorldPanel.ecoPortal ||
            _panel == WorldPanel.ecoZone ||
            _panel == WorldPanel.ascension ||
            _panel == WorldPanel.lostLoot ||
            _panel == WorldPanel.trader ||
            _panel == WorldPanel.fountain ||
            _panel == WorldPanel.travel ||
            _panel == WorldPanel.biomeNpc ||
            _panel == WorldPanel.questLog ||
            _panel == WorldPanel.helper) &&
        mode != SessionMode.lobby &&
        !((_panel == WorldPanel.armory || _panel == WorldPanel.forge) &&
            _runShopOpen(s))) {
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
    if (_panel != null || editingTown) return (null, null);
    if (nearArmory) return (WorldPrompt.armory, null);
    if (nearForge) return (WorldPrompt.forge, null);
    if (nearWorkshop) return (WorldPrompt.workshop, null);
    if (nearPortal) return (WorldPrompt.ecoPortal, null);
    if (nearEcoPortal != null) return (WorldPrompt.ecoZone, null);
    if (nearStatue) return (WorldPrompt.statue, null);
    if (nearLostLoot) return (WorldPrompt.lostLoot, null);
    if (nearCounter) return (WorldPrompt.missionBoard, null);
    if (nearFountain) return (WorldPrompt.fountain, null);
    if (nearTravel) return (WorldPrompt.poi, '[E] Mapa de viaje');
    if (nearNpc case final n?) {
      return (WorldPrompt.poi, '[E] Hablar con ${n.name}');
    }
    if (nearFisher case final f?) {
      return (WorldPrompt.poi, '[E] Hablar con ${f.name}');
    }
    if (nearForage case final i?) return (WorldPrompt.poi, forageHint(i));
    final helperTip = nearHelper == null ? '' : ' · ${WorldPrompt.helper.label}';
    if (farmHint() case final h?) return (WorldPrompt.farm, '$h$helperTip');
    if (nearHelper != null) return (WorldPrompt.helper, null);
    if (nearChest case final b?) {
      return (
        WorldPrompt.chest,
        b.chest.isEmpty ? 'Cofre vacío' : '[E] Recoger cofre (${b.chestTotal})'
      );
    }
    if (mapFishing case final f?) return (WorldPrompt.fishing, fishingHint(f));
    if (facingWater) return (WorldPrompt.fishing, null);
    if (nearTrader) return (WorldPrompt.trader, null);
    if (canFish) return (WorldPrompt.fishing, null);
    if (nearSeal != null) return (WorldPrompt.seal, null);
    if (nearOffering) return (WorldPrompt.poi, '[E] Ofrenda del jefe');
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
      required this.cells,
      this.box});

  final String id;
  final SessionAction action;
  final bool put;
  final int tab;
  final int left;
  final String? reason;
  final List<int> cells;

  /// TOMAR de Objetos sin recoger: la posición pedida.
  final int? box;
  double wait = 0;
  int tries = 0;
}

/// Herramienta de oficio en la mano (HUD de herramienta, farming.md § 4).
enum ActiveTool { rod, hoe }

/// Herramienta de huerta en la mano (farming.md § 2.5).
enum FarmHand { hoe, seed, can, fert }
