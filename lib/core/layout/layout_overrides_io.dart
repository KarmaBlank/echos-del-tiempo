import 'dart:io';

import '../edition/game_data_guard_io.dart';

import 'package:flutter/services.dart';

import 'layout_catalog.dart';
import 'layout_doc.dart';
import '../data/manifest_text.dart';

/// Overrides locales de layouts en disco (§ 2.6):
/// `<root>/layouts/<screen>.layout.yaml`. Misma carpeta `overrides/` que
/// sprites y animaciones (game_editor.md § 4.2); nunca la carpeta de
/// datos del juego.
class LocalLayoutOverrides implements EditableLayoutOverrides {
  LocalLayoutOverrides(this.root) {
    if (isInsideGameData(root)) {
      throw StateError('Los overrides no van en la carpeta de datos del juego');
    }
  }


  final String root;
  static const folder = 'layouts';

  File _file(String screen) => File('$root/$folder/$screen.layout.yaml');

  @override
  Future<String?> read(String screen) async {
    final f = _file(screen);
    return f.existsSync() ? f.readAsString() : null;
  }

  @override
  Future<Set<String>> screens() async {
    final d = Directory('$root/$folder');
    if (!d.existsSync()) return {};
    return {
      for (final f in d.listSync().whereType<File>())
        if (f.uri.pathSegments.last.endsWith('.layout.yaml'))
          f.uri.pathSegments.last.replaceAll('.layout.yaml', ''),
    };
  }

  @override
  Future<void> put(String screen, String yaml) async {
    final f = _file(screen);
    await f.parent.create(recursive: true);
    await f.writeAsString(yaml, flush: true);
  }

  @override
  Future<void> remove(String screen) async {
    final f = _file(screen);
    if (f.existsSync()) await f.delete();
  }

  @override
  Future<bool> publish(String repoRoot, String screen) async {
    var yaml = await read(screen);
    if (yaml == null) return false;
    LayoutDoc.parse(yaml); // nunca publica algo ilegible
    final dir = '$repoRoot/${LayoutCatalog.dir}';
    final out = File('$dir/$screen.layout.yaml');
    // Se conserva el comentario de cabecera que ya tenía el archivo del
    // repo (no se pisa con "Generado por Editor -> LAYOUT").
    if (out.existsSync()) {
      yaml = withYamlHeader(yaml, yamlHeaderComment(await out.readAsString()));
    }
    await out.parent.create(recursive: true);
    await out.writeAsString(yaml, flush: true);
    final m = File('$repoRoot/${LayoutCatalog.manifestPath}');
    final text = m.existsSync() ? await m.readAsString() : '';
    await m.writeAsString(
        addLayoutManifestEntry(text, screen, '$screen.layout.yaml'),
        flush: true);
    await remove(screen);
    return true;
  }
}

/// Suma `<screen>: <file>` bajo `screens:` conservando el resto.
String addLayoutManifestEntry(String manifest, String screen, String file) =>
    upsertManifestEntry(manifest, 'screens', screen, file);

/// Crea la capa de overrides de layouts en [dir] (por defecto la carpeta
/// `overrides/` de sprites: `ECOS_OVERRIDES` o `overrides/` del directorio
/// actual).
EditableLayoutOverrides? createLocalLayoutOverrides([String? dir]) =>
    LocalLayoutOverrides(dir ?? _defaultDir());

/// Igual que `defaultOverridesDir` de sprites (game_editor.md § 4.2).
String _defaultDir() {
  const env = String.fromEnvironment('ECOS_OVERRIDES');
  return env.isNotEmpty
      ? env
      : '${Directory.current.path}${Platform.pathSeparator}overrides';
}

/// Lee los assets del repo en disco (`<repo>/assets/...`): el Editor ve lo
/// recién publicado sin recompilar.
AssetBundle? repoAssetBundle(String repo) => _RepoBundle(repo);

class _RepoBundle extends CachingAssetBundle {
  _RepoBundle(this.root);
  final String root;

  @override
  Future<ByteData> load(String key) async {
    final f = File('$root/$key');
    if (!f.existsSync()) throw StateError('No existe $key en $root');
    return ByteData.sublistView(Uint8List.fromList(await f.readAsBytes()));
  }
}
