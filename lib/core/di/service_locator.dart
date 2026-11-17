import 'dart:async';

import 'package:get_it/get_it.dart';

import '../../features/lobby/data/json_file_profile_store.dart';
import '../../game_engine/data/game_catalog.dart';
import '../../game_engine/data/passive_tree_catalog.dart';
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
import '../audio/audioplayers_music_player.dart';
import '../audio/audioplayers_sfx_player.dart';
import '../audio/music/music_service.dart';
import '../audio/sfx_service.dart';

final sl = GetIt.instance;

/// Registra TODO lo que no depende del netcode (game_engine, features).
/// Cada `main_*.dart` llama primero a esto y después a su propio
/// `registerNetcode*()` — así el "composition root" queda explícito:
/// mirás el main y sabés exactamente qué build estás armando.
void registerSharedDependencies() {
  if (sl.isRegistered<PassiveTreeRules>()) return;

  sl.registerLazySingleton<GameCatalog>(() => GameCatalog.standard);
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
    ),
  );
  // Perfil en disco en escritorio; en memoria donde todavía no hay una
  // carpeta conocida (docs/specs/exploration.md § "Persistencia").
  sl.registerLazySingleton<ProfileStore>(
    () => JsonFileProfileStore.forPlatform() ?? InMemoryProfileStore(),
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
}

/// Variante P2P por internet: WebRTC + señalización por Firestore.
/// [signaling] lo decide el composition root según la plataforma (REST en
/// escritorio, SDK en web/móvil: `resolveP2PSignaling`); `null` = Firebase
/// sin configurar y el título muestra [p2pUnavailable]. Ver
/// docs/specs/netcode.md § "P2P por internet".
void registerP2PNetcode({required SignalingService Function()? signaling}) {
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
    ),
  ));
}

const p2pUnavailable = 'P2P por internet: falta configurar Firebase';

/// Variante LAN: WebSocket en la red local, código `IP:PUERTO`, sin
/// Firebase. Ver docs/specs/netcode.md § "LAN".
void registerLanNetcode() {
  sl.registerSingleton<NetSessionFactory>(NetSessionFactory(
    label: 'LAN',
    codeHint: 'IP:PUERTO',
    create: () => LanNetSession(catalog: sl<GameCatalog>()),
  ));
}

// void registerDedicatedServerNetcode() { ... } // futuro
// void registerRollbackNetcode() { ... }        // futuro
