import 'package:echos_del_tiempo/core/update/semver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SemVer v(String s) => SemVer.tryParse(s)!;

  test('parsea con y sin v, prerelease y build', () {
    expect(v('v1.2.3').toString(), '1.2.3');
    expect(v('1.2.3').toString(), '1.2.3');
    expect(v(' V0.10.0 ').toString(), '0.10.0');
    expect(v('1.0.0-beta.2').prerelease, ['beta', '2']);
    expect(v('1.0.0+7'), v('1.0.0'));
    expect(v('1.0.0-rc.1+abc').toString(), '1.0.0-rc.1');
  });

  test('basura → null, sin lanzar', () {
    for (final s in [
      null, '', 'v', 'latest', '1.2', '1.2.3.4', 'v1.2.x', '01.2.3',
      '1.2.3-', 'v1.2.3 beta', 'nightly-2026', '-1.0.0',
    ]) {
      expect(SemVer.tryParse(s), isNull, reason: '$s');
    }
  });

  test('orden numérico (no alfabético)', () {
    expect(v('0.10.0') > v('0.9.9'), isTrue);
    expect(v('1.0.0') > v('0.99.99'), isTrue);
    expect(v('0.1.1') > v('0.1.0'), isTrue);
    expect(v('0.1.0') > v('0.1.0'), isFalse);
    expect(v('0.1.0').compareTo(v('v0.1.0')), 0);
  });

  test('prerelease: menor que la final y orden SemVer', () {
    final ordered = [
      '1.0.0-alpha', '1.0.0-alpha.1', '1.0.0-alpha.beta', '1.0.0-beta',
      '1.0.0-beta.2', '1.0.0-beta.11', '1.0.0-rc.1', '1.0.0',
    ].map(v).toList();
    for (var i = 0; i + 1 < ordered.length; i++) {
      expect(ordered[i] < ordered[i + 1], isTrue,
          reason: '${ordered[i]} < ${ordered[i + 1]}');
    }
    expect(v('1.0.0-rc.1') > v('0.9.0'), isTrue);
  });
}
