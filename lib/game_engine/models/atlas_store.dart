import 'atlas.dart';

/// Dónde vive el Atlas del Tiempo de la cuenta (docs/specs/ecos_atlas.md
/// § 5). `game_engine` solo define el contrato; la cuenta real
/// (`account.json`) lo implementa en `features/characters/data`.
abstract interface class AtlasStore {
  /// El Atlas guardado (vacío si no hay).
  Future<AtlasProgress> load();

  Future<void> save(AtlasProgress atlas);
}

/// En memoria (tests, builds sin carpeta de datos). Guarda el JSON para
/// probar también la ida y vuelta.
class InMemoryAtlasStore implements AtlasStore {
  InMemoryAtlasStore([AtlasProgress? initial]) : _json = initial?.toJson();

  Map<String, Object?>? _json;
  int saves = 0;

  @override
  Future<AtlasProgress> load() async =>
      _json == null ? AtlasProgress() : AtlasProgress.fromJson(_json);

  @override
  Future<void> save(AtlasProgress atlas) async {
    saves++;
    _json = atlas.toJson();
  }
}
