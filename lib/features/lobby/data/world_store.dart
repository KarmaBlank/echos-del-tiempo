import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../../game_engine/models/world_save.dart';
import 'json_file_profile_store.dart';

/// Dónde viven los mundos de la cuenta (town_loop.md § 11c): un archivo
/// por mundo en `accounts/worlds/<id>.json` dentro de la carpeta de datos
/// de la edición, y el elegido en `accounts/world_selected.json`.
abstract interface class WorldStore {
  /// Todos los mundos. Si no hay ninguno (save viejo, primera vez) arma
  /// el primero ("Mi mundo", Cooperativo) con el estado actual del
  /// pueblo y lo guarda: la migración.
  Future<WorldBook> load();

  /// Guarda la lista entera (mundos y elegido) y borra del disco los que
  /// ya no están.
  Future<void> save(WorldBook book);
}

/// Id nuevo de mundo (`w` + milisegundos + azar).
String newWorldId(DateTime now) =>
    'w${now.millisecondsSinceEpoch.toRadixString(36)}'
    '${math.Random().nextInt(1 << 20).toRadixString(36)}';

WorldBook _migrate(DateTime now, String id) => WorldBook()
    .create(WorldBook.firstWorldName, WorldLabel.cooperativo, now: now, id: id);

/// En memoria (tests, plataformas sin carpeta de datos).
class InMemoryWorldStore implements WorldStore {
  InMemoryWorldStore([this._book]);

  WorldBook? _book;
  int saves = 0;

  @override
  Future<WorldBook> load() async => _book ??= _migrate(DateTime.now(), 'w1');

  @override
  Future<void> save(WorldBook book) async {
    saves++;
    _book = book;
  }
}

/// Los mundos en disco.
class JsonFileWorldStore implements WorldStore {
  JsonFileWorldStore(this.dataDirectory,
      {DateTime Function()? now, String Function(DateTime)? newId})
      : _now = now ?? DateTime.now,
        _newId = newId ?? newWorldId;

  /// La carpeta de datos de la edición (la de `account.json`).
  final Directory dataDirectory;
  final DateTime Function() _now;
  final String Function(DateTime) _newId;

  String get _sep => Platform.pathSeparator;

  Directory get worldsDir =>
      Directory('${dataDirectory.path}${_sep}accounts${_sep}worlds');

  File get selectedFile =>
      File('${dataDirectory.path}${_sep}accounts${_sep}world_selected.json');

  File worldFile(String id) => File('${worldsDir.path}$_sep$id.json');

  /// El de la carpeta de datos del escritorio, o `null` (móvil, web).
  static JsonFileWorldStore? forPlatform() {
    String? dir;
    try {
      dir = JsonFileProfileStore.dataDirectory();
    } on UnsupportedError {
      dir = null;
    }
    return dir == null ? null : JsonFileWorldStore(Directory(dir));
  }

  @override
  Future<WorldBook> load() async {
    final worlds = <WorldSave>[];
    if (await worldsDir.exists()) {
      await for (final f in worldsDir.list()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        try {
          final w = WorldSave.fromJson(jsonDecode(await f.readAsString()));
          if (w != null) worlds.add(w);
        } catch (_) {
          // Archivo dañado: se deja en disco (no se pisa) y se ignora.
        }
      }
    }
    if (worlds.isEmpty) {
      final now = _now();
      final book = _migrate(now, _newId(now));
      await save(book);
      return book;
    }
    worlds.sort((a, b) => a.created.compareTo(b.created));
    String? sel;
    try {
      if (await selectedFile.exists()) {
        final j = jsonDecode(await selectedFile.readAsString());
        if (j is Map && j['selected'] is String) sel = j['selected'] as String;
      }
    } catch (_) {}
    return WorldBook(worlds: worlds, selectedId: sel);
  }

  Future<void> _write(File f, Object json) async {
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(json),
        flush: true);
    if (await f.exists()) await f.delete();
    await tmp.rename(f.path);
  }

  @override
  Future<void> save(WorldBook book) async {
    await worldsDir.create(recursive: true);
    for (final w in book.worlds) {
      await _write(worldFile(w.id), w.toJson());
    }
    final keep = {for (final w in book.worlds) worldFile(w.id).path};
    await for (final f in worldsDir.list()) {
      if (f is File && f.path.endsWith('.json') && !keep.contains(f.path)) {
        // Solo los que son mundos (un archivo ajeno se deja).
        try {
          if (WorldSave.fromJson(jsonDecode(await f.readAsString())) != null) {
            await f.delete();
          }
        } catch (_) {}
      }
    }
    await _write(selectedFile, {'selected': book.selectedId});
  }
}
