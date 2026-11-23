import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/audio/audioplayers_sfx_player.dart';
import '../../core/audio/sfx_files.dart';
import '../../core/audio/sfx_service.dart';
import '../../core/data/build_template_loader.dart';
import '../../core/data/npc_data_loader.dart';
import '../../features/admin/data/admin_host.dart';
import '../../features/admin/presentation/admin_app.dart';
import '../../features/admin/presentation/admin_controller.dart';
import '../../features/admin/presentation/editor/fx_editor_controller.dart';
import '../../features/admin/presentation/editor/layout_editor_controller.dart';
import '../../features/admin/presentation/editor/npc_editor_controller.dart';
import '../../features/admin/presentation/editor/sprite_editor_controller.dart';
import '../../features/combat/presentation/scene/fx_bridge.dart';
import '../../features/combat/data/local_sprite_overrides.dart';
import '../../features/combat/presentation/sprite_catalog.dart';
import '../../firebase_options.dart';
import '../../core/layout/layout_catalog.dart';
import '../../core/layout/layout_overrides.dart';
import '../../core/screen_layout/screen_layout_catalog.dart';
import '../../features/screen_editor/data/screen_layout_writer.dart';
import '../../features/screen_editor/presentation/screen_editor_controller.dart';

/// Composition root del admin de balance y monitoreo
/// (docs/specs/balance_admin.md § 5):
/// `flutter run -d windows -t lib/app/flavors/main_admin.dart`
/// (desde la carpeta del repo, o con `--dart-define=ECOS_REPO=<ruta>`).
///
/// No registra las dependencias del juego (`registerSharedDependencies`):
/// no toca `%APPDATA%\EcosDelTiempo` (ni cuenta, ni ajustes, ni log) ni
/// abre red de juego. Solo el motor puro para la vista previa.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Plantillas de BUILD para Balance → Plantillas (build_planner_v2.md § 2.2).
  await BuildTemplateLoader.load();
  // Textos y encargos de los habitantes (docs/specs/npc_editor.md § 1).
  await NpcDataLoader.load();
  // Mismas opciones que la señalización REST de escritorio (solo lectura).
  const firebase = DefaultFirebaseOptions.windows;
  final controller = AdminController(
    host: createAdminHost(),
    firestoreProjectId: firebase.projectId,
    firestoreApiKey: firebase.apiKey,
  );
  await controller.load();
  // Visuales → Sprites (docs/specs/game_editor.md § 3.1): el catálogo con
  // la capa de overrides locales (`overrides/` junto al repo/ejecutable).
  final host = controller.host;
  final repo = host.defaultRepoPath;
  final overrides = await createLocalSpriteOverrides(
      repo == null ? null : host.join(repo, 'overrides'));
  final sprites = SpriteEditorController(
    catalog: await SpriteCatalog.load(overrides: overrides),
    overrides: overrides,
    repoPath: repo,
  );
  // Visuales → Animaciones (§ 3.2): fx de datos + overrides de la misma
  // carpeta + el adaptador de lo que todavía es código.
  // Sonidos como archivo + overrides de la misma carpeta (§ 7.6).
  await SfxFiles.install(overrides: overrides);
  final fx = FxEditorController(
    catalog: await installFx(overrides: overrides),
    overrides: overrides,
    repoPath: repo,
    spriteImage: sprites.imageOf,
    // Vista previa con sonido (§ 7.6): el mismo sintetizador del juego.
    sfx: SfxService(player: AudioplayersSfxPlayer()),
  );
  sprites.fx = fx;
  // LAYOUT (docs/specs/editor_layout.md § 3): YAML del repo en disco (para
  // ver lo publicado sin recompilar) + overrides de la misma carpeta.
  final layoutCatalog = LayoutCatalog(
      bundle: repo == null ? null : repoAssetBundle(repo),
      overrides: createLocalLayoutOverrides(
          repo == null ? null : host.join(repo, 'overrides')));
  await layoutCatalog.load();
  final layouts = LayoutEditorController(
    catalog: layoutCatalog,
    overrides: layoutCatalog.overrides as EditableLayoutOverrides?,
    repoPath: repo,
  );
  // PANTALLAS (docs/specs/screen_editor.md § 5): layouts de pantallas
  // del repo en disco; GUARDAR escribe ahí.
  final screenCatalog = ScreenLayoutCatalog();
  await screenCatalog.load(
      bundle: repo == null ? null : repoAssetBundle(repo));
  final screens = ScreenEditorController(
      catalog: screenCatalog, writer: createScreenLayoutWriter(repo));
  unawaited(sprites.loadAll());
  runApp(AdminApp(
      controller: controller,
      sprites: sprites,
      animations: fx,
      layouts: layouts,
      screens: screens,
      // NPC (docs/specs/npc_editor.md).
      npcs: NpcEditorController(
          balance: controller, spriteImage: sprites.imageOf)));
  // Releases publicados: la versión siguiente no puede repetir un tag.
  unawaited(controller.refreshReleases());
}
