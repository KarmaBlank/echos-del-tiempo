import 'release_channel.dart';
import 'semver.dart';

/// Un archivo adjunto a un release de GitHub.
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, required this.size});

  final String name;

  /// `browser_download_url` (redirige a la CDN de GitHub).
  final Uri url;

  /// Bytes según GitHub; la descarga tiene que medir exactamente esto.
  final int size;

  static ReleaseAsset? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final url = json['browser_download_url'];
    final size = json['size'];
    if (name is! String || url is! String || size is! int || size < 0) {
      return null;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !_allowedUrl(uri)) return null;
    return ReleaseAsset(name: name, url: uri, size: size);
  }

  /// Solo `https` (o `http` a la propia máquina, para los tests).
  static bool _allowedUrl(Uri u) =>
      u.scheme == 'https' ||
      (u.scheme == 'http' && const {'127.0.0.1', 'localhost'}.contains(u.host));
}

/// Lo que importa de `GET /repos/{owner}/{repo}/releases/latest`. Ver
/// docs/specs/distribution.md § "Flujo de actualización".
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.version,
    required this.notes,
    required this.installer,
    this.checksum,
    this.pageUrl,
  });

  /// Tag tal cual (`v0.2.0`).
  final String tag;
  final SemVer version;

  /// Cuerpo del release (markdown crudo; se muestra como texto plano).
  final String notes;

  /// El instalador `EcosDelTiempo-Setup-<versión>.exe`.
  final ReleaseAsset installer;

  /// `<instalador>.sha256`, si el release lo trae.
  final ReleaseAsset? checksum;

  /// Página web del release (`html_url`), para bajarlo a mano.
  final Uri? pageUrl;

  /// Prefijo del instalador que sube tool/release.ps1.
  static const installerPrefix = 'ecosdeltiempo-setup-';

  /// Parsea el JSON de la API. Devuelve `null` si no sirve como
  /// actualización: borrador, tag que no es `vX.Y.Z`, o sin instalador.
  /// Nunca lanza con JSON inesperado.
  /// [channel] decide qué tags valen y el prefijo del instalador.
  static ReleaseInfo? tryFromJson(Object? json,
      {ReleaseChannel channel = ReleaseChannel.mundo}) {
    if (json is! Map) return null;
    if (json['draft'] == true) return null;
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final version = channel.versionOf(tag);
    if (version == null) return null;
    final rawAssets = json['assets'];
    final assets = rawAssets is List
        ? rawAssets.map(ReleaseAsset.tryFromJson).whereType<ReleaseAsset>().toList()
        : const <ReleaseAsset>[];
    final installer =
        pickInstaller(assets, version, prefix: channel.installerPrefix);
    if (installer == null) return null;
    final body = json['body'];
    final html = json['html_url'];
    return ReleaseInfo(
      tag: tag,
      version: version,
      notes: body is String ? stripScreenshots(body) : '',
      installer: installer,
      checksum: pickChecksum(assets, installer),
      pageUrl: html is String ? Uri.tryParse(html) : null,
    );
  }

  /// El `.exe` del instalador: nombre `EcosDelTiempo-Setup-*.exe` (sin
  /// importar mayúsculas). Si hay varios, el que nombra esta versión.
  static ReleaseAsset? pickInstaller(List<ReleaseAsset> assets, SemVer v,
      {String prefix = installerPrefix}) {
    final candidates = assets.where((a) {
      final n = a.name.toLowerCase();
      return n.startsWith(prefix) && n.endsWith('.exe') && a.size > 0;
    }).toList();
    if (candidates.isEmpty) return null;
    final exact =
        candidates.where((a) => a.name.toLowerCase() == '$prefix$v.exe');
    return exact.isNotEmpty ? exact.first : candidates.first;
  }

  /// `<nombre del instalador>.sha256`.
  /// Marca que tool/release.ps1 pone antes de la sección de capturas de
  /// las notas (docs/specs/distribution.md § "Capturas en el release").
  static const screenshotsMarker = '<!-- capturas -->';

  /// Las notas sin la sección de capturas: en el juego no se ven imágenes.
  static String stripScreenshots(String body) {
    final i = body.indexOf(screenshotsMarker);
    return (i < 0 ? body : body.substring(0, i)).trim();
  }

  static ReleaseAsset? pickChecksum(
      List<ReleaseAsset> assets, ReleaseAsset installer) {
    final want = '${installer.name}.sha256'.toLowerCase();
    for (final a in assets) {
      if (a.name.toLowerCase() == want) return a;
    }
    return null;
  }
}
