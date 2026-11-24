import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../../core/audio/sfx_files.dart';
import '../../core/balance/balance_asset_loader.dart';
import '../../core/data/build_template_loader.dart';
import '../../core/data/climate_data_loader.dart';
import '../../core/data/npc_data_loader.dart';
import '../../core/data/world_events_loader.dart';
import '../../core/data/ult_data_loader.dart';
import '../../core/di/service_locator.dart';
import '../../core/i18n/string_tables.dart';
import '../../core/layout/layout_catalog.dart';
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
  // Sonidos como archivo (docs/specs/game_editor.md § 7.6).
  await SfxFiles.install();
  // Layouts como datos (docs/specs/editor_layout.md § 2.6).
  await LayoutCatalog.instance.load();
  // Plantillas de BUILD (docs/specs/build_planner_v2.md § 2.2).
  await BuildTemplateLoader.load();
  // Textos y encargos de los habitantes (docs/specs/npc_editor.md § 1).
  await NpcDataLoader.load();
  await WorldEventsLoader.load();
  // Climate rules (docs/specs/weather_seasons.md § 8).
  await ClimateDataLoader.load();
  registerSharedDependencies(
      balance: await BalanceAssetLoader.load(),
      ults: await UltDataLoader.load(),
      strings: await StringTables.load(rootBundle.loadString));
  // Cerrar la ventana guarda antes (docs/specs/characters.md § 1.4).
  installExitOnClose();
  registerLanNetcode();
  runApp(const EcosApp());
}
