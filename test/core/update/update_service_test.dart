import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/core/update/release_info.dart';
import 'package:echos_del_tiempo/core/update/sha256.dart';
import 'package:echos_del_tiempo/core/update/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor HTTP local que imita a GitHub (API + descargas).
class FakeGitHub {
  late HttpServer server;
  int apiStatus = 200;
  Map<String, String> apiHeaders = {};
  Object? apiJson;
  String? apiRaw;
  bool hangApi = false;
  final files = <String, List<int>>{};

  /// Bytes a mandar de menos/más en `/dl/` (corrupción de tamaño).
  int truncate = 0;

  Uri get api => Uri.parse('http://127.0.0.1:${server.port}/repos/x/y/releases/latest');
  String dl(String name) => 'http://127.0.0.1:${server.port}/dl/$name';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      if (req.uri.path.startsWith('/repos/')) {
        if (hangApi) return; // nunca responde
        res.statusCode = apiStatus;
        apiHeaders.forEach(res.headers.set);
        res.write(apiRaw ?? jsonEncode(apiJson));
      } else if (req.uri.path.startsWith('/dl/')) {
        final name = req.uri.pathSegments.last;
        final body = files[name];
        if (body == null) {
          res.statusCode = 404;
        } else {
          res.add(body.sublist(0, body.length - truncate));
        }
      }
      await res.close();
    });
  }

  Map<String, Object?> releaseJson(String tag,
      {required List<int> installer, String? sha, bool withSha = true}) {
    final name = 'EcosDelTiempo-Setup-${tag.substring(1)}.exe';
    files[name] = installer;
    final assets = <Map<String, Object?>>[
      {'name': name, 'size': installer.length, 'browser_download_url': dl(name)},
    ];
    if (withSha) {
      final shaBody = utf8.encode('${sha ?? Sha256.of(installer)}  $name\n');
      files['$name.sha256'] = shaBody;
      assets.add({
        'name': '$name.sha256',
        'size': shaBody.length,
        'browser_download_url': dl('$name.sha256'),
      });
    }
    return {'tag_name': tag, 'body': 'notas', 'draft': false, 'assets': assets};
  }
}

void main() {
  late FakeGitHub gh;
  late Directory tmp;

  setUp(() async {
    gh = FakeGitHub();
    await gh.start();
    tmp = await Directory.systemTemp.createTemp('ecos_update_test');
  });

  tearDown(() async {
    await gh.server.close(force: true);
    await tmp.delete(recursive: true);
  });

  GitHubUpdateService svc({String current = '0.1.0', Uri? endpoint}) =>
      GitHubUpdateService(
        currentVersion: current,
        endpoint: endpoint ?? gh.api,
        checkTimeout: const Duration(milliseconds: 500),
        idleTimeout: const Duration(seconds: 2),
        downloadDir: tmp,
        exitApp: (_) {},
      );

  final payload = List<int>.generate(70000, (i) => i % 251);

  group('check', () {
    test('versión mayor → UpdateAvailable', () async {
      gh.apiJson = gh.releaseJson('v0.2.0', installer: payload);
      final r = await svc().check();
      expect(r, isA<UpdateAvailable>());
      expect((r as UpdateAvailable).release.version.toString(), '0.2.0');
    });

    test('misma o menor versión → UpToDate', () async {
      gh.apiJson = gh.releaseJson('v0.1.0', installer: payload);
      final r = await svc().check();
      expect(r, isA<UpToDate>());
      expect((r as UpToDate).latest.toString(), '0.1.0');
      expect(await svc(current: '0.3.0').check(), isA<UpToDate>());
    });

    test('sin releases (404) → UpToDate sin latest', () async {
      gh.apiStatus = 404;
      gh.apiJson = {'message': 'Not Found'};
      final r = await svc().check();
      expect(r, isA<UpToDate>());
      expect((r as UpToDate).latest, isNull);
    });

    test('límite de GitHub (403) → mensaje con la hora', () async {
      gh.apiStatus = 403;
      gh.apiHeaders = {'x-ratelimit-remaining': '0', 'x-ratelimit-reset': '1900000000'};
      gh.apiJson = {'message': 'API rate limit exceeded'};
      final r = await svc().check();
      expect(r, isA<UpdateCheckFailed>());
      expect((r as UpdateCheckFailed).message, contains('limitó'));
    });

    test('500, JSON basura o release sin instalador → falla suave', () async {
      gh.apiStatus = 500;
      gh.apiJson = {};
      expect(await svc().check(), isA<UpdateCheckFailed>());
      gh.apiStatus = 200;
      gh.apiRaw = '<html>no es json';
      expect(await svc().check(), isA<UpdateCheckFailed>());
      gh.apiRaw = null;
      gh.apiJson = {'tag_name': 'v9.9.9', 'assets': []};
      expect(await svc().check(), isA<UpdateCheckFailed>());
    });

    test('timeout → UpdateCheckFailed (no cuelga)', () async {
      gh.hangApi = true;
      final sw = Stopwatch()..start();
      final r = await svc().check();
      expect(r, isA<UpdateCheckFailed>());
      expect((r as UpdateCheckFailed).message, contains('tardó'));
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('sin conexión (puerto cerrado) → UpdateCheckFailed', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      final r = await svc(endpoint: Uri.parse('http://127.0.0.1:$port/x')).check();
      expect(r, isA<UpdateCheckFailed>());
    });
  });

  group('download', () {
    Future<ReleaseInfo> available() async {
      final r = await svc().check();
      return (r as UpdateAvailable).release;
    }

    test('baja, informa progreso y verifica SHA-256', () async {
      gh.apiJson = gh.releaseJson('v0.2.0', installer: payload);
      final rel = await available();
      final seen = <int>[];
      final f = await svc().download(rel, onProgress: (got, total) {
        expect(total, payload.length);
        seen.add(got);
      });
      expect(await f.readAsBytes(), payload);
      expect(f.path, endsWith('EcosDelTiempo-Setup-0.2.0.exe'));
      expect(seen.last, payload.length);
      expect(File('${f.path}.part').existsSync(), isFalse);
    });

    test('checksum distinto → rechazado y sin archivo', () async {
      gh.apiJson = gh.releaseJson('v0.2.0',
          installer: payload, sha: Sha256.of(utf8.encode('otra cosa')));
      final rel = await available();
      await expectLater(svc().download(rel),
          throwsA(isA<UpdateFailure>().having((e) => e.message, 'msg', contains('SHA-256'))));
      expect(tmp.listSync(), isEmpty);
    });

    test('tamaño distinto → rechazado', () async {
      gh.apiJson = gh.releaseJson('v0.2.0', installer: payload);
      final rel = await available();
      gh.truncate = 10;
      await expectLater(svc().download(rel),
          throwsA(isA<UpdateFailure>().having((e) => e.message, 'msg', contains('incompleta'))));
      expect(tmp.listSync(), isEmpty);
    });

    test('release sin .sha256 → rechazado (requireChecksum)', () async {
      gh.apiJson = gh.releaseJson('v0.2.0', installer: payload, withSha: false);
      final rel = await available();
      await expectLater(svc().download(rel), throwsA(isA<UpdateFailure>()));
    });

    test('servidor caído a mitad → UpdateFailure', () async {
      gh.apiJson = gh.releaseJson('v0.2.0', installer: payload);
      final rel = await available();
      final s = svc();
      await gh.server.close(force: true);
      await expectLater(s.download(rel), throwsA(isA<UpdateFailure>()));
    });
  });
}
