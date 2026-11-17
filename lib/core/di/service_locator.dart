import 'package:get_it/get_it.dart';

import '../../game_engine/rules/passive_tree_rules.dart';
import '../../game_engine/rules/stats_calculator.dart';
import '../../netcode/contracts/net_session.dart';
import '../../netcode/p2p_webrtc/firestore_signaling_service.dart';
import '../../netcode/p2p_webrtc/webrtc_net_session.dart';

final sl = GetIt.instance;

/// Registra TODO lo que no depende del netcode (game_engine, features).
/// Cada `main_*.dart` llama primero a esto y después a su propio
/// `registerNetcode*()` — así el "composition root" queda explícito:
/// mirás el main y sabés exactamente qué build estás armando.
void registerSharedDependencies() {
  if (sl.isRegistered<PassiveTreeRules>()) return;

  // TODO(migración): reemplazar por el catálogo real portado del
  // prototipo (TREE completo) una vez migrados los datos de clases/armas.
  sl.registerLazySingleton<PassiveTreeRules>(
    () => throw UnimplementedError(
      'Registrar PassiveTreeRules con el catálogo real en el composition root',
    ),
  );
  sl.registerLazySingleton<StatsCalculator>(
    () => throw UnimplementedError(
      'Registrar StatsCalculator con las clases/armas reales en el composition root',
    ),
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
