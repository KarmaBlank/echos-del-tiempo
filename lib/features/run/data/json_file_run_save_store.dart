import 'dart:convert';
import 'dart:io';

import '../../../game_engine/models/run_save.dart';
import '../../lobby/data/json_file_profile_store.dart';

/// La run en curso de la Travesía en `travesia_run.json`, en la carpeta
/// de datos de la Travesía (docs/specs/roguelike.md § 8.5). Solo la
/// registra el composition root de la Travesía: nunca toca la del Mundo.
class JsonFileRunSaveStore implements RunSaveStore {
  JsonFileRunSaveStore(this.file);

  final File file;

  static const fileName = 'travesia_run.json';

  static JsonFileRunSaveStore? forPlatform() {
    String? dir;
    try {
      dir = JsonFileProfileStore.dataDirectory();
    } on UnsupportedError {
      dir = null;
    }
    return dir == null
        ? null
        : JsonFileRunSaveStore(File('$dir${Platform.pathSeparator}$fileName'));
  }

  @override
  Future<RunSave?> load() async {
    if (!await file.exists()) return null;
    try {
      return RunSave.tryParse(jsonDecode(await file.readAsString()));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(RunSave save) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(save.toJson()), flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}
