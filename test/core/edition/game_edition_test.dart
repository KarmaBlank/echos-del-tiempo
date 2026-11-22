import 'dart:io';

import 'package:echos_del_tiempo/core/edition/game_data_guard_io.dart';
import 'package:echos_del_tiempo/core/edition/game_edition.dart';
import 'package:echos_del_tiempo/core/update/release_channel.dart';
import 'package:echos_del_tiempo/core/update/semver.dart';
import 'package:echos_del_tiempo/features/lobby/data/json_file_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => GameEdition.install(GameEdition.mundo));

  test('cada juego tiene su carpeta, versión, canal y protocolo', () {
    const m = GameEdition.mundo, t = GameEdition.travesia;
    expect(m.dataFolder, 'EcosDelTiempo');
    expect(t.dataFolder, 'EcosDelTiempo-Travesia');
    // Versión propia (lib/app/travesia_version.dart), no la del pubspec.
    expect(SemVer.tryParse(t.version), isNotNull);    expect(m.releases, same(ReleaseChannel.mundo));
    expect(t.releases, same(ReleaseChannel.travesia));
    expect(m.wire.protocol, isNot(t.wire.protocol));
  });

  test('bajo flutter test la carpeta de datos nunca es %APPDATA%', () {
    for (final e in GameEdition.all) {
      GameEdition.install(e);
      final dir = JsonFileProfileStore.dataDirectory()!;
      expect(dir, endsWith(e.dataFolder));
      expect(dir, startsWith(Directory.systemTemp.path));
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        expect(dir.toLowerCase().startsWith('${appData.toLowerCase()}\\ecos'),
            isFalse);
      }
    }
  });

  test('los overrides no van en la carpeta de ningún juego', () {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return;
    expect(isInsideGameData('$appData\\EcosDelTiempo\\overrides'), isTrue);
    expect(isInsideGameData('$appData\\EcosDelTiempo-Travesia\\x'), isTrue);
    expect(isInsideGameData('$appData\\OtraCosa'), isFalse);
  });
}
