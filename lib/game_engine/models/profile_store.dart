import 'player_profile.dart';

/// Dónde se guarda el perfil local (`loadProfile` / `saveProfile` del
/// prototipo). `game_engine` solo define el contrato: la implementación
/// real (disco, `shared_preferences`, nube) vive fuera, en `features/*/data`.
abstract interface class ProfileStore {
  /// El perfil guardado, o `null` si no hay ninguno (o está corrupto).
  /// Quien lo usa debe pasarlo por `ProgressionRules.normalize`.
  Future<PlayerProfile?> load();

  Future<void> save(PlayerProfile profile);
}

/// Implementación en memoria (tests, demo sin persistencia). Guarda el
/// JSON, así también prueba la ida y vuelta.
class InMemoryProfileStore implements ProfileStore {
  InMemoryProfileStore([PlayerProfile? initial]) : _json = initial?.toJson();

  Map<String, Object?>? _json;

  @override
  Future<PlayerProfile?> load() async =>
      _json == null ? null : PlayerProfile.fromJson(_json!);

  @override
  Future<void> save(PlayerProfile profile) async => _json = profile.toJson();
}

/// Lee de [inner] y nunca escribe (personaje descartable de la Travesía;
/// docs/specs/roguelike.md § 8.5).
class ReadOnlyProfileStore implements ProfileStore {
  const ReadOnlyProfileStore(this.inner);
  final ProfileStore inner;

  @override
  Future<PlayerProfile?> load() => inner.load();

  @override
  Future<void> save(PlayerProfile profile) async {}
}
