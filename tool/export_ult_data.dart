// Escribe los YAML de las ULT (docs/specs/ultimates_v2.md § 5.1) desde
// el catálogo del código: `assets/data/ults/` (50 de jugador) y
// `assets/data/enemy_ults/` (jefes, élites y Furia Élite).
//
//   dart run tool/export_ult_data.dart
//
// El catálogo de Dart es el respaldo; los YAML son lo que se edita. El
// test `test/game_engine/ult_data_test.dart` comprueba que coincidan.
import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/serialization/ult_yaml.dart';

void main() {
  final players = <String, String>{};
  Directory(UltYaml.playerDir).createSync(recursive: true);
  for (final u in kUltV2List) {
    final file = '${u.id}.ult.yaml';
    File('${UltYaml.playerDir}$file')
        .writeAsStringSync(UltYaml.playerToYaml(u));
    players[u.id] = file;
  }
  File(UltYaml.playerManifest)
      .writeAsStringSync(UltYaml.manifestToYaml('ults', players));

  final enemies = <String, String>{};
  Directory(UltYaml.enemyDir).createSync(recursive: true);
  for (final u in kEnemyUlts.values) {
    final boss = kEnemies.values.where((e) => e.ultId == u.id).firstOrNull;
    final elite = kEnemies.values.where((e) => e.eliteUltId == u.id).firstOrNull;
    final file = '${u.id}.eult.yaml';
    File('${UltYaml.enemyDir}$file').writeAsStringSync(UltYaml.enemyToYaml(u,
        owner: (boss ?? elite)?.id, elite: elite != null || u.id == kEliteUltId));
    enemies[u.id] = file;
  }
  File(UltYaml.enemyManifest)
      .writeAsStringSync(UltYaml.manifestToYaml('eults', enemies));
  stdout.writeln('${players.length} ULT de jugador, ${enemies.length} enemigas.');
}
