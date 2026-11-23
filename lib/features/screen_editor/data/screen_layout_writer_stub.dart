/// Guarda el JSON de [screen] en el repo. `null` = sin disco.
typedef ScreenLayoutWriter = Future<void> Function(String screen, String json);

/// Sin `dart:io`: no hay dónde guardar.
ScreenLayoutWriter? createScreenLayoutWriter(String? repoRoot) => null;
