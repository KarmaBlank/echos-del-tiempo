import 'dart:convert';
import 'dart:io';

import '../../../game_engine/models/travesia_meta.dart';
import '../../lobby/data/json_file_profile_store.dart';

/// El progreso entre runs en `travesia_meta.json`, en la carpeta de datos
/// de la Travesía (docs/specs/roguelike.md § 8). Nunca la del Mundo.
class JsonFileTravesiaMetaStore implements TravesiaMetaStore {
  JsonFileTravesiaMetaStore(this.file);

  final File file;

  static const fileName = 'travesia_meta.json';

  static JsonFileTravesiaMetaStore? forPlatform() {
    String? dir;
    try {
      dir = JsonFileProfileStore.dataDirectory();
    } on UnsupportedError {
      dir = null;
    }
    return dir == null
        ? null
        : JsonFileTravesiaMetaStore(
            File('$dir${Platform.pathSeparator}$fileName'));
  }

  @override
  Future<TravesiaMeta> load() async {
    if (!await file.exists()) return TravesiaMeta.empty;
    try {
      return TravesiaMeta.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return TravesiaMeta.empty;
    }
  }

  @override
  Future<void> save(TravesiaMeta meta) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(meta.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}
