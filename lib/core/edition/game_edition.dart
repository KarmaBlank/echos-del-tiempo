import '../../app/app_version.dart';
import '../../app/travesia_version.dart';
import '../../game_engine/models/game_mode.dart';
import '../../netcode/protocol/wire.dart';
import '../update/release_channel.dart';

/// Qué juego publicado arma un composition root (docs/specs/
/// distribution.md § "Dos juegos, un repo"). El monorepo da dos juegos
/// instalables uno al lado del otro: cada uno con su versión, su canal de
/// releases, su carpeta de datos y su protocolo de red. Los flavors lo
/// instalan con `registerSharedDependencies(edition:)`; nadie mira el
/// nombre del flavor.
class GameEdition {
  const GameEdition({
    required this.mode,
    required this.title,
    required this.version,
    required this.dataFolder,
    required this.linuxDataFolder,
    required this.releases,
    required this.wire,
  });

  final GameModeKind mode;

  /// Nombre para el jugador.
  final String title;

  /// Versión instalada (`X.Y.Z`), la que compara el actualizador.
  final String version;

  /// Carpeta bajo `%APPDATA%` (y `Application Support` en macOS).
  final String dataFolder;

  /// Carpeta bajo `$XDG_DATA_HOME` / `~/.local/share` en Linux.
  final String linuxDataFolder;

  final ReleaseChannel releases;
  final WireGame wire;

  static const mundo = GameEdition(
    mode: GameModeKind.mundo,
    title: 'Ecos del Tiempo',
    version: appVersion,
    dataFolder: 'EcosDelTiempo',
    linuxDataFolder: 'ecos_del_tiempo',
    releases: ReleaseChannel.mundo,
    wire: WireGame.mundo,
  );

  static const travesia = GameEdition(
    mode: GameModeKind.travesia,
    title: 'Ecos del Tiempo: Travesía',
    version: travesiaVersion,
    dataFolder: 'EcosDelTiempo-Travesia',
    linuxDataFolder: 'ecos_del_tiempo_travesia',
    releases: ReleaseChannel.travesia,
    wire: WireGame.travesia,
  );

  static const all = [mundo, travesia];

  /// La del proceso. Por defecto Mundo (tests y flavors de siempre).
  static GameEdition get current => _current;
  static GameEdition _current = mundo;

  /// Solo los composition roots (vía `registerSharedDependencies`).
  static void install(GameEdition edition) => _current = edition;
}
