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
      case WaystoneAction(:final stone, :final to):
        return _waystone(p, stone, to);
      case WildLootAction(:final i, :final shrine):
        return _wildLoot(p, i, shrine);
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
    final fromShop = ShopInteriorRules.isShop(s.place);
    final next = place == kPueblo ? null : place;
    if (next == s.place && portal == null) return false;
    final moved = next != s.place;
    // What nobody picked up goes back to its owner (loot.md § 4c).
    if (moved) _recoverGround();
    final arrive = MiningRules.arrival(s.place, place, worldId: s.worldId);
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
      if (fromMine != null && portal == null && arrive == null) {
        final f = MiningRules.entranceFront(fromMine.$1, fromMine.$2);
        pos = WorldPoint(f.x + (i.isOdd ? 1 : -1) * 10.0 * ((i + 1) ~/ 2), f.y);
      }
      // Into / out of the shop (player_shop.md § 6).
      if (shopPos(fromShop, place) case final f?) {
        pos = WorldPoint(f.x + (i.isOdd ? 1 : -1) * 10.0 * ((i + 1) ~/ 2), f.y);
        pos = ShopInteriorRules.safeLanding(place, s.town, pos);
      }
      // Between mine levels (mining_smithing.md § 1.4).
      if (arrive != null) {
        pos = WorldPoint(
            arrive.x + (i.isOdd ? 1 : -1) * 8.0 * ((i + 1) ~/ 2), arrive.y);
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

  /// Where a player lands entering or leaving the shop, or `null`.
  WorldPoint? shopPos(bool fromShop, String place) {
    if (ShopInteriorRules.isShop(place)) return ShopInteriorRules.arrival;
    if (fromShop) {
      return ShopInteriorRules.townFront(
          TownPlan.landmarksOf(s.town), s.town.origin);
    }
    return null;
  }

  /// Biomes need the zone unlocked; a mine is entered from its biome and
  /// left back to it (mining_smithing.md § 1.1).
  bool _canGo(SessionPlayer p, String place) {
    if (ShopInteriorRules.isShop(place) || ShopInteriorRules.isShop(s.place)) {
      return ShopInteriorRules.canTravel(s.place, place);
    }
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
    s.town = BiomeRules.pick(s.town, biome, spot, s.time,
        respawn: BiomeRules.respawnOf(f.kind));
    // Region forage (biome_regions.md § 5): plants, seed bushes,
    // seasonal sprouts and echo blooms.
    final r = BiomeRules.forageSpot(_rand, f.kind, lay.seeds,
        season: WeatherRules.season(s.town.sky.day));
    final crop = r.item == null ? null : kCrops[r.item];
    final seedCrop = r.seed == null ? null : kCrops[r.seed];
    if (crop == null && seedCrop == null) return false;
    final lvl0 = FarmingRules.level(p.profile);
    var farm = p.profile.life.farm;
    // Recolectar cuenta como Cultivo (overworld_biomes.md § 3.2).
    final rar = (crop ?? seedCrop)!.rarity.index + 1;
    farm = farm.copyWith(
        xp: farm.xp +
            (BiomeRules.t.i('forageXp') * rar * BiomeRules.xpMul(f.kind))
                .round());
    _profileChange(
        p, p.profile.copyWith(life: p.profile.life.copyWith(farm: farm)),
        gain: true);
    events.add(
        CropHarvestedEvent(p.id, (crop ?? seedCrop)!.id, 0, 1, f.x, f.y));
    // The pick pops out of the bush; the magnet brings it (loot.md § 4c).
    _spill(p, [
      if (crop != null) GoodsRules.crop(cropKey(crop.id, CropQuality.normal), 1),
      if (r.seed != null) GoodsRules.seed(r.seed!, 1),
    ], cx, cy);
    final seed = seedCrop == null ? '' : seedCrop.seedName;
    say(crop == null
        ? '${p.name} recolectó $seed.'
        : '${p.name} recolectó ${crop.name}${seed.isEmpty ? '' : ' y $seed'}.');
    final lvl1 = FarmingRules.level(p.profile);
    if (lvl1 > lvl0) say('${p.name} subió Granjero a nivel $lvl1.');
    return true;
  }

  /// Activates the waystone [stone] in reach, or travels from it to the
  /// active stone [to] (biome_regions.md § 4). Only the traveller moves.
  bool _waystone(SessionPlayer p, int stone, int? to) {
    if (s.mode != SessionMode.lobby || p.isCompanion) return false;
    final lay = biomeLayout(s.place);
    if (lay == null) return false;
    final who = p.profile.name;
    if (WaystoneRules.near(lay, p.x, p.y) != stone) return false;
    if (to == null) {
      final next = WaystoneRules.activate(s.town, who, lay, stone);
      if (identical(next, s.town)) return false;
      s.town = next;
      say('${p.name} activó una piedra de paso.');
      return true;
    }
    if (WaystoneRules.blocked(s.town, who, lay, p.x, p.y, to) != null) {
      return false;
    }
    final a = WaystoneRules.arrival(lay, to);
    p
      ..x = a.x
      ..y = a.y
      ..fishLine = null
      ..epoch += 1;
    return true;
  }

  /// A wilds chest or shrine (biome_exploration.md § 3.3–3.4): once per
  /// player per day, in reach.
  bool _wildLoot(SessionPlayer p, int i, bool shrine) {
    if (s.mode != SessionMode.lobby || p.isCompanion) return false;
    final lay = biomeLayout(s.place);
    if (lay == null) return false;
    final spots = shrine ? lay.shrines : lay.chestSpots;
    if (i < 0 || i >= spots.length) return false;
    final (tx, ty) = spots[i];
    if (WorldRules.distance(p.x, p.y, (tx + 0.5) * 16, (ty + 0.5) * 16) >
        forageReach) {
      return false;
    }
    final day = s.town.sky.day;
    final key = WildLootRules.lootKey(p.profile.name, lay.id, i, day,
        shrine: shrine);
    if (s.town.daily.containsKey(key)) return false;
    s.town = s.town.copyWith(daily: {...s.town.daily, key: 1});
    final ores = kBiomeOres[lay.id];
    // Everything spills on the ground like a dungeon chest (§ 3.3–3.4):
    // a shrine drops in front of it (one tile below), a chest on itself.
    final cx = (tx + 0.5) * 16, cy = (ty + 0.5) * 16;
    if (shrine) {
      // A blessing: gold and the biome's rare material.
      final gold = WildLootRules.t.i('shrineGold');
      say('${p.name} recibió la bendición del santuario.');
      _spill(p, [
        GoodsRules.goldDrop(gold),
        if (ores != null) GoodsRules.ore(ores.rare, 1),
      ], cx, cy + 16);
      return true;
    }
    final def = kChestTiers[ChestTier.madera]!;
    final lvlP = math.max(1, p.profile.level);
    final cr = ((15 + (_rand() * 26).floor()) * def.creditMult).round();
    say('${p.name} abrió un cofre escondido.');
    _spill(p, [
      GoodsRules.goldDrop(cr),
      if (ores != null) GoodsRules.ore(ores.ore, 2),
      ..._chestDrops(p, def, lvlP),
    ], cx, cy);
    return true;
  }

  /// Waystones are discovered on touch (biome_exploration.md § 5).
  void waystoneTouchTick() {
    final lay = biomeLayout(s.place);
    if (lay == null) return;
    for (final q in players) {
      if (q.isCompanion) continue;
      final i = WaystoneRules.near(lay, q.x, q.y);
      if (i == null) continue;
      final next = WaystoneRules.activate(s.town, q.profile.name, lay, i);
      if (identical(next, s.town)) continue;
      // Silent: walking past is not news for the whole room's chat.
      s.town = next;
    }
  }

  /// The party draws the overworld map by walking (biome_exploration.md
  /// § 11.4): host-authoritative, shared, saved with the world.
  void mapRevealTick() {
    final lay = biomeLayout(s.place);
    if (lay == null) return;
    s.town = MapDiscoveryRules.reveal(s.town, lay, [
      for (final q in players)
        if (!q.isCompanion) (q.x, q.y)
    ]);
  }

  /// Regrowth out of view (biome_regions.md § 5.2), every lobby tick.
  void forageHoldTick() {
    waystoneTouchTick();
    mapRevealTick();
    final lay = biomeLayout(s.place);
    if (lay == null || s.town.wild.isEmpty) return;
    s.town = BiomeRules.holdInView(s.town, lay.id, lay.forage,
        [for (final q in players) (q.x, q.y)], s.time);
  }
}
