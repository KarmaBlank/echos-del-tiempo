import 'package:flutter/widgets.dart';

import '../../core/balance/balance_asset_loader.dart';
import '../../core/data/ult_data_loader.dart';
import '../../core/di/service_locator.dart';
import '../../core/persistence/exit_on_close.dart';
import '../../core/settings/frame_limiter.dart';
import '../../features/combat/presentation/scene/fx_bridge.dart';
import '../app.dart';

/// Composition root de la versión LAN: misma red local (o dos ventanas en
/// la misma PC), WebSocket directo, sin Firebase. El código de sala es la
/// `IP:PUERTO` del host (docs/specs/netcode.md § "LAN").
/// `flutter run -d windows -t lib/app/flavors/main_lan.dart`
Future<void> main() async {
  // Binding con límite de FPS (docs/specs/settings.md § 3.4).
  EcosBinding.ensureInitialized();
  // Parche de balance (docs/specs/balance_admin.md § 3).
  // Animaciones como datos (docs/specs/game_editor.md § 2.2).
  await installFx();
  registerSharedDependencies(
      balance: await BalanceAssetLoader.load(),
      ults: await UltDataLoader.load());
  // Cerrar la ventana guarda antes (docs/specs/characters.md § 1.4).
  installExitOnClose();
  registerLanNetcode();
  runApp(const EcosApp());
}
