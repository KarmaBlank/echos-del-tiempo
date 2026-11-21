import 'package:echos_del_tiempo/core/update/release_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mundo: vX.Y.Z (v opcional), nunca un tag de Travesía', () {
    const c = ReleaseChannel.mundo;
    expect(c.versionOf('v0.20.6').toString(), '0.20.6');
    expect(c.versionOf('0.20.6').toString(), '0.20.6');
    expect(c.versionOf('travesia-v0.1.0'), isNull);
    expect(c.tagFor('0.21.0'), 'v0.21.0');
  });

  test('Travesía: solo travesia-vX.Y.Z, prereleases incluidos', () {
    const c = ReleaseChannel.travesia;
    expect(c.versionOf('travesia-v0.1.0').toString(), '0.1.0');
    expect(c.versionOf('travesia-v0.2.0-beta.1')!.isPrerelease, isTrue);
    expect(c.versionOf('v0.20.6'), isNull);
    expect(c.versionOf('travesia-vx'), isNull);
    expect(c.tagFor('0.1.0'), 'travesia-v0.1.0');
    expect(c.includePrereleases, isTrue);
  });
}
