import '../../../../../game_engine/models/battle_state.dart';

/// Qué arena se dibuja en una batalla (docs/specs/battle_presentation.md
/// § "Arenas"). Dart puro: lo eligen [selectArena] y los tests.

/// Tipo de encuentro: decide el tamaño, el marco y la luz de la arena.
enum EncounterKind { normal, elite, boss }

/// Escenografía de la arena (una por zona + Prueba + pueblo).
enum ArenaTheme {
  /// Zona 1 · Pradera Esmeralda: pasto, flores, colinas y cielo.
  pradera,

  /// Zona 2 · Bosque Hondo: claro de bosque con troncos y raíces.
  bosque,

  /// Zona 3 · Ruinas Cronales: losas partidas y columnas rotas.
  ruinas,

  /// Zona 4 · Cavernas Heladas: hielo, carámbanos y cristales.
  cavernas,

  /// Zona 5 · Fortaleza Caída: patio de armas, almenas y estandartes.
  fortaleza,

  /// Zona 6 · Laberinto Temporal: losas con bronce y engranajes.
  laberinto,

  /// Zona 7 · Grieta Ígnea: basalto con vetas de lava.
  grieta,

  /// Zona 8 · Cementerio de Eras: tierra gris, lápidas, vacío violeta.
  cementerio,

  /// Zona 9 · Abismo del Tiempo: isla de roca sobre el vacío.
  abismo,

  /// Zona 10 · Corazón del Tiempo: cristal dorado y círculo rúnico.
  corazon,

  /// Prueba del Tiempo: sala de plata y violeta con relojes de arena.
  prueba,

  /// Pueblo / mapa del mundo / sin datos: plaza empedrada.
  pueblo,
}

/// La arena elegida: escenografía, tipo, jefe (set-piece) y variantes.
class ArenaSpec {
  const ArenaSpec({
    required this.theme,
    required this.kind,
    this.bossType,
    this.phase2 = false,
    this.eco = false,
  });

  final ArenaTheme theme;
  final EncounterKind kind;

  /// `enemyType` del jefe (set-piece propio); `null` fuera de jefes.
  final String? bossType;

  /// El jefe está en su segunda fase (Devorador): otra arena.
  final bool phase2;

  /// Batalla de un Eco (tinte espectral sobre la escenografía).
  final bool eco;

  /// Clave de la capa estática cacheada.
  String get cacheKey =>
      '${theme.name}/${kind.name}/${bossType ?? '-'}/${phase2 ? 2 : 1}/'
      '${eco ? 'eco' : '-'}';

  @override
  bool operator ==(Object other) =>
      other is ArenaSpec && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;

  @override
  String toString() => 'ArenaSpec($cacheKey)';
}

/// Tema de mapa (`GameMap.theme`) → arena.
const Map<String, ArenaTheme> kArenaByMapTheme = {
  'pradera': ArenaTheme.pradera,
  'mundo': ArenaTheme.pradera,
  'bosque': ArenaTheme.bosque,
  'ruinas': ArenaTheme.ruinas,
  'cavernas': ArenaTheme.cavernas,
  'fortaleza': ArenaTheme.fortaleza,
  'laberinto': ArenaTheme.laberinto,
  'grieta': ArenaTheme.grieta,
  'cementerio': ArenaTheme.cementerio,
  'abismo': ArenaTheme.abismo,
  'corazon': ArenaTheme.corazon,
  'lobby': ArenaTheme.pueblo,
};

/// Zona (1..10) → arena (si el tema del mapa no se conoce).
const List<ArenaTheme> kArenaByZone = [
  ArenaTheme.pradera,
  ArenaTheme.bosque,
  ArenaTheme.ruinas,
  ArenaTheme.cavernas,
  ArenaTheme.fortaleza,
  ArenaTheme.laberinto,
  ArenaTheme.grieta,
  ArenaTheme.cementerio,
  ArenaTheme.abismo,
  ArenaTheme.corazon,
];

/// Tipo de encuentro de [s]: jefe si la batalla o algún enemigo es jefe;
/// élite si la batalla o algún enemigo es élite; si no, normal. Sale del
/// estado que ya viaja por la red (`BattleState.boss` / `.elite`).
EncounterKind encounterKindOf(BattleState s) {
  if (s.boss || s.enemies.any((e) => e.boss)) return EncounterKind.boss;
  if (s.elite || s.enemies.any((e) => e.elite)) return EncounterKind.elite;
  return EncounterKind.normal;
}

/// Escenografía: la Prueba del Tiempo tiene la suya; si no, el tema del
/// mapa (un Eco usa el de su zona: su mapa lleva ese tema); si no, la
/// zona; si no, el pueblo.
ArenaTheme arenaThemeFor({String? mapTheme, int zone = 0, bool trial = false}) {
  if (trial) return ArenaTheme.prueba;
  final byMap = kArenaByMapTheme[mapTheme];
  if (byMap != null) return byMap;
  if (zone >= 1 && zone <= kArenaByZone.length) return kArenaByZone[zone - 1];
  return ArenaTheme.pueblo;
}

/// Arena de la batalla [battle] (docs/specs/battle_presentation.md
/// § "Arenas"). Pura: misma entrada, misma arena.
ArenaSpec selectArena({
  required BattleState battle,
  String? mapTheme,
  int zone = 0,
  bool trial = false,
  bool eco = false,
}) {
  final kind = encounterKindOf(battle);
  Combatant? boss;
  if (kind == EncounterKind.boss) {
    for (final e in battle.enemies) {
      if (e.boss) {
        boss = e;
        break;
      }
    }
  }
  return ArenaSpec(
    theme: arenaThemeFor(mapTheme: mapTheme, zone: zone, trial: trial),
    kind: kind,
    bossType: boss?.enemyType,
    phase2: (boss?.phase ?? 0) >= 2,
    eco: eco,
  );
}

/// Tamaño del escenario (px del mundo) y su centro: la cámara nunca sale
/// de él. Ver § "Arenas" → "Escenario".
abstract final class ArenaStage {
  static const width = 960.0, height = 540.0;

  /// Centro del escenario (línea media entre los dos bandos) y la línea
  /// de los pies.
  static const centerX = 480.0, floorY = 300.0;

  /// Aire extra alrededor de la pelea en el encuadre (px del mundo):
  /// más escenario a la vista cuanto más importante el encuentro.
  static (double, double) padFor(EncounterKind k) => switch (k) {
        EncounterKind.normal => (8.0, 4.0),
        EncounterKind.elite => (20.0, 8.0),
        EncounterKind.boss => (44.0, 16.0),
      };

  /// Distancia del centro al borde interno de cada bando.
  static double gapFor(EncounterKind k) => switch (k) {
        EncounterKind.normal => 40.0,
        EncounterKind.elite => 46.0,
        EncounterKind.boss => 52.0,
      };
}
