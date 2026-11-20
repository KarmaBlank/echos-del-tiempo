import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/admin/data/admin_host.dart';
import '../../features/admin/presentation/admin_app.dart';
import '../../features/admin/presentation/admin_controller.dart';
import '../../features/admin/presentation/editor/fx_editor_controller.dart';
import '../../features/admin/presentation/editor/sprite_editor_controller.dart';
import '../../features/combat/presentation/scene/fx_bridge.dart';
import '../../features/combat/data/local_sprite_overrides.dart';
import '../../features/combat/presentation/sprite_catalog.dart';
import '../../firebase_options.dart';

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
  final fx = FxEditorController(
    catalog: await installFx(overrides: overrides),
    overrides: overrides,
    repoPath: repo,
    spriteImage: sprites.imageOf,
  );
  sprites.fx = fx;
  unawaited(sprites.loadAll());
  runApp(AdminApp(controller: controller, sprites: sprites, animations: fx));
  // Releases publicados: la versión siguiente no puede repetir un tag.
  unawaited(controller.refreshReleases());
}
