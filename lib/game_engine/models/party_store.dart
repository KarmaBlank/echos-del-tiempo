import 'build_wants.dart';
import 'player_profile.dart';

/// Un compañero de la party guardado en la cuenta (docs/specs/
/// solo_party.md § 5): su ranura, su perfil, si tiene AUTO y el resumen
/// de su plan de build (para la condición `Build` de su filtro).
class CompanionSlot {
  const CompanionSlot({
    required this.slotId,
    required this.profile,
    this.auto = false,
    this.wants,
  });

  final String slotId;
  final PlayerProfile profile;
  final bool auto;
  final BuildWants? wants;
}

/// Dónde se guardan los compañeros de la party del jugador solo. Como
/// `ProfileStore`, `game_engine` solo define el contrato; la cuenta real
/// vive en `features/characters/data` (`AccountPartyStore`).
abstract interface class PartyStore {
  /// Los compañeros de la party del personaje elegido, en orden (vacío =
  /// sin party).
  Future<List<CompanionSlot>> load();

  /// Guarda el perfil del compañero de la ranura [slotId] (nunca la del
  /// líder).
  Future<void> save(String slotId, PlayerProfile profile);

  /// Cambia la party (ids de ranura, en orden; se sanea).
  Future<void> setCompanions(List<String> slotIds);

  /// Prende o apaga el AUTO de [slotId] (se recuerda).
  Future<void> setAuto(String slotId, bool auto);
}

/// En memoria (tests). [slots] son todas las ranuras disponibles (como
/// los demás personajes de la cuenta); [party] los que van.
class InMemoryPartyStore implements PartyStore {
  InMemoryPartyStore({
    Map<String, PlayerProfile>? slots,
    List<String> party = const [],
    Set<String> auto = const {},
    this.maxCompanions = 3,
  })  : _slots = {
          for (final e in (slots ?? const {}).entries) e.key: e.value.toJson()
        },
        _party = [...party],
        _auto = {...auto};

  final int maxCompanions;
  final Map<String, Map<String, Object?>> _slots;
  List<String> _party;
  final Set<String> _auto;

  /// Guardados por ranura (tests).
  final saves = <String, int>{};

  /// Falla la próxima escritura (tests de guardado).
  bool failNext = false;

  List<String> get party => List.unmodifiable(_party);
  Set<String> get auto => Set.unmodifiable(_auto);

  PlayerProfile? profileOf(String slotId) {
    final j = _slots[slotId];
    return j == null ? null : PlayerProfile.fromJson(j);
  }

  @override
  Future<List<CompanionSlot>> load() async => [
        for (final id in _party)
          if (_slots[id] case final j?)
            CompanionSlot(
                slotId: id,
                profile: PlayerProfile.fromJson(j),
                auto: _auto.contains(id)),
      ];

  @override
  Future<void> save(String slotId, PlayerProfile profile) async {
    if (failNext) {
      failNext = false;
      throw StateError('disco lleno');
    }
    _slots[slotId] = profile.toJson();
    saves[slotId] = (saves[slotId] ?? 0) + 1;
  }

  @override
  Future<void> setCompanions(List<String> slotIds) async {
    final out = <String>[];
    for (final id in slotIds) {
      if (_slots.containsKey(id) && !out.contains(id)) out.add(id);
    }
    _party = out.take(maxCompanions).toList();
  }

  @override
  Future<void> setAuto(String slotId, bool auto) async {
    if (auto) {
      _auto.add(slotId);
    } else {
      _auto.remove(slotId);
    }
  }
}
