part of 'session_engine.dart';

// Farm animals in the room (docs/specs/animals.md): buying, daily care,
// the production cycle at each new world day and the ranch helpers. The
// host validates and applies everything; coops and barns travel inside
// the town of the snapshot.

/// Host-only animal bookkeeping (not in the snapshot).
class AnimalHostState {
  /// Cultivo XP from animals per player for the world day [day].
  final xp = <String, (int, int)>{};
}

extension _AnimalOp on _Op {
  AnimalHostState get _an => e.animals;

  int get _animalDay => math.max(1, s.town.sky.day);

  /// A new world day (animals.md § 4.2): products and affection decay.
  void animalsDay(int day) {
    for (final b in s.town.builds) {
      if (!b.kind.ranch || b.animals.isEmpty) continue;
      s.town = s.town.withBuild(AnimalRules.onDay(b, day, _fa.bgRand.nextDouble));
    }
  }

  /// One ranch helper round on [b] (animals.md § 6).
  TownBuild animalHelperRound(TownBuild b) => AnimalRules.helperCare(
      b, _animalDay, (bb, key) => TownRules.addToChest(bb, key, 1));

  /// [p] is close enough to [b] to care for its animals (≤ 2 tiles from
  /// the footprint).
  bool _nearHome(SessionPlayer p, TownBuild b) {
    final (ox, oy) = s.town.origin;
    final r = b.bounds.inflate(2);
    final tx = (p.x / 16).floor() - ox, ty = (p.y / 16).floor() - oy;
    return r.contains(tx, ty);
  }

  /// Cultivo XP from animal care with the daily cap (animals.md § 7).
  void _animalXp(SessionPlayer p, int xp) {
    if (xp <= 0 || p.isCompanion) return;
    final day = _animalDay;
    final (d, used0) = _an.xp[p.id] ?? (day, 0);
    final used = d == day ? used0 : 0;
    final n = AnimalRules.capXp(used, xp);
    _an.xp[p.id] = (day, used + n);
    if (n <= 0) return;
    final lvl0 = FarmingRules.level(p.profile);
    _profileChange(p, AnimalRules.grantXp(p.profile, n), gain: true);
    final lvl1 = FarmingRules.level(p.profile);
    if (lvl1 > lvl0) {
      say('${p.name} subió Cultivo a nivel $lvl1.');
      lifeLevelXp(p, lvl1);
    }
  }

  bool animalAction(SessionPlayer p, TownAction a) {
    if (!_inTown(p) || s.place != null) return false;
    final day = _animalDay;
    switch (a.op) {
      case TownOp.buyAnimal:
        final sp = a.id;
        if (sp == null || p.isCompanion) return false;
        final r = AnimalRules.buy(p.profile, s.town, sp);
        if (r == null) return false;
        _profileChange(p, r.$1);
        s.town = r.$2;
        say('${p.name} compró ${kAnimals[sp]!.name.toLowerCase()}.');
        return true;
      case TownOp.depositHay:
        final id = a.target;
        if (id == null) return false;
        final r = AnimalRules.depositHay(p.profile, s.town, id);
        if (r == null) return false;
        _profileChange(p, r.$1);
        s.town = r.$2;
        return true;
      case TownOp.animalFeed || TownOp.animalPet || TownOp.animalCollect:
        final b = s.town.build(a.target ?? '');
        if (b == null || !b.kind.ranch || !_nearHome(p, b)) return false;
        final uid = a.n;
        final an = b.animal(uid);
        if (an == null) return false;
        switch (a.op) {
          case TownOp.animalFeed:
            final r = AnimalRules.feed(p.profile, b, uid, day);
            if (r == null) return false;
            _profileChange(p, r.$1);
            s.town = s.town.withBuild(r.$2);
            _animalXp(p, r.$3);
          case TownOp.animalPet:
            final r = AnimalRules.pet(b, uid, day);
            if (r == null) return false;
            s.town = s.town.withBuild(r.$1);
            _animalXp(p, r.$2);
          default:
            final r = AnimalRules.collect(p.profile, b, uid);
            if (r == null) return false;
            s.town = s.town.withBuild(r.$1);
            final (ox, oy) = s.town.origin;
            final (nx, ny) = AnimalRules.nestOf(b, an);
            // Pops out like a harvest; the short magnet brings it
            // (animals.md § 4.2, loot.md § 4c).
            _spill(p, [GoodsRules.animal(r.$2, 1)], (nx + ox + 0.5) * 16,
                (ny + oy + 0.5) * 16);
            _animalXp(p, r.$3);
        }
        return true;
      default:
        return false;
    }
  }

  bool animalShop(SessionPlayer p, FarmShopAction a) {
    if (!_inTown(p) || p.isCompanion) return false;
    final prof = p.profile;
    switch (a.op) {
      case FarmShopOp.buyHay:
        return _profileChange(p, AnimalRules.buyHay(prof, a.n));
      case FarmShopOp.buyRanchTool:
        final id = a.id;
        if (id == null || !_profileChange(p, AnimalRules.buyTool(prof, id))) {
          return false;
        }
        say('${p.name} compró ${RanchTool.fromId(id)!.sourceName}.');
        return true;
      case FarmShopOp.makeHay:
        final id = a.id;
        return id != null &&
            _profileChange(p, AnimalRules.makeHay(prof, id, a.n));
      case FarmShopOp.sellGoods:
        final r = AnimalRules.sell(prof, a.id);
        if (r == null) return false;
        _profileChange(p, r.profile);
        say('${p.name} vendió ${r.sold} producto${r.sold == 1 ? '' : 's'} '
            'de granja por ${r.gold} de oro.');
        return true;
      default:
        return false;
    }
  }
}
