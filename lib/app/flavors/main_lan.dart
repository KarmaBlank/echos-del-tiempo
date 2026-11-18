import 'package:flutter/widgets.dart';

import '../../core/di/service_locator.dart';
import '../../core/persistence/exit_on_close.dart';
import '../../core/settings/frame_limiter.dart';
import '../app.dart';

/// Composition root de la versión LAN: misma red local (o dos ventanas en
/// la misma PC), WebSocket directo, sin Firebase. El código de sala es la
/// `IP:PUERTO` del host (docs/specs/netcode.md § "LAN").
/// `flutter run -d windows -t lib/app/flavors/main_lan.dart`
void main() {
  // Binding con límite de FPS (docs/specs/settings.md § 3.4).
  EcosBinding.ensureInitialized();
  registerSharedDependencies();
  // Cerrar la ventana guarda antes (docs/specs/characters.md § 1.4).
  installExitOnClose();
  registerLanNetcode();
  runApp(const EcosApp());
}
