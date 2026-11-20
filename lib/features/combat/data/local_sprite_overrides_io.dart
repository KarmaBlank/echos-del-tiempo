import 'dart:io';
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

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

  /// Paquete de arte con todos los overrides.
  @override
  Future<Uint8List> exportPack() async => ArtPack({
        for (final id in overriddenIds) id: (await read(id))!,
      }).encode();

  /// Instala un paquete de arte (pisa overrides con el mismo id).
  /// Devuelve los ids instalados. [FormatException] si no es válido.
  @override
  Future<List<String>> importPack(Uint8List zip) async {
    final pack = ArtPack.decode(zip);
    for (final MapEntry(:key, :value) in pack.sprites.entries) {
      await put(key, value);
    }
    return pack.sprites.keys.toList();
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
