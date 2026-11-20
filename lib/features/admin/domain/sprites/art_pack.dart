import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:yaml/yaml.dart';

/// Paquete de arte (game_editor.md § 4.2): un zip con overrides de
/// sprites (y, desde el paso 2, de fx) para pasárselo a un amigo sin
/// publicar. Dart puro.
///
/// ```
/// art_pack.yaml      schema: 1 / sprites: { <id>: sprites/<id>.png }
/// sprites/<id>.png
/// ```
class ArtPack {
  const ArtPack(this.sprites);

  /// Id de sprite → bytes PNG.
  final Map<String, Uint8List> sprites;

  static const indexName = 'art_pack.yaml';
  static const schema = 1;

  Uint8List encode() {
    final ids = sprites.keys.toList()..sort();
    final index = StringBuffer('schema: $schema\nsprites:\n');
    for (final id in ids) {
      index.writeln('  $id: sprites/$id.png');
    }
    final a = Archive();
    final idx = utf8.encode(index.toString());
    a.addFile(ArchiveFile(indexName, idx.length, idx));
    for (final id in ids) {
      a.addFile(ArchiveFile('sprites/$id.png', sprites[id]!.length, sprites[id]!));
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
    return ArtPack(out);
  }
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
