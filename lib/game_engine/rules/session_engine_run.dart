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
        a is RunVoteAction ||
        a is RunRewardAction ||
        a is RunReadyAction;
    if (!isRun) return isRunAction ? false : null;
    final r = s.run;
    final stop = r != null && r.phase == RunPhase.stop && r.node != null
        ? RunRules.floorOf(r).node(r.node!).type
        : null;
    switch (a) {
      case RunStartAction():
        return startRun(p);
      case RunVoteAction(:final nodeId):
        return runVote(p, nodeId);
      case RunRewardAction():
        return runReward(p, a);
      case RunReadyAction():
        return runReady(p);
      // Comprar: solo en la tienda. Forjar / fusionar: solo en la armería.
      case BuyItemAction() || BuyWeaponAction():
        return stop == RunNodeType.tienda ? null : false;
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

  /// Un jugador nuevo de la Travesía entra con su personaje de run.
  PlayerProfile runEntryProfile(PlayerProfile normalized) =>
      isRun ? RunRules.runProfile(rules, normalized) : normalized;

  /// Se fue un jugador: sus marcas dejan de contar.
  void runPlayerLeft(String id) {
    final r = s.run;
    if (r == null) return;
    r.votes.remove(id);
    r.offers.remove(id);
    r.ready.remove(id);
  }

  bool startRun(SessionPlayer p) {
    final r = s.run;
    final canStart = s.mode == SessionMode.lobby ||
        (s.mode == SessionMode.run && r?.phase == RunPhase.over);
    if (!canStart || p.isCompanion) return false;
    final run = RunState(seed: e._seeds(), zones: _runRules.floorZones());
    s
      ..run = run
      ..mode = SessionMode.run
      ..battle = null;
    // Personajes nuevos para cada run (los de la anterior se descartan).
    for (final q in players) {
      q.profile = RunRules.runProfile(rules, q.profile);
      q.ult = 0;
      refresh(q);
      fill(q);
    }
    say('¡Comienza la Travesía! Piso 1: ${_zoneName(run, 0)}. '
        'Marquen el camino en el mapa.');
    return true;
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
        tree: a.tree, weapon: a.weapon, extra: a.extra);
    if (next == null) return false;
    p.profile = next;
    r.offers.remove(p.id);
    refresh(p, gain: true);
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
    final level = RunRules.enemyLevel(r.floor, n);
    // El personaje sigue el nivel de los enemigos (sin puntos: solo para
    // poder equipar lo que sale), con tope antes de los hitos del árbol.
    final target = math.min(RunTuning.maxPlayerLevel, level);
    for (final q in players) {
      if (q.profile.level < target) {
        q.profile = q.profile.copyWith(level: target);
        refresh(q, gain: true);
      }
    }
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

  void _runBattle(RunState r, RunNode n, int level) {
    final group = _runRules.enemyGroup(r.zones[r.floor], r.floor, n, _rand);
    s.seq++;
    final step = e.battles.start(
      party: [for (final p in players) e.partyMember(p)],
      enemyTypes: group,
      elite: n.type == RunNodeType.elite,
      triggeredBy: humans.firstOrNull?.id,
    );
    ZoneRules.scaleBattle(step.state, level, curve: catalog.curve);
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

  /// Fin de una pelea de la run (en vez del botín y la XP del Mundo).
  void runBattleFinished(bool victory) {
    final r = s.run!;
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
    for (final h in humans) {
      final streak = r.missStreak[h.id] ?? 0;
      final (offer, hit) = _offers.offer(h.profile,
          floor: r.floor, rnd: _rand, missStreak: streak);
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
