part of 'session_engine.dart';

// TUTORIAL: Ecos de práctica (docs/specs/combat_tutorial.md). El host lleva
// el guion (`GameSession.tutorial`, § 4.1): acomoda los turnos para que
// actúe quien corresponde, valida las acciones contra el paso, abre el
// cartel de efecto y, al final, manda `TutorialDoneEvent`. Vive aparte
// para no tocar el resto de la sesión: `session_engine` solo llama a
// estos ganchos.

extension _TutorialOp on _Op {
  TutorialRules get _tut => e.tutorials;

  /// Algún humano de la sala no tiene el tutorial vigente: el sello solo
  /// deja el TUTORIAL (§ 2).
  bool get tutorialLocked => _tut.missing(s).isNotEmpty;

  bool startTutorial(SessionPlayer p, StartTutorialAction a) {
    if (s.mode != SessionMode.lobby ||
        s.vote != null ||
        s.prep != null ||
        s.tutorial != null ||
        p.isCompanion) {
      return false;
    }
    final hs = humans.toList();
    // En grupo solo el host (el primero de la sala) lo inicia.
    if (hs.length > 1 && hs.first.id != p.id) return false;
    final members = [
      for (final q in players)
        if (!q.isCompanion || (a.companions && hs.length == 1)) q,
    ];
    final minV = hs
        .map((q) => q.tutorialVersion)
        .fold<int>(1 << 30, (m, v) => math.min(m, v));
    s.tutorialRuns++;
    _startTutorialBattle(TutorialState(
      attempt: s.tutorialRuns,
      stages: _tut.stagesFor(minV),
      order: [for (final q in members) q.id],
      fromVersion: minV,
    ));
    return true;
  }

  void _startTutorialBattle(TutorialState t) {
    final members = [
      for (final id in t.order)
        if (s.players[id] case final q?) q,
    ];
    s.seq++;
    e.battles
      ..townPotion = 0
      ..townHp = 0;
    final step = e.battles.start(
      party: [
        for (final q in members)
          BattlePartyMember(
            id: q.id,
            name: q.name,
            build: e.progression.buildOf(q.profile),
            potions: q.profile.potions,
            ethers: q.profile.ethers,
          ),
      ],
      enemyTypes: const [TutorialRules.spriteType],
    );
    _tut.setUpBattle(step.state, t);
    s
      ..battle = SessionBattle(
          id: s.seq,
          state: step.state,
          fieldEnemyId: -1,
          boss: true,
          elite: false)
      ..tutorial = t
      ..vote = null
      ..mode = SessionMode.battle;
    for (final q in players) {
      q
        ..epoch += 1
        ..moving = false;
    }
    events.add(BattleStartedEvent(s.seq, -1, boss: true, elite: false));
    say('${TutorialRules.name}: empieza el entrenamiento.');
    _enterStage();
  }

  /// Prepara la etapa actual y abre su cartel de inicio.
  void _enterStage() {
    final t = s.tutorial!;
    final b = s.battle!;
    final st = _tut.currentStage(t);
    if (st == null) return;
    t
      ..step = 0
      ..reps = 0
      ..prepared = false;
    // Cada etapa arranca limpia: autómata, línea de tiempo y recursos.
    _tut.setUpStage(b.state, st);
    b.wait = 0;
    _openCard(t, _tut.stageCard(t, st,
        names: {for (final q in players) q.id: q.name},
        present: {for (final c in b.state.party) c.id}));
  }

  /// Abre [card]: el guion espera la votación (§ 4.1).
  void _openCard(TutorialState t, TutorialCard card) {
    t
      ..card = card
      ..votes.clear();
    if (card.effect) t.last = card;
  }

  /// `TutorialAckAction` = el voto SIGUIENTE ("Leí y entendí") de [p].
  /// El cartel se cierra cuando votaron todos los humanos de la sala; los
  /// compañeros IA no votan.
  bool ackTutorial(SessionPlayer p) {
    final t = s.tutorial;
    if (t == null || t.card == null || p.isCompanion) return false;
    if (!t.votes.add(p.id)) return false;
    if (_tut.waiting(s).isEmpty) _closeCard();
    return true;
  }

  void _closeCard() {
    final t = s.tutorial!;
    final card = t.card;
    t
      ..card = null
      ..votes.clear();
    if (card != null && card.effect) _advanceStep();
  }

  /// Avanza al próximo paso. Si pasó algo imprevisto, el guion lo acepta
  /// y sigue.
  void _advanceStep() {
    final t = s.tutorial!;
    final turns = _tut.currentTurns(t).length;
    t
      ..prepared = false
      ..step += 1
      ..reps = 0;
    if (t.running && t.step >= turns) {
      t.stage++;
      if (t.running) _enterStage();
    }
  }

  /// `TutorialControlAction` (menú de pausa, § 4.3). En grupo, solo el
  /// host. Reanuda la sala.
  bool controlTutorial(SessionPlayer p, TutorialControl op) {
    final t = s.tutorial;
    if (t == null || p.isCompanion) return false;
    final hs = humans.toList();
    if (hs.length > 1 && hs.first.id != p.id) return false;
    s
      ..pausedBy = null
      ..pausedName = null;
    switch (op) {
      case TutorialControl.repeatStage:
        switch (t.phase) {
          case TutorialPhase.script:
            _enterStage();
            say('Se repite la etapa.');
          case TutorialPhase.train || TutorialPhase.trainOver:
            _startTraining();
          case TutorialPhase.menu:
            break;
        }
      case TutorialControl.repeat:
        final present = {for (final c in s.battle!.state.party) c.id};
        s.tutorialRuns++;
        _startTutorialBattle(TutorialState(
          attempt: s.tutorialRuns,
          stages: t.stages,
          order: [
            for (final id in t.order)
              if (present.contains(id)) id
          ],
          fromVersion: t.fromVersion,
        ));
      case TutorialControl.exit:
        say('Saliste del TUTORIAL sin completarlo.');
        _endTutorial();
    }
    return true;
  }

  /// Valida [cmd] contra el paso (§ 6). `null` = no es del tutorial.
  bool? tutorialAllows(SessionPlayer p, BattleCommand cmd) {
    final t = s.tutorial;
    final b = s.battle;
    if (t == null || b == null) return null;
    return _tut.allows(t, b.state, p.id, cmd);
  }

  /// Después de un comando aceptado: el cartel de efecto.
  void afterTutorialCommand(SessionPlayer p, BattleCommand cmd,
      BattleState before, List<BattleEvent> evs) {
    final t = s.tutorial!;
    final b = s.battle!;
    if (t.phase == TutorialPhase.train) {
      // ENTRENAR: sin votación; el narrador cuenta lo que pasó.
      _narrate(before, evs, p.id, cmd);
      return;
    }
    _openCard(
        t,
        _tut.effectCard(before, b.state, evs, p.id,
            cmd: cmd, said: t.said));
  }

  /// Guarda un paso del motor sin XP, K.O. de misión ni fin de batalla.
  void _applyTutorialStep(SessionBattle b, BattleStep step) {
    b.state = step.state..outcome = null;
    if (step.events.isNotEmpty) events.add(BattleStepEvent(step.events));
  }

  /// El ritmo de la pelea de práctica (reemplaza a `battleTick`): sin
  /// límite de 30 s.
  void tutorialTick(double dt) {
    final b = s.battle!;
    final t = s.tutorial!;
    if (t.card != null) {
      // Sin cierre por tiempo: solo la votación. Si el que faltaba se
      // desconectó, deja de contarse.
      if (_tut.waiting(s).isEmpty) _closeCard();
      return;
    }
    switch (t.phase) {
      case TutorialPhase.menu || TutorialPhase.trainOver:
        // Votación: si el que faltaba se desconectó, deja de contarse.
        _resolvePicks();
        return;
      case TutorialPhase.train:
        if (b.wait > 0) {
          b.wait -= dt;
          return;
        }
        _trainStep(b, t, dt);
        return;
      case TutorialPhase.script:
        break;
    }
    if (b.wait > 0) {
      b.wait -= dt;
      return;
    }
    if (!t.running) {
      _finishScript();
      return;
    }
    switch (_tut.currentStep(t)) {
      case TutorialPlayerStep step:
        _playerStep(b, t, step, dt);
      case TutorialEnemyStep():
        if (!t.prepared) {
          // Antes de actuar, el autómata se anuncia y espera la votación.
          t.prepared = true;
          _openCard(t, _tut.enemyAnnounce(b.state));
          return;
        }
        _enemyStep(b, t);
      case TutorialResetStep step:
        // Entre parejas: el autómata vuelve a cero, con lo justo puesto.
        _tut
          ..resetCombatants(b.state)
          ..applySetup(b.state, step.setup);
        _advanceStep();
      case TutorialFillStep step:
        if (!t.prepared) {
          // Se reinicia y se ve la barra vacía un instante.
          if (step.reset) _tut.resetCombatants(b.state);
          t.prepared = true;
          b.wait = step.reset ? 0.6 : 0.3;
          return;
        }
        final boss = b.state.byId(TutorialRules.bossId)!;
        boss
          ..breakGauge = boss.breakMax
          ..fissured = true;
        final turns = _tut.currentTurns(t);
        final next = t.step + 1 < turns.length ? turns[t.step + 1].actor : null;
        final id = next == null || next >= t.order.length ? null : t.order[next];
        _openCard(
            t,
            _tut.fillCard(
                id == null ? null : (b.state.byId(id)?.name ?? s.players[id]?.name),
                said: t.said));
      case null:
        t.stage++;
        if (t.running) _enterStage();
    }
  }

  /// Le da el turno a [id] ("acomoda las velocidades", § 4.1): su
  /// próximo turno pasa a ser el primero de la línea de tiempo.
  List<BattleEvent> _forceTurn(SessionBattle b, String id) {
    final st = b.state;
    final c = st.byId(id);
    if (c == null) return const [];
    st.currentId = null;
    var first = c.nextTurn;
    for (final x in [...st.party, ...st.enemies]) {
      if (x.alive && x.nextTurn < first) first = x.nextTurn;
    }
    c.nextTurn = math.min(c.nextTurn, first - 0.001);
    final step = e.battles.nextTurn(st);
    _applyTutorialStep(b, step);
    return step.events;
  }

  void _playerStep(
      SessionBattle b, TutorialState t, TutorialPlayerStep step, double dt) {
    final present = {for (final c in b.state.party) c.id};
    final id = _tut.currentActor(t, present);
    if (id == null) {
      _advanceStep();
      return;
    }
    if (!t.prepared || b.state.currentId != id) {
      if (b.state.currentId != id) {
        _forceTurn(b, id);
        // Perdió el turno (algo imprevisto): se vuelve a intentar.
        if (b.state.currentId != id) return;
      }
      _tut.prepare(step, b.state, b.state.byId(id)!);
      t.prepared = true;
      b.turnTime = 0;
      return;
    }
    b.turnTime += dt;
    final p = s.players[id];
    if (p != null &&
        p.isCompanion &&
        b.turnTime >= TutorialRules.companionDelay) {
      // La IA hace su paso (y el cartel lo anuncia).
      final cmd = _tut.scripted(step, b.state.byId(id)!);
      if (cmd != null && !_battleCommand(p, cmd)) _advanceStep();
    }
  }

  void _enemyStep(SessionBattle b, TutorialState t) {
    final before = b.state.copy();
    final evs = <BattleEvent>[];
    const boss = TutorialRules.bossId;
    if (b.state.currentId != boss) {
      evs.addAll(_forceTurn(b, boss));
    }
    if (b.state.currentId == boss) {
      final step = e.battles.enemyTurn(b.state);
      if (step != null) {
        _applyTutorialStep(b, step);
        evs.addAll(step.events);
      }
    }
    b.wait = evs.any((ev) => ev is EnemyUltEvent) ? 2.3 : 0.8;
    _openCard(t, _tut.effectCard(before, b.state, evs, null, said: t.said));
  }

  /// ENTRENAR: la línea de tiempo real, sin guion; el narrador cuenta lo
  /// que pasa y, si el autómata cae, se vota Reiniciar o Salir.
  void _trainStep(SessionBattle b, TutorialState t, double dt) {
    if (_trainingOver()) return;
    if (b.state.currentId == null) {
      final before = b.state.copy();
      final step = e.battles.nextTurn(b.state);
      _applyTutorialStep(b, step);
      _narrate(before, step.events, null, null);
      b.turnTime = 0;
      return;
    }
    final cur = b.state.current!;
    if (!cur.isPlayer) {
      final before = b.state.copy();
      final step = e.battles.enemyTurn(b.state);
      if (step != null) {
        _applyTutorialStep(b, step);
        _narrate(before, step.events, null, null);
      }
      b.wait = 0.8;
      return;
    }
    b.turnTime += dt;
    final p = s.players[cur.id];
    if (p != null &&
        p.isCompanion &&
        b.turnTime >= TutorialRules.companionDelay) {
      final pick = const CompanionAi().choose(b.state, cur.id);
      for (final c in [if (pick != null) pick, ...CompanionAi.fallbacks]) {
        if (_battleCommand(p, c)) return;
      }
    }
  }

  /// Suma las líneas del narrador (las últimas
  /// [TutorialRules.narrationMax]).
  void _narrate(BattleState before, List<BattleEvent> evs, String? actorId,
      BattleCommand? cmd) {
    final t = s.tutorial!;
    final b = s.battle!;
    final lines = _tut.narrate(before, b.state, evs, actorId,
        cmd: cmd, primers: t.primers);
    _tut.trackPrimers(before, b.state, actorId, t.primers);
    t.narration.addAll(lines);
    if (t.narration.length > TutorialRules.narrationMax) {
      t.narration
          .removeRange(0, t.narration.length - TutorialRules.narrationMax);
    }
    _trainingOver();
  }

  /// El autómata cayó en ENTRENAR: votación Reiniciar / Salir.
  bool _trainingOver() {
    final t = s.tutorial!;
    if (t.phase == TutorialPhase.trainOver) return true;
    if (t.phase != TutorialPhase.train) return false;
    final boss = s.battle!.state.byId(TutorialRules.bossId);
    if (boss != null && boss.alive) return false;
    t
      ..phase = TutorialPhase.trainOver
      ..picks.clear();
    s.battle!.state.currentId = null;
    say('¡El autómata de entrenamiento cayó!');
    return true;
  }

  /// Arranca (o reinicia) ENTRENAR: se resetea todo y cada uno recibe su
  /// kit de entrenamiento (§ 4.4).
  void _startTraining() {
    final t = s.tutorial!;
    final b = s.battle!;
    t
      ..phase = TutorialPhase.train
      ..card = null
      ..votes.clear()
      ..picks.clear()
      ..narration.clear()
      ..primers.clear()
      ..prepared = false;
    final present = {for (final c in b.state.party) c.id};
    for (var i = 0; i < b.state.party.length; i++) {
      b.state.party[i] = _tut.kitOf(b.state.party[i], t, present);
    }
    b.state.enemies
      ..clear()
      ..add(_tut.trainingBoss(math.max(1, b.state.party.length)));
    final ults = {for (final c in b.state.party) c.id: c.ult};
    _tut.resetCombatants(b.state);
    for (final c in b.state.party) {
      c.ult = ults[c.id] ?? 0;
    }
    b.state.outcome = null;
    b.wait = 0;
    t.narration.add('ENTRENAR: cada uno tiene un kit de entrenamiento. '
        'Probá combos; el autómata ahora puede caer.');
    say('ENTRENAR: empieza.');
  }

  /// `TutorialChoiceAction`: el voto de [p] en la votación abierta.
  bool pickTutorial(SessionPlayer p, String choice) {
    final t = s.tutorial;
    if (t == null || p.isCompanion || !_tut.validChoice(t, choice)) {
      return false;
    }
    t.picks[p.id] = choice;
    _resolvePicks();
    return true;
  }

  void _resolvePicks() {
    final t = s.tutorial;
    if (t == null) return;
    // Los que se fueron dejan de contarse.
    final ids = {for (final q in _tut.voters(s)) q.id};
    t.picks.removeWhere((id, _) => !ids.contains(id));
    final d = _tut.decided(s);
    if (d == null) return;
    switch (d) {
      case 'repeat':
        final present = {for (final c in s.battle!.state.party) c.id};
        s.tutorialRuns++;
        _startTutorialBattle(TutorialState(
          attempt: s.tutorialRuns,
          stages: _tut.stagesFor(0),
          order: [
            for (final id in t.order)
              if (present.contains(id)) id
          ],
          fromVersion: _tut.version,
        ));
      case 'train' || 'restart':
        _startTraining();
      case 'exit':
        say('Saliste del TUTORIAL.');
        _endTutorial();
    }
  }

  /// Terminó el guion: cada cuenta que sigue en la pelea lo completa y se
  /// abre la votación "Repetir tutorial" / "ENTRENAR" / "Salir".
  void _finishScript() {
    final t = s.tutorial!;
    final inBattle = {for (final c in s.battle!.state.party) c.id};
    final done = [
      for (final h in humans)
        if (inBattle.contains(h.id) && t.order.contains(h.id)) h,
    ];
    for (final h in done) {
      h.tutorialVersion = math.max(h.tutorialVersion, _tut.version);
    }
    events.add(TutorialDoneEvent([for (final h in done) h.id], _tut.version));
    say('¡Guion completo!');
    t
      ..phase = TutorialPhase.menu
      ..picks.clear()
      ..card = null
      ..votes.clear();
    s.battle!.state.currentId = null;
  }

  /// Sale de la pelea de práctica: nada queda en el perfil (vida, MP,
  /// pociones, XP ni las habilidades prestadas, que vivían solo en la
  /// batalla).
  void _endTutorial() {
    s
      ..tutorial = null
      ..battle = null;
    toLobby();
  }
}
