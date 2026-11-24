import 'dart:convert';

import 'package:flutter/services.dart';

import '../../game_engine/data/world_events_catalog.dart';
import '../persistence/ecos_log.dart';

/// Single reader of `assets/data/events/world_events.json`
/// (docs/specs/world_events.md § 7). Never throws: a broken or missing
/// file keeps the code defaults and logs.
abstract final class WorldEventsLoader {
  static Future<WorldEventsConfig?> load({AssetBundle? bundle}) async {
    try {
      final raw =
          await (bundle ?? rootBundle).loadString(WorldEventsConfig.assetPath);
      final cfg = WorldEventsConfig.fromJson(jsonDecode(raw));
      kWorldEvents = cfg;
      return cfg;
    } on Object catch (e) {
      kWorldEvents = kWorldEventsDefaults;
      EcosLog.error(
          'Eventos: ${WorldEventsConfig.assetPath}: $e (se usan los del código)');
      return null;
    }
  }
}
