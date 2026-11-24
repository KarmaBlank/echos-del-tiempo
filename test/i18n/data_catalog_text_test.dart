import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/core/i18n/data_text.dart';
import 'package:echos_del_tiempo/core/i18n/locale_id.dart';
import 'package:echos_del_tiempo/core/i18n/string_tables.dart';
import 'package:echos_del_tiempo/game_engine/data/achievements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/missions_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/zones_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:flutter_test/flutter_test.dart';

/// The es-AR tables of the data domains mirror the catalogs
/// (docs/specs/i18n.md § 3.4). `I18N_DUMP_DATA=1` rewrites them.
Map<String, Map<String, String>> catalogText() {
  final d = <String, Map<String, String>>{
    'data.zones': {},
    'data.missions': {},
    'data.enemies': {},
    'data.achievements': {},
  };
  for (final z in kZones) {
    d['data.zones']![DataKeys.zoneName(z.id)] = z.name;
  }
  for (final m in [...kZoneMissions, ...kPrototypeMissions]) {
    d['data.missions']![DataKeys.missionName(m.id)] = m.name;
    d['data.missions']![DataKeys.missionType(m.type)] = m.type;
  }
  for (final e in kEnemies.values) {
    d['data.enemies']![DataKeys.enemyName(e.id)] = e.name;
    final t = e.title;
    if (t != null && t.isNotEmpty) {
      d['data.enemies']![DataKeys.enemyTitle(e.id)] = t;
    }
  }
  for (final m in kBossMechanics.values) {
    d['data.enemies']![DataKeys.mechanicName(m.id)] = m.name;
    d['data.enemies']![DataKeys.mechanicCounter(m.id)] = m.counter;
  }
  for (final c in AchievementCategory.values) {
    d['data.achievements']![DataKeys.achievementCategory(c.name)] = c.label;
  }
  for (final a in kAchievements) {
    d['data.achievements']![DataKeys.achievementName(a.id)] = a.name;
    d['data.achievements']![DataKeys.achievementHow(a.id)] = a.how;
  }
  return d;
}

void main() {
  final want = catalogText();
  if (Platform.environment['I18N_DUMP_DATA'] == '1') {
    const enc = JsonEncoder.withIndent('  ');
    for (final e in want.entries) {
      File(StringTables.path(LocaleId.source, e.key))
          .writeAsStringSync('${enc.convert(e.value)}\n');
    }
  }

  test('es-AR data tables mirror the catalogs', () {
    final tables = StringTables.loadDirectorySync(StringTables.assetRoot)!;
    final src = tables.tables[LocaleId.source]!;
    for (final dom in want.values) {
      for (final e in dom.entries) {
        expect(src[e.key]?.text, e.value, reason: e.key);
      }
    }
  });
}
