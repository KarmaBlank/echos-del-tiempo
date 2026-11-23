import 'dart:io';
import 'dart:typed_data';

import 'package:echos_del_tiempo/core/i18n/locale_id.dart';
import 'package:echos_del_tiempo/core/i18n/string_tables.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cobertura de glifos (docs/specs/i18n.md § 2 y § 6): cada carácter del
/// texto de un idioma tiene que estar en el `cmap` de las fuentes que lo
/// dibujan. zh-Hans se saltea hasta que entre la fuente CJK
/// (docs/tech_debt.md).
///
/// [knownGaps]: faltantes ya sabidos por fuente (no frenan el test, pero
/// uno nuevo sí). Se achica cuando se arregla la fuente.
const knownGaps = <String, Set<String>>{
  // Símbolos que la UI ya usaba antes de pasar a tablas (flechas del
  // TUTORIAL y del HUD del mundo, ★ del plan, − de las púas, ₵ de
  // créditos; en combate, ▲▼ de buffs, ▸ y ← de los menús).
  'PressStart2P': {'−', '₵', '▸'},
  'VT323': {'★', '→', '↑', '↓', '▲', '▼', '←', '▸', '▶'},
  'AtkinsonHyperlegible': {'★', '→', '₵', '↑', '↓', '▲', '▼', '←', '▸', '▶'},
};

const fonts = {
  'PressStart2P': 'assets/fonts/PressStart2P-Regular.ttf',
  'VT323': 'assets/fonts/VT323-Regular.ttf',
  'AtkinsonHyperlegible': 'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
};

/// Idiomas sin fuente propia todavía: motivo del salto.
const pendingFont = {
  LocaleId.zhHans: 'Sin fuente CJK (Fusion Pixel) todavía: '
      'docs/tech_debt.md § i18n',
};

/// Code points con glifo en un TTF (cmap formatos 4 y 12).
Set<int> cmapOf(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  final numTables = d.getUint16(4);
  int? cmap;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
    if (tag == 'cmap') cmap = d.getUint32(rec + 8);
  }
  if (cmap == null) throw StateError('sin tabla cmap');
  final out = <int>{};
  final n = d.getUint16(cmap + 2);
  for (var i = 0; i < n; i++) {
    final rec = cmap + 4 + i * 8;
    final platform = d.getUint16(rec), encoding = d.getUint16(rec + 2);
    final unicode = platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
    if (!unicode) continue;
    final sub = cmap + d.getUint32(rec + 4);
    final format = d.getUint16(sub);
    if (format == 4) {
      final segX2 = d.getUint16(sub + 6);
      final ends = sub + 14, starts = ends + segX2 + 2;
      final deltas = starts + segX2, ranges = deltas + segX2;
      for (var s = 0; s < segX2 ~/ 2; s++) {
        final end = d.getUint16(ends + s * 2), start = d.getUint16(starts + s * 2);
        final delta = d.getInt16(deltas + s * 2);
        final rangeAt = ranges + s * 2, range = d.getUint16(rangeAt);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          int glyph;
          if (range == 0) {
            glyph = (c + delta) & 0xFFFF;
          } else {
            final g = d.getUint16(rangeAt + range + (c - start) * 2);
            glyph = g == 0 ? 0 : (g + delta) & 0xFFFF;
          }
          if (glyph != 0) out.add(c);
        }
      }
    } else if (format == 12) {
      final groups = d.getUint32(sub + 12);
      for (var g = 0; g < groups; g++) {
        final at = sub + 16 + g * 12;
        final start = d.getUint32(at), end = d.getUint32(at + 4);
        for (var c = start; c <= end; c++) {
          out.add(c);
        }
      }
    }
  }
  return out;
}

void main() {
  final tables = StringTables.loadDirectorySync(StringTables.assetRoot)!;
  final cmaps = {
    for (final f in fonts.entries)
      f.key: cmapOf(File(f.value).readAsBytesSync()),
  };

  test('el lector de cmap ve el latín básico en las tres fuentes', () {
    for (final c in cmaps.entries) {
      expect(c.value.containsAll('AZaz09'.runes), isTrue, reason: c.key);
    }
  });

  for (final locale in LocaleId.values) {
    test('glifos de ${locale.tag} en las fuentes del juego', () {
      final chars = <int>{
        for (final e in tables.tables[locale]?.values ?? const <StringEntry>[])
          ...e.text.runes,
      }..removeWhere((c) => c <= 0x20); // espacios y control
      final problems = <String>[];
      for (final c in cmaps.entries) {
        final gaps = knownGaps[c.key] ?? const {};
        final missing = chars
            .where((r) => !c.value.contains(r))
            .map(String.fromCharCode)
            .where((s) => !gaps.contains(s))
            .toList();
        if (missing.isNotEmpty) problems.add('${c.key}: ${missing.join(' ')}');
      }
      expect(problems, isEmpty);
    }, skip: pendingFont[locale]);
  }
}
