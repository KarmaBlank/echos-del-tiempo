import 'music_score.dart';
import 'tracks/abyss_boss_theme.dart';
import 'tracks/battle_theme.dart';
import 'tracks/secret_boss_theme.dart';
import 'tracks/boss_theme.dart';
import 'tracks/final_boss_theme.dart';
import 'tracks/jingles.dart';
import 'tracks/overworld_theme.dart';
import 'tracks/title_theme.dart';
import 'tracks/town_theme.dart';
import 'tracks/zone10_corazon.dart';
import 'tracks/zone1_pradera.dart';
import 'tracks/zone2_bosque.dart';
import 'tracks/zone3_ruinas.dart';
import 'tracks/zone4_cavernas.dart';
import 'tracks/zone5_fortaleza.dart';
import 'tracks/zone6_laberinto.dart';
import 'tracks/zone7_grieta.dart';
import 'tracks/zone8_cementerio.dart';
import 'tracks/zone9_abismo.dart';

/// Ids de las piezas (docs/specs/music.md § 4).
abstract final class Music {
  static const title = 'title';
  static const town = 'town';
  static const overworld = 'overworld';
  static const battle = 'battle';
  static const boss = 'boss';

  /// Variante del jefe final (Devorador de Eras, zona 10).
  static const bossFinal = 'bossFinal';

  /// Jefes del Abismo 1–4 (v0.8, docs/specs/abyss_bosses.md § 4).
  static const bossAbyss = 'bossAbyss';

  /// Jefe secreto del Abismo (Eco Primordial).
  static const bossSecret = 'bossSecret';

  static const victory = 'jingle.victory';
  static const defeat = 'jingle.defeat';
  static const levelUp = 'jingle.levelUp';
  static const zoneUnlocked = 'jingle.zoneUnlocked';

  /// Cinemática de ascensión (docs/specs/ascension.md § 5).
  static const ascension = 'jingle.ascension';

  static const zone1 = 'zone1';

  /// Zonas con pieza propia.
  static const zones = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

  /// La pieza de la zona [z] (1–10).
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
    zone6Laberinto(),
    zone7Grieta(),
    zone8Cementerio(),
    zone9Abismo(),
    zone10Corazon(),
    battleTheme(),
    bossTheme(),
    finalBossTheme(),
    abyssBossTheme(),
    secretBossTheme(),
    victoryJingle(),
    defeatJingle(),
    levelUpJingle(),
    zoneUnlockedJingle(),
    ascensionJingle(),
  ])
    s.id: s,
};
