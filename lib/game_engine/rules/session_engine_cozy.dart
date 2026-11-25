part of 'session_engine.dart';

// Cozy life (docs/specs/cozy_life.md): tree search in the biome
// exteriors, raft decorations and compost. Host-authoritative.

extension _CozyOp on _Op {
  bool cozyAction(SessionPlayer p, CozyAction a) {
    if (s.mode != SessionMode.lobby || p.isCompanion) return false;
    switch (a.op) {
      case CozyOp.search:
        final x = a.x, y = a.y;
        return x != null && y != null && _search(p, x, y);
      case CozyOp.raftDeco:
        final id = a.id;
        if (id == null) return false;
        final next = CozyRules.raftDeco(p.profile, id);
        if (next == null) return false;
        _profileChange(p, next);
        return true;
      case CozyOp.compost:
        final id = a.id;
        if (id == null) return false;
        final farm = CozyRules.compost(p.profile.life.farm, id,
            bonus: LifeTreeRules.farm(p.profile, LifeFx.compost));
        if (farm == null) return false;
        _profileChange(
            p, p.profile.copyWith(life: p.profile.life.copyWith(farm: farm)));
        say('${p.name} preparó abono.');
        return true;
    }
  }

  /// Search the tree at ([x], [y]) of the exterior (cozy_life.md § 3):
  /// in reach, once per player per tree per day.
  bool _search(SessionPlayer p, int x, int y) {
    final lay = biomeLayout(s.place);
    if (lay == null) return false;
    final map = e.mapFor(s);
    if (x < 0 || y < 0 || x >= map.width || y >= map.height) return false;
    if (map.tileAt(x, y) != Tile.tree) return false;
    if (WorldRules.distance(p.x, p.y, (x + 0.5) * 16, (y + 0.5) * 16) >
        _BiomeOp.forageReach + 4) {
      return false;
    }
    final who = p.profile.name;
    final key = CozyRules.searchKey(who, lay.id, x, y, s.town.sky.day);
    if (s.town.daily.containsKey(key)) return false;
    s.town = s.town.copyWith(daily: {...s.town.daily, key: 1});
    final lvl0 = FarmingRules.level(p.profile);
    final life = p.profile.life;
    var farm = life.farm;
    // What falls from the branches pops out as ground loot with the
    // short magnet (cozy_life.md § 3, loot.md § 4c).
    final found = <LootDrop>[];
    // profession_gear.md § 3.1: a rare weapon seed in the branches.
    if (_rand() < GearRules.t.d('seedSearchChance')) {
      final ws = GearRules.rollSeed(_rand);
      found.add(GoodsRules.wseed(ws));
      say('${p.name} encontró ${kWeaponSeedNames[ws]} en un árbol.');
    }
    switch (CozyRules.searchRoll(_rand())) {
      case SearchFind.nothing:
        say('${p.name} buscó en un árbol: nada esta vez.');
      case SearchFind.seed:
        final seed = _pickSeed(lay.seeds);
        if (seed != null) {
          found.add(GoodsRules.seed(seed, 1));
          say('${p.name} encontró ${kCrops[seed]!.seedName}.');
        }
      case SearchFind.mushroom:
        found.add(GoodsRules.crop(
            cropKey(CozyRules.mushroom, CropQuality.normal), 1));
        say('${p.name} encontró un hongo.');
      case SearchFind.nest:
        found.add(GoodsRules.bait(CozyRules.nestBait, CozyRules.nestBaits));
        say('${p.name} encontró un nido con lombrices.');
      case SearchFind.recipe:
        final r = CozyRules.newRecipe(farm.recipes, _rand());
        if (r == null) {
          found.add(GoodsRules.fert('abono', 1));
          say('${p.name} encontró una bolsa de abono.');
        } else {
          farm = farm.copyWith(recipes: {...farm.recipes, r});
          say('${p.name} encontró una receta de abono.');
        }
    }
    farm = farm.copyWith(xp: farm.xp + CozyRules.t.i('searchXp'));
    _profileChange(p, p.profile.copyWith(life: life.copyWith(farm: farm)),
        gain: true);
    _spill(p, found, (x + 0.5) * 16, (y + 0.5) * 16 + 8);
    final lvl1 = FarmingRules.level(p.profile);
    if (lvl1 > lvl0) say('${p.name} subió Cultivo a nivel $lvl1.');
    return true;
  }

  String? _pickSeed(Map<String, double> pool) {
    if (pool.isEmpty) return null;
    final total = pool.values.fold(0.0, (a, b) => a + b);
    var r = _rand() * total;
    for (final e in pool.entries) {
      r -= e.value;
      if (r < 0) return e.key;
    }
    return pool.keys.first;
  }
}
