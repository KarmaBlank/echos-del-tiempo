import 'dart:io';

import 'package:echos_del_tiempo/core/audio/music/music_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ocarina_songbook.dart';

void main() {
  test('every track has a mood entry in the songbook', () {
    for (final id in kMusicCatalog.keys) {
      expect(kSongMoods.containsKey(id), isTrue, reason: id);
    }
  });

  test('the ocarina songbook is in sync with the scores', () {
    final file = File(songbookPath);
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync().replaceAll('\r\n', '\n'), buildSongbook(),
        reason: 'run: dart run tool/ocarina_songbook.dart');
  });
}
