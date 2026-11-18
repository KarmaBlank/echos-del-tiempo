import 'package:echos_del_tiempo/features/admin/domain/admin_host.dart';

/// [AdminHost] en memoria para los tests del admin.
class FakeAdminHost implements AdminHost {
  FakeAdminHost({Map<String, String>? files, this.responses = const {}})
      : files = files ?? {};

  final Map<String, String> files;

  /// Respuestas HTTP por prefijo de URL.
  final Map<String, HostResponse> responses;
  final writes = <String>[];
  final runs = <List<String>>[];

  /// Salida de `git show main:...` (null = no existe en main).
  String? releasedBalance;

  @override
  bool get supportsFiles => true;

  @override
  bool get supportsProcesses => true;

  @override
  String? get defaultRepoPath => 'repo';

  @override
  String? get gameLogPath => 'appdata/EcosDelTiempo/ecos.log';

  @override
  Future<String?> readFile(String path) async => files[path];

  @override
  Future<void> writeFile(String path, String content) async {
    if (path.startsWith('appdata/')) throw StateError('carpeta del juego');
    writes.add(path);
    files[path] = content;
  }

  @override
  String join(String a, String b) => '$a/$b';

  @override
  Future<HostResponse> http(String method, Uri uri,
      {String? body, Map<String, String> headers = const {}}) async {
    for (final e in responses.entries) {
      if (uri.toString().startsWith(e.key)) return e.value;
    }
    return const HostResponse(404, '{}');
  }

  @override
  Future<int> run(String exe, List<String> args,
      {required String workingDirectory,
      required void Function(String line) onLine}) async {
    runs.add([exe, ...args]);
    if (exe == 'git') {
      if (releasedBalance == null) return 128;
      releasedBalance!.split('\n').forEach(onLine);
      return 0;
    }
    onLine('ok');
    return 0;
  }
}
