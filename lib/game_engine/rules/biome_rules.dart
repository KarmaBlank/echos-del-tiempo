import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/world_save.dart';

/// Reglas del mapa de viaje, los exteriores de bioma, los refuerzos y la
/// dificultad por sala (docs/specs/overworld_biomes.md). Puras; los
/// números en `kTuning[TuningId.town]` (Editor → Balance → Pueblo).
/// A forage spot position (tiles).
typedef BiomeLayoutSpot = ({int x, int y, int kind});

abstract final class BiomeRules {
  static TuningDef get t => tuning(TuningId.town);

  /// Se puede viajar a [id] (el pueblo o un bioma abierto) con la zona
  /// [unlockedZone] del dueño del mundo desbloqueada (§ 1.1).
  static bool canTravelTo(String id, {int unlockedZone = 1}) {
    final b = biomeDef(id);
    return b != null && b.open && unlockedZone >= b.unlockZone;
  }

  /// Por qué [id] está cerrado todavía (`null` = se puede).
  static String? lockedReason(String id, int unlockedZone) {
    final b = biomeDef(id);
    if (b == null || !b.open) return 'Próximamente';
    if (unlockedZone >= b.unlockZone) return null;
    return 'Se abre al llegar a la zona ${b.unlockZone}';
  }

  /// Precio en oro de la semilla [crop] que vende el habitante de [place]
  /// (§ 9.1); `null` = no la vende ahí.
  static int? vendorPrice(String? place, String crop) =>
      biomeLayout(place)?.npc.seeds[crop];

  /// Clave de un recolectable en `TownState.wild`.
  static String wildKey(String biome, int i) => '$biome:$i';

  /// Recolectables de [biome] que todavía no volvieron a crecer en [now].
  static Set<int> picked(TownState town, String biome, double now) => {
        for (final e in town.wild.entries)
          if (e.key.startsWith('$biome:') && e.value > now)
            if (int.tryParse(e.key.substring(biome.length + 1)) case final i?)
              i,
      };

  /// Segundos que le faltan al recolectable [i] (0 = listo).
  static double regrowIn(TownState town, String biome, int i, double now) =>
      math.max(0, (town.wild[wildKey(biome, i)] ?? 0) - now);

  /// Marca el recolectable [i] como usado (vuelve en `forageRespawnSec`,
  /// or [respawn] s). Limpia los que ya volvieron.
  static TownState pick(TownState town, String biome, int i, double now,
      {double? respawn}) {
    final wild = {
      for (final e in town.wild.entries)
        if (e.value > now) e.key: e.value,
      wildKey(biome, i): (now + (respawn ?? t.d('forageRespawnSec'))).ceil(),
    };
    return town.copyWith(wild: wild);
  }

  /// Regrow time of a spot of [kind] (biome_regions.md § 5): echo blooms
  /// take `echoBloomRespawnSec`.
  static double respawnOf(int kind) =>
      _cls(kind) == ForageClass.echoBloom
          ? tuning(TuningId.regions).d('echoBloomRespawnSec')
          : t.d('forageRespawnSec');

  static ForageClass _cls(int kind) =>
      kForageKinds[kind.clamp(0, kForageKinds.length - 1)].cls;

  /// Regrowth out of view (biome_regions.md § 5.2): spots of [biome]
  /// whose timer ran out regrow only while no player of [players] (px) is
  /// within `forageHideRadius`; a watched one waits `forageRecheckSec`
  /// more. Regrown spots leave [TownState.wild]. Same instance when
  /// nothing changes.
  static TownState holdInView(TownState town, String biome,
      List<BiomeLayoutSpot> spots, List<(double, double)> players, double now) {
    final rt = tuning(TuningId.regions);
    final r2 = math.pow(rt.d('forageHideRadius'), 2);
    Map<String, int>? next;
    for (final e in town.wild.entries) {
      if (e.value > now || !e.key.startsWith('$biome:')) continue;
      final i = int.tryParse(e.key.substring(biome.length + 1));
      if (i == null) continue;
      next ??= Map.of(town.wild);
      if (i >= 0 && i < spots.length) {
        final cx = (spots[i].x + 0.5) * 16, cy = (spots[i].y + 0.5) * 16;
        final seen = players.any((p) =>
            (p.$1 - cx) * (p.$1 - cx) + (p.$2 - cy) * (p.$2 - cy) <= r2);
        if (seen) {
          next[e.key] = (now + rt.d('forageRecheckSec')).ceil();
          continue;
        }
      }
      next.remove(e.key);
    }
    return next == null ? town : town.copyWith(wild: next);
  }

  /// What a spot of [kind] gives (biome_regions.md § 5): the product
  /// (`null` for a seed bush) and maybe a seed of [seeds]. Seasonal spots
  /// give the product of [season].
  static ({String? item, String? seed}) forageSpot(
      double Function() rand, int kind, Map<String, double> seeds,
      {Season season = Season.spring}) {
    switch (_cls(kind)) {
      case ForageClass.plant:
        final r = forage(rand, kind, seeds);
        return (item: r.item, seed: r.seed);
      case ForageClass.seedBush:
        // Rare seeds (the wild-only ones) weigh `seedBushRareMul` more.
        final mul = tuning(TuningId.regions).d('seedBushRareMul');
        final low = seeds.values.fold(1.0, math.min);
        final pool = {
          for (final e in seeds.entries)
            e.key: e.value <= low ? e.value * mul : e.value,
        };
        return (item: null, seed: _weighted(rand, pool));
      case ForageClass.seasonal:
        return (item: kSeasonalForage[season.index], seed: null);
      case ForageClass.echoBloom:
        return (item: kForageKinds[kind].item, seed: null);
    }
  }

  /// Farming XP multiplier of a spot of [kind].
  static double xpMul(int kind) => switch (_cls(kind)) {
        ForageClass.seasonal => tuning(TuningId.regions).d('seasonalXpMul'),
        ForageClass.echoBloom => tuning(TuningId.regions).d('echoBloomXpMul'),
        _ => 1.0,
      };

  static String? _weighted(double Function() rand, Map<String, double> pool) {
    if (pool.isEmpty) return null;
    final total = pool.values.fold(0.0, (a, b) => a + b);
    var r = rand() * total;
    for (final e in pool.entries) {
      r -= e.value;
      if (r < 0) return e.key;
    }
    return pool.keys.first;
  }

  /// Al cargar un mundo (el reloj de la sala arranca en [now]): nada
  /// espera más que un rebrote completo.
  static TownState rebase(TownState town, double now) {
    if (town.wild.isEmpty) return town;
    final cap = (now + t.d('forageRespawnSec')).ceil();
    return town.copyWith(wild: {
      for (final e in town.wild.entries) e.key: math.min(e.value, cap),
    });
  }

  /// Lo que da recolectar el tipo [kind]: el producto silvestre y, con
  /// `forageSeedChance`, una semilla de [seeds] (ponderada; por defecto
  /// las del Bosque).
  static ({String item, String? seed}) forage(
      double Function() rand, int kind, [Map<String, double>? seeds]) {
    final pool = seeds ?? kForestSeeds;
    final item = kForageKinds[kind.clamp(0, kForageKinds.length - 1)].item;
    if (rand() >= t.d('forageSeedChance')) return (item: item, seed: null);
    final total = pool.values.fold(0.0, (a, b) => a + b);
    var r = rand() * total;
    for (final e in pool.entries) {
      r -= e.value;
      if (r < 0) return (item: item, seed: e.key);
    }
    return (item: item, seed: pool.keys.first);
  }

  /// Tamaño efectivo de la sala para la dificultad (town_loop.md § 6):
  /// cada ausente pesa `absentWeight` (0.6). [present] ≥ 1.
  static double roomSize(int present, int absent, {double? weight}) =>
      math.max(1, present) +
      math.max(0, absent) * (weight ?? t.d('absentWeight')).clamp(0.0, 1.0);

  /// Intervalos de espera del refuerzo que entra a una pelea en curso.
  static double get reinforceDelay =>
      t.d('reinforceDelay').clamp(0.0, 10.0).toDouble();
}
