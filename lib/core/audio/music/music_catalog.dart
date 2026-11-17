import 'music_score.dart';
import 'tracks/battle_theme.dart';
import 'tracks/boss_theme.dart';
import 'tracks/jingles.dart';
import 'tracks/overworld_theme.dart';
import 'tracks/title_theme.dart';
import 'tracks/town_theme.dart';
import 'tracks/zone1_pradera.dart';
import 'tracks/zone2_bosque.dart';
import 'tracks/zone3_ruinas.dart';
import 'tracks/zone4_cavernas.dart';
import 'tracks/zone5_fortaleza.dart';

/// Ids de las piezas (docs/specs/music.md § 4).
abstract final class Music {
  static const title = 'title';
  static const town = 'town';
  static const overworld = 'overworld';
  static const battle = 'battle';
  static const boss = 'boss';

  static const victory = 'jingle.victory';
  static const defeat = 'jingle.defeat';
  static const levelUp = 'jingle.levelUp';
  static const zoneUnlocked = 'jingle.zoneUnlocked';

  static const zone1 = 'zone1';

  /// Zonas con pieza propia.
  static const zones = [1, 2, 3, 4, 5];

  /// La pieza de la zona [z] (1–5).
  static String zone(int z) => 'zone$z';
}

/// Todas las piezas por id. Se arman una vez (al primer uso).
final Map<String, Song> kMusicCatalog = {
  for (final s in [
    titleTheme(),
    townTheme(),
    overworldTheme(),
    zone1Pradera(),
    zone2Bosque(),
    zone3Ruinas(),
    zone4Cavernas(),
    zone5Fortaleza(),
    battleTheme(),
    bossTheme(),
    victoryJingle(),
    defeatJingle(),
    levelUpJingle(),
    zoneUnlockedJingle(),
  ])
    s.id: s,
};
