import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/enemy_def.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/js_math.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

// Jefes y comunes de la v0.3 (zonas 6–10): docs/specs/bosses.md § "v0.3".

const _startNodes = PassiveTreeCatalog(
  nodes: {
    's_gue': PassiveNode(id: 's_gue', x: 0, y: -1.1, name: 'Inicio: Guerrero', kind: 'st', effects: {}, links: []),
    's_mag': PassiveNode(id: 's_mag', x: 1.1, y: 0, name: 'Inicio: Maga', kind: 'st', effects: {}, links: []),
    's_tir': PassiveNode(id: 's_tir', x: 0, y: 1.1, name: 'Inicio: Tirador', kind: 'st', effects: {}, links: []),
    's_pal': PassiveNode(id: 's_pal', x: -1.1, y: 0, name: 'Inicio: Paladín', kind: 'st', effects: {}, links: []),
  },
  startNodeByClass: {'guerrero': 's_gue', 'maga': 's_mag', 'tirador': 's_tir', 'paladin': 's_pal'},
  exclusions: {},
);

const _stats = StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(_startNodes));

/// Azar con valores fijos; cuando se acaban, 0.99 (nunca crítico).
BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(stats: _stats, random: () => i < rolls.length ? rolls[i++] : 0.99);
}

BattlePartyMember _member(String id, String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: '${cls.name} $id',
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

/// [types] contra [classes]; los jugadores aguantan todo (vida enorme).
BattleState _start(BattleEngine e, List<String> types, List<String> classes) {
  final s = e
      .start(
        party: [for (var i = 0; i < classes.length; i++) _member('p${i + 1}', classes[i])],
        enemyTypes: types,
      )
      .state;
  for (final p in s.party) {
    p
      ..maxHp = 99999
      ..hp = 99999
      ..mp = 99;
  }
  return s;
}

/// El turno de [id] sin pasar por `nextTurn` (Pulso lleno: estas pruebas
/// no miden el Pulso, combo_balance.md § 5.2).
BattleState _turnOf(BattleState s, String id) {
  final c = s.copy()..currentId = id;
  for (final p in c.party) {
    p.pulse = BattleEngine.pulseMax;
  }
  return c;
}

Iterable<BossMechanicEvent> _mech(BattleStep s, [BossMechanicPhase? ph]) =>
    s.events.whereType<BossMechanicEvent>().where((e) => ph == null || e.phase == ph);

int _dmgTo(BattleStep s, String id) =>
    s.events.whereType<DamageEvent>().where((d) => d.targetId == id).fold(0, (a, d) => a + d.amount);

void main() {
  group('catálogo v0.3', () {
    const commons = {
      'ecoSombra': 26, 'guardianReloj': 26, 'salamandra': 31, 'golemMagma': 31, 'necrofago': 36,
      'almaErrante': 36, 'vigilanteVacio': 41, 'ojoAbismo': 41, 'heraldoEras': 46, 'fragmentoTiempo': 46,
    };
    const bosses = {
      'hechicera': ('ecos', 'eult_coro', 'truenoBronce'),
      'bestiaMagma': ('lava', 'eult_erupcion', 'fauceVolcan'),
      'espectroCoronado': ('sequito', 'eult_lamento', 'primaveraRota'),
      'centinela': ('marca', 'eult_colapsoVacio', 'rompemundos'),
      'devorador': ('fases', 'eult_finEras', 'segadoraEras'),
    };

    test('comunes: quiebre 12 puntos, sin mecánica de jefe', () {
      for (final id in commons.keys) {
        final d = kEnemies[id]!;
        expect(d.boss, isFalse, reason: id);
        expect(d.breakMax, 12, reason: id);
        expect(d.mechanicId, isNull, reason: id);
      }
      // Los comunes suben con la zona.
      expect(kEnemies['heraldoEras']!.attack, greaterThan(kEnemies['ecoSombra']!.attack));
    });

    test('jefes: mecánica, ULT, título, legendario y quiebre 65-95 puntos', () {
      for (final e in bosses.entries) {
        final d = kEnemies[e.key]!;
        final (mech, ult, legend) = e.value;
        expect([d.boss, d.mechanicId, d.ultId, d.legendaryId], [true, mech, ult, legend], reason: e.key);
        expect(d.title, isNotEmpty);
        expect(kBossMechanics[mech]!.counter, isNotEmpty);
        expect(kEnemyUlts, contains(ult));
        expect(kUniques, contains(legend), reason: legend);
        expect(d.breakMax, inInclusiveRange(65, 95), reason: e.key);
      }
      // Escalón de jefe a jefe.
      final hp = [for (final id in bosses.keys) kEnemies[id]!.hp];
      final atk = [for (final id in bosses.keys) kEnemies[id]!.attack];
      for (var i = 1; i < hp.length; i++) {
        expect(hp[i], greaterThan(hp[i - 1]));
        expect(atk[i], greaterThan(atk[i - 1]));
      }
      expect(kEnemies['caballeroHueco']!.hp, lessThan(hp.first));
      expect(kEnemies['hechicera']!.theName, 'la Hechicera del Eco');
    });

    test('invocaciones: actúan, sin XP ni quiebre', () {
      for (final id in ['ecoHechicera', 'siervoEspectral']) {
        final d = kEnemies[id]!;
        expect([d.passive, d.xp, d.credits, d.breakMax, d.ultId], [false, 0, 0, 0, null], reason: id);
      }
      expect(kBossMechanics['ecos']!.addType, 'ecoHechicera');
      expect(kBossMechanics['sequito']!.addType, 'siervoEspectral');
    });

    test('ULT nuevas con su efecto extra', () {
      expect(kEnemyUlts['eult_coro']!.extra, EnemyUltExtra.echoChorus);
      expect(kEnemyUlts['eult_erupcion']!.extra, EnemyUltExtra.lavaFlood);
      expect(kEnemyUlts['eult_lamento']!.extra, EnemyUltExtra.summonAll);
      expect(kEnemyUlts['eult_colapsoVacio']!.extra, EnemyUltExtra.voidMark);
      for (final id in ['eult_coro', 'eult_erupcion', 'eult_lamento', 'eult_colapsoVacio']) {
        expect(kEnemyUlts[id]!.allTargets, isTrue, reason: id);
      }
    });
  });

  group('Hechicera del Eco: ecos', () {
    test('2 ecos con grupo, 1 solo; actúan (tienen turno) y caen con ella', () {
      final e = _engine();
      final duo = _start(e, ['hechicera'], ['guerrero', 'maga']);
      expect(duo.enemies.map((c) => c.enemyType), ['hechicera', 'ecoHechicera', 'ecoHechicera']);
      for (final c in duo.enemies.skip(1)) {
        expect(c.nextTurn, greaterThan(0));
        expect(c.hasBreak, isFalse);
        expect(c.ultId, isNull);
      }
      final solo = _start(_engine(), ['hechicera'], ['guerrero']);
      expect(solo.enemies.where((c) => c.enemyType == 'ecoHechicera'), hasLength(1));
      // Un eco actúa.
      final st = e.enemyTurn(_turnOf(duo, 'e1'))!;
      expect(st.events.whereType<ActionEvent>().single.actorId, 'e1');
      // Al caer la Hechicera caen los ecos: victoria sin XP extra.
      final s = duo.copy();
      s.enemies[0].hp = 1;
      final end = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand(targetId: 'e0'))!;
      expect(end.state.enemies.every((c) => !c.alive), isTrue);
      expect(end.state.outcome?.xp, kEnemies['hechicera']!.xp);
    });

    test('los ecos reciben ×0.5 (evento una vez); la real, daño completo', () {
      final e = _engine();
      final s = _start(e, ['hechicera'], ['guerrero', 'maga']);
      final real = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand(targetId: 'e0'))!;
      final echo = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand(targetId: 'e1'))!;
      final full = _dmgTo(real, 'e0');
      // Los dos con la mitigación de grupo (2 jugadores, × 0.92).
      expect(full, jsRound(s.party[0].attack * 0.92));
      expect(_dmgTo(echo, 'e1'), jsRound(s.party[0].attack * 0.5 * 0.92));
      expect(_mech(real), isEmpty);
      final res = _mech(echo, BossMechanicPhase.echoResist).single;
      expect([res.actorId, res.value], ['e1', 0.5]);
      expect(echo.state.log, contains('× 0.5 ECO'));
    });

    test('quebrarla disipa un eco', () {
      final e = _engine();
      final s = _start(e, ['hechicera'], ['guerrero', 'maga']);
      s.enemies[0]
        ..breakGauge = s.enemies[0].breakMax
        ..fissured = true;
      final st = e.command(_turnOf(s, 'p1'), 'p1',
          const SkillCommand('quebrar', targetId: 'e0'))!;
      final sh = _mech(st, BossMechanicPhase.shatter).single;
      expect(st.state.byId(sh.targetId!)!.alive, isFalse);
      expect(st.state.log, contains('disipa'));
    });

    test('3 turnos suyos con ecos caídos: los vuelve a crear', () {
      final e = _engine();
      var s = _start(e, ['hechicera'], ['guerrero', 'maga']);
      s.enemies[1].hp = 0;
      s.enemies[2].hp = 0;
      for (var k = 1; k <= 2; k++) {
        final st = e.enemyTurn(_turnOf(s, 'e0'))!;
        expect(_mech(st, BossMechanicPhase.echoSummon), isEmpty, reason: 'turno $k');
        s = st.state;
        expect(s.enemies[0].mechTurns, k);
      }
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      final back = _mech(st, BossMechanicPhase.echoSummon).map((m) => m.targetId).toList();
      expect(back, ['e1', 'e2']);
      for (final id in back) {
        final c = st.state.byId(id!)!;
        expect(c.hp, c.maxHp);
        expect(c.nextTurn, greaterThan(st.state.clock));
      }
      expect(st.state.enemies[0].mechTurns, 0);
    });

    test('Coro de Ecos: ATQ × (1 + 0.3 por eco vivo) a todos, retrasa y rehace los ecos', () {
      final e = _engine();
      final s = _turnOf(_start(e, ['hechicera'], ['guerrero', 'maga']), 'e0');
      s.enemies[0].ultPending = true;
      s.enemies[2].hp = 0; // queda 1 eco vivo
      final st = e.enemyTurn(s)!;
      expect((st.events.first as EnemyUltEvent).name, 'Coro de Ecos');
      expect(st.state.log, contains('× 1.3'));
      expect(st.events.whereType<DelayedEvent>(), hasLength(2));
      expect(_mech(st, BossMechanicPhase.echoSummon).single.targetId, 'e2');
      expect(st.state.byId('e2')!.alive, isTrue);
    });

    test('un jugador que entra tarde: aparece un eco nuevo escalado como la jefa', () {
      final e = _engine();
      final s = _start(e, ['hechicera'], ['guerrero']);
      // Ya son 2 jugadores, pero hay 1 eco.
      final s2 = e.join(s, _member('p2', 'maga')).state;
      final boss = s2.enemies[0]..ultPending = true;
      final st = e.enemyTurn(_turnOf(s2, boss.id))!;
      final added = _mech(st, BossMechanicPhase.echoSummon).single;
      expect(added.targetId, 'e2');
      final c = st.state.byId('e2')!;
      final ratio = boss.maxHp / kEnemies['hechicera']!.hp;
      expect(c.maxHp, jsRound(kEnemies['ecoHechicera']!.hp * ratio));
    });
  });

  group('Bestia de Magma: lava', () {
    test('cada 3 acciones, después de atacar, sube la lava 2 turnos', () {
      final e = _engine();
      final s = _start(e, ['bestiaMagma'], ['guerrero', 'maga']);
      s.enemies[0].actions = 2;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st.events.whereType<ActionEvent>(), hasLength(1));
      final rise = _mech(st, BossMechanicPhase.lavaRise).single;
      expect(rise.value, 2);
      expect(st.state.enemies[0].lava, 2);
      // Después de la acción (el golpe va antes).
      expect(st.events.indexOf(rise), greaterThan(st.events.indexWhere((x) => x is ActionEvent)));
    });

    test('con lava quema a los que se defienden (ATQ × 0.4, Defender no lo reduce) + 2 Quemadura', () {
      final e = _engine();
      final s = _start(e, ['bestiaMagma'], ['guerrero', 'maga']);
      final boss = s.enemies[0]..lava = 2;
      s.party[0].defending = true;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      final burns = _mech(st, BossMechanicPhase.lavaBurn).toList();
      expect(burns.map((b) => b.targetId), ['p1']);
      expect(burns.single.value, 2);
      final p1 = st.state.byId('p1')!;
      final lava = jsRound(boss.attack * 0.4 * (1 - p1.defensePercent));
      // La primera DamageEvent a p1 es la de la lava.
      expect(st.events.whereType<DamageEvent>().firstWhere((d) => d.targetId == 'p1').amount, lava);
      expect(p1.stacks(StatusKind.burn), greaterThanOrEqualTo(2));
      expect(st.state.enemies[0].lava, 1);
      expect(st.state.log, contains('Charcos de Lava'));
    });

    test('se enfría al terminar; sin defensores no quema', () {
      final e = _engine();
      final s = _start(e, ['bestiaMagma'], ['guerrero', 'maga']);
      s.enemies[0].lava = 1;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(st, BossMechanicPhase.lavaBurn), isEmpty);
      expect(_mech(st, BossMechanicPhase.lavaFade), hasLength(1));
      expect(st.state.enemies[0].lava, 0);
    });

    test('solo: ATQ × 0.25 + 1 Quemadura', () {
      final e = _engine();
      final s = _start(e, ['bestiaMagma'], ['guerrero']);
      final boss = s.enemies[0]..lava = 2;
      s.party[0].defending = true;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(st, BossMechanicPhase.lavaBurn).single.value, 1);
      final p1 = st.state.byId('p1')!;
      expect(st.events.whereType<DamageEvent>().first.amount, jsRound(boss.attack * 0.25 * (1 - p1.defensePercent)));
    });

    test('Erupción Total: a todos + 2 Quemadura y la lava sube 3 turnos', () {
      final e = _engine();
      final s = _turnOf(_start(e, ['bestiaMagma'], ['guerrero', 'maga']), 'e0');
      s.enemies[0].ultPending = true;
      final st = e.enemyTurn(s)!;
      expect((st.events.first as EnemyUltEvent).name, 'Erupción Total');
      expect(_mech(st, BossMechanicPhase.lavaRise).single.value, 3);
      expect(st.state.enemies[0].lava, 3);
      for (final p in st.state.party) {
        expect(p.stacks(StatusKind.burn), 2);
      }
    });
  });

  group('Espectro Coronado: séquito', () {
    test('2 siervos con grupo, 1 solo; con séquito vivo es inmune a los estados', () {
      final e = _engine();
      final s = _start(e, ['espectroCoronado'], ['maga', 'guerrero']);
      expect(s.enemies.where((c) => c.enemyType == 'siervoEspectral'), hasLength(2));
      expect(_start(_engine(), ['espectroCoronado'], ['maga']).enemies, hasLength(2));
      final st = e.command(_turnOf(s, 'p1'), 'p1', const SkillCommand('chispa', targetId: 'e0'))!;
      expect(st.state.enemies[0].stacks(StatusKind.burn), 0);
      expect(_mech(st, BossMechanicPhase.immune).single.actorId, 'e0');
      expect(st.state.log, contains('INMUNE'));
      // A los siervos sí les entran.
      final st2 = e.command(_turnOf(s, 'p1'), 'p1', const SkillCommand('chispa', targetId: 'e1'))!;
      expect(st2.state.byId('e1')!.stacks(StatusKind.burn), 1);
    });

    test('sin siervos vivos los estados entran', () {
      final e = _engine();
      final s = _start(e, ['espectroCoronado'], ['maga', 'guerrero']);
      s.enemies[1].hp = 0;
      s.enemies[2].hp = 0;
      final st = e.command(_turnOf(s, 'p1'), 'p1', const SkillCommand('chispa', targetId: 'e0'))!;
      expect(st.state.enemies[0].stacks(StatusKind.burn), 1);
      expect(_mech(st, BossMechanicPhase.immune), isEmpty);
    });

    test('a los 3 turnos con el séquito incompleto lo completa; Lamento Eterno también', () {
      final e = _engine();
      var s = _start(e, ['espectroCoronado'], ['maga', 'guerrero']);
      s.enemies[2].hp = 0;
      for (var k = 0; k < 2; k++) {
        s = e.enemyTurn(_turnOf(s, 'e0'))!.state;
      }
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(st, BossMechanicPhase.summon).single.targetId, 'e2');
      final u = _turnOf(st.state, 'e0');
      u.enemies[1].hp = 0;
      u.enemies[0].ultPending = true;
      final ult = e.enemyTurn(u)!;
      expect((ult.events.first as EnemyUltEvent).name, 'Lamento Eterno');
      expect(_mech(ult, BossMechanicPhase.summon).single.targetId, 'e1');
      for (final p in ult.state.party) {
        expect(p.stacks(StatusKind.freeze), greaterThanOrEqualTo(2));
      }
    });
  });

  group('Centinela del Vacío: marca', () {
    test('a la 3.ª acción marca (sin atacar); la siguiente pega ×2 al marcado aunque haya provocador', () {
      final e = _engine([0.5, 0.5, 0.5, 0.0]); // inicio ×3; marca al primero
      final s = _start(e, ['centinela'], ['guerrero', 'maga']);
      s.enemies[0].actions = 2;
      final mark = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(mark.events.whereType<ActionEvent>(), isEmpty);
      expect(_mech(mark, BossMechanicPhase.markCast).single.targetId, 'p1');
      expect(mark.state.byId('p1')!.voidMarked, isTrue);
      final t = _turnOf(mark.state, 'e0');
      t.party[1].taunt = 2;
      final hit = e.enemyTurn(t)!;
      final act = hit.events.whereType<ActionEvent>().single;
      expect([act.kind, act.targetId], [BattleActionKind.enemyHeavy, 'p1']);
      expect(_mech(hit, BossMechanicPhase.markHit).single.value, 2);
      final p1 = hit.state.byId('p1')!;
      final atk = hit.state.enemies[0].attack;
      expect(_dmgTo(hit, 'p1'), jsRound(atk * 2 * kClasses['guerrero']!.pierceWeakness * (1 - p1.defensePercent)));
      expect(p1.voidMarked, isFalse);
      expect(hit.state.byId('p2')!.taunt, 2, reason: 'la marca ignora la provocación');
    });

    test('co-op: si otro lo Protege, el protector recibe un golpe normal y la marca se disipa', () {
      final e = _engine();
      final s = _start(e, ['centinela'], ['guerrero', 'paladin']);
      s.party[0].voidMarked = true;
      s.party[1].protecting = true;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      final g = _mech(st, BossMechanicPhase.markGuarded).single;
      expect([g.actorId, g.targetId], ['p2', 'p1']);
      expect(_mech(st, BossMechanicPhase.markHit), isEmpty);
      expect(_dmgTo(st, 'p1'), 0);
      expect(_dmgTo(st, 'p2'), greaterThan(0));
      expect(st.state.byId('p1')!.voidMarked, isFalse);
      // Defender no alcanza con grupo.
      final s2 = _start(_engine(), ['centinela'], ['guerrero', 'paladin']);
      s2.party[0]
        ..voidMarked = true
        ..defending = true;
      final st2 = _engine().enemyTurn(_turnOf(s2, 'e0'))!;
      expect(_mech(st2, BossMechanicPhase.markHit), hasLength(1));
    });

    test('solo: Defender contrarresta la marca; sin defender, ×2', () {
      final e = _engine();
      final s = _start(e, ['centinela'], ['guerrero']);
      s.party[0]
        ..voidMarked = true
        ..defending = true;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      final g = _mech(st, BossMechanicPhase.markGuarded).single;
      expect([g.actorId, g.targetId], ['p1', 'p1']);
      final s2 = _start(_engine(), ['centinela'], ['guerrero']);
      s2.party[0].voidMarked = true;
      final st2 = _engine().enemyTurn(_turnOf(s2, 'e0'))!;
      expect(_mech(st2, BossMechanicPhase.markHit).single.value, 2);
    });

    test('Colapso del Vacío: el marcado sin proteger recibe ×2; después marca al de más vida', () {
      final e = _engine();
      final s = _turnOf(_start(e, ['centinela'], ['guerrero', 'maga']), 'e0');
      s.enemies[0].ultPending = true;
      s.party[0].voidMarked = true;
      s.party[1].hp = 99998; // p1 queda con más vida después del golpe
      final st = e.enemyTurn(s)!;
      expect((st.events.first as EnemyUltEvent).name, 'Colapso del Vacío');
      expect(_mech(st, BossMechanicPhase.markHit).single.targetId, 'p1');
      final cast = _mech(st, BossMechanicPhase.markCast).single;
      final marked = st.state.party.where((p) => p.voidMarked).single;
      expect(cast.targetId, marked.id);
      expect(marked.hp, st.state.party.map((p) => p.hp).reduce((a, b) => a > b ? a : b));
      expect(_dmgTo(st, 'p1'), greaterThan(_dmgTo(st, 'p2')));
    });

    test('si el marcado cae, la marca se pierde', () {
      final e = _engine();
      final s = _start(e, ['centinela'], ['guerrero', 'maga']);
      s.party[0]
        ..voidMarked = true
        ..hp = 1;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st.state.byId('p1')!.alive, isFalse);
      expect(st.state.byId('p1')!.voidMarked, isFalse);
    });
  });

  group('Devorador de Eras: 2 fases', () {
    test('fase 1: Colapso Temporal cada 3 acciones', () {
      final e = _engine();
      final s = _start(e, ['devorador'], ['guerrero', 'maga']);
      s.enemies[0].actions = 2;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st.events.whereType<ActionEvent>().single.kind, BattleActionKind.enemyArea);
      s.enemies[0].actions = 1;
      final st2 = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st2.events.whereType<ActionEvent>().single.kind, BattleActionKind.enemyAttack);
    });

    test('al 50%: el golpe se queda en la mitad, se transforma (estados fuera, ATQ ×1.15, acciones a 0)', () {
      final e = _engine();
      final s = _start(e, ['devorador'], ['guerrero', 'maga']);
      final boss = s.enemies[0]
        ..hp = jsRound(s.enemies[0].maxHp * 0.5) + 2
        ..actions = 5
        ..breakGauge = 50
        ..statuses = {StatusKind.burn: 3};
      final atk0 = boss.attack;
      final st = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand(targetId: 'e0'))!;
      final b = st.state.enemies[0];
      expect(b.hp, (b.maxHp * 0.5).ceil());
      expect(b.phase, 2);
      expect(b.attack, jsRound(atk0 * 1.15));
      expect(b.actions, 0);
      expect(b.stacks(StatusKind.burn), 0);
      expect(b.breakGauge, 0);
      final ph = _mech(st, BossMechanicPhase.phaseShift).single;
      expect(ph.value, 2);
      // Después del golpe.
      expect(st.events.indexOf(ph), greaterThan(st.events.indexWhere((x) => x is DamageEvent)));
      expect(st.state.log, contains('FASE 2'));
      // Solo una vez.
      final again = e.command(_turnOf(st.state, 'p1'), 'p1', const AttackCommand(targetId: 'e0'))!;
      expect(_mech(again, BossMechanicPhase.phaseShift), isEmpty);
      expect(again.state.enemies[0].hp, lessThan(b.hp));
    });

    test('un golpe enorme en fase 1 no lo mata: se queda en la mitad', () {
      final e = _engine();
      final s = _start(e, ['devorador'], ['guerrero']);
      s.enemies[0].hp = 10;
      final st = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand(targetId: 'e0'))!;
      expect(st.state.enemies[0].alive, isTrue);
      expect(st.state.enemies[0].phase, 2);
      expect(st.state.ended, isFalse);
    });

    test('fase 2: Colapso Temporal cada 2 acciones', () {
      final e = _engine();
      final s = _start(e, ['devorador'], ['guerrero', 'maga']);
      s.enemies[0]
        ..phase = 2
        ..actions = 1;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st.events.whereType<ActionEvent>().single.kind, BattleActionKind.enemyArea);
      final st2 = e.enemyTurn(_turnOf(st.state, 'e0'))!;
      expect(st2.events.whereType<ActionEvent>().single.kind, BattleActionKind.enemyAttack);
      final st3 = e.enemyTurn(_turnOf(st2.state, 'e0'))!;
      expect(st3.events.whereType<ActionEvent>().single.kind, BattleActionKind.enemyArea);
    });

    test('estados que lo bajan del 50% también lo transforman', () {
      final e = _engine();
      final s = _start(e, ['devorador'], ['guerrero']);
      final boss = s.enemies[0]
        ..hp = jsRound(s.enemies[0].maxHp * 0.5) + 1
        ..statuses = {StatusKind.poison: 5};
      boss.nextTurn = 0;
      for (final p in s.party) {
        p.nextTurn = 999;
      }
      final st = e.nextTurn(s);
      expect(st.state.enemies[0].phase, 2);
      expect(_mech(st, BossMechanicPhase.phaseShift), hasLength(1));
    });
  });

  group('comunes v0.3', () {
    test('Eco Sombrío esquiva: el golpe solo lo roza (×0.3)', () {
      final e = _engine([0.5, 0.5, 0.0]); // inicio ×2; tirada de esquiva
      final s = _start(e, ['ecoSombra'], ['guerrero']);
      final st = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand(targetId: 'e0'))!;
      expect(_mech(st, BossMechanicPhase.evaded).single.actorId, 'e0');
      expect(st.state.log, contains('ESQUIVA'));
      final st2 = _engine().command(_turnOf(_start(_engine(), ['ecoSombra'], ['guerrero']), 'p1'), 'p1',
          const AttackCommand(targetId: 'e0'))!;
      expect(_mech(st2), isEmpty);
      expect(_dmgTo(st, 'e0'), jsRound(_dmgTo(st2, 'e0') * 0.3));
    });

    test('Guardián del Reloj y Fragmento retrasan al golpeado', () {
      for (final id in ['guardianReloj', 'fragmentoTiempo']) {
        final e = _engine();
        final s = _start(e, [id], ['guerrero']);
        final before = s.party[0].nextTurn;
        final st = e.enemyTurn(_turnOf(s, 'e0'))!;
        expect(st.events.whereType<DelayedEvent>().single.targetId, 'p1', reason: id);
        expect(st.state.party[0].nextTurn, greaterThan(before));
      }
    });

    test('Vigilante: marca +20% de daño recibido 2 turnos y el siguiente golpe lo usa', () {
      final e = _engine();
      final s = _start(e, ['vigilanteVacio'], ['guerrero']);
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      final buff = st.events.whereType<BuffAppliedEvent>().single;
      expect([buff.sourceId, buff.stat, buff.value, buff.turns], ['vigilancia', BuffStat.damageTaken, 0.2, 2]);
      final first = _dmgTo(st, 'p1');
      final st2 = e.enemyTurn(_turnOf(st.state, 'e0'))!;
      expect(_dmgTo(st2, 'p1'), jsRound(first * 1.2));
      expect(st2.state.log, contains('marca'));
    });

    test('Heraldo: estados en ciclo y ULT propia sin ser élite', () {
      final e = _engine();
      final s = _start(e, ['heraldoEras'], ['guerrero']);
      expect(s.enemies[0].ultId, kEliteUltId);
      expect(s.enemies[0].ult, BattleEngine.enemyUltStart);
      var cur = s;
      final kinds = <StatusKind>[];
      for (var k = 0; k < 3; k++) {
        final st = e.enemyTurn(_turnOf(cur, 'e0'))!;
        kinds.add(st.events.whereType<StatusAppliedEvent>().single.kind);
        cur = st.state..enemies[0].ult = 0;
      }
      expect(kinds, [StatusKind.burn, StatusKind.poison, StatusKind.freeze]);
    });
  });

  group('red', () {
    test('Combatant serializa lava, marca, fase y turnos sin invocaciones (opcionales)', () {
      const json = SessionJson();
      final c = Combatant(
          id: 'e0', name: 'X', isPlayer: false, hp: 1, maxHp: 1, speed: 1, attack: 1, critChance: 0,
          lava: 2, voidMarked: true, phase: 2, mechTurns: 1);
      final back = json.combatantFromJson(asJson(jsonDecode(jsonEncode(json.combatantToJson(c)))));
      expect([back.lava, back.voidMarked, back.phase, back.mechTurns], [2, true, 2, 1]);
      final plain = Combatant(id: 'p', name: 'Y', isPlayer: true, hp: 1, maxHp: 1, speed: 1, attack: 1, critChance: 0);
      final raw = json.combatantToJson(plain);
      expect(raw.keys.toSet().intersection({'lava', 'vmk', 'phase', 'mchN'}), isEmpty);
      final b2 = json.combatantFromJson(raw);
      expect([b2.lava, b2.voidMarked, b2.phase, b2.mechTurns], [0, false, 0, 0]);
    });

    test('las fases nuevas de BossMechanicEvent van y vuelven', () {
      const ej = EventJson();
      for (final ph in [
        BossMechanicPhase.echoSummon, BossMechanicPhase.echoResist, BossMechanicPhase.lavaRise,
        BossMechanicPhase.lavaBurn, BossMechanicPhase.lavaFade, BossMechanicPhase.summon,
        BossMechanicPhase.immune, BossMechanicPhase.markCast, BossMechanicPhase.markHit,
        BossMechanicPhase.markGuarded, BossMechanicPhase.phaseShift, BossMechanicPhase.evaded,
      ]) {
        final ev = BossMechanicEvent('e0', ph, targetId: 'p1', value: 2);
        final back = ej.battleFromJson(asJson(jsonDecode(jsonEncode(ej.battleToJson(ev))))) as BossMechanicEvent;
        expect([back.phase, back.targetId, back.value], [ph, 'p1', 2.0]);
      }
    });

    test('estado de batalla con invocaciones nuevas va y vuelve por la red', () {
      final e = _engine();
      final s = _start(e, ['espectroCoronado'], ['maga', 'guerrero']);
      s.enemies[0].mechTurns = 2;
      const json = SessionJson();
      final back = [
        for (final c in s.enemies)
          json.combatantFromJson(asJson(jsonDecode(jsonEncode(json.combatantToJson(c))))),
      ];
      expect(back.map((c) => c.enemyType), s.enemies.map((c) => c.enemyType));
      expect(back[1].inflicts?.kind, StatusKind.freeze);
      expect(back[0].mechTurns, 2);
    });

    test('determinista: cada jefe nuevo, misma semilla, mismos eventos', () {
      for (final boss in ['hechicera', 'bestiaMagma', 'espectroCoronado', 'centinela', 'devorador']) {
        List<String> run() {
          var i = 0;
          final rolls = [0.3, 0.7, 0.1, 0.9, 0.5, 0.2, 0.8, 0.4];
          final e = BattleEngine(stats: _stats, random: () => rolls[i++ % rolls.length]);
          var s = _start(e, [boss], ['guerrero', 'paladin']);
          final out = <String>[];
          for (var k = 0; k < 40 && !s.ended; k++) {
            s = e.nextTurn(s).state;
            final cur = s.current;
            if (cur == null) continue;
            final st = cur.isPlayer
                ? (k % 3 == 0 ? e.command(s, cur.id, const DefendCommand()) : e.command(s, cur.id, const AttackCommand()))!
                : e.enemyTurn(s)!;
            s = st.state;
            out.add(s.log);
          }
          return out;
        }

        expect(run(), run(), reason: boss);
      }
    });
  });
}
