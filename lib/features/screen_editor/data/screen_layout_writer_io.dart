import 'dart:io';

import '../../../core/screen_layout/screen_layout_catalog.dart';

/// Guarda el JSON de [screen] en el repo.
typedef ScreenLayoutWriter = Future<void> Function(String screen, String json);

/// Escribe `<repo>/assets/layouts/<screen>.screen.json`.
ScreenLayoutWriter? createScreenLayoutWriter(String? repoRoot) {
  if (repoRoot == null) return null;
  return (screen, json) async {
    final f = File('$repoRoot/${ScreenLayoutCatalog.pathOf(screen)}');
    await f.parent.create(recursive: true);
    await f.writeAsString(json);
  };
}
