part of 'session_engine.dart';

// Travesía (docs/specs/roguelike.md, "MVP implementado"): por ahora la run
// vive dentro de la sesión para reusar la red autoritativa del host, el
// combate, el inventario, la tienda y el crafteo tal cual. Todo se activa
// solo con `SessionEngine.gameMode == GameModeKind.travesia`; el Mundo no
// pasa por acá (salvo los ganchos que devuelven `null` / `false`).

extension _RunOp on _Op {
  bool get isRun => e.gameMode == GameModeKind.travesia;

  RunRules get _runRules => RunRules(catalog: catalog);

  RewardOfferRules get _offers =>
      RewardOfferRules(tree: rules.treeRules.catalog, catalog: catalog);

  /// En la Travesía decide la acción [a] (`true` / `false`) o devuelve
  /// `null` para que siga el camino normal. En el Mundo siempre `null`,
  /// salvo las acciones de la run (rechazadas).
  bool? runGate(SessionPlayer p, SessionAction a) {
    final isRunAction = a is RunStartAction ||
        a is RunPrepAction ||
        a is RunVoteAction ||
        a is RunRewardAction ||
        a is RunReadyAction ||
        a is RunBuyUltAction ||
        a is RunSkillAction ||
        a is RunUpgradeSkillAction;
    if (!isRun) return isRunAction ? false : null;
    final r = s.run;
    final stop = r != null && r.phase == RunPhase.stop && r.node != null
        ? RunRules.floorOf(r).node(r.node!).type
        : null;
    switch (a) {
      case RunStartAction():
        return startRun(p, a);
      case RunPrepAction(:final prep):
        final r0 = s.run;
        if (p.isCompanion ||
            !(s.mode == SessionMode.lobby ||
                (s.mode == SessionMode.run && r0?.phase == RunPhase.over))) {
          return false;
        }
        e.runPreps[p.id] = prep;
        return true;
      case RunVoteAction(:final nodeId):
        return runVote(p, nodeId);
      case RunRewardAction():
        return runReward(p, a);
      case RunReadyAction():
        return runReady(p);
      case RunSkillAction(:final skillId, :final equip):
        return runSkill(p, skillId, equip: equip);
      case RunUpgradeSkillAction(:final skillId):
        return stop == RunNodeType.armeria && runUpgradeSkill(p, skillId);
      case RunBuyUltAction(:final ultId):
        return stop == RunNodeType.tienda && runBuyUlt(p, ultId);
      // Comprar: solo en la tienda. Forjar / fusionar: solo en la armería.
      case BuyItemAction() || BuyWeaponAction():
        return stop == RunNodeType.tienda ? null : false;
      // Condensar es del Mundo (materials_economy.md § 4.3): la Travesía
      // no tiene economía de materiales entre runs.
      case CraftAction(op: CraftOp.condense):
        return false;
      case CraftAction(:final op) when !op.destroys:
        return stop == RunNodeType.armeria ? null : false;
      case FuseAction() || UpgradeAction() || EcoCraftAction():
        return stop == RunNodeType.armeria ? null : false;
      // Lo del Mundo que la Travesía no tiene: misiones, pueblo, alijo,
      // progresión por puntos (el árbol crece solo con recompensas).
      case ProposeMissionAction() ||
            VoteMissionAction() ||
            ReadyAction() ||
            CancelPrepAction() ||
            ActivateSealAction() ||
            ChangeClassAction() ||
            RespecAction() ||
            AllocateStatsAction() ||
            TakeNodeAction() ||
            TakeNodesAction() ||
            ChooseMilestoneAction() ||
            UntakeNodeAction() ||
            ResetTreeAction() ||
            StashPutAction() ||
            StashTakeAction() ||
            BackToLobbyAction() ||
            LeaveReadyAction() ||
            TakeLostLootAction() ||
            FishBiteAction() ||
            FishResultAction() ||
            SellFishAction() ||
            ExchangeFishAction() ||
            BuyRodAction() ||
            EquipRodAction() ||
            FarmTileAction() ||
            FarmShopAction() ||
            TownAction() ||
            LifeTreeAction() ||
            UseStairsAction() ||
            InteractPoiAction() ||
            PickUpAction() ||
            DropItemAction() ||
            ProposeEcoAction() ||
            DevGrantEcoAction() ||
            ProposeTrialAction() ||
            ChooseAscensionAction() ||
            TakeAscensionNodeAction() ||
            ResetAscensionAction() ||
            DevGrantTrialAction() ||
            ProposeAbyssAction() ||
            StartTutorialAction() ||
            DevAbyssAction():
        return false;
      default:
        return null;
    }
  }

  /// Un jugador nuevo de la Travesía entra con su personaje de run (sin
  /// niveles: los atributos son la base de la clase, § 5).
  PlayerProfile runEntryProfile(PlayerProfile normalized) =>
      isRun ? RunRules.runProfile(rules, normalized) : normalized;

  // ---------------- guardado (§ 8.5) ----------------

  RunSave? runSave() {
    final r = s.run;
    if (!isRun || r == null || r.phase == RunPhase.over) return null;
    final run = r.copy()
      ..votes.clear()
      ..offers.clear()
      ..ready.clear()
      ..boons.clear()
      ..loadout.clear()
      ..skills.clear()
      ..skillUps.clear();
    return RunSave(run: run, players: [
      for (final p in players)
        RunSavePlayer(
          profile: p.profile,
          hp: p.hp,
          mp: p.mp,
          ult: p.ult,
          boons: [...?r.boons[p.id]],
          loadout: [...?r.loadout[p.id]],
          skills: [...?r.skills[p.id]],
          skillUps: [...?r.skillUps[p.id]],
        ),
      // Los que no volvieron siguen en el guardado.
      ...e.runParked.values,
    ]);
  }

  void resumeRun(RunSave save) {
    final run = save.run.copy()
      ..votes.clear()
      ..offers.clear()
      ..ready.clear()
      ..boons.clear()
      ..loadout.clear()
      ..skills.clear()
      ..skillUps.clear();
    e.runParked
      ..clear()
      ..addEntries([for (final q in save.players) MapEntry(q.key, q)]);
    s
      ..run = run
      ..mode = SessionMode.run
      ..battle = null;
    // El anfitrión retoma el primero de su clase si cambió de nombre.
    final ps = players.toList();
    for (final p in ps) {
      runClaim(p, any: identical(p, ps.first));
    }
    say('Travesía retomada: piso ${run.floor + 1}, '
        '${_zoneName(run, run.floor)}.');
    final at = run.node;
    if (run.phase == RunPhase.battle && at != null) {
      final n = RunRules.floorOf(run).node(at);
      _runBattle(run, n, RunRules.enemyLevel(run.floor, n));
    } else if (run.phase == RunPhase.reward) {
      _advance(run);
    }
  }

  /// [p] entra a una run retomada: recupera su personaje guardado (por
  /// nombre y clase; con [any], el primero de su clase que quede).
  void runClaim(SessionPlayer p, {bool any = false}) {
    final parked = e.runParked;
    if (!isRun || parked.isEmpty || s.run == null) return;
    var key = RunSavePlayer.keyOf(p.profile);
    if (!parked.containsKey(key) && any) {
      key = parked.keys.firstWhere(
          (k) => parked[k]!.profile.classId == p.profile.classId,
          orElse: () => key);
    }
    final q = parked.remove(key);
    if (q == null) return;
    p
      ..profile = rules.normalize(q.profile)
      ..ult = q.ult;
    refresh(p);
    p
      ..hp = math.min(q.hp, p.maxHp.toDouble())
      ..mp = math.min(q.mp, p.maxMp.toDouble());
    if (q.boons.isNotEmpty) s.run!.boons[p.id] = [...q.boons];
    if (q.loadout.isNotEmpty) s.run!.loadout[p.id] = [...q.loadout];
    if (q.skills.isNotEmpty) s.run!.skills[p.id] = [...q.skills];
    if (q.skillUps.isNotEmpty) s.run!.skillUps[p.id] = [...q.skillUps];
  }

  /// Se fue un jugador: sus marcas dejan de contar.
  void runPlayerLeft(String id) {
    final r = s.run;
    if (r == null) return;
    r.votes.remove(id);
    r.offers.remove(id);
    r.ready.remove(id);
  }

  bool startRun(SessionPlayer p, RunStartAction a) {
    final r = s.run;
    final canStart = s.mode == SessionMode.lobby ||
        (s.mode == SessionMode.run && r?.phase == RunPhase.over);
    if (!canStart || p.isCompanion) return false;
    e.runParked.clear();
    final run = RunState(
      seed: e._seeds(),
      zones: _runRules.floorZones(unlocked: a.zones),
      difficulty: math.max(0, a.difficulty),
      eliteWins: a.eliteWins,
    );
    s
      ..run = run
      ..mode = SessionMode.run
      ..battle = null;
    // Personajes nuevos para cada run (los de la anterior se descartan).
    for (final q in players) {
      q.profile = RunRules.runProfile(rules, q.profile);
      q.ult = 0;
      _applyPrep(run, q, e.runPreps[q.id] ?? RunPrep.none);
      refresh(q);
      fill(q);
    }
    say('¡Comienza la Travesía! Piso 1: ${_zoneName(run, 0)}. '
        'Marquen el camino en el mapa.');
    return true;
  }

  /// Bonos del árbol de afuera y loadout de [q] (§ 8.1).
  void _applyPrep(RunState r, SessionPlayer q, RunPrep prep) {
    const cap = ProgressionRules.maxItems;
    final pr = q.profile;
    q.profile = pr.copyWith(
      credits: pr.credits + math.max(0, prep.gold),
      potions: math.min(cap, pr.potions + math.max(0, prep.potions)),
      ethers: math.min(cap, pr.ethers + math.max(0, prep.ethers)),
      attributes: pr.attributes.add({
        for (final e in prep.attributes.entries)
          if (e.key != Attribute.agi) e.key: math.max(0, e.value),
      }),
    );
    final skills = [
      for (final s in prep.skills.take(math.min(
          MetaProgressRules.loadoutSlots, RunTuning.freeSkillSlots)))
        if (catalog.skills.containsKey(s)) s,
    ];
    if (skills.isNotEmpty) r.loadout[q.id] = skills;
    final boons = [
      for (final b in prep.boons)
        if (RunBoon.byName(b) != null) b,
    ];
    if (boons.isNotEmpty) r.boons[q.id] = boons;
  }

  String _zoneName(RunState r, int floor) =>
      catalog.zone(r.zones[floor])?.name ?? 'Zona ${r.zones[floor]}';

  bool runVote(SessionPlayer p, int nodeId) {
    final r = s.run;
    if (s.mode != SessionMode.run ||
        r == null ||
        r.phase != RunPhase.map ||
        p.isCompanion ||
        !RunRules.reachable(r).contains(nodeId)) {
      return false;
    }
    r.votes[p.id] = nodeId;
    return true;
  }

  bool runReward(SessionPlayer p, RunRewardAction a) {
    final r = s.run;
    final offer = r?.offers[p.id];
    if (s.mode != SessionMode.run ||
        r == null ||
        r.phase != RunPhase.reward ||
        offer == null) {
      return false;
    }
    final next = RunRules.applyReward(rules, p.profile, offer,
        tree: a.tree, weapon: a.weapon, extra: a.extra, ult: a.ult);
    if (next == null) return false;
    // Habilidad nueva (§ 12.2): entra si hay lugar; si no, se sacrifica
    // una libre ([RunRewardAction.drop]).
    final skill = a.extra == null ? null : offer.extras[a.extra!].skill;
    if (skill != null) {
      final eq = r.loadout[p.id] ??= [];
      if (r.ownedSkills(p.id).contains(skill)) return false;
      if (eq.length >= RunTuning.freeSkillSlots) {
        final drop = a.drop;
        if (drop == null || !eq.contains(drop)) return false;
        eq.remove(drop);
        r.skillUps[p.id]?.removeWhere((s) => s == drop);
      }
      eq.add(skill);
    }
    p.profile = next;
    final boon = a.extra == null ? null : offer.extras[a.extra!].boon;
    if (boon != null) (r.boons[p.id] ??= []).add(boon);
    r.offers.remove(p.id);
    refresh(p, gain: true);
    return true;
  }

  /// Compra en la tienda una ULT de su surtido (§ 12.2): queda aprendida
  /// y activa.
  bool runBuyUlt(SessionPlayer p, String ultId) {
    final r = s.run;
    if (r == null || r.node == null || p.isCompanion) return false;
    final stock = _offers.shopUlts(p.profile,
        seed: r.seed, floor: r.floor, node: r.node!);
    final price = RunTuning.ultPrice;
    if (!stock.contains(ultId) || p.profile.credits < price) return false;
    p.profile = UltRules.learn(p.profile, ultId).copyWith(
        credits: p.profile.credits - price, ultSel: () => ultId);
    refresh(p);
    say('${p.name} compró una ULT.');
    return true;
  }

  /// Equipa o guarda una habilidad libre propia (fuera de combate).
  bool runSkill(SessionPlayer p, String skillId, {required bool equip}) {
    final r = s.run;
    if (r == null ||
        s.mode != SessionMode.run ||
        r.phase == RunPhase.over ||
        p.isCompanion) {
      return false;
    }
    final eq = r.loadout[p.id] ??= [];
    final bag = r.skills[p.id] ??= [];
    if (equip) {
      if (!bag.contains(skillId) || eq.length >= RunTuning.freeSkillSlots) {
        return false;
      }
      bag.remove(skillId);
      eq.add(skillId);
    } else {
      if (!eq.remove(skillId)) return false;
      bag.add(skillId);
    }
    return true;
  }

  /// Mejora una habilidad libre propia en la armería (§ 12.2).
  bool runUpgradeSkill(SessionPlayer p, String skillId) {
    final r = s.run;
    if (r == null || p.isCompanion || !r.ownedSkills(p.id).contains(skillId)) {
      return false;
    }
    final lv = r.skillLevel(p.id, skillId);
    if (lv >= RunTuning.skillUpMax) return false;
    final cost = RunTuning.skillUpCost(lv + 1);
    if (p.profile.credits < cost) return false;
    p.profile = p.profile.copyWith(credits: p.profile.credits - cost);
    (r.skillUps[p.id] ??= []).add(skillId);
    say('${p.name} mejoró ${catalog.skills[skillId]?.name ?? skillId} '
        '(nivel ${lv + 1}).');
    return true;
  }

  bool runReady(SessionPlayer p) {
    final r = s.run;
    if (s.mode != SessionMode.run ||
        r == null ||
        r.phase != RunPhase.stop ||
        p.isCompanion ||
        r.ready.contains(p.id)) {
      return false;
    }
    r.ready.add(p.id);
    return true;
  }

  /// `SessionMode.run`: resuelve la votación y espera recompensas / LISTO.
  void runTick() {
    final r = s.run;
    final hs = humans.toList();
    if (r == null || hs.isEmpty) return;
    switch (r.phase) {
      case RunPhase.map:
        if (!hs.every((h) => r.votes.containsKey(h.id))) return;
        final votes = {for (final h in hs) h.id: r.votes[h.id]!};
        final to = RunRules.resolveVote(votes,
            seed: r.seed, floor: r.floor, from: r.node);
        r.votes.clear();
        _enterNode(r, to);
      case RunPhase.reward:
        if (r.offers.isEmpty) _advance(r);
      case RunPhase.stop:
        if (hs.every((h) => r.ready.contains(h.id))) {
          r.ready.clear();
          _advance(r);
        }
      case RunPhase.battle:
      case RunPhase.over:
        break;
    }
  }

  void _enterNode(RunState r, int id) {
    final n = RunRules.floorOf(r).node(id);
    r.node = id;
    events.add(RunNodeEnteredEvent(r.floor, id));
    // Sin niveles ni XP (§ 5): el personaje solo crece con recompensas.
    final level = RunRules.enemyLevel(r.floor, n);
    if (n.type.isFight) {
      _runBattle(r, n, level);
      return;
    }
    r.phase = RunPhase.stop;
    r.ready.clear();
    switch (n.type) {
      case RunNodeType.descanso:
        for (final q in players) {
          q
            ..hp = RunRules.rested(q.hp, q.maxHp)
            ..mp = RunRules.rested(q.mp, q.maxMp);
        }
        say('Descanso: el grupo recupera fuerzas.');
      case RunNodeType.tienda:
        say('Tienda: compren con su oro y den LISTO.');
      case RunNodeType.armeria:
        say('Armería: forja y fusión. Den LISTO para seguir.');
      default:
        break;
    }
  }

  void _runBattle(RunState r, RunNode n, int baseLevel) {
    var level = baseLevel;

    final eliteType = n.type == RunNodeType.elite
        ? _runRules.eliteOf(r.zones[r.floor], r.eliteWins, _rand)
        : null;
    final group =
        _runRules.enemyGroup(r.zones[r.floor], r.floor, n, _rand, elite: eliteType);
    if (eliteType != null) {
      level += RunRules.eliteRepeatLevels(r.eliteWins[eliteType] ?? 0);
    }
    // El maná arranca lleno en cada pelea; vida y carga de ULT siguen
    // como quedaron (§ 6).
    for (final p in players) {
      p.mp = p.maxMp.toDouble();
    }
    s.seq++;
    final step = e.battles.start(
      party: [for (final p in players) _runMember(r, p, n)],
      enemyTypes: group,
      elite: n.type == RunNodeType.elite,
      triggeredBy: humans.firstOrNull?.id,
      // Travesía: turno del grupo / turno enemigo (§ 6).
      turnRule: TurnRule.porBando,
    );
    ZoneRules.scaleBattle(step.state, level, curve: catalog.curve);
    // Curva de la Travesía y dificultad (§ 8.2): vida y ATQ enemigos.
    {
      final (hp, atk) = MetaProgressRules.difficultyMults(r.difficulty);
      for (final en in step.state.enemies) {
        en
          ..maxHp = (en.maxHp * hp).round()
          ..hp = (en.hp * hp).round()
          ..attack = (en.attack * atk).round();
      }
    }
    // Mejora «Pulso al empezar» (§ 4).
    for (final c in step.state.party) {
      final extra = RunRules.boonPulse(r.boons[c.id] ?? const []);
      if (extra > 0) {
        c.pulse = math.min(BattleEngine.pulseMax, c.pulse + extra);
      }
    }
    final boss = n.type == RunNodeType.jefe;
    final elite = n.type == RunNodeType.elite;
    s.battle = SessionBattle(
      id: s.seq,
      state: step.state,
      fieldEnemyId: -1,
      boss: boss,
      elite: elite,
      level: level,
    );
    r.phase = RunPhase.battle;
    s.mode = SessionMode.battle;
    events.add(BattleStartedEvent(s.seq, -1, boss: boss, elite: elite));
  }

  /// La entrada al combate de [p] con sus mejoras directas (§ 4).
  BattlePartyMember _runMember(RunState r, SessionPlayer p, RunNode n) {
    final m = e.partyMember(p);
    final mods = RunRules.boonMods(r.boons[p.id] ?? const [],
        eliteFight: n.type != RunNodeType.combate);
    final skills = r.loadout[p.id] ?? const <String>[];
    final scale = RunRules.skillScale(r.skillUps[p.id] ?? const []);
    if (mods.isEmpty && skills.isEmpty && scale.isEmpty) return m;
    return BattlePartyMember(
      id: m.id,
      name: m.name,
      build: ExplorationRules.withMods(m.build, mods),
      hp: m.hp,
      mp: m.mp,
      ult: m.ult,
      potions: m.potions,
      ethers: m.ethers,
      aethers: m.aethers,
      fusedSkillId: m.fusedSkillId,
      extraSkills: skills,
      skillScale: scale,
    );
  }

  /// Fin de una pelea de la run (en vez del botín y la XP del Mundo).
  void runBattleFinished(bool victory) {
    final r = s.run!;
    final foes = s.battle?.state.enemies ?? const [];
    s.battle = null;
    for (final p in players) {
      p.epoch++;
      if (p.hp <= 0) p.hp = 1;
      refresh(p);
    }
    if (!victory) {
      _endRun(r, false);
      return;
    }
    r.wins++;
    final n = RunRules.floorOf(r).node(r.node!);
    if (n.type == RunNodeType.elite) {
      final t = foes.firstOrNull?.enemyType;
      if (t != null) r.elitesBeaten.add(t);
    }
    if (n.type == RunNodeType.jefe) r.bossesBeaten++;
    final gold = switch (n.type) {
      RunNodeType.jefe => RunTuning.goldJefe,
      RunNodeType.elite => RunTuning.goldElite,
      _ => RunTuning.goldCombate,
    };
    for (final p in players) {
      p.profile = p.profile.copyWith(credits: p.profile.credits + gold);
    }
    if (n.type == RunNodeType.jefe && r.floor >= RunTuning.floors - 1) {
      _endRun(r, true);
      return;
    }
    r.offers.clear();
    // ULT de rama: rara y valiosa (§ 12.2), de 1 a 3 opciones; la
    // probabilidad sube con el tipo de pelea.
    final ults = _rand() < RunTuning.ultChance(n.type);
    final ultCount = ults ? RunTuning.ultCount(_rand()) : 0;
    for (final h in humans) {
      final streak = r.missStreak[h.id] ?? 0;
      final (offer, hit) = _offers.offer(h.profile,
          floor: r.floor,
          rnd: _rand,
          missStreak: streak,
          ults: ults,
          ultCount: ultCount,
          ownedSkills: r.ownedSkills(h.id));
      r.offers[h.id] = offer;
      if (_offers.mainPath(h.profile) != null) {
        r.missStreak[h.id] = hit ? 0 : streak + 1;
      }
    }
    r.phase = RunPhase.reward;
    s.mode = SessionMode.run;
    say('¡Victoria! +$gold de oro. Elijan su recompensa.');
  }

  /// Después de la recompensa o del LISTO: al mapa (o al piso siguiente
  /// si se venció al jefe).
  void _advance(RunState r) {
    final at = r.node;
    if (at != null && RunRules.floorOf(r).node(at).type == RunNodeType.jefe) {
      r
        ..floor += 1
        ..node = null;
      say('Piso ${r.floor + 1}: ${_zoneName(r, r.floor)}.');
    }
    r.phase = RunPhase.map;
    r.votes.clear();
    s.mode = SessionMode.run;
  }

  void _endRun(RunState r, bool victory) {
    e.runParked.clear();
    r
      ..phase = RunPhase.over
      ..victory = victory
      ..votes.clear()
      ..offers.clear()
      ..ready.clear();
    s.mode = SessionMode.run;
    events.add(RunEndedEvent(victory));
    say(victory
        ? '¡Travesía completada! El último guardián cayó.'
        : 'El grupo cayó. Fin de la Travesía.');
  }
}
