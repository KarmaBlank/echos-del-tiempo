import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../models/game_map.dart';
import '../models/player_profile.dart';
import 'map_generator.dart';

/// Un portal de Ecos en el exterior de un bioma (ecos_zone.md § 2).
class EcoPortalSpot {
  const EcoPortalSpot(this.zone, this.biome, this.x, this.y);

  final int zone;

  /// Id del bioma cuyo exterior lo tiene (`bosque`...).
  final String biome;

  /// Tile del medio (el portal ocupa `x − 1 .. x + 1`).
  final int x, y;

  /// Dónde queda parado el jugador al llegar (frente al portal).
  WorldPoint get front => WorldPoint(
      (x + 0.5) * MapGenerator.tileSize, (y + 1.6) * MapGenerator.tileSize);
}

/// Ecos por zona (docs/specs/ecos_zone.md): dónde está el portal de cada
/// zona, qué tiers tiene abiertos cada personaje y por qué no.
abstract final class EcoPortalRules {
  static const maxTier = 16;

  /// Distancia (px) al borde del portal para usarlo con E.
  static const range = 14.0;

  /// The portals of the generated regions (biome_regions.md), rebuilt
  /// when the world seed changes.
  static Map<int, EcoPortalSpot> get _spots {
    final hit = _cache;
    if (hit != null && _cacheSeed == BiomeRegions.seed) return hit;
    _cacheSeed = BiomeRegions.seed;
    return _cache = {
      for (final l in kBiomeLayouts.values)
        for (final (zone, x, y) in l.ecoPortals)
          zone: EcoPortalSpot(zone, l.id, x, y),
    };
  }

  static Map<int, EcoPortalSpot>? _cache;
  static int _cacheSeed = 0;

  /// Todos los portales, por zona (1..10).
  static List<EcoPortalSpot> get all =>
      [for (final z in _spots.keys.toList()..sort()) _spots[z]!];

  static EcoPortalSpot? of(int zone) => _spots[zone];

  /// La zona del portal frente al que está (x, y) px en el exterior
  /// [place], o `null`.
  static int? near(String? place, double x, double y) {
    if (place == null) return null;
    const ts = MapGenerator.tileSize;
    for (final p in _spots.values) {
      if (p.biome != place) continue;
      final x0 = (p.x - 1) * ts, x1 = (p.x + 2) * ts;
      final y0 = p.y * ts, y1 = (p.y + 1) * ts;
      final dx = math.max(math.max(x0 - x, 0.0), x - x1);
      final dy = math.max(math.max(y0 - y, 0.0), y - y1);
      if (math.sqrt(dx * dx + dy * dy) <= range) return p.zone;
    }
    return null;
  }

  /// El jefe de la zona ya cayó (abre T1).
  static bool zoneBeaten(PlayerProfile p, int zone) =>
      zone >= 10 ? p.ecosUnlocked : p.unlockedZone > zone;

  /// Tier más alto abierto en el portal de [zone] (0 = ninguno).
  static int unlockedTier(PlayerProfile p, int zone) {
    if (!zoneBeaten(p, zone)) return 0;
    return math.min(maxTier, (p.ecoTiers[zone] ?? 0) + 1);
  }

  static bool isUnlocked(PlayerProfile p, int zone, int tier) =>
      tier >= 1 && tier <= unlockedTier(p, zone);

  /// Por qué el portal T[tier] de [zone] está cerrado, o `null`.
  static String? lockReason(PlayerProfile p, int zone, int tier,
      {String? zoneName}) {
    if (!zoneBeaten(p, zone)) {
      return 'Vencé al jefe de ${zoneName ?? 'la zona $zone'} para abrir '
          'sus portales.';
    }
    if (tier > unlockedTier(p, zone)) {
      return 'Completá un Eco T${tier - 1} de esta zona para abrir el T$tier.';
    }
    return null;
  }

  /// El perfil después de completar un Eco de [zone] y [tier].
  static PlayerProfile recordCompleted(PlayerProfile p, int zone, int tier) {
    if ((p.ecoTiers[zone] ?? 0) >= tier) return p;
    return p.copyWith(ecoTiers: {...p.ecoTiers, zone: tier});
  }

  /// Cuántos Ecos de [zone] tiene, por tier (1..16).
  static Map<int, int> countByTier(PlayerProfile p, int zone) {
    final out = <int, int>{};
    for (final e in p.ecos) {
      if (e.zone == zone) out[e.tier] = (out[e.tier] ?? 0) + 1;
    }
    return out;
  }
}
