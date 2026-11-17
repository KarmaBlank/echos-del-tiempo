import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../app.dart';

/// Composition root de la versión P2P (la que jugás hoy con amigos,
/// sin servidor propio). `flutter run -t lib/app/flavors/main_p2p.dart`
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerSharedDependencies();
  registerP2PNetcode();
  runApp(const EcosApp());
}
