import 'dart:collection';

import '../data/enemy_families.dart';
import '../data/game_catalog.dart';
import '../models/ascension.dart';
import '../models/attributes.dart';
import '../models/battle_state.dart';
import '../models/eco.dart';
import '../models/passive_mechanic.dart';
import '../models/game_session.dart';
import '../models/item.dart';
import '../models/loot.dart';
import '../models/passive_tree.dart';
import '../models/player_profile.dart';
import '../models/player_state.dart';
import '../models/status.dart';
import '../models/upgrade_stat.dart';
import '../models/weapon.dart';
import '../models/tutorial.dart';
import 'json_read.dart';
import 'run_json.dart';

/// `GameSession` completo ⇄ JSON: el snapshot que el host manda a los
/// clientes (`{t:'state', s:S}` del prototipo). Claves en
/// docs/specs/netcode.md § "Host → cliente".
///
/// El [catalog] solo hace falta para leer: el `build` de un combatiente
/// guarda el arma por id y se resuelve contra el catálogo.
class SessionJson {
  const SessionJson([this.catalog = GameCatalog.standard]);

  final GameCatalog catalog;

  // ------------------------------------------------------------------
  // GameSession
  // ------------------------------------------------------------------

  /// [profiles] `false`: los jugadores van sin su perfil `p` (el snapshot
  /// de red los manda aparte, solo cuando cambian; netcode.md § "Perfiles
  /// solo cuando cambian").
  Json toJson(GameSession s, {bool profiles = true}) => {
        'mode': s.mode.name,
        'players': [
          for (final p in s.playerList) playerToJson(p, profile: profiles),
        ],
        'mission': s.mission == null ? null : missionToJson(s.mission!),
        'battle': s.battle == null ? null : battleToJson(s.battle!),
        'vote': s.vote == null ? null : voteToJson(s.vote!),
        'prep': s.prep == null ? null : prepToJson(s.prep!),
        'result': s.result == null ? null : resultToJson(s.result!),
        'time': s.time,
        'grace': s.graceUntil,
        'after': s.afterLevelUp?.name,
        'seq': s.seq,
        if (s.ground.isNotEmpty)
          'ground': [for (final g in s.ground) groundToJson(g)],
        if (s.groundSeq != 0) 'gseq': s.groundSeq,
        // Opcional: solo con la sala pausada.
        if (s.pausedBy != null)
          'pause': {'id': s.pausedBy, 'name': s.pausedName ?? ''},
        // Endgame v0.4 (ecos_atlas.md § 7): opcionales.
        if (s.eco != null) 'eco': s.eco!.toJson(),
        if (s.ecoOwner != null) 'ecoBy': s.ecoOwner,
        if (s.atlas.isNotEmpty) 'atlas': s.atlas,
        // Ascensión v0.5 (ascension.md § 6): opcional.
        if (s.trial != null) 'trial': s.trial,
        // Tiempo de turno v0.5.1 (accessibility.md § 7): opcional, solo
        // si no es el normal (un cliente viejo lo ignora).
        if (s.turnTimer != TurnTimer.normal) 'tt': s.turnTimer.name,
        // Jefes del Abismo v0.8 (abyss_bosses.md § 5): opcionales.
        if (s.abyss != null) 'abyss': s.abyss,
        if (s.abyssOwner != null) 'abyssBy': s.abyssOwner,
        // TUTORIAL v0.9 (combat_tutorial.md § 6): opcionales.
        if (s.tutorial != null) 'tut': s.tutorial!.toJson(),
        if (s.tutorialRuns != 0) 'tutN': s.tutorialRuns,
        // Travesía (protocolo Travesía 1; roguelike.md): opcional.
        if (s.run != null) 'run': RunJson.toJson(s.run!),
      };

  GameSession fromJson(Json j) {
    final players = <String, SessionPlayer>{};
    for (final raw in j.list('players')) {
      final p = playerFromJson(asJson(raw));
      players[p.id] = p;
    }
    return GameSession(
      mode: j.enumByName('mode', SessionMode.values),
      players: LinkedHashMap.of(players),
      mission: _opt(j.objOrNull('mission'), missionFromJson),
      battle: _opt(j.objOrNull('battle'), battleFromJson),
      vote: _opt(j.objOrNull('vote'), voteFromJson),
      prep: _opt(j.objOrNull('prep'), prepFromJson),
      result: _opt(j.objOrNull('result'), resultFromJson),
      time: j.dbl('time'),
      graceUntil: j.dbl('grace'),
      afterLevelUp: j.enumOrNull('after', AfterLevelUp.values),
      seq: j.integer('seq'),
      ground: j['ground'] == null
          ? null
          : [for (final raw in j.list('ground')) groundFromJson(asJson(raw))],
      groundSeq: j.intOrNull('gseq') ?? 0,
      pausedBy: j.objOrNull('pause')?.str('id'),
      pausedName: j.objOrNull('pause')?.str('name'),
      eco: j['eco'] == null
          ? null
          : EcoItem.fromJson(j['eco']) ??
              (throw FormatException('JSON inválido: eco', j['eco'])),
      ecoOwner: j.strOrNull('ecoBy'),
      atlas: j['atlas'] == null ? null : j.strings('atlas'),
      trial: j.intOrNull('trial'),
      turnTimer: TurnTimer.fromName(j['tt']),
      abyss: j.intOrNull('abyss'),
      abyssOwner: j.strOrNull('abyssBy'),
      tutorial: j.objOrNull('tut') == null
          ? null
          : TutorialState.fromJson(j.objOrNull('tut')!),
      tutorialRuns: j.intOrNull('tutN') ?? 0,
      run: _opt(j.objOrNull('run'), RunJson.fromJson),
    );
  }

  // ------------------------------------------------------------------
  // Loot v2: piso (todo el loot va en el snapshot; cada cliente muestra
  // solo el suyo y el compartido, ver netcode.md § "Loot instanciado")
  // ------------------------------------------------------------------

  Json groundToJson(GroundLoot g) => {
        'id': g.id,
        'd': g.drop.toJson(),
        'x': g.x,
        'y': g.y,
        if (g.ownerId != null) 'own': g.ownerId,
        // v0.5.1: piso de la misión donde cayó (opcional; 0 si falta).
        if (g.floor != 0) 'f': g.floor,
        // v0.20.11 (protocolo 33): quién soltó el loot compartido.
        if (g.byId != null) 'by': g.byId,
      };

  GroundLoot groundFromJson(Json j) => GroundLoot(
        id: j.integer('id'),
        drop: LootDrop.fromJson(j['d']) ??
            (throw FormatException('JSON inválido: drop', j['d'])),
        x: j.dbl('x'),
        y: j.dbl('y'),
        ownerId: j.strOrNull('own'),
        floor: j.intOrNull('f') ?? 0,
        byId: j.strOrNull('by'),
      );

  static T? _opt<T>(Json? j, T Function(Json) f) => j == null ? null : f(j);

  // ------------------------------------------------------------------
  // Jugadores
  // ------------------------------------------------------------------

  Json playerToJson(SessionPlayer p, {bool profile = true}) => {
        'id': p.id,
        if (profile) 'p': p.profile.toJson(),
        'x': p.x,
        'y': p.y,
        'dir': p.dir,
        'ep': p.epoch,
        'mv': p.moving,
        'hp': p.hp,
        'mp': p.mp,
        'mhp': p.maxHp,
        'mmp': p.maxMp,
        'ult': p.ult,
        'lvup': p.levelUpPending,
        if (p.tutorialVersion != 0) 'tv': p.tutorialVersion,
        // Protocolo 21: confirmaciones del alijo (characters.md § 3.2).
        if (p.stashAcks.isNotEmpty)
          'sk': [
            for (final MapEntry(key: id, value: a) in p.stashAcks.entries)
              {
                'id': id,
                if (a.put) 'put': true,
                if (a.box) 'bx': true,
                'd': [for (final d in a.drops) d?.toJson()],
              },
          ],
      };

  static Map<String, StashAck> _stashAcks(Object? raw) {
    final out = <String, StashAck>{};
    if (raw is! List) return out;
    for (final r in raw) {
      if (r is! Map) continue;
      final id = r['id'], d = r['d'];
      if (id is! String || d is! List) continue;
      out[id] = StashAck(
          put: r['put'] == true,
          box: r['bx'] == true,
          drops: [for (final x in d) LootDrop.fromJson(x)]);
    }
    return out;
  }

  SessionPlayer playerFromJson(Json j) => SessionPlayer(
        id: j.str('id'),
        profile: PlayerProfile.fromJson(j.obj('p')),
        x: j.dbl('x'),
        y: j.dbl('y'),
        dir: j.integer('dir'),
        epoch: j.integer('ep'),
        moving: j.boolean('mv'),
        hp: j.dbl('hp'),
        mp: j.dbl('mp'),
        maxHp: j.integer('mhp'),
        maxMp: j.integer('mmp'),
        ult: j.dbl('ult'),
        levelUpPending: j.boolean('lvup'),
        tutorialVersion: j.intOrNull('tv') ?? 0,
        stashAcks: _stashAcks(j['sk']),
      );

  // ------------------------------------------------------------------
  // Misión
  // ------------------------------------------------------------------

  Json missionToJson(MissionRun m) => {
        'id': m.missionId,
        'seed': m.seed,
        'goal': m.goal,
        'kills': m.kills,
        'elapsed': m.elapsed,
        'kos': m.kos,
        'xp': m.xp,
        'cr': m.credits,
        'obj': [
          for (final o in m.objectives)
            {'k': o.kind.name, 'goal': o.goal, 'n': o.count},
        ],
        'open': m.open,
        'elites': m.elites,
        'eliteDrops': [for (final d in m.eliteDrops) dropToJson(d)],
        'fe': [for (final e in m.enemies) enemyToJson(e)],
        'items': [for (final i in m.items) itemToJson(i)],
        if (m.zoneLevel != 1) 'zl': m.zoneLevel,
        if (m.zone != 0) 'zone': m.zone,
        if (m.floor != 0) 'floor': m.floor,
        if (m.floors != 1) 'floors': m.floors,
        if (m.floorGoals.isNotEmpty) 'fg': m.floorGoals,
        if (m.levels.isNotEmpty) 'lv': m.levels,
        if (m.opened.isNotEmpty) 'opened': (m.opened.toList()..sort()),
        // v0.6 (protocolo 7; worldgen.md § 11.6): exploración.
        if (m.poiUsed.isNotEmpty) 'pu': (m.poiUsed.toList()..sort()),
        if (m.poiSeen.isNotEmpty) 'ps': (m.poiSeen.toList()..sort()),
        if (m.questsDone.isNotEmpty) 'qd': (m.questsDone.toList()..sort()),
        if (m.questsFailed.isNotEmpty) 'qf': (m.questsFailed.toList()..sort()),
        if (m.blessing != null) 'bl': m.blessing!.name,
        if (m.windUntil != 0) 'wind': m.windUntil,
      };

  static List<int> _ints(Json j, String k) {
    final v = j[k];
    if (v == null) return const [];
    return [
      for (final e in asList(v))
        e is num ? e.toInt() : throw FormatException('JSON inválido: $k', v),
    ];
  }

  MissionRun missionFromJson(Json j) => MissionRun(
        missionId: j.str('id'),
        seed: j.integer('seed'),
        goal: j.integer('goal'),
        kills: j.integer('kills'),
        elapsed: j.dbl('elapsed'),
        kos: j.integer('kos'),
        xp: j.integer('xp'),
        credits: j.integer('cr'),
        objectives: [
          for (final raw in j.list('obj'))
            () {
              final o = asJson(raw);
              return MissionObjective(
                  o.enumByName('k', ObjectiveKind.values), o.integer('goal'),
                  count: o.integer('n'));
            }(),
        ],
        open: j.boolean('open'),
        elites: j.integer('elites'),
        eliteDrops: [
          for (final raw in j.list('eliteDrops')) dropFromJson(asJson(raw)),
        ],
        enemies: [for (final raw in j.list('fe')) enemyFromJson(asJson(raw))],
        items: [for (final raw in j.list('items')) itemFromJson(asJson(raw))],
        zoneLevel: j.intOrNull('zl') ?? 1,
        zone: j.intOrNull('zone') ?? 0,
        floor: j.intOrNull('floor') ?? 0,
        floors: j.intOrNull('floors') ?? 1,
        floorGoals: _ints(j, 'fg'),
        levels: _ints(j, 'lv'),
        opened: _ints(j, 'opened').toSet(),
        poiUsed: _ints(j, 'pu').toSet(),
        poiSeen: _ints(j, 'ps').toSet(),
        questsDone: _ints(j, 'qd').toSet(),
        questsFailed: _ints(j, 'qf').toSet(),
        blessing: j.enumOrNull('bl', BlessingKind.values),
        windUntil: j.dblOrNull('wind') ?? 0,
      );

  Json dropToJson(WeaponDrop d) => {
        'p': d.playerId,
        'w': d.weaponId,
        if (d.uid != null) 'u': d.uid,
        if (d.rarity != null) 'r': d.rarity!.name,
      };

  WeaponDrop dropFromJson(Json j) => WeaponDrop(j.str('p'), j.str('w'),
      uid: j.strOrNull('u'), rarity: j.enumOrNull('r', Rarity.values));

  Json enemyToJson(FieldEnemy e) => {
        'id': e.id,
        'x': e.x,
        'y': e.y,
        'hx': e.homeX,
        'hy': e.homeY,
        'g': e.group,
        'boss': e.boss,
        'elite': e.elite,
        'alive': e.alive,
        'tm': e.timer,
        'vx': e.vx,
        'vy': e.vy,
        'dir': e.dir,
        'aggro': e.aggro,
        if (e.floor != 0) 'f': e.floor,
      };

  FieldEnemy enemyFromJson(Json j) => FieldEnemy(
        id: j.integer('id'),
        x: j.dbl('x'),
        y: j.dbl('y'),
        homeX: j.dbl('hx'),
        homeY: j.dbl('hy'),
        group: List.unmodifiable(j.strings('g')),
        boss: j.boolean('boss'),
        elite: j.boolean('elite'),
        alive: j.boolean('alive'),
        timer: j.dbl('tm'),
        vx: j.dbl('vx'),
        vy: j.dbl('vy'),
        dir: j.integer('dir'),
        aggro: j.boolean('aggro'),
        floor: j.intOrNull('f') ?? 0,
      );

  Json itemToJson(MissionItem i) => {
        'id': i.id,
        'k': i.kind.name,
        'x': i.x,
        'y': i.y,
        'done': i.done,
        if (i.floor != 0) 'f': i.floor,
        if (i.tier != ChestTier.madera) 'tr': i.tier.name,
        if (i.guard != null) 'gd': i.guard,
        if (i.secret != null) 'sc': i.secret,
      };

  MissionItem itemFromJson(Json j) => MissionItem(
        id: j.integer('id'),
        kind: j.enumByName('k', MissionItemKind.values),
        x: j.dbl('x'),
        y: j.dbl('y'),
        done: j.boolean('done'),
        floor: j.intOrNull('f') ?? 0,
        tier: j.enumOrNull('tr', ChestTier.values) ?? ChestTier.madera,
        guard: j.intOrNull('gd'),
        secret: j.intOrNull('sc'),
      );

  // ------------------------------------------------------------------
  // Lobby: votación, preparación y resultado
  // ------------------------------------------------------------------

  Json voteToJson(MissionVote v) =>
      {'m': v.missionId, 'by': v.proposedBy, 'yes': v.yes.toList()};

  MissionVote voteFromJson(Json j) =>
      MissionVote(j.str('m'), j.str('by'), j.strings('yes').toSet());

  Json prepToJson(MissionPrep p) => {'m': p.missionId, 'ready': p.ready};

  MissionPrep prepFromJson(Json j) {
    final ready = <String, bool>{};
    for (final e in j.obj('ready').entries) {
      final v = e.value;
      if (v is! bool) throw FormatException('JSON inválido: ready', v);
      ready[e.key] = v;
    }
    return MissionPrep(j.str('m'), ready);
  }

  Json resultToJson(MissionResult r) => {
        'id': r.id,
        'm': r.missionId,
        'name': r.missionName,
        'ok': r.success,
        'rank': r.rank.name,
        'time': r.time,
        'xp': r.xp,
        'cr': r.credits,
        'bonus': r.bonus,
        'bonusPct': r.bonusPercent,
        'kos': r.kos,
        'elites': r.elites,
        'eliteDrops': [for (final d in r.eliteDrops) dropToJson(d)],
        'drops': r.drops,
        'left': r.timeLeft,
        if (r.zone != 0) 'zone': r.zone,
        if (r.unlocked.isNotEmpty) 'unl': r.unlocked,
      };

  MissionResult resultFromJson(Json j) {
    final drops = <String, String>{};
    for (final e in j.obj('drops').entries) {
      final v = e.value;
      if (v is! String) throw FormatException('JSON inválido: drop', v);
      drops[e.key] = v;
    }
    return MissionResult(
      id: j.integer('id'),
      missionId: j.str('m'),
      missionName: j.str('name'),
      success: j.boolean('ok'),
      rank: j.enumByName('rank', MissionRank.values),
      time: j.dbl('time'),
      xp: j.integer('xp'),
      credits: j.integer('cr'),
      bonus: j.integer('bonus'),
      bonusPercent: j.dbl('bonusPct'),
      kos: j.integer('kos'),
      elites: j.integer('elites'),
      eliteDrops: [
        for (final raw in j.list('eliteDrops')) dropFromJson(asJson(raw)),
      ],
      drops: drops,
      timeLeft: j.dbl('left'),
      zone: j.intOrNull('zone') ?? 0,
      unlocked: {
        for (final e
            in (j.objOrNull('unl') ?? const <String, Object?>{}).entries)
          e.key: e.value is num
              ? (e.value as num).toInt()
              : throw FormatException('JSON inválido: unl', e.value),
      },
    );
  }

  // ------------------------------------------------------------------
  // Batalla
  // ------------------------------------------------------------------

  Json battleToJson(SessionBattle b) => {
        'id': b.id,
        'st': battleStateToJson(b.state),
        'fe': b.fieldEnemyId,
        'boss': b.boss,
        'elite': b.elite,
        'wait': b.wait,
        'turn': b.turnTime,
        'end': b.endTimer,
        if (b.endHold > 0) 'hold': b.endHold,
        if (b.level != 0) 'lv': b.level,
      };

  SessionBattle battleFromJson(Json j) => SessionBattle(
        id: j.integer('id'),
        state: battleStateFromJson(j.obj('st')),
        fieldEnemyId: j.integer('fe'),
        boss: j.boolean('boss'),
        elite: j.boolean('elite'),
        wait: j.dbl('wait'),
        turnTime: j.dbl('turn'),
        endTimer: j.dblOrNull('end'),
        endHold: j.dblOrNull('hold') ?? 0,
        level: j.intOrNull('lv') ?? 0,
      );

  Json battleStateToJson(BattleState s) => {
        'party': [for (final c in s.party) combatantToJson(c)],
        'enemies': [for (final c in s.enemies) combatantToJson(c)],
        // Invocaciones v0.8.1 (opcional; summoner.md § 6).
        if (s.summons.isNotEmpty)
          'sum': [for (final c in s.summons) combatantToJson(c)],
        'clock': s.clock,
        'cur': s.currentId,
        'log': s.log,
        'out': s.outcome == null
            ? null
            : {
                'win': s.outcome!.victory,
                'xp': s.outcome!.xp,
                'cr': s.outcome!.credits,
              },
        'boss': s.boss,
        'elite': s.elite,
        // Travesía, turnos porBando (roguelike.md § 6); el Mundo no los
        // manda (mismo formato que el protocolo 31).
        if (s.porBando) ...{
          'tr': s.turnRule.name,
          'gp': s.groupPhase,
          'act': s.acted.toList(),
          'rd': s.round,
        },
      };

  BattleState battleStateFromJson(Json j) {
    final out = j.objOrNull('out');
    return BattleState(
      party: [
        for (final raw in j.list('party')) combatantFromJson(asJson(raw))
      ],
      enemies: [
        for (final raw in j.list('enemies')) combatantFromJson(asJson(raw)),
      ],
      summons: j['sum'] == null
          ? null
          : [for (final raw in j.list('sum')) combatantFromJson(asJson(raw))],
      clock: j.dbl('clock'),
      currentId: j.strOrNull('cur'),
      log: j.str('log'),
      outcome: out == null
          ? null
          : BattleOutcome(
              victory: out.boolean('win'),
              xp: out.integer('xp'),
              credits: out.integer('cr'),
            ),
      boss: j.boolean('boss'),
      elite: j.boolean('elite'),
      turnRule: j.enumOrNull('tr', TurnRule.values) ?? TurnRule.velocidad,
      groupPhase: j['gp'] as bool? ?? false,
      acted: j['act'] == null ? null : j.strings('act').toSet(),
      round: j.intOrNull('rd') ?? 0,
    );
  }

  Json combatantToJson(Combatant c) => {
        'id': c.id,
        'name': c.name,
        'pl': c.isPlayer,
        'hp': c.hp,
        'mhp': c.maxHp,
        'mp': c.mp,
        'mmp': c.maxMp,
        'spd': c.speed,
        'atk': c.attack,
        'mag': c.magic,
        'crit': c.critChance,
        'critX': c.critMultiplier,
        'def': c.defense,
        'defPct': c.defensePercent,
        'ultB': c.ultChargeBonus,
        'healB': c.healBonus,
        'stb': enumIntMapToJson(c.statusBonus),
        'keys': c.keystones.toList(),
        'pierceW': c.pierceWeakness,
        'statusW': c.statusWeakness,
        'stunCh': c.stunOnAttackChance,
        'build': c.build == null ? null : buildToJson(c.build!),
        'cls': c.classId,
        'wt': c.weaponType,
        'sk': c.skillIds,
        'pot': c.potions,
        'eter': c.ethers,
        'eterV': c.aethers,
        'et': c.enemyType,
        'elite': c.elite,
        'boss': c.boss,
        'area': c.areaAttack,
        'pierce': c.pierce,
        'inf': c.inflicts == null
            ? null
            : {
                'k': c.inflicts!.kind.name,
                'n': c.inflicts!.stacks,
                'ch': c.inflicts!.chance,
              },
        'sts': enumIntMapToJson(c.statuses),
        'holy': c.holyTurns,
        if (c.basicHits != 0) 'bh': c.basicHits,
        'nt': c.nextTurn,
        'dfd': c.defending,
        'prot': c.protecting,
        'taunt': c.taunt,
        'bdef': c.bonusDefense,
        'ult': c.ult,
        'acts': c.actions,
        if (c.mechanics.isNotEmpty) 'mech': c.mechanics.toList(),
        if (c.effects.isNotEmpty)
          'fx': [for (final e in c.effects) timedEffectToJson(e)],
        if (c.extraTurn != 0) 'xt': c.extraTurn,
        // Quiebre y ULT enemiga (opcionales).
        if (c.breakBase != 0) 'brkB': c.breakBase,
        if (c.level != 0) 'lv': c.level,
        if (c.breakGauge != 0) 'brk': c.breakGauge,
        if (c.breaks != 0) 'brkN': c.breaks,
        if (c.vulnerable != 0) 'vul': c.vulnerable,
        if (c.breakSkip) 'brkS': true,
        if (c.fissured) 'fis': true,
        if (c.ultId != null) 'eult': c.ultId,
        if (c.ultPending) 'ultP': true,
        // ULT v2 (opcionales; ultimates_v2.md § 5.2).
        if (c.ultWeaken != 0) 'ultW': c.ultWeaken,
        if (c.lastSkillId != null) 'lsk': c.lastSkillId,
        if (c.doomTurns != 0) 'doom': [c.doom, c.doomTurns, c.doomBy],
        // Mecánicas de jefe v0.2 (opcionales).
        if (c.webbed) 'web': true,
        if (c.stance != 0) 'stc': c.stance,
        if (c.stanceTurns != 0) 'stcN': c.stanceTurns,
        // Mecánicas de jefe v0.3 (opcionales).
        if (c.lava != 0) 'lava': c.lava,
        if (c.voidMarked) 'vmk': true,
        if (c.phase != 0) 'phase': c.phase,
        if (c.mechTurns != 0) 'mchN': c.mechTurns,
        // Afijos del arma (loot v2, opcionales).
        if (c.lifeSteal != 0) 'ls': c.lifeSteal,
        if (c.regenPerTurn != 0) 'rgn': c.regenPerTurn,
        if (c.statusResist != 0) 'sres': c.statusResist,
        if (c.healReceived != 0) 'hrec': c.healReceived,
        // Ascensión (opcional): mecánicas de 1 vez por batalla ya usadas.
        if (c.once.isNotEmpty) 'once': c.once.toList(),
        // Elementos v0.7 (opcionales). La familia solo viaja si no es la
        // del tipo de enemigo (razas de jugador, pruebas).
        if (c.family != null &&
            (c.isPlayer || c.family != kEnemyFamily[c.enemyType]))
          'fam': c.family!.name,
        if (c.brittle) 'brit': true,
        if (c.freezeResist != 0) 'frzR': c.freezeResist,
        if (c.primedBy.isNotEmpty)
          'prim': {for (final e in c.primedBy.entries) e.key.name: e.value},
        // Jefes del Abismo v0.8 (opcionales; abyss_bosses.md § 5).
        if (c.abyssTurns != 0) 'abT': c.abyssTurns,
        if (c.abyssEnraged) 'abE': true,
        if (c.abyssSeal != 0) 'abS': c.abyssSeal,
        if (c.abyssSealTurns != 0) 'abSN': c.abyssSealTurns,
        if (c.abyssAspect != 0) 'abA': c.abyssAspect,
        if (c.abyssTaken != 0) 'abK': c.abyssTaken,
        if (c.delayStreak != 0) 'dlS': c.delayStreak,
        if (c.abyssFeast != 0) 'abF': c.abyssFeast,
        if (c.abyssCopy != null) 'abC': c.abyssCopy,
        // Invocador v0.8.1 (opcionales).
        if (c.summonOwner != null) 'smO': c.summonOwner,
        if (c.summonKind != null) 'smK': c.summonKind,
        if (c.summonTurns != 0) 'smT': c.summonTurns,
        if (c.summonKills != 0) 'smN': c.summonKills,
        // Pulso e Instante v0.9 (opcionales; combo_balance.md § 5.2).
        if (c.pulse != 0) 'pls': c.pulse,
        if (c.ultBonusTurn != 0) 'ubt': c.ultBonusTurn,
        if (c.chained) 'chn': true,
        if (c.guardStreak) 'gst': true,
        if (c.guardHitPending) 'ghp': true,
        if (c.practice) 'prac': true,
        // Letra de repetidos v0.13.1 (opcional).
        if (c.tag != null) 'tag': c.tag,
      };

  Json timedEffectToJson(TimedEffect e) => {
        'src': e.sourceId,
        'stat': e.stat.name,
        'v': e.value,
        'turns': e.turns,
        if (e.ownerId != null) 'by': e.ownerId,
        if (e.fresh) 'new': true,
      };

  TimedEffect timedEffectFromJson(Json j) => TimedEffect(
        sourceId: j.str('src'),
        stat: j.enumByName('stat', BuffStat.values),
        value: j.dbl('v'),
        turns: j.integer('turns'),
        ownerId: j.strOrNull('by'),
        fresh: j.flag('new'),
      );

  Combatant combatantFromJson(Json j) {
    final inf = j.objOrNull('inf');
    final build = j.objOrNull('build');
    return Combatant(
      id: j.str('id'),
      name: j.str('name'),
      isPlayer: j.boolean('pl'),
      hp: j.integer('hp'),
      maxHp: j.integer('mhp'),
      mp: j.dbl('mp'),
      maxMp: j.integer('mmp'),
      speed: j.dbl('spd'),
      attack: j.integer('atk'),
      magic: j.integer('mag'),
      critChance: j.dbl('crit'),
      critMultiplier: j.dbl('critX'),
      defense: j.integer('def'),
      defensePercent: j.dbl('defPct'),
      ultChargeBonus: j.dbl('ultB'),
      healBonus: j.dbl('healB'),
      statusBonus: enumIntMap(j['stb'], StatusKind.values),
      keystones: j.strings('keys').toSet(),
      pierceWeakness: j.dbl('pierceW'),
      statusWeakness: j.integer('statusW'),
      stunOnAttackChance: j.dbl('stunCh'),
      build: build == null ? null : buildFromJson(build),
      classId: j.strOrNull('cls'),
      weaponType: j.strOrNull('wt'),
      skillIds: List.unmodifiable(j.strings('sk')),
      potions: j.integer('pot'),
      ethers: j.integer('eter'),
      aethers: j.intOrNull('eterV') ?? 0,
      enemyType: j.strOrNull('et'),
      elite: j.boolean('elite'),
      boss: j.boolean('boss'),
      areaAttack: j.boolean('area'),
      pierce: j.boolean('pierce'),
      inflicts: inf == null
          ? null
          : StatusApplication(
              inf.enumByName('k', StatusKind.values), inf.integer('n'),
              chance: inf.dblOrNull('ch')),
      statuses: enumIntMap(j['sts'], StatusKind.values),
      holyTurns: j.integer('holy'),
      basicHits: j['bh'] is num ? (j['bh'] as num).toInt() : 0,
      nextTurn: j.dbl('nt'),
      defending: j.boolean('dfd'),
      protecting: j.boolean('prot'),
      taunt: j.integer('taunt'),
      bonusDefense: j.integer('bdef'),
      ult: j.dbl('ult'),
      actions: j.integer('acts'),
      // Árbol v2: opcionales (un estado viejo no los trae).
      mechanics: j['mech'] == null ? {} : j.strings('mech').toSet(),
      effects: j['fx'] == null
          ? []
          : [for (final raw in j.list('fx')) timedEffectFromJson(asJson(raw))],
      extraTurn: j.intOrNull('xt') ?? 0,
      breakBase: j.dblOrNull('brkB') ?? 0,
      level: j.intOrNull('lv') ?? 0,
      breakGauge: j.dblOrNull('brk') ?? 0,
      breaks: j.intOrNull('brkN') ?? 0,
      vulnerable: j.intOrNull('vul') ?? 0,
      breakSkip: j.flag('brkS'),
      fissured: j.flag('fis'),
      ultId: j.strOrNull('eult'),
      ultPending: j.flag('ultP'),
      ultWeaken: j.dblOrNull('ultW') ?? 0,
      lastSkillId: j.strOrNull('lsk'),
      doom: _doom(j['doom'], 0) as int,
      doomTurns: _doom(j['doom'], 1) as int,
      doomBy: _doom(j['doom'], 2) as String?,
      webbed: j.flag('web'),
      stance: j.intOrNull('stc') ?? 0,
      stanceTurns: j.intOrNull('stcN') ?? 0,
      lava: j.intOrNull('lava') ?? 0,
      voidMarked: j.flag('vmk'),
      phase: j.intOrNull('phase') ?? 0,
      mechTurns: j.intOrNull('mchN') ?? 0,
      lifeSteal: j.dblOrNull('ls') ?? 0,
      regenPerTurn: j.dblOrNull('rgn') ?? 0,
      statusResist: j.intOrNull('sres') ?? 0,
      healReceived: j.dblOrNull('hrec') ?? 0,
      once: j['once'] == null ? {} : j.strings('once').toSet(),
      family: j.enumOrNull('fam', EnemyFamily.values),
      brittle: j.flag('brit'),
      freezeResist: j.intOrNull('frzR') ?? 0,
      primedBy: {
        if (j.objOrNull('prim') case final m?)
          for (final e in m.entries)
            if (StatusKind.values.asNameMap()[e.key] case final k?)
              if (e.value case final String id) k: id,
      },
      abyssTurns: j.intOrNull('abT') ?? 0,
      abyssEnraged: j.flag('abE'),
      abyssSeal: j.intOrNull('abS') ?? 0,
      abyssSealTurns: j.intOrNull('abSN') ?? 0,
      abyssAspect: j.intOrNull('abA') ?? 0,
      abyssTaken: j.intOrNull('abK') ?? 0,
      delayStreak: j.intOrNull('dlS') ?? 0,
      abyssFeast: j.intOrNull('abF') ?? 0,
      abyssCopy: j.strOrNull('abC'),
      summonOwner: j.strOrNull('smO'),
      summonKind: j.strOrNull('smK'),
      summonTurns: j.intOrNull('smT') ?? 0,
      summonKills: j.intOrNull('smN') ?? 0,
      pulse: j.intOrNull('pls') ?? 0,
      ultBonusTurn: j.dblOrNull('ubt') ?? 0,
      chained: j.flag('chn'),
      guardStreak: j.flag('gst'),
      guardHitPending: j.flag('ghp'),
      practice: j.flag('prac'),
      tag: j.strOrNull('tag'),
    );
  }

  /// Campo [i] de la marca `doom` (`[daño, turnos, quién]`).
  static Object? _doom(Object? raw, int i) {
    if (raw is! List || raw.length < 3) return i == 2 ? null : 0;
    final v = raw[i];
    if (i == 2) return v is String ? v : null;
    return v is num ? v.toInt() : 0;
  }

  Json buildToJson(PlayerBuild b) => {
        'cls': b.classId,
        'lvl': b.level,
        'st': {
          for (final a in Attribute.values)
            PlayerProfile.attributeKey(a): b.attributes[a],
        },
        'w': b.equippedWeapon.id,
        'up': b.weaponUpgrades.toJson(),
        'tree': b.passiveProgress.takenNodeIds,
        'bdef': b.bonusDefense,
        if (b.item != null) 'item': b.item!.toJson(),
        if (!b.ascension.isEmpty) 'asc': b.ascension.toJson(),
        // ULT activa (ultimates_v2.md § 5.2): opcional.
        if (b.ultSel != null) 'us': b.ultSel,
        if (b.ultLevel > 1) 'ulv': b.ultLevel,
      };

  PlayerBuild buildFromJson(Json j) {
    final wid = j.str('w');
    final weapon = catalog.weapons[wid] ??
        (throw FormatException('JSON inválido: arma desconocida', wid));
    final st = j.obj('st');
    var up = const WeaponUpgradeLevels();
    for (final e in j.obj('up').entries) {
      final stat = UpgradeStat.fromKey(e.key) ??
          (throw FormatException('JSON inválido: mejora', e.key));
      final v = e.value;
      if (v is! num) throw FormatException('JSON inválido: mejora', v);
      up = up.withLevel(stat, v.toInt());
    }
    return PlayerBuild(
      classId: j.str('cls'),
      level: j.integer('lvl'),
      attributes: PlayerAttributes(Map.unmodifiable({
        for (final a in Attribute.values)
          a: st.integer(PlayerProfile.attributeKey(a)),
      })),
      equippedWeapon: weapon,
      weaponUpgrades: up,
      passiveProgress:
          PlayerPassiveProgress(List.unmodifiable(j.strings('tree'))),
      item: j['item'] == null
          ? null
          : ItemInstance.fromJson(j['item']) ??
              (throw FormatException('JSON inválido: arma', j['item'])),
      bonusDefense: j.integer('bdef'),
      ascension: AscensionProgress.fromJson(j['asc']),
      ultSel: j.strOrNull('us'),
      ultLevel: j.intOrNull('ulv') ?? 1,
    );
  }
}
