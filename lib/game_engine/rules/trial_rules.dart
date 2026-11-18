import 'dart:math' as math;

import '../data/game_catalog.dart';
import '../data/trials_catalog.dart';
import '../models/ascension.dart';
import '../models/game_map.dart';
import '../models/mission_def.dart';
import '../models/player_profile.dart';
import '../models/zone_def.dart';
import 'map_generator.dart';
import 'mulberry32.dart';

export '../models/ascension.dart' show TrapKind;

/// Reglas de las Pruebas del Tiempo (ascension.md § 1): disponibilidad,
/// mazmorra con trampas y recompensa. Puras.
class TrialRules {
  const TrialRules({this.catalog = GameCatalog.standard});

  final GameCatalog catalog;

  /// `missionId` de las Pruebas (votación, preparación, sesión).
  static const missionId = 'trial';

  /// Ciclo del Pulso del Tiempo (s) y cuándo empieza a estar activo.
  static const pulsePeriod = 3.0;
  static const pulseActiveFrom = 2.0;

  /// Las púas dañan una vez cada tanto (s) mientras se esté encima.
  static const spikeEvery = 1.0;

  /// Distancias de ubicación de las trampas (tiles).
  static const minSpawnDistance = 7;
  static const minStairsDistance = 4;
  static const minTrapDistance = 4;

  /// El Pulso del Tiempo está activo en el instante [time] de la sala.
  static bool pulseActive(double time) =>
      time % pulsePeriod >= pulseActiveFrom;

  /// Carga del pulso (0..1 mientras carga; 1 activo).
  static double pulseCharge(double time) {
    final t = time % pulsePeriod;
    return t >= pulseActiveFrom ? 1 : t / pulseActiveFrom;
  }

  /// La trampa del tile [ch] (o `null`).
  static TrapKind? trapAt(String ch) => switch (ch) {
        Tile.spikes => TrapKind.spikes,
        Tile.pulse => TrapKind.pulse,
        _ => null,
      };

  // ------------------------------------------------------------------
  // Disponibilidad y recompensa (§ 1, § 1.2)
  // ------------------------------------------------------------------

  /// Por qué [p] no puede proponer la Prueba [n] (o `null` si puede).
  String? cannotPropose(PlayerProfile p, int n) {
    final t = trialDef(n);
    if (t == null) return 'Prueba desconocida';
    if (p.level < t.level) return 'Requiere nivel ${t.level}';
    if (n > 1 && !p.ascension.trials.contains(n - 1)) {
      return 'Superá antes la Prueba ${trialDef(n - 1)!.roman}';
    }
    return null;
  }

  /// [p] gana los puntos de la Prueba [n] al completarla: no la tenía,
  /// tiene el nivel y la anterior.
  bool earnsPoints(PlayerProfile p, int n) =>
      !p.ascension.trials.contains(n) && cannotPropose(p, n) == null;

  /// El perfil con la Prueba [n] superada.
  PlayerProfile complete(PlayerProfile p, int n) => p.copyWith(
      ascension: p.ascension.copyWith(trials: {...p.ascension.trials, n}));

  /// Puntos que da cada Prueba.
  static const points = AscensionProgress.pointsPerTrial;

  // ------------------------------------------------------------------
  // Mazmorra (§ 1)
  // ------------------------------------------------------------------

  /// La zona sintética de la Prueba [t].
  ZoneDef zoneDef(TrialDef t) {
    final z = catalog.zone(t.zone) ?? catalog.zones.first;
    final b = catalog.zone(t.bossZone) ?? z;
    return ZoneDef(
      index: z.index,
      id: missionId,
      name: t.fullName,
      gen: z.gen,
      minLevel: t.monsterLevel,
      maxLevel: t.monsterLevel,
      floors: t.floors,
      bossId: b.bossId,
      bossName: b.bossName,
      theme: z.theme,
      missionId: missionId,
    );
  }

  /// La misión de la Prueba [t]: grupos del último piso de la misión de
  /// su zona y el jefe de la misión de su zona de jefe.
  MissionDef missionDef(TrialDef t) {
    final z = zoneDef(t);
    final zm = catalog.mission(catalog.zone(t.zone)?.missionId ?? '') ??
        catalog.missions.first;
    final bm = catalog.mission(catalog.zone(t.bossZone)?.missionId ?? '') ?? zm;
    return MissionDef(
      id: missionId,
      name: t.fullName,
      type: 'Prueba',
      rank: 'A',
      recommendedLevel: t.level,
      theme: z.theme,
      goal: 4 * t.floors,
      groups: zm.groupsFor(zm.floors - 1),
      boss: bm.boss,
      sTime: 300 * t.floors,
      elite: zm.elite,
      extra: 0,
      zone: z.index,
      floors: t.floors,
      floorGoal: 4,
    );
  }

  /// La mazmorra de la Prueba [t] con [seed]: el atlas de pisos de su
  /// zona con las trampas encima.
  GameMap map(TrialDef t, int seed) =>
      withTraps(MapGenerator.zone(zoneDef(t), seed), t, seed);

  /// Pone las trampas de [t] en cada piso de [base] (§ 1.1).
  static GameMap withTraps(GameMap base, TrialDef t, int seed) {
    final rows = [for (final r in base.rows) r.split('')];
    bool ground(int x, int y) =>
        y >= 0 &&
        y < rows.length &&
        x >= 0 &&
        x < rows[y].length &&
        (rows[y][x] == Tile.floor || rows[y][x] == Tile.path);
    int dist(int ax, int ay, int bx, int by) =>
        math.max((ax - bx).abs(), (ay - by).abs());
    (int, int) tileOf(WorldPoint p) =>
        ((p.x / MapGenerator.tileSize).floor(), (p.y / MapGenerator.tileSize).floor());

    for (final f in base.floors) {
      final r = mulberry32((seed ^ (0x7A11 + 131 * f.index)) | 0);
      final sp = tileOf(f.spawn);
      final stairs = [
        if (f.stairsDown case final s?) tileOf(s),
        if (f.stairsUp case final s?) tileOf(s),
      ];
      final ar = f.arena;
      bool inArena(int x, int y) =>
          ar != null &&
          x >= ar.x - 2 &&
          y >= ar.y - 2 &&
          x < ar.x + ar.w + 2 &&
          y < ar.y + ar.h + 2;
      final placed = <(int, int)>[];
      final spots = f.spots;
      void place(int count, int size, String tile) {
        for (var k = 0; k < count && spots.isNotEmpty; k++) {
          for (var tries = 0; tries < 200; tries++) {
            final (x, y) = spots[(r() * spots.length).floor()];
            if (!ground(x, y) ||
                dist(x, y, sp.$1, sp.$2) <= minSpawnDistance ||
                stairs.any((s) => dist(x, y, s.$1, s.$2) <= minStairsDistance) ||
                inArena(x, y) ||
                placed.any((p) => dist(x, y, p.$1, p.$2) < minTrapDistance)) {
              continue;
            }
            final o = size == 3 ? -1 : 0;
            var n = 0;
            for (var dy = 0; dy < size; dy++) {
              for (var dx = 0; dx < size; dx++) {
                final tx = x + o + dx, ty = y + o + dy;
                if (!ground(tx, ty) || inArena(tx, ty)) continue;
                rows[ty][tx] = tile;
                n++;
              }
            }
            if (n > 0) placed.add((x, y));
            break;
          }
        }
      }

      place(t.spikes, 2, Tile.spikes);
      place(t.pulses, 3, Tile.pulse);
    }

    return GameMap(
      width: base.width,
      height: base.height,
      rows: [for (final r in rows) r.join()],
      theme: base.theme,
      spawn: base.spawn,
      side: base.side,
      arena: base.arena,
      rooms: base.rooms,
      boss: base.boss,
      spots: base.spots,
      floors: base.floors,
      zone: base.zone,
    );
  }
}
