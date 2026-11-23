import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/core/i18n/icu_formatter.dart';
import 'package:echos_del_tiempo/core/i18n/locale_id.dart';
import 'package:echos_del_tiempo/core/i18n/string_tables.dart';
import 'package:flutter_test/flutter_test.dart';

/// Consistencia de claves (docs/specs/i18n.md § 6, fase 1): toda clave
/// existe en es-AR, los placeholders coinciden entre idiomas, los
/// mensajes ICU son válidos, los idiomas publicados están completos y
/// toda clave usada en el código existe.
void main() {
  final tables = StringTables.loadDirectorySync(StringTables.assetRoot)!;
  final source = tables.tables[LocaleId.source]!;

  test('hay dominios y cada archivo de dominio existe en cada idioma', () {
    expect(tables.registry.domains, isNotEmpty);
    for (final l in tables.registry.status.keys) {
      for (final d in tables.registry.domains) {
        expect(File(StringTables.path(l, d)).existsSync(), isTrue,
            reason: StringTables.path(l, d));
      }
    }
  });

  test('cada clave de un dominio empieza con el nombre del dominio', () {
    for (final l in tables.registry.status.keys) {
      for (final d in tables.registry.domains) {
        final j = jsonDecode(File(StringTables.path(l, d)).readAsStringSync())
            as Map<String, Object?>;
        for (final k in j.keys) {
          expect(k.startsWith('$d.'), isTrue, reason: '$k en ${l.tag}/$d');
        }
      }
    }
  });

  test('toda clave de otro idioma existe en es-AR', () {
    for (final e in tables.tables.entries) {
      final extra = e.value.keys.where((k) => !source.containsKey(k));
      expect(extra, isEmpty, reason: '${e.key.tag} tiene claves sin fuente');
    }
  });

  test('mensajes ICU válidos y mismos placeholders que la fuente', () {
    for (final e in tables.tables.entries) {
      for (final k in e.value.entries) {
        final text = k.value.text;
        if (text.isEmpty) continue;
        expect(() => IcuFormatter.validate(text), returnsNormally,
            reason: '${e.key.tag} $k');
        final src = source[k.key];
        if (src == null) continue;
        expect(IcuFormatter.argumentNames(text),
            IcuFormatter.argumentNames(src.text),
            reason: '${e.key.tag} ${k.key}');
      }
    }
  });

  test('los idiomas publicados tienen texto revisado para cada clave', () {
    for (final l in tables.registry.selectable()) {
      final t = tables.tables[l]!;
      final missing = [
        for (final k in source.keys)
          if ((t[k]?.text ?? '').isEmpty ||
              t[k]!.status != EntryStatus.reviewed)
            k,
      ];
      expect(missing, isEmpty, reason: '${l.tag}: faltan o no revisadas');
    }
  });

  test('toda clave literal usada en lib/ existe en es-AR', () {
    // Literales con forma de clave de un dominio cargado: 'ui.title.x'.
    final prefixes = tables.registry.domains.map(RegExp.escape).join('|');
    final re = RegExp("'((?:$prefixes)\\.[a-z0-9_.]+)'");
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        if (!source.containsKey(m[1])) missing.add('${f.path}: ${m[1]}');
      }
    }
    expect(missing, isEmpty);
  });

  test('las claves de los layouts existen en es-AR', () {
    final re = RegExp(r'"textKey"\s*:\s*"([^"]+)"');
    for (final f in Directory('assets/layouts').listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      for (final m in re.allMatches(f.readAsStringSync())) {
        expect(source.containsKey(m[1]), isTrue, reason: '${f.path}: ${m[1]}');
      }
    }
  });
}
