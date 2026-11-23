part of 'session_engine.dart';

// Huerta, mejoras del pueblo y árboles de oficios en la sala
// (docs/specs/farming.md § 10, life_skill_trees.md § 4). Todo lo valida y
// otorga el anfitrión; el pueblo (`GameSession.town`) viaja en el estado.

/// Estado de la huerta del anfitrión (no viaja en el snapshot).
class FarmingHostState {
  final lastWork = <String, double>{};

  /// XP de personaje ganada cultivando en esta estadía en el pueblo.
  final charXp = <String, int>{};

  /// Segundos sin aplicar al crecimiento (se aplica de a 1 s).
  double acc = 0;

  /// Segundos hasta la próxima vuelta del ayudante.
  double helperIn = 0;

  void newStay() => charXp.clear();
}

extension _FarmingOp on _Op {
  FarmingHostState get _fa => e.farming;
  TuningDef get _fat => FarmingRules.t;

  /// El dueño del mundo: el primer humano de la sala (el anfitrión).
  bool _isOwner(SessionPlayer p) => humans.firstOrNull?.id == p.id;

  bool farmingAction(SessionPlayer p, SessionAction a) {
    switch (a) {
      case FarmTileAction():
        return _farmTile(p, a);
      case FarmShopAction():
        return _farmShop(p, a);
      case TownAction():
        return _townAction(p, a);
      case LifeTreeAction(:final skill, :final node):
        final k = LifeSkillKind.values.where((v) => v.name == skill).firstOrNull;
        if (k == null || p.isCompanion) return false;
        final next = node == null
            ? LifeTreeRules.reset(p.profile, k)
            : LifeTreeRules.take(p.profile, k, node);
        return _profileChange(p, next);
      default:
        return false;
    }
  }

  // ---------------- crecimiento ----------------

  /// Corre siempre (pueblo, campo y batalla): la huerta crece mientras la
  /// sala está abierta. De a 1 s para no mover el estado en cada cuadro.
  void farmTick(double dt) {
    if (s.run != null) return;
    _fa.acc += dt;
    if (_fa.acc < 1) return;
    final step = _fa.acc;
    _fa.acc = 0;
    final t = s.town;
    if (t.plots.isNotEmpty) {
      var changed = false;
      final out = <String, FarmPlot>{};
      for (final e in t.plots.entries) {
        final g = FarmingRules.grow(e.value, step);
        if (g != e.value) changed = true;
        out[e.key] = g;
      }
      if (changed) s.town = t.copyWith(plots: out);
    }
    if (s.town.helper > 0) {
      _fa.helperIn -= step;
      if (_fa.helperIn <= 0) {
        _fa.helperIn = TownRules.t.d('helperEverySec');
        _helperRound();
      }
    }
  }

  /// Misión ganada: los cultivos dan un salto y los peces pueden criar.
  void farmMissionWon() {
    final t = s.town;
    s.town = TownRules.breed(_rand, t.copyWith(plots: {
      for (final e in t.plots.entries) e.key: FarmingRules.missionGrow(e.value),
    }));
  }

  /// El ayudante riega las secas y cosecha (y replanta) las maduras de
  /// hasta `helperPlots` parcelas; lo cosechado va al granero.
  void _helperRound() {
    final t = s.town;
    var left = TownRules.helperPlots(t,
        boost: TownRules.helperBoost(humans.map((h) => h.profile)));
    final plots = {...t.plots};
    final silo = {...t.silo};
    final owner = humans.firstOrNull;
    for (final e in t.plots.entries) {
      if (left <= 0) break;
      final pl = e.value;
      if (!pl.planted) continue;
      if (FarmingRules.ripe(pl) && owner != null) {
        final h =
            FarmingRules.harvest(_rand, owner.profile, pl, helper: true)!;
        final k = cropKey(h.crop.id, h.quality);
        silo[k] = (silo[k] ?? 0) + h.count;
        plots[e.key] = FarmPlot(
            seed: pl.seed,
            boost: pl.boost,
            potential: pl.potential,
            planter: pl.planter);
        final (x, y) = parsePlotKey(e.key)!;
        events.add(CropHarvestedEvent(
            owner.id, h.crop.id, h.quality.index, h.count, x, y,
            helper: true));
        left--;
      } else if (!pl.watered) {
        plots[e.key] = pl.copyWith(
            wet: _fat.d('waterSec'),
            waterRate: _fat.d('waterRateMin'),
            waterer: 'Ayudante');
        left--;
      }
    }
    s.town = t.copyWith(plots: plots, silo: silo);
  }

  // ---------------- labores ----------------

  bool _farmTile(SessionPlayer p, FarmTileAction a) {
    if (!_inTown(p)) return false;
    final map = e.mapFor(s);
    if (!_soil(map, a.tx, a.ty)) return false;
    final cx = (a.tx + 0.5) * 16, cy = (a.ty + 0.5) * 16;
    if (WorldRules.distance(p.x, p.y, cx, cy) > _fat.d('reachPx')) return false;
    final last = _fa.lastWork[p.id];
    if (last != null && s.time - last < _fat.d('minWorkSec')) return false;
    final key = plotKey(a.tx, a.ty);
    final plots = {...s.town.plots};
    final prof = p.profile;
    var done = false;
    switch (a.op) {
      case FarmOp.till:
        final area = FarmingRules.toolBonus(prof, FarmingRules.hoeOf(prof)).area;
        for (final (x, y) in FarmingRules.areaTiles(a.tx, a.ty, area)) {
          final k = plotKey(x, y);
          if (!_soil(map, x, y) || plots.containsKey(k)) continue;
          plots[k] = FarmingRules.till();
          done = true;
        }
      case FarmOp.plant:
        final seed = a.seed ?? prof.life.farm.activeSeed;
        final pl = plots[key];
        if (seed == null || pl == null || prof.life.farm.seedCount(seed) < 1) {
          return false;
        }
        final next = FarmingRules.plant(pl, seed, prof);
        if (next == null) return false;
        plots[key] = next;
        final f = prof.life.farm;
        p.profile = prof.copyWith(
            life: prof.life.copyWith(
                farm: f.copyWith(
                    seeds: {...f.seeds, seed: f.seedCount(seed) - 1},
                    seed: seed)));
        done = true;
      case FarmOp.water:
        final area = FarmingRules.toolBonus(prof, FarmingRules.canOf(prof)).area;
        for (final (x, y) in FarmingRules.areaTiles(a.tx, a.ty, area)) {
          final k = plotKey(x, y);
          final pl = plots[k];
          if (pl == null || FarmingRules.ripe(pl)) continue;
          final w = FarmingRules.water(pl, prof);
          if (w == pl) continue;
          plots[k] = w;
          done = true;
        }
      case FarmOp.fert:
        final pl = plots[key];
        final fid = a.seed ?? _bestFert(prof);
        if (pl == null || fid == null || prof.life.farm.fertCount(fid) < 1) {
          return false;
        }
        final next = FarmingRules.fertilize(pl, fid, prof);
        if (next == null) return false;
        plots[key] = next;
        final f = prof.life.farm;
        p.profile = prof.copyWith(
            life: prof.life.copyWith(
                farm: f.copyWith(
                    ferts: {...f.ferts, fid: f.fertCount(fid) - 1})));
        done = true;
      case FarmOp.harvest:
        final pl = plots[key];
        if (pl == null || !FarmingRules.ripe(pl)) return false;
        _fa.lastWork[p.id] = s.time;
        // Queda arada y vacía, lista para replantar.
        s.town = s.town.copyWith(plots: {...plots, key: const FarmPlot()});
        _grantHarvest(p, pl, a.tx, a.ty);
        return true;
    }
    if (!done) return false;
    _fa.lastWork[p.id] = s.time;
    s.town = s.town.copyWith(plots: plots);
    p.profile = FarmingRules.workXp(p.profile);
    refresh(p);
    return true;
  }

  /// El mejor abono que tiene (si no dice cuál).
  static String? _bestFert(PlayerProfile p) {
    String? best;
    for (final id in kFertilizers.keys) {
      if (p.life.farm.fertCount(id) > 0) best = id;
    }
    return best;
  }

  static bool _soil(GameMap m, int x, int y) =>
      x >= 0 && y >= 0 && x < m.width && y < m.height &&
      m.tileAt(x, y) == Tile.soil;

  void _grantHarvest(SessionPlayer p, FarmPlot pl, int tx, int ty) {
    final h = FarmingRules.harvest(_rand, p.profile, pl)!;
    final lvl0 = FarmingRules.level(p.profile);
    var prof = FarmingRules.addHarvest(p.profile, h);
    final used = _fa.charXp[p.id] ?? 0;
    final cxp = math.min(FarmingRules.charXp(h.crop),
        math.max(0, _fat.i('charXpCap') - used));
    if (cxp > 0) {
      _fa.charXp[p.id] = used + cxp;
      final g = rules.gainXp(prof, cxp);
      prof = g.profile;
      if (g.levelsGained > 0) events.add(LevelUpEvent(p.id, prof.level));
    }
    _profileChange(p, prof, gain: true);
    events.add(CropHarvestedEvent(
        p.id, h.crop.id, h.quality.index, h.count, tx, ty));
    say('${p.name} cosechó ${h.count > 1 ? '${h.count} × ' : ''}'
        '${h.crop.name} (${h.quality.label}).');
    if (h.loot != FarmLootKind.none) _grantFarmLoot(p, h.loot, tx, ty);
    final lvl1 = FarmingRules.level(p.profile);
    if (lvl1 > lvl0) say('${p.name} subió Cultivo a nivel $lvl1.');
  }

  void _grantFarmLoot(SessionPlayer p, FarmLootKind kind, int tx, int ty) {
    var label = '';
    var rarity = Rarity.raro;
    switch (kind) {
      case FarmLootKind.semilla:
        final id = FarmingRules.rareSeed(_rand);
        final c = kCrops[id]!;
        p.profile = p.profile.copyWith(
            life: p.profile.life
                .copyWith(farm: p.profile.life.farm.addSeed(id)));
        label = c.seedName;
        rarity = c.rarity == FishRarity.epico ? Rarity.epico : Rarity.raro;
      case FarmLootKind.legendaria:
        final id = FarmingRules.legendarySeed(_rand);
        p.profile = p.profile.copyWith(
            life: p.profile.life
                .copyWith(farm: p.profile.life.farm.addSeed(id)));
        label = kCrops[id]!.seedName;
        rarity = Rarity.legendario;
      case FarmLootKind.materiales:
        final lo = _fat.i('lootMatMin');
        final hi = math.max(lo, _fat.i('lootMatMax'));
        final n = lo + (_rand() * (hi - lo + 1)).floor();
        _deliver(p, [LootDrop.stack(StackKind.esquirla, n)], LootSource.mission,
            p.x, p.y, stashOverflow: true);
        label = '$n ${StackKind.esquirla.label}';
      case FarmLootKind.none:
        return;
    }
    refresh(p);
    events.add(FarmLootEvent(p.id, label, rarity.index, tx, ty));
    say('${p.name} encontró en la tierra: $label.');
  }

  // ---------------- comerciante ----------------

  bool _farmShop(SessionPlayer p, FarmShopAction a) {
    if (!_inTown(p)) return false;
    final prof = p.profile;
    final id = a.id;
    switch (a.op) {
      case FarmShopOp.buySeed:
        return id != null &&
            _profileChange(p, FarmingRules.buySeed(prof, id, a.n));
      case FarmShopOp.buyTool:
        if (id == null || !_profileChange(p, FarmingRules.buyTool(prof, id))) {
          return false;
        }
        say('${p.name} compró ${kFarmTools[id]!.name}.');
        return true;
      case FarmShopOp.equipTool:
        return id != null && _profileChange(p, FarmingRules.equipTool(prof, id));
      case FarmShopOp.selectSeed:
        return id != null && _profileChange(p, FarmingRules.selectSeed(prof, id));
      case FarmShopOp.buyAbono:
        return id != null &&
            _profileChange(p, FarmingRules.buyFert(prof, id, a.n));
      case FarmShopOp.sell || FarmShopOp.sellAll:
        if (a.op == FarmShopOp.sell && id == null) return false;
        final r = FarmingRules.sell(prof,
            key: a.op == FarmShopOp.sell ? id : null, materials: a.materials);
        if (r == null) return false;
        _profileChange(p, r.profile);
        say('${p.name} vendió ${r.sold} cosecha${r.sold == 1 ? '' : 's'}'
            '${r.credits > 0 ? ' por ${r.credits} de oro' : ''}'
            '${r.esquirlas > 0 ? '${r.credits > 0 ? ' y' : ' por'} '
                '${r.esquirlas} Esquirla${r.esquirlas == 1 ? '' : 's'}' : ''}.');
        return true;
      case FarmShopOp.exchange:
        if (id == null ||
            !_profileChange(p, FarmingRules.exchangeLegendary(prof, id))) {
          return false;
        }
        say('${p.name} canjeó ${parseCropKey(id)!.$1.name} por materiales raros.');
        return true;
      case FarmShopOp.collectSilo:
        final r = TownRules.collectSilo(prof, s.town);
        if (r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1);
        say('${p.name} recogió el granero del ayudante.');
        return true;
    }
  }

  // ---------------- pueblo ----------------

  /// Corre a todos los del pueblo si el origen del mapa cambió (amplió al
  /// norte o al oeste; town_editor.md § 2.2).
  void _shiftTown(TownState before) {
    final (ax, ay) = before.origin;
    final (bx, by) = s.town.origin;
    if (ax == bx && ay == by) return;
    for (final p in s.playerList) {
      p.x += (bx - ax) * 16;
      p.y += (by - ay) * 16;
      p.fishLine = null;
      p.epoch++;
    }
  }

  bool _townAction(SessionPlayer p, TownAction a) {
    if (!_inTown(p)) return false;
    switch (a.op) {
      case TownOp.expand:
        final side = TownSide.fromCode(a.id);
        if (!_isOwner(p) || side == null) return false;
        final r = TownRules.expand(p.profile, s.town, side);
        if (r == null) return false;
        final before = s.town;
        s.town = r.$2;
        _shiftTown(before);
        _profileChange(p, r.$1);
        say('${p.name} amplió el pueblo al ${side.label.toLowerCase()}.');
        return true;
      case TownOp.place:
        final id = a.id, x = a.x, y = a.y;
        if (!_isOwner(p) || id == null || x == null || y == null) return false;
        final r = TownRules.place(s.town, id, x, y);
        if (r.town == null) return false;
        s.town = r.town!;
        say('${p.name} construyó ${construction(id)!.name}.');
        return true;
      case TownOp.move:
        final id = a.target, x = a.x, y = a.y;
        if (!_isOwner(p) || id == null || x == null || y == null) return false;
        final r = TownRules.move(s.town, id, x, y);
        if (r.town == null) return false;
        s.town = r.town!;
        return true;
      case TownOp.remove:
        final id = a.target;
        if (!_isOwner(p) || id == null) return false;
        final b = s.town.build(id);
        final r = TownRules.remove(p.profile, s.town, id);
        if (b == null || r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1);
        say('${p.name} borró ${b.kind == BuildKind.lago ? 'un lago' : 'una huerta'}.');
        return true;
      case TownOp.stock:
        final sp = a.id;
        if (sp == null) return false;
        final r = TownRules.stock(p.profile, s.town, sp, a.target);
        if (r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1);
        say('${p.name} soltó ${kFish[sp]!.name} en el lago.');
        return true;
      case TownOp.hireHelper:
        final r = TownRules.hire(p.profile, s.town);
        if (r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1);
        say('${p.name} contrató al ayudante de la huerta (nivel ${s.town.helper}).');
        return true;
    }
  }
}
