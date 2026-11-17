/// Una misión del mostrador (`MISSIONS` en el prototipo).
class MissionDef {
  final String id;
  final String name;
  final String type; // 'Exterminio' | 'Recuperación' | 'Urgente'
  final String rank; // 'C' | 'B' | 'A'
  final int recommendedLevel;
  final String theme;

  /// Grupos normales a derrotar para abrir la barrera.
  final int goal;

  /// Grupos de enemigos posibles en el campo.
  final List<List<String>> groups;

  /// Grupo del jefe (el primero es el jefe).
  final List<String> boss;

  /// Tiempo máximo (s) para rango S.
  final int sTime;

  /// Tipo de enemigo de los grupos élite.
  final String elite;

  /// Cuántos objetivos extra (`frag`, `seal`, `elite`) se sortean.
  final int extra;

  /// Zona del mapa del mundo (1..10); 0 = misión vieja de un solo mapa
  /// (`genMap`), sin escalado por nivel. Ver worldgen.md § 6.2.
  final int zone;

  /// Pisos de la misión (1 en las misiones viejas).
  final int floors;

  /// Grupos normales a vencer por piso (misiones de zona).
  final int floorGoal;

  /// Grupos posibles por piso (misiones de zona); vacío = [groups].
  final List<List<List<String>>> floorGroups;

  const MissionDef({
    required this.id,
    required this.name,
    required this.type,
    required this.rank,
    required this.recommendedLevel,
    required this.theme,
    required this.goal,
    required this.groups,
    required this.boss,
    required this.sTime,
    required this.elite,
    required this.extra,
    this.zone = 0,
    this.floors = 1,
    this.floorGoal = 0,
    this.floorGroups = const [],
  });

  /// Grupos posibles en el piso [f].
  List<List<String>> groupsFor(int f) => floorGroups.isEmpty
      ? groups
      : floorGroups[f.clamp(0, floorGroups.length - 1)];

  /// Nivel de botín por rango (cofres): A 3, B 2, C 1.
  int get chestTier => rank == 'A'
      ? 3
      : rank == 'B'
          ? 2
          : 1;
}
