import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/world_save.dart';

/// Reglas del mapa de viaje, los exteriores de bioma, los refuerzos y la
/// dificultad por sala (docs/specs/overworld_biomes.md). Puras; los
/// números en `kTuning[TuningId.town]` (Editor → Balance → Pueblo).
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

  /// Marca el recolectable [i] como usado (vuelve en `forageRespawnSec`).
  /// Limpia los que ya volvieron.
  static TownState pick(TownState town, String biome, int i, double now) {
    final wild = {
      for (final e in town.wild.entries)
        if (e.value > now) e.key: e.value,
      wildKey(biome, i): (now + t.d('forageRespawnSec')).ceil(),
    };
    return town.copyWith(wild: wild);
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
