part of 'session_engine.dart';

// Mapa de viaje y exteriores de bioma (docs/specs/overworld_biomes.md).
// Todo lo decide el anfitrión: viajar (el grupo va junto) y recolectar.

extension _BiomeOp on _Op {
  /// Distancia (px) del personaje al centro de una mata para recolectar.
  static const forageReach = 26.0;

  bool biomeAction(SessionPlayer p, SessionAction a) {
    switch (a) {
      case TravelAction(:final place):
        return _travel(p, place);
      case ForageAction(:final spot):
        return _forage(p, spot);
      default:
        return false;
    }
  }

  bool _travel(SessionPlayer p, String place) {
    if (s.mode != SessionMode.lobby ||
        s.run != null ||
        s.vote != null ||
        s.prep != null ||
        p.isCompanion ||
        !_isOwner(p) ||
        !BiomeRules.canTravelTo(place)) {
      return false;
    }
    final next = place == kPueblo ? null : place;
    if (next == s.place) return false;
    s.place = next;
    e.fishing.pending.clear();
    var i = 0;
    for (final q in players) {
      final pos = spawnPos(i++);
      q
        ..x = pos.x
        ..y = pos.y
        ..fishLine = null
        ..epoch += 1;
    }
    say('El grupo viajó a ${biomeDef(place)!.name}.');
    return true;
  }

  bool _forage(SessionPlayer p, int spot) {
    if (s.mode != SessionMode.lobby ||
        s.place != kBosque ||
        p.isCompanion ||
        spot < 0 ||
        spot >= BosqueLayout.forage.length) {
      return false;
    }
    final f = BosqueLayout.forage[spot];
    final cx = (f.x + 0.5) * 16, cy = (f.y + 0.5) * 16;
    if (WorldRules.distance(p.x, p.y, cx, cy) > forageReach) return false;
    if (BiomeRules.regrowIn(s.town, kBosque, spot, s.time) > 0) return false;
    s.town = BiomeRules.pick(s.town, kBosque, spot, s.time);
    final r = BiomeRules.forage(_rand, f.kind);
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
