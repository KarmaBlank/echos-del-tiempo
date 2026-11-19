import 'package:echos_del_tiempo/core/update/release_info.dart';
import 'package:echos_del_tiempo/core/update/semver.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> asset(String name, {int size = 100, String? url}) => {
      'name': name,
      'size': size,
      'browser_download_url':
          url ?? 'https://github.com/KarmaBlank/echos-del-tiempo/releases/download/v0.2.0/$name',
    };

Map<String, Object?> release({
  String tag = 'v0.2.0',
  List<Object?>? assets,
  Object? body = '- Nuevo jefe\n- Arreglos',
  bool draft = false,
}) =>
    {
      'tag_name': tag,
      'name': 'Ecos del Tiempo $tag',
      'draft': draft,
      'prerelease': false,
      'body': body,
      'html_url': 'https://github.com/KarmaBlank/echos-del-tiempo/releases/tag/$tag',
      'assets': assets ??
          [
            asset('EcosDelTiempo-Setup-0.2.0.exe', size: 30000000),
            asset('EcosDelTiempo-Setup-0.2.0.exe.sha256', size: 96),
          ],
    };

void main() {
  test('parsea el release de la API con instalador y checksum', () {
    final r = ReleaseInfo.tryFromJson(release())!;
    expect(r.tag, 'v0.2.0');
    expect(r.version, const SemVer(0, 2, 0));
    expect(r.notes, '- Nuevo jefe\n- Arreglos');
    expect(r.installer.name, 'EcosDelTiempo-Setup-0.2.0.exe');
    expect(r.installer.size, 30000000);
    expect(r.checksum!.name, 'EcosDelTiempo-Setup-0.2.0.exe.sha256');
    expect(r.pageUrl.toString(), contains('/releases/tag/v0.2.0'));
  });

  test('elige el .exe de esta versión entre varios e ignora lo demás', () {
    final r = ReleaseInfo.tryFromJson(release(assets: [
      asset('notas.txt'),
      asset('EcosDelTiempo-Setup-0.1.9.exe'),
      asset('ecosdeltiempo-setup-0.2.0.EXE'),
      asset('EcosDelTiempo-Setup-0.2.0.zip'),
      asset('ecosdeltiempo-setup-0.2.0.exe.SHA256'),
    ]))!;
    expect(r.installer.name, 'ecosdeltiempo-setup-0.2.0.EXE');
    expect(r.checksum!.name, 'ecosdeltiempo-setup-0.2.0.exe.SHA256');
  });

  test('sin checksum: igual parsea (la descarga decide)', () {
    final r = ReleaseInfo.tryFromJson(
        release(assets: [asset('EcosDelTiempo-Setup-0.2.0.exe')]))!;
    expect(r.checksum, isNull);
  });

  test('sin instalador, tag basura, borrador o JSON raro → null', () {
    expect(ReleaseInfo.tryFromJson(release(assets: [asset('x.zip')])), isNull);
    expect(ReleaseInfo.tryFromJson(release(assets: [])), isNull);
    expect(ReleaseInfo.tryFromJson(release(tag: 'latest')), isNull);
    expect(ReleaseInfo.tryFromJson(release(draft: true)), isNull);
    expect(ReleaseInfo.tryFromJson(null), isNull);
    expect(ReleaseInfo.tryFromJson([1, 2]), isNull);
    expect(ReleaseInfo.tryFromJson({'tag_name': 3}), isNull);
    expect(
        ReleaseInfo.tryFromJson(release(assets: [
          {'name': 'EcosDelTiempo-Setup-0.2.0.exe', 'size': '9'},
        ])),
        isNull);
    // Instalador vacío o por http a otro host: no sirve.
    expect(
        ReleaseInfo.tryFromJson(
            release(assets: [asset('EcosDelTiempo-Setup-0.2.0.exe', size: 0)])),
        isNull);
    expect(
        ReleaseInfo.tryFromJson(release(assets: [
          asset('EcosDelTiempo-Setup-0.2.0.exe', url: 'http://evil.example/x.exe'),
        ])),
        isNull);
  });

  test('cuerpo ausente → notas vacías', () {
    expect(ReleaseInfo.tryFromJson(release(body: null))!.notes, '');
  });

  test('las capturas del release no se muestran en el juego', () {
    final r = ReleaseInfo.tryFromJson(release(
        body: '# v0.9\n- algo\n\n<!-- capturas -->\n## Capturas\n![a](x.png)'))!;
    expect(r.notes, '# v0.9\n- algo');
  });
}
