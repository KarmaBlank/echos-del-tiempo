import 'dart:typed_data';

/// Fuente de overrides locales de sonido (`overrides/sfx/<id>.wav|ogg`,
/// docs/specs/game_editor.md § 7.6). Solo el Editor y `main_dev`.
abstract class SfxOverrideSource {
  Set<String> get overriddenSfx;
  Future<Uint8List?> readSfx(String id);
  Future<void> refreshSfx();
}

/// Overrides de sonido que el Editor puede escribir.
abstract class EditableSfxOverrides implements SfxOverrideSource {
  /// Guarda [bytes] (WAV u OGG) como el sonido [id].
  Future<void> putSfx(String id, Uint8List bytes);
  Future<void> removeSfx(String id);

  /// "Publicar al repo": copia cada override a `assets/sfx/`, suma la
  /// entrada en `sfx_manifest.yaml` y borra el override. Devuelve los ids.
  Future<List<String>> publishSfx(String repoRoot);
}
