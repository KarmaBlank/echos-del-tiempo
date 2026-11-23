import 'dart:convert';
import 'dart:io';

import '../../lobby/data/json_file_profile_store.dart';

/// Niebla explorada por mazmorra de este dispositivo
/// (persistent_dungeons.md § 2.2): `accounts/fog.json`, el `archive` de
/// `FogOfWar` tal cual (clave → bits en base64). Es del jugador local.
class FogStore {
  FogStore(this.file);

  final File file;

  /// El de la carpeta de datos del escritorio, o `null` (móvil, web).
  static FogStore? forPlatform() {
    String? dir;
    try {
      dir = JsonFileProfileStore.dataDirectory();
    } on UnsupportedError {
      dir = null;
    }
    if (dir == null) return null;
    final sep = Platform.pathSeparator;
    return FogStore(File('$dir${sep}accounts${sep}fog.json'));
  }

  Map<String, String> load() {
    try {
      if (!file.existsSync()) return const {};
      final j = jsonDecode(file.readAsStringSync());
      if (j is! Map) return const {};
      return {
        for (final e in j.entries)
          if (e.value is String) '${e.key}': e.value as String,
      };
    } catch (_) {
      return const {};
    }
  }

  void save(Map<String, String> archive) {
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(archive));
    } catch (_) {}
  }
}
