import 'dart:collection';

import '../data/game_catalog.dart';
import '../models/attributes.dart';
import '../models/battle_state.dart';
import '../models/game_session.dart';
import '../models/passive_tree.dart';
import '../models/player_profile.dart';
import '../models/player_state.dart';
import '../models/status.dart';
import '../models/upgrade_stat.dart';
import '../models/weapon.dart';
import 'json_read.dart';

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

  Json toJson(GameSession s) => {
        'mode': s.mode.name,
        'players': [for (final p in s.playerList) playerToJson(p)],
        'mission': s.mission == null ? null : missionToJson(s.mission!),
        'battle': s.battle == null ? null : battleToJson(s.battle!),
        'vote': s.vote == null ? null : voteToJson(s.vote!),
        'prep': s.prep == null ? null : prepToJson(s.prep!),
        'result': s.result == null ? null : resultToJson(s.result!),
        'time': s.time,
        'grace': s.graceUntil,
        'after': s.afterLevelUp?.name,
        'seq': s.seq,
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
    );
  }

  static T? _opt<T>(Json? j, T Function(Json) f) => j == null ? null : f(j);

  // ------------------------------------------------------------------
  // Jugadores
  // ------------------------------------------------------------------

  Json playerToJson(SessionPlayer p) => {
        'id': p.id,
        'p': p.profile.toJson(),
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
      };

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
      };

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
      );

  Json dropToJson(WeaponDrop d) => {'p': d.playerId, 'w': d.weaponId};

  WeaponDrop dropFromJson(Json j) => WeaponDrop(j.str('p'), j.str('w'));

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
      );

  Json itemToJson(MissionItem i) =>
      {'id': i.id, 'k': i.kind.name, 'x': i.x, 'y': i.y, 'done': i.done};

  MissionItem itemFromJson(Json j) => MissionItem(
        id: j.integer('id'),
        kind: j.enumByName('k', MissionItemKind.values),
        x: j.dbl('x'),
        y: j.dbl('y'),
        done: j.boolean('done'),
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
      );

  Json battleStateToJson(BattleState s) => {
        'party': [for (final c in s.party) combatantToJson(c)],
        'enemies': [for (final c in s.enemies) combatantToJson(c)],
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
      };

  BattleState battleStateFromJson(Json j) {
    final out = j.objOrNull('out');
    return BattleState(
      party: [for (final raw in j.list('party')) combatantFromJson(asJson(raw))],
      enemies: [
        for (final raw in j.list('enemies')) combatantFromJson(asJson(raw)),
      ],
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
        'nt': c.nextTurn,
        'dfd': c.defending,
        'prot': c.protecting,
        'taunt': c.taunt,
        'bdef': c.bonusDefense,
        'ult': c.ult,
        'acts': c.actions,
      };

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
      nextTurn: j.dbl('nt'),
      defending: j.boolean('dfd'),
      protecting: j.boolean('prot'),
      taunt: j.integer('taunt'),
      bonusDefense: j.integer('bdef'),
      ult: j.dbl('ult'),
      actions: j.integer('acts'),
    );
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
      passiveProgress: PlayerPassiveProgress(List.unmodifiable(j.strings('tree'))),
      bonusDefense: j.integer('bdef'),
    );
  }
}
