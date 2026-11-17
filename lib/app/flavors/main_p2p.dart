import 'package:flutter/widgets.dart';

import '../../core/di/service_locator.dart';
import '../app.dart';
import 'firebase_bootstrap.dart';

/// Composition root de la versión P2P por internet (WebRTC + señalización
/// Firestore). Sin Firebase configurado arranca igual y el título avisa
/// que falta configurarlo (docs/specs/netcode.md).
/// `flutter run -d windows -t lib/app/flavors/main_p2p.dart`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerSharedDependencies();
  registerP2PNetcode(signaling: await resolveP2PSignaling());
  runApp(const EcosApp());
}
