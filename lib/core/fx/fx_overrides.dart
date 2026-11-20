/// Fuente de overrides locales de fx (`overrides/fx/<id>.fx.yaml`,
/// docs/specs/game_editor.md § 4.2). Solo el Editor y `main_dev`. Dart
/// puro.
abstract class FxOverrideSource {
  Set<String> get overriddenFx;
  Future<String?> readFx(String id);
  Future<void> refreshFx();
}

/// Overrides de fx que el Editor puede escribir.
abstract class EditableFxOverrides implements FxOverrideSource {
  Future<void> putFx(String id, String yaml);
  Future<void> removeFx(String id);

  /// "Publicar al repo": copia cada override de [paths] (id → ruta dentro
  /// de `assets/fx/`) al repo, suma la entrada que falte en
  /// `fx_manifest.yaml` y borra el override. Devuelve los ids publicados.
  Future<List<String>> publishFx(String repoRoot, Map<String, String> paths);
}
