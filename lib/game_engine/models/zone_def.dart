/// Generador de los pisos de una zona (worldgen.md § 2 y § 6.6).
enum ZoneGen { pradera, bosque, ruinas, cavernas, fortaleza, laberinto, abismo }

/// Una zona del mapa del mundo (worldgen.md § 6.1).
class ZoneDef {
  /// 1..10, en orden de dificultad.
  final int index;
  final String id;
  final String name;
  final ZoneGen gen;
  final int minLevel;
  final int maxLevel;
  final int floors;

  /// Jefe del último piso (id del catálogo de enemigos; tentativo en las
  /// zonas que todavía no se juegan).
  final String bossId;

  /// Nombre del jefe para los carteles.
  final String bossName;

  /// Tema visual de los pisos (`GameMap.theme`).
  final String theme;

  /// Misión del mostrador de la zona; `null` = "Próximamente".
  final String? missionId;

  const ZoneDef({
    required this.index,
    required this.id,
    required this.name,
    required this.gen,
    required this.minLevel,
    required this.maxLevel,
    required this.floors,
    required this.bossId,
    required this.bossName,
    required this.theme,
    this.missionId,
  });

  bool get playable => missionId != null;

  /// `"Lv 1-5"`.
  String get levelText => 'Lv $minLevel-$maxLevel';
}
