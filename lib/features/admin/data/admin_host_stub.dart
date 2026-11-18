import '../domain/admin_host.dart';

/// [AdminHost] para web: sin disco ni procesos. El navegador de balance,
/// el editor, la vista previa y las notas funcionan; guardar y publicar
/// no (docs/specs/balance_admin.md § 5).
class StubAdminHost implements AdminHost {
  @override
  bool get supportsFiles => false;

  @override
  bool get supportsProcesses => false;

  @override
  String? get defaultRepoPath => null;

  @override
  String? get gameLogPath => null;

  @override
  Future<String?> readFile(String path) async => null;

  @override
  Future<void> writeFile(String path, String content) async =>
      throw UnsupportedError('Sin disco en web');

  @override
  String join(String a, String b) => '$a/$b';

  @override
  Future<HostResponse> http(String method, Uri uri,
          {String? body, Map<String, String> headers = const {}}) async =>
      const HostResponse(0, 'Sin red directa en web (CORS)');

  @override
  Future<int> run(String exe, List<String> args,
          {required String workingDirectory,
          required void Function(String line) onLine}) async =>
      throw UnsupportedError('Sin procesos en web');
}

AdminHost createAdminHost() => StubAdminHost();
