import 'semver.dart';

/// De qué releases del repo se actualiza un juego (docs/specs/
/// distribution.md § "Dos juegos, un repo"). El monorepo publica Ecos del
/// Tiempo (tags `vX.Y.Z`, el "latest" del repo) y Ecos del Tiempo:
/// Travesía (tags `travesia-vX.Y.Z`, siempre `--latest=false`). Lo elige
/// el composition root vía `GameEdition`; nadie mira el nombre del flavor.
class ReleaseChannel {
  const ReleaseChannel({
    required this.tagPrefix,
    required this.installerPrefix,
    this.useLatestEndpoint = false,
    this.includePrereleases = false,
  });

  /// Ecos del Tiempo: `releases/latest` y tag `vX.Y.Z` (igual que antes de
  /// separar los juegos).
  static const mundo = ReleaseChannel(
      tagPrefix: 'v',
      installerPrefix: 'ecosdeltiempo-setup-',
      useLatestEndpoint: true);

  /// Ecos del Tiempo: Travesía: lista `/releases`, filtra por prefijo y se
  /// queda con la semver más alta (prereleases incluidos).
  static const travesia = ReleaseChannel(
      tagPrefix: 'travesia-v',
      installerPrefix: 'ecosdeltiempo-travesia-setup-',
      includePrereleases: true);

  static const all = [mundo, travesia];

  /// Prefijo del tag (`v`, `travesia-v`).
  final String tagPrefix;

  /// Prefijo del `.exe` del instalador, en minúsculas.
  final String installerPrefix;

  /// `true`: se consulta `releases/latest` (Mundo). `false`: se lista
  /// `/releases` y se filtra por [tagPrefix].
  final bool useLatestEndpoint;

  /// Si un prerelease cuenta como actualización.
  final bool includePrereleases;

  /// Tag de una versión (`travesia-v0.1.0`).
  String tagFor(String version) => '$tagPrefix$version';

  /// La versión de [tag] si es de este canal, o `null`. El `v` de Mundo
  /// sigue siendo opcional (como siempre aceptó el actualizador), pero un
  /// tag de otro canal nunca cuenta.
  SemVer? versionOf(String tag) {
    for (final other in all) {
      if (!identical(other, this) &&
          other.tagPrefix.length > tagPrefix.length &&
          tag.startsWith(other.tagPrefix)) {
        return null;
      }
    }
    if (useLatestEndpoint) return SemVer.tryParse(tag);
    if (!tag.startsWith(tagPrefix)) return null;
    final rest = tag.substring(tagPrefix.length);
    if (rest.isEmpty || !RegExp(r'^\d').hasMatch(rest)) return null;
    return SemVer.tryParse(rest);
  }
}
