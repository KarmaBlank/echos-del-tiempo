import 'package:flutter/widgets.dart';

import '../../core/balance/balance_asset_loader.dart';
import '../../core/di/service_locator.dart';
import '../../core/persistence/exit_on_close.dart';
import '../../core/settings/frame_limiter.dart';
import '../app.dart';
import '../feature_flags.dart';
import 'firebase_bootstrap.dart';

/// Composition root de desarrollo: mismo netcode P2P, pero con todas
/// las feature flags "experimentales" prendidas (roster completo,
/// personajes/features en prueba, debug overlay). Es el build en el
/// que vos probás cosas antes de que lleguen al resto.
Future<void> main() async {
  // Binding con límite de FPS (docs/specs/settings.md § 3.4).
  EcosBinding.ensureInitialized();
  FeatureFlags.instance = const FeatureFlags(
    unlockAllCharacters: true,
    showDebugOverlay: true,
    enableExperimentalFeatures: true,
    devTools: true,
    soloParty: true,
  );
  // Parche de balance (docs/specs/balance_admin.md § 3).
  registerSharedDependencies(balance: await BalanceAssetLoader.load());
  // Cerrar la ventana guarda antes (docs/specs/characters.md § 1.4).
  installExitOnClose();
  registerP2PNetcode(signaling: await resolveP2PSignaling());
  runApp(const EcosApp());
}
