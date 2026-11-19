/// Dónde vive la bandera del TUTORIAL de la cuenta (`tutV`,
/// docs/specs/combat_tutorial.md § 2): la última versión del tutorial que
/// completó la cuenta (0 = nunca). Por cuenta, no por personaje.
/// `game_engine` solo define el contrato; la cuenta real (`account.json`)
/// lo implementa en `features/characters/data`.
abstract interface class TutorialStore {
  Future<int> load();

  Future<void> save(int version);
}

/// En memoria (tests, builds sin carpeta de datos).
class InMemoryTutorialStore implements TutorialStore {
  InMemoryTutorialStore([this.version = 0]);

  int version;
  int saves = 0;

  @override
  Future<int> load() async => version;

  @override
  Future<void> save(int version) async {
    saves++;
    this.version = version;
  }
}
