import 'dart:io';

import 'package:echos_del_tiempo/game_engine/data/build_templates_catalog.dart';

/// Carga `assets/data/build_templates.yaml` en el registro (los tests
/// corren con el directorio del proyecto como actual). Idempotente.
List<BuildTemplate> installBuildTemplates() {
  final raw = File(BuildTemplateYaml.assetPath).readAsStringSync();
  final f = BuildTemplateYaml.parse(raw);
  BuildTemplates.install(f.templates, issues: f.issues);
  return f.templates;
}
