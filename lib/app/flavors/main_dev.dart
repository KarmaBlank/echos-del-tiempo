import 'package:flutter/widgets.dart';

import '../../core/audio/sfx_files.dart';
import '../../core/balance/balance_asset_loader.dart';
import '../../core/data/build_template_loader.dart';
import '../../core/data/ult_data_loader.dart';
import '../../core/di/service_locator.dart';
import '../../core/layout/layout_catalog.dart';
import '../../core/layout/layout_overrides.dart';
import '../../core/persistence/exit_on_close.dart';
import '../../core/settings/frame_limiter.dart';
import '../../features/combat/data/local_sprite_overrides.dart';
import '../../features/combat/presentation/sprite_catalog.dart';
import '../../features/combat/presentation/scene/fx_bridge.dart';
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
    useLocalOverrides: true,
  );
  // Arte de prueba del Editor (docs/specs/game_editor.md § 4.2).
  final local = await createLocalSpriteOverrides();
  SpriteCatalog.defaultOverrides = local;
  // Animaciones como datos, con los overrides locales del Editor (§ 4.2).
  await installFx(overrides: local);
  // Sonidos como archivo (docs/specs/game_editor.md § 7.6).
  await SfxFiles.install(overrides: local);
  // Layouts como datos con los overrides del Editor (editor_layout.md § 2.6).
  LayoutCatalog.instance.overrides =
      createLocalLayoutOverrides();
  await LayoutCatalog.instance.load();
  // Parche de balance (docs/specs/balance_admin.md § 3).
  // Plantillas de BUILD (docs/specs/build_planner_v2.md § 2.2).
  await BuildTemplateLoader.load();
  registerSharedDependencies(
      balance: await BalanceAssetLoader.load(),
      ults: await UltDataLoader.load());
  // Cerrar la ventana guarda antes (docs/specs/characters.md § 1.4).
  installExitOnClose();
  registerP2PNetcode(signaling: await resolveP2PSignaling());
  runApp(const EcosApp());
}
