import 'dart:io';

import 'package:echos_del_tiempo/game_engine/balance/balance_codecs.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/fx/fx_timeline.dart';
import 'package:echos_del_tiempo/game_engine/serialization/ult_yaml.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

// Datos YAML de las ULT (docs/specs/ultimates_v2.md § 5.1) y sus FXA.

void main() {
  test('cada ULT de jugador: YAML == código (ida y vuelta)', () {
    final m = UltYaml.manifestFromYaml(
        File(UltYaml.playerManifest).readAsStringSync(), 'ults');
    expect(m.keys.toSet(), kUltV2.keys.toSet());
    for (final u in kUltV2List) {
      final back = UltYaml.playerFromYaml(
          File('${UltYaml.playerDir}${m[u.id]}').readAsStringSync());
      expect(ultimateCodec.read(back.skill), ultimateCodec.read(u.skill), reason: u.id);
      expect(back.source, u.source);
      expect(back.ref, u.ref);
      expect(back.weapons, u.weapons);
      expect(back.classes, u.classes);
      expect(back.element, u.element);
      // Escribir de nuevo da lo mismo.
      expect(UltYaml.playerToYaml(back), UltYaml.playerToYaml(u));
    }
  });

  test('cada ULT enemiga: YAML == código', () {
    final m = UltYaml.manifestFromYaml(
        File(UltYaml.enemyManifest).readAsStringSync(), 'eults');
    expect(m.keys.toSet(), kEnemyUlts.keys.toSet());
    for (final u in kEnemyUlts.values) {
      final back = UltYaml.enemyFromYaml(
          File('${UltYaml.enemyDir}${m[u.id]}').readAsStringSync());
      expect(enemyUltCodec.read(back), enemyUltCodec.read(u), reason: u.id);
      expect(back.extra, u.extra);
    }
  });

  test('cada ULT nueva tiene FXA propia con ecos y dura ≤ 2600 ms', () {
    final man = loadYaml(File('assets/fx/fx_manifest.yaml').readAsStringSync())
        as YamlMap;
    final fx = man['fx'] as YamlMap;
    final ids = [...kUltV2.keys, ...kEnemyUlts.keys];
    final seen = <String>{};
    for (final id in ids) {
      final rel = fx[id] as String?;
      expect(rel, isNotNull, reason: id);
      final t = FxTimeline.parse(
          File('assets/fx/$rel').readAsStringSync(), fallbackId: id);
      expect(t.id, id);
      expect(t.duration, lessThanOrEqualTo(2600), reason: id);
      expect(t.category, kUltV2.containsKey(id) ? 'ult' : 'enemy_ult');
      expect(t.tracks.any((k) => k.type == 'echo'), isTrue, reason: id);
      expect(t.warnings, isEmpty, reason: '$id: ${t.warnings}');
      // Identidad propia: ninguna repite el cuerpo de otra.
      final body = File('assets/fx/$rel')
          .readAsStringSync()
          .split('\n')
          .skip(4)
          .join('\n');
      expect(seen.add(body), isTrue, reason: '$id repite otra animación');
    }
  });
}
