part of 'session_engine.dart';

// Mines v2, carts, smelting and forging weapons
// (docs/specs/mining_smithing.md). Everything is decided by the host.

/// A lit bomb waiting for its fuse (host only).
class PendingBomb {
  PendingBomb(this.place, this.x, this.y, this.at, this.owner);
  final String place;
  final int x, y;
  final double at;
  final String owner;
}

/// Mining state of the host (not in the snapshot): swing clocks, crack
/// damage per tile, boosters, lit bombs and the miners' clock.
class MiningHostState {
  final lastSwing = <String, double>{};

  /// `<place>|<tile>` → hits dealt so far.
  final cracks = <String, int>{};

  /// Player → room second the booster ends.
  final boost = <String, double>{};
  final bombs = <PendingBomb>[];
  double stepAcc = 0;
  double seenAcc = 0;
}

extension _MiningOp on _Op {
  MiningHostState get _mh => e.mining;
  TuningDef get _mt => MiningRules.t;

  bool miningAction(SessionPlayer p, SessionAction a) {
    switch (a) {
      case MineAction():
        return _mine(p, a);
      case SmithAction():
        return _smith(p, a);
      default:
        return false;
    }
  }

  bool _boosted(SessionPlayer p) => (_mh.boost[p.id] ?? -1) > s.time;

  /// The mine level the room is in, with its state, or `null`.
  (String, MineLevel, MineLevelState)? get _level {
    final place = s.place;
    final lvl = MiningRules.level(place, worldId: s.worldId);
    if (place == null || lvl == null) return null;
    return (place, lvl, s.town.mine(place));
  }

  bool _reaches(SessionPlayer p, int x, int y) =>
      WorldRules.distance(p.x, p.y, (x + 0.5) * 16, (y + 0.5) * 16) <=
      MiningRules.t.d('mineReach') + 10;

  bool _mine(SessionPlayer p, MineAction a) {
    if (s.mode != SessionMode.lobby || s.run != null || p.isCompanion) {
      return false;
    }
    switch (a.op) {
      case MineOp.unload:
        return _unloadCart(p, a.id);
      case MineOp.buy:
        return _buyMine(p, a.id, a.n);
      case MineOp.craft:
        return _craftMine(p, a.id, a.mat);
      case MineOp.sell:
        return _sellMine(p, a.id, a.n);
      default:
    }
    final lv = _level;
    if (lv == null) return false;
    final (place, lvl, st) = lv;
    switch (a.op) {
      case MineOp.dig:
        return _dig(p, place, lvl, st, a.x, a.y);
      case MineOp.bomb:
        if (p.profile.life.ore(kMineBomb) <= 0 || !_reaches(p, a.x, a.y)) {
          return false;
        }
        _profileChange(p, MiningRules.give(p.profile, {kMineBomb: -1}));
        final fuse = _mt.d('bombFuse');
        _mh.bombs.add(PendingBomb(place, a.x, a.y, s.time + fuse, p.id));
        events.add(MineBombEvent(a.x, a.y, fuse));
        return true;
      case MineOp.torch:
        if (p.profile.life.ore(kMineTorch) <= 0 ||
            !_reaches(p, a.x, a.y) ||
            !MiningRules.canTorch(lvl, st, a.x, a.y)) {
          return false;
        }
        _profileChange(p, MiningRules.give(p.profile, {kMineTorch: -1}));
        s.town = s.town.withMine(
            place, st.copyWith(torches: {...st.torches, lvl.idx(a.x, a.y)}));
        return true;
      case MineOp.boost:
        if (p.profile.life.ore(kVeinOil) <= 0) return false;
        _profileChange(p, MiningRules.give(p.profile, {kVeinOil: -1}));
        _mh.boost[p.id] = s.time + _mt.d('boostSec');
        say('${p.name} untó su pico con Aceite de veta.');
        return true;
      case MineOp.use:
        return _useTile(p, place, lvl, st, a.x, a.y);
      case MineOp.hire:
        if (!st.station || st.miners.length >= _mt.i('minerMax')) return false;
        if (p.profile.credits < _mt.i('minerCost')) return false;
        _profileChange(
            p, p.profile.copyWith(credits: p.profile.credits - _mt.i('minerCost')));
        final (mx, my) = MineWorkRules.minerSpawn(lvl);
        s.town = s.town.withMine(
            place, st.copyWith(miners: [...st.miners, MinerState(mx, my)]));
        say('${p.name} contrató un minero para ${MiningRules.placeName(place)}.');
        return true;
      case MineOp.upgrade:
        // Raise the pick of the miner [a.n] by one tier (§ 1.7).
        final k = a.n;
        if (k < 0 || k >= st.miners.length) return false;
        final m = st.miners[k];
        final c = MineWorkRules.upgradeCost(m.tier + 1);
        if (c == null) return false;
        if (p.profile.credits < c.gold || p.profile.life.ore(c.ingot) < c.n) {
          return false;
        }
        _profileChange(
            p,
            MiningRules.give(p.profile, {c.ingot: -c.n})
                .copyWith(credits: p.profile.credits - c.gold));
        final miners = [...st.miners]..[k] = m.copyWith(tier: m.tier + 1);
        s.town = s.town.withMine(place, st.copyWith(miners: miners));
        say('${p.name} mejoró el pico de un minero (nivel ${m.tier + 1}).');
        return true;
      case MineOp.fire:
        if (st.miners.isEmpty) return false;
        s.town = s.town.withMine(place,
            st.copyWith(miners: st.miners.sublist(0, st.miners.length - 1)));
        return true;
      default:
        return false;
    }
  }

  bool _dig(SessionPlayer p, String place, MineLevel lvl, MineLevelState st,
      int x, int y) {
    if (!_reaches(p, x, y)) return false;
    final tool = MiningRules.tool(p.profile);
    final last = _mh.lastSwing[p.id] ?? -99;
    // Pico sub-path A (life_trees_v2.md § 2.1): faster swings.
    if (s.time - last < tool.swing * 0.6 * GearRules.swingMult(p.profile)) {
      return false;
    }
    final code = MiningRules.tileAt(lvl, st, x, y);
    if (MiningRules.cannotBreak(code, lvl.level, tool) != null) return false;
    _mh.lastSwing[p.id] = s.time;
    final key = '$place|${lvl.idx(x, y)}';
    final dealt = (_mh.cracks[key] ?? 0) + tool.power;
    if (dealt < MiningRules.hits(code, lvl.level)) {
      _mh.cracks[key] = dealt;
      return true;
    }
    _mh.cracks.remove(key);
    _breakTile(p, place, lvl, x, y, tool.yieldBonus);
    // Veta sub-path A: the blow also breaks veins around it.
    if (MineTile.veins.contains(code)) {
      var left = GearRules.veinArea(p.profile);
      for (final (vx, vy) in squareTiles(x, y, 1)) {
        if (left <= 0) break;
        if (vx == x && vy == y) continue;
        final c = MiningRules.tileAt(lvl, s.town.mine(place), vx, vy);
        if (!MineTile.veins.contains(c) ||
            MiningRules.cannotBreak(c, lvl.level, tool) != null) {
          continue;
        }
        _breakTile(p, place, lvl, vx, vy, tool.yieldBonus);
        left--;
      }
    }
    return true;
  }

  /// Breaks ([x], [y]) for [p]: the level changes for everyone, [p] gets
  /// what it held.
  void _breakTile(SessionPlayer p, String place, MineLevel lvl, int x, int y,
      double toolBonus) {
    final st = s.town.mine(place);
    final code = MiningRules.tileAt(lvl, st, x, y);
    s.town = s.town.withMine(place, MiningRules.dig(lvl, st, x, y, s.time));
    var got = MiningRules.veinYield(_rand, lvl.biome,
        code: code,
        toolBonus: toolBonus,
        boosted: _boosted(p),
        day: s.town.sky.day,
        rareBonus: LifeTreeRules.smith(p.profile, LifeFx.rareOre));
    if (code == MineTile.wallTorch) got = {kMineTorch: 1};
    // Sometimes a bait comes out of a vein (fishing.md § 14.4).
    if (MineTile.veins.contains(code)) {
      if (MiningRules.veinBait(_rand) case final bait?) {
        p.profile = p.profile.copyWith(life: p.profile.life.addBait(bait));
      }
    }
    if (got.isNotEmpty) {
      _profileChange(
          p,
          MiningRules.give(p.profile, got,
              source: MiningRules.mineSource(lvl.biome), day: s.town.sky.day),
          gain: true);
    }
    events.add(MineDugEvent(p.id, x, y, code, _oreText(got)));
    smithXp(p, MiningRules.digXp(lvl.biome, code));
  }

  bool _useTile(SessionPlayer p, String place, MineLevel lvl,
      MineLevelState st, int x, int y) {
    if (!_reaches(p, x, y)) return false;
    final code = MiningRules.tileAt(lvl, st, x, y);
    final i = lvl.idx(x, y);
    switch (code) {
      case MineTile.chest || MineTile.relic:
        s.town = s.town.withMine(place, st.copyWith(opened: {...st.opened, i}));
        final relic = code == MineTile.relic;
        final def = kChestTiers[relic ? ChestTier.oro : ChestTier.madera]!;
        final lvlP = math.max(1, p.profile.level);
        final cr = ((15 + (_rand() * 26).floor()) * def.creditMult).round();
        final drops = <LootDrop>[
          GoodsRules.goldDrop(cr),
          ..._chestDrops(p, def, lvlP),
        ];
        events.add(MineDugEvent(p.id, x, y, code, ''));
        // profession_gear.md § 3.1: cave chests may hold a weapon seed.
        if (_rand() < GearRules.t.d('seedMineChestChance')) {
          final ws = GearRules.rollSeed(_rand, ancientBonus: relic ? 0.25 : 0);
          drops.add(GoodsRules.wseed(ws));
        }
        say(relic
            ? '${p.name} abrió un cofre reliquia magitec.'
            : '${p.name} abrió un cofre de la mina.');
        // Spills on the ground like a dungeon chest (mining_smithing.md
        // § 1.3, loot.md § 4c).
        _spill(p, drops, (x + 0.5) * 16, (y + 0.5) * 16);
        return true;
      case MineTile.mushroom:
        s.town = s.town.withMine(place, st.copyWith(opened: {...st.opened, i}));
        final life = p.profile.life;
        _profileChange(
            p,
            p.profile.copyWith(
                life: life.copyWith(
                    crafts: {...life.crafts, 'fibra': life.craft('fibra') + 2})),
            gain: true);
        events.add(MineDugEvent(p.id, x, y, code, '+2'));
        return true;
      case MineTile.station:
        if (st.station) return false;
        final ing = kBiomeOres[kBosque]!.ingot;
        final gold = _mt.i('stationGold'), n = _mt.i('stationIngots');
        if (p.profile.credits < gold || p.profile.life.ore(ing) < n) {
          return false;
        }
        _profileChange(
            p,
            MiningRules.give(p.profile, {ing: -n})
                .copyWith(credits: p.profile.credits - gold));
        s.town = s.town.withMine(place, st.copyWith(station: true));
        say('${p.name} armó la estación de vagonetas de '
            '${MiningRules.placeName(place)}.');
        return true;
      default:
        return false;
    }
  }

  bool _unloadCart(SessionPlayer p, String? place) {
    if (place == null || s.place != null) return false;
    final st = s.town.mines[place];
    if (st == null) return false;
    final r = MineWorkRules.unload(st, s.time);
    if (r == null) return false;
    s.town = s.town.withMine(place, r.$1);
    final m = MiningRules.parse(place);
    _profileChange(
        p,
        MiningRules.give(p.profile, r.$2,
            source: m == null ? null : MiningRules.mineSource(m.$1),
            day: s.town.sky.day),
        gain: true);
    say('${p.name} descargó la vagoneta de ${MiningRules.placeName(place)} '
        '(${_oreText(r.$2)}).');
    return true;
  }

  bool _buyMine(SessionPlayer p, String? id, int n) {
    if (id == null || n < 1 || s.place != null) return false;
    final price = MiningRules.price(id);
    final tool = mineTool(id);
    if (price <= 0 || (tool != null && (tool.tier == 0 || n != 1))) {
      return false;
    }
    if (tool != null && p.profile.life.ore(id) > 0) return false;
    if (p.profile.credits < price * n) return false;
    _profileChange(
        p,
        MiningRules.give(p.profile, {id: n})
            .copyWith(credits: p.profile.credits - price * n));
    return true;
  }

  bool _craftMine(SessionPlayer p, String? id, String? ore) {
    if (id == null || s.place != null) return false;
    final rec = MiningRules.recipe(id, ore ?? kBiomeOres[kBosque]!.ore);
    if (rec == null) return false;
    if (ore != null && kSmithMaterials[ore]?.kind != SmithMatKind.ore) {
      return false;
    }
    if (mineTool(id) != null && p.profile.life.ore(id) > 0) return false;
    for (final e in rec.mats.entries) {
      if (p.profile.life.ore(e.key) < e.value) return false;
    }
    if (p.profile.credits < rec.gold) return false;
    _profileChange(
        p,
        MiningRules.give(p.profile, {
          for (final e in rec.mats.entries) e.key: -e.value,
          id: rec.n,
        }).copyWith(credits: p.profile.credits - rec.gold));
    smithXp(p, _mt.i('smeltXp'));
    return true;
  }

  bool _sellMine(SessionPlayer p, String? id, int n) {
    if (id == null || n < 1 || s.place != null) return false;
    final price = SmithCraftRules.sellPrice(id);
    if (price <= 0 || p.profile.life.ore(id) < n) return false;
    _profileChange(
        p,
        MiningRules.give(p.profile, {id: -n})
            .copyWith(credits: p.profile.credits + price * n));
    return true;
  }

  /// Bombs, veins growing back where nobody looks, miners and carts.
  /// [world]: this room runs the world clocks (miners, carts).
  void mineTick(double dt, bool world) {
    if (_mh.bombs.isNotEmpty) {
      final due = [
        for (final b in _mh.bombs)
          if (b.at <= s.time && b.place == s.place) b
      ];
      for (final b in due) {
        _mh.bombs.remove(b);
        _blast(b);
      }
    }
    if (_level case (final place, final lvl, final st)
        when st.regrow.isNotEmpty) {
      final next = MineWorkRules.regrowTick(lvl, st, s.time,
          [for (final p in players) (p.x / 16, p.y / 16)], _rand);
      if (!identical(next, st)) s.town = s.town.withMine(place, next);
    }
    // Veins each player discovers (minimap, § 1.11), twice a second.
    _mh.seenAcc += dt;
    if (_mh.seenAcc >= 0.5) {
      _mh.seenAcc = 0;
      if (_level case (final place, final lvl, final st0)) {
        var st = st0;
        for (final p in players) {
          if (p.isCompanion) continue;
          st = MineWorkRules.discover(
              lvl, st, p.profile.name, p.x / 16, p.y / 16,
              detect: GearRules.detectRadius(p.profile));
        }
        if (!identical(st, st0)) s.town = s.town.withMine(place, st);
      }
    }
    if (!world || s.town.mines.isEmpty) return;
    _mh.stepAcc += dt;
    final step = math.max(0.1, _mt.d('minerStepSec'));
    final work = _mh.stepAcc >= step;
    if (work) _mh.stepAcc -= step;
    var mines = s.town.mines;
    var changed = false;
    for (final e in s.town.mines.entries) {
      var st = e.value;
      final cart = MineWorkRules.cartTick(st.cart, s.time);
      if (!identical(cart, st.cart)) st = st.copyWith(cart: cart);
      if (work && st.miners.isNotEmpty) {
        final lvl = MiningRules.level(e.key, worldId: s.worldId);
        if (lvl != null) {
          final before = st.cart.phase;
          st = MineWorkRules.minerStep(lvl, st, s.time, _rand);
          if (before == CartPhase.mine && st.cart.phase == CartPhase.toTown) {
            say('La vagoneta de ${MiningRules.placeName(e.key)} salió '
                'llena hacia el pueblo.');
          }
        }
      }
      if (!identical(st, e.value)) {
        if (!changed) mines = {...mines};
        changed = true;
        mines[e.key] = st;
      }
    }
    if (changed) s.town = s.town.copyWith(mines: mines);
  }

  void _blast(PendingBomb b) {
    final lv = _level;
    if (lv == null) return;
    final (place, lvl, st) = lv;
    final owner = s.players[b.owner];
    final tiles = MiningRules.bombTiles(lvl, st, b.x, b.y);
    events.add(MineBlastEvent(b.x, b.y, _mt.i('bombRadius')));
    if (owner == null) {
      var cur = st;
      for (final (x, y) in tiles) {
        cur = MiningRules.dig(lvl, cur, x, y, s.time);
      }
      s.town = s.town.withMine(place, cur);
      return;
    }
    final bonus = MiningRules.tool(owner.profile).yieldBonus;
    for (final (x, y) in tiles) {
      _breakTile(owner, place, lvl, x, y, bonus);
    }
  }

  String _oreText(Map<String, int> got) => [
        for (final e in got.entries)
          '${e.value} ${kSmithMaterials[e.key]?.name ?? e.key}'
      ].join(', ');

  bool _smith(SessionPlayer p, SmithAction a) {
    // At the town FORGE only (not the Travesía, not a biome or a mine).
    if (!_inTown(p) || s.place != null) return false;
    switch (a.op) {
      case SmithOp.smelt:
        final next = SmithCraftRules.smelt(p.profile, a.material, a.n,
            day: s.town.sky.day);
        if (next == null) return false;
        _profileChange(p, next);
        say('${p.name} fundió ${a.n} '
            '${kSmithMaterials[ingotOf(a.material)]?.name ?? a.material}.');
        // Fundición sub-path A (life_trees_v2.md § 2.1): double ingots.
        final dbl = GearRules.smeltDouble(p.profile);
        if (dbl > 0 && _rand() < dbl) {
          if (ingotOf(a.material) case final ing?) {
            _profileChange(p, MiningRules.give(p.profile, {ing: a.n}));
            say('La fundición de ${p.name} rindió el doble.');
          }
        }
        smithXp(p, SmithCraftRules.smeltXp(a.material, a.n));
        return true;
      case SmithOp.fishForge:
        // profession_gear.md § 4.2: Brann forges a legendary fish.
        final r =
            GearRules.fishForge(rules.loot, _rand, p.profile, a.material);
        if (r == null) return false;
        _profileChange(p, r.$1);
        say('Brann forjó para ${p.name} un arma de '
            '${kFish[a.material]?.name ?? a.material}.');
        smithXp(p, SmithRules.t.i('smithXpCommission'));
        _deliver(p, [LootDrop.item(r.$2)], LootSource.mission, p.x, p.y,
            stashOverflow: true);
        return true;
      case SmithOp.forgeParts:
        // profession_gear_v2.md § 3: forge by parts, step by step.
        final type = a.base;
        if (type == null) return false;
        final r = GearV2Rules.forge(rules.loot, _rand, p.profile, type,
            [a.material, ...a.parts]);
        if (r == null) return false;
        _profileChange(p, r.$1);
        say('${p.name} forjó por piezas: '
            '${r.$2.rarity.label.toLowerCase()} de nivel ${r.$2.itemLevel}'
            '${r.$2.masterwork ? ' (obra maestra)' : ''}.');
        smithXp(p, SmithCraftRules.forgeXp(r.$2.rarity));
        _deliver(p, [LootDrop.item(r.$2)], LootSource.mission, p.x, p.y,
            stashOverflow: true);
        return true;
      case SmithOp.animalForge:
        // animals.md § 10: Brann forges a legendary animal product.
        final r =
            GearRules.animalForge(rules.loot, _rand, p.profile, a.material);
        if (r == null) return false;
        _profileChange(p, r.$1);
        say('Brann forjó para ${p.name} un arma de '
            '${kAnimalProducts[a.material]?.name ?? a.material}.');
        smithXp(p, SmithRules.t.i('smithXpCommission'));
        _deliver(p, [LootDrop.item(r.$2)], LootSource.mission, p.x, p.y,
            stashOverflow: true);
        return true;
      case SmithOp.fishSplit:
        // profession_gear_v2.md § 4: Brann takes a fish apart (it's gone).
        final next = GearV2Rules.split(p.profile, a.material);
        if (next == null) return false;
        _profileChange(p, next);
        say('Brann desarmó un ${kFish[a.material]?.name ?? a.material} '
            'para ${p.name}.');
        return true;
      case SmithOp.forge || SmithOp.brann:
        if (a.rarity < 0 || a.rarity >= Rarity.values.length) return false;
        final r = Rarity.values[a.rarity];
        final brann = a.op == SmithOp.brann;
        final b = s.town.resident('brann');
        final cap = brann
            ? Rarity.values[ResidentRules.commissionRarity(b,
                fishLv: FishingRules.level(p.profile),
                farmLv: FarmingRules.level(p.profile),
                smithLv: SmithRules.level(p.profile))]
            : SmithCraftRules.maxRarity(SmithRules.level(p.profile));
        final base = a.base == null ? null : catalog.weapons[a.base];
        if (SmithCraftRules.cannotForge(p.profile, base, a.material, r,
                maxRarity: cap,
                brann: brann,
                brannHome: b.invited && b.house > 0) !=
            null) {
          return false;
        }
        final c = SmithCraftRules.cost(p.profile.level, a.material, r,
            brann: brann)!;
        final paid =
            SmithCraftRules.pay(p.profile, a.material, r, brann: brann);
        if (paid == null) return false;
        _profileChange(p, paid);
        var item =
            SmithCraftRules.make(rules.loot, _rand, base!, r, c.itemLevel);
        if (!brann && item.rarity != Rarity.legendario) {
          // profession_gear.md § 5: sometimes a forge-only weapon comes
          // out instead, same rarity and level (marked as forged).
          if (GearRules.forgeGear(_rand, p.profile) case final g?) {
            final gi = GearRules.makeDef(
                rules.loot, _rand, g, item.rarity, item.itemLevel);
            item = gi.copyWith(uid: '$kForgedUidPrefix${gi.uid}');
          }
          // Forja sub-path B: one more affix, or one rarity up.
          item = GearRules.forgeAffix(rules.loot, _rand, p.profile, item);
        }
        say('${brann ? 'Brann' : p.name} forjó para ${p.name}: '
            '${item.rarity.label.toLowerCase()} de nivel ${item.itemLevel}.');
        smithXp(
            p,
            brann
                ? SmithRules.t.i('smithXpCommission') ~/ 2
                : SmithCraftRules.forgeXp(r));
        _deliver(p, [LootDrop.item(item)], LootSource.mission, p.x, p.y,
            stashOverflow: true);
        return true;
    }
  }

  /// A rare dungeon vein (mining_smithing.md § 1.4).
  void _mineDungeonVein(SessionPlayer p, int zone) {
    if (p.isCompanion) return;
    final got = MiningRules.dungeonYield(_rand, zone, day: s.town.sky.day);
    _profileChange(
        p,
        MiningRules.give(p.profile, got,
            source: MiningRules.dungeonSource(zone), day: s.town.sky.day),
        gain: true);
    say('${p.name} picó una veta rara (${_oreText(got)}).');
    smithXp(p, MiningRules.t.i('mineXp') * 2);
  }

  /// Guardian cores for everyone who beat a zone boss (§ 1.5).
  void _bossCores() {
    final n = MiningRules.t.i('bossCore');
    if (n <= 0 || s.run != null || s.tutorial != null) return;
    for (final q in players) {
      if (q.isCompanion) continue;
      _profileChange(q, MiningRules.give(q.profile, {kGuardianCore: n},
              source: 'boss', day: s.town.sky.day),
          gain: true);
    }
    say('El guardián dejó $n ${kSmithMaterials[kGuardianCore]!.name}.');
  }
}
