import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'release_info.dart';
import 'semver.dart';
import 'sha256.dart';

/// Auto-actualizador: consulta el último release de GitHub, baja el
/// instalador verificando tamaño y SHA-256, y lo lanza en modo silencioso.
/// Solo `dart:io`. Ver docs/specs/distribution.md § "Flujo de
/// actualización".

/// Resultado de buscar actualizaciones.
sealed class UpdateCheck {
  const UpdateCheck();
}

/// No hay nada más nuevo (o todavía no se publicó ningún release).
class UpToDate extends UpdateCheck {
  const UpToDate({required this.current, this.latest});

  final SemVer current;

  /// Último release publicado (`null`: no hay ninguno).
  final SemVer? latest;
}

/// Hay un release con versión mayor a la instalada.
class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable({required this.current, required this.release});

  final SemVer current;
  final ReleaseInfo release;
}

/// No se pudo consultar (sin internet, timeout, límite de GitHub...). El
/// juego sigue normal: nunca es un error bloqueante.
class UpdateCheckFailed extends UpdateCheck {
  const UpdateCheckFailed(this.message);

  /// Texto para el jugador, en castellano.
  final String message;
}

/// Falla al descargar o verificar el instalador.
class UpdateFailure implements Exception {
  const UpdateFailure(this.message);

  final String message;

  @override
  String toString() => 'UpdateFailure: $message';
}

/// Progreso de descarga: bytes recibidos de [total].
typedef DownloadProgress = void Function(int received, int total);

/// Lo que la UI necesita del actualizador (los tests lo reemplazan).
abstract interface class UpdateService {
  /// Versión instalada.
  SemVer get currentVersion;

  /// `false` donde no se puede instalar solo (fuera de Windows): la UI
  /// avisa y ofrece la página del release.
  bool get canInstall;

  Future<UpdateCheck> check();

  /// Baja el instalador de [release] y lo verifica. Lanza [UpdateFailure].
  Future<File> download(ReleaseInfo release, {DownloadProgress? onProgress});

  /// Lanza el instalador en silencio y cierra el juego (el instalador lo
  /// vuelve a abrir al terminar). Lanza [UpdateFailure] si no arranca.
  Future<void> installAndExit(File installer);
}

/// [UpdateService] contra la API pública de GitHub Releases (sin token).
class GitHubUpdateService implements UpdateService {
  GitHubUpdateService({
    required String currentVersion,
    Uri? endpoint,
    HttpClient Function()? httpClient,
    this.checkTimeout = const Duration(seconds: 8),
    this.idleTimeout = const Duration(seconds: 30),
    Directory? downloadDir,
    this.requireChecksum = true,
    void Function(int code)? exitApp,
  })  : currentVersion =
            SemVer.tryParse(currentVersion) ?? const SemVer(0, 0, 0),
        endpoint = endpoint ?? defaultEndpoint,
        _httpClient = httpClient ?? HttpClient.new,
        _downloadDir = downloadDir,
        _exit = exitApp ?? exit;

  /// Repo público del juego.
  static final defaultEndpoint = Uri.parse(
      'https://api.github.com/repos/KarmaBlank/echos-del-tiempo/releases/latest');

  /// Argumentos de Inno Setup para actualizar sin preguntas. `/RELAUNCH`
  /// es propio de installer/ecos_del_tiempo.iss: abre el juego al terminar.
  static const installerArgs = [
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/CLOSEAPPLICATIONS',
    '/RELAUNCH',
  ];

  @override
  final SemVer currentVersion;
  final Uri endpoint;
  final Duration checkTimeout;

  /// Máximo sin recibir bytes durante la descarga.
  final Duration idleTimeout;

  /// Sin `.sha256` en el release, la descarga se rechaza.
  final bool requireChecksum;

  final HttpClient Function() _httpClient;
  final Directory? _downloadDir;
  final void Function(int code) _exit;

  static const _userAgent = 'EcosDelTiempo-Updater';

  @override
  bool get canInstall => Platform.isWindows;

  @override
  Future<UpdateCheck> check() async {
    final client = _httpClient()..connectionTimeout = checkTimeout;
    try {
      return await _check(client).timeout(checkTimeout);
    } on TimeoutException {
      return const UpdateCheckFailed(
          'No se pudo buscar actualizaciones: GitHub tardó demasiado.');
    } on SocketException {
      return const UpdateCheckFailed(
          'No se pudo buscar actualizaciones: sin conexión a internet.');
    } on HandshakeException {
      return const UpdateCheckFailed(
          'No se pudo buscar actualizaciones: conexión segura rechazada.');
    } on HttpException catch (e) {
      return UpdateCheckFailed(
          'No se pudo buscar actualizaciones: ${e.message}.');
    } on FormatException {
      return const UpdateCheckFailed(
          'No se pudo buscar actualizaciones: respuesta inválida de GitHub.');
    } finally {
      client.close(force: true);
    }
  }

  Future<UpdateCheck> _check(HttpClient client) async {
    final req = await client.getUrl(endpoint);
    req.headers
      ..set(HttpHeaders.userAgentHeader, _userAgent)
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set('X-GitHub-Api-Version', '2022-11-28');
    final res = await req.close();
    final body = await utf8.decoder.bind(res).join();
    if (res.statusCode == HttpStatus.notFound) {
      return UpToDate(current: currentVersion);
    }
    if (res.statusCode == HttpStatus.forbidden ||
        res.statusCode == HttpStatus.tooManyRequests) {
      return UpdateCheckFailed(_rateLimitMessage(res.headers));
    }
    if (res.statusCode != HttpStatus.ok) {
      return UpdateCheckFailed(
          'No se pudo buscar actualizaciones (GitHub respondió '
          '${res.statusCode}).');
    }
    final release = ReleaseInfo.tryFromJson(jsonDecode(body));
    if (release == null) {
      return const UpdateCheckFailed(
          'El último release publicado no trae un instalador válido.');
    }
    if (release.version > currentVersion) {
      return UpdateAvailable(current: currentVersion, release: release);
    }
    return UpToDate(current: currentVersion, latest: release.version);
  }

  static String _rateLimitMessage(HttpHeaders h) {
    final reset = int.tryParse(h.value('x-ratelimit-reset') ?? '');
    if (reset == null) {
      return 'GitHub limitó las consultas; probá de nuevo en un rato.';
    }
    final at = DateTime.fromMillisecondsSinceEpoch(reset * 1000).toLocal();
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return 'GitHub limitó las consultas; probá de nuevo después de las '
        '$hh:$mm.';
  }

  @override
  Future<File> download(ReleaseInfo release,
      {DownloadProgress? onProgress}) async {
    final asset = release.installer;
    final name = asset.name;
    if (name.contains(RegExp(r'[\\/:]')) || name.startsWith('.')) {
      throw const UpdateFailure('Nombre de instalador inválido.');
    }
    final dir = _downloadDir ??
        Directory('${Directory.systemTemp.path}${Platform.pathSeparator}'
            'EcosDelTiempo-update');
    await dir.create(recursive: true);
    final target = File('${dir.path}${Platform.pathSeparator}$name');
    final part = File('${target.path}.part');

    final client = _httpClient()..connectionTimeout = checkTimeout;
    try {
      String? expected;
      final checksum = release.checksum;
      if (checksum != null) {
        expected = parseSha256File(await _getText(client, checksum.url));
        if (expected == null) {
          throw const UpdateFailure('El archivo .sha256 del release no sirve.');
        }
      } else if (requireChecksum) {
        throw const UpdateFailure(
            'El release no trae el .sha256 del instalador; '
            'no se puede verificar la descarga.');
      }

      final res = await _get(client, asset.url);
      final hash = Sha256();
      final sink = part.openWrite();
      var received = 0;
      try {
        await for (final chunk in res.timeout(idleTimeout)) {
          received += chunk.length;
          if (received > asset.size) {
            throw const UpdateFailure(
                'La descarga es más grande de lo esperado.');
          }
          hash.add(chunk);
          sink.add(chunk);
          onProgress?.call(received, asset.size);
        }
      } finally {
        await sink.close();
      }
      if (received != asset.size) {
        throw UpdateFailure('Descarga incompleta ($received de '
            '${asset.size} bytes).');
      }
      final actual = hash.close();
      if (expected != null && actual != expected) {
        throw const UpdateFailure(
            'El instalador descargado no coincide con su SHA-256; '
            'se descartó.');
      }
      if (await target.exists()) await target.delete();
      return await part.rename(target.path);
    } on UpdateFailure {
      await _deleteQuietly(part);
      rethrow;
    } on TimeoutException {
      await _deleteQuietly(part);
      throw const UpdateFailure('La descarga se cortó (sin datos por un rato).');
    } on SocketException {
      await _deleteQuietly(part);
      throw const UpdateFailure('Se perdió la conexión durante la descarga.');
    } on HttpException catch (e) {
      await _deleteQuietly(part);
      throw UpdateFailure('Error de descarga: ${e.message}.');
    } on FileSystemException catch (e) {
      await _deleteQuietly(part);
      throw UpdateFailure('No se pudo guardar el instalador: ${e.message}.');
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClientResponse> _get(HttpClient client, Uri url) async {
    final req = await client.getUrl(url).timeout(checkTimeout);
    req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    final res = await req.close().timeout(checkTimeout);
    if (res.statusCode != HttpStatus.ok) {
      await res.drain<void>();
      throw UpdateFailure('GitHub respondió ${res.statusCode} al descargar.');
    }
    return res;
  }

  Future<String> _getText(HttpClient client, Uri url) async {
    final res = await _get(client, url);
    return utf8.decoder.bind(res).join().timeout(idleTimeout);
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // Archivo temporal: si no se puede borrar, lo limpia Windows.
    }
  }

  @override
  Future<void> installAndExit(File installer) async {
    if (!canInstall) {
      throw const UpdateFailure('La actualización automática es solo para '
          'Windows.');
    }
    final log = '${installer.parent.path}${Platform.pathSeparator}'
        'install.log';
    try {
      await Process.start(
        installer.path,
        [...installerArgs, '/LOG=$log'],
        mode: ProcessStartMode.detached,
      );
    } on ProcessException catch (e) {
      throw UpdateFailure('No se pudo abrir el instalador: ${e.message}.');
    }
    // El instalador espera/cierra este proceso (Restart Manager) y abre la
    // versión nueva con `/RELAUNCH`.
    _exit(0);
  }
}
