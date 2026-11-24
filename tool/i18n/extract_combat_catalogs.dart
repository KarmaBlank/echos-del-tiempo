// Dumps the es-AR source text of the combat catalogs (classes, skills,
// ults, passives, elements) into `assets/i18n/es-AR/data.*.json`
// (docs/specs/i18n.md § 3.4). Run from the repo root:
// `dart run tool/i18n/extract_combat_catalogs.dart`.
// Existing en / zh-Hans entries are kept; new keys are added empty.
import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/game_engine/catalog_text_keys.dart';

void main() {
  final src = sourceCatalogTexts();
  final byDomain = <String, Map<String, String>>{};
  src.forEach((k, v) {
    final d = k.split('.').take(2).join('.');
    (byDomain[d] ??= {})[k] = v;
  });
  const enc = JsonEncoder.withIndent('  ');
  for (final d in byDomain.keys) {
    final f0 = File('assets/i18n/es-AR/$d.json');
    // Keys added by hand (not from the catalogs) stay.
    final prev = f0.existsSync()
        ? (jsonDecode(f0.readAsStringSync()) as Map).cast<String, Object?>()
        : <String, Object?>{};
    final merged = <String, Object?>{...prev, ...byDomain[d]!};
    final es = Map.fromEntries(
        merged.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    f0.writeAsStringSync('${enc.convert(es)}\n');
    for (final tag in ['en', 'zh-Hans']) {
      final f = File('assets/i18n/$tag/$d.json');
      final old = f.existsSync()
          ? (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>()
          : <String, Object?>{};
      final out = {for (final k in es.keys) k: old[k] ?? ''};
      f.writeAsStringSync('${enc.convert(out)}\n');
    }
    stdout.writeln('$d: ${es.length}');
  }
}
