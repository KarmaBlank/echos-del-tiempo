part of 'session_engine.dart';

// Huerta, mejoras del pueblo y árboles de oficios en la sala
// (docs/specs/farming.md § 10, life_skill_trees.md § 4). Todo lo valida y
// otorga el anfitrión; el pueblo (`GameSession.town`) viaja en el estado.

/// Estado de la huerta del anfitrión (no viaja en el snapshot).
class FarmingHostState {
  /// Background clock RNG (sky, lightning, world events): separate from
  /// the session RNG so the world clock ticking during missions and runs
  /// does not reshuffle combat rolls.
  final math.Random bgRand = math.Random(0x5EC0);

  final lastWork = <String, double>{};

  /// XP de personaje ganada cultivando en esta estadía en el pueblo.
  final charXp = <String, int>{};

  /// Segundos sin aplicar al crecimiento (se aplica de a 1 s).
  double acc = 0;

  /// Última vuelta de los ayudantes (`s.time ~/ período`).
  int? lastRound;

  /// Segundos de tormenta desde la última tirada de rayo.
  double boltAcc = 0;

  /// Último día del mundo procesado para los habitantes.
  int residentDay = 0;

  /// Nueva estadía en el pueblo de [ids] (`null` = todos).
  void newStay([Iterable<String>? ids]) {
    if (ids == null) {
      charXp.clear();
    } else {
      ids.forEach(charXp.remove);
    }
  }
}

extension _FarmingOp on _Op {
  FarmingHostState get _fa => e.farming;
  TuningDef get _fat => FarmingRules.t;

  /// El dueño del mundo: el primer humano de la sala (el anfitrión).
  bool _isOwner(SessionPlayer p) =>
      (s.ownerId ?? humans.firstOrNull?.id) == p.id;

  /// Puede cambiar el pueblo (town_editor.md § 1.3): quien tiene el
  /// candado; sin candado, el dueño (compatibilidad con las acciones
  /// sueltas).
  bool _mayEdit(SessionPlayer p) =>
      s.townEditor == null ? _isOwner(p) : s.townEditor == p.id;

  /// Suelta el candado si quien lo tiene ya no está o salió del pueblo.
  void releaseTownLock() {
    final id = s.townEditor;
    if (id == null) return;
    final p = s.players[id];
    if (p == null || !_inTown(p) || s.place != null) s.townEditor = null;
  }

  bool farmingAction(SessionPlayer p, SessionAction a) {
    switch (a) {
      case FarmTileAction():
        return _farmTile(p, a);
      case FarmShopAction():
        return _farmShop(p, a);
      case TownAction():
        return _townAction(p, a);
      case LifeTreeAction(:final skill, :final node):
        final k =
            LifeSkillKind.values.where((v) => v.name == skill).firstOrNull;
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
  /// Runs whenever the room is open, also during missions, runs and
  /// dungeons (farming.md § 2.3): only a paused session stops it.
  void farmTick(double dt) {
    _fa.acc += dt;
    if (_fa.acc < 1) return;
    final step = _fa.acc;
    _fa.acc = 0;
    _skyTick(step);
    final t = s.town;
    final rain = SkyRules.now(t.sky).wet;
    if (t.plots.isNotEmpty) {
      var changed = false;
      final out = <String, FarmPlot>{};
      for (final e in t.plots.entries) {
        // Con lluvia se riega todo lo plantado (day_night_weather.md § 3.2).
        final w = rain ? FarmingRules.rain(e.value) : e.value;
        // Afinidad del cultivo con la hora y el clima (farming.md § 14).
        final seed = w.seed;
        final g = FarmingRules.grow(w, step,
            mult: seed == null ? 1 : LifeTimeRules.cropGrowth(seed, t.sky));
        if (g != e.value) changed = true;
        out[e.key] = g;
      }
      if (changed) s.town = t.copyWith(plots: out);
    }
    if (s.town.builds.any((b) => b.helper > 0)) {
      // Vueltas alineadas al reloj de la sala: los clientes saben cuánto
      // falta (`TownRules.nextRoundIn`).
      final k = (s.time / TownRules.helperPeriod(humans.map((h) => h.profile)))
          .floor();
      if (_fa.lastRound != null && k != _fa.lastRound) _helperRound();
      _fa.lastRound = k;
    }
  }

  /// El reloj del mundo y los rayos de la tormenta (day_night_weather.md
  /// § 1 y § 3.3). Solo el anfitrión: el cielo viaja en el pueblo.
  void _skyTick(double dt) {
    final sky = SkyRules.advance(s.town.sky, dt, _fa.bgRand.nextDouble);
    s.town = s.town.copyWith(sky: sky);
    // Habitantes (overworld_biomes.md § 10.4 y 10.5): pedidos, ánimo y
    // órdenes al cambiar el día del mundo.
    if (sky.day != _fa.residentDay) {
      _fa.residentDay = sky.day;
      s.town = ResidentRules.onDayAll(s.town, sky.day,
          fishLv: humans.fold(
              1, (a, h) => math.max(a, FishingRules.level(h.profile))),
          farmLv: humans.fold(
              1, (a, h) => math.max(a, FarmingRules.level(h.profile))),
          smithLv: humans.fold(
              0, (a, h) => math.max(a, SmithRules.level(h.profile))));
      s.town = s.town.copyWith(daily: {
        for (final e in s.town.daily.entries)
          if (e.key.endsWith(':${sky.day}')) e.key: e.value,
      });
      _worldEventsDay(sky.day);
      _stallDay(sky.day);
      animalsDay(sky.day);
    }
    if (SkyRules.now(sky) != Weather.tormenta) {
      _fa.boltAcc = 0;
      return;
    }
    _fa.boltAcc += dt;
    final every = math.max(1.0, SkyRules.t.d('boltEverySec'));
    while (_fa.boltAcc >= every) {
      _fa.boltAcc -= every;
      if (_fa.bgRand.nextDouble() >= SkyRules.t.d('boltChance')) continue;
      final keys = s.town.plots.keys.toList()..sort();
      if (keys.isEmpty) continue;
      final k = keys[(_fa.bgRand.nextDouble() * keys.length)
          .floor()
          .clamp(0, keys.length - 1)];
      final xy = parsePlotKey(k);
      if (xy == null) continue;
      final hit = s.town.plots[k]!;
      s.town = TownRules.strike(s.town, k);
      events.add(LightningEvent(xy.$1, xy.$2, lost: hit.planted));
      if (hit.planted) {
        say('Un rayo cayó en la huerta: se perdió '
            '${kCrops[hit.seed]?.name.toLowerCase() ?? 'un cultivo'}.');
      }
    }
  }

  /// Stall visitors of the new world [day] (player_shop.md § 3): every
  /// human of the room, host only.
  void _stallDay(int day) {
    for (final h in humans) {
      final (next, sales) =
          StallRules.visitDay(h.profile, day, _fa.bgRand.nextDouble);
      if (identical(next, h.profile)) continue;
      _profileChange(h, next);
      if (sales.isEmpty) continue;
      final gold = sales.fold(0, (a, x) => a + x.gold);
      say('Los vecinos le compraron a ${h.name} en su puesto: '
          '$gold de oro.');
    }
  }

  /// World events (world_events.md § 2): expiry and the deterministic
  /// roll on a new world day. Host only; the state travels in the town.
  void _worldEventsDay(int day) {
    var ev = s.town.events;
    if (ev.seed == 0) {
      ev =
          ev.copyWith(seed: 1 + (_fa.bgRand.nextDouble() * 0x7FFFFFFE).floor());
    }
    // The notice line is added by every peer in its own language when
    // the event shows up in the town (SessionController).
    final (next, _) = WorldEventRules.onDay(ev, day, kWorldEvents,
        ctx: WorldEventContext(
            residents: {
              for (final r in s.town.residents.values)
                if (r.invited) r.npc
            },
            extraCondition:
                WorldEventRules.climateCondition(s.town.sky.seed, day),
            renown: RenownRules.score(s.town)));
    if (next != s.town.events) s.town = s.town.copyWith(events: next);
    // Town events whose day passed unplayed (renown_town_growth.md § 6.1).
    final rn = RenownRules.expire(s.town.renown, day);
    if (!identical(rn, s.town.renown)) s.town = s.town.copyWith(renown: rn);
  }

  /// Mission won: the fish may breed. Crops get no extra jump: they
  /// already grew in real time during the mission (farming.md § 2.3).
  void farmMissionWon() {
    s.town = TownRules.breed(_rand, s.town);
  }

  /// Una vuelta de los ayudantes (farming.md § 8): cada granjero atiende
  /// su área (cosecha al cofre, planta de sus semillas, riega) y cada
  /// pescador saca `fisherCatch` peces del lago al cofre.
  void _helperRound() {
    final owner = humans.firstOrNull;
    if (owner == null) return;
    final net = humans.fold(
        0.0, (a, h) => math.max(a, LifeTreeRules.fish(h.profile, LifeFx.auto)));
    for (final b0 in s.town.builds) {
      if (b0.helper <= 0) continue;
      s.town = s.town.withBuild(b0.kind.ranch
          ? animalHelperRound(b0)
          : b0.kind == BuildKind.huerta
              ? _farmerRound(owner, b0)
              : _fisherRound(b0, net));
    }
  }

  TownBuild _farmerRound(SessionPlayer owner, TownBuild b0) {
    var b = b0;
    final (ox, oy) = s.town.origin;
    final (ax, ay) = b0.anchor;
    for (var i = 0; i < b0.helper; i++) {
      // Ritmo (§ 8.5): a veces hace una vuelta más.
      final turns = _rand() < HelperRules.extraChance(b, i) ? 2 : 1;
      for (var k = 0; k < turns; k++) {
        final (nb, hs) = TownRules.farmerCycle(
            b,
            i,
            (pl) =>
                FarmingRules.harvest(_rand, owner.profile, pl, helper: true)!,
            rand: _rand,
            rareSeed: () => FarmingRules.rareSeed(_rand),
            season: WeatherRules.season(s.town.sky.day));
        b = nb;
        for (final (x, y, h) in hs) {
          events.add(CropHarvestedEvent(owner.id, h.crop.id, h.quality.index,
              h.count, ax + x + ox, ay + y + oy,
              helper: true));
        }
      }
    }
    return b;
  }

  TownBuild _fisherRound(TownBuild b0, double net) {
    var b = b0;
    final roll = TownRules.lakeRoll(s.town, b0);
    // Con tormenta casi no pica (day_night_weather.md § 3.3).
    final storm = SkyRules.fisherFactor(s.town.sky);
    for (var i = 0; i < b0.helper; i++) {
      final turns = _rand() < HelperRules.extraChance(b, i) ? 2 : 1;
      final per = TownRules.t.i('fisherCatch') +
          net.round() +
          HelperRules.extraFish(b, i);
      final n = (per * turns * storm).round();
      final rare = HelperRules.rareFishChance(b, i);
      var got = 0;
      for (var k = 0; k < n && !TownRules.chestFull(b); k++) {
        var f = FishingRules.roll(_rand, roll, auto: true);
        // Rareza (§ 8.5): tira otra vez y se queda con el más raro.
        if (rare > 0 && _rand() < rare) {
          final g = FishingRules.roll(_rand, roll, auto: true);
          if (g.rarity.index > f.rarity.index) f = g;
        }
        // Como la red de antes: nunca legendarios.
        if (f.rarity == FishRarity.legendario) continue;
        b = TownRules.addToChest(b, f.species, 1);
        got++;
      }
      b = HelperRules.gainXp(b, i, got);
    }
    return b;
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
        final area =
            FarmingRules.toolBonus(prof, FarmingRules.hoeOf(prof)).area;
        for (final (x, y) in FarmingRules.areaTiles(a.tx, a.ty, area)) {
          final k = plotKey(x, y);
          if (!_soil(map, x, y) || plots.containsKey(k)) continue;
          plots[k] = FarmingRules.till();
          done = true;
        }
      case FarmOp.plant:
        final seed = a.seed ?? FarmingRules.activeSeed(prof);
        final pl = plots[key];
        if (seed == null || pl == null) return false;
        // Living weapons (profession_gear.md § 3): a weapon seed, or a
        // living weapon of the bag replanted to grow it further.
        if (seed.startsWith(kRegrowItem)) {
          final it = prof.itemByUid(seed.substring(kRegrowItem.length));
          if (it == null || prof.equippedItem?.uid == it.uid) return false;
          final next = GearRules.regrow(pl, it, prof);
          if (next == null) return false;
          plots[key] = next;
          p.profile = InventoryRules.removeItem(prof, it.uid);
          done = true;
          break;
        }
        if (kWeaponSeeds.containsKey(seed)) {
          final f = prof.life.farm;
          if (f.wseedCount(seed) < 1) return false;
          final next = GearRules.plant(pl, seed, prof);
          if (next == null) return false;
          plots[key] = next;
          p.profile = prof.copyWith(
              life: prof.life.copyWith(
                  farm: f.copyWith(
                      wseeds: {...f.wseeds, seed: f.wseedCount(seed) - 1})));
          done = true;
          break;
        }
        if (prof.life.farm.seedCount(seed) < 1) return false;
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
        // Tierra sub-path A (life_trees_v2.md § 2.1): 3×3 (5×5) watering.
        final tiles = {
          ...FarmingRules.areaTiles(a.tx, a.ty,
              FarmingRules.toolBonus(prof, FarmingRules.canOf(prof)).area),
          ...squareTiles(
              a.tx, a.ty, LifeTreeRules.farm(prof, LifeFx.waterArea)),
        };
        for (final (x, y) in tiles) {
          final k = plotKey(x, y);
          final pl = plots[k];
          if (pl == null || FarmingRules.ripe(pl)) continue;
          final w = FarmingRules.water(pl, prof);
          if (w == pl) continue;
          plots[k] = w;
          done = true;
        }
      case FarmOp.fert:
        final fid = a.seed ?? _bestFert(prof);
        if (fid == null || prof.life.farm.fertCount(fid) < 1) return false;
        // Abono sub-path B: one bag composts the 3×3 (5×5) around.
        for (final (x, y) in squareTiles(
            a.tx, a.ty, LifeTreeRules.farm(prof, LifeFx.compostArea))) {
          final k = plotKey(x, y);
          final pl = plots[k];
          if (pl == null) continue;
          final next = GearRules.isLiving(pl.seed)
              ? GearRules.compost(pl, fid, prof)
              : FarmingRules.fertilize(pl, fid, prof);
          if (next == null) continue;
          plots[k] = next;
          done = true;
        }
        if (!done) return false;
        final f = prof.life.farm;
        p.profile = prof.copyWith(
            life: prof.life.copyWith(
                farm: f
                    .copyWith(ferts: {...f.ferts, fid: f.fertCount(fid) - 1})));
      case FarmOp.harvest:
        final pl = plots[key];
        if (pl == null || !FarmingRules.ripe(pl)) return false;
        if (GearRules.isLiving(pl.seed)) {
          _fa.lastWork[p.id] = s.time;
          s.town = s.town.copyWith(plots: {...plots, key: const FarmPlot()});
          _grantLiving(p, pl, a.tx, a.ty);
          return true;
        }
        // Winter crops: only harvested in winter (farming.md § 15).
        if (!FarmingRules.harvestable(
            pl, WeatherRules.season(s.town.sky.day))) {
          say('${kCrops[pl.seed]?.name ?? 'Ese cultivo'} solo se cosecha en '
              'invierno.');
          return false;
        }
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
      x >= 0 &&
      y >= 0 &&
      x < m.width &&
      y < m.height &&
      m.tileAt(x, y) == Tile.soil;

  void _grantHarvest(SessionPlayer p, FarmPlot pl, int tx, int ty) {
    // Scarecrow nearby: a small quality bias (cozy_life.md § 2).
    final h = FarmingRules.harvest(_rand, p.profile, pl,
        bias: CozyRules.scarecrowBias(s.town, tx, ty))!;
    final lvl0 = FarmingRules.level(p.profile);
    // XP and pity now; the crop and its seeds pop out of the plot as
    // ground loot with a short magnet (farming.md § 3, loot.md § 4c).
    final bags = p.profile.life.farm;
    var prof = FarmingRules.addHarvest(p.profile, h);
    prof = prof.copyWith(
        life: prof.life.copyWith(
            farm: prof.life.farm
                .copyWith(crops: bags.crops, seeds: bags.seeds)));
    final used = _fa.charXp[p.id] ?? 0;
    final cxp = math.min(
        FarmingRules.charXp(h.crop), math.max(0, _fat.i('charXpCap') - used));
    if (cxp > 0) {
      _fa.charXp[p.id] = used + cxp;
      final g = rules.gainXp(prof, cxp);
      prof = g.profile;
      if (g.levelsGained > 0) events.add(LevelUpEvent(p.id, prof.level));
    }
    _profileChange(p, prof, gain: true);
    events.add(
        CropHarvestedEvent(p.id, h.crop.id, h.quality.index, h.count, tx, ty));
    _spill(p, [
      GoodsRules.crop(cropKey(h.crop.id, h.quality), h.count),
      if (h.seeds > 0) GoodsRules.seed(h.crop.id, h.seeds),
    ], (tx + 0.5) * 16, (ty + 0.5) * 16);
    say('${p.name} cosechó ${h.count > 1 ? '${h.count} × ' : ''}'
        '${h.crop.name} (${h.quality.label}).');
    if (h.loot != FarmLootKind.none) _grantFarmLoot(p, h.loot, tx, ty);
    // Semilla sub-paths (life_trees_v2.md § 2.1): A gives a seed back, B
    // sometimes a mutated rare variety (or a weapon seed).
    final back = LifeTreeRules.farm(p.profile, LifeFx.seedBack);
    if (back > 0 &&
        kCrops[h.crop.id]?.rarity != FishRarity.legendario &&
        _rand() < back) {
      _profileChange(
          p,
          p.profile.copyWith(
              life: p.profile.life.copyWith(
                  farm: p.profile.life.farm.addSeed(h.crop.id))));
      say('${p.name} guardó una semilla de ${h.crop.name}.');
    }
    final mut = LifeTreeRules.farm(p.profile, LifeFx.mutate);
    if (mut > 0 && _rand() < mut) {
      final weapon = _rand() < GearRules.t.d('seedMutateShare');
      final id =
          weapon ? GearRules.rollSeed(_rand) : FarmingRules.rareSeed(_rand);
      final f = p.profile.life.farm;
      _profileChange(
          p,
          p.profile.copyWith(
              life: p.profile.life.copyWith(
                  farm: weapon ? f.addWseed(id) : f.addSeed(id))),
          gain: true);
      say('${p.name} encontró una variedad mutada: '
          '${weapon ? kWeaponSeedNames[id] : kCrops[id]?.seedName}.');
    }
    final lvl1 = FarmingRules.level(p.profile);
    if (lvl1 > lvl0) {
      say('${p.name} subió Cultivo a nivel $lvl1.');
      lifeLevelXp(p, lvl1);
    }
  }


  /// A ripe living weapon (profession_gear.md § 3.4): the weapon to the
  /// harvester (inventory, floor or stash), Cultivo XP and an event.
  void _grantLiving(SessionPlayer p, FarmPlot pl, int tx, int ty) {
    final item = GearRules.harvest(rules.loot, _rand, p.profile, pl);
    if (item == null) return;
    final lvl0 = FarmingRules.level(p.profile);
    final f = p.profile.life.farm;
    _profileChange(
        p,
        p.profile.copyWith(
            life: p.profile.life.copyWith(
                farm: f.copyWith(
                    xp: f.xp + GearRules.t.i('livingHarvestXp')))),
        gain: true);
    final d = LootDrop.item(item);
    events.add(FarmLootEvent(p.id, _dropText(d), item.rarity.index, tx, ty));
    say('${p.name} cosechó un arma viva: ${_dropText(d)}.');
    _deliver(p, [d], LootSource.mission, p.x, p.y, stashOverflow: true);
    final lvl1 = FarmingRules.level(p.profile);
    if (lvl1 > lvl0) {
      say('${p.name} subió Cultivo a nivel $lvl1.');
      lifeLevelXp(p, lvl1);
    }
  }

  /// Subir de nivel un oficio da XP de personaje (life_skill_trees.md
  /// § 6): `lifeLevelCharXp` × nivel, sin el tope por estadía.
  void lifeLevelXp(SessionPlayer p, int lvl) =>
      grantCharXp(p, ResidentRules.t.i('lifeLevelCharXp') * lvl);

  /// XP de Herrería (roles.md § 6); al subir de nivel, XP de personaje.
  void smithXp(SessionPlayer p, int base) {
    if (p.isCompanion || base <= 0) return;
    final lvl0 = SmithRules.level(p.profile);
    _profileChange(p, SmithRules.gain(p.profile, base));
    final lvl1 = SmithRules.level(p.profile);
    if (lvl1 > lvl0) {
      say('${p.name} subió Herrería a nivel $lvl1.');
      lifeLevelXp(p, lvl1);
    }
  }

  /// Suma [xp] de personaje a [p] (con sus subidas de nivel).
  void grantCharXp(SessionPlayer p, int xp) {
    if (xp <= 0) return;
    final g = rules.gainXp(p.profile, xp);
    _profileChange(p, g.profile, gain: true);
    if (g.levelsGained > 0) {
      p.levelUpPending = true;
      events.add(LevelUpEvent(p.id, g.profile.level));
    }
  }

  void _grantFarmLoot(SessionPlayer p, FarmLootKind kind, int tx, int ty) {
    var label = '';
    var rarity = Rarity.raro;
    switch (kind) {
      case FarmLootKind.semilla:
        final id = FarmingRules.rareSeed(_rand);
        final c = kCrops[id]!;
        p.profile = p.profile.copyWith(
            life:
                p.profile.life.copyWith(farm: p.profile.life.farm.addSeed(id)));
        label = c.seedName;
        rarity = c.rarity == FishRarity.epico ? Rarity.epico : Rarity.raro;
      case FarmLootKind.legendaria:
        final id = FarmingRules.legendarySeed(_rand);
        p.profile = p.profile.copyWith(
            life:
                p.profile.life.copyWith(farm: p.profile.life.farm.addSeed(id)));
        label = kCrops[id]!.seedName;
        rarity = Rarity.legendario;
      case FarmLootKind.materiales:
        final lo = _fat.i('lootMatMin');
        final hi = math.max(lo, _fat.i('lootMatMax'));
        final n = lo + (_rand() * (hi - lo + 1)).floor();
        _deliver(p, [LootDrop.stack(StackKind.esquirla, n)], LootSource.mission,
            p.x, p.y,
            stashOverflow: true);
        label = '$n ${StackKind.esquirla.label}';
      case FarmLootKind.none:
        return;
    }
    refresh(p);
    events.add(FarmLootEvent(p.id, label, rarity.index, tx, ty));
    say('${p.name} encontró en la tierra: $label.');
  }

  // ---------------- agropecuario ----------------

  bool _farmShop(SessionPlayer p, FarmShopAction a) {
    if (!_inTown(p)) return false;
    final prof = p.profile;
    final id = a.id;
    switch (a.op) {
      case FarmShopOp.buySeed:
        // Trade goods of a resident (overworld_biomes.md § 9.1.1): same
        // op, the id says which bag it goes to.
        if (id != null && kSmithMaterials.containsKey(id)) {
          final npc = biomeLayout(s.place)?.npc;
          final price = npc != null
              ? BiomeRules.vendorStockPrice(
                  s.place, id, ResidentRules.tier(s.town.resident(npc.id)))
              : (s.place == null
                  ? ResidentRules.townSeedPrice(s.town, id)
                  : null);
          return _profileChange(
              p, ResidentRules.buyWare(prof, id, a.n, price));
        }
        // Habitante del bioma (overworld_biomes.md § 9.1): sus semillas.
        final vendor = id == null
            ? null
            : BiomeRules.vendorPrice(s.place, id) ??
                (s.place == null
                    ? ResidentRules.townSeedPrice(s.town, id)
                    : null);
        return id != null &&
            _profileChange(p, FarmingRules.buySeed(prof, id, a.n, vendor));
      case FarmShopOp.buyTool:
        if (id == null || !_profileChange(p, FarmingRules.buyTool(prof, id))) {
          return false;
        }
        say('${p.name} compró ${kFarmTools[id]!.name}.');
        return true;
      case FarmShopOp.equipTool:
        return id != null &&
            _profileChange(p, FarmingRules.equipTool(prof, id));
      case FarmShopOp.selectSeed:
        return id != null &&
            _profileChange(p, FarmingRules.selectSeed(prof, id));
      case FarmShopOp.buyBait:
        return id != null && _profileChange(p, BaitRules.buy(prof, id, a.n));
      case FarmShopOp.selectBait:
        return id != null && _profileChange(p, BaitRules.select(prof, id));
      case FarmShopOp.cycleBait:
        return _profileChange(p, BaitRules.cycle(prof));
      case FarmShopOp.craftBait:
        if (id == null || !_profileChange(p, BaitRules.craft(prof, id))) {
          return false;
        }
        say('${p.name} preparó ${kBaits[id]!.name}.');
        return true;
      case FarmShopOp.cook:
        if (id == null || a.n < 0 || a.n >= CropQuality.values.length) {
          return false;
        }
        if (!_profileChange(
            p, CookingRules.cook(prof, id, CropQuality.values[a.n]))) {
          return false;
        }
        say('${p.name} cocinó ${kMeals[id]!.name}.');
        return true;
      case FarmShopOp.eat:
        if (id == null || !_profileChange(p, CookingRules.eat(prof, id))) {
          return false;
        }
        refresh(p);
        say('${p.name} comió ${parseMealKey(id)!.$1.name}.');
        return true;
      case FarmShopOp.giveMeal:
        final to = s.players[a.to ?? ''];
        if (id == null ||
            to == null ||
            to.id == p.id ||
            to.isCompanion ||
            !_inTown(to)) {
          return false;
        }
        final g = CookingRules.give(prof, to.profile, id);
        if (g == null) return false;
        _profileChange(p, g.$1);
        _profileChange(to, g.$2);
        say('${p.name} le dio ${parseMealKey(id)!.$1.name} a ${to.name}.');
        return true;
      case FarmShopOp.feast:
        if (id == null || a.n < 0 || a.n >= CropQuality.values.length) {
          return false;
        }
        final f = CookingRules.feast(prof, id, CropQuality.values[a.n]);
        if (f == null) return false;
        _profileChange(p, f.$1);
        for (final q in s.players.values) {
          if (q.isCompanion || !_inTown(q)) continue;
          _profileChange(q, CookingRules.serve(q.profile, f.$2));
        }
        say('${p.name} cocinó un festín de ${kMeals[id]!.name} para el grupo.');
        return true;
      case FarmShopOp.buyAbono:
        return id != null &&
            _profileChange(p, FarmingRules.buyFert(prof, id, a.n));
      case FarmShopOp.sell || FarmShopOp.sellAll:
        if (a.op == FarmShopOp.sell && id == null) return false;
        final r = FarmingRules.sell(prof,
            key: a.op == FarmShopOp.sell ? id : null,
            materials: a.materials,
            season: WeatherRules.season(s.town.sky.day));
        if (r == null) return false;
        _profileChange(p, r.profile);
        say('${p.name} vendió ${r.sold} cosecha${r.sold == 1 ? '' : 's'}'
            '${r.credits > 0 ? ' por ${r.credits} de oro' : ''}'
            '${r.esquirlas > 0 ? '${r.credits > 0 ? ' y' : ' por'} '
                '${r.esquirlas} Esquirla${r.esquirlas == 1 ? '' : 's'}' : ''}.');
        return true;
      case FarmShopOp.buyHay ||
            FarmShopOp.buyRanchTool ||
            FarmShopOp.makeHay ||
            FarmShopOp.sellGoods:
        return animalShop(p, a);
      case FarmShopOp.exchange:
        if (id == null ||
            !_profileChange(p, FarmingRules.exchangeLegendary(prof, id))) {
          return false;
        }
        say('${p.name} canjeó ${parseCropKey(id)!.$1.name} por materiales raros.');
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

  /// Tras mover un lugar (town_editor.md § 3.3): quien quedó dentro de
  /// algo sólido vuelve a la aparición (al sur de la fuente).
  void _unstuckTown() {
    final m = e.mapFor(s);
    var i = 0;
    for (final p in s.playerList) {
      final tx = (p.x / 16).floor(), ty = (p.y / 16).floor();
      if (!WorldRules.isSolid(m, tx, ty)) continue;
      final sp = m.spawn;
      p.x = sp.x + (i % 3 - 1) * 12.0;
      p.y = sp.y + (i ~/ 3) * 10.0;
      i++;
      p.fishLine = null;
      p.epoch++;
    }
  }

  /// Chest of [tier] from a resident: gold and the usual loot rolls at
  /// the player's level (roles.md § 9).
  void _residentChest(SessionPlayer p, ChestTier tier) {
    final def = kChestTiers[tier]!;
    final cr = ((20 + (_rand() * 31).floor()) * def.creditMult).round();
    p.profile = p.profile.copyWith(credits: p.profile.credits + cr);
    _deliver(p, _chestDrops(p, def, p.profile.level), LootSource.chest,
        p.x, p.y,
        stashOverflow: true);
  }

  /// The rolled part of a milestone (the static part is already paid by
  /// [ResidentMilestoneRules.claim]).
  void _payMilestone(SessionPlayer p, MilestoneReward r) {
    final il = LootRules.itemLevelFor(p.profile.level, LootSource.chest,
        cap: _lootCap());
    switch (r) {
      case MilestoneReward.chestWood:
        _residentChest(p, ChestTier.madera);
      case MilestoneReward.chestSilver:
        _residentChest(p, ChestTier.plata);
      case MilestoneReward.ecoOrGold:
        if (p.profile.ecosUnlocked) {
          _deliver(
              p,
              [
                LootDrop.eco(ecos.generate(_ecoRand,
                    tier: EcoRules.dropTier(_ecoRand, _eco),
                    source: LootSource.chest,
                    atlas: _eco == null ? AtlasEffects.none : _atlas))
              ],
              LootSource.chest,
              p.x,
              p.y,
              stashOverflow: true);
        } else {
          _residentChest(p, ChestTier.oro);
        }
      case MilestoneReward.weapon || MilestoneReward.unique:
        final item = rules.loot.generate(_rand,
            itemLevel: il,
            rarity: r == MilestoneReward.unique
                ? Rarity.legendario
                : Rarity.epico,
            family: p.profile.classId,
            source: LootSource.chest);
        _deliver(p, [LootDrop.item(item)], LootSource.chest, p.x, p.y,
            stashOverflow: true);
      case MilestoneReward.material ||
            MilestoneReward.meal ||
            MilestoneReward.perk:
        break;
    }
  }

  /// Habitantes (overworld_biomes.md § 10). Invitar, regalar y entregar
  /// encargos también en su bioma; lo demás, en el pueblo.
  bool _residentAction(SessionPlayer p, TownAction a) {
    final npc = a.id;
    // NPC hecho con datos (npc_editor.md § 6.3): solo INVITAR.
    if (npc != null && a.op == TownOp.invite && kCustomNpcs[npc] != null) {
      final r = CustomNpcRules.invite(s.town, npc, s.place);
      if (r == null) return false;
      s.town = r;
      say('${kCustomNpcs[npc]!.name.text} se muda al pueblo.');
      return true;
    }
    final n = npc == null ? null : biomeNpc(npc);
    if (npc == null || n == null) return false;
    final home = s.place == null;
    final day = math.max(1, s.town.sky.day);
    // Una vez mudado, el habitante solo está en el pueblo (§ 10.1).
    if (!home && s.town.resident(npc).invited) return false;
    switch (a.op) {
      case TownOp.invite:
        final r = ResidentRules.invite(s.town, npc, time: s.time);
        if (r == null) return false;
        s.town = r;
        say('${n.name} se muda al pueblo.');
        return true;
      case TownOp.assign:
        final id = a.target;
        if (!home || !_mayEdit(p) || id == null) return false;
        final r = ResidentRules.assign(s.town, npc, id);
        if (r == null) return false;
        s.town = r;
        say('${n.name} vive en su casa nueva.');
        return true;
      case TownOp.gift:
        final item = a.target;
        if (item == null) return false;
        final r = ResidentRules.gift(p.profile, s.town, npc, item);
        if (r == null) return false;
        _profileChange(p, r.$1);
        s.town = r.$2;
        say(r.$3
            ? '${n.name} aceptó el regalo de ${p.name} (+1 de relación).'
            : '${n.name} aceptó el regalo (hoy ya recibió uno).');
        return true;
      case TownOp.turnIn:
        final r = ResidentRules.turnIn(p.profile, s.town, npc);
        if (r == null) return false;
        _profileChange(p, r.profile, gain: true);
        s.town = r.town;
        if (r.done case final q?) {
          say('${p.name} cumplió un encargo de ${n.name} (+${q.gold} de oro).');
          if (kResidentRelics[q.reward] case final rl?) {
            say('${n.name} te dio ${rl.name}.');
          }
        }
        return true;
      case TownOp.fulfil:
        if (!home || ResidentRules.requestUnmet(s.town, npc) != null) {
          return false;
        }
        s.town = s.town
            .withResident(ResidentRules.fulfill(s.town.resident(npc), day));
        say('${n.name} está contento: pedido cumplido.');
        return true;
      case TownOp.invest:
        if (!home) return false;
        final r = ResidentRules.invest(p.profile, s.town, npc);
        if (r == null) return false;
        _profileChange(p, r.$1);
        s.town = r.$2;
        say('${p.name} subió la casa de ${n.name} a nivel '
            '${s.town.houseOf(npc)!.level}.');
        return true;
      case TownOp.order:
        if (!home) return false;
        final key = '${p.profile.name}:$day';
        final used = s.town.daily[key] ?? 0;
        final ord = s.town.resident(npc).order;
        final forged = ord != null && ResidentRules.isForgeOrder(ord);
        final oq = s.town.resident(npc).orderQ;
        final r = ResidentRules.deliverOrder(
            p.profile, s.town, npc, ResidentRules.t.i('orderXpDayCap') - used,
            pick: a.target);
        if (r == null) return false;
        final pts = r.$1.treeBonus - p.profile.treeBonus;
        // Encargos sub-path A (life_trees_v2.md § 2.1): better pay.
        final paidGold = r.$1.credits - p.profile.credits;
        final extraGold = paidGold > 0
            ? (paidGold * (GearRules.orderPayMult(p.profile) - 1)).round()
            : 0;
        _profileChange(p, r.$1.copyWith(credits: r.$1.credits + extraGold),
            gain: true);
        // Forged weapon order (mining_smithing.md § 2.2): Smithing XP too.
        if (forged) smithXp(p, ResidentRules.forgeOrderXp(oq));
        s.town = r.$2;
        s.town = s.town.copyWith(daily: {...s.town.daily, key: used + r.$3});
        grantCharXp(p, r.$3);
        say('${p.name} entregó la orden de ${n.name} (+${r.$3} XP'
            '${pts > 0 ? ', +1 punto de árbol' : ''}).');
        // roles.md § 9.3: sometimes the order comes with a bonus chest.
        // Encargos sub-path B adds to that chance.
        if (_rand() <
            ResidentMilestoneRules.orderChestChance +
                GearRules.orderChest(p.profile)) {
          _residentChest(p, ChestTier.madera);
          say('${n.name} agregó un cofre de regalo.');
        }
        // profession_gear.md § 3.1: some orders pay a weapon seed too.
        if (_rand() < GearRules.t.d('seedOrderChance')) {
          final ws = GearRules.rollSeed(_rand);
          _profileChange(
              p,
              p.profile.copyWith(
                  life: p.profile.life
                      .copyWith(farm: p.profile.life.farm.addWseed(ws))),
              gain: true);
          say('${n.name} te regaló ${kWeaponSeedNames[ws]}.');
        }
        return true;
      case TownOp.claimMilestone:
        // roles.md § 9: one milestone of the track, once per character.
        if (!home || p.isCompanion) return false;
        final i = a.n;
        final paid = ResidentMilestoneRules.claim(p.profile, s.town, npc, i);
        if (paid == null) return false;
        _profileChange(p, paid, gain: true);
        _payMilestone(p, kResidentMilestones[i].reward);
        say('${p.name} recibió el regalo de ${n.name} '
            '(relación ${kResidentMilestones[i].rep}).');
        return true;
      case TownOp.commission:
        // Encargo de forja de Brann (roles.md § 4): un arma de tu clase,
        // uno por día del mundo.
        if (!home || npc != 'brann') return false;
        final key = 'com:${p.profile.name}:$day';
        if (s.town.daily.containsKey(key)) return false;
        final paid = ResidentRules.payCommission(p.profile, s.town);
        if (paid == null) return false;
        _profileChange(p, paid);
        s.town = s.town.copyWith(daily: {...s.town.daily, key: 0});
        final ri = ResidentRules.commissionRarity(s.town.resident('brann'),
            fishLv: FishingRules.level(p.profile),
            farmLv: FarmingRules.level(p.profile),
            smithLv: SmithRules.level(p.profile));
        final item = rules.loot.generate(_rand,
            itemLevel: ResidentRules.commissionItemLevel(p.profile.level),
            rarity: Rarity.values[ri],
            family: p.profile.classId,
            source: LootSource.chest);
        say('Brann forjó para ${p.name}: ${item.rarity.label.toLowerCase()} '
            'de nivel ${item.itemLevel}.');
        smithXp(p, SmithRules.t.i('smithXpCommission'));
        _deliver(p, [LootDrop.item(item)], LootSource.mission, p.x, p.y,
            stashOverflow: true);
        return true;
      default:
        return false;
    }
  }

  bool _townAction(SessionPlayer p, TownAction a) {
    if (!_inTown(p)) return false;
    switch (a.op) {
      case TownOp.lock:
        if (s.place != null) return false;
        if (s.townEditor != null && s.townEditor != p.id) return false;
        s.townEditor = p.id;
        return true;
      case TownOp.unlock:
        if (s.townEditor != p.id) return false;
        s.townEditor = null;
        return true;
      case TownOp.expand:
        final side = TownSide.fromCode(a.id);
        if (!_mayEdit(p) || side == null) return false;
        final r = TownRules.expand(p.profile, s.town, side);
        if (r == null) return false;
        final before = s.town;
        s.town = r.$2;
        _shiftTown(before);
        _profileChange(p, r.$1);
        say('${p.name} amplió el pueblo al ${side.label.toLowerCase()}.');
        return true;
      case TownOp.place when kFarmDecos.containsKey(a.id):
        final x = a.x, y = a.y;
        if (!_mayEdit(p) || x == null || y == null) return false;
        final r = CozyRules.placeDecor(p.profile, s.town, a.id!, x, y);
        if (r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1);
        return true;
      case TownOp.move when TownState.parseDecorId(a.target) != null:
        final x = a.x, y = a.y;
        if (!_mayEdit(p) || x == null || y == null) return false;
        final r = CozyRules.moveDecor(s.town, a.target!, x, y);
        if (r == null) return false;
        s.town = r;
        return true;
      case TownOp.remove when TownState.parseDecorId(a.target) != null:
        if (!_mayEdit(p)) return false;
        final r = CozyRules.removeDecor(s.town, a.target!);
        if (r == null) return false;
        s.town = r;
        return true;
      case TownOp.place when a.id == kFaroId:
        final x = a.x, y = a.y;
        if (!_mayEdit(p) || x == null || y == null) return false;
        final r = TownRules.placeLight(p.profile, s.town, x, y);
        if (r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1);
        say('${p.name} puso un faro.');
        return true;
      case TownOp.move when TownState.parseLightId(a.target) != null:
        final x = a.x, y = a.y;
        if (!_mayEdit(p) || x == null || y == null) return false;
        final r = TownRules.moveLight(s.town, a.target!, x, y);
        if (r == null) return false;
        s.town = r;
        return true;
      case TownOp.remove when TownState.parseLightId(a.target) != null:
        if (!_mayEdit(p)) return false;
        final r = TownRules.removeLight(s.town, a.target!);
        if (r == null) return false;
        s.town = r;
        say('${p.name} sacó un faro.');
        return true;
      case TownOp.place:
        final id = a.id, x = a.x, y = a.y;
        if (!_mayEdit(p) || id == null || x == null || y == null) return false;
        final casa = id == kCasaId;
        final ranch = animalHomeById(id) != null;
        final paid = casa
            ? HelperRules.pay(p.profile, ResidentRules.placeCost())
            : ranch
                ? AnimalRules.payBuild(p.profile, id)
                : null;
        if ((casa || ranch) && paid == null) return false;
        final r = TownRules.place(s.town, id, x, y);
        if (r.town == null) return false;
        s.town = r.town!;
        if (paid != null) _profileChange(p, paid);
        say('${p.name} construyó ${construction(id)!.name}.');
        return true;
      case TownOp.move:
        final id = a.target, x = a.x, y = a.y;
        if (!_mayEdit(p) || id == null || x == null || y == null) return false;
        final r = TownRules.move(s.town, id, x, y);
        if (r.town == null) return false;
        s.town = r.town!;
        if (TownLayout.byId(id) case final l?) {
          _unstuckTown();
          say('${p.name} movió ${l.name.toLowerCase()}.');
        }
        return true;
      case TownOp.remove:
        final id = a.target;
        if (!_mayEdit(p) || id == null) return false;
        final b = s.town.build(id);
        final r = TownRules.remove(p.profile, s.town, id);
        if (b == null || r == null) return false;
        s.town = ResidentRules.sync(r.$2);
        _profileChange(p, r.$1);
        say('${p.name} borró ${switch (b.kind) {
          BuildKind.lago => 'un lago',
          BuildKind.huerta => 'una huerta',
          BuildKind.casa => 'una casa',
          BuildKind.gallinero => 'un gallinero',
          BuildKind.establo => 'un establo',
        }}.');
        return true;
      case TownOp.track:
        final k = a.target;
        if (k == null) return false;
        final r = QuestTrackRules.toggle(p.profile, s.town, k);
        return r != null && _profileChange(p, r);
      case TownOp.seen:
        final id = a.id;
        if (id == null) return false;
        final r = QuestTrackRules.markSeen(p.profile, s.town, id);
        return r != null && _profileChange(p, r);
      case TownOp.invite ||
            TownOp.assign ||
            TownOp.gift ||
            TownOp.turnIn ||
            TownOp.fulfil ||
            TownOp.invest ||
            TownOp.order ||
            TownOp.commission ||
            TownOp.claimMilestone:
        return _residentAction(p, a);
      case TownOp.fisherReq:
        // Pescador nativo (fishing.md § 12): solo en su bioma.
        final biome = a.id;
        if (biome == null || s.place != biome || p.isCompanion) return false;
        final day = math.max(1, s.town.sky.day);
        final lv0 = FishingRules.level(p.profile);
        final r = BiomeFisherRules.deliver(p.profile, s.town, biome, day);
        if (r == null) return false;
        _profileChange(p, r.$1, gain: true);
        s.town = NpcTalkRules.onOrder(r.$2, biome);
        grantCharXp(p, r.$3);
        say('${p.name} le entregó el pedido a '
            '${kBiomeFishers[biome]?.name ?? 'el pescador'} (+${r.$3} XP).');
        final lv1 = FishingRules.level(p.profile);
        if (lv1 > lv0) {
          say('${p.name} subió Pesca a nivel $lv1.');
          lifeLevelXp(p, lv1);
        }
        return true;
      case TownOp.talk:
        // Charla con un habitante (overworld_biomes.md § 12): una por día.
        final id = a.id;
        if (id == null || p.isCompanion) return false;
        final t = NpcTalkRules.talk(s.town, id, math.max(1, s.town.sky.day));
        if (t == null) return false;
        s.town = t;
        return true;
      case TownOp.nativeInvite:
        final biome = a.id;
        if (biome == null || s.place != biome || p.isCompanion) return false;
        final lv0 = FishingRules.level(p.profile);
        final r = NpcTalkRules.invite(p.profile, s.town, biome);
        if (r == null) return false;
        _profileChange(p, r.$1, gain: true);
        s.town = r.$2;
        final d = kNpcTalks[nativeId(biome)];
        say('${kBiomeFishers[biome]?.name ?? 'El pescador'} no se muda, '
            'pero le dio a ${p.name}: ${d?.gift ?? 'un regalo'}.');
        final lv1 = FishingRules.level(p.profile);
        if (lv1 > lv0) {
          say('${p.name} subió Pesca a nivel $lv1.');
          lifeLevelXp(p, lv1);
        }
        return true;
      case TownOp.nativeTrade:
        final biome = a.id, sp = a.target;
        if (biome == null || sp == null || s.place != biome) return false;
        if (p.isCompanion) return false;
        final r = NpcTalkRules.trade(
            p.profile, s.town, biome, sp, a.n, math.max(1, s.town.sky.day),
            buy: a.x == 1);
        if (r == null) return false;
        _profileChange(p, r);
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
        final id = a.target;
        if (!_mayEdit(p) || id == null) return false;
        final r = TownRules.hire(p.profile, s.town, id);
        if (r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1);
        final b = s.town.build(id)!;
        say('${p.name} contrató un '
            '${b.kind.ranch ? 'granjero de corral' : b.kind == BuildKind.huerta ? 'granjero' : 'pescador'}.');
        return true;
      case TownOp.fireHelper:
        final id = a.target;
        if (!_mayEdit(p) || id == null) return false;
        final r = TownRules.fire(s.town, id);
        if (r == null) return false;
        s.town = r;
        return true;
      case TownOp.helperTasks:
        final id = a.target, i = a.x;
        if (!_mayEdit(p) || id == null || i == null) return false;
        final r = TownRules.setTasks(s.town, id, i, a.n);
        if (r == null) return false;
        s.town = r;
        return true;
      case TownOp.giveSeeds || TownOp.takeSeeds:
        final id = a.target, seed = a.id;
        if (id == null || seed == null) return false;
        final r = a.op == TownOp.giveSeeds
            ? TownRules.giveSeeds(p.profile, s.town, id, seed, a.n)
            : TownRules.takeSeeds(p.profile, s.town, id, seed, a.n);
        if (r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1);
        return true;
      case TownOp.buyAnimal ||
            TownOp.animalFeed ||
            TownOp.animalPet ||
            TownOp.animalCollect ||
            TownOp.depositHay:
        return animalAction(p, a);
      case TownOp.helperUpgrade:
        final id = a.target, i = a.x, u = HelperUpgrade.fromName(a.id);
        if (!_mayEdit(p) || id == null || i == null || u == null) return false;
        final r = HelperRules.upgrade(p.profile, s.town, id, i, u);
        if (r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1);
        final b = s.town.build(id)!;
        say('${p.name} mejoró ${u.label.toLowerCase()} del '
            '${b.kind == BuildKind.huerta ? 'granjero' : 'pescador'} ${i + 1} '
            '(rango ${b.stat(i).rank(u)}).');
        return true;
      case TownOp.collectChest:
        final id = a.target;
        if (id == null) return false;
        final n = s.town.build(id)?.chestTotal ?? 0;
        final r = TownRules.collectChest(p.profile, s.town, id);
        if (r == null) return false;
        s.town = r.$2;
        _profileChange(p, r.$1, gain: true);
        say('${p.name} recogió $n del cofre.');
        return true;
    }
  }
}

extension _ResidentWin on _Op {
  /// Mazmorra de la zona [zone] ganada (o élite vencido): avanza los
  /// encargos de los habitantes y paga el oro de cada paso a la party
  /// (overworld_biomes.md § 10.2).
  void residentWin(int zone, {bool elite = false}) {
    final (town, done) = ResidentRules.onWin(s.town, zone, elite: elite);
    s.town = town;
    for (final (npc, q) in done) {
      for (final p in players) {
        p.profile = p.profile.copyWith(credits: p.profile.credits + q.gold);
      }
      final n = biomeNpc(npc)!;
      say('Encargo de ${n.name} cumplido (+${q.gold} de oro para cada uno).');
      if (kResidentRelics[q.reward] case final rl?) {
        say('${n.name} les guarda ${rl.name}.');
      }
    }
  }
}
