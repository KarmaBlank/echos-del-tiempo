part of 'session_engine.dart';

// Pesca y agropecuario en la sala (docs/specs/fishing.md § 6). El
// minijuego corre en cada cliente; el anfitrión tira el pez al clavar,
// valida el resultado (picada pendiente, tiempos mínimos, caña) y otorga.

/// Picada pendiente de un jugador (solo en el motor del anfitrión).
class FishPending {
  FishPending(this.fish, this.at, [this.kind = WaterLootKind.fish]);
  final FishCatch fish;
  final double at;

  /// Pez, basura o hallazgo (fishing.md § 8).
  final WaterLootKind kind;
}

/// One player's auto-fishing on the host (fishing.md § 6).
class AutoFishState {
  AutoFishState(this.nextAt);

  /// Session time of the next bite roll.
  double nextAt;

  /// Fish caught since it was turned on.
  int caught = 0;
}

/// Estado de pesca del anfitrión (no viaja en el snapshot).
class FishingHostState {
  final pending = <String, FishPending>{};

  /// Players auto-fishing (fishing.md § 6).
  final auto = <String, AutoFishState>{};
  final lastCast = <String, double>{};

  /// XP de personaje ganada pescando en esta estadía en el pueblo.
  final charXp = <String, int>{};

  /// Raft net progress per player (Red sub-path B, profession_gear.md
  /// § 4.3): one catch each time it reaches 1.
  final net = <String, double>{};

  /// Quién ya avisó en el chat que se puso a pescar (por estadía).
  final announced = <String>{};

  /// Nueva estadía en el pueblo de [ids] (`null` = todos).
  void newStay([Iterable<String>? ids]) {
    if (ids == null) {
      pending.clear();
      auto.clear();
      charXp.clear();
      announced.clear();
      return;
    }
    for (final id in ids) {
      pending.remove(id);
      auto.remove(id);
      charXp.remove(id);
      announced.remove(id);
    }
  }
}

extension _FishingOp on _Op {
  FishingHostState get _f => e.fishing;
  TuningDef get _ft => FishingRules.t;

  bool _inTown(SessionPlayer p) =>
      s.mode == SessionMode.lobby && s.run == null && !p.isCompanion;

  bool fishingAction(SessionPlayer p, SessionAction a) {
    switch (a) {
      case FishBiteAction(:final power):
        return _fishBite(p, power);
      case FishResultAction(:final success):
        return _fishResult(p, success);

      case FishLineAction(:final line):
        return _fishLine(p, line);
      case FishAutoAction(:final on, :final reason):
        if (!on) {
          if (!_f.auto.containsKey(p.id)) return false;
          stopAutoFish(p, reason);
          return true;
        }
        return _autoFishOn(p);
      case SellFishAction(:final species, :final materials):
        if (!_inTown(p)) return false;
        final r = FishingRules.sell(p.profile,
            species: species, materials: materials);
        if (r == null) return false;
        _profileChange(p, r.profile);
        say('${p.name} vendió ${r.sold} pescado${r.sold == 1 ? '' : 's'}'
            '${r.credits > 0 ? ' por ${r.credits} de oro' : ''}'
            '${r.esquirlas > 0 ? '${r.credits > 0 ? ' y' : ' por'} '
                '${r.esquirlas} Esquirla${r.esquirlas == 1 ? '' : 's'}' : ''}.');
        return true;
      case ExchangeFishAction(:final species):
        if (!_inTown(p)) return false;
        if (!_profileChange(
            p, FishingRules.exchangeLegendary(p.profile, species))) {
          return false;
        }
        say('${p.name} canjeó ${kFish[species]!.name} por materiales raros.');
        return true;
      case BuyRodAction(:final rodId):
        if (!_inTown(p)) return false;
        if (!_profileChange(p, FishingRules.buyRod(p.profile, rodId))) {
          return false;
        }
        say('${p.name} compró ${kRods[rodId]!.name}.');
        return true;
      case EquipRodAction(:final rodId):
        return _inTown(p) &&
            _profileChange(p, FishingRules.equipRod(p.profile, rodId));
      default:
        return false;
    }
  }

  bool _fishBite(SessionPlayer p, double power) {
    if (!_inTown(p) || !FishingRules.plausible(p.profile)) return false;
    // Auto-fishing (§ 6) does its own bites.
    if (_f.auto.containsKey(p.id)) return false;
    // Cualquier orilla del lago (v0.22.2), no solo los muelles.
    if (!FishingCast.nearWater(e.mapFor(s), p.x, p.y)) return false;
    final last = _f.lastCast[p.id];
    if (last != null && s.time - last < _ft.d('minCastSec')) return false;
    _f.lastCast[p.id] = s.time;
    final w = _waterSpot(p, power);
    final bonus = w.bonus, dock = w.dock, spot = w.spot;
    // Botín del agua (§ 8): a veces no es un pez.
    final kind =
        FishingRules.rollLoot(_rand, p.profile,
            luck: bonus.rare + dock + (spot ? _ft.d('spotLoot') : 0.0));
    final FishCatch fish;
    switch (kind) {
      case WaterLootKind.fish:
        // Arpón sub-path B (profession_gear.md § 4.3): from the raft over
        // deep water a big fish can be harpooned — rarer and top size.
        final hc = p.rafting
            ? GearRules.harpoonChance(p.profile, fishDepth(e.mapFor(s), p))
            : 0.0;
        final harpoon = hc > 0 && _rand() < hc;
        fish = FishingRules.roll(_rand, w.table,
            rareBonus: w.rare + (harpoon ? 2.0 : 0.0),
            pity: p.profile.life.pity,
            sizeBonus: harpoon ? 1.0 : w.size);
        if (harpoon) say('${p.name} arponeó una pieza grande desde la balsa.');
      case WaterLootKind.basura:
        final junk = w.junk;
        final id = junk[(_rand() * junk.length).floor() % junk.length];
        final d = kFish[id]!;
        fish =
            FishCatch(id, d.minCm + (_rand() * (d.maxCm - d.minCm)).round());
      default:
        fish = const FishCatch(kWaterBundle, 0);
    }
    _f.pending[p.id] = FishPending(fish, s.time, kind);
    events.add(FishBiteEvent(p.id, fish.species, fish.sizeCm));
    if (_f.announced.add(p.id)) say('${p.name} se puso a pescar.');
    return true;
  }

  /// The water [p] fishes in: its table, junk and rarity bonus.
  /// [passive] scales the rod / tree bonuses (auto-fishing, § 6).
  ({
    List<String> table,
    double size,
    List<String> junk,
    double rare,
    double dock,
    bool spot,
    ({double bite, double zone, double rare}) bonus,
  }) _waterSpot(SessionPlayer p, double power, {double passive = 1}) {
    final rb = FishingRules.rodBonus(p.profile);
    final bonus =
        (bite: rb.bite * passive, zone: rb.zone * passive, rare: rb.rare * passive);
    final map = e.mapFor(s);
    // Exterior de bioma (overworld_biomes.md § 3.1): su lago y su tabla.
    final biome = biomeLayout(s.place);
    final wild = biome != null;
    final lake = wild ? null : TownRules.lakeNear(s.town, p.x, p.y);
    final dock = WorldRules.townSpot(p.x, p.y, map: map) == TownSpot.fishing
        ? _ft.d('dockBonus')
        : 0.0;
    // El lago donde pesca (town_editor.md § 5): su tamaño y sus peces.
    // Agua brillante del bioma (fishing.md § 11): mejor rareza y botín.
    final spot = wild &&
        FishingCast.nearHiddenSpot(map, s.place!, math.max(1, s.town.sky.day),
            p.x, p.y, _ft.i('spotRadius'));
    final spotRare = spot ? _ft.d('spotRare') : 0.0;
    // Aguas abiertas (fishing.md § 15): tiles from the bobber (or the
    // raft) to the shore; deep water adds rarity, size and its species.
    final depth = wild ? fishDepth(map, p) : 0;
    final bait = BaitRules.active(p.profile);
    final rare = RaftRules.depthRare(depth) +
        (bait == null ? 0.0 : BaitRules.rare(bait)) +
        bonus.rare +
        dock +
        spotRare +
        (wild ? 0.0 : TownRules.lakeRare(s.town, lake)) +
        _ft.d('distanceBonus') * power.clamp(0.0, 1.0);
    // Horario y clima de cada pez (fishing.md § 13): fuera de su franja
    // casi nunca pica.
    // Estación y clima del lugar (weather_seasons.md § 4): fuera de
    // estación no pica; se suman los visitantes de la estación / clima.
    final table = LifeTimeRules.activeTable(
        wild
            ? [...biome.fish, ...deepFishOf(s.place, depth)]
            : TownRules.lakeRoll(s.town, lake),
        s.town.sky,
        _rand,
        biome: wild ? s.place : kTownStartBiome,
        weather: SkyRules.nowIn(s.town.sky, s.place));
    // Cebo (fishing.md § 14): the fish it attracts weigh more, plus its
    // rarity and size bonuses. Same rule for manual and auto.
    final junk = wild ? biome.junk : kWaterJunk;
    return (
      table: BaitRules.weighted(table, bait),
      size: math.min(1.0,
          (bait == null ? 0.0 : BaitRules.size(bait)) + RaftRules.depthSize(depth) +
              // Hondura sub-path B: bigger fish.
              GearRules.bigBonus(p.profile)),
      junk: junk,
      rare: rare,
      dock: dock,
      spot: spot,
      bonus: bonus,
    );
  }

  /// Depth (tiles to the shore) [p] fishes at: under the bobber, or
  /// under the raft when there is no bobber yet (fishing.md § 15).
  static int fishDepth(GameMap map, SessionPlayer p) {
    final l = p.fishLine;
    if (l != null && l.hasBobber) return RaftRules.depthAt(map, l.bx, l.by);
    return p.rafting ? RaftRules.depthAt(map, p.x, p.y) : 0;
  }

  // ---------------- auto-fishing (fishing.md § 6) ----------------

  TuningDef get _at => tuning(TuningId.town);

  /// Seconds until the next auto bite: the manual wait with the bonuses
  /// at `autoPassiveMult`, × `autoWaitMult`.
  double _autoWait(SessionPlayer p) {
    final bait = BaitRules.active(p.profile);
    final bite =
        FishingRules.rodBonus(p.profile).bite * _at.d('autoPassiveMult') +
            (bait == null ? 0.0 : BaitRules.bite(bait));
    return FishingRules.biteDelay(_rand(), bite) *
        math.max(0.1, _at.d('autoWaitMult')) *
        // Calma sub-path A (life_trees_v2.md § 2.1): calmer, faster bites.
        GearRules.calmMult(p.profile);
  }

  /// `fAuto {on}`: with the rod out at the water, the host fishes for [p].
  bool _autoFishOn(SessionPlayer p) {
    final line = p.fishLine;
    if (line == null ||
        _f.auto.containsKey(p.id) ||
        !_inTown(p) ||
        !FishingRules.plausible(p.profile) ||
        !FishingCast.nearWater(e.mapFor(s), p.x, p.y)) {
      return false;
    }
    _f.pending.remove(p.id);
    p.fishLine = line.withAuto(true);
    _f.auto[p.id] = AutoFishState(s.time + _autoWait(p));
    return true;
  }

  /// Stops [p]'s auto-fishing (if on) and tells everyone why.
  void stopAutoFish(SessionPlayer p, AutoFishStop why) {
    final st = _f.auto.remove(p.id);
    if (st == null) return;
    if (p.fishLine case final l?) p.fishLine = l.withAuto(false);
    events.add(FishAutoStoppedEvent(p.id, why, st.caught));
  }

  /// Every host tick: stop whoever can't keep fishing, roll the bites
  /// that are due. Storm (`stormBite`) still applies.
  void autoFishTick() {
    if (_f.auto.isEmpty) return;
    for (final id in [..._f.auto.keys]) {
      final p = s.players[id];
      final st = _f.auto[id]!;
      if (p == null) {
        _f.auto.remove(id);
        continue;
      }
      if (!_inTown(p)) {
        stopAutoFish(p,
            s.mode == SessionMode.battle ? AutoFishStop.battle : AutoFishStop.left);
        continue;
      }
      if (p.fishLine == null) {
        stopAutoFish(p, AutoFishStop.moved);
        continue;
      }
      if (s.time < st.nextAt) continue;
      st.nextAt = s.time + _autoWait(p);
      if (_rand() >= SkyRules.biteChance(s.town.sky, s.place)) continue;
      final w = _waterSpot(p, 0, passive: _at.d('autoPassiveMult'));
      final fish = FishingRules.roll(_rand, w.table,
          rareBonus: w.rare,
          noLegend: true,
          epicMult: _at.d('autoEpicMult'),
          sizeBonus: w.size);
      st.caught++;
      _grantFish(p, fish, auto: true, log: true);
    }
  }

  /// Red sub-path B (profession_gear.md § 4.3): a player sailing a raft
  /// with the net fishes on their own — `net` catches every
  /// `netEverySec` (never legendary, auto quality).
  void raftNetTick(double dt) {
    for (final p in players) {
      if (!p.rafting || p.isCompanion || !_inTown(p)) {
        _f.net.remove(p.id);
        continue;
      }
      final rate = GearRules.netRate(p.profile);
      if (rate <= 0) continue;
      final acc = (_f.net[p.id] ?? 0) +
          dt / math.max(1.0, GearRules.t.d('netEverySec')) * rate;
      if (acc < 1) {
        _f.net[p.id] = acc;
        continue;
      }
      _f.net[p.id] = acc - 1;
      final w = _waterSpot(p, 0, passive: _at.d('autoPassiveMult'));
      final fish = FishingRules.roll(_rand, w.table,
          rareBonus: w.rare, auto: true, sizeBonus: w.size);
      _grantFish(p, fish, auto: true, log: true);
      say('La red de la balsa de ${p.name} sacó algo.');
    }
  }

  /// `fLn`: lo que los demás ven de la pesca (caña, línea, boya). Solo
  /// en el pueblo, cerca del agua y con la boya en un tile del lago.
  bool _fishLine(SessionPlayer p, FishLine? line) {
    if (line == null) {
      stopAutoFish(p, AutoFishStop.moved);
      p.fishLine = null;
      return true;
    }
    if (!_inTown(p) || !FishingRules.plausible(p.profile)) return false;
    final map = e.mapFor(s);
    if (!FishingCast.nearWater(map, p.x, p.y)) return false;
    if (line.hasBobber &&
        !FishingCast.plausibleBobber(map, p.x, p.y, line.bx, line.by)) {
      return false;
    }
    p.fishLine = line.withAuto(_f.auto.containsKey(p.id));
    return true;
  }

  bool _fishResult(SessionPlayer p, bool success) {
    final pend = _f.pending[p.id];
    if (pend == null || !_inTown(p)) return false;
    if (success && s.time - pend.at < _ft.d('minReelSec')) return false;
    _f.pending.remove(p.id);
    if (!success) return true;
    if (pend.kind == WaterLootKind.fish || pend.kind == WaterLootKind.basura) {
      _grantFish(p, pend.fish, log: pend.kind == WaterLootKind.fish);
      p.profile = FishingRules.markDry(p.profile, pend.kind);
    } else {
      _grantWaterLoot(p, pend.kind);
    }
    return true;
  }


  /// Materiales, cofre hundido o arma (fishing.md § 8). Va al inventario
  /// con las reglas de siempre (lo que no entra, al piso o al alijo).
  void _grantWaterLoot(SessionPlayer p, WaterLootKind kind) {
    final lvl = math.max(1, p.profile.level);
    final drops = <LootDrop>[];
    var label = '';
    var rarity = Rarity.raro;
    switch (kind) {
      case WaterLootKind.materiales:
        final lo = _ft.i('lootMatMin');
        final hi = math.max(lo, _ft.i('lootMatMax'));
        final cristal = _rand() < 0.25;
        final k = cristal ? StackKind.cristal : StackKind.esquirla;
        final n = cristal ? 1 : lo + (_rand() * (hi - lo + 1)).floor();
        drops.add(LootDrop.stack(k, n));
        label = '$n ${k.label}';
        // Sometimes a bait comes up with it (fishing.md § 14.4).
        if (_rand() < _ft.d('baitWaterChance')) {
          final b = BaitRules.foundBait(_rand());
          p.profile = p.profile.copyWith(life: p.profile.life.addBait(b));
          label = '$label y ${kBaits[b]!.name}';
        }
        rarity = cristal ? Rarity.epico : Rarity.raro;
      case WaterLootKind.cofre:
        final tier = _rand() < 0.15 ? ChestTier.plata : ChestTier.madera;
        final def = kChestTiers[tier]!;
        final cr = ((20 + (_rand() * 31).floor()) * def.creditMult).round();
        p.profile = p.profile.copyWith(credits: p.profile.credits + cr);
        drops.addAll(_chestDrops(p, def, lvl));
        label = 'un cofre hundido (+$cr de oro)';
        rarity = tier == ChestTier.plata ? Rarity.epico : Rarity.raro;
        // profession_gear.md § 4.1: sometimes a sunken echo weapon inside.
        if (_rand() < GearRules.sunkenChestChance(p.profile)) {
          final w = GearRules.sunken(rules.loot, _rand, p.profile,
              LootRules.itemLevelFor(lvl, LootSource.chest, cap: _lootCap()),
              manual: !_f.auto.containsKey(p.id));
          drops.add(LootDrop.item(w));
          if (w.rarity.index > rarity.index) rarity = w.rarity;
        }
      case WaterLootKind.arma:
        final il =
            LootRules.itemLevelFor(lvl, LootSource.chest, cap: _lootCap());
        // profession_gear.md § 4.1: a sunken echo weapon (fishing only).
        if (_rand() <
            GearRules.sunkenChance(p.profile, fishDepth(e.mapFor(s), p))) {
          final item = GearRules.sunken(rules.loot, _rand, p.profile, il,
              manual: !_f.auto.containsKey(p.id));
          final d = LootDrop.item(item);
          drops.add(d);
          label = _dropText(d);
          rarity = item.rarity;
          break;
        }
        final pool = [
          for (final id in kFishingLegendaries)
            if (kUniques[id] case final u?
                when catalog.weapons.containsKey(u.baseId))
              u,
        ];
        final legend = pool.isNotEmpty &&
            FishingRules.legendEligible(p.profile) &&
            _rand() < _ft.d('lootLegendChance');
        final item = legend
            ? rules.loot.generateUnique(
                _rand, pool[(_rand() * pool.length).floor() % pool.length], il)
            : rules.loot.generate(_rand,
                itemLevel: il,
                family: p.profile.classId,
                source: LootSource.chest);
        final d = LootDrop.item(item);
        drops.add(d);
        label = _dropText(d);
        rarity = item.rarity;
      default:
        return;
    }
    // Pity del botín y un poco de XP de Pesca por el hallazgo.
    final marked = FishingRules.markDry(p.profile, kind);
    p.profile = marked.copyWith(
        life: marked.life.copyWith(fishXp: marked.life.fishXp + 10));
    events.add(WaterLootEvent(p.id, label, rarity.index));
    say('${p.name} sacó del agua $label.');
    _deliver(p, drops, LootSource.mission, p.x, p.y, stashOverflow: true);
  }

  void _grantFish(SessionPlayer p, FishCatch c,
      {bool auto = false, bool log = false}) {
    final lvl0 = FishingRules.level(p.profile);
    final first = log && !p.profile.life.discovered(c.species);
    // Auto-fishing (§ 6): XP × `autoXpMult`, tree at `autoPassiveMult`,
    // pity untouched.
    final xm = auto ? _at.d('autoXpMult') : 1.0;
    var prof = FishingRules.addCatch(p.profile, c,
        keepPity: auto,
        xpMult: xm,
        treeMult: auto ? _at.d('autoPassiveMult') : 1.0);
    if (log) {
      prof = prof.copyWith(
          life: prof.life
              .logCatch(c.species, c.sizeCm)
              // Fishing journal (cozy_life.md § 4): where and when.
              .logFishFind(c.species, s.place ?? kPueblo, s.town.sky.day));
      // One bait per catch (fishing.md § 14.3), manual or auto.
      final bait = BaitRules.active(prof);
      if (bait != null) prof = BaitRules.consume(prof, bait);
    }
    // Primera captura de la especie (fishing.md § 10): XP de Pesca y de
    // personaje extra, sin el tope por estadía.
    var firstXp = 0;
    if (first) {
      prof = prof.copyWith(
          life: prof.life.copyWith(
              fishXp: prof.life.fishXp +
                  FishingRules.fishXp(c) * _ft.i('firstCatchFishXp')));
      firstXp = FishingRules.charXp(c) * _ft.i('firstCatchCharXp');
    }
    // XP de personaje con tope por estadía (town_loop.md § 11c).
    final used = _f.charXp[p.id] ?? 0;
    final cxp = math.min((FishingRules.charXp(c) * xm).round(),
        math.max(0, _ft.i('charXpCap') - used));
    if (cxp > 0) {
      _f.charXp[p.id] = used + cxp;
      final g = rules.gainXp(prof, cxp);
      prof = g.profile;
      if (g.levelsGained > 0) events.add(LevelUpEvent(p.id, prof.level));
    }
    _profileChange(p, prof, gain: true);
    events.add(FishCaughtEvent(p.id, c.species, c.sizeCm, auto: auto));
    say('${p.name} pescó ${c.def.name} (${c.sizeCm} cm, ${c.rarity.label})'
        '${auto ? ' (auto-pesca)' : ''}.');
    // Calma sub-path B (profession_gear.md § 4.3): sometimes two at once.
    final twin = GearRules.twinChance(p.profile);
    if (log && twin > 0 && _rand() < twin) {
      _profileChange(p,
          p.profile.copyWith(life: p.profile.life.addFish(c.species)),
          gain: true);
      say('${p.name} sacó dos de una: otro ${c.def.name}.');
    }
    if (first) {
      say('Especie nueva en el bestiario de pesca de ${p.name}: '
          '${c.def.name}.');
      grantCharXp(p, firstXp);
    }
    final lvl1 = FishingRules.level(prof);
    if (lvl1 > lvl0) {
      say('${p.name} subió Pesca a nivel $lvl1.');
      lifeLevelXp(p, lvl1);
    }
  }
}
