import 'package:flutter/widgets.dart';

import '../../core/di/service_locator.dart';
import '../../core/settings/frame_limiter.dart';
import '../app.dart';
import 'firebase_bootstrap.dart';

/// Composition root de la versión P2P por internet (WebRTC + señalización
/// Firestore). Sin Firebase configurado arranca igual y el título avisa
/// que falta configurarlo (docs/specs/netcode.md).
/// `flutter run -d windows -t lib/app/flavors/main_p2p.dart`
Future<void> main() async {
  // Binding con límite de FPS (docs/specs/settings.md § 3.4).
  EcosBinding.ensureInitialized();
  registerSharedDependencies();
  registerP2PNetcode(signaling: await resolveP2PSignaling());
  runApp(const EcosApp());
}
