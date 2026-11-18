part of 'battle_engine.dart';

// Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 2): fases con una
// rotación de movimientos, aviso del próximo, furia, sello, aspecto,
// reflejo, devorar, rebobinar, distorsión, curas que dañan e inmunidad
// al daño. Vive aparte para no tocar el resto del motor: `battle_engine`
// solo llama a estos ganchos.

/// `DamageEvent.sourceId` del daño de las curas del grupo a un jefe.
const kAbyssHealSourceId = 'abismo.cura';

/// Fracción de turno que se adelanta el jefe con la Distorsión.
const kAbyssHaste = 0.3;

/// Poder del golpe a todos en furia.
const kAbyssEnrageStrike = 1.0;

/// Adelanto del próximo turno del jefe pedido en este paso (Distorsión).
final _abyssHaste = Expando<double>('abyssHaste');

extension _AbyssTurn on _Turn {
  AbyssBossDef? _abyssDef(Combatant e) =>
      e.isPlayer ? null : engine.catalog.abyssOf(e.enemyType);

  bool get _abyssSolo => state.party.length == 1;

  GameElement? _abyssAspect(Combatant e) =>
      e.abyssAspect <= 0 ? null : GameElement.values[e.abyssAspect - 1];

  /// El estado que dejan los golpes con el aspecto de [e] (o `null`).
  StatusApplication? _abyssAspectStatus(Combatant e) {
    final el = _abyssAspect(e);
    final st = el?.status;
    if (st == null) return null;
    final n = st == StatusKind.burn || st == StatusKind.poison ? 2 : 1;
    return StatusApplication(st, n);
  }

  /// Invocaciones vivas de la mecánica de [e].
  bool _abyssAddsAlive(Combatant e) {
    final m = _mechanicOf(e);
    return m?.addType != null && _addsAlive(m!.addType!);
  }

  /// Inmune al daño (fase con `immuneWhileAdds` y alguna invocación viva).
  bool _abyssDamageImmune(Combatant e) {
    final d = _abyssDef(e);
    return d != null &&
        AbyssRules.phaseOf(d, e).immuneWhileAdds &&
        _abyssAddsAlive(e);
  }

  /// Inmune a los estados (fase con `statusImmuneWhileAdds`).
  bool _abyssStatusImmune(Combatant e) {
    final d = _abyssDef(e);
    return d != null &&
        AbyssRules.phaseOf(d, e).statusImmuneWhileAdds &&
        _abyssAddsAlive(e);
  }

  /// Multiplicador del daño que recibe [e] de un golpe de [el]: 0 si es
  /// inmune, × sello y × aspecto. [mods] recibe el texto del log.
  double _abyssFactor(Combatant e, GameElement? el, [List<String>? mods]) {
    final d = _abyssDef(e);
    if (d == null) return 1;
    if (_abyssDamageImmune(e)) {
      if (_immuneShown.add('dmg|${e.id}')) {
        events.add(BossMechanicEvent(e.id, BossMechanicPhase.immune));
        _notes.add('${e.name} es INMUNE al daño mientras vivan sus '
            'invocaciones');
      }
      mods?.add('× 0 INMUNE');
      return 0;
    }
    var f = 1.0;
    if (e.abyssSeal > 0) {
      final s = AbyssRules.sealMove(d);
      final block = s == null ? 0.0 : (_abyssSolo ? s.soloValue : s.value);
      f *= 1 - block;
      mods?.add('× ${fm(1 - block)} SELLO');
    }
    final asp = _abyssAspect(e);
    if (asp != null && el == asp && d.aspectResist != 1) {
      f *= d.aspectResist;
      mods?.add('× ${fm(d.aspectResist)} ASPECTO');
    }
    return f;
  }

  // ---------------- inicio del turno del jefe ----------------

  void _abyssTurnStart(Combatant e) {
    final d = _abyssDef(e);
    if (d == null) return;
    e.abyssTurns++;
    if (!e.abyssEnraged && e.abyssTurns >= d.enrageTurns) {
      e
        ..abyssEnraged = true
        ..attack = jsRound(e.attack * d.enragePower);
      events.add(BossMechanicEvent(e.id, BossMechanicPhase.enrage,
          value: d.enragePower));
      _notes.add('¡${e.name} entra en FURIA! ATQ ×${fm(d.enragePower)} y '
          'golpea a todos');
    }
    final aspects = AbyssRules.phaseOf(d, e).aspects;
    if (aspects.length > 1) {
      final cur = _abyssAspect(e);
      final i = cur == null ? -1 : aspects.indexOf(cur);
      final next = aspects[(i + 1) % aspects.length];
      e.abyssAspect = next.index + 1;
      events.add(BossMechanicEvent(e.id, BossMechanicPhase.aspect,
          value: next.index.toDouble()));
      _notes.add('${e.name} toma el aspecto de ${next.label}');
    } else if (aspects.length == 1) {
      e.abyssAspect = aspects.first.index + 1;
    }
    if (e.abyssSeal > 0) {
      e.abyssSealTurns--;
      if (e.abyssSealTurns <= 0) {
        e
          ..abyssSeal = 0
          ..abyssSealTurns = 0;
        events.add(BossMechanicEvent(e.id, BossMechanicPhase.sealFade));
        _notes.add('el sello de ${e.name} se apaga');
      }
    }
  }

  // ---------------- la acción ----------------

  /// La acción de [e] (ya contó `actions`): el movimiento de su rotación
  /// o, en furia, un golpe a todos. Después avisa el próximo.
  void _abyssAct(Combatant e, BossMechanicDef m, List<Combatant> alive) {
    final d = _abyssDef(e);
    if (d == null) {
      _basicAttack(e, m, alive);
      return;
    }
    if (e.abyssEnraged) {
      _abyssStrike(
          e,
          const AbyssMoveDef(AbyssMoveKind.strike,
              name: 'Furia del Abismo', power: kAbyssEnrageStrike),
          alive);
    } else {
      final moves = AbyssRules.phaseOf(d, e).moves;
      final mv = moves[(e.actions - 1) % moves.length];
      switch (mv.kind) {
        case AbyssMoveKind.attack:
          _basicAttack(e, m, alive);
        case AbyssMoveKind.strike:
          _abyssStrike(e, mv, alive);
        case AbyssMoveKind.rewind:
          _abyssRewind(e, mv);
        case AbyssMoveKind.timeWarp:
          _abyssTimeWarp(e, mv, alive);
        case AbyssMoveKind.mirror:
          _abyssMirror(e, m, mv, alive);
        case AbyssMoveKind.seal:
          _abyssSeal(e, mv);
        case AbyssMoveKind.summon:
          final k = _summonAdds(e, m);
          if (k == 0) {
            _basicAttack(e, m, alive);
          } else {
            state.log = '${e.name} · ${mv.label}: vuelven $k invocación'
                '${k == 1 ? '' : 'es'}';
          }
        case AbyssMoveKind.devour:
          _abyssDevour(e, mv);
      }
    }
    e.abyssTaken = 0;
    if (!e.alive || e.abyssEnraged) return;
    final next = AbyssRules.nextMove(d, e);
    if (next.kind.telegraphed) {
      events.add(BossMechanicEvent(e.id, BossMechanicPhase.abyssTelegraph,
          value: next.kind.index.toDouble()));
      _notes.add('Próximo: ${next.label}');
    }
  }

  int _abyssAtk(Combatant e) {
    final mod = e.effectTotal(BuffStat.attack);
    return mod == 0 ? e.attack : math.max(1, jsRound(e.attack * (1 + mod)));
  }

  /// Golpe a todos. Defender: ½ daño y el golpe llega físico (no
  /// reacciona ni deja estado).
  void _abyssStrike(Combatant e, AbyssMoveDef mv, List<Combatant> alive) {
    final d = engine.catalog.enemies[e.enemyType];
    final aspectSt = _abyssAspectStatus(e);
    final el = mv.element ??
        _abyssAspect(e) ??
        enemyAttackElement(d, _inflictsOf(e));
    final st = mv.status ?? (mv.element == null ? aspectSt : null);
    final atk = _abyssAtk(e);
    events.add(ActionEvent(e.id, BattleActionKind.enemyArea, allTargets: true));
    final protector = alive.where((p) => p.protecting).firstOrNull;
    final parts = <String>[];
    for (final p0 in alive) {
      final p = protector != null && p0 != protector ? protector : p0;
      if (!p.alive) continue;
      final guard = p.defending;
      final h = _hurt(p, atk * mv.power, e.critChance, e.pierce,
          from: e,
          element: guard ? GameElement.fisico : el,
          inflicted: guard ? null : st);
      if (p != p0 && p.alive) {
        _fire(ProcTrigger.onProtectHit, p, target: e, amount: h.damage);
      }
      if (!guard && st != null && p.alive) _addStatus(p, st);
      if (mv.delay > 0 && p.alive) {
        p.nextTurn += _iv(p) * mv.delay;
        events.add(DelayedEvent(p.id));
      }
      parts.add('${p.name} ${h.damage}${guard ? ' (defiende)' : ''}');
    }
    state.log = '${e.name} · ${mv.label} (todos, ATQ $atk × ${fm(mv.power)}'
        '${el != GameElement.fisico ? ', ${el.label}' : ''}'
        '${mv.delay > 0 ? ', retrasa' : ''}): ${parts.join(', ')}';
  }

  void _abyssRewind(Combatant e, AbyssMoveDef mv) {
    if (e.broken) {
      state.log = '${e.name} intenta rebobinar, pero está QUEBRADO';
      return;
    }
    final f = _abyssSolo ? mv.soloValue : mv.value;
    final h = math.min(e.maxHp - e.hp, jsRound(e.abyssTaken * f));
    if (h > 0) {
      e.hp += h;
      events.add(HealEvent(e.id, h));
    }
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.rewind,
        value: h.toDouble()));
    state.log = '${e.name} · ${mv.label}: recupera $h HP '
        '(${_pct(f)} de lo recibido desde su acción anterior)';
  }

  void _abyssTimeWarp(Combatant e, AbyssMoveDef mv, List<Combatant> alive) {
    final f = _abyssSolo ? mv.soloValue : mv.value;
    for (final p in alive) {
      p.nextTurn += _iv(p) * f;
      events.add(DelayedEvent(p.id));
    }
    _abyssHaste[this] = kAbyssHaste;
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.timeWarp, value: f));
    state.log = '${e.name} · ${mv.label}: retrasa al grupo ${_pct(f)} de un '
        'turno y adelanta el suyo';
  }

  /// Cada eco vivo (o el jefe, sin ecos) copia la última habilidad del
  /// grupo.
  void _abyssMirror(Combatant e, BossMechanicDef m, AbyssMoveDef mv,
      List<Combatant> alive) {
    final copy = e.abyssCopy;
    final sk = copy == null
        ? null
        : engine.catalog.skills[copy] ??
            engine.catalog.ultimates.values
                .where((u) => u.id == copy)
                .firstOrNull;
    final el = elementOf(sk?.id);
    final casters = [
      for (final c in state.enemies)
        if (c.alive && m.addType != null && c.enemyType == m.addType) c,
    ];
    if (casters.isEmpty) casters.add(e);
    final name = sk == null ? 'Reflejo' : 'Reflejo: ${sk.name}';
    final parts = <String>[];
    for (final c in casters) {
      final live = _aliveParty.toList();
      if (live.isEmpty) break;
      final targets = sk?.allTargets ?? false
          ? live
          : [live[(_rand() * live.length).floor()]];
      events.add(ActionEvent(
          c.id,
          targets.length > 1
              ? BattleActionKind.enemyArea
              : BattleActionKind.enemyAttack,
          targetId: targets.length == 1 ? targets.first.id : null,
          allTargets: targets.length > 1));
      for (final p in targets) {
        events.add(
            BossMechanicEvent(c.id, BossMechanicPhase.mirror, targetId: p.id));
        final h = _hurt(p, _abyssAtk(c) * mv.power, 0, false,
            from: c, element: el, inflicted: sk?.status);
        if (sk?.status case final st? when p.alive) _addStatus(p, st);
        parts.add('${p.name} ${h.damage}');
      }
    }
    state.log = '${e.name} · $name'
        '${el != GameElement.fisico ? ' (${el.label})' : ''}: '
        '${parts.join(', ')}';
  }

  void _abyssSeal(Combatant e, AbyssMoveDef mv) {
    final r = mv.reaction ?? ReactionKind.electrocucion;
    e
      ..abyssSeal = r.index + 1
      ..abyssSealTurns = math.max(1, mv.turns);
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.sealCast,
        value: r.index.toDouble()));
    final block = _abyssSolo ? mv.soloValue : mv.value;
    state.log = '${e.name} · ${mv.label}: recibe −${_pct(block)} de daño '
        '${mv.turns} turnos · rompelo con ${_abyssSolo ? 'cualquier reacción' : r.label} '
        'o quebrándolo';
  }

  /// Se come los buffs y escudos del grupo: +ATQ por cada uno (tope).
  void _abyssDevour(Combatant e, AbyssMoveDef mv) {
    var n = 0;
    for (final p in state.party) {
      if (!p.alive) continue;
      final kept = [
        for (final fx in p.effects)
          if (fx.value <= 0 ||
              fx.stat == BuffStat.stunLock ||
              fx.stat == BuffStat.damageTaken ||
              fx.stat == BuffStat.charge ||
              fx.stat == BuffStat.trap)
            fx,
      ];
      n += p.effects.length - kept.length;
      p.effects = kept;
      if (p.bonusDefense > 0) {
        p.bonusDefense = 0;
        engine._refreshStats(p);
        n++;
      }
    }
    final per = _abyssSolo ? mv.soloValue : mv.value;
    final cap = mv.cap > 0 ? mv.cap : 1.0;
    final before = math.min(cap, e.abyssFeast * per);
    e.abyssFeast += n;
    final after = math.min(cap, e.abyssFeast * per);
    if (after > before) {
      e.attack = jsRound(e.attack * (1 + after) / (1 + before));
    }
    events.add(
        BossMechanicEvent(e.id, BossMechanicPhase.devour, value: n.toDouble()));
    state.log = n == 0
        ? '${e.name} · ${mv.label}: no encuentra buffs que comer'
        : '${e.name} · ${mv.label}: se come $n buff${n == 1 ? '' : 's'} del '
            'grupo · ATQ +${_pct(after)} (tope +${_pct(cap)})';
  }

  // ---------------- fases ----------------

  /// Si [e] cruzó el umbral de su próxima fase: la vida queda en él y
  /// sube de fase. `true` si hay que llamar a [_abyssTransform].
  bool _abyssGate(Combatant e) {
    final d = _abyssDef(e);
    if (d == null) return false;
    final cur = math.max(1, e.phase);
    if (cur >= d.phases.length) return false;
    final gate = (e.maxHp * d.phases[cur].gate).ceil();
    if (e.hp > gate) return false;
    e
      ..hp = gate
      ..phase = cur + 1;
    return true;
  }

  void _abyssTransform(Combatant e) {
    final d = _abyssDef(e);
    final m = _mechanicOf(e);
    if (d == null || m == null) return;
    final ph = AbyssRules.phaseOf(d, e);
    e
      ..statuses = {}
      ..holyTurns = 0
      ..brittle = false
      ..attack = jsRound(e.attack * ph.attackMult)
      ..actions = 0
      ..abyssSeal = 0
      ..abyssSealTurns = 0
      ..abyssTaken = 0
      ..abyssAspect = ph.aspects.isEmpty ? 0 : ph.aspects.first.index + 1;
    if (!e.broken) e.breakGauge = 0;
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.phaseShift,
        value: e.phase.toDouble()));
    _notes.add('¡${e.name}: FASE ${e.phase} · ${ph.name}! Pierde sus estados'
        '${ph.attackMult != 1 ? ', ATQ ×${fm(ph.attackMult)}' : ''}');
    if (ph.summon && m.addType != null) {
      e.mechTurns = 0;
      final k = _summonAdds(e, m);
      if (k > 0) _notes.add('vuelven $k invocación${k == 1 ? '' : 'es'}');
    }
  }

  // ---------------- reacciones, quiebre, curas y copias ----------------

  /// Una reacción de [by] sobre [t]: rompe el sello si es la pedida (en
  /// solo, cualquiera).
  void _abyssReacted(Combatant? by, Combatant t, ReactionKind k) {
    if (t.abyssSeal <= 0 || by == null || !by.isPlayer) return;
    if (!_abyssSolo && t.abyssSeal - 1 != k.index) return;
    _abyssBreakSeal(t, by, '¡${k.label} rompe el sello de ${t.name}!');
  }

  /// El quiebre también rompe el sello.
  void _abyssBroken(Combatant e) {
    if (e.abyssSeal <= 0) return;
    _abyssBreakSeal(e, _attacker, 'el quiebre rompe el sello de ${e.name}');
  }

  void _abyssBreakSeal(Combatant e, Combatant? by, String note) {
    e
      ..abyssSeal = 0
      ..abyssSealTurns = 0;
    events.add(BossMechanicEvent(e.id, BossMechanicPhase.sealBroken,
        targetId: by?.id));
    _notes.add(note);
  }

  /// Curas del grupo: dañan a los jefes con `healHurts` (también en su
  /// fase inmune).
  void _abyssHealed(Combatant q, int healed) {
    if (!q.isPlayer || healed <= 0) return;
    for (final e in state.enemies) {
      if (!e.alive) continue;
      final d = _abyssDef(e);
      if (d == null || d.healHurts <= 0) continue;
      final dmg = math.max(1, jsRound(healed * d.healHurts));
      _rawDamage(null, e, dmg, kAbyssHealSourceId);
      _notes.add('la cura daña a ${e.name}: $dmg');
    }
  }

  /// Un jugador usó [skillId]: los jefes con Reflejo lo copian.
  void _abyssCopied(String skillId) {
    for (final e in state.enemies) {
      if (e.alive && _abyssDef(e) != null) e.abyssCopy = skillId;
    }
  }
}
