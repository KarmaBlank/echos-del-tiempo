import 'package:flutter/services.dart';

import '../../game_engine/data/build_templates_catalog.dart';
import '../persistence/ecos_log.dart';

/// Carga las plantillas de BUILD (docs/specs/build_planner_v2.md § 2.2):
/// `assets/data/build_templates.yaml` y, si existe, el archivo del dueño
/// `build_templates_custom.yaml` (gana su id). Nunca lanza: lo inválido
/// queda en el log de desarrollo y el juego sigue.
abstract final class BuildTemplateLoader {
  static Future<void> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final issues = <String>[];
    var game = const <BuildTemplate>[];
    var custom = const <BuildTemplate>[];
    try {
      final f = BuildTemplateYaml.parse(
          await b.loadString(BuildTemplateYaml.assetPath, cache: false));
      game = f.templates;
      issues.addAll(f.issues);
    } on Object catch (e) {
      issues.add('sin ${BuildTemplateYaml.assetPath}: $e');
    }
    try {
      final f = BuildTemplateYaml.parse(await b
          .loadString(BuildTemplateYaml.customAssetPath, cache: false));
      custom = f.templates;
      issues.addAll(f.issues);
    } on Object {
      // Opcional: sin archivo del dueño.
    }
    for (final i in issues) {
      EcosLog.error('Plantillas de BUILD: $i');
    }
    BuildTemplates.install(game, custom: custom, issues: issues);
  }
}
