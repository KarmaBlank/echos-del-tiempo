part of 'battle_engine.dart';

// Invocador v0.8.1 (docs/specs/summoner.md): invocaciones como aliados
// de la IA en la línea de tiempo (`BattleState.summons`). Vive aparte
// para no tocar el resto del motor: `battle_engine` solo llama a estos
// ganchos (turno, ataque enemigo, habilidades de apoyo, ULT del Libro
// de los Cuatro y el inicio del turno del invocador).

/// Marca (en `Combatant.once`) de los elementales del Portal: al
/// terminar detonan su elemento.
const kPortalMark = 'portal';

/// `TimedEffect.sourceId` del buff de daño de Coro de Ecos.
const kCoroEcosSource = 'coroEcos';

extension _SummonTurn on _Turn {
  Combatant? _ownerOf(Combatant s) =>
      state.party.where((p) => p.id == s.summonOwner).firstOrNull;

  SummonDef _defOf(Combatant s) =>
      kSummons[SummonKind.values.byName(s.summonKind!)]!;

  Set<String> _ids(Combatant owner) => {...owner.mechanics, ...owner.keystones};

  double _smod(Combatant owner, SummonMod m) =>
      SummonRules.mod(_ids(owner), m);

  List<Combatant> _summonsOf(Combatant owner) => [
        for (final s in state.summons)
          if (s.alive && s.summonOwner == owner.id) s,
      ];

  // ---------------- invocar ----------------

  /// Invoca [kind] para [owner]; si ya tiene el máximo, se va la más
  /// vieja. Devuelve la invocación.
  Combatant _summon(Combatant owner, SummonKind kind, {bool portal = false}) {
    final d = kSummons[kind]!;
    final ids = _ids(owner);
    final mine = _summonsOf(owner);
    final max = SummonRules.maxActive(ids);
    while (mine.length >= max) {
      final old = mine.removeAt(0);
      state.summons.remove(old);
      events.add(KnockedOutEvent(old.id));
      _notes.add('${old.name} se desvanece (máx. $max)');
    }
    final st = SummonRules.stats(d,
        magic: owner.magic,
        maxHp: owner.maxHp,
        speed: owner.speed,
        crit: owner.critChance,
        level: owner.build?.level ?? 1,
        build: owner.build,
        ids: ids);
    var n = state.summons.length;
    String id() => 'sum_${owner.id}_${kind.name}_$n';
    while (state.byId(id()) != null) {
      n++;
    }
    final s = Combatant(
      id: id(),
      name: d.name,
      isPlayer: false,
      hp: st.hp,
      maxHp: st.hp,
      speed: st.speed,
      attack: st.attack,
      magic: st.attack,
      critChance: st.crit,
      summonOwner: owner.id,
      summonKind: kind.name,
      summonTurns: st.turns,
      once: {if (portal) kPortalMark},
    );
    s.nextTurn = state.clock + engine.interval(s) * 0.5;
    state.summons.add(s);
    assignCombatantTags(state);
    final ult = _smod(owner, SummonMod.invokeUlt);
    if (ult > 0) owner.ult = math.min(100, owner.ult + ult);
    _summonSync(owner);
    return s;
  }

  /// Coro de Ecos: +daño propio por invocación activa.
  void _summonSync(Combatant owner) {
    final v = _smod(owner, SummonMod.danceDamage);
    owner.effects = [
      for (final fx in owner.effects)
        if (fx.sourceId != kCoroEcosSource) fx,
    ];
    final n = _summonsOf(owner).length;
    if (v <= 0 || n == 0) return;
    owner.effects = [
      ...owner.effects,
      TimedEffect(
          sourceId: kCoroEcosSource,
          stat: BuffStat.damage,
          value: v * n,
          turns: 99,
          ownerId: owner.id),
    ];
  }

  String _summonText(Combatant s) => '${s.name} (${s.hp} HP, '
      '${s.attack} poder, ${s.summonTurns >= kSummonForever ? '∞' : s.summonTurns} turnos)';

  // ---------------- habilidades (gancho de `_useSkill`) ----------------

  /// Habilidades del Invocador. `false` si [tk] no es una.
  bool _summonSkill(Combatant p, SkillDef tk, List<Combatant> foes) {
    final kind = kSummonSkillKind[tk.id];
    if (kind != null) {
      final s = _summon(p, kind);
      state.log = '${p.name} · ${tk.name}: ${_summonText(s)}';
      return true;
    }
    switch (tk.id) {
      case 'enjambre':
        final a = kElementalSummons[(_rand() * 4).floor().clamp(0, 3)];
        final b = kElementalSummons[(_rand() * 4).floor().clamp(0, 3)];
        final s1 = _summon(p, a), s2 = _summon(p, b);
        state.log = '${p.name} · ${tk.name}: ${s1.name} y ${s2.name}';
        return true;
      case 'comandar':
        final mine = _summonsOf(p);
        if (mine.isEmpty) {
          state.log = '${p.name} · ${tk.name}: no tenés invocaciones';
          return true;
        }
        _actAll(p, '${p.name} · ${tk.name}: ¡${mine.length} invocaciones '
            'actúan ya!', mine, 1);
        return true;
      case 'sacrificio':
        _sacrifice(p, tk);
        return true;
      case 'ult_portal':
        for (final k in kElementalSummons) {
          _summon(p, k, portal: true);
        }
        _actAll(
            p,
            '${p.name} · ${tk.name}: ¡los cuatro elementales atacan ya '
                '(×${fm(kPortalStrike)})!',
            _summonsOf(p).where((s) => s.once.contains(kPortalMark)),
            kPortalStrike);
        return true;
      case 'ult_avatar':
        _avatar(p, tk);
        return true;
      case 'ult_marea':
        final g = _summon(p, SummonKind.golem);
        final s1 = _summon(p, SummonKind.espiritu);
        final s2 = _summon(p, SummonKind.espiritu);
        final amount = math.max(1, jsRound(p.maxHp * kMareaShield));
        for (final q in _aliveParty) {
          q.effects = [
            for (final fx in q.effects)
              if (!(fx.sourceId == tk.id && fx.stat == BuffStat.shield)) fx,
            TimedEffect(
                sourceId: tk.id,
                stat: BuffStat.shield,
                value: amount.toDouble(),
                turns: 2,
                ownerId: p.id),
          ];
          events.add(ShieldEvent(q.id, amount));
        }
        for (final s in _summonsOf(p)) {
          s.taunt = kMareaTaunt;
        }
        state.log = '${p.name} · ${tk.name}: ${g.name}, ${s1.name} y '
            '${s2.name} · escudo de $amount a todo el grupo · tus '
            'invocaciones provocan $kMareaTaunt golpes';
        return true;
    }
    return false;
  }

  /// [list] actúa ya (Comandar, Portal); el log junta sus acciones.
  void _actAll(Combatant p, String head, Iterable<Combatant> list, double mult) {
    final parts = <String>[];
    for (final s in list.toList()) {
      if (state.enemies.every((e) => !e.alive)) break;
      _summonAction(s, p, mult);
      parts.add(state.log);
    }
    state.log = [head, ...parts].join(' · ');
  }

  /// Avatar del Pacto: absorbe a sus invocaciones (+15% de daño cada una
  /// y sus estados en cada golpe) por 3 turnos.
  void _avatar(Combatant p, SkillDef tk) {
    final mine = _summonsOf(p);
    p.once.removeWhere((k) => k.startsWith('avatar:'));
    for (final s in mine) {
      p.once.add('avatar:${s.summonKind}');
      state.summons.remove(s);
      events.add(KnockedOutEvent(s.id));
    }
    p.effects = [
      for (final fx in p.effects)
        if (fx.sourceId != tk.id) fx,
      if (mine.isNotEmpty)
        TimedEffect(
            sourceId: tk.id,
            stat: BuffStat.damage,
            value: kAvatarPower * mine.length,
            turns: kAvatarTurns,
            ownerId: p.id,
            fresh: true),
    ];
    _summonSync(p);
    state.log = mine.isEmpty
        ? '${p.name} · ${tk.name}: no tenés invocaciones para fundirte'
        : '${p.name} · ${tk.name}: se funde con ${mine.length} invocaciones '
            '(+${_pct(kAvatarPower * mine.length)} de daño y '
            '${mine.map((s) => _defOf(s).element.label).toSet().join(', ')} '
            'en cada golpe, $kAvatarTurns turnos)';
  }

  /// Golpe de un jugador en Avatar: deja los estados de lo absorbido
  /// (gancho de `_damageEnemy`).
  void _avatarHit(Combatant a, Combatant e) {
    if (!e.alive) return;
    for (final st in _avatarStatuses(a)) {
      if (e.alive) _addStatus(e, st, source: a);
    }
  }

  /// Estados que deja cada golpe de [a] en Avatar (vacío si no lo está).
  /// El golpe los "lleva": también detonan reacciones
  /// (elemental_reactions.md § 9).
  List<StatusApplication> _avatarStatuses(Combatant a) {
    if (!a.isPlayer || a.once.isEmpty) return const [];
    if (a.effectFrom(kAvatarUltimate.id, BuffStat.damage) == null) {
      return const [];
    }
    return [
      for (final k in a.once)
        if (k.startsWith('avatar:'))
          if (kSummons[SummonKind.values.asNameMap()[k.substring(7)]]?.status
              case final st?)
            st,
    ];
  }

  /// Sacrificio: la invocación más vieja detona su elemento en todos.
  void _sacrifice(Combatant p, SkillDef tk) {
    final mine = _summonsOf(p);
    if (mine.isEmpty) {
      state.log = '${p.name} · ${tk.name}: no tenés invocaciones';
      return;
    }
    final s = mine.first;
    final d = _defOf(s);
    final ritual = _smod(p, SummonMod.sacrificeStatus) > 0;
    final parts = <String>[];
    for (final e in state.enemies.where((e) => e.alive).toList()) {
      final h = _damageEnemy(e, p.magic * kSacrificePower, p.critChance,
          element: d.element,
          physical: d.element == GameElement.fisico,
          hitStatus: d.status);
      parts.add('${e.name} ${h.damage}${h.critical ? '!' : ''}');
      if (ritual && d.status != null && e.alive) {
        _addStatus(e, d.status!, source: p);
      }
    }
    state.log = '${p.name} · ${tk.name}: ${s.name} detona '
        '${d.element.label} (MAG ${p.magic} × ${fm(kSacrificePower)}): '
        '${parts.join(', ')}';
    _summonGone(s, p, burst: true);
  }

  // ---------------- turno de la invocación ----------------

  /// Turno propio de [s] (gancho de `BattleEngine.enemyTurn`).
  void _summonTurn(Combatant s) {
    final owner = _ownerOf(s);
    if (owner == null || !owner.alive) {
      state.log = '${s.name} se desvanece (su invocador cayó)';
      _summonGone(s, null);
      return;
    }
    _summonAction(s, owner, 1);
    if (!s.alive) return;
    if (s.summonTurns < kSummonForever) s.summonTurns--;
    if (s.summonTurns <= 0) {
      _notes.add('${s.name} se desvanece');
      _summonGone(s, owner, burst: s.once.contains(kPortalMark));
    }
  }

  /// La acción de [s] según su tipo (IA de datos, summoner.md § 3).
  void _summonAction(Combatant s, Combatant owner, double mult) {
    final d = _defOf(s);
    final foes = state.enemies.where((e) => e.alive && !_passive(e)).toList();
    final anyFoe = state.enemies.where((e) => e.alive).toList();
    final pool = foes.isEmpty ? anyFoe : foes;
    switch (d.role) {
      case SummonRole.elemental:
        if (pool.isEmpty) return;
        final t = _summonTarget(d, pool);
        final h = _summonStrike(s, owner, t, mult);
        state.log = '${s.name} → ${t.name}: ${h.damage}${h.critical ? '!' : ''}'
            '${d.status != null && t.alive ? ' ${_statusText(d.status!)}' : ''}';
      case SummonRole.golem:
        final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
        var log = s.name;
        if (q != null) {
          final amount = jsRound(owner.magic *
              kGolemShield *
              (1 + _smod(owner, SummonMod.golemShield)) *
              mult);
          q.effects = [
            for (final fx in q.effects)
              if (!(fx.sourceId == 'golem' && fx.stat == BuffStat.shield)) fx,
            TimedEffect(
                sourceId: 'golem',
                stat: BuffStat.shield,
                value: amount.toDouble(),
                turns: 2,
                ownerId: owner.id),
          ];
          events.add(ShieldEvent(q.id, amount));
          log += ' escuda a ${q.name} ($amount)';
        }
        if (pool.isNotEmpty) {
          final t = pool.first;
          final h = _summonStrike(s, owner, t, mult);
          log += ' · golpea a ${t.name}: ${h.damage}';
        }
        state.log = '$log · provoca';
      case SummonRole.espiritu:
        final q = _lowest(_aliveParty, (c) => c.hp / c.maxHp);
        if (q != null && q.hp < q.maxHp * 0.8) {
          final h = math.max(1, jsRound(owner.magic * kSpiritHeal * mult));
          _heal(q, h);
          state.log = '${s.name} cura a ${q.name}: +$h HP';
        } else if (pool.isNotEmpty) {
          final t = pool[(_rand() * pool.length).floor()];
          t.effects = [
            for (final fx in t.effects)
              if (!(fx.sourceId == 'espiritu' &&
                  fx.stat == BuffStat.damageTaken))
                fx,
            TimedEffect(
                sourceId: 'espiritu',
                stat: BuffStat.damageTaken,
                value: kSpiritMark,
                turns: 2,
                ownerId: owner.id),
          ];
          events.add(BuffAppliedEvent(
              t.id, 'espiritu', BuffStat.damageTaken, kSpiritMark, 2));
          final h = _summonStrike(s, owner, t, mult);
          state.log = '${s.name} marca a ${t.name} (+${_pct(kSpiritMark)} '
              'daño recibido) · ${h.damage}';
        }
    }
    _flush();
  }

  /// A quién pega un elemental: al que reacciona con su elemento; si no,
  /// al que no tiene su estado; si no, al más herido.
  Combatant _summonTarget(SummonDef d, List<Combatant> pool) {
    for (final e in pool) {
      if (_reactionFor(e, d.element) != null) return e;
    }
    final st = d.status?.kind;
    if (st != null) {
      final fresh = pool.where((e) => e.stacks(st) == 0).toList();
      if (fresh.isNotEmpty) return fresh.first;
    }
    return _lowest(pool, (c) => c.hp / c.maxHp) ?? pool.first;
  }

  /// Golpe de [s] a [e]: su elemento y su estado (lo prepara a nombre del
  /// invocador). Las reacciones detonan como con cualquier golpe.
  _Hit _summonStrike(Combatant s, Combatant owner, Combatant e, double mult,
      {bool primary = true}) {
    final d = _defOf(s);
    final prevA = _attacker, prevAct = _act;
    _attacker = s;
    _act = null;
    final grow = SummonRules.killBonus(_ids(owner), s.summonKills);
    final h = _damageEnemy(e, s.attack * mult * (1 + grow), s.critChance,
        primary: primary,
        element: d.element,
        physical: d.element == GameElement.fisico,
        hitStatus: d.status);
    if (d.status != null && e.alive) _addStatus(e, d.status!, source: owner);
    if (!e.alive) s.summonKills++;
    _attacker = prevA;
    _act = prevAct;
    return h;
  }

  /// [s] se va (vencida, sacrificada o desvanecida). Con [burst] y
  /// Ofrenda Volátil (o Portal) detona su elemento en todos.
  void _summonGone(Combatant s, Combatant? owner, {bool burst = false}) {
    state.summons.remove(s);
    events.add(KnockedOutEvent(s.id));
    if (owner == null) return;
    final ofrenda = _smod(owner, SummonMod.deathBurst);
    final power = s.once.contains(kPortalMark)
        ? math.max(kPortalBurst, ofrenda)
        : ofrenda;
    if ((burst || ofrenda > 0) && power > 0) {
      final d = _defOf(s);
      final parts = <String>[];
      for (final e in state.enemies.where((e) => e.alive).toList()) {
        final prevA = _attacker, prevAct = _act;
        _attacker = s;
        _act = null;
        final h = _damageEnemy(e, owner.magic * power, 0,
            primary: false,
            element: d.element,
            physical: d.element == GameElement.fisico,
            hitStatus: d.status);
        _attacker = prevA;
        _act = prevAct;
        parts.add('${e.name} ${h.damage}');
      }
      if (parts.isNotEmpty) {
        _notes.add('¡${s.name} explota! ${d.element.label} '
            '(MAG × ${fm(power)}): ${parts.join(', ')}');
      }
    }
    _summonSync(owner);
  }

  // ---------------- golpes enemigos (gancho de `_basicAttack`) ----------

  /// Un golpe de un solo objetivo de [e] puede ir a una invocación: el
  /// Gólem provoca (50%); sin Gólem, 12% por invocación (tope 40%).
  bool _summonIntercept(Combatant e) {
    if (e.areaAttack) return false;
    final alive = state.summons.where((s) => s.alive).toList();
    if (alive.isEmpty) return false;
    // Marea de Espíritus: las que provocan se llevan el golpe seguro.
    final taunter = alive.where((s) => s.taunt > 0).firstOrNull;
    final golem = taunter ??
        alive.where((s) => s.summonKind == SummonKind.golem.name).firstOrNull;
    final chance = taunter != null
        ? 1.0
        : golem != null
            ? kGolemTaunt
            : math.min(0.4, kSummonDrawChance * alive.length);
    if (taunter == null && _rand() >= chance) return false;
    if (taunter != null) taunter.taunt--;
    final t = golem ?? alive[(_rand() * alive.length).floor()];
    final atk = math.max(1, jsRound(e.attack * (1 + e.effectTotal(BuffStat.attack))));
    final dmg = math.max(1, jsRound(atk * (golem != null ? 0.6 : 1.0)));
    events.add(ActionEvent(e.id, BattleActionKind.enemyAttack, targetId: t.id));
    t.hp = math.max(0, t.hp - dmg);
    events.add(DamageEvent(t.id, dmg));
    state.log = '${e.name} → ${t.name}: $dmg'
        '${golem != null ? ' (provocado)' : ''}';
    if (!t.alive) {
      _notes.add('${t.name} cae');
      _summonGone(t, _ownerOf(t));
    }
    _flush();
    return true;
  }

  // ---------------- inicio del turno del invocador ----------------

  /// Pacto Eterno: −5% de vida máx. por invocación (nunca baja de 1).
  void _summonPactTick(Combatant p) {
    if (_smod(p, SummonMod.pact) <= 0) return;
    final n = _summonsOf(p).length;
    if (n == 0) return;
    final cost = math.min(p.hp - 1, jsRound(p.maxHp * kPactCost * n));
    if (cost <= 0) return;
    p.hp -= cost;
    events.add(DamageEvent(p.id, cost, sourceId: 'pacto'));
    _notes.add('Pacto Eterno: ${p.name} paga $cost HP por $n invocaciones');
  }
}
