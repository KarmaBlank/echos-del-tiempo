import 'package:flutter/services.dart';

import '../../game_engine/serialization/climate_data_json.dart';
import '../persistence/ecos_log.dart';

/// Only reader of `assets/data/climate/climate.json`
/// (docs/specs/weather_seasons.md § 8). Never throws: a broken or missing
/// file leaves the code defaults and logs it.
abstract final class ClimateDataLoader {
  static Future<ClimateData?> load({AssetBundle? bundle}) async {
    try {
      final raw =
          await (bundle ?? rootBundle).loadString(ClimateData.assetPath);
      final d = ClimateData.decode(raw);
      for (final id in d.install()) {
        EcosLog.error('Clima: id desconocido "$id" (se ignora)');
      }
      return d;
    } on Object catch (e) {
      ClimateData.restore();
      EcosLog.error('Clima: ${ClimateData.assetPath}: $e (se usa el código)');
      return null;
    }
  }
}
