import 'dart:io';
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

import '../../../core/audio/sfx_files.dart' show addSfxManifestEntry, sfxExtOf;
import '../../../core/procedural/procedural_art.dart';
import '../../admin/domain/sprites/art_pack.dart';
import '../domain/sprite_entry.dart';

/// Carpeta de overrides por defecto: `--dart-define=ECOS_OVERRIDES=<ruta>`
/// o `overrides/` en el directorio actual (junto al ejecutable o el
/// repo; game_editor.md § 4.2). Nunca la carpeta de datos del juego.
String defaultOverridesDir() {
  const env = String.fromEnvironment('ECOS_OVERRIDES');
  return env.isNotEmpty
      ? env
      : '${Directory.current.path}${Platform.pathSeparator}overrides';
}

/// Crea la capa de overrides en [dir] (por defecto [defaultOverridesDir])
/// y lee su índice.
Future<EditableSpriteOverrides?> createLocalSpriteOverrides([String? dir]) async {
  final o = LocalSpriteOverrides(dir ?? defaultOverridesDir());
  await o.refresh();
  return o;
}

/// Overrides locales de sprites en disco (game_editor.md § 4.2):
/// `<root>/sprites/<id>.png` + `<root>/sprite_overrides.yaml`
/// (`sprites: { <id>: sprites/<id>.png }`). Lo leen el Editor y
/// `main_dev` (`useLocalOverrides`); el juego publicado no.
class LocalSpriteOverrides implements EditableSpriteOverrides {
  LocalSpriteOverrides(this.root) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null &&
        _norm(root).startsWith(_norm('$appData${Platform.pathSeparator}EcosDelTiempo'))) {
      throw StateError('Los overrides no van en la carpeta de datos del juego');
    }
  }

  static String _norm(String p) =>
      File(p).absolute.path.replaceAll('\\', '/').toLowerCase();

  @override
  final String root;
  static const indexName = 'sprite_overrides.yaml';

  final _index = <String, String>{};

  File _file(String rel) => File('$root/$rel');

  @override
  Set<String> get overriddenIds => _index.keys.toSet();

  @override
  Future<void> refresh() async {
    _index.clear();
    final f = _file(indexName);
    if (!f.existsSync()) return;
    try {
      final doc = loadYaml(await f.readAsString());
      final s = doc is YamlMap ? doc['sprites'] : null;
      if (s is YamlMap) {
        for (final MapEntry(:key, :value) in s.entries) {
          if (value is String && _file(value).existsSync()) {
            _index[key as String] = value;
          }
        }
      }
    } catch (_) {
      // Índice roto: sin overrides (nunca rompe el juego).
    }
  }

  @override
  Future<Uint8List?> read(String id) async {
    final rel = _index[id];
    if (rel == null) return null;
    final f = _file(rel);
    return f.existsSync() ? f.readAsBytes() : null;
  }

  /// Guarda [png] como override de [id].
  @override
  Future<void> put(String id, Uint8List png) async {
    final rel = 'sprites/$id.png';
    final f = _file(rel);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(png, flush: true);
    _index[id] = rel;
    await _writeIndex();
  }

  /// Descarta el override de [id] (vuelve el asset).
  @override
  Future<void> remove(String id) async {
    final rel = _index.remove(id);
    if (rel != null) {
      final f = _file(rel);
      if (f.existsSync()) await f.delete();
    }
    await _writeIndex();
  }

  Future<void> _writeIndex() async {
    final ids = _index.keys.toList()..sort();
    final b = StringBuffer('# Overrides locales de sprites (Editor; '
        'docs/specs/game_editor.md § 4.2).\nsprites:\n');
    for (final id in ids) {
      b.writeln('  $id: ${_index[id]}');
    }
    if (ids.isEmpty) b.writeln('  {}');
    await Directory(root).create(recursive: true);
    await _file(indexName).writeAsString(
        ids.isEmpty ? 'sprites: {}\n' : b.toString(),
        flush: true);
  }

  /// Paquete de arte con todos los overrides (sprites y fx).
  @override
  Future<Uint8List> exportPack() async {
    await refreshFx();
    await refreshSfx();
    return ArtPack({
      for (final id in overriddenIds) id: (await read(id))!,
    }, {
      for (final id in overriddenFx) id: (await readFx(id))!,
    }, await readProcedural(), {
      for (final id in overriddenSfx) id: (await readSfx(id))!,
    }, _readLayouts()).encode();
  }

  /// Layouts de `<root>/layouts/` (editor_layout.md § 2.6): viajan en el
  /// mismo paquete de arte.
  Map<String, String> _readLayouts() {
    final d = Directory('$root/layouts');
    if (!d.existsSync()) return const {};
    return {
      for (final f in d.listSync().whereType<File>())
        if (f.uri.pathSegments.last.endsWith('.layout.yaml'))
          f.uri.pathSegments.last.replaceAll('.layout.yaml', ''):
              f.readAsStringSync(),
    };
  }

  // ------------------------------------------------- perillas (§ 7.5)

  static const proceduralName = 'procedural.yaml';

  @override
  Future<String?> readProcedural() async {
    final f = _file(proceduralName);
    return f.existsSync() ? f.readAsString() : null;
  }

  @override
  Future<void> putProcedural(String yaml) async {
    await Directory(root).create(recursive: true);
    await _file(proceduralName).writeAsString(yaml, flush: true);
  }

  @override
  Future<void> removeProcedural() async {
    final f = _file(proceduralName);
    if (f.existsSync()) await f.delete();
  }

  @override
  Future<bool> publishProcedural(String repoRoot) async {
    final raw = await readProcedural();
    if (raw == null) return false;
    final mine = ProcDoc.parse(raw);
    if (mine.isEmpty) {
      await removeProcedural();
      return false;
    }
    final out = File('$repoRoot/assets/sprites/$proceduralName');
    final repo = out.existsSync()
        ? ProcDoc.parse(await out.readAsString())
        : ProcDoc();
    await out.parent.create(recursive: true);
    await out.writeAsString(repo.merged(mine).encode(), flush: true);
    await removeProcedural();
    return true;
  }

  /// Instala un paquete de arte (pisa overrides con el mismo id).
  /// Devuelve los ids instalados (sprites y fx). [FormatException] si no
  /// es válido.
  @override
  Future<List<String>> importPack(Uint8List zip) async {
    final pack = ArtPack.decode(zip);
    for (final MapEntry(:key, :value) in pack.sprites.entries) {
      await put(key, value);
    }
    for (final MapEntry(:key, :value) in pack.fx.entries) {
      await putFx(key, value);
    }
    // Perillas: se fusionan con las que ya hay (las del paquete pisan).
    if (pack.procedural case final p?) {
      final mine = ProcDoc.parse(await readProcedural());
      await putProcedural(mine.merged(ProcDoc.parse(p)).encode());
    }
    for (final MapEntry(:key, :value) in pack.sfx.entries) {
      await putSfx(key, value);
    }
    for (final MapEntry(:key, :value) in pack.layouts.entries) {
      final f = _file('layouts/$key.layout.yaml');
      await f.parent.create(recursive: true);
      await f.writeAsString(value, flush: true);
    }
    return [
      ...pack.sprites.keys,
      ...pack.fx.keys,
      ...pack.sfx.keys,
      for (final k in pack.layouts.keys) 'layout:$k',
      if (pack.procedural != null) ArtPack.proceduralName,
    ];
  }

  // ------------------------------------------------------------ fx

  static const fxIndexName = 'fx_overrides.yaml';
  final _fx = <String, String>{};

  @override
  Set<String> get overriddenFx => _fx.keys.toSet();

  @override
  Future<void> refreshFx() async {
    _fx.clear();
    final f = _file(fxIndexName);
    if (!f.existsSync()) return;
    try {
      final doc = loadYaml(await f.readAsString());
      final s = doc is YamlMap ? doc['fx'] : null;
      if (s is YamlMap) {
        for (final MapEntry(:key, :value) in s.entries) {
          if (value is String && _file(value).existsSync()) {
            _fx[key as String] = value;
          }
        }
      }
    } catch (_) {
      // Índice roto: sin overrides de fx.
    }
  }

  @override
  Future<String?> readFx(String id) async {
    final rel = _fx[id];
    if (rel == null) return null;
    final f = _file(rel);
    return f.existsSync() ? f.readAsString() : null;
  }

  @override
  Future<void> putFx(String id, String yaml) async {
    final rel = 'fx/$id.fx.yaml';
    final f = _file(rel);
    await f.parent.create(recursive: true);
    await f.writeAsString(yaml, flush: true);
    _fx[id] = rel;
    await _writeFxIndex();
  }

  @override
  Future<void> removeFx(String id) async {
    final rel = _fx.remove(id);
    if (rel != null) {
      final f = _file(rel);
      if (f.existsSync()) await f.delete();
    }
    await _writeFxIndex();
  }

  Future<void> _writeFxIndex() async {
    final ids = _fx.keys.toList()..sort();
    final b = StringBuffer('# Overrides locales de animaciones (Editor; '
        'docs/specs/game_editor.md § 4.2).\n');
    if (ids.isEmpty) {
      b.writeln('fx: {}');
    } else {
      b.writeln('fx:');
      for (final id in ids) {
        b.writeln('  $id: ${_fx[id]}');
      }
    }
    await Directory(root).create(recursive: true);
    await _file(fxIndexName).writeAsString(b.toString(), flush: true);
  }

  @override
  Future<List<String>> publishFx(
      String repoRoot, Map<String, String> paths) async {
    final manifestFile = File('$repoRoot/assets/fx/fx_manifest.yaml');
    if (!manifestFile.existsSync()) {
      throw StateError('No encuentro assets/fx/fx_manifest.yaml en $repoRoot');
    }
    var manifest = await manifestFile.readAsString();
    final done = <String>[];
    for (final MapEntry(key: id, value: rel) in paths.entries) {
      final yaml = await readFx(id);
      if (yaml == null) continue;
      final out = File('$repoRoot/assets/fx/$rel');
      await out.parent.create(recursive: true);
      await out.writeAsString(yaml, flush: true);
      manifest = addFxManifestEntry(manifest, id, rel);
      await removeFx(id);
      done.add(id);
    }
    await manifestFile.writeAsString(manifest, flush: true);
    return done;
  }

  // ------------------------------------------------ sonido (§ 7.6)

  static const sfxIndexName = 'sfx_overrides.yaml';
  final _sfx = <String, String>{};

  @override
  Set<String> get overriddenSfx => _sfx.keys.toSet();

  @override
  Future<void> refreshSfx() async {
    _sfx.clear();
    final f = _file(sfxIndexName);
    if (!f.existsSync()) return;
    try {
      final doc = loadYaml(await f.readAsString());
      final s = doc is YamlMap ? doc['sfx'] : null;
      if (s is YamlMap) {
        for (final MapEntry(:key, :value) in s.entries) {
          if (value is String && _file(value).existsSync()) {
            _sfx[key as String] = value;
          }
        }
      }
    } catch (_) {
      // Índice roto: sin overrides de sonido.
    }
  }

  @override
  Future<Uint8List?> readSfx(String id) async {
    final rel = _sfx[id];
    if (rel == null) return null;
    final f = _file(rel);
    return f.existsSync() ? f.readAsBytes() : null;
  }

  @override
  Future<void> putSfx(String id, Uint8List bytes) async {
    final old = _sfx[id];
    final rel = 'sfx/$id.${sfxExtOf(bytes)}';
    if (old != null && old != rel && _file(old).existsSync()) {
      await _file(old).delete();
    }
    final f = _file(rel);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
    _sfx[id] = rel;
    await _writeSfxIndex();
  }

  @override
  Future<void> removeSfx(String id) async {
    final rel = _sfx.remove(id);
    if (rel != null && _file(rel).existsSync()) await _file(rel).delete();
    await _writeSfxIndex();
  }

  Future<void> _writeSfxIndex() async {
    final ids = _sfx.keys.toList()..sort();
    final b = StringBuffer('# Overrides locales de sonido (Editor; '
        'docs/specs/game_editor.md § 7.6).\n');
    if (ids.isEmpty) {
      b.writeln('sfx: {}');
    } else {
      b.writeln('sfx:');
      for (final id in ids) {
        b.writeln('  $id: ${_sfx[id]}');
      }
    }
    await Directory(root).create(recursive: true);
    await _file(sfxIndexName).writeAsString(b.toString(), flush: true);
  }

  @override
  Future<List<String>> publishSfx(String repoRoot) async {
    final manifestFile = File('$repoRoot/assets/sfx/sfx_manifest.yaml');
    if (!manifestFile.existsSync()) {
      throw StateError('No encuentro assets/sfx/sfx_manifest.yaml en $repoRoot');
    }
    var manifest = await manifestFile.readAsString();
    final done = <String>[];
    await refreshSfx();
    for (final id in overriddenSfx.toList()..sort()) {
      final bytes = await readSfx(id);
      if (bytes == null) continue;
      final rel = '$id.${sfxExtOf(bytes)}';
      final out = File('$repoRoot/assets/sfx/$rel');
      await out.writeAsBytes(bytes, flush: true);
      manifest = addSfxManifestEntry(manifest, id, rel);
      await removeSfx(id);
      done.add(id);
    }
    await manifestFile.writeAsString(manifest, flush: true);
    return done;
  }

  /// "Publicar al repo": copia cada override de [entries] a
  /// `<repo>/assets/sprites/<ruta>`, actualiza `sprite_manifest.yaml` si
  /// la entrada era procedural y borra el override. Devuelve los ids
  /// publicados.
  @override
  Future<List<String>> publish(String repoRoot, List<SpriteEntry> entries) async {
    final manifestFile = File('$repoRoot/assets/sprites/sprite_manifest.yaml');
    if (!manifestFile.existsSync()) {
      throw StateError('No encuentro assets/sprites/sprite_manifest.yaml en $repoRoot');
    }
    var manifest = await manifestFile.readAsString();
    final done = <String>[];
    for (final e in entries) {
      final png = await read(e.id);
      if (png == null) continue;
      final path = e.publishPath;
      final out = File('$repoRoot/assets/sprites/$path');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(png, flush: true);
      if (e.path != path) {
        manifest = setManifestPath(manifest, e.section, e.key, e.animation, path);
      }
      await remove(e.id);
      done.add(e.id);
    }
    await manifestFile.writeAsString(manifest, flush: true);
    return done;
  }
}
