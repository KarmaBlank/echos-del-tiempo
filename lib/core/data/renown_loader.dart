import 'dart:convert';

import 'package:flutter/services.dart';

import '../../game_engine/data/renown_catalog.dart';
import '../persistence/ecos_log.dart';

/// Single reader of `assets/data/renown/renown.json`
/// (docs/specs/renown_town_growth.md § 7). Never throws: a broken or
/// missing file keeps the code defaults and logs.
abstract final class RenownLoader {
  static Future<RenownConfig?> load({AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(RenownConfig.assetPath);
      final cfg = RenownConfig.fromJson(jsonDecode(raw));
      kRenown = cfg;
      return cfg;
    } on Object catch (e) {
      kRenown = kRenownDefaults;
      EcosLog.error(
          'Renombre: ${RenownConfig.assetPath}: $e (se usan los del código)');
      return null;
    }
  }
}
