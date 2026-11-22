import '../serialization/json_read.dart';
import '../serialization/run_json.dart';
import 'player_profile.dart';
import 'run_state.dart';

/// Un jugador de la run guardada (docs/specs/roguelike.md § 8.5). Se
/// reconoce al volver por nombre y clase (los ids de red cambian).
class RunSavePlayer {
  const RunSavePlayer({
    required this.profile,
    required this.hp,
    required this.mp,
    this.ult = 0,
    this.boons = const [],
    this.loadout = const [],
  });

  final PlayerProfile profile;
  final double hp;
  final double mp;
  final double ult;
  final List<String> boons;
  final List<String> loadout;

  String get key => keyOf(profile);

  static String keyOf(PlayerProfile p) => '${p.name}|${p.classId}';

  Json toJson() => {
        'p': profile.toJson(),
        'hp': hp,
        'mp': mp,
        'u': ult,
        if (boons.isNotEmpty) 'b': boons,
        if (loadout.isNotEmpty) 'l': loadout,
      };

  static RunSavePlayer fromJson(Json j) => RunSavePlayer(
        profile: PlayerProfile.fromJson(asJson(j['p'])),
        hp: (j['hp'] as num).toDouble(),
        mp: (j['mp'] as num).toDouble(),
        ult: (j['u'] as num?)?.toDouble() ?? 0,
        boons: j['b'] == null ? const [] : j.strings('b'),
        loadout: j['l'] == null ? const [] : j.strings('l'),
      );
}

/// La run en curso guardada al entrar a cada nodo y al volver al mapa
/// (§ 8.5). La guarda el anfitrión; el mapa sale de la semilla.
class RunSave {
  const RunSave({required this.run, required this.players});

  static const version = 1;

  final RunState run;

  /// En orden de la sala (el anfitrión primero).
  final List<RunSavePlayer> players;

  Json toJson() => {
        'v': version,
        'run': RunJson.toJson(run),
        'players': [for (final p in players) p.toJson()],
      };

  /// `null` si el archivo no es de esta versión o está roto.
  static RunSave? tryParse(Object? raw) {
    try {
      final j = asJson(raw);
      if (j['v'] != version) return null;
      return RunSave(
        run: RunJson.fromJson(asJson(j['run'])),
        players: [
          for (final p in j.list('players')) RunSavePlayer.fromJson(asJson(p)),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

/// Dónde se guarda la run (la Travesía: `travesia_run.json` en su carpeta;
/// tests: en memoria).
abstract interface class RunSaveStore {
  Future<RunSave?> load();
  Future<void> save(RunSave save);
  Future<void> clear();
}

class InMemoryRunSaveStore implements RunSaveStore {
  InMemoryRunSaveStore([this.value]);
  RunSave? value;

  @override
  Future<RunSave?> load() async => value;

  @override
  Future<void> save(RunSave save) async => value = save;

  @override
  Future<void> clear() async => value = null;
}
