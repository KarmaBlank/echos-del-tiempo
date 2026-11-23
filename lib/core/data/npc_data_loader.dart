import 'package:flutter/services.dart';

import '../../game_engine/serialization/npc_data_json.dart';
import '../persistence/ecos_log.dart';

/// Lector único de `assets/data/npcs/npcs.json` (docs/specs/npc_editor.md
/// § 1). Nunca lanza: archivo roto o ausente = quedan los textos del
/// código (respaldo) y se loguea.
abstract final class NpcDataLoader {
  static Future<NpcData?> load({AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(NpcData.assetPath);
      final d = NpcData.decode(raw);
      for (final id in d.install()) {
        EcosLog.error('NPC: id desconocido "$id" (se ignora)');
      }
      return d;
    } on Object catch (e) {
      NpcData.restore();
      EcosLog.error('NPC: ${NpcData.assetPath}: $e (se usan los del código)');
      return null;
    }
  }
}
