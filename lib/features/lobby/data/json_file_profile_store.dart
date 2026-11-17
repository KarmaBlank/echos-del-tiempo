import 'dart:convert';
import 'dart:io';

import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/profile_store.dart';

/// `loadProfile` / `saveProfile` del prototipo sobre un archivo JSON.
/// Ver docs/specs/exploration.md § "Persistencia".
///
/// Usa solo `dart:io` (sin `path_provider`, que no es dependencia
/// directa): la carpeta la decide [forPlatform] con las variables de
/// entorno de cada escritorio.
class JsonFileProfileStore implements ProfileStore {
  JsonFileProfileStore(this.file);

  final File file;

  static const fileName = 'profile.json';

  /// El store de la carpeta de datos del usuario en escritorio, o `null`
  /// si la plataforma no tiene una conocida (móvil, web): ahí quien lo
  /// usa cae a `InMemoryProfileStore`.
  static JsonFileProfileStore? forPlatform() {
    String? dir;
    try {
      dir = dataDirectory();
    } on UnsupportedError {
      dir = null; // web: `Platform` no existe
    }
    return dir == null ? null : JsonFileProfileStore(File('$dir/$fileName'));
  }

  /// `%APPDATA%\EcosDelTiempo`, `~/Library/Application Support/EcosDelTiempo`
  /// o `$XDG_DATA_HOME|~/.local/share` + `/ecos_del_tiempo`.
  static String? dataDirectory() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      final appData = env['APPDATA'];
      return appData == null ? null : '$appData\\EcosDelTiempo';
    }
    final home = env['HOME'];
    if (Platform.isMacOS) {
      return home == null
          ? null
          : '$home/Library/Application Support/EcosDelTiempo';
    }
    if (Platform.isLinux) {
      final xdg = env['XDG_DATA_HOME'];
      if (xdg != null && xdg.isNotEmpty) return '$xdg/ecos_del_tiempo';
      return home == null ? null : '$home/.local/share/ecos_del_tiempo';
    }
    return null;
  }

  @override
  Future<PlayerProfile?> load() async {
    try {
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, Object?>) return null;
      return PlayerProfile.fromJson(json);
    } catch (_) {
      // Corrupto o ilegible: como el prototipo, se arranca de cero.
      return null;
    }
  }

  @override
  Future<void> save(PlayerProfile profile) async {
    await file.parent.create(recursive: true);
    // Escritura atómica: si se corta a la mitad queda el archivo viejo.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(profile.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}
