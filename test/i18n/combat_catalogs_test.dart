import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/core/i18n/battle_log_text.dart';
import 'package:echos_del_tiempo/core/i18n/locale_id.dart';
import 'package:echos_del_tiempo/core/i18n/string_tables.dart';
import 'package:echos_del_tiempo/game_engine/catalog_text_keys.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_log.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 3 (docs/specs/i18n.md § 3.4 and § 3.5): the es-AR combat
/// catalogs match the engine, and every battle log key exists.
void main() {
  Map<String, String> read(String loc, String domain) =>
      Map<String, String>.from(
          jsonDecode(File('assets/i18n/$loc/$domain.json').readAsStringSync())
              as Map);

  const domains = [
    'data.classes',
    'data.skills',
    'data.ults',
    'data.passives',
    'data.elements',
  ];

  test('es-AR combat catalogs == engine texts (run the extractor)', () {
    final engine = sourceCatalogTexts();
    final disk = {for (final d in domains) ...read('es-AR', d)};
    expect(disk, engine,
        reason: 'dart run tool/i18n/extract_combat_catalogs.dart');
  });

  test('every ui.battle_log key the engine uses exists', () {
    final es = read('es-AR', 'ui.battle_log');
    final used = <String>{};
    for (final f in [
      'battle_engine.dart',
      'battle_engine_abyss.dart',
      'battle_engine_summons.dart',
    ]) {
      final src = File('lib/game_engine/rules/$f').readAsStringSync();
      for (final m in RegExp(r"_l\(\s*'([A-Za-z0-9_.]+)'").allMatches(src)) {
        used.add('ui.battle_log.${m.group(1)}');
      }
      for (final m in RegExp(
              r"\?\s*'([a-z][A-Za-z0-9_.]*)'\s*:\s*'([a-z][A-Za-z0-9_.]*)'")
          .allMatches(src)) {
        for (final k in [m.group(1)!, m.group(2)!]) {
          if (k.contains('_') || k.contains('.')) {
            used.add('ui.battle_log.$k');
          }
        }
      }
    }
    expect(used.difference(es.keys.toSet()), isEmpty);
  });

  test('a log line formats in es-AR and en, and round-trips JSON', () {
    final tables = StringTables.loadDirectorySync(StringTables.assetRoot)!;
    final line = LogLine.join([
      const LogLine('ui.battle_log.break', {'a': 'Limo'}),
      LogLine.skill('abanico', 'X'),
    ]);
    final back = LogLine.fromJson(jsonDecode(jsonEncode(line.toJson())));
    expect(back, line);
    final es = battleLogText(line, strings: tables.strings(LocaleId.source));
    expect(es, contains('¡QUIEBRE! Limo'));
    final en = battleLogText(line, strings: tables.strings(LocaleId.en));
    expect(en, contains('BREAK! Limo'));
    expect(en, contains('Dagger Fan'));
  });
}
