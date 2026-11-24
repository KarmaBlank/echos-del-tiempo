import 'strings.dart';

/// Keys of the data catalogs that live in `game_engine` (pure Dart: the
/// catalogs keep their es-AR text; presentation resolves the key).
/// docs/specs/i18n.md § 3.4.
abstract final class DataKeys {
  /// `reyLimo` → `rey_limo` (keys are lowercase snake case).
  static String slug(String id) => id
      .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
      .replaceAll(RegExp('[^a-z0-9_]'), '_');

  static String zoneName(String id) => 'data.zones.${slug(id)}.name';
  static String missionName(String id) => 'data.missions.${slug(id)}.name';
  static String missionType(String type) =>
      'data.missions.type.${slug(_fold(type))}';
  static String enemyName(String id) => 'data.enemies.${slug(id)}.name';
  static String enemyTitle(String id) => 'data.enemies.${slug(id)}.title';
  static String mechanicName(String id) =>
      'data.enemies.mechanic.${slug(id)}.name';
  static String mechanicCounter(String id) =>
      'data.enemies.mechanic.${slug(id)}.counter';
  static String achievementName(String id) =>
      'data.achievements.${slug(id)}.name';
  static String achievementHow(String id) =>
      'data.achievements.${slug(id)}.how';
  static String achievementCategory(String name) =>
      'data.achievements.category.${slug(name)}';

  static String _fold(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');
}

extension DataStrings on Strings {
  /// Text of a data catalog entry: in es-AR the catalog's own [source]
  /// (what the editors write); in another language the key's text in that
  /// language, or [source] when it has none.
  String data(StringKey key, String source) =>
      isSource ? source : (lookup(key) ?? source);
}
