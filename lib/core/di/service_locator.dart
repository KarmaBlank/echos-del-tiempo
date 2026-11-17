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
import '../../netcode/contracts/net_session.dart';
import '../../netcode/p2p_webrtc/firestore_signaling_service.dart';
import '../../netcode/p2p_webrtc/webrtc_net_session.dart';
import '../audio/audioplayers_sfx_player.dart';
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
}

/// Variante P2P (la de HOY): WebRTC + señalización por Firestore.
void registerP2PNetcode() {
  sl.registerLazySingleton<FirestoreSignalingService>(
    () => FirestoreSignalingService(),
  );
  sl.registerLazySingleton<NetSession>(
    () => WebRTCNetSession(signaling: sl<FirestoreSignalingService>()),
  );
}

// void registerDedicatedServerNetcode() { ... } // futuro
// void registerRollbackNetcode() { ... }        // futuro
