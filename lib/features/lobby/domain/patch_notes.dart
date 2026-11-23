/// Notas del parche (docs/specs/title_screen.md § 4): versiones de
/// `docs/release_notes/*.md` y un markdown mínimo (encabezados, viñetas,
/// párrafos). Dart puro.
library;

/// Una versión con sus notas en un asset.
class PatchNoteEntry {
  const PatchNoteEntry(this.version, this.asset);

  /// `0.36.0`.
  final String version;
  final String asset;

  List<int> get parts => [for (final p in version.split('.')) int.parse(p)];
}

final _numbered = RegExp(r'^v(\d+)\.(\d+)\.(\d+)\.md$');

/// Las notas de [assets] para la edición: Mundo `vX.Y.Z.md`, Travesía
/// `travesia-vX.Y.Z.md` (con [prefix] = `travesia-`). La más nueva
/// primero (orden semántico). Otros nombres se ignoran.
List<PatchNoteEntry> patchNotesFrom(Iterable<String> assets,
    {String prefix = ''}) {
  final out = <PatchNoteEntry>[];
  for (final a in assets) {
    if (!a.startsWith('docs/release_notes/')) continue;
    final name = a.substring(a.lastIndexOf('/') + 1);
    if (!name.startsWith(prefix)) continue;
    final rest = name.substring(prefix.length);
    // "v0.1.0.md" del Mundo no debe tomar "travesia-v0.1.0.md".
    if (prefix.isEmpty && name.contains('-')) continue;
    final m = _numbered.firstMatch(rest);
    if (m == null) continue;
    out.add(PatchNoteEntry('${m[1]}.${m[2]}.${m[3]}', a));
  }
  out.sort((a, b) {
    final x = a.parts, y = b.parts;
    for (var i = 0; i < 3; i++) {
      if (x[i] != y[i]) return y[i].compareTo(x[i]);
    }
    return 0;
  });
  return out;
}

enum NoteBlockKind { heading, bullet, paragraph }

/// Un bloque del markdown: encabezado (nivel 1-3), viñeta (sangría 0+) o
/// párrafo.
class NoteBlock {
  const NoteBlock(this.kind, this.text, {this.level = 0});
  final NoteBlockKind kind;
  final String text;

  /// Encabezado: 1-3. Viñeta: sangría (0 = primer nivel).
  final int level;

  @override
  String toString() => '${kind.name}($level): $text';
}

final _heading = RegExp(r'^(#{1,6})\s+(.*)$');
final _bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$');

/// `**x**`, `__x__`, `` `x` ``, `[t](url)` → texto plano (sin negrita).
String plainInline(String s) => s
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m[1]!)
    .replaceAll('**', '')
    .replaceAll('__', '')
    .replaceAll('`', '')
    .trim();

/// Markdown de las notas → bloques.
List<NoteBlock> parsePatchNotes(String md) {
  final out = <NoteBlock>[];
  final buf = StringBuffer();
  NoteBlockKind? kind;
  var level = 0;

  void flush() {
    final t = plainInline(buf.toString());
    if (kind != null && t.isNotEmpty) {
      out.add(NoteBlock(kind!, t, level: level));
    }
    buf.clear();
    kind = null;
  }

  for (var line in md.replaceAll('\r', '').split('\n')) {
    line = line.replaceAll('﻿', '');
    if (line.trim().isEmpty) {
      flush();
      continue;
    }
    final h = _heading.firstMatch(line);
    if (h != null) {
      flush();
      kind = NoteBlockKind.heading;
      level = h[1]!.length.clamp(1, 3);
      buf.write(h[2]);
      flush();
      continue;
    }
    final b = _bullet.firstMatch(line);
    if (b != null) {
      flush();
      kind = NoteBlockKind.bullet;
      level = (b[1]!.replaceAll('\t', '  ').length / 2).floor();
      buf.write(b[2]);
      continue;
    }
    // Continuación de la viñeta / párrafo abierto.
    if (kind == null) {
      kind = NoteBlockKind.paragraph;
      level = 0;
    } else {
      buf.write(' ');
    }
    buf.write(line.trim());
  }
  flush();
  return out;
}
