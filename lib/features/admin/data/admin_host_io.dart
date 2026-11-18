import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/admin_host.dart';

/// [AdminHost] de escritorio con `dart:io`.
class IoAdminHost implements AdminHost {
  IoAdminHost({HttpClient? client})
      : _client = client ?? (HttpClient()..connectionTimeout = _timeout);

  static const _timeout = Duration(seconds: 15);
  final HttpClient _client;

  @override
  bool get supportsFiles => true;

  @override
  bool get supportsProcesses => Platform.isWindows;

  static const _repoDefine = String.fromEnvironment('ECOS_REPO');

  @override
  String? get defaultRepoPath {
    if (_repoDefine.isNotEmpty) return _repoDefine;
    final dir = Directory.current.path;
    final pubspec = File('$dir${Platform.pathSeparator}pubspec.yaml');
    try {
      if (pubspec.existsSync() &&
          pubspec.readAsStringSync().contains('name: echos_del_tiempo')) {
        return dir;
      }
    } on FileSystemException {
      // sin permiso: que lo elija el dueño
    }
    return null;
  }

  /// Carpeta de datos del juego (nunca se escribe ahí).
  String? get _gameDataDir {
    final appData = Platform.environment['APPDATA'];
    if (Platform.isWindows && appData != null) return '$appData\\EcosDelTiempo';
    return null;
  }

  @override
  String? get gameLogPath {
    final d = _gameDataDir;
    return d == null ? null : '$d\\ecos.log';
  }

  @override
  Future<String?> readFile(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  @override
  Future<void> writeFile(String path, String content) async {
    final data = _gameDataDir;
    final abs = File(path).absolute.path.toLowerCase();
    if (data != null && abs.startsWith(data.toLowerCase())) {
      throw StateError('El admin no escribe en la carpeta de datos del juego.');
    }
    final f = File(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(content, flush: true);
  }

  @override
  String join(String a, String b) {
    final sep = Platform.pathSeparator;
    final tail = b.replaceAll('/', sep);
    return a.endsWith(sep) ? '$a$tail' : '$a$sep$tail';
  }

  @override
  Future<HostResponse> http(String method, Uri uri,
      {String? body, Map<String, String> headers = const {}}) async {
    final req = await _client.openUrl(method, uri).timeout(_timeout);
    req.headers.set(HttpHeaders.userAgentHeader, 'ecos-admin');
    headers.forEach(req.headers.set);
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(body));
    }
    final res = await req.close().timeout(_timeout);
    final text = await res.transform(utf8.decoder).join().timeout(_timeout);
    return HostResponse(res.statusCode, text);
  }

  @override
  Future<int> run(String exe, List<String> args,
      {required String workingDirectory,
      required void Function(String line) onLine}) async {
    final p = await Process.start(exe, args,
        workingDirectory: workingDirectory, runInShell: false);
    final done = <Future<void>>[
      p.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .forEach(onLine),
      p.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .forEach((l) => onLine('[stderr] $l')),
    ];
    final code = await p.exitCode;
    await Future.wait(done);
    return code;
  }
}

AdminHost createAdminHost() => IoAdminHost();
