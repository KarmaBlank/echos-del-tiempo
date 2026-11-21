import 'dart:convert';

/// Edición de texto de manifests YAML de una sola sección plana
/// (`<section>:` con hijos `  <key>: <value>`), usada por los "Publicar
/// al repo" del Editor. Conserva comentarios y el resto del archivo.
///
/// Robusta a CRLF, a espacios / comentarios tras `<section>:` y a
/// archivos ya rotos con la sección repetida: une todas en UNA (la
/// primera), sin claves duplicadas. Idempotente.

/// ¿[line] abre la sección [section]? (`fx:`, `fx:  # nota`, `sfx: {}`).
bool isManifestSection(String line, String section) {
  final t = line.replaceFirst(RegExp(r'\s+#.*$'), '').trimRight();
  return t == '$section:' || t == '$section: {}';
}

/// Índice de la primera línea que abre [section] (o -1).
int manifestSectionIndex(List<String> lines, String section) =>
    lines.indexWhere((l) => isManifestSection(l, section));

/// Fin (exclusivo) del bloque que abre en [s].
int manifestBlockEnd(List<String> lines, int s) {
  var end = s + 1;
  while (end < lines.length &&
      (lines[end].startsWith(' ') ||
          lines[end].startsWith('\t') ||
          lines[end].trim().isEmpty)) {
    end++;
  }
  return end;
}

/// Líneas de [text] sin `\r`, y con la sección [section] repetida unida
/// en la primera (los hijos de las siguientes se suman; una clave
/// repetida se queda con el último valor, como al publicar en orden).
List<String> normalizedManifestLines(String text, String section) {
  final lines = const LineSplitter().convert(text);
  final first = manifestSectionIndex(lines, section);
  if (first < 0) return lines;
  if (lines[first].trimRight().endsWith('{}')) lines[first] = '$section:';
  var end = manifestBlockEnd(lines, first);
  var next = lines.indexWhere((l) => isManifestSection(l, section), end);
  while (next >= 0) {
    final nEnd = manifestBlockEnd(lines, next);
    final moved = [
      for (final l in lines.sublist(next + 1, nEnd))
        if (l.trim().isNotEmpty) l
    ];
    lines.removeRange(next, nEnd);
    var at = end;
    while (at > first + 1 && lines[at - 1].trim().isEmpty) {
      at--;
    }
    for (final l in moved) {
      final key = _keyOf(l);
      final k = key == null
          ? -1
          : lines.indexWhere((x) => _keyOf(x) == key, first + 1);
      if (k >= 0 && k < at) {
        lines[k] = l;
      } else {
        lines.insert(at++, l);
      }
    }
    end = manifestBlockEnd(lines, first);
    next = lines.indexWhere((l) => isManifestSection(l, section), end);
  }
  return lines;
}

String? _keyOf(String l) {
  final m = RegExp(r'^  ([^\s#:][^:]*):').firstMatch(l);
  return m?.group(1);
}

/// Suma o corrige `<key>: <value>` bajo `<section>:`. Si ya está igual,
/// devuelve el texto igual (salvo reparar una sección repetida o CRLF).
String upsertManifestEntry(
    String manifest, String section, String key, String value) {
  final lines = normalizedManifestLines(manifest, section);
  final s = manifestSectionIndex(lines, section);
  if (s < 0) {
    final head = lines.join('\n').trimRight();
    return '$head${head.isEmpty ? '' : '\n'}$section:\n  $key: $value\n';
  }
  final end = manifestBlockEnd(lines, s);
  final k = lines.indexWhere((l) => _keyOf(l) == key, s + 1);
  if (k >= 0 && k < end) {
    lines[k] = '  $key: $value';
  } else {
    var at = end;
    while (at > s + 1 && lines[at - 1].trim().isEmpty) {
      at--;
    }
    lines.insert(at, '  $key: $value');
  }
  return '${lines.join('\n')}\n';
}

/// Comentario de cabecera de un YAML (líneas `#` y en blanco del
/// principio, sin la línea en blanco final). Vacío si no hay.
String yamlHeaderComment(String yaml) {
  final out = <String>[];
  for (final l in const LineSplitter().convert(yaml)) {
    if (l.trimLeft().startsWith('#') || l.trim().isEmpty) {
      out.add(l);
    } else {
      break;
    }
  }
  while (out.isNotEmpty && out.last.trim().isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}

/// [yaml] con su cabecera de comentarios reemplazada por [header] (si
/// [header] está vacío, lo deja igual).
String withYamlHeader(String yaml, String header) {
  if (header.trim().isEmpty) return yaml;
  final lines = const LineSplitter().convert(yaml);
  var i = 0;
  while (i < lines.length &&
      (lines[i].trimLeft().startsWith('#') || lines[i].trim().isEmpty)) {
    i++;
  }
  return '$header\n${lines.sublist(i).join('\n')}\n';
}
