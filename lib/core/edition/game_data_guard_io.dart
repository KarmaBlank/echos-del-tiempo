import 'dart:io';

import 'game_edition.dart';

/// Si [path] cae dentro de la carpeta de datos de alguno de los juegos
/// bajo `%APPDATA%` (`EcosDelTiempo` o `EcosDelTiempo-Travesia`). Los
/// overrides del Editor nunca van ahí (game_editor.md § 4.2).
bool isInsideGameData(String path) {
  final appData = Platform.environment['APPDATA'];
  if (appData == null) return false;
  String norm(String p) =>
      File(p).absolute.path.replaceAll('\\', '/').toLowerCase();
  final target = norm(path);
  for (final e in GameEdition.all) {
    final dir = norm('$appData${Platform.pathSeparator}${e.dataFolder}');
    if (target == dir || target.startsWith('$dir/')) return true;
  }
  return false;
}
