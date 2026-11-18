/// Respuesta HTTP mínima.
class HostResponse {
  const HostResponse(this.status, this.body);
  final int status;
  final String body;
  bool get ok => status >= 200 && status < 300;
}

/// Lo que el admin necesita de la plataforma (disco, red, procesos). En
/// escritorio es `dart:io`; en web, un stub sin disco ni procesos
/// (docs/specs/balance_admin.md § 5). Así el dominio y la UI no importan
/// `dart:io`.
abstract class AdminHost {
  /// Hay disco (leer/escribir el repo, leer `ecos.log`).
  bool get supportsFiles;

  /// Se pueden correr procesos (`tool/release.ps1`).
  bool get supportsProcesses;

  /// El repo detectado: el directorio actual si es este proyecto, o
  /// `--dart-define=ECOS_REPO=<ruta>`.
  String? get defaultRepoPath;

  /// `%APPDATA%\EcosDelTiempo\ecos.log` (solo lectura).
  String? get gameLogPath;

  /// `null` si no existe.
  Future<String?> readFile(String path);

  /// Escribe (crea carpetas). Nunca dentro de la carpeta de datos del
  /// juego: lanza [StateError].
  Future<void> writeFile(String path, String content);

  String join(String a, String b);

  Future<HostResponse> http(String method, Uri uri,
      {String? body, Map<String, String> headers = const {}});

  /// Corre [exe] y pasa cada línea de salida a [onLine]; devuelve el
  /// código de salida.
  Future<int> run(String exe, List<String> args,
      {required String workingDirectory,
      required void Function(String line) onLine});
}
