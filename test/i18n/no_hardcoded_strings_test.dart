import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lint de textos fijos (docs/specs/i18n.md § 6, fase 1): cuenta, por
/// archivo, los literales con letras que van directo a la pantalla
/// (`Text('…')`, `DsButton('…')`, `tooltip: '…'`, `label: '…'`…) en
/// `lib/features/**/presentation` y `lib/game_engine/data`. Ningún archivo
/// puede superar su cuenta en [baselineFile]: el texto nuevo va con clave
/// (`ref.t('ui.…')`). La línea base solo baja: con
/// `I18N_UPDATE_BASELINE=1` se reescribe con el mínimo entre la cuenta
/// vieja y la actual (y no se escribe si algún archivo subió).
const baselineFile = 'test/i18n/hardcoded_strings_baseline.json';

final _scanRoots = [
  (dir: 'lib/features', mustContain: '${Platform.pathSeparator}presentation'),
  (dir: 'lib/game_engine/data', mustContain: ''),
];

/// Un literal (comillas simples o dobles, sin interpolar comillas) con al
/// menos una letra, justo después de un constructor o parámetro de texto.
final _pattern = RegExp(
  r'''(?:\b(?:Text|DsButton|DsTab|DsBadge|DsSectionHeader|retroText|ProtoText|SelectableText)\(\s*|\b(?:tooltip|label|labelText|title|hint|hintText|message|subtitle|text|name|desc|description)\s*:\s*)r?(?:'[^'\n]*[A-Za-zÁÉÍÓÚÜÑáéíóúüñ¿¡][^'\n]*'|"[^"\n]*[A-Za-zÁÉÍÓÚÜÑáéíóúüñ¿¡][^"\n]*")''',
);

Map<String, int> scanCounts() {
  final counts = <String, int>{};
  for (final root in _scanRoots) {
    final dir = Directory(root.dir);
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (!f.path.contains(root.mustContain)) continue;
      final n = _pattern.allMatches(f.readAsStringSync()).length;
      if (n > 0) counts[f.path.replaceAll(r'\', '/')] = n;
    }
  }
  return counts;
}

void main() {
  test('no hay textos fijos nuevos para el jugador (línea base que baja)', () {
    final current = scanCounts();
    final file = File(baselineFile);
    final baseline = file.existsSync()
        ? (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)
            .map((k, v) => MapEntry(k, v as int))
        : <String, int>{};
    final grew = <String>[
      for (final e in current.entries)
        if (e.value > (baseline[e.key] ?? 0))
          '${e.key}: ${baseline[e.key] ?? 0} → ${e.value}',
    ];
    // Sin línea base (primera vez) se genera; si ya hay, solo se reescribe
    // cuando nada subió, así que cada cuenta nueva es <= la vieja.
    final update = Platform.environment['I18N_UPDATE_BASELINE'] == '1';
    if (update && (grew.isEmpty || baseline.isEmpty)) {
      final sorted = Map.fromEntries(
          current.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      grew.clear();
      file.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
    }
    expect(grew, isEmpty,
        reason: 'Textos fijos nuevos: usá una clave de assets/i18n '
            '(docs/specs/i18n.md § 3) en vez de un literal.');
  });

  test('el patrón detecta los casos típicos y no los ids', () {
    int n(String s) => _pattern.allMatches(s).length;
    expect(n("Text('Hola')"), 1);
    expect(n("DsButton('JUGAR', key: k)"), 1);
    expect(n("tooltip: 'Máximo 4'"), 1);
    expect(n('label: "¿Seguro?"'), 1);
    expect(n("Text(ref.t('ui.title.play'))"), 0);
    expect(n("label: '42'"), 0);
    expect(n("key: ValueKey('title-start')"), 0);
  });
}
