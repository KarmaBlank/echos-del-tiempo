import 'package:flutter/widgets.dart';

import '../../core/di/service_locator.dart';
import '../app.dart';
import '../feature_flags.dart';
import 'firebase_bootstrap.dart';

/// Composition root de desarrollo: mismo netcode P2P, pero con todas
/// las feature flags "experimentales" prendidas (roster completo,
/// personajes/features en prueba, debug overlay). Es el build en el
/// que vos probás cosas antes de que lleguen al resto.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FeatureFlags.instance = const FeatureFlags(
    unlockAllCharacters: true,
    showDebugOverlay: true,
    enableExperimentalFeatures: true,
  );
  registerSharedDependencies();
  registerP2PNetcode(signaling: await resolveP2PSignaling());
  runApp(const EcosApp());
}
