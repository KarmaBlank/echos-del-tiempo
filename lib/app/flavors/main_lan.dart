import 'package:flutter/widgets.dart';

import '../../core/di/service_locator.dart';
import '../app.dart';

/// Composition root de la versión LAN: misma red local (o dos ventanas en
/// la misma PC), WebSocket directo, sin Firebase. El código de sala es la
/// `IP:PUERTO` del host (docs/specs/netcode.md § "LAN").
/// `flutter run -d windows -t lib/app/flavors/main_lan.dart`
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerSharedDependencies();
  registerLanNetcode();
  runApp(const EcosApp());
}
