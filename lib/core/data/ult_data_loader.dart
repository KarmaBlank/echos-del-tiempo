import 'package:flutter/services.dart';

import '../../game_engine/data/game_catalog.dart';
import '../../game_engine/data/ults_v2_catalog.dart';
import '../../game_engine/models/enemy_def.dart';
import '../../game_engine/models/ult_def.dart';
import '../../game_engine/serialization/ult_yaml.dart';
import '../persistence/ecos_log.dart';

/// Lo leído de `assets/data/ults/` y `assets/data/enemy_ults/`.
class UltData {
  const UltData(this.players, this.enemies, this.issues);

  static const empty = UltData({}, {}, []);

  final Map<String, UltDef> players;
  final Map<String, EnemyUltDef> enemies;
  final List<String> issues;
}

/// Carga los YAML de las ULT (docs/specs/ultimates_v2.md § 5.1). Nunca
/// lanza: un archivo roto queda en `issues` y esa ULT sigue con la del
/// código (respaldo).
abstract final class UltDataLoader {
  static Future<UltData> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final issues = <String>[];
    final players = <String, UltDef>{};
    final enemies = <String, EnemyUltDef>{};
    Future<void> each(String manifest, String dir, String key,
        void Function(String raw) parse) async {
      Map<String, String> files;
      try {
        files = UltYaml.manifestFromYaml(await b.loadString(manifest), key);
      } on Object catch (e) {
        issues.add('sin $manifest: $e');
        return;
      }
      for (final MapEntry(key: id, value: file) in files.entries) {
        try {
          parse(await b.loadString('$dir$file'));
        } on Object catch (e) {
          issues.add('$id: $e (se usa la del código)');
        }
      }
    }

    await each(UltYaml.playerManifest, UltYaml.playerDir, 'ults', (raw) {
      final u = UltYaml.playerFromYaml(raw);
      players[u.id] = u;
    });
    await each(UltYaml.enemyManifest, UltYaml.enemyDir, 'eults', (raw) {
      final u = UltYaml.enemyFromYaml(raw);
      enemies[u.id] = u;
    });
    return UltData(players, enemies, issues);
  }

  /// Pone los datos encima de [catalog]: las ULT de jugador también en
  /// el registro global (fuente y compatibilidad); solo ids conocidos.
  static GameCatalog install(GameCatalog catalog, UltData? data) {
    final d = data ?? UltData.empty;
    for (final i in d.issues) {
      EcosLog.error('ULT: $i');
    }
    if (d.players.isEmpty && d.enemies.isEmpty) return catalog;
    for (final u in d.players.values) {
      if (!kUltV2.containsKey(u.id)) continue;
      kUltV2[u.id] = u;
      kUltV2Skills[u.id] = u.skill;
    }
    return catalog.withUlts(
      playerUlts: {
        ...catalog.playerUlts,
        for (final u in d.players.values)
          if (catalog.playerUlts.containsKey(u.id)) u.id: u.skill,
      },
      enemyUlts: {
        ...catalog.enemyUlts,
        for (final u in d.enemies.values)
          if (catalog.enemyUlts.containsKey(u.id)) u.id: u,
      },
    );
  }
}
