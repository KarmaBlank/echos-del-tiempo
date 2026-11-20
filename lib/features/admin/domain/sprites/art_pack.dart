import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:yaml/yaml.dart';

/// Paquete de arte (game_editor.md § 4.2): un zip con overrides de
/// sprites y de animaciones (fx, paso 2) para pasárselo a un amigo sin
/// publicar. Dart puro.
///
/// ```
/// art_pack.yaml      schema: 1
///                    sprites: { <id>: sprites/<id>.png }
///                    fx: { <id>: fx/<id>.fx.yaml }
/// sprites/<id>.png
/// fx/<id>.fx.yaml
/// ```
class ArtPack {
  const ArtPack(this.sprites,
      [this.fx = const {}, this.procedural, this.layouts = const {}]);

  /// Id de sprite → bytes PNG.
  final Map<String, Uint8List> sprites;

  /// Id de animación → texto `.fx.yaml`.
  final Map<String, String> fx;

  /// Perillas del arte procedural (`procedural.yaml`, § 7.5), o `null`.
  final String? procedural;

  static const proceduralName = 'procedural.yaml';

  /// Pantalla → texto `<screen>.layout.yaml` (editor_layout.md § 2.6).
  final Map<String, String> layouts;

  static const indexName = 'art_pack.yaml';
  static const schema = 1;

  Uint8List encode() {
    final ids = sprites.keys.toList()..sort();
    final fxIds = fx.keys.toList()..sort();
    final index = StringBuffer('schema: $schema\n')
      ..writeln(ids.isEmpty ? 'sprites: {}' : 'sprites:');
    for (final id in ids) {
      index.writeln('  $id: sprites/$id.png');
    }
    if (fxIds.isNotEmpty) {
      index.writeln('fx:');
      for (final id in fxIds) {
        index.writeln('  $id: fx/$id.fx.yaml');
      }
    }
    if (procedural != null) index.writeln('procedural: $proceduralName');
    final layoutIds = layouts.keys.toList()..sort();
    if (layoutIds.isNotEmpty) {
      index.writeln('layouts:');
      for (final id in layoutIds) {
        index.writeln('  $id: layouts/$id.layout.yaml');
      }
    }
    final a = Archive();
    final idx = utf8.encode(index.toString());
    a.addFile(ArchiveFile(indexName, idx.length, idx));
    for (final id in ids) {
      a.addFile(ArchiveFile('sprites/$id.png', sprites[id]!.length, sprites[id]!));
    }
    for (final id in fxIds) {
      final b = utf8.encode(fx[id]!);
      a.addFile(ArchiveFile('fx/$id.fx.yaml', b.length, b));
    }
    if (procedural case final p?) {
      final b = utf8.encode(p);
      a.addFile(ArchiveFile(proceduralName, b.length, b));
    }
    for (final id in layoutIds) {
      final b = utf8.encode(layouts[id]!);
      a.addFile(ArchiveFile('layouts/$id.layout.yaml', b.length, b));
    }
    return Uint8List.fromList(ZipEncoder().encode(a)!);
  }

  /// Lanza [FormatException] si no es un paquete válido.
  static ArtPack decode(Uint8List zip) {
    final Archive a;
    try {
      a = ZipDecoder().decodeBytes(zip);
    } catch (_) {
      throw const FormatException('No es un zip válido.');
    }
    final idx = a.findFile(indexName);
    if (idx == null) throw const FormatException('Falta $indexName.');
    final doc = loadYaml(utf8.decode(idx.content as List<int>));
    if (doc is! YamlMap || (doc['schema'] as num? ?? 0) > schema) {
      throw const FormatException('Índice del paquete no soportado.');
    }
    final out = <String, Uint8List>{};
    final sprites = doc['sprites'];
    if (sprites is YamlMap) {
      for (final MapEntry(:key, :value) in sprites.entries) {
        final f = a.findFile(value as String);
        if (f == null) throw FormatException('Falta $value.');
        out[key as String] = Uint8List.fromList(f.content as List<int>);
      }
    }
    final fx = <String, String>{};
    final fxIdx = doc['fx'];
    if (fxIdx is YamlMap) {
      for (final MapEntry(:key, :value) in fxIdx.entries) {
        final f = a.findFile(value as String);
        if (f == null) throw FormatException('Falta $value.');
        fx[key as String] = utf8.decode(f.content as List<int>);
      }
    }
    String? procedural;
    if (doc['procedural'] case final String path) {
      final f = a.findFile(path);
      if (f == null) throw FormatException('Falta $path.');
      procedural = utf8.decode(f.content as List<int>);
    }
    final layouts = <String, String>{};
    if (doc['layouts'] case final YamlMap l) {
      for (final MapEntry(:key, :value) in l.entries) {
        final f = a.findFile(value as String);
        if (f == null) throw FormatException('Falta $value.');
        layouts[key as String] = utf8.decode(f.content as List<int>);
      }
    }
    return ArtPack(out, fx, procedural, layouts);
  }
}

/// Suma (o corrige) en el texto de fx_manifest.yaml la entrada
/// `<id>: <path>` bajo `fx:`, conservando comentarios y el resto. Si ya
/// apunta a [path], devuelve el texto igual.
String addFxManifestEntry(String manifest, String id, String path) {
  final lines = const LineSplitter().convert(manifest);
  final s = lines.indexOf('fx:');
  if (s < 0) return '${manifest.trimRight()}\nfx:\n  $id: $path\n';
  var end = s + 1;
  while (end < lines.length &&
      (lines[end].startsWith(' ') || lines[end].trim().isEmpty)) {
    end++;
  }
  final k = lines.indexWhere((l) => l.startsWith('  $id:'), s + 1);
  if (k >= 0 && k < end) {
    if (lines[k].trim() == '$id: $path') return manifest;
    lines[k] = '  $id: $path';
  } else {
    var at = end;
    while (at > s + 1 && lines[at - 1].trim().isEmpty) {
      at--;
    }
    lines.insert(at, '  $id: $path');
  }
  return '${lines.join('\n')}\n';
}

/// Reescribe en el texto de sprite_manifest.yaml la entrada
/// `<section>.<key>` para que apunte a [path] (frame [animation]),
/// conservando comentarios y el resto del archivo. Para publicar al repo
/// un PNG de algo que era `procedural: true`. Si la entrada ya apunta a
/// [path], devuelve el texto igual.
String setManifestPath(String manifest, String section, String key,
    String animation, String path) {
  final lines = const LineSplitter().convert(manifest);
  final s = lines.indexOf('$section:');
  if (s < 0) {
    return '${manifest.trimRight()}\n$section:\n  $key:\n    $animation: $path\n';
  }
  var end = s + 1;
  while (end < lines.length &&
      (lines[end].startsWith(' ') || lines[end].trim().isEmpty)) {
    end++;
  }
  final block = ['  $key:', '    $animation: $path'];
  final k = lines.indexWhere((l) => l.startsWith('  $key:'), s + 1);
  if (k < 0 || k >= end) {
    lines.insertAll(end, block);
  } else {
    var kEnd = k + 1;
    while (kEnd < end && lines[kEnd].startsWith('    ')) {
      kEnd++;
    }
    final children = lines.sublist(k + 1, kEnd);
    if (children.any((l) => l.trim() == '$animation: $path')) return manifest;
    // Se conservan los datos que no son el frame (scale, float, …); se va
    // `procedural` y `size` (ahora manda el PNG).
    final keep = children.where((l) {
      final t = l.trim();
      return !t.startsWith('$animation:') &&
          !t.startsWith('procedural:') &&
          !t.startsWith('size:');
    });
    lines.replaceRange(k, kEnd, [...block, ...keep]);
  }
  return '${lines.join('\n')}\n';
}
