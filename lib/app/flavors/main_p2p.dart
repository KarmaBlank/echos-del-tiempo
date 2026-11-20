import 'package:flutter/widgets.dart';

import '../../core/balance/balance_asset_loader.dart';
import '../../core/di/service_locator.dart';
import '../../core/persistence/exit_on_close.dart';
import '../../core/settings/frame_limiter.dart';
import '../../features/combat/presentation/scene/fx_bridge.dart';
import '../app.dart';
import 'firebase_bootstrap.dart';

/// Composition root de la versión P2P por internet (WebRTC + señalización
/// Firestore). Sin Firebase configurado arranca igual y el título avisa
/// que falta configurarlo (docs/specs/netcode.md).
/// `flutter run -d windows -t lib/app/flavors/main_p2p.dart`
Future<void> main() async {
  // Binding con límite de FPS (docs/specs/settings.md § 3.4).
  EcosBinding.ensureInitialized();
  // Parche de balance (docs/specs/balance_admin.md § 3).
  // Animaciones como datos (docs/specs/game_editor.md § 2.2).
  await installFx();
  registerSharedDependencies(balance: await BalanceAssetLoader.load());
  // Cerrar la ventana guarda antes (docs/specs/characters.md § 1.4).
  installExitOnClose();
  // Sin party jugando solo (FeatureFlags.soloParty queda en false;
  // docs/specs/solo_party.md § 0).
  registerP2PNetcode(signaling: await resolveP2PSignaling());
  runApp(const EcosApp());
}
