import 'dart:async';

import 'package:get_it/get_it.dart';

import '../../app/feature_flags.dart';
import '../../features/characters/data/account_repository.dart';
import '../../features/characters/data/account_store.dart';
import '../../features/lobby/data/json_file_profile_store.dart';
import '../../game_engine/balance/balance_patch.dart';
import '../../game_engine/data/game_catalog.dart';
import '../../game_engine/data/passive_tree_catalog.dart';
import '../../game_engine/models/atlas_store.dart';
import '../../game_engine/models/game_mode.dart';
import '../../netcode/protocol/wire.dart' show WireGame;
import '../edition/game_edition.dart';
import '../../features/run/data/json_file_run_save_store.dart';
import '../../features/run/data/json_file_travesia_meta_store.dart';
import '../../game_engine/models/travesia_meta.dart';
import '../../game_engine/models/run_save.dart';
import '../../game_engine/models/bestiary.dart';
import '../../game_engine/models/tutorial_store.dart';
import '../../game_engine/models/party_store.dart';
import '../../game_engine/models/profile_store.dart';
import '../../game_engine/rules/battle_engine.dart';
import '../../game_engine/rules/passive_tree_rules.dart';
import '../../game_engine/rules/progression_rules.dart';
import '../../game_engine/rules/session_engine.dart';
import '../../game_engine/rules/stats_calculator.dart';
import '../../netcode/contracts/net_session_factory.dart';
import '../../netcode/lan/lan_net_session.dart';
import '../../netcode/p2p_webrtc/signaling_service.dart';
import '../../netcode/p2p_webrtc/webrtc_net_session.dart';
import '../audio/audio_settings.dart';
import '../balance/balance_asset_loader.dart';
import '../data/ult_data_loader.dart';
import '../audio/audioplayers_music_player.dart';
import '../audio/audioplayers_sfx_player.dart';
import '../audio/music/music_service.dart';
import '../audio/sfx_service.dart';
import '../persistence/ecos_log.dart';
import '../persistence/exit_guard.dart';
import '../settings/frame_limiter.dart';
import '../settings/game_settings.dart';
import '../settings/window_mode.dart';

final sl = GetIt.instance;

/// Registra TODO lo que no depende del netcode (game_engine, features).
/// Cada `main_*.dart` llama primero a esto y después a su propio
/// `registerNetcode*()` — así el "composition root" queda explícito:
/// mirás el main y sabés exactamente qué build estás armando.
///
/// [accountStore] reemplaza el `account.json` de la carpeta de datos
/// (tests); todas las variantes (solo, host, LAN, P2P) usan la misma
/// cuenta: no hay un store por modo (docs/specs/characters.md § 1.4).
///
/// [balance] es el `balance.json` ya leído (`BalanceAssetLoader.load`,
/// docs/specs/balance_admin.md § 3); `null` = el catálogo del código.
void registerSharedDependencies(
    {AccountStore? accountStore,
    BalanceParseResult? balance,
    UltData? ults,
    GameEdition edition = GameEdition.mundo}) {
  if (sl.isRegistered<PassiveTreeRules>()) return;
  // Qué juego es (docs/specs/distribution.md § "Dos juegos, un repo"):
  // versión, canal de releases, carpeta de datos y protocolo. Va antes del
  // log, que ya escribe en la carpeta del juego.
  GameEdition.install(edition);
  final gameMode = edition.mode;
  // Versión del juego (docs/specs/roguelike.md § 9): Mundo o Travesía.
  sl.registerSingleton<GameModeKind>(gameMode);
  // `ecos.log` junto a la cuenta (docs/specs/characters.md § 1.5).
  if (accountStore == null) {
    try {
      final dir = JsonFileProfileStore.dataDirectory();
      if (dir != null) {
        EcosLog.init(dir);
        EcosLog.info('Inicio del juego');
      }
    } on UnsupportedError {
      // web: sin registro en disco
    }
  }

  // Parche de balance encima del código (registros globales incluidos).
  // Datos de las ULT (YAML, ultimates_v2.md § 5.1) y, encima, el parche.
  final catalog = BalanceAssetLoader.install(balance,
      base: UltDataLoader.install(GameCatalog.standard, ults));
  sl.registerLazySingleton<GameCatalog>(() => catalog);
  sl.registerLazySingleton<PassiveTreeRules>(
    () => PassiveTreeRules(kPassiveTree),
  );
  sl.registerLazySingleton<StatsCalculator>(
    () => StatsCalculator(
      classes: sl<GameCatalog>().classes,
      treeRules: sl<PassiveTreeRules>(),
    ),
  );
  // Sin `random`: azar real. El host P2P es quien corre el motor.
  sl.registerFactory<BattleEngine>(
    () => BattleEngine(
      stats: sl<StatsCalculator>(),
      catalog: sl<GameCatalog>(),
    ),
  );
  sl.registerLazySingleton<ProgressionRules>(
    () => ProgressionRules(
      stats: sl<StatsCalculator>(),
      catalog: sl<GameCatalog>(),
      ignoreRequirements: gameMode == GameModeKind.travesia,
    ),
  );
  // Una sala nueva = un motor nuevo (cachea los mapas de sus misiones).
  sl.registerFactory<SessionEngine>(
    () => SessionEngine(
      battles: sl<BattleEngine>(),
      progression: sl<ProgressionRules>(),
      // Los drops caen al piso por jugador y se levantan caminando o con
      // E (docs/specs/loot.md, exploration.md § "Loot en el piso").
      groundLoot: true,
      // Atajos de desarrollo de los Ecos solo en `main_dev`
      // (docs/specs/ecos_atlas.md § 8).
      devTools: FeatureFlags.instance.devTools,
      maxPlayers: FeatureFlags.instance.maxPlayers,
      gameMode: gameMode,
    ),
  );
  // Cuenta con varios personajes y alijo (`account.json`, migra el
  // `profile.json` viejo); en memoria donde todavía no hay una carpeta
  // conocida. La sesión ve solo el personaje elegido
  // (docs/specs/characters.md § 1).
  sl.registerLazySingleton<AccountRepository>(() {
    final repo = AccountRepository(accountStore ??
        JsonFileAccountStore.forPlatform() ??
        InMemoryAccountStore());
    // Al salir, lo que quedó sin escribir va a disco (después de la
    // sesión, que le pasa el último perfil).
    ExitGuard.register(repo, repo.flush, last: true);
    return repo;
  });
  sl.registerLazySingleton<ProfileStore>(() {
    final store = SelectedCharacterProfileStore(sl<AccountRepository>());
    // Travesía: el personaje de la run nunca pisa al de la cuenta
    // (roguelike.md § 8.5); se lee el elegido y no se escribe nada.
    return gameMode == GameModeKind.travesia
        ? ReadOnlyProfileStore(store)
        : store;
  });
  // Travesía: la run en curso y el progreso entre runs, en su propia
  // carpeta (roguelike.md § 8). El Mundo no registra nada de esto.
  if (gameMode == GameModeKind.travesia) {
    sl.registerLazySingleton<RunSaveStore>(() =>
        JsonFileRunSaveStore.forPlatform() ?? InMemoryRunSaveStore());
    sl.registerLazySingleton<TravesiaMetaStore>(() =>
        JsonFileTravesiaMetaStore.forPlatform() ??
        InMemoryTravesiaMetaStore());
  }
  // Alijo en partida (docs/specs/characters.md § 3.2).
  sl.registerLazySingleton<StashStore>(
    () => AccountStashStore(sl<AccountRepository>()),
  );
  // Party jugando solo: las otras ranuras de la misma cuenta
  // (docs/specs/solo_party.md § 5).
  sl.registerLazySingleton<PartyStore>(
    () => AccountPartyStore(sl<AccountRepository>()),
  );
  // Atlas del Tiempo: uno por cuenta (docs/specs/ecos_atlas.md § 5).
  sl.registerLazySingleton<AtlasStore>(
    () => AccountAtlasStore(sl<AccountRepository>()),
  );
  // Bestiario: uno por cuenta (docs/specs/bestiary.md § 2).
  sl.registerLazySingleton<BestiaryStore>(
    () => AccountBestiaryStore(sl<AccountRepository>()),
  );
  // TUTORIAL: bandera `tutV` por cuenta (docs/specs/combat_tutorial.md § 2).
  sl.registerLazySingleton<TutorialStore>(
    () => AccountTutorialStore(sl<AccountRepository>()),
  );
  // Sonido real con audioplayers (docs/specs/audio.md § "Reproducción").
  // Los tests no pasan por acá: usan su propio reproductor o el no-op.
  sl.registerLazySingleton<SfxPlayer>(() => AudioplayersSfxPlayer());
  sl.registerLazySingleton<SfxService>(
    () => SfxService(player: sl<SfxPlayer>()),
  );
  // Música (docs/specs/music.md § 6): render en isolate y caché en disco.
  sl.registerLazySingleton<MusicPlayer>(() => AudioplayersMusicPlayer());
  sl.registerLazySingleton<MusicService>(
    () => MusicService(player: sl<MusicPlayer>(), render: renderSongInIsolate),
  );
  // Ajustes de audio: `audio.json` junto al perfil; en memoria donde no
  // hay carpeta de datos conocida.
  sl.registerLazySingleton<AudioSettingsController>(() {
    String? dir;
    try {
      dir = JsonFileProfileStore.dataDirectory();
    } on UnsupportedError {
      dir = null; // web
    }
    final c = AudioSettingsController(
      store: dir == null
          ? InMemoryAudioSettingsStore()
          : JsonFileAudioSettingsStore.inDirectory(dir),
      music: sl<MusicService>(),
      sfx: sl<SfxService>(),
    );
    unawaited(c.load());
    return c;
  });
  // Ajustes de pantalla y de juego: `game.json` en la misma carpeta
  // (docs/specs/settings.md). Pantalla completa por el runner de Windows.
  sl.registerLazySingleton<WindowMode>(WindowMode.forPlatform);
  sl.registerLazySingleton<GameSettingsController>(() {
    String? dir;
    try {
      dir = JsonFileProfileStore.dataDirectory();
    } on UnsupportedError {
      dir = null; // web
    }
    final c = GameSettingsController(
      store: dir == null
          ? InMemoryGameSettingsStore()
          : JsonFileGameSettingsStore.inDirectory(dir),
      window: sl<WindowMode>(),
      frameLimiter: FrameLimiter.shared,
    );
    unawaited(c.load());
    return c;
  });
}

/// Variante P2P por internet: WebRTC + señalización por Firestore.
/// [signaling] lo decide el composition root según la plataforma (REST en
/// escritorio, SDK en web/móvil: `resolveP2PSignaling`); `null` = Firebase
/// sin configurar y el título muestra [p2pUnavailable]. Ver
/// docs/specs/netcode.md § "P2P por internet".
/// [game]: juego y protocolo de la sala; por defecto el de
/// `GameEdition.current` (lo instaló `registerSharedDependencies`).
void registerP2PNetcode(
    {required SignalingService Function()? signaling, WireGame? game}) {
  final wire = game ?? GameEdition.current.wire;
  if (signaling == null) {
    sl.registerSingleton<NetSessionFactory>(
        NetSessionFactory.unavailable('P2P', p2pUnavailable));
    return;
  }
  sl.registerLazySingleton<SignalingService>(signaling);
  sl.registerSingleton<NetSessionFactory>(NetSessionFactory(
    label: 'P2P',
    codeHint: 'CODIGO',
    create: () => WebRTCNetSession(
      signaling: sl<SignalingService>(),
      catalog: sl<GameCatalog>(),
      maxPlayers: FeatureFlags.instance.maxPlayers,
      game: wire,
    ),
  ));
}

const p2pUnavailable = 'P2P por internet: falta configurar Firebase';

/// Variante LAN: WebSocket en la red local, código `IP:PUERTO`, sin
/// Firebase. Ver docs/specs/netcode.md § "LAN".
void registerLanNetcode({WireGame? game}) {
  final wire = game ?? GameEdition.current.wire;
  sl.registerSingleton<NetSessionFactory>(NetSessionFactory(
    label: 'LAN',
    codeHint: 'IP:PUERTO',
    create: () => LanNetSession(
        catalog: sl<GameCatalog>(),
        maxPlayers: FeatureFlags.instance.maxPlayers,
        game: wire),
  ));
}

// void registerDedicatedServerNetcode() { ... } // futuro
// void registerRollbackNetcode() { ... }        // futuro
