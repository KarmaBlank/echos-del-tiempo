import 'package:flutter/services.dart';

import '../../game_engine/balance/balance_patch.dart';
import '../../game_engine/balance/balance_registries.dart';
import '../../game_engine/data/game_catalog.dart';
import '../persistence/ecos_log.dart';

/// Carga `assets/balance/balance.json` (docs/specs/balance_admin.md § 3).
/// Nunca lanza: sin archivo, con JSON roto o con entradas inválidas, el
/// juego sigue con lo válido (o con el catálogo del código).
abstract final class BalanceAssetLoader {
  static const assetPath = 'assets/balance/balance.json';

  static Future<BalanceParseResult> load({AssetBundle? bundle}) async {
    try {
      final text =
          await (bundle ?? rootBundle).loadString(assetPath, cache: false);
      return BalancePatch.parse(text, BalanceBase.standard());
    } on Object catch (e) {
      return BalanceParseResult(BalancePatch.empty,
          [BalanceIssue(assetPath, 'no se pudo leer: $e', error: false)]);
    }
  }

  /// Instala los registros globales del parche y devuelve el catálogo
  /// parcheado. Ante cualquier falla, vuelve al código.
  /// [base]: el catálogo de partida (el del código con los datos de las
  /// ULT ya puestos, ultimates_v2.md § 5.1).
  static GameCatalog install(BalanceParseResult? loaded,
      {GameCatalog base = GameCatalog.standard}) {
    final r = loaded ?? const BalanceParseResult(BalancePatch.empty, []);
    for (final i in r.issues) {
      EcosLog.error('Balance: $i');
    }
    if (r.patch.isEmpty) return base;
    try {
      r.patch.installRegistries();
      final catalog = r.patch.applyTo(base);
      EcosLog.info('Balance: parche ${catalog.balanceHash} '
          '(${r.patch.entityCount} entradas)');
      return catalog;
    } on Object catch (e) {
      BalanceRegistries.restore();
      EcosLog.error('Balance: no se pudo aplicar, se usa el código', e);
      return base;
    }
  }
}
