import '../domain/town_names.dart';
import '../../../game_engine/models/combat_mode.dart';
import '../../../game_engine/models/fog_of_war.dart';
import '../data/fog_store.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../../inventory/domain/item_names.dart';
import '../../../core/i18n/catalog_text.dart';

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
import '../../../game_engine/rules/npc_talk_rules.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/atlas_store.dart';
import '../../../game_engine/models/game_mode.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/data/town_layout.dart';
import '../../../game_engine/data/biomes_catalog.dart';
import '../../../game_engine/rules/biome_rules.dart';
import '../../../game_engine/rules/waystone_rules.dart';
import '../../../game_engine/rules/raft_rules.dart';
import '../../../game_engine/rules/wild_loot_rules.dart';
import '../../../game_engine/rules/action_targeting.dart';
import '../../../game_engine/rules/cozy_rules.dart';
import '../../../game_engine/data/cozy_catalog.dart' show kFarmDecos;
import '../../../game_engine/rules/weather_rules.dart';
import '../../../game_engine/rules/mine_work_rules.dart';
import '../../../game_engine/data/mine_catalog.dart';
import '../../../game_engine/rules/mining_rules.dart';
import '../../../game_engine/rules/shop_interior_rules.dart';
import '../../../game_engine/rules/home_interior_rules.dart';
import '../../../game_engine/data/smithing_catalog.dart'
    show kMineNpcLines, kMineLoreLines;
import '../../../game_engine/rules/eco_portal_rules.dart';
import '../../../game_engine/rules/town_plan.dart';
import '../../../game_engine/models/world_save.dart';
import '../../../game_engine/data/world_events_catalog.dart';
import '../../../game_engine/models/localized_text.dart';
import '../../../game_engine/rules/renown_rules.dart';
import '../../../game_engine/rules/world_event_rules.dart';
import '../../../game_engine/data/construction_catalog.dart' show kFaroId;
import '../../../game_engine/rules/helper_rules.dart';
import '../../../game_engine/rules/sky_rules.dart';
import '../../../game_engine/rules/resident_rules.dart';
import '../../../game_engine/rules/biome_fisher_rules.dart';
import '../../../game_engine/models/custom_npc.dart';
import '../../../game_engine/rules/custom_npc_rules.dart';
import '../../../game_engine/rules/npc_camp_rules.dart';
import '../../../game_engine/rules/town_rules.dart';
import '../../../game_engine/rules/quest_track_rules.dart';
import 'town_edit.dart';
import 'home_edit.dart';
import 'map/home_interior_layer.dart' show HomeGhost;
import '../../../core/procedural/item_icons.dart' show ItemIconImages;
import '../../../game_engine/data/home_furniture_catalog.dart';
import '../../../game_engine/data/weapons_catalog.dart' show kWeapons;
import '../../../game_engine/models/home_layout.dart';
import '../../../game_engine/rules/life_craft_rules.dart' show kLifeMaterials;

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
import '../../../game_engine/rules/bait_rules.dart';
import '../../../game_engine/rules/fishing_rules.dart';
import '../../../game_engine/rules/fishing_minigame.dart';
import '../../../game_engine/rules/map_fishing.dart';
import '../../../game_engine/rules/animal_rules.dart';
import '../../../game_engine/rules/farming_rules.dart';
import '../../../game_engine/rules/life_time_rules.dart';
import '../../../game_engine/rules/profession_gear_rules.dart';
import '../../../game_engine/rules/life_tree_rules.dart';
import '../../../game_engine/models/fish_line.dart';
import '../../../core/audio/sfx_catalog.dart';
import 'local_player.dart';
import 'session_view.dart';
import 'world_text.dart';
import 'world_strings.dart';

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
  )..strings = ref.read(stringsProvider);
  // Texto del jugador en el idioma activo (docs/specs/i18n.md).
  ref.listen(stringsProvider, (_, s) => c.strings = s);
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

  /// Texto del jugador (docs/specs/i18n.md § 3): avisos, motivos y
  /// mensajes que arma el controlador. El provider lo mantiene al día con
  /// el idioma; sin él, es-AR.
  Strings strings = worldFallbackStrings();

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
    _beginSave();
    st.save(fog.archive);
    _endSave();
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
  WorldPanel? _shownPanel;
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
            strings.t('ui.world.ctl.room_created', {'code': code})),
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
      _addChat(ChatLine.system(strings.t('ui.world.ctl.bestiary_added', {'name': name})));
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
    _disposing = true;
    _townSaveTimer?.cancel();
    _gatherTimer?.cancel();
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
    // A failing tick rule is skipped and logged once with its stack
    // (netcode.md § "Tick a prueba de fallos").
    SessionEngine.onRuleError ??= (rule, e, st) =>
        EcosLog.error('Regla del tick "$rule" falló (se saltea)', '$e\n$st');
    try {
      _sendPosition();
      _sinceSave += dt;
      _world(_we.tick(_w!, dt));
      _autoTurn();
      _save();
    } catch (e, st) {
      // Never silent and never every tick: once per distinct error.
      if (_tickErrors.add('${e.runtimeType}|$e') && _tickErrors.length <= 16) {
        EcosLog.error('Tick del anfitrión', '$e\n$st');
      }
    }
  }

  /// Host tick failures already logged.
  final _tickErrors = <String>{};

  /// Turno de un compañero con AUTO (solo_party.md § 4.1).
  void _autoTurn() {
    final s = _s;
    final b = s?.battle;
    if (s == null || b == null || s.paused || !b.waitingForPlayer) return;
    // Action queue (turn_modes.md § 3.1): an AUTO local player agrees the
    // order on its own so the block is never held waiting for it.
    if (_auto.contains(localId) &&
        b.queue.isNotEmpty &&
        !b.queueReady.contains(localId) &&
        b.state.pendingGroup.any((c) => c.id == localId) &&
        b.turnTime >= autoDelay) {
      if (_apply(const ConfirmBattleQueueAction())) return;
    }
    // porBando: en el turno del grupo, el primer compañero con AUTO que
    // falta (roguelike.md § 6).
    final cur = b.state.currentId ??
        b.state.pendingGroup
            .map((p) => p.id)
            .where((id) => _auto.contains(id) && !b.queued(id))
            .firstOrNull;
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
      // Caminar, salir del pueblo o abrir un panel guarda la caña. With
      // auto-fishing a menu also stops it (fishing.md § 6).
      final moving = ix != 0 || iy != 0;
      final away = s.mode != SessionMode.lobby;
      if (moving || away || _panel != null || (_autoFish && menuOpen)) {
        stopFishing(
            why: moving
                ? AutoFishStop.moved
                : away
                    ? AutoFishStop.battle
                    : AutoFishStop.menu);
      } else if (!_autoFish) {
        _tickFishing(f, dt);
      }
    }
    local.step(engine.mapFor(s), ix, iy, dt,
        canMove: _canMove(s, me),
        gateOpen: s.gateOpen,
        raft: me.rafting && me.epoch == local.epoch,
        // Viento del Eco (worldgen.md § 11.3).
        speedMult: me.rafting
            ? GearRules.raftMult(me.profile)
            : s.mode == SessionMode.field
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
  void teleport(double x, double y, {bool moving = false}) {
    final s = _s;
    final me = s?.players[localId];
    if (s == null || me == null) return;
    local
      ..sync(me)
      ..x = x
      ..y = y
      ..moving = moving;
    _apply(MoveAction(x, y,
        epoch: local.epoch, dir: local.dir, moving: moving));
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
    if (spot == null) return strings.t('ui.world.ctl.no_portal');
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

  /// The owner id of the shop counter in front of the local player
  /// (player_shop.md § 6), or `null` (no counter, or a free one).
  String? get nearCounterOwner {
    final s = _s;
    if (s == null || townSpot != TownSpot.stall) return null;
    final i = ShopInteriorRules.counterNear(local.x, local.y);
    final owners = ShopInteriorRules.owners(s.players.values);
    return i == null || i >= owners.length ? null : owners[i];
  }

  /// In front of the player's own counter inside the shop (§ 6).
  bool get nearStall => nearCounterOwner == localId;

  /// The TIENDA door in town, or the exit door inside (§ 6).
  bool get nearShopDoor => townSpot == TownSpot.shop;

  /// Whose stall the open stall panel shows to buy from (another
  /// player's counter); `null` = the local player's own stall.
  String? stallOwner;

  /// Enters the shop from town, or leaves it back to town (§ 6).
  bool travelShop() {
    final s = _s;
    if (s == null || cannotTravel != null) return false;
    closePanel();
    stopFishing();
    return _apply(TravelAction(ShopInteriorRules.isShop(s.place)
        ? kPueblo
        : ShopInteriorRules.place));
  }

  /// Enters the player house from town, or leaves it back to town
  /// (player_house.md § 2).
  bool travelHome() {
    final s = _s;
    if (s == null || cannotTravel != null) return false;
    closePanel();
    stopFishing();
    return _apply(TravelAction(
        HomeInteriorRules.isHome(s.place) ? kPueblo : HomeInteriorRules.place));
  }

  /// The local player is lying in a bed of the house (§ 3).
  bool get inBed => _s?.players[localId]?.inBed ?? false;

  /// Gets into the bed in front (DORMIR) or out of it (§ 3).
  bool toggleSleep() => _apply(SleepAction(!inBed));

  /// "Esperando a los demás (x/n)" while in bed and others are not
  /// (§ 4); `null` otherwise.
  String? get sleepWaitText {
    final w = _s?.sleepWait;
    if (w == null || !inBed) return null;
    return strings.t('ui.world.home.waiting', {'x': w.$1, 'n': w.$2});
  }

  // ---- EDITAR CASA (player_house.md § 8) ----

  HomeEdit? _homeEdit;

  /// The house edit in progress (`null` = playing).
  HomeEdit? get homeEdit => _homeEdit != null &&
          HomeInteriorRules.isHome(_s?.place) &&
          _s?.mode == SessionMode.lobby
      ? _homeEdit
      : null;

  bool get editingHome => homeEdit != null;

  /// The layout the room shows (its owner's, § 8.1).
  HomeLayout get homeLayout {
    final s = _s;
    return s == null ? kDefaultHomeLayout : HomeInteriorRules.layoutOf(s);
  }

  /// The local player's profile (for costs and gates).
  PlayerProfile? get _homeMe => _s?.players[localId]?.profile;

  /// Why EDITAR CASA is grey (`null` = it can open): only the player
  /// whose layout the room shows, and only out of fights and votes.
  String? get cannotEditHome {
    final s = _s;
    if (s == null || !HomeInteriorRules.isHome(s.place)) {
      return strings.t('ui.town.home.edit.busy');
    }
    if (s.mode != SessionMode.lobby) return strings.t('ui.town.home.edit.busy');
    final o = HomeInteriorRules.layoutOwner(s);
    if (o != localId) {
      return strings.t(
          'ui.town.home.edit.not_owner', {'name': s.players[o]?.name ?? '?'});
    }
    return null;
  }

  bool enterHomeEdit() {
    if (cannotEditHome != null) return false;
    _panel = null;
    _homeEdit = HomeEdit();
    stopFishing();
    _emit();
    return true;
  }

  void exitHomeEdit() {
    if (_homeEdit == null) return;
    _homeEdit = null;
    _emit();
  }

  /// Esc in the house edit: drop the piece, then the selection, then
  /// close the palette, then leave.
  void homeEditBack() {
    final e = _homeEdit;
    if (e == null) return;
    if (e.step != HomeEditStep.browse || e.selected != null) {
      e.reset();
    } else if (e.paletteOpen) {
      e.paletteOpen = false;
    } else {
      _homeEdit = null;
    }
    _emit();
  }

  void homeEditTogglePalette() {
    final e = _homeEdit;
    if (e == null) return;
    e.paletteOpen = !e.paletteOpen;
    _emit();
  }

  void homeEditFilter(String f) {
    final e = _homeEdit;
    if (e == null) return;
    e.filter = f;
    _emit();
  }

  void homeEditPick(String? id) {
    final e = _homeEdit;
    if (e == null) return;
    e.picked = id;
    _emit();
  }

  /// The localized reason behind an engine reason (§ 8.3).
  String homeReason(String why) => switch (why) {
        'Va en la pared del fondo' => strings.t('ui.town.home.why.wall'),
        'Fuera de la casa' => strings.t('ui.town.home.why.outside'),
        'Tapa la puerta' => strings.t('ui.town.home.why.door'),
        'Se pisa con otro mueble' => strings.t('ui.town.home.why.overlap'),
        'Así queda un rincón sin paso' => strings.t('ui.town.home.why.blocked'),
        'Tiene que quedar una cama' => strings.t('ui.town.home.why.one_bed'),
        'Ya está puesto' => strings.t('ui.town.home.why.already'),
        _ => why,
      };

  /// Why the local player cannot buy [id] now (`null` = can): town level,
  /// gold, craft material (§ 8.2, § 8.4).
  String? homeBuyWhy(String id) {
    final p = _homeMe;
    if (p == null) return strings.t('ui.town.edit.no_character');
    final need = HomeInteriorRules.levelOf(id);
    final now = HomeInteriorRules.level(town);
    if (now < need) {
      return strings.t('ui.town.home.why.level', {'need': need, 'now': now});
    }
    final c = HomeInteriorRules.costOf(id);
    if (p.credits < c.gold) {
      return strings.t(
          'ui.town.edit.missing_gold', {'have': p.credits, 'need': c.gold});
    }
    for (final m in c.mats.entries) {
      final have = p.life.craft(m.key);
      if (have < m.value) {
        return strings.t('ui.town.home.why.mat', {
          'name': kLifeMaterials[m.key]?.name ?? m.key,
          'have': have,
          'need': m.value
        });
      }
    }
    return null;
  }

  /// Starts placing furniture [id] (closes the palette, § 8.3).
  bool homeStartPlacing(String id) {
    final e = _homeEdit;
    if (e == null || furniture(id) == null || homeBuyWhy(id) != null) {
      return false;
    }
    e
      ..reset()
      ..step = HomeEditStep.placing
      ..placeDef = id
      ..paletteOpen = false;
    _emit();
    return true;
  }

  /// Wall or floor material, or paint `paint:<n>` (§ 8.4).
  bool homeApplySurface(String id) {
    if (id.startsWith('paint:')) {
      final n = int.tryParse(id.substring(6));
      return n != null && _apply(HomeEditAction(HomeOp.paint, n: n));
    }
    return _apply(HomeEditAction(HomeOp.surface, id: id));
  }

  /// The ghost under the mouse while placing or moving.
  HomeGhost? get homeGhost {
    final e = homeEdit;
    final h = e?.hover;
    if (e == null || h == null) return null;
    final l = homeLayout;
    String? id;
    int? moving;
    if (e.step == HomeEditStep.placing) id = e.placeDef;
    if (e.step == HomeEditStep.moving) {
      moving = e.selected;
      id = l.piece(moving ?? -1)?.id;
    }
    if (id == null) return null;
    final d = furniture(id)!;
    final y = d.onWall ? 0 : h.$2;
    return (
      id: id,
      x: h.$1,
      y: y,
      ok: HomeInteriorRules.cannotPlace(l, id, h.$1, y, moving: moving) == null
    );
  }

  /// Why the ghost is red (localized), or `null`.
  String? get homeGhostWhy {
    final g = homeGhost;
    final e = homeEdit;
    if (g == null || e == null || g.ok) return null;
    final why = HomeInteriorRules.cannotPlace(homeLayout, g.id, g.x, g.y,
        moving: e.step == HomeEditStep.moving ? e.selected : null);
    return why == null ? null : homeReason(why);
  }

  void homeHover((int, int)? tile) {
    final e = _homeEdit;
    if (e == null || e.hover == tile) return;
    e.hover = tile;
    _emit();
  }

  /// A click on the room while editing (§ 8.3).
  void homeClick(int tx, int ty) {
    final e = homeEdit;
    if (e == null) return;
    e.hover = (tx, ty);
    final g = homeGhost;
    switch (e.step) {
      case HomeEditStep.placing:
        if (g == null || !g.ok) return;
        _apply(HomeEditAction(HomeOp.place, id: g.id, x: g.x, y: g.y));
        // The piece stays picked to place another, while it can be paid.
        if (homeBuyWhy(g.id) != null) e.reset();
      case HomeEditStep.moving:
        if (g == null || !g.ok) return;
        _apply(HomeEditAction(HomeOp.move, uid: e.selected, x: g.x, y: g.y));
        e.reset();
      case HomeEditStep.browse:
        e.selected = HomeInteriorRules.pieceAt(homeLayout, tx, ty)?.uid;
    }
    _emit();
  }

  void homeStartMove() {
    final e = homeEdit;
    if (e == null || e.selected == null) return;
    e.step = HomeEditStep.moving;
    _emit();
  }

  /// Why the selected piece cannot be removed (localized), or `null`.
  String? get homeRemoveWhy {
    final uid = homeEdit?.selected;
    if (uid == null) return null;
    final why = HomeInteriorRules.cannotRemove(homeLayout, uid);
    return why == null ? null : homeReason(why);
  }

  bool homeRemoveSelected() {
    final e = homeEdit;
    final uid = e?.selected;
    if (e == null || uid == null || homeRemoveWhy != null) return false;
    final ok = _apply(HomeEditAction(HomeOp.remove, uid: uid));
    e.reset();
    _emit();
    return ok;
  }

  /// The icon shape key of weapon [uid] of the room owner (racks, § 8.2).
  String? homeWeaponShape(String uid) {
    final s = _s;
    if (s == null) return null;
    final owner = s.players[HomeInteriorRules.layoutOwner(s)]?.profile;
    final it = owner?.items.where((i) => i.uid == uid).firstOrNull;
    final type = it == null ? null : kWeapons[it.baseId]?.type;
    return type == null ? null : ItemIconImages.keyOf(type.split('+').first);
  }

  /// The rack whose panel is open (§ 8.2).
  int? homeRackUid;

  bool openHomeRack() {
    final s = _s;
    if (s == null || HomeInteriorRules.layoutOwner(s) != localId) {
      addLocalNotice(strings.t('ui.town.home.rack.not_owner'));
      return false;
    }
    final p = HomeInteriorRules.pieceNear(homeLayout, local.x, local.y,
        kind: FurnitureKind.rack);
    if (p == null) return false;
    homeRackUid = p.uid;
    openPanel(WorldPanel.homeRack);
    return true;
  }

  bool setHomeRack(List<String> weapons) {
    final uid = homeRackUid;
    if (uid == null) return false;
    return _apply(HomeEditAction(HomeOp.rack, uid: uid, weapons: weapons));
  }

  /// Lo que dice el cartel del lago: especies y tu nivel de Pesca.
  String get signText {
    final p = _s?.players[localId]?.profile;
    final lake = TownRules.lakeNear(town, local.x, local.y);
    return strings.t('ui.world.ctl.sign', {
      'lake': lake == null ? strings.t('ui.world.ctl.no_lake') : TownRules.lakeSignText(town, lake),
      'level': p == null ? 1 : FishingRules.level(p)
    });
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
    // Two side by side: the hovered one, the one in the last WASD
    // direction, else the nearest (controls.md § Cursor de acción).
    final near = _npcTargets();
    if (near.isEmpty) return null;
    final (px, py) = _myTile;
    final pick = ActionTargeting.select(
      px: px,
      py: py,
      candidates: [for (final (t, _) in near) t],
      hover: _hover,
      facing: _facingStep,
      reach: _actReach,
    );
    for (final (t, n) in near) {
      if (t == pick) return n;
    }
    return null;
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
    final at = NpcCampRules.state(lay.npc, s.time);
    return near(at.x, at.y) ? lay.npc : null;
  }

  /// Abre la pantalla de [n] (clic o E).
  void openResident(BiomeNpcDef n) {
    talkNpc = n;
    openPanel(WorldPanel.biomeNpc);
  }

  /// The world event actor in reach (visitor, wanderer, caravan or an
  /// open rift portal; world_events.md § 3), or `null`.
  ActiveWorldEvent? get nearWorldEvent {
    final s = _s;
    if (s == null || s.mode != SessionMode.lobby || editingTown) return null;
    return WorldEventRules.near(s.town, s.place ?? kPueblo, local.x, local.y,
        player: localId);
  }

  /// The event whose panel is open.
  String? worldEventUid;

  ActiveWorldEvent? get worldEvent => town.events.active
      .where((a) => a.uid == worldEventUid)
      .firstOrNull;

  void openWorldEvent(ActiveWorldEvent a) {
    worldEventUid = a.uid;
    openPanel(WorldPanel.worldEvent);
  }

  /// Accept a resident's town event proposal (renown_town_growth.md
  /// § 6.1; the host schedules it).
  bool scheduleTownEvent(String id) =>
      _apply(ScheduleTownEventAction(id));

  /// INSCRIBIRSE in the town tournament [id] on its day (§ 6.2).
  bool signUpTourney(String id) {
    closePanel();
    stopFishing();
    return _apply(ProposeTourneyAction(id));
  }

  /// Gift or rumor [i] of the event NPC [uid] (world_events.md § 3.6;
  /// the host checks and keeps it once per player).
  bool eventNpcAct(String uid, int i) => _apply(EventNpcActAction(uid, i));

  /// ENTRAR to the rift [uid] (host decides; gathers like missions).
  bool enterRift(String uid) {
    closePanel();
    stopFishing();
    return _apply(ProposeRiftAction(uid));
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

  // ------------- NPC hechos con datos (npc_editor.md § 6) -------------

  /// Los NPC de datos que están en esta sala ahora.
  List<CustomNpcSpot> get customNpcsHere {
    final s = _s;
    if (s == null || s.mode != SessionMode.lobby) return const [];
    return CustomNpcRules.here(s.town, s.place);
  }

  /// El NPC de datos en el tile ([tx], [ty]) o al lado.
  CustomNpcSpot? customNpcAt(int tx, int ty) {
    for (final n in customNpcsHere) {
      if (((n.x / 16).floor() - tx).abs() <= 1 &&
          ((n.y / 16).floor() - ty).abs() <= 1) {
        return n;
      }
    }
    return null;
  }

  /// El NPC de datos frente al jugador local.
  CustomNpcSpot? get nearCustomNpc {
    for (final n in customNpcsHere) {
      if (WorldRules.distance(local.x, local.y, n.x, n.y) < 26) return n;
    }
    return null;
  }

  /// Con quién se habla en [WorldPanel.customNpc].
  String? talkCustom;

  void openCustomNpc(String id) {
    talkCustom = id;
    openPanel(WorldPanel.customNpc);
  }

  /// INVITAR de un NPC de datos (se muda al pueblo).
  bool customInvite(String id) => residentOp(TownOp.invite, id);

  bool fisherDeliver() {
    final b = place;
    return _apply(TownAction(TownOp.fisherReq, id: b));
  }

  /// Frase del habitante (cambia con el día del mundo).
  String npcLine(BiomeNpcDef n) =>
      NpcTalkRules.dayLine(n.id, town.sky.day,
          inTown: town.resident(n.id).invited) ?? '…';

  bool travelPlace(String id) {
    if (cannotTravel != null || id == place) return false;
    if (travelLocked(id) != null) return false;
    closePanel();
    stopFishing();
    return _apply(TravelAction(id));
  }

  // ---------------- mining v2 (mining_smithing.md § 1) ----------------

  /// The mine level the room is in, or `null`.
  MineLevel? get mineLevel {
    final s = _s;
    if (s == null) return null;
    return MiningRules.level(s.place, worldId: s.worldId);
  }

  /// What changed in that level (dug tiles, torches, station, miners).
  MineLevelState get mineState => town.mine(_s?.place ?? '');

  /// In a mine level, free to dig (lobby, no panel).
  bool get inMine =>
      mineLevel != null && _s?.mode == SessionMode.lobby && _panel == null;

  static double _tileDist(double x, double y, int tx, int ty) =>
      WorldRules.distance(x, y, (tx + 0.5) * 16, (ty + 0.5) * 16);

  /// The mine entrance (index) in front of the local player, in a biome.
  int? get nearMineEntrance {
    final s = _s;
    final lay = biomeLayout(s?.place);
    if (s == null || s.mode != SessionMode.lobby || lay == null) return null;
    final spots = MiningRules.entrances(lay);
    for (var i = 0; i < spots.length; i++) {
      final (x, y) = spots[i];
      if (_tileDist(local.x, local.y, x, y) < 26) return i;
    }
    return null;
  }

  /// In a mine, in front of its way up.
  bool get nearMineExit {
    final m = mineLevel;
    if (m == null || _s?.mode != SessionMode.lobby) return false;
    return _tileDist(local.x, local.y, m.exit.$1, m.exit.$2) < 24;
  }

  /// In a mine, next to its shaft down.
  bool get nearShaft {
    final sh = mineLevel?.shaft;
    if (sh == null || _s?.mode != SessionMode.lobby) return false;
    return _tileDist(local.x, local.y, sh.$1, sh.$2) < 20;
  }

  /// The mine NPC (`kMineNpcs` id) in front of the local player.
  String? get nearMineNpc {
    final npc = mineLevel?.npc;
    if (npc == null) return null;
    return _tileDist(local.x, local.y, npc.$2, npc.$3) < 26 ? npc.$1 : null;
  }

  /// Goes into mine [i] of this biome; with [i] `null`, one level up (or
  /// out to the biome from the first level).
  bool travelMine(int? i, {bool down = false}) {
    if (cannotTravel != null) return false;
    final s = _s;
    if (s == null) return false;
    final String to;
    if (i == null) {
      final m = MiningRules.parse(s.place);
      if (m == null) return false;
      final l = m.$3 + (down ? 1 : -1);
      to = l < 0 ? m.$1 : MiningRules.placeOf(m.$1, m.$2, l);
    } else {
      if (biomeLayout(s.place) == null) return false;
      to = MiningRules.placeOf(s.place!, i);
    }
    closePanel();
    stopFishing();
    return _apply(TravelAction(to));
  }

  /// The mine NPC whose dialogue is open (panel `mineNpc`).
  String? talkMineNpcId;

  /// The i18n key of the line of the mine NPC [id] (changes with the
  /// world day).
  String mineNpcLineKey(String id) =>
      'ui.world.mine.npc.$id.${(town.sky.day + id.length) % kMineNpcLines}';

  /// Talk to the mine NPC [id]: opens its dialogue box (cozy_life.md § 3).
  void talkMineNpc(String id) {
    mineHoldEnd();
    talkMineNpcId = id;
    openPanel(WorldPanel.mineNpc);
  }

  /// The mine NPC standing on tile ([x], [y]) within talking reach, or
  /// `null` (a click on her talks, like E).
  String? mineNpcAt(int x, int y) {
    final npc = mineLevel?.npc;
    if (npc == null || npc.$2 != x || npc.$3 != y) return null;
    return nearMineNpc;
  }

  /// What the local player holds in a mine (HUD slots, § 1.6).
  MineHand mineHand = MineHand.pick;

  void selectMineHand(MineHand h) {
    if (mineHand == h) return;
    mineHand = h;
    _emit();
  }

  void cycleMineHand(int d) => selectMineHand(MineHand
      .values[(mineHand.index + d) % MineHand.values.length]);

  /// The tile in front of the local player (the one a swing hits).
  /// Tile picked with the mouse (a click next to the player), kept while
  /// the button is held; `null` = the tile in front.
  (int, int)? _mineAim;

  (int, int) get mineTarget {
    final (px, py) = _myTile;
    // The held click's tile only while still in reach: walking away
    // re-picks (controls.md § Cursor de acción).
    if (ActionTargeting.heldAim(px, py, _mineAim) case final a?) return a;
    final (sx, sy) = _facingStep;
    final ahead = (px + sx, py + sy);
    final lvl = mineLevel;
    if (lvl == null) return ahead;
    // The hovered tile in reach, the one in the last WASD direction, else
    // the nearest rock / find next to the player (controls.md).
    final r = CozyRules.actionReach;
    final rocks = <ActionTarget>[];
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        if (dx == 0 && dy == 0) continue;
        final c = MiningRules.tileAt(lvl, mineState, px + dx, py + dy);
        if (c == Tile.floor || c == MineTile.torch) continue;
        rocks.add(ActionTarget(px + dx, py + dy, ActionTargetKind.rock));
      }
    }
    return ActionTargeting.select(
          px: px,
          py: py,
          candidates: rocks,
          hover: _hover,
          facing: (sx, sy),
          reach: r,
        )?.tile ??
        ahead;
  }

  /// The code of the tile in front.
  String? get mineTargetCode {
    final lvl = mineLevel;
    if (lvl == null) return null;
    final (x, y) = mineTarget;
    return MiningRules.tileAt(lvl, mineState, x, y);
  }

  /// Veins the area pickaxe (Veta sub-path A, life_trees_v2.md § 2.1)
  /// also breaks with a blow on the vein in front: the same pick the host
  /// makes (session_engine_mining), drawn as the area indicator.
  List<(int, int)> get mineAreaTiles {
    final lvl = mineLevel;
    final p = _s?.players[localId]?.profile;
    if (lvl == null || p == null || !inMine) return const [];
    final (x, y) = mineTarget;
    if (!MineTile.veins.contains(MiningRules.tileAt(lvl, mineState, x, y))) {
      return const [];
    }
    var left = GearRules.veinArea(p);
    final tool = MiningRules.tool(p);
    final out = <(int, int)>[];
    for (final (vx, vy) in squareTiles(x, y, 1)) {
      if (left <= 0) break;
      if (vx == x && vy == y) continue;
      final c = MiningRules.tileAt(lvl, mineState, vx, vy);
      if (!MineTile.veins.contains(c) ||
          MiningRules.cannotBreak(c, lvl.level, tool) != null) {
        continue;
      }
      out.add((vx, vy));
      left--;
    }
    return out;
  }

  /// Hits dealt by the local player per tile (prediction for the crack
  /// stages; the host keeps the real count).
  final mineCracks = <int, int>{};

  /// Last local swing (ms of [mineClock]) and its tile, for the swing
  /// animation and the cooldown.
  double lastSwingMs = -1e9;
  (int, int)? lastSwingTile;
  final mineClock = Stopwatch()..start();

  /// Called with each local swing (chips and sparks in the map layer);
  /// `bounced` = the pick cannot break that tile.
  void Function(int tx, int ty, bool bounced)? onMineSwing;

  /// Whether E / the click is held in a mine (keeps the pick raised and
  /// the dig indicator up between hits).
  bool get mineHolding => _mineHold != null;

  /// Ms between hits of the held pick (the swing animation's period).
  double get mineSwingPeriodMs {
    final p = _s?.players[localId]?.profile;
    return p == null
        ? 300
        : MiningRules.tool(p).swing * GearRules.swingMult(p) * 1000;
  }

  /// The tile last hit, its hits dealt (prediction), its total hits and
  /// whether the pick can break it; `null` = no breakable tile there (it
  /// broke, or none hit yet). The map turns it into the dig indicator.
  ((int, int), int, int, bool)? get mineDigState {
    final lvl = mineLevel;
    final p = _s?.players[localId]?.profile;
    final tile = lastSwingTile;
    if (lvl == null || p == null || tile == null || !inMine) return null;
    final (x, y) = tile;
    // Never on a tile the player walked away from (controls.md § Cursor
    // de acción): the bar and the cursor only show in reach.
    final (px, py) = _myTile;
    if (!ActionTargeting.inReach(px, py, x, y)) return null;
    final c = MiningRules.tileAt(lvl, mineState, x, y);
    if (!MineTile.breakable.contains(c) && c != MineTile.bedrock) return null;
    final ok =
        MiningRules.cannotBreak(c, lvl.level, MiningRules.tool(p)) == null;
    return (
      tile,
      ok ? mineCracks[lvl.idx(x, y)] ?? 0 : 0,
      MiningRules.hits(c, lvl.level),
      ok
    );
  }

  Timer? _mineHold;
  double _lastSwingT = -1e9;
  double _lastBlockNotice = -1e9;

  /// Why a swing at the target fails (i18n key), or `null`.
  String? get mineBlock {
    final lvl = mineLevel;
    final p = _s?.players[localId]?.profile;
    final c = mineTargetCode;
    if (lvl == null || p == null || c == null) return null;
    if (!MineTile.breakable.contains(c) && c != MineTile.bedrock) return null;
    return switch (MiningRules.cannotBreak(c, lvl.level, MiningRules.tool(p))) {
      'bedrock' => 'ui.world.mine.why.bedrock',
      'tier' => 'ui.world.mine.why.tier',
      _ => null,
    };
  }

  /// One swing of the held tool at the tile in front (predicts the
  /// crack; the host decides).
  bool mineSwing() {
    final lvl = mineLevel;
    final p = _s?.players[localId]?.profile;
    if (lvl == null || p == null || !inMine) return false;
    final tool = MiningRules.tool(p);
    final now = mineClock.elapsedMilliseconds.toDouble();
    // The rhythm runs on the room clock (the host checks the same one).
    final st = _s!.time;
    // Pico sub-path A: faster swings (GearRules.swingMult).
    if (st - _lastSwingT < tool.swing * GearRules.swingMult(p)) return false;
    final (x, y) = mineTarget;
    final c = MiningRules.tileAt(lvl, mineState, x, y);
    if (MiningRules.cannotBreak(c, lvl.level, tool) case final why?) {
      if (c == MineTile.bedrock || MineTile.breakable.contains(c)) {
        // The pick bounces off; say why (at most every 2 s).
        if (st - _lastBlockNotice > 2) {
          _lastBlockNotice = st;
          addLocalNotice(why == 'tier'
              ? strings.t('ui.world.mine.need_tier',
                  {'n': MiningRules.reqTierOf(c, lvl.level)})
              : strings.t('ui.world.mine.why.bedrock'));
        }
        _lastSwingT = st;
        lastSwingMs = now;
        lastSwingTile = (x, y);
        onMineSwing?.call(x, y, true);
        _emit();
      }
      return false;
    }
    lastSwingMs = now;
    _lastSwingT = st;
    lastSwingTile = (x, y);
    final i = lvl.idx(x, y);
    mineCracks.removeWhere((k, _) =>
        !MineTile.breakable.contains(MiningRules.tileAt(
            lvl, mineState, k % lvl.width, k ~/ lvl.width)));
    mineCracks[i] = (mineCracks[i] ?? 0) + tool.power;
    onMineSwing?.call(x, y, false);
    fishSfx?.call(Sfx.hit);
    return _apply(MineAction(MineOp.dig, x: x, y: y));
  }

  /// E / click held in a mine: swing again at the tool's rhythm (the
  /// drill mines continuously while held).
  void mineHoldStart() {
    if (!inMine || mineHand != MineHand.pick) return;
    mineSwing();
    _mineHold?.cancel();
    _mineHold = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!inMine) return mineHoldEnd();
      mineSwing();
    });
  }

  void mineHoldEnd() {
    // The same release ends a hold-to-gather (cozy_life.md § 3).
    gatherHoldEnd();
    _mineHold?.cancel();
    _mineHold = null;
    _mineAim = null;
  }

  /// E in a mine: the find in front (chest, mushrooms, lore stone,
  /// station spot) or the held tool.
  bool mineUse({(int, int)? at}) {
    final lvl = mineLevel;
    if (lvl == null || !inMine) return false;
    // A new use: only a find / the station below makes it single-press.
    _holdInteracted = false;
    // A click on a tile next to the player aims there (§ 1.12).
    _mineAim = null;
    if (at != null) {
      final (px, py) = _myTile;
      _mineAim = ActionTargeting.heldAim(px, py, at);
    }
    // The cart-station spot nearby wins over the tool (§ 1.7): what the
    // prompt says is what E does.
    if (mineStationSpot case (final sx, final sy)) {
      _holdInteracted = true;
      return _buildMineStation(sx, sy);
    }
    final (x, y) = mineTarget;
    final c = MiningRules.tileAt(lvl, mineState, x, y);
    if (c == MineTile.chest ||
        c == MineTile.relic ||
        c == MineTile.mushroom ||
        c == MineTile.lore ||
        c == MineTile.station) {
      _holdInteracted = true;
    }
    switch (c) {
      case MineTile.chest || MineTile.relic || MineTile.mushroom:
        return _apply(MineAction(MineOp.use, x: x, y: y));
      case MineTile.lore:
        final n = (lvl.level + lvl.index + lvl.biome.length) % kMineLoreLines;
        addLocalNotice(strings.t('ui.world.mine.lore.$n'));
        return true;
      case MineTile.station when !mineState.station:
        return _apply(MineAction(MineOp.use, x: x, y: y));
      case MineTile.station:
        // Built station: the miners panel (§ 1.7).
        openMiners();
        return true;
      default:
    }
    switch (mineHand) {
      case MineHand.pick:
        mineHoldStart();
        return true;
      case MineHand.torch:
        return _apply(MineAction(MineOp.torch, x: x, y: y));
      case MineHand.bomb:
        return _apply(MineAction(MineOp.bomb, x: x, y: y));
      case MineHand.oil:
        final ok = _apply(const MineAction(MineOp.boost));
        if (ok) {
          boostUntilMs = mineClock.elapsedMilliseconds +
              MiningRules.t.d('boostSec') * 1000;
        }
        return ok;
    }
  }

  /// The unbuilt cart-station spot of this level when the local player
  /// is within `stationReachTiles` of it (facing not required), or `null`.
  (int, int)? get mineStationSpot {
    final lvl = mineLevel;
    if (lvl == null || !inMine || mineState.station) return null;
    final (sx, sy) = lvl.station;
    return _tileDist(local.x, local.y, sx, sy) <= MiningRules.stationReach
        ? (sx, sy)
        : null;
  }

  /// E at the station spot: builds it, or says what is missing.
  bool _buildMineStation(int x, int y) {
    final p = _s?.players[localId]?.profile;
    if (p == null) return false;
    final gold = MiningRules.t.i('stationGold');
    final n = MiningRules.t.i('stationIngots');
    final ing = MiningRules.stationIngot;
    if (p.credits < gold || p.life.ore(ing) < n) {
      addLocalNotice(strings.t('ui.world.mine.station_short', {
        'gold': gold,
        'n': n,
        'ingot': strings.t('data.materials.smith.$ing.name'),
      }));
      return false;
    }
    return _apply(MineAction(MineOp.use, x: x, y: y));
  }

  /// The current E / click hold started on an interaction (station,
  /// chest, lore…): it does not repeat into the tool.
  bool _holdInteracted = false;

  /// Local booster clock (HUD), ms of [mineClock].
  double boostUntilMs = 0;
  int get boostLeft => math.max(
      0, ((boostUntilMs - mineClock.elapsedMilliseconds) / 1000).ceil());

  /// Hire / dismiss a miner on this level (needs its station).
  bool hireMiner() => _apply(const MineAction(MineOp.hire));

  /// The miner with the weakest pick that can still improve, or `null`.
  int? get _minerToUpgrade {
    final m = mineState.miners;
    int? best;
    for (var i = 0; i < m.length; i++) {
      if (m[i].tier >= kMineTools.last.tier) continue;
      if (best == null || m[i].tier < m[best].tier) best = i;
    }
    return best;
  }

  /// U at the station: raise the pick of the miner with the weakest one.
  bool upgradeMiner() {
    final k = _minerToUpgrade;
    if (k == null) return false;
    return _apply(MineAction(MineOp.upgrade, n: k));
  }
  bool fireMiner() => _apply(const MineAction(MineOp.fire));

  /// Raise the pick of miner [k] of this level by one tier (§ 1.7; the
  /// host validates gold and ingots).
  bool upgradeMinerAt(int k) => _apply(MineAction(MineOp.upgrade, n: k));

  /// Miner selected when the miners panel opens (G next to a miner).
  int minerPanelFocus = 0;

  /// The miners panel of this level (§ 1.7): needs its station built.
  bool openMiners({int focus = 0}) {
    if (!inMine || !mineState.station) return false;
    minerPanelFocus = focus;
    openPanel(WorldPanel.miners);
    return true;
  }

  /// Index of the miner next to the player, or `null`.
  int? get nearMiner {
    if (!inMine) return null;
    final m = mineState.miners;
    for (var i = 0; i < m.length; i++) {
      if (_tileDist(local.x, local.y, m[i].x, m[i].y) < 26) return i;
    }
    return null;
  }

  /// In the mine, next to its built station.
  bool get nearMineStation {
    final lvl = mineLevel;
    if (lvl == null || !mineState.station) return false;
    return _tileDist(local.x, local.y, lvl.station.$1, lvl.station.$2) < 30;
  }

  /// Hint in front of the target (prompt line).
  String? mineHint() {
    final lvl = mineLevel;
    if (lvl == null) return null;
    final c = mineTargetCode;
    if (mineStationSpot != null || (c == MineTile.station && !mineState.station)) {
      return strings.t('ui.world.mine.prompt_station', {
        'gold': MiningRules.t.i('stationGold'),
        'n': MiningRules.t.i('stationIngots'),
      });
    }
    if (c == MineTile.chest || c == MineTile.relic) {
      return strings.t('ui.world.mine.prompt_chest');
    }
    if (c == MineTile.mushroom) return strings.t('ui.world.mine.prompt_mushroom');
    if (c == MineTile.lore) return strings.t('ui.world.mine.prompt_lore');
    if (nearMineStation) {
      final base = '${strings.t('ui.world.mine.prompt_open_miners')} · ${strings.t('ui.world.mine.prompt_miners', {
        'n': mineState.miners.length,
        'max': MiningRules.t.i('minerMax'),
        'gold': MiningRules.t.i('minerCost'),
      })}';
      final k = _minerToUpgrade;
      final up = k == null
          ? null
          : MineWorkRules.upgradeCost(mineState.miners[k].tier + 1);
      if (up == null) return base;
      return '$base · ${strings.t('ui.world.mine.prompt_miner_up', {
            'tier': mineState.miners[k!].tier + 1,
            'gold': up.gold,
            'n': up.n,
            'ingot': strings.t('data.materials.smith.${up.ingot}.name'),
          })}';
    }
    if (mineBlock case final k?) return strings.t(k);
    return switch (mineHand) {
      MineHand.pick => MineTile.breakable.contains(c)
          ? strings.t('ui.world.mine.prompt_dig')
          : null,
      MineHand.torch => strings.t('ui.world.mine.prompt_torch'),
      MineHand.bomb => strings.t('ui.world.mine.prompt_bomb'),
      MineHand.oil => strings.t('ui.world.mine.prompt_oil'),
    };
  }

  // ---- the town cart station (§ 1.8) ----

  /// Near the town cart station.
  bool get nearCartStation => townSpot == TownSpot.carts;

  /// The first cart parked in town (mine level place), or `null`.
  String? get parkedCart {
    for (final (place, c) in MineWorkRules.townCarts(town.mines)) {
      if (c.phase == CartPhase.town) return place;
    }
    return null;
  }

  /// Unloads the first parked cart.
  bool unloadCart() {
    final p = parkedCart;
    return p != null && _apply(MineAction(MineOp.unload, id: p));
  }

  /// Label of a cart: its mine and biome.
  String cartLabel(String place) {
    final m = MiningRules.parse(place);
    if (m == null) return place;
    return strings.t('ui.world.mine.cart_label', {
      'n': m.$2 + 1,
      'level': m.$3 + 1,
      'biome': biomeDef(m.$1)?.name ?? m.$1,
    });
  }

  /// Buy, craft or sell mining goods (trader / forge).
  bool buyMine(String id, [int n = 1]) =>
      _apply(MineAction(MineOp.buy, id: id, n: n));
  bool craftMine(String id, [String? ore]) =>
      _apply(MineAction(MineOp.craft, id: id, mat: ore));
  bool sellMine(String id, [int n = 1]) =>
      _apply(MineAction(MineOp.sell, id: id, n: n));

  /// La mata del exterior frente al jugador local (índice), o `null`.
  int? get nearForage {
    final s = _s;
    final lay = biomeLayout(s?.place);
    if (s == null || s.mode != SessionMode.lobby || lay == null) {
      return null;
    }
    // Nearest bush in reach, a grown one first: a picked bush never
    // hides the ripe one beside it.
    int? best;
    var bestScore = double.infinity;
    for (var i = 0; i < lay.forage.length; i++) {
      final f = lay.forage[i];
      final d = WorldRules.distance(
          local.x, local.y, (f.x + 0.5) * 16, (f.y + 0.5) * 16);
      if (d >= 24) continue;
      final score = d +
          (BiomeRules.regrowIn(town, lay.id, i, s.time) > 0 ? 1e6 : 0);
      if (score < bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  String forageHint(int i) {
    final lay = biomeLayout(_s?.place) ?? bosqueLayout;
    final name = forageName(lay.forage[i].kind);
    final left = BiomeRules.regrowIn(town, lay.id, i, _s?.time ?? 0).ceil();
    return left > 0
        ? strings.t('ui.world.forage.regrow', {'name': name, 'n': left})
        : strings.t('ui.world.forage.prompt', {'name': name});
  }

  /// Name of what a forage spot of [kind] gives (biome_regions.md § 5).
  String forageName(int kind) {
    final k = kForageKinds[kind.clamp(0, kForageKinds.length - 1)];
    String crop(String id) => strings.t('data.materials.crop.$id.name');
    return switch (k.cls) {
      ForageClass.plant => crop(k.item),
      ForageClass.echoBloom => strings.t('ui.world.forage.echo_bloom'),
      ForageClass.seedBush => strings.t('ui.world.forage.seed_bush'),
      ForageClass.seasonal => crop(
          kSeasonalForage[WeatherRules.season(town.sky.day).index]),
    };
  }

  // ---------------- lake rafts (fishing.md § 15) ----------------

  /// The local player is steering a raft.
  bool get onRaft {
    final me = _s?.players[localId];
    return me != null && me.rafting;
  }

  /// The raft dock in reach of the local player (on foot), or `null`.
  RaftDock? get nearRaftDock {
    final s = _s;
    if (s == null || s.mode != SessionMode.lobby || isRun || onRaft) {
      return null;
    }
    return RaftRules.nearDock(biomeLayout(s.place), local.x, local.y);
  }

  /// On a raft next to a shore: E gets off there.
  bool get canLeaveRaft {
    final s = _s;
    if (s == null || s.mode != SessionMode.lobby || !onRaft) return false;
    return RaftRules.landing(engine.mapFor(s), local.x, local.y) != null;
  }

  /// E at the dock: on the raft (the host places it).
  bool boardRaft() {
    if (nearRaftDock == null) return false;
    stopFishing();
    return _apply(const RaftAction(true));
  }

  /// E by the shore on a raft: back on land (nearest free tile).
  bool leaveRaft() {
    if (!canLeaveRaft) return false;
    stopFishing();
    return _apply(const RaftAction(false));
  }

  // ---------------- region waystones (biome_regions.md § 4) ----------

  /// The region waystone in reach of the local player (index), or `null`.
  int? get nearWaystone {
    final s = _s;
    final lay = biomeLayout(s?.place);
    if (s == null || s.mode != SessionMode.lobby || lay == null) return null;
    return WaystoneRules.near(lay, local.x, local.y);
  }

  String get _me => _s?.players[localId]?.profile.name ?? '';

  /// Waystone [i] of this region is active for the local player.
  bool waystoneActive(int i) {
    final lay = biomeLayout(_s?.place);
    return lay != null && WaystoneRules.isActive(town, _me, lay, i);
  }

  /// E on a waystone: activates it (host validates) and opens the menu.
  void useWaystone(int i) {
    if (!waystoneActive(i)) _apply(WaystoneAction(i));
    openPanel(WorldPanel.waystone);
  }

  /// Fast travel from the waystone in reach to [to].
  bool travelWaystone(int to) {
    final from = nearWaystone;
    if (from == null) return false;
    closePanel();
    stopFishing();
    return _apply(WaystoneAction(from, to: to));
  }

  /// The wilds chest / shrine in reach (biome_exploration.md § 3.3–3.4):
  /// (index, is a shrine), or `null`.
  (int, bool)? get nearWildLoot {
    final s = _s;
    final lay = biomeLayout(s?.place);
    if (s == null || s.mode != SessionMode.lobby || lay == null) return null;
    return WildLootRules.nearest(lay, town, _me, local.x, local.y);
  }

  /// Click on tile ([tx], [ty]): uses the wilds chest / shrine there if
  /// it is the one in reach (same as E).
  bool clickWildLoot(int tx, int ty) {
    final near = nearWildLoot;
    final lay = biomeLayout(_s?.place);
    if (near == null || lay == null) return false;
    final (i, shrine) = near;
    final spot = (shrine ? lay.shrines : lay.chestSpots)[i];
    if (spot != (tx, ty)) return false;
    useWildLoot(i, shrine: shrine);
    return true;
  }

  /// E on a wilds chest / shrine.
  bool useWildLoot(int i, {bool shrine = false}) {
    final lay = biomeLayout(_s?.place);
    if (lay != null &&
        WildLootRules.taken(town, _me, lay.id, i, shrine: shrine)) {
      addLocalNotice(strings.t('ui.world.wild.prompt_done'));
      return false;
    }
    return _apply(WildLootAction(i, shrine: shrine));
  }

  bool forage() {
    final i = nearForage;
    return i != null && _apply(ForageAction(i));
  }

  // ---------------- hold to gather (cozy_life.md § 3) ----------------

  // ------------- action cursor (controls.md § Cursor de acción) -------------

  /// Tile under the mouse and where the player stood when it was set:
  /// the mouse picks the target until the player walks away from there,
  /// then the keyboard (last WASD direction) picks again.
  (int, int)? _aimHover;
  double _aimX = 0, _aimY = 0;

  /// The mouse moved over [tile] (`null` = off the map).
  void aimHover((int, int)? tile) {
    _aimHover = tile;
    _aimX = local.x;
    _aimY = local.y;
  }

  (int, int)? get _hover => _aimHover != null &&
          (local.x - _aimX).abs() < 2 &&
          (local.y - _aimY).abs() < 2
      ? _aimHover
      : null;

  (int, int) get _myTile => ((local.x / 16).floor(), (local.y / 16).floor());

  (int, int) get _facingStep =>
      ActionTargeting.facingStep(local.fx, local.fy);

  /// Bushes and searchable trees in reach of a biome exterior.
  List<ActionTarget> _gatherCandidates() {
    final s = _s;
    final lay = biomeLayout(s?.place);
    if (s == null || s.mode != SessionMode.lobby || lay == null || onRaft) {
      return const [];
    }
    final (px, py) = _myTile;
    final r = CozyRules.actionReach;
    final map = engine.mapFor(s);
    final out = <ActionTarget>[];
    for (var i = 0; i < lay.forage.length; i++) {
      final f = lay.forage[i];
      if (!ActionTargeting.inReach(px, py, f.x, f.y, reach: r)) continue;
      out.add(ActionTarget(f.x, f.y, ActionTargetKind.forage,
          ok: BiomeRules.regrowIn(town, lay.id, i, s.time) <= 0, id: i));
    }
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        final tx = px + dx, ty = py + dy;
        if (!CozyRules.searchable(map, lay.id, town.sky.day, tx, ty)) continue;
        out.add(ActionTarget(tx, ty, ActionTargetKind.tree,
            ok: !CozyRules.searched(town, _me, lay.id, tx, ty)));
      }
    }
    return out;
  }

  /// The bush / tree E or a click works next ([skip]: tiles already worked
  /// in this hold).
  ActionTarget? gatherTargetFor({Set<(int, int)> skip = const {}}) {
    final (px, py) = _myTile;
    return ActionTargeting.select(
        px: px,
        py: py,
        candidates: _gatherCandidates(),
        hover: _hover,
        facing: _facingStep,
        skip: skip,
        reach: CozyRules.actionReach);
  }

  /// The selected bush / tree (drawn with the tile cursor).
  ActionTarget? get gatherTarget => gatherTargetFor();

  /// The selected searchable tree (tile), from any side, or `null`.
  (int, int)? get facingTree => switch (gatherTarget) {
        final g? when g.kind == ActionTargetKind.tree => g.tile,
        _ => null,
      };

  bool _gatherInReach((int, int) t) {
    final (px, py) = _myTile;
    return ActionTargeting.inReach(px, py, t.$1, t.$2,
        reach: CozyRules.actionReach);
  }

  void _gatherStart(ActionTarget g) => g.kind == ActionTargetKind.forage
      ? gatherHoldStart(forage: g.id)
      : gatherHoldStart(tree: g.tile);

  /// I already searched the tree [t] today.
  bool searchedToday((int, int) t) {
    final lay = biomeLayout(_s?.place);
    return lay != null &&
        CozyRules.searched(town, _me, lay.id, t.$1, t.$2);
  }

  /// Seconds the local player holds E to gather (by Cultivo level).
  double get gatherSec {
    final p = _s?.players[localId]?.profile;
    return CozyRules.gatherHoldSec(p == null ? 1 : FarmingRules.level(p));
  }

  Timer? _gatherTimer;
  final _gatherClock = Stopwatch();
  int? _gatherForage;
  (int, int)? _gatherTree;

  /// The hold in progress: (tile, 0..1), or `null`.
  ((int, int), double)? get gatherProgress {
    if (_gatherTimer == null) return null;
    final at = _gatherTree ??
        switch (_gatherForage) {
          final i? => switch (biomeLayout(_s?.place)) {
              final lay? when i < lay.forage.length => (
                  lay.forage[i].x,
                  lay.forage[i].y
                ),
              _ => null,
            },
          null => null,
        };
    if (at == null) return null;
    final k = _gatherClock.elapsedMilliseconds / (gatherSec * 1000);
    return (at, k.clamp(0.0, 1.0));
  }

  /// E / click held on a forage spot or a tree: fills a bar, then
  /// gathers (cozy_life.md § 3). Repeats while held are ignored.
  void gatherHoldStart({int? forage, (int, int)? tree}) {
    if (_gatherTimer != null) return;
    if (tree != null && searchedToday(tree)) {
      addLocalNotice(strings.t('ui.world.cozy.searched'));
      return;
    }
    _gatherForage = forage;
    _gatherTree = tree;
    _gatherClock
      ..reset()
      ..start();
    _gatherTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      final lay = biomeLayout(_s?.place);
      final gf = _gatherForage;
      final still = _gatherTree != null
          ? _gatherInReach(_gatherTree!)
          : gf != null &&
              lay != null &&
              gf < lay.forage.length &&
              _gatherInReach((lay.forage[gf].x, lay.forage[gf].y));
      if (!still) return gatherHoldEnd();
      if (_gatherClock.elapsedMilliseconds >= gatherSec * 1000) {
        final f = _gatherForage, t = _gatherTree;
        gatherHoldEnd();
        final lay2 = biomeLayout(_s?.place);
        _holdDone.add(t ??
            (lay2 != null && f! < lay2.forage.length
                ? (lay2.forage[f].x, lay2.forage[f].y)
                : (-1, f!)));
        if (t != null) {
          _apply(CozyAction(CozyOp.search, x: t.$1, y: t.$2));
        } else if (f != null) {
          _apply(ForageAction(f));
        }
      }
    });
  }

  /// A mouse press on [tile] (no tool in hand): hold-to-gather the bush
  /// in reach on / next to it or the tree faced there, or harvest a ripe
  /// plot (cozy_life.md § 3). Releasing ends it ([gatherHoldEnd]).
  /// Returns whether the press was used.
  bool gatherPress((int, int) tile) {
    final s = _s;
    if (s == null || _panel != null || s.mode != SessionMode.lobby) {
      return false;
    }
    // The mouse is the cursor: a press in reach selects what is there
    // (or the nearest), a press far away does nothing.
    final (px, py) = _myTile;
    if (!ActionTargeting.inReach(px, py, tile.$1, tile.$2,
        reach: CozyRules.actionReach)) {
      return false;
    }
    aimHover(tile);
    if (gatherTarget case final g?) {
      _gatherStart(g);
      return true;
    }
    if (farmTile == tile && farmOp == FarmOp.harvest) return farmWork();
    return false;
  }

  void gatherHoldEnd() {
    _gatherTimer?.cancel();
    _gatherTimer = null;
    _gatherClock.stop();
  }

  bool get gathering => _gatherTimer != null;

  // ---------------- hold = repeat (cozy_life.md § 3) ----------------

  Timer? _holdTimer;

  /// Held with the mouse: the tile under the cursor (`null` = E held).
  (int, int)? _holdTile;
  bool _holdPointer = false;

  /// Targets already worked in this hold (farm tiles, trees; bushes as
  /// `(-1, index)`): each one once per hold.
  final _holdDone = <(int, int)>{};

  /// Whether E / the click is held (repeating).
  bool get holding => _holdTimer != null;

  /// E / the click went down: keep repeating the tool action every
  /// `holdRepeatSec` while held ([holdRelease] ends it). [tile] = the
  /// tile under the cursor for a click.
  void holdStart({(int, int)? tile, bool pointer = false}) {
    _holdPointer = pointer;
    _holdTile = tile;
    if (pointer && tile != null) aimHover(tile);
    _holdDone.clear();
    final t = farmTile;
    if (t != null && farmOp != null) _holdDone.add(t);
    if (gatherTarget case final g?) _holdDone.add(g.tile);
    _holdTimer?.cancel();
    final ms = (CozyRules.holdRepeatSec * 1000).round().clamp(16, 5000);
    _holdTimer =
        Timer.periodic(Duration(milliseconds: ms), (_) => holdRepeat());
  }

  /// The cursor moved while the click is held.
  void holdAim((int, int)? tile) {
    if (_holdPointer) _holdTile = tile;
    aimHover(tile);
  }

  /// E / the click released: ends the repeat, the pick and any bar.
  void holdRelease() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdDone.clear();
    _holdInteracted = false;
    mineHoldEnd();
  }

  /// One repeat of the held E / click: re-reads the target and, if valid,
  /// does the tool action again. Never talks, opens or travels.
  void holdRepeat() {
    final s = _s;
    if (s == null || !mounted) return holdRelease();
    if (_panel != null ||
        s.mode != SessionMode.lobby ||
        _fishing != null ||
        editingTown ||
        onRaft) {
      return;
    }
    if (gathering) return;
    // A hold that began by talking, opening or travelling never repeats
    // (controls.md § Cursor de acción).
    if (_holdInteracted) return;
    if (inMine) {
      // A hold that began on an interaction never turns into swings.
      if (_holdInteracted || mineStationSpot != null) return;
      if (mineHand != MineHand.pick) return;
      // A held click aims at the tile next to the player under the cursor.
      _mineAim = null;
      if (_holdPointer) {
        final (px, py) = _myTile;
        _mineAim = ActionTargeting.heldAim(px, py, _holdTile);
      }
      _mineHold ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
        if (!inMine) return mineHoldEnd();
        mineSwing();
      });
      mineSwing();
      return;
    }
    // Bushes and trees: start the bar on the next one in reach (the
    // hovered one first), each once per hold.
    final lay = biomeLayout(s.place);
    if (lay != null && (!_holdPointer || activeTool == null)) {
      if (gatherTargetFor(skip: _holdDone) case final g? when g.ok) {
        _gatherStart(g);
        return;
      }
    }
    // Farm plots: the one in front, once per hold.
    final t = farmTile;
    if (t != null && !_holdDone.contains(t)) {
      if (_holdPointer && activeTool == null && farmOp != FarmOp.harvest) {
        return;
      }
      // A press inside the farm cooldown just tries again next repeat; a
      // blocked plot is skipped so the hold moves on to the next one.
      if (farmWork() || farmOp == null) _holdDone.add(t);
    }
  }

  /// Buy / toggle a raft decoration (cozy_life.md § 1).
  bool raftDeco(String id) => _apply(CozyAction(CozyOp.raftDeco, id: id));

  /// Prepare a compost recipe (cozy_life.md § 3).
  bool compost(String id) => _apply(CozyAction(CozyOp.compost, id: id));

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
    // One rule with the bushes and trees (controls.md § Cursor de
    // acción): the hovered plot, the one in the last WASD direction, then
    // the nearest; a held E moves on to the next one.
    final (px, py) = _myTile;
    final r = CozyRules.actionReach;
    return ActionTargeting.select(
      px: px,
      py: py,
      candidates: [
        for (var dy = -r; dy <= r; dy++)
          for (var dx = -r; dx <= r; dx++)
            if (_isSoil(px + dx, py + dy))
              ActionTarget(px + dx, py + dy, ActionTargetKind.plot)
      ],
      hover: _hover,
      facing: _facingStep,
      skip: holding ? _holdDone : const {},
      reach: r,
    )?.tile;
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
    if (inMine) return ActiveTool.mine;
    if (!_townFree()) return null;
    if (_fishing != null || canFish) return ActiveTool.rod;
    if (nearFarm) return ActiveTool.hoe;
    return null;
  }

  /// Aviso compacto sobre las pociones (farming.md § 4, fishing.md § 4).
  String? get toolPrompt {
    if (inMine) return mineHint();
    if (_fishing case final f?) return fishingHint(f);
    // Junto a un ayudante, su pantalla primero (antes que "Sin semillas…").
    if (nearHelper != null) return strings.t(WorldPrompt.helper.key);
    if (farmHint() case final h?) return h;
    if (canFish) return strings.t(WorldPrompt.fishing.key);
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
      FarmHand.hoe => pl == null ? null : strings.t('ui.world.ctl.farm.already_tilled'),
      FarmHand.seed => pl == null
          ? strings.t('ui.world.ctl.farm.till_first')
          : pl.planted
              ? strings.t('ui.world.ctl.farm.already_planted')
              : FarmingRules.activeSeed(p) == null
                  ? strings.t('ui.world.tools.no_seeds_tip')
                  : null,
      FarmHand.can => pl == null
          ? strings.t('ui.world.ctl.farm.till_first')
          : !pl.planted
              ? strings.t('ui.world.ctl.farm.plant_first')
              : null,
      FarmHand.fert => pl == null
          ? strings.t('ui.world.ctl.farm.till_first')
          : !pl.planted
              ? strings.t('ui.world.ctl.farm.plant_first')
              : pl.fert != null
                  ? strings.t('ui.world.ctl.farm.already_fert')
                  : farmFert == null
                      ? strings.t('ui.world.tools.no_fert_tip')
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
            ? FarmingRules.activeSeed(p)
            : op == FarmOp.fert
                ? farmFert
                : null));
    if (ok) {
      fishSfx?.call(switch (op) {
        // Cozy farm sounds (cozy_life.md § 2).
        FarmOp.till => Sfx.farmHoe,
        FarmOp.plant => Sfx.turnTick,
        FarmOp.water => Sfx.farmWater,
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

  /// The crop does not grow right now (out of season, farming.md § 15).
  bool _cropPaused(FarmPlot pl) =>
      pl.seed != null &&
      FarmingRules.growthPaused(
          pl, LifeTimeRules.cropGrowth(pl.seed!, townState.sky));

  /// Lo que se sabe de una parcela (aviso y tooltip): quién plantó, quién
  /// regó, el abono y las chances si la cosechás vos.
  String plotInfo(int x, int y) {
    final pl = plotAt(x, y);
    final me = _s?.players[localId]?.profile;
    if (pl == null) return strings.t('ui.world.ctl.farm.untilled');
    if (!pl.planted) return strings.t('ui.world.ctl.farm.empty_plot');
    final c = kCrops[pl.seed]!;
    final r = FarmingRules.ratio(pl);
    final parts = <String>[
      strings.t('ui.world.ctl.farm.plot_line', {
        'crop': c.text,
        'ripe': r >= 1 ? 'yes' : 'no',
        'pct': (r * 100).round(),
        'watered': pl.watered ? 'yes' : 'no'
      }),
      if (_cropPaused(pl)) strings.t('ui.world.ctl.farm.paused_season'),
      if (pl.planter != null) strings.t('ui.world.ctl.farm.planted_by', {'name': pl.planter}),
      if (pl.waterer != null)
        strings.t('ui.world.ctl.farm.watered_by', {'name': pl.waterer, 'n': pl.waterings}),
      if (kFertilizers[pl.fert] case final f?)
        pl.fertBy == null
            ? f.text
            : strings.t('ui.world.ctl.farm.fert_by', {'fert': f.text, 'name': pl.fertBy}),
    ];
    if (me != null) {
      final o = FarmingRules.odds(me, pl);
      parts.add(strings.t('ui.world.ctl.farm.odds', {
        'epic': _pct(o[CropQuality.epico]!),
        'legendary': _pct(o[CropQuality.legendario]!)
      }));
    }
    return parts.join('\n');
  }

  /// Display name of a plantable [id]: crop seed, weapon seed or a living
  /// weapon to replant (profession_gear.md § 3.5).
  String plantableName(String id) {
    if (kCrops[id] case final c?) return c.seedName;
    if (kWeaponSeeds.containsKey(id)) {
      return CatalogText.of(
          'data.items.gear.seed.$id', kWeaponSeedNames[id] ?? id);
    }
    if (id.startsWith(kRegrowItem)) {
      final it = _s?.players[localId]?.profile
          .itemByUid(id.substring(kRegrowItem.length));
      if (it != null) return localItemName(engine.progression.items, it);
    }
    return id;
  }

  /// Texto del aviso de la huerta (sobre las pociones).
  String? farmHint() {
    final t = farmTile;
    final p = _s?.players[localId]?.profile;
    if (t == null || p == null) return null;
    final pl = plotAt(t.$1, t.$2);
    final seed = FarmingRules.activeSeed(p);
    final fert = pl != null &&
            pl.planted &&
            pl.fert == null &&
            farmFert != null &&
            farmHand != FarmHand.fert
        ? ' · ${strings.t('ui.world.ctl.farm.fert_key')}'
        : '';
    // Corto (una línea): el detalle completo está en el tooltip del mouse.
    if (pl != null && pl.planted && FarmingRules.ripe(pl)) {
      final o = FarmingRules.odds(p, pl);
      return strings.t('ui.world.ctl.farm.harvest', {'legendary': _pct(o[CropQuality.legendario]!)});
    }
    if (farmBlockReason case final r?) return r;
    if (farmHand == FarmHand.fert && pl != null && pl.planted) {
      return strings.t('ui.world.ctl.farm.fertilize', {'fert': kFertilizers[farmFert]?.name ?? strings.t('ui.world.ctl.farm.fert_generic')});
    }
    if (pl == null) return strings.t('ui.world.ctl.farm.till');
    if (!pl.planted) {
      // Any plantable: crop seed, weapon seed or a living weapon to
      // replant (v0.49.22: a weapon seed here threw and froze the HUD).
      if (seed == null) return strings.t('ui.world.tools.no_seeds');
      return strings.t('ui.world.ctl.farm.plant', {'crop': kCrops[seed]?.name ?? plantableName(seed)});
    }
    final r = (FarmingRules.ratio(pl) * 100).round();
    final paused = _cropPaused(pl)
        ? ' · ${strings.t('ui.world.ctl.farm.paused_season')}'
        : '';
    return '${strings.t('ui.world.ctl.farm.water', {'pct': r})}$paused$fert';
  }

  bool buySeed(String id, [int n = 1]) =>
      _apply(FarmShopAction(FarmShopOp.buySeed, id: id, n: n));

  // Habitantes (overworld_biomes.md § 10): todo lo valida el anfitrión.
  bool residentOp(TownOp op, String npc, {String? target}) =>
      _apply(TownAction(op, id: npc, target: target));

  /// Claims milestone [i] of resident [npc] (roles.md § 9). Host-validated.
  bool claimMilestone(String npc, int i) =>
      _apply(TownAction(TownOp.claimMilestone, id: npc, n: i));

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

  // ---- Cebos (fishing.md § 14) ----

  /// The bait on the hook (the picked one, else the best owned).
  String? get activeBait {
    final p = _s?.players[localId]?.profile;
    return p == null ? null : BaitRules.active(p);
  }

  List<String> get ownedBaits {
    final p = _s?.players[localId]?.profile;
    return p == null ? const [] : BaitRules.owned(p);
  }

  /// CEBO slot click / F with the rod out: the next owned bait.
  bool cycleBait() => ownedBaits.length > 1 &&
      _apply(const FarmShopAction(FarmShopOp.cycleBait));
  bool selectBait(String id) =>
      _apply(FarmShopAction(FarmShopOp.selectBait, id: id));
  bool buyBait(String id, [int n = 1]) =>
      _apply(FarmShopAction(FarmShopOp.buyBait, id: id, n: n));
  bool craftBait(String id) =>
      _apply(FarmShopAction(FarmShopOp.craftBait, id: id));

  /// Cocina (farming.md § 17): cook [meal] with crops of [quality].
  bool cookMeal(String meal, int quality) =>
      _apply(FarmShopAction(FarmShopOp.cook, id: meal, n: quality));

  /// Eat the meal bag key [key] (replaces the active meal).
  bool eatMeal(String key) =>
      _apply(FarmShopAction(FarmShopOp.eat, id: key));

  /// Give the meal bag key [key] to the player [to] (farming.md § 19.2).
  bool giveMeal(String key, String to) =>
      _apply(FarmShopAction(FarmShopOp.giveMeal, id: key, to: to));

  /// Cook [meal] at [quality] as a feast for everyone in town.
  bool feastMeal(String meal, int quality) =>
      _apply(FarmShopAction(FarmShopOp.feast, id: meal, n: quality));
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

  /// Segundos entre vueltas de los ayudantes (los mismos jugadores que
  /// cuenta el motor).
  double get helperPeriod => TownRules.helperPeriod(
      _s?.playerList.where((p) => !p.isCompanion).map((p) => p.profile) ?? const []);

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
        strings.t('ui.world.ctl.helper.fisher_title', {'n': i + 1, 'level': HelperRules.level(b.stat(i))}),
        [
          strings.t('ui.world.ctl.helper.fisher_line'),
          strings.t('ui.world.ctl.helper.fisher_catch', {'n': TownRules.t.i('fisherCatch') + HelperRules.extraFish(b, i)}),
          strings.t('ui.world.ctl.helper.chest_next', {'n': b.chestTotal, 's': secs}),
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
      strings.t('ui.world.ctl.helper.farmer_title', {'n': i + 1, 'level': HelperRules.level(b.stat(i))}),
      [
        strings.t('ui.world.ctl.helper.farmer_area', {'n': TownRules.helperArea(b, i).length}),
        strings.t('ui.world.ctl.helper.farmer_seeds', {'n': b.seedTotal}),
        strings.t('ui.world.ctl.helper.farmer_tasks', {'list': on.isEmpty ? strings.t('ui.world.ctl.helper.none') : on.join(', ')}),
        strings.t('ui.town.helper.next_cycle', {
          'task': next?.text.toLowerCase() ?? strings.t('ui.town.helper.rests'),
          's': secs
        }),
      ]
    );
  }

  // ---- Farm animals (docs/specs/animals.md) ----

  /// The world day animals count by.
  int get animalDay => math.max(1, town.sky.day);

  /// Night: the animals sleep inside (animals.md § 4.4).
  bool get animalsAsleep => SkyRules.isNight(town.sky);

  /// The animal under the mouse (outlined on the map).
  ({String build, int uid})? hoverAnimal;

  /// The coop / barn whose panel is open, and the animal picked in it.
  String? animalPanelBuild;
  int? animalPanelUid;

  /// Animal care targets in reach of the local player: each animal on
  /// its tile and each egg on its nest (`id` = index in [_animalRefs]).
  final List<(String, int)> _animalRefs = [];

  List<ActionTarget> _animalCandidates() {
    _animalRefs.clear();
    final p = _s?.players[localId]?.profile;
    if (!_townFree() || _s?.place != null || p == null || animalsAsleep) {
      return const [];
    }
    final (px, py) = _myTile;
    final (ox, oy) = town.origin;
    final r = CozyRules.actionReach;
    final out = <ActionTarget>[];
    for (final b in town.builds) {
      if (!b.kind.ranch || b.animals.isEmpty) continue;
      if (!b.bounds.inflate(r + 1).contains(px - ox, py - oy)) continue;
      for (final a in b.animals) {
        final pos = AnimalRules.animalPos(b, a, sessionTime);
        final tile = (pos.x.floor() + ox, pos.y.floor() + oy);
        final step = AnimalRules.next(p, b, a, animalDay);
        final ok = step != AnimalCare.done &&
            !(step == AnimalCare.collect &&
                AnimalRules.collectBlock(p, a) == AnimalBlock.noTool);
        _animalRefs.add((b.id, a.uid));
        out.add(ActionTarget(tile.$1, tile.$2, ActionTargetKind.animal,
            ok: ok, id: _animalRefs.length - 1));
        if (a.ready != null && a.def.tool == null) {
          final (nx, ny) = AnimalRules.nestOf(b, a);
          _animalRefs.add((b.id, a.uid));
          out.add(ActionTarget(nx + ox, ny + oy, ActionTargetKind.animal,
              id: _animalRefs.length - 1));
        }
      }
    }
    return out;
  }

  /// The animal (or egg) E / a click cares for now.
  ActionTarget? get animalTarget {
    final (px, py) = _myTile;
    return ActionTargeting.select(
        px: px,
        py: py,
        candidates: _animalCandidates(),
        hover: _hover,
        facing: _facingStep,
        reach: CozyRules.actionReach);
  }

  ({TownBuild build, FarmAnimal animal})? _animalOf(ActionTarget t) {
    if (t.id < 0 || t.id >= _animalRefs.length) return null;
    final (id, uid) = _animalRefs[t.id];
    final b = town.build(id);
    final a = b?.animal(uid);
    return b == null || a == null ? null : (build: b, animal: a);
  }

  /// The animal under the map tile ([tx], [ty]) (hover outline, tooltip).
  ({TownBuild build, FarmAnimal animal})? animalAt(int tx, int ty) {
    if (animalsAsleep) return null;
    final (ox, oy) = town.origin;
    for (final b in town.builds) {
      if (!b.kind.ranch) continue;
      for (final a in b.animals) {
        final pos = AnimalRules.animalPos(b, a, sessionTime);
        if (pos.x.floor() + ox == tx && pos.y.floor() + oy == ty) {
          return (build: b, animal: a);
        }
      }
    }
    return null;
  }

  /// The coop / barn whose house is next to the local player (E: panel).
  TownBuild? get nearRanchHouse {
    if (!_townFree() || _s?.place != null) return null;
    final (px, py) = _myTile;
    final (ox, oy) = town.origin;
    for (final b in town.builds) {
      if (!b.kind.ranch) continue;
      if (AnimalRules.houseOf(b).inflate(1).contains(px - ox, py - oy)) {
        return b;
      }
    }
    return null;
  }

  /// What E does on [a] of [b] for the local player, as a prompt line.
  String animalPrompt(TownBuild b, FarmAnimal a) {
    final p = _s?.players[localId]?.profile;
    final name = animalPetText(a);
    if (p == null) return name;
    if (a.ready != null) {
      if (AnimalRules.collectBlock(p, a) == AnimalBlock.noTool) {
        return strings.t('ui.town.ranch.prompt_need_tool',
            {'name': name, 'tool': a.def.tool!.text});
      }
      return strings.t('ui.town.ranch.prompt_collect',
          {'name': name, 'item': a.def.productDef.text});
    }
    return switch (AnimalRules.next(p, b, a, animalDay)) {
      AnimalCare.feed => strings.t('ui.town.ranch.prompt_feed', {'name': name}),
      AnimalCare.pet => strings.t('ui.town.ranch.prompt_pet', {'name': name}),
      AnimalCare.done || AnimalCare.collect =>
        strings.t('ui.town.ranch.prompt_done', {'name': name}),
    };
  }

  /// E on an animal: the first missing step (animals.md § 4.2).
  bool careAnimal(String buildId, int uid) {
    final b = town.build(buildId);
    final a = b?.animal(uid);
    final p = _s?.players[localId]?.profile;
    if (b == null || a == null || p == null) return false;
    if (a.ready != null) {
      if (AnimalRules.collectBlock(p, a) != AnimalBlock.noTool) {
        return collectAnimal(buildId, uid);
      }
      addLocalNotice(
          strings.t('ui.town.ranch.need_tool', {'tool': a.def.tool!.text}));
      return false;
    }
    switch (AnimalRules.next(p, b, a, animalDay)) {
      case AnimalCare.feed:
        return feedAnimal(buildId, uid);
      case AnimalCare.pet:
        return petAnimal(buildId, uid);
      case AnimalCare.collect:
        return collectAnimal(buildId, uid);
      case AnimalCare.done:
        if (AnimalRules.feedBlock(p, b, a, animalDay) == AnimalBlock.noHay) {
          addLocalNotice(strings.t('ui.town.ranch.no_hay'));
        }
        return false;
    }
  }

  bool feedAnimal(String id, int uid) =>
      _apply(TownAction(TownOp.animalFeed, target: id, n: uid));
  bool petAnimal(String id, int uid) =>
      _apply(TownAction(TownOp.animalPet, target: id, n: uid));
  bool collectAnimal(String id, int uid) =>
      _apply(TownAction(TownOp.animalCollect, target: id, n: uid));
  bool depositHay(String id) =>
      _apply(TownAction(TownOp.depositHay, target: id));
  bool buyAnimal(String species) =>
      _apply(TownAction(TownOp.buyAnimal, id: species));
  bool buyHay(int n) => _apply(FarmShopAction(FarmShopOp.buyHay, n: n));
  bool buyRanchTool(String id) =>
      _apply(FarmShopAction(FarmShopOp.buyRanchTool, id: id));
  bool makeHay(String cropKey, int n) =>
      _apply(FarmShopAction(FarmShopOp.makeHay, id: cropKey, n: n));
  bool sellGoods([String? key]) =>
      _apply(FarmShopAction(FarmShopOp.sellGoods, id: key));

  /// Cheese / mayonnaise machine (animals.md § 11): [n] of [key].
  bool processGoods(String key, int n) =>
      _apply(FarmShopAction(FarmShopOp.processGoods, id: key, n: n));

  /// Brann forges the legendary animal product [id] (animals.md § 10).
  bool animalForge(String id) =>
      _apply(SmithAction(SmithOp.animalForge, id));

  /// Opens the panel of the coop / barn [buildId] (animal [uid] picked).
  void openAnimals(String buildId, {int? uid}) {
    animalPanelBuild = buildId;
    animalPanelUid = uid;
    openPanel(WorldPanel.animals);
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
    return strings.t('ui.world.ctl.editing', {'name': _s?.players[ed]?.name ?? strings.t('ui.world.ctl.other_player')});
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

  /// Gold "!" over the rune fountain until the local player opens its
  /// panel once (town_editor.md § 1.5); per player, saved in the profile.
  bool get fountainAlert {
    final p = _s?.players[localId]?.profile;
    return p != null && !QuestTrackRules.seenFountain(p);
  }

  /// Why the local player can't hire a [kind] helper yet because of the
  /// PROFESSION level (or `null`), with the current level
  /// (town_editor.md § 1.6).
  String? hireLevelWhy(BuildKind kind) {
    final p = _s?.players[localId]?.profile;
    if (p == null) return null;
    final need = HelperRules.hireCost(kind).level;
    final farm = kind == BuildKind.huerta || kind.ranch;
    final now = farm ? FarmingRules.level(p) : FishingRules.level(p);
    if (now >= need) return null;
    return strings.t(
        farm ? 'ui.town.fountain.need_farming' : 'ui.town.fountain.need_fishing',
        {'need': need, 'now': now});
  }
  /// Por qué no se puede elegir dónde contratar un ayudante de [kind]
  /// (o `null`): solo el dueño, y tiene que haber alguna huerta o lago.
  String? cannotPickHire(BuildKind kind) {
    if (cannotEditTown case final why?) return why;
    if (hireLevelWhy(kind) case final why?) return why;
    if (kind.ranch) {
      // Ranch helper (animals.md § 6): any coop or barn.
      if (!town.builds.any((b) => b.kind.ranch)) {
        return strings.t('ui.world.ctl.no_ranch');
      }
      final p = _s?.players[localId]?.profile;
      if (p != null && FarmingRules.level(p) < AnimalRules.helperLevel) {
        return strings.t('ui.town.ranch.helper_level',
            {'n': AnimalRules.helperLevel});
      }
      return null;
    }
    if (!town.builds.any((b) => b.kind == kind)) {
      return kind == BuildKind.huerta
          ? strings.t('ui.world.ctl.no_farms')
          : strings.t('ui.world.ctl.no_lakes');
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

  /// ASIGNAR CASA desde el diálogo de [npc] (overworld_biomes.md § 10.1):
  /// la cámara de la edición, sin paleta, con las casas libres resaltadas.
  bool enterHousePick(String npc) {
    if (cannotEditTown != null) return false;
    if (ResidentRules.cannotAssignFree(town, npc) != null) return false;
    if (!enterTownEdit()) return false;
    _edit!
      ..houseFor = npc
      ..center = true;
    _emit();
    return true;
  }

  /// ASIGNAR from the rune fountain's house screen (town_editor.md
  /// § 1.1): the same host op as the dialogue's ASIGNAR CASA. Takes the
  /// edit lock for the op when this player does not hold it.
  bool assignHouse(String npc, String houseId) {
    if (cannotEditTown != null) return false;
    final held = _s?.townEditor == localId;
    if (!held && !_apply(const TownAction(TownOp.lock))) return false;
    final ok = residentOp(TownOp.assign, npc, target: houseId);
    if (!held) _apply(const TownAction(TownOp.unlock));
    return ok;
  }

  /// Habitante que acaba de recibir casa: su diálogo abre agradeciendo.
  String? thanksNpc;

  /// Confirma la casa elegida ([TownEdit.selected]) para el habitante.
  bool confirmHouse() {
    final e = _edit;
    final npc = e?.houseFor, id = e?.selected;
    if (e == null || npc == null || id == null) return false;
    if (!residentOp(TownOp.assign, npc, target: id)) return false;
    exitTownEdit();
    final n = biomeNpc(npc);
    if (n != null) {
      thanksNpc = npc;
      openResident(n);
    }
    return true;
  }

  /// Por qué no se puede elegir [b] en el modo de elegir (o `null`).
  String? pickWhy(TownBuild b) {
    if (_edit?.houseFor != null) {
      return b.kind != BuildKind.casa
          ? strings.t('ui.town.edit.house_not_house')
          : b.resident != null
              ? strings.t('ui.town.edit.house_taken')
              : null;
    }
    return hireWhy(b);
  }

  /// A pick for [hire] accepts [k] (any coop or barn for a ranch helper).
  static bool hireKindMatches(BuildKind hire, BuildKind k) =>
      hire.ranch ? k.ranch : hire == k;

  /// Por qué no se puede contratar en [b] en el modo de elegir (o `null`).
  String? hireWhy(TownBuild b) {
    final p = _s?.players[localId]?.profile;
    if (p == null) return 'Sin personaje';
    return hireLevelWhy(b.kind) ?? TownRules.cannotHire(p, town, b.id);
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
    if (e.houseFor != null && e.selected != null) {
      e.selected = null;
      _emit();
      return;
    }
    if (e.step == TownEditStep.browse || e.pick != null) {
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
      final light = _pinAt(tx, ty);
      final b = side != null
          ? null
          : light ??
              (TownRules.buildAt(town, tx, ty) ??
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
    // Farm decorations (cozy_life.md § 2): 1×1 like the lighthouse.
    if (e.step == TownEditStep.placing && kFarmDecos.containsKey(e.placeDef)) {
      final p = _s?.players[localId]?.profile;
      final cost = CozyRules.decorCost(e.placeDef!);
      if (p != null && p.credits < cost) {
        return 'Falta oro (${p.credits}/$cost)';
      }
      return CozyRules.decorError(town, g.$1 - ox, g.$2 - oy);
    }
    if (TownState.parseDecorId(e.selected) case final from?
        when e.step == TownEditStep.moving) {
      return CozyRules.decorError(town, g.$1 - ox, g.$2 - oy, ignore: from);
    }
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
    if (e.houseFor != null) {
      final b = TownRules.buildAt(town, tx, ty) ??
          TownRules.buildAtSign(town, tx, ty);
      e.selected = b != null && pickWhy(b) == null ? b.id : null;
      _emit();
      return;
    }
    if (e.hire case final kind?) {
      final b = TownRules.buildAt(town, tx, ty) ??
          TownRules.buildAtSign(town, tx, ty);
      if (b != null && hireKindMatches(kind, b.kind) && hireWhy(b) == null) {
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
          // Poner deja la pieza elegida para poner otra (town_editor.md
          // § 1.2); mover termina.
          if (ok && e.step == TownEditStep.moving) e.reset();
        }
      default:
        final side = editSideAt(tx, ty);
        final light = _pinAt(tx, ty);
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
            ..selected = light;
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
        }
    }
    _emit();
  }

  /// Elegir en la paleta qué poner (town_editor.md § 1.2): el fantasma
  /// sigue al mouse y cada clic válido pone una. Elegir la misma pieza
  /// otra vez la suelta.
  void editChoose(String defId) {
    final e = _edit;
    if (e == null || e.pick != null) return;
    if (e.step == TownEditStep.placing && e.placeDef == defId) {
      e.reset();
    } else {
      // Al cambiar de pieza el fantasma queda donde estaba el mouse.
      final ghost = e.step == TownEditStep.placing ? e.ghost : null;
      e
        ..reset()
        ..step = TownEditStep.placing
        ..placeDef = defId
        ..ghost = ghost
        // Elegir una pieza cierra la ventana: el mapa queda libre.
        ..buildOpen = false;
    }
    _emit();
  }

  /// Abre o cierra la ventana CONSTRUIR (town_editor.md § 1.2); sin
  /// [open], la alterna.
  void setBuildOpen([bool? open]) {
    final e = _edit;
    if (e == null) return;
    final v = open ?? !e.buildOpen;
    if (v == e.buildOpen) return;
    e.buildOpen = v;
    _emit();
  }

  void editStartMove() {
    final e = _edit;
    final b = e?.selected == null ? null : town.build(e!.selected!);
    final l = editLandmark;
    final f = TownState.parseLightId(e?.selected) ??
        TownState.parseDecorId(e?.selected);
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

  /// The id of the 1×1 piece on map tile ([tx], [ty]): a lighthouse or a
  /// farm decoration (cozy_life.md § 2), or `null`.
  String? _pinAt(int tx, int ty) {
    if (TownRules.lightAt(town, tx, ty) case final l?) {
      return TownState.lightId(l);
    }
    if (CozyRules.decorAt(town, tx, ty) case (_, final x, final y)?) {
      return TownState.decorId(x, y);
    }
    return null;
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
        BuildKind.home => (
            strings.t('ui.town.home.name'),
            strings.t('ui.town.home.info')
          ),
        BuildKind.gallinero || BuildKind.establo => (
            strings.t('ui.town.ranch.${b.kind.name}.name'),
            strings.t('ui.town.ranch.sign', {
              'n': b.animals.length,
              'max': AnimalRules.homeOf(b)!.cap,
              'hay': b.hay,
            })
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
        biteBonus: b.bite +
            (BaitRules.active(p) == null
                ? 0.0
                : BaitRules.bite(BaitRules.active(p)!)),
        zoneBonus: b.zone,
        biteChance: SkyRules.biteChance(s.town.sky, s.place));
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
    if (f == null || _autoFish) return;
    f.press();
    _fishFx(f);
    _emit();
  }

  /// Soltar E / clic: tirar el lance, bajar la zona.
  void fishRelease() {
    final f = _fishing;
    if (f == null || _autoFish) return;
    f.release();
    _fishFx(f);
    _emit();
  }

  // ---- Auto-fishing (fishing.md § 6): the host fishes; R toggles ----

  bool _autoFish = false;
  int _autoCaught = 0;

  /// Auto-fishing on for the local player.
  bool get autoFishing => _autoFish;

  /// Fish auto-caught since it was turned on.
  int get autoFishCaught => _autoCaught;

  /// R with the rod out: turn auto-fishing on (rod idle or line waiting)
  /// or off. Returns whether something changed.
  bool toggleAutoFish() {
    final f = _fishing;
    if (f == null) return false;
    if (_autoFish) {
      _stopAutoFish(AutoFishStop.key);
      _emit();
      return true;
    }
    // Also right after a catch or a miss (won / lost): R used to do
    // nothing there, so auto-fishing never started (v0.49.14).
    if (!const {
      FishPhase.idle,
      FishPhase.waiting,
      FishPhase.won,
      FishPhase.lost
    }.contains(f.phase)) {
      return false;
    }
    if (!_apply(const FishAutoAction(true))) return false;
    _autoFish = true;
    _autoCaught = 0;
    _emit();
    return true;
  }

  /// Local side of stopping; the host's `fAutoOff` brings the log line.
  /// A battle is detected by the host itself.
  void _stopAutoFish(AutoFishStop why) {
    if (!_autoFish) return;
    _autoFish = false;
    if (why != AutoFishStop.battle) _apply(FishAutoAction(false, why));
  }

  /// Log text for a stop reason.
  String autoFishStopText(AutoFishStop why, int n) => strings.t(
      'ui.world.ctl.autofish.stop.${why.name}', {'n': n});

  /// Guarda la caña (caminar o Esc). En plena pelea cuenta como escapado.
  /// [why]: reason given to the host if auto-fishing was on.
  void stopFishing({AutoFishStop why = AutoFishStop.moved}) {
    final f = _fishing;
    if (f == null) return;
    _stopAutoFish(why);
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
  String fishingHint(MapFishing f) => _autoFish
      ? strings.t('ui.world.ctl.fish.auto')
      : switch (f.phase) {
        FishPhase.idle =>
          strings.t('ui.world.ctl.fish.idle'),
        FishPhase.charging => strings.t('ui.world.ctl.fish.charging'),
        FishPhase.flying => strings.t('ui.world.ctl.fish.flying'),
        FishPhase.waiting => f.game.nibbling
            ? strings.t('ui.world.ctl.fish.nibble')
            : strings.t('ui.world.ctl.fish.waiting'),
        FishPhase.bite => strings.t('ui.world.ctl.fish.bite'),
        FishPhase.hooking => strings.t('ui.world.ctl.fish.hooking'),
        FishPhase.reel => strings.t('ui.world.ctl.fish.reel'),
        FishPhase.won => strings.t('ui.world.ctl.fish.won', {'fish': f.fish?.def.text ?? strings.t('ui.world.ctl.fish.a_fish')}),
        FishPhase.lost => strings.t('ui.world.ctl.fish.lost', {'reason': f.game.lostReason ?? strings.t('ui.world.ctl.fish.escaped')}),
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

  /// IR CON [a] (free_movement.md § 2.5): se puede si los dos lugares
  /// están fuera de batalla. El host lo vuelve a validar.
  bool canJoinPlayer(AwayPlayer a) {
    final s = _s;
    if (s == null || isRun || !engine.freeMovement || a.busy) return false;
    return WorldEngine.canJoin(s, s);
  }

  /// IR CON [a]: viaja a la instancia del otro jugador, a su posición.
  bool joinPlayer(AwayPlayer a) {
    if (!canJoinPlayer(a)) return false;
    closePanel();
    return _apply(JoinPlayerAction(a.id));
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

  // ------ every interactable under one cursor (controls.md) ------

  /// Unified reach (tiles) for the selection: each source already keeps
  /// its own range (px) when it offers a candidate.
  static const _actReach = 3;

  /// Kinds worked with a tool / a hold (E held repeats on them).
  static const _toolKinds = {
    ActionTargetKind.tree,
    ActionTargetKind.forage,
    ActionTargetKind.plot,
    ActionTargetKind.rock,
  };

  Object? _actKey;
  _Act? _actPick;

  /// Every interactable in reach of the local player in the World, with
  /// what E / the click does there and what the prompt says
  /// (controls.md § Cursor de acción).
  List<_Act> _actables() {
    final s = _s;
    if (s == null ||
        s.mode != SessionMode.lobby ||
        _panel != null ||
        editingTown ||
        onRaft) {
      return const [];
    }
    final out = <_Act>[];
    void add(ActionTarget t, void Function() run,
            [(WorldPrompt?, String?) Function()? prompt]) =>
        out.add(_Act(t, run, prompt));
    String talk(String name) =>
        strings.t('ui.world.ctl.prompt_talk', {'name': name});
    (int, int) tileOf(double x, double y) =>
        ((x / 16).floor(), (y / 16).floor());
    final lay = biomeLayout(s.place);

    // Town places (buildings, fountain, portal, travel road, signs).
    if (townSpot case final spot?) {
      final t = _spotTile(spot);
      ActionTarget at(ActionTargetKind k) =>
          ActionTarget(t.$1, t.$2, k, key: 'spot:${spot.name}');
      switch (spot) {
        case TownSpot.board:
          add(at(ActionTargetKind.shop),
              () => openPanel(WorldPanel.missionBoard),
              () => (WorldPrompt.missionBoard, null));
        case TownSpot.armory:
          add(at(ActionTargetKind.shop),
              () => openPanel(WorldPanel.armory),
              () => (WorldPrompt.armory, null));
        case TownSpot.forge:
          add(at(ActionTargetKind.shop),
              () => openPanel(WorldPanel.forge),
              () => (WorldPrompt.forge, null));
        case TownSpot.workshop:
          add(at(ActionTargetKind.shop),
              () => openPanel(WorldPanel.workshop),
              () => (WorldPrompt.workshop, null));
        case TownSpot.portal:
          add(at(ActionTargetKind.portal),
              () => openPanel(WorldPanel.ecoPortal),
              () => (WorldPrompt.ecoPortal, null));
        case TownSpot.statue:
          add(at(ActionTargetKind.shop), () => openPanel(WorldPanel.ascension),
              () => (WorldPrompt.statue, null));
        case TownSpot.lostLoot:
          add(at(ActionTargetKind.shop), () => openPanel(WorldPanel.lostLoot),
              () => (WorldPrompt.lostLoot, null));
        case TownSpot.stall:
          // A shop counter (player_shop.md § 6): your own stall, or
          // another player's to buy from; a free counter does nothing.
          if (nearCounterOwner case final o?) {
            add(at(ActionTargetKind.shop), () {
              stallOwner = o == localId ? null : o;
              openPanel(WorldPanel.stall);
            }, () {
              if (o == localId) return (WorldPrompt.stall, null);
              return (
                WorldPrompt.poi,
                strings.t('ui.world.shop.prompt_buy',
                    {'name': _s?.players[o]?.name ?? ''})
              );
            });
          }
        case TownSpot.shop:
          add(at(ActionTargetKind.travel), () => travelShop(),
              () => ShopInteriorRules.isShop(_s?.place)
                  ? (WorldPrompt.poi, strings.t('ui.world.shop.prompt_exit'))
                  : (WorldPrompt.shop, null));
        case TownSpot.home:
          add(at(ActionTargetKind.travel), () => travelHome(),
              () => (
                    WorldPrompt.poi,
                    strings.t(HomeInteriorRules.isHome(_s?.place)
                        ? 'ui.world.home.prompt_exit'
                        : 'ui.world.home.prompt_enter')
                  ));
        case TownSpot.bed:
          add(at(ActionTargetKind.shop), () => toggleSleep(), () {
            final night = SkyRules.isNight(town.sky);
            return (
              WorldPrompt.poi,
              strings.t(inBed
                  ? 'ui.world.home.prompt_wake'
                  : night
                      ? 'ui.world.home.prompt_sleep_morning'
                      : 'ui.world.home.prompt_sleep_night')
            );
          });
        case TownSpot.homeStash:
          add(at(ActionTargetKind.shop), () => openStash(),
              () => (WorldPrompt.poi, strings.t('ui.town.home.prompt_stash')));
        case TownSpot.homeKitchen:
          add(at(ActionTargetKind.shop),
              () => openPanel(WorldPanel.homeKitchen),
              () => (WorldPrompt.poi, strings.t('ui.town.home.prompt_kitchen')));
        case TownSpot.homeRack:
          add(at(ActionTargetKind.shop), () => openHomeRack(),
              () => (WorldPrompt.poi, strings.t('ui.town.home.prompt_rack')));
        case TownSpot.trader:
          add(at(ActionTargetKind.shop), () => openPanel(WorldPanel.trader),
              () => (WorldPrompt.trader, null));
        case TownSpot.fountain:
          add(at(ActionTargetKind.fountain),
              () => openPanel(WorldPanel.fountain),
              () => (WorldPrompt.fountain, null));
        case TownSpot.travel:
          add(at(ActionTargetKind.travel), () => openPanel(WorldPanel.travel),
              () => (WorldPrompt.poi, strings.t('ui.world.ctl.prompt_travel')));
        case TownSpot.carts:
          add(at(ActionTargetKind.station), () {
            if (!unloadCart()) {
              addLocalNotice(strings.t('ui.world.mine.no_cart'));
            }
          }, () {
            final c = parkedCart;
            return (
              WorldPrompt.poi,
              c == null
                  ? strings.t('ui.world.mine.no_cart')
                  : strings.t(
                      'ui.world.mine.prompt_unload', {'name': cartLabel(c)})
            );
          });
        case TownSpot.sign:
          final info = signAt(t.$1, t.$2);
          add(
              at(ActionTargetKind.sign),
              () => addLocalNotice(
                  info == null ? signText : '${info.$1}: ${info.$2}'),
              () => (WorldPrompt.poi, strings.t('ui.world.ctl.prompt_read')));
        default:
          break;
      }
    }
    // Eco portal of a biome exterior.
    if (nearEcoPortal case final z?) {
      if (EcoPortalRules.of(z) case final p?) {
        add(ActionTarget(p.x, p.y, ActionTargetKind.portal, key: 'eco:$z'),
            () {
          ecoZone = z;
          openPanel(WorldPanel.ecoZone);
        }, () => (WorldPrompt.ecoZone, null));
      }
    }
    // Data-made NPCs (npc_editor.md § 6).
    for (final n in customNpcsHere) {
      if (WorldRules.distance(local.x, local.y, n.x, n.y) >= 26) continue;
      final (tx, ty) = tileOf(n.x, n.y);
      add(
          ActionTarget(tx, ty, ActionTargetKind.npc,
              key: 'custom:${n.def.id}'),
          () => openCustomNpc(n.def.id),
          () => (WorldPrompt.poi, talk(n.def.name.text)));
    }
    // World event actors (visitors, wanderers, elites, rift portals).
    for (final a in s.town.events.at(s.place ?? kPueblo)) {
      final d = kWorldEvents.def(a.def);
      if (d == null || !WorldEventRules.hasActor(d.category)) continue;
      final rift = d.category == WorldEventCategory.echoPortal;
      if (rift && s.town.events.clearedBy(a.uid, localId)) continue;
      // A linked data NPC stars in the visit (npc_editor.md § 6.4).
      if (!rift &&
          kCustomNpcs.values.any(
              (n) => n.spawn == CustomNpcSpawn.event && n.place == d.id)) {
        continue;
      }
      final p = WorldEventRules.spot(s.town, a);
      if (p == null ||
          WorldRules.distance(local.x, local.y, p.$1, p.$2) >
              WorldEventRules.range) {
        continue;
      }
      final (tx, ty) = tileOf(p.$1, p.$2);
      final fights = !WorldEventRules.talks(d);
      add(
          ActionTarget(
              tx, ty, rift ? ActionTargetKind.portal : ActionTargetKind.npc,
              key: 'event:${a.uid}'),
          () => fights ? enterRift(a.uid) : openWorldEvent(a),
          () => (
                WorldPrompt.poi,
                rift
                    ? strings.t('ui.town.events.prompt_rift')
                    : fights
                        ? strings.t('ui.town.events.prompt_fight',
                            {'name': d.title.text})
                        : talk(d.title.text)
              ));
    }
    // Biome NPC / town residents.
    for (final (t, n) in _npcTargets()) {
      add(t, () => openResident(n), () => (WorldPrompt.poi, talk(n.name)));
    }
    if (lay != null) {
      // Native fisher of the biome (fishing.md § 12).
      if (kBiomeFishers[lay.id] case final f?) {
        final (x, y) = BiomeFisherRules.position(lay, s.time);
        if (WorldRules.distance(local.x, local.y, x, y) < 26) {
          final (tx, ty) = tileOf(x, y);
          add(
              ActionTarget(tx, ty, ActionTargetKind.npc,
                  key: 'fisher:${lay.id}'),
              () => openPanel(WorldPanel.biomeFisher),
              () => (WorldPrompt.poi, talk(f.name)));
        }
      }
      // Mine mouths.
      final mouths = MiningRules.entrances(lay);
      for (var i = 0; i < mouths.length; i++) {
        final (x, y) = mouths[i];
        if (_tileDist(local.x, local.y, x, y) >= 26) continue;
        add(ActionTarget(x, y, ActionTargetKind.mine, key: 'mine:$i'),
            () => travelMine(i),
            () => (WorldPrompt.poi, strings.t('ui.world.mine.prompt_enter')));
      }
      // Region waystone.
      if (nearWaystone case final i?) {
        final w = lay.waystones[i];
        add(ActionTarget(w.x, w.y, ActionTargetKind.waystone, key: 'way:$i'),
            () => useWaystone(i),
            () => (
                  WorldPrompt.poi,
                  strings.t(waystoneActive(i)
                      ? 'ui.world.way.prompt_use'
                      : 'ui.world.way.prompt_activate')
                ));
      }
      // Wilds chests and shrines (biome_exploration.md § 3.3–3.4).
      for (final (list, shrine) in [
        (lay.chestSpots, false),
        (lay.shrines, true)
      ]) {
        for (var i = 0; i < list.length; i++) {
          final (tx, ty) = list[i];
          if (_tileDist(local.x, local.y, tx, ty) > WildLootRules.reach) {
            continue;
          }
          final done =
              WildLootRules.taken(town, _me, lay.id, i, shrine: shrine);
          add(
              ActionTarget(tx, ty,
                  shrine ? ActionTargetKind.shrine : ActionTargetKind.chest,
                  ok: !done, key: '${shrine ? 'shrine' : 'wild'}:$i'),
              () => useWildLoot(i, shrine: shrine),
              () => (
                    done ? WorldPrompt.spent : WorldPrompt.poi,
                    strings.t(done
                        ? 'ui.world.wild.prompt_done'
                        : shrine
                            ? 'ui.world.wild.prompt_shrine'
                            : 'ui.world.wild.prompt_chest')
                  ));
        }
      }
      // Raft dock.
      if (nearRaftDock case final d?) {
        add(ActionTarget(d.x, d.y, ActionTargetKind.dock, key: 'dock'),
            boardRaft,
            () => (WorldPrompt.poi, strings.t('ui.world.raft.prompt_board')));
      }
      // Bushes and searchable trees (hold to gather).
      for (final g in _gatherCandidates()) {
        add(g, () => _gatherStart(g), () {
          if (g.kind == ActionTargetKind.forage) {
            return (WorldPrompt.poi, forageHint(g.id));
          }
          return (
            g.ok ? WorldPrompt.poi : WorldPrompt.spent,
            strings.t(g.ok
                ? 'ui.world.cozy.search_prompt'
                : 'ui.world.cozy.searched')
          );
        });
      }
    }
    // Mines: way up, shaft, the mine NPC and the rocks / finds.
    if (mineLevel case final m?) {
      if (nearMineExit) {
        add(
            ActionTarget(m.exit.$1, m.exit.$2, ActionTargetKind.mine,
                key: 'exit'),
            () => travelMine(null),
            () => (WorldPrompt.poi, strings.t('ui.world.mine.prompt_exit')));
      }
      if (nearShaft) {
        final sh = m.shaft!;
        add(ActionTarget(sh.$1, sh.$2, ActionTargetKind.mine, key: 'shaft'),
            () => travelMine(null, down: true),
            () => (WorldPrompt.poi, strings.t('ui.world.mine.prompt_down')));
      }
      if (nearMineNpc case final id?) {
        final npc = m.npc!;
        add(
            ActionTarget(npc.$2, npc.$3, ActionTargetKind.npc,
                key: 'minenpc:$id'),
            () => talkMineNpc(id),
            () => (
                  WorldPrompt.poi,
                  talk(strings.t('ui.world.mine.npc.$id.name'))
                ));
      }
      if (inMine) {
        for (final r in _mineCandidates()) {
          add(r, () => mineUse(at: r.tile));
        }
      }
    }
    // Town: craft chests, build signs and the farm plot.
    if (!isRun && s.place == null) {
      final (ox, oy) = town.origin;
      if (nearChest case final b?) {
        final (cx, cy) = TownRules.chestOf(town, b);
        add(
            ActionTarget(cx + ox, cy + oy, ActionTargetKind.chest,
                ok: b.chest.isNotEmpty, key: 'chest:${b.id}'),
            () {
          if (b.chest.isNotEmpty) collectChest(b.id);
        },
            () => (
                  WorldPrompt.chest,
                  b.chest.isEmpty
                      ? strings.t('ui.world.ctl.chest_empty')
                      : strings.t(
                          'ui.world.ctl.chest_collect', {'n': b.chestTotal})
                ));
      }
      final (px, py) = _myTile;
      for (final b in town.builds) {
        final (sx, sy) = TownPlan.signOf(town, b);
        final tx = sx + ox, ty = sy + oy;
        if (!ActionTargeting.inReach(px, py, tx, ty)) continue;
        if (out.any((a) => a.target.tile == (tx, ty))) continue;
        final info = signAt(tx, ty);
        if (info == null) continue;
        add(ActionTarget(tx, ty, ActionTargetKind.sign, key: 'sign:${b.id}'),
            () => addLocalNotice('${info.$1}: ${info.$2}'),
            () => (WorldPrompt.poi, strings.t('ui.world.ctl.prompt_read')));
      }
      if (farmTile case final t?) {
        add(ActionTarget(t.$1, t.$2, ActionTargetKind.plot, key: 'plot'),
            farmWork, () {
          final tip = nearHelper == null
              ? ''
              : ' · ${strings.t(WorldPrompt.helper.key)}';
          if (farmHint() case final h?) return (WorldPrompt.farm, '$h$tip');
          if (nearHelper != null) return (WorldPrompt.helper, null);
          return (null, null);
        });
      }
    }
    // Farm animals, their eggs and the coop / barn house (animals.md
    // § 4.2): the tile cursor (they walk; the house is a sprite).
    if (!isRun && s.place == null) {
      for (final t in _animalCandidates()) {
        final r = _animalOf(t);
        if (r == null) continue;
        final b = r.build, a = r.animal;
        add(
            ActionTarget(t.x, t.y, ActionTargetKind.animal,
                ok: t.ok,
                id: t.id,
                key: 'animal:${b.id}:${a.uid}:${t.x},${t.y}',
                outline: false),
            () => careAnimal(b.id, a.uid),
            () => (
                  t.ok ? WorldPrompt.poi : WorldPrompt.spent,
                  animalPrompt(b, a)
                ));
      }
      if (nearRanchHouse case final b?) {
        final (ox, oy) = town.origin;
        final (px, py) = _myTile;
        final h = AnimalRules.houseOf(b);
        final tx = (px - ox).clamp(h.x, h.x + h.w - 1) + ox;
        final ty = (py - oy).clamp(h.y, h.y + h.h - 1) + oy;
        add(
            ActionTarget(tx, ty, ActionTargetKind.animal,
                key: 'ranch:${b.id}', outline: false),
            () => openAnimals(b.id),
            () => (
                  WorldPrompt.poi,
                  strings.t('ui.town.ranch.prompt_house',
                      {'name': strings.t('ui.town.ranch.${b.kind.name}.name')})
                ));
      }
    }
    // Mission entrances (zone arches).
    if (nearEntrance case final e?) {
      add(
          ActionTarget(e.tx, e.ty, ActionTargetKind.portal,
              key: 'zone:${e.zone}'),
          () => enterZone(e), () {
        final z = zoneStatus(e.zone);
        if (z == null) return (null, null);
        return (WorldPrompt.entrance, entrancePromptText(z, s.vote, localId));
      });
    }
    return out;
  }

  /// The tile of the town place [spot] nearest to the local player.
  (int, int) _spotTile(TownSpot spot) {
    final s = _s!;
    final map = engine.mapFor(s);
    final (px, py) = _myTile;
    final (ox, oy) = map.townOrigin;
    (int, int)? best;
    var bd = 1 << 30;
    void consider(int x, int y) {
      final d = (x - px) * (x - px) + (y - py) * (y - py);
      if (d < bd) (bd, best) = (d, (x, y));
    }

    if (map.place == null) {
      for (final l in map.townMarks ?? TownLayout.landmarks) {
        if (l.spot != spot) continue;
        consider(px.clamp(l.x + ox, l.x + ox + l.w - 1),
            py.clamp(l.y + oy, l.y + oy + l.h - 1));
      }
    }
    if (best == null) {
      final want = switch (spot) {
        TownSpot.sign => Tile.sign,
        TownSpot.travel => Tile.path,
        _ => null,
      };
      if (want != null) {
        for (var y = py - 2; y <= py + 2; y++) {
          for (var x = px - 2; x <= px + 2; x++) {
            if (map.contains(x, y) && map.tileAt(x, y) == want) consider(x, y);
          }
        }
      }
    }
    return best ?? (px + _facingStep.$1, py + _facingStep.$2);
  }

  /// The biome NPC (or the town residents) in talking reach.
  List<(ActionTarget, BiomeNpcDef)> _npcTargets() {
    final s = _s;
    if (s == null || s.mode != SessionMode.lobby) return const [];
    final lay = biomeLayout(s.place);
    if (lay == null) {
      // In town: the residents walking in front of their houses (§ 10.1).
      if (s.place != null || editingTown) return const [];
      final night = SkyRules.isNight(s.town.sky);
      final out = <(ActionTarget, BiomeNpcDef)>[];
      for (final n in ResidentRules.living(s.town)) {
        final pos = ResidentRules.position(s.town, n.id, s.time, night: night);
        if (pos == null) continue;
        if (WorldRules.distance(local.x, local.y, pos.$1, pos.$2) >= 26) {
          continue;
        }
        out.add((
          ActionTarget((pos.$1 / 16).floor(), (pos.$2 / 16).floor(),
              ActionTargetKind.npc,
              key: 'npc:${n.id}'),
          n
        ));
      }
      return out;
    }
    // Already lives in town: no longer in its biome (§ 10.1).
    if (s.town.resident(lay.npc.id).invited) return const [];
    // Walking around its camp (§ 9.2).
    final at = NpcCampRules.state(lay.npc, s.time);
    if (WorldRules.distance(local.x, local.y, at.x, at.y) >= 26) {
      return const [];
    }
    return [
      (
        ActionTarget((at.x / 16).floor(), (at.y / 16).floor(),
            ActionTargetKind.npc,
            key: 'npc:${lay.npc.id}'),
        lay.npc
      )
    ];
  }

  /// Rocks and finds next to the player in a mine (`mineTarget`'s
  /// candidates), typed for the cursor.
  List<ActionTarget> _mineCandidates() {
    final lvl = mineLevel;
    if (lvl == null) return const [];
    final (px, py) = _myTile;
    final r = CozyRules.actionReach;
    final out = <ActionTarget>[];
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        if (dx == 0 && dy == 0) continue;
        final c = MiningRules.tileAt(lvl, mineState, px + dx, py + dy);
        if (c == Tile.floor || c == MineTile.torch) continue;
        final kind = switch (c) {
          MineTile.chest ||
          MineTile.relic ||
          MineTile.mushroom ||
          MineTile.lore ||
          MineTile.station =>
            ActionTargetKind.find,
          _ => ActionTargetKind.rock,
        };
        out.add(ActionTarget(px + dx, py + dy, kind));
      }
    }
    return out;
  }

  _Act? get _selectedAct {
    final s = _s;
    if (s == null) return null;
    final key = (
      identityHashCode(s),
      local.x,
      local.y,
      local.fx,
      local.fy,
      _hover,
      _panel,
      editingTown,
      holding,
    );
    if (key == _actKey) return _actPick;
    final list = _actables();
    final (px, py) = _myTile;
    final t = ActionTargeting.select(
      px: px,
      py: py,
      candidates: [for (final a in list) a.target],
      hover: _hover,
      facing: _facingStep,
      reach: _actReach,
    );
    _actKey = key;
    _actPick = t == null ? null : list.firstWhere((a) => a.target == t);
    return _actPick;
  }

  /// What E / the click acts on now (controls.md § Cursor de acción), or
  /// `null`: the prompt and the map's cursor / outline read this.
  ActionTarget? get actionTarget => _selectedAct?.target;

  /// The selection's key without [prefix] when it is of that family
  /// (`npc:`, `event:`, `custom:`, `fisher:`, `minenpc:`, `chest:`,
  /// `spot:`), else `null`.
  String? selectedOf(String prefix) {
    final k = actionTarget?.key;
    return k != null && k.startsWith(prefix)
        ? k.substring(prefix.length)
        : null;
  }

  /// The tiles the selection is painted on (a town place's whole
  /// rectangle, an Eco portal's three tiles), for its outline.
  List<(int, int)> get actionTiles {
    final t = actionTarget;
    final s = _s;
    if (t == null || s == null) return const [];
    if (selectedOf('spot:') case final name?) {
      final map = engine.mapFor(s);
      final (ox, oy) = map.townOrigin;
      final (px, py) = _myTile;
      List<(int, int)>? best;
      var bd = 1 << 30;
      for (final l in map.townMarks ?? TownLayout.landmarks) {
        if (l.spot.name != name || map.place != null) continue;
        final cx = px.clamp(l.x + ox, l.x + ox + l.w - 1);
        final cy = py.clamp(l.y + oy, l.y + oy + l.h - 1);
        final d = (cx - px) * (cx - px) + (cy - py) * (cy - py);
        if (d >= bd) continue;
        bd = d;
        best = [
          for (var y = l.y + oy; y < l.y + oy + l.h; y++)
            for (var x = l.x + ox; x < l.x + ox + l.w; x++) (x, y)
        ];
      }
      if (best != null) return best;
    }
    if (t.key.startsWith('eco:')) {
      return [for (var dx = -1; dx <= 1; dx++) (t.x + dx, t.y)];
    }
    return [t.tile];
  }

  /// The live tile code at ([x], [y]) where it differs from the map's
  /// (a mine's dug / opened state), else `null`.
  String? liveTileCode(int x, int y) {
    final lvl = mineLevel;
    return lvl == null ? null : MiningRules.tileAt(lvl, mineState, x, y);
  }

  /// No selection, or a tool target: the farm and mine markers show only
  /// then (one marker on the map at a time).
  bool get toolCursor => switch (actionTarget?.kind) {
        null || ActionTargetKind.plot || ActionTargetKind.rock => true,
        _ => false,
      };

  /// Click on tile [tile] in reach: acts on the selection when the
  /// cursor sits there (same as E). Returns whether it was used.
  bool clickAction((int, int) tile) {
    final s = _s;
    if (s == null || _panel != null || s.mode != SessionMode.lobby) {
      return false;
    }
    aimHover(tile);
    final a = _selectedAct;
    if (a == null || a.target.tile != tile) return false;
    if (_toolKinds.contains(a.target.kind)) return false;
    _holdInteracted = true;
    a.run();
    return true;
  }

  /// E / Espacio.
  void interact() {
    final s = _s;
    if (s == null || _panel != null) return;
    if (s.mode == SessionMode.lobby) {
      // On a raft (fishing.md § 15): by a shore E gets off; out on the
      // water it fishes.
      if (onRaft) {
        if (canLeaveRaft) {
          leaveRaft();
        } else if (canFish) {
          startFishing();
        }
        return;
      }
      // Whatever the cursor selected (controls.md § Cursor de acción): no
      // fixed priority between kinds. Talking, opening and travelling
      // never repeat while E is held.
      if (_selectedAct case final a?) {
        _holdInteracted = !_toolKinds.contains(a.target.kind);
        a.run();
      } else if (inMine) {
        mineUse();
      } else if (facingWater || canFish) {
        startFishing();
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
    // EDITAR CASA (player_house.md § 8.3): Esc goes back one step.
    if (editingHome) {
      if (key == LogicalKeyboardKey.escape) homeEditBack();
      return key == LogicalKeyboardKey.escape;
    }
    // Edición del pueblo: Esc vuelve un paso o sale; el resto no juega.
    if (editingTown) {
      if (key == LogicalKeyboardKey.escape) {
        // Esc cierra primero la ventana CONSTRUIR (town_editor.md § 1.2).
        if (_edit?.buildShown ?? false) {
          setBuildOpen(false);
        } else {
          editBack();
        }
      }
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
        stopFishing(why: AutoFishStop.key);
        return true;
      }
      // R with the rod out at the water: auto-fishing (fishing.md § 6).
      // Takes precedence over R near the farm (other hand), which only
      // applies with the rod away.
      if (key == LogicalKeyboardKey.keyR) {
        toggleAutoFish();
        return true;
      }
    }
    // R at the shore (rod away): take the rod out and auto-fish right
    // away, as the prompt says (fishing.md § 6).
    if (key == LogicalKeyboardKey.keyR &&
        _panel == null &&
        !inMine &&
        !onRaft &&
        canFish) {
      if (startFishing()) toggleAutoFish();
      return true;
    }
    // Mines (mining_smithing.md § 1.6): G hires a miner at the station
    // (Shift+G dismisses one); R / Shift+R cycles the held tool.
    if (_panel == null && inMine) {
      if (key == LogicalKeyboardKey.keyG && nearMineStation) {
        HardwareKeyboard.instance.isShiftPressed ? fireMiner() : hireMiner();
        return true;
      }
      // G next to a miner: its panel, like any helper (§ 1.7).
      if (key == LogicalKeyboardKey.keyG) {
        if (nearMiner case final k? when mineState.station) {
          openMiners(focus: k);
          return true;
        }
      }
      // U: quick upgrade of the weakest pick (same op as the panel).
      if (key == LogicalKeyboardKey.keyU && nearMineStation) {
        upgradeMiner();
        return true;
      }
      if (key == LogicalKeyboardKey.keyR) {
        cycleMineHand(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
        return true;
      }
      for (final (k, h) in [
        (LogicalKeyboardKey.digit1, MineHand.pick),
        (LogicalKeyboardKey.digit2, MineHand.torch),
        (LogicalKeyboardKey.digit3, MineHand.bomb),
        (LogicalKeyboardKey.digit4, MineHand.oil),
      ]) {
        if (key == k) {
          selectMineHand(h);
          return true;
        }
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
    // F with the rod out: next bait (fishing.md § 14.5).
    if (_panel == null &&
        farmTile == null &&
        activeTool == ActiveTool.rod &&
        key == LogicalKeyboardKey.keyF) {
      return cycleBait();
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
    if (key == LogicalKeyboardKey.keyL && wispBlock() == null) {
      toggleWisp();
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
    // First visit clears the fountain's onboarding "!" (town_editor.md § 1.5).
    if (panel == WorldPanel.fountain && fountainAlert) {
      markNpcSeen(QuestTrackRules.fountainKey);
    }
    _emit();
  }

  /// `closePanel`: no cierra si hay que repartir puntos; en preparación
  /// vuelve al panel de preparación.
  void closePanel() {
    final s = _s;
    if (s == null || _panel == null || s.mustAllocate(localId)) return;
    stallOwner = null;
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

  /// Why UNIRSE on [a]'s card is off, or `null` when it works
  /// (free_movement.md § 2.5).
  String? joinPlayerBlock(AwayPlayer a) {
    if (canJoinPlayer(a)) return null;
    return a.busy
        ? strings.t('ui.world.hud.join_busy', {'name': a.name})
        : strings.t('ui.world.hud.join_off');
  }

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
    final cur = view?.turnActor;
    return _applyFor(
        _companions.containsKey(cur) ? cur! : localId, BattleAction(command));
  }

  /// Withdraws [actorId]'s queued command (turn_modes.md § 3.1).
  bool cancelQueued(String actorId) =>
      _applyFor(actorId, const CancelQueuedBattleAction());

  /// Moves [playerId]'s queued command to position [to] (§ 3.1).
  bool moveQueued(String playerId, int to) =>
      _apply(MoveQueuedBattleAction(playerId, to));

  /// The local player agrees the queue order (§ 3.1).
  bool confirmQueue() => _apply(const ConfirmBattleQueueAction());

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
  /// La Llama errante del jugador local está encendida.
  bool get wispOn => _s?.players[localId]?.wisp ?? false;

  /// Clave i18n del motivo por el que [toggleWisp] no aplica (o `null`): en batalla, o
  /// al aire libre, donde la Llama va sola de noche (lighting.md § 3.1.1).
  String? wispBlock() {
    final s = _s;
    if (s == null || s.mode == SessionMode.battle) {
      return 'ui.world.hud.flame.why_battle';
    }
    if (_wispOutdoor()) {
      return 'ui.world.hud.flame.why_outdoor';
    }
    return null;
  }

  /// Enciende o apaga la Llama errante (tecla L o el atajo del HUD).
  void toggleWisp() {
    if (wispBlock() != null) return;
    _apply(WispAction(!wispOn));
  }

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

  /// Smelt or forge (mining_smithing.md § 3–5).
  bool smith(SmithAction a) => _applyFor(actingId, a);

  /// Dar [count] de [token] (`uid`, `pot`, `eter`, `mat:<material>`) a
  /// otro jugador de la sala.
  bool give(String toPlayerId, String token, {int count = 1}) =>
      _applyFor(actingId, GiveItemAction(toPlayerId, token, count: count));

  /// Give [count] of the profession cell [cell] to [toPlayerId]
  /// (share_materials.md).
  bool giveLife(String toPlayerId, String cell, int count) =>
      _apply(GiveLifeAction(toPlayerId, cell, count: count));

  /// Player stall (player_shop.md): list [qty] of [cell] at [price]
  /// (qty 0 = only the price), take it back, or buy from [owner].
  bool stallList(String cell, int qty, int price) =>
      _apply(StallAction(StallOp.list, cell, qty: qty, price: price));
  bool stallUnlist(String cell) => _apply(StallAction(StallOp.unlist, cell));
  bool stallBuy(String owner, String cell, int qty) =>
      _apply(StallAction(StallOp.buy, cell, qty: qty, owner: owner));

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

  /// Fusionar Ecos del mismo tier en uno de tier + 1 (ecos_atlas.md § 4.2).
  bool ecoFuse(List<String> uids) =>
      _applyFor(actingId, EcoFuseAction(List.unmodifiable(uids)));

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
    if (it != null) return localItemName(engine.progression.items, it);
    if (d.eco != null) return 'Eco';
    if (d.isGoods) return localGoodsName(d);
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

  /// World events (world_events.md § 6): every peer adds the notice of a
  /// new event in its own language. Nothing on the first state (joining).
  void _announceWorldEvents(WorldEventsState? before, WorldEventsState now) {
    if (before == null) return;
    final old = {for (final a in before.active) a.uid};
    for (final a in now.active) {
      if (old.contains(a.uid)) continue;
      final d = kWorldEvents.def(a.def);
      // Deep actors of the wilds are found by exploring, not announced
      // (biome_exploration.md § 6).
      if (d != null && WorldEventRules.isDeep(d)) continue;
      final text = d?.notice.text;
      if (text == null || text.isEmpty) continue;
      _messages.add(text);
      if (_messages.length > maxMessages) _messages.removeAt(0);
      _addChat(ChatLine.system(text));
    }
  }

  void _step(SessionStep step) {
    // Deed tokens for every shown text (renown_town_growth.md § 3).
    LocalizedText.tokens = RenownRules.tokens(step.state.town,
        worldName: step.state.worldName);
    _announceWorldEvents(_s?.town.events, step.state.town.events);
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
          _messages.add(strings.t('ui.world.ctl.caught', {'what': label}));
          if (_messages.length > maxMessages) _messages.removeAt(0);
        case LightningEvent():
          fishSfx?.call(Sfx.impactBolt);
        case SleptEvent(:final toMorning):
          addLocalNotice(strings.t(toMorning
              ? 'ui.world.home.slept_morning'
              : 'ui.world.home.slept_night'));
        case FishAutoStoppedEvent(:final playerId, :final reason, :final caught)
            when playerId == localId:
          _autoFish = false;
          _messages.add(autoFishStopText(reason, caught));
          if (_messages.length > maxMessages) _messages.removeAt(0);
        case FishCaughtEvent(
              :final playerId,
              :final species,
              :final sizeCm,
              :final auto
            )
            when playerId == localId:
          if (auto) _autoCaught++;
          final name = kFish[species]?.name ?? species;
          _messages.add(strings.t('ui.world.ctl.caught_cm', {'what': name, 'cm': sizeCm}));
          if (_messages.length > maxMessages) _messages.removeAt(0);
        case BattleFinishedEvent(victory: true):
          _onBattleWon();
        // Hazañas (achievements.md § 5.1): la recompensa ya está en el
        // perfil de sesión; se guarda enseguida en la cuenta.
        case AchievementUnlockedEvent(:final playerId, :final id)
            when controls(playerId):
          achievementLog.add(e);
          final name = kAchievementsById[id]?.name ?? id;
          _addChat(ChatLine.system(strings.t('ui.world.ctl.achievement', {'name': name})));
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
    _watchTown();
    _emit();
  }

  /// Espera tras un cambio del pueblo antes de escribirlo (junta varias
  /// ediciones seguidas en una sola escritura).
  static const townSaveDelay = Duration(seconds: 2);

  /// Mínimo que queda a la vista el aviso de guardado (para leerlo).
  static const savingMinVisible = Duration(milliseconds: 1500);

  Object? _townSeen;
  bool _townWasEdited = false;
  Timer? _townSaveTimer;

  /// Host/solo: el pueblo cambió (edición propia o de un cliente aplicada
  /// acá) → se guarda al terminar la edición, o a los [townSaveDelay] si
  /// sigue editando (docs/specs/save_indicator.md § 1).
  void _watchTown() {
    final s = _s;
    if (s == null || isClient || isRun || world == null || onWorldTown == null) {
      return;
    }
    final t = s.town, editing = s.townEditor != null;
    final first = _townSeen == null;
    final changed = !first && !identical(_townSeen, t);
    final ended = _townWasEdited && !editing;
    _townSeen = t;
    _townWasEdited = editing;
    // El pueblo cambia solo todo el tiempo (cielo, ayudantes, cultivos):
    // fuera de la edición se guarda una vez por día de juego, no en cada
    // cambio (save_indicator.md § 1).
    final day = t.sky.day;
    final newDay = _townDay != null && day != _townDay && day > 1;
    _townDay = day;
    if (first) return;
    if (ended || newDay) {
      _flushTownSave(emit: false);
    } else if (changed && editing) {
      if (!_disposing) _townSaveTimer ??= Timer(townSaveDelay, _flushTownSave);
    }
  }

  int? _townDay;

  void _flushTownSave({bool emit = true}) {
    _townSaveTimer?.cancel();
    _townSaveTimer = null;
    _saveWorld();
    if (emit) _emit();
  }

  int _savesInFlight = 0;
  bool _disposing = false;
  DateTime? _savingSince;

  /// Hay una escritura a disco en curso (o empezó hace menos de
  /// [savingMinVisible]). Sin timers: la vista se recalcula en cada paso
  /// del juego, así que el aviso se apaga solo en el siguiente.
  bool get saving {
    final since = _savingSince;
    if (since == null) return false;
    if (_savesInFlight > 0) return true;
    if (DateTime.now().difference(since) < savingMinVisible) return true;
    _savingSince = null;
    return false;
  }

  void _beginSave() {
    _savesInFlight++;
    _savingSince ??= DateTime.now();
  }

  void _endSave() {
    if (_savesInFlight > 0) _savesInFlight--;
  }

  /// Marca [f] como guardado en curso para el aviso del HUD.
  Future<T> _tracked<T>(Future<T> f) {
    if (!_announceSaves) return f;
    _beginSave();
    return f.whenComplete(_endSave);
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
    _beginSave();
    cb(
        w.id,
        town.copyWith(
            upgrades: w.town.upgrades,
            lostLoot: [for (final g in s.lostLoot) codec.groundToJson(g)],
            cycle: _worldCycle));
    _endSave();
  }

  /// Se juega la Travesía (la UI arma sus pantallas en vez del pueblo).
  bool get isRun => engine.gameMode == GameModeKind.travesia;

  /// Política de guardado (save_indicator.md § 1): una vez por día de
  /// juego, al cerrar un menú ([_saveSoon] desde [_emit]; dentro del
  /// menú no se guarda nada) y forzado al terminar misión / salir. Si un
  /// guardado falló se reintenta cada [saveEvery] s.
  void _save({bool force = false}) {
    if (!_persist) return;
    final day = _s?.town.sky.day;
    // Día 0 = cielo sin arrancar: pasar a 1 no es un día nuevo.
    final newDay = day != null && (_savedDay ?? 0) > 0 && day != _savedDay;
    if (day != null) _savedDay = day;
    final soon = _saveSoonAt != null &&
        DateTime.now().difference(_saveSoonAt!) < saveSoonWindow;
    if (!soon) _saveSoonAt = null;
    final retry = _saveError != null && _sinceSave >= saveEvery;
    if (!force && !newDay && !soon && !retry) return;
    _sinceSave = 0;
    _announceSaves = true;
    for (final id in _companions.keys) {
      _saveCompanion(id);
    }
    _saveLocal();
    _announceSaves = false;
  }

  int? _savedDay;
  DateTime? _saveSoonAt;

  /// Tras cerrar un menú se guarda lo que cambie en
  /// este lapso (al cliente el perfil nuevo le llega con un snapshot).
  static const saveSoonWindow = Duration(seconds: 2);

  void _saveSoon() => _saveSoonAt = DateTime.now();

  /// Los guardados de perfil en curso se muestran en el HUD.
  bool _announceSaves = false;

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
    unawaited(_tracked(ps.save(slot, p)).then((_) => _companionSaveOk(id, p),
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
    unawaited(_tracked(store.save(p)).then((_) => _saveOk(p), onError: (Object e) {
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
    _saveError = strings.t('ui.world.ctl.save_failed');
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
            _panel == WorldPanel.stall ||
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
    // Menú cerrado (o cambiado): se guarda lo hecho con él abierto.
    if (_shownPanel != null && _panel != _shownPanel) _saveSoon();
    _shownPanel = _panel;

    // A failing prompt must never stop the view (v0.49.22): before, the
    // exception skipped `state = ...`, so the HUD kept the last prompt
    // on screen until a later emit happened to succeed.
    WorldPrompt? prompt;
    String? promptText;
    try {
      (prompt, promptText) = _prompt();
    } catch (e, st) {
      if (_promptErrors++ < 3) EcosLog.error('Aviso del mapa', '$e\n$st');
    }
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
      saving: saving,
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

  /// Prompt failures logged so far (only the first few go to the log).
  int _promptErrors = 0;

  (WorldPrompt?, String?) _prompt() {
    if (_panel != null || editingTown) return (null, null);
    // Same order as `interact` (fishing.md § 15).
    if (onRaft && _s?.mode == SessionMode.lobby) {
      if (canLeaveRaft) {
        return (WorldPrompt.poi, strings.t('ui.world.raft.prompt_leave'));
      }
      if (mapFishing case final f?) {
        return (WorldPrompt.fishing, fishingHint(f));
      }
      return (WorldPrompt.fishing, strings.t('ui.world.raft.prompt_fish'));
    }
    // The action cursor's selection (controls.md § Cursor de acción):
    // the line always describes what E / the click does there.
    if (_selectedAct case final a?) {
      if (a.prompt case final p?) {
        final r = p();
        if (r.$1 != null || r.$2 != null) return r;
      }
    }
    if (farmHint() case final h?) return (WorldPrompt.farm, h);
    if (nearHelper != null) return (WorldPrompt.helper, null);
    if (mapFishing case final f?) return (WorldPrompt.fishing, fishingHint(f));
    if (facingWater) return (WorldPrompt.fishing, null);
    if (canFish) return (WorldPrompt.fishing, null);
    if (nearSeal != null) return (WorldPrompt.seal, null);
    if (nearOffering) return (WorldPrompt.poi, strings.t('ui.world.ctl.prompt_offering'));
    if (nearPoi case final p? when p.kind == PoiKind.ore) {
      return (WorldPrompt.poi, strings.t('ui.world.mine.prompt_mine'));
    }
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
    if (nearMerchant) return (WorldPrompt.merchant, null);
    return (null, null);
  }
}

/// One interactable for the action cursor: where it is, what E / the
/// click does and what the prompt says (`null` = the default line).
class _Act {
  const _Act(this.target, this.run, this.prompt);
  final ActionTarget target;
  final void Function() run;
  final (WorldPrompt?, String?) Function()? prompt;
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
enum ActiveTool { rod, hoe, mine }

/// What the local player holds in a mine (mining_smithing.md § 1.6): the
/// best pick (or drill), torches, bombs and the vein oil.
enum MineHand { pick, torch, bomb, oil }

/// Herramienta de huerta en la mano (farming.md § 2.5).
enum FarmHand { hoe, seed, can, fert }
