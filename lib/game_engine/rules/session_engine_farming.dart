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

  /// Última vuelta de los ayudantes (`s.time ~/ período`).
  int? lastRound;

  /// Segundos de tormenta desde la última tirada de rayo.
  double boltAcc = 0;

  /// XP de órdenes de habitantes dada hoy (`id:día` → XP; § 10.5).
  final orderXp = <String, int>{};

  /// Último día del mundo procesado para los habitantes.
  int residentDay = 0;

  void newStay() => charXp.clear();
}

extension _FarmingOp on _Op {
  FarmingHostState get _fa => e.farming;
  TuningDef get _fat => FarmingRules.t;

  /// El dueño del mundo: el primer humano de la sala (el anfitrión).
  bool _isOwner(SessionPlayer p) => humans.firstOrNull?.id == p.id;

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
  void farmTick(double dt) {
    if (s.run != null) return;
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
        final g = FarmingRules.grow(w, step);
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
    final sky = SkyRules.advance(s.town.sky, dt, _rand);
    s.town = s.town.copyWith(sky: sky);
    // Habitantes (overworld_biomes.md § 10.4 y 10.5): pedidos, ánimo y
    // órdenes al cambiar el día del mundo.
    if (sky.day != _fa.residentDay) {
      _fa.residentDay = sky.day;
      s.town = ResidentRules.onDayAll(s.town, sky.day,
          fishLv: humans.fold(
              1, (a, h) => math.max(a, FishingRules.level(h.profile))),
          farmLv: humans.fold(
              1, (a, h) => math.max(a, FarmingRules.level(h.profile))));
      _fa.orderXp.removeWhere((k, _) => !k.endsWith(':${sky.day}'));
    }
    if (SkyRules.now(sky) != Weather.tormenta) {
      _fa.boltAcc = 0;
      return;
    }
    _fa.boltAcc += dt;
    final every = math.max(1.0, SkyRules.t.d('boltEverySec'));
    while (_fa.boltAcc >= every) {
      _fa.boltAcc -= every;
      if (_rand() >= SkyRules.t.d('boltChance')) continue;
      final keys = s.town.plots.keys.toList()..sort();
      if (keys.isEmpty) continue;
      final k = keys[(_rand() * keys.length).floor().clamp(0, keys.length - 1)];
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

  /// Misión ganada: los cultivos dan un salto y los peces pueden criar.
  void farmMissionWon() {
    final t = s.town;
    s.town = TownRules.breed(
        _rand,
        t.copyWith(plots: {
          for (final e in t.plots.entries)
            e.key: FarmingRules.missionGrow(e.value),
        }));
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
      s.town = s.town.withBuild(b0.kind == BuildKind.huerta
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
            rareSeed: () => FarmingRules.rareSeed(_rand));
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
        final area =
            FarmingRules.toolBonus(prof, FarmingRules.canOf(prof)).area;
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
                farm: f
                    .copyWith(ferts: {...f.ferts, fid: f.fertCount(fid) - 1})));
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
      x >= 0 &&
      y >= 0 &&
      x < m.width &&
      y < m.height &&
      m.tileAt(x, y) == Tile.soil;

  void _grantHarvest(SessionPlayer p, FarmPlot pl, int tx, int ty) {
    final h = FarmingRules.harvest(_rand, p.profile, pl)!;
    final lvl0 = FarmingRules.level(p.profile);
    var prof = FarmingRules.addHarvest(p.profile, h);
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
    say('${p.name} cosechó ${h.count > 1 ? '${h.count} × ' : ''}'
        '${h.crop.name} (${h.quality.label}).');
    if (h.loot != FarmLootKind.none) _grantFarmLoot(p, h.loot, tx, ty);
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

  /// Habitantes (overworld_biomes.md § 10). Invitar, regalar y entregar
  /// encargos también en su bioma; lo demás, en el pueblo.
  bool _residentAction(SessionPlayer p, TownAction a) {
    final npc = a.id;
    final n = npc == null ? null : biomeNpc(npc);
    if (npc == null || n == null) return false;
    final home = s.place == null;
    final day = math.max(1, s.town.sky.day);
    switch (a.op) {
      case TownOp.invite:
        final r = ResidentRules.invite(s.town, npc);
        if (r == null) return false;
        s.town = r;
        say('${n.name} se muda al pueblo. Hacele una CASA en EDITAR PUEBLO.');
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
        final key = '${p.id}:$day';
        final used = _fa.orderXp[key] ?? 0;
        final r = ResidentRules.deliverOrder(
            p.profile, s.town, npc, ResidentRules.t.i('orderXpDayCap') - used);
        if (r == null) return false;
        final pts = r.$1.treeBonus - p.profile.treeBonus;
        _profileChange(p, r.$1, gain: true);
        s.town = r.$2;
        _fa.orderXp[key] = used + r.$3;
        grantCharXp(p, r.$3);
        say('${p.name} entregó la orden de ${n.name} (+${r.$3} XP'
            '${pts > 0 ? ', +1 punto de árbol' : ''}).');
        return true;
      case TownOp.commission:
        // Encargo de forja de Brann (roles.md § 4): un arma de tu clase,
        // uno por día del mundo.
        if (!home || npc != 'brann') return false;
        final key = 'com:${p.id}:$day';
        if (_fa.orderXp.containsKey(key)) return false;
        final paid = ResidentRules.payCommission(p.profile, s.town);
        if (paid == null) return false;
        _profileChange(p, paid);
        _fa.orderXp[key] = 0;
        final ri = ResidentRules.commissionRarity(s.town.resident('brann'),
            fishLv: FishingRules.level(p.profile),
            farmLv: FarmingRules.level(p.profile));
        final item = rules.loot.generate(_rand,
            itemLevel: ResidentRules.commissionItemLevel(p.profile.level),
            rarity: Rarity.values[ri],
            family: p.profile.classId,
            source: LootSource.chest);
        say('Brann forjó para ${p.name}: ${item.rarity.label.toLowerCase()} '
            'de nivel ${item.itemLevel}.');
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
        final paid =
            casa ? HelperRules.pay(p.profile, ResidentRules.placeCost()) : null;
        if (casa && paid == null) return false;
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
            TownOp.commission:
        return _residentAction(p, a);
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
            '${b.kind == BuildKind.huerta ? 'granjero' : 'pescador'}.');
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
