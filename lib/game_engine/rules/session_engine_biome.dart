part of 'session_engine.dart';

// Mapa de viaje y exteriores de bioma (docs/specs/overworld_biomes.md).
// Todo lo decide el anfitrión: viajar (el grupo va junto) y recolectar.

extension _BiomeOp on _Op {
  /// Distancia (px) del personaje al centro de una mata para recolectar.
  static const forageReach = 26.0;

  bool biomeAction(SessionPlayer p, SessionAction a) {
    switch (a) {
      case TravelAction(:final place, :final ecoZone):
        return _travel(p, place, ecoZone);
      case ForageAction(:final spot):
        return _forage(p, spot);
      default:
        return false;
    }
  }

  bool _travel(SessionPlayer p, String place, [int? ecoZone]) {
    final portal = ecoZone == null ? null : EcoPortalRules.of(ecoZone);
    if (ecoZone != null && portal?.biome != place) return false;
    if (s.mode != SessionMode.lobby ||
        s.run != null ||
        s.vote != null ||
        s.prep != null ||
        p.isCompanion ||
        !_isOwner(p) ||
        !_canGo(p, place)) {
      return false;
    }
    final fromMine = MiningRules.parse(s.place);
    final next = place == kPueblo ? null : place;
    if (next == s.place && portal == null) return false;
    final moved = next != s.place;
    s.place = next;
    e.fishing.pending.clear();
    var i = 0;
    for (final q in players) {
      var pos = spawnPos(i);
      // ECOS: frente al portal de esa zona (ecos_zone.md § 5).
      if (portal != null) {
        final f = portal.front;
        pos = WorldPoint(f.x + (i.isOdd ? 1 : -1) * 10.0 * ((i + 1) ~/ 2), f.y);
      }
      // Out of a mine: in front of its entrance (mining_smithing.md § 1.1).
      if (fromMine != null && portal == null) {
        final f = MiningRules.entranceFront(fromMine.$1, fromMine.$2);
        pos = WorldPoint(f.x + (i.isOdd ? 1 : -1) * 10.0 * ((i + 1) ~/ 2), f.y);
      }
      i++;
      q
        ..x = pos.x
        ..y = pos.y
        ..fishLine = null
        ..epoch += 1;
    }
    if (moved) say('El grupo viajó a ${MiningRules.placeName(place)}.');
    return true;
  }

  /// Biomes need the zone unlocked; a mine is entered from its biome and
  /// left back to it (mining_smithing.md § 1.1).
  bool _canGo(SessionPlayer p, String place) {
    if (MiningRules.isMine(place) || MiningRules.isMine(s.place)) {
      return MiningRules.canTravel(s.place, place);
    }
    return BiomeRules.canTravelTo(place,
        unlockedZone: ZoneRules.unlockedZone(p.profile));
  }

  bool _forage(SessionPlayer p, int spot) {
    if (s.mode != SessionMode.lobby ||
        p.isCompanion) {
      return false;
    }
    final lay = biomeLayout(s.place);
    if (lay == null || spot < 0 || spot >= lay.forage.length) return false;
    final biome = lay.id;
    final f = lay.forage[spot];
    final cx = (f.x + 0.5) * 16, cy = (f.y + 0.5) * 16;
    if (WorldRules.distance(p.x, p.y, cx, cy) > forageReach) return false;
    if (BiomeRules.regrowIn(s.town, biome, spot, s.time) > 0) return false;
    s.town = BiomeRules.pick(s.town, biome, spot, s.time);
    final r = BiomeRules.forage(_rand, f.kind, lay.seeds);
    final crop = kCrops[r.item]!;
    final lvl0 = FarmingRules.level(p.profile);
    var farm = p.profile.life.farm.addCrop(cropKey(crop.id, CropQuality.normal));
    if (r.seed != null) farm = farm.addSeed(r.seed!);
    // Recolectar cuenta como Cultivo (overworld_biomes.md § 3.2).
    farm = farm.copyWith(
        xp: farm.xp + BiomeRules.t.i('forageXp') * (crop.rarity.index + 1));
    _profileChange(
        p, p.profile.copyWith(life: p.profile.life.copyWith(farm: farm)),
        gain: true);
    events.add(CropHarvestedEvent(p.id, crop.id, 0, 1, f.x, f.y));
    final seed = r.seed == null ? '' : ' y ${kCrops[r.seed]!.seedName}';
    say('${p.name} recolectó ${crop.name}$seed.');
    final lvl1 = FarmingRules.level(p.profile);
    if (lvl1 > lvl0) say('${p.name} subió Cultivo a nivel $lvl1.');
    return true;
  }
}
