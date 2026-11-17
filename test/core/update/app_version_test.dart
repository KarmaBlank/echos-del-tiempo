import 'dart:io';

import 'package:echos_del_tiempo/app/app_version.dart';
import 'package:echos_del_tiempo/core/update/semver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_version.dart coincide con la línea version: del pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([^\s+]+)', multiLine: true).firstMatch(pubspec);
    expect(m, isNotNull);
    expect(appVersion, m!.group(1),
        reason: 'Corré tool/release.ps1 (o actualizá lib/app/app_version.dart)');
    expect(SemVer.tryParse(appVersion), isNotNull);
  });
}
