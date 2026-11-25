import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
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
import '../helpers/battle_log_helper.dart';

// Mecánicas de los jefes nuevos de la v0.2: docs/specs/bosses.md § "v0.2".

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

/// [boss] contra [classes]; con [tough] los jugadores aguantan todo (las
/// pruebas de varios turnos no terminan por K.O.).
BattleState _start(BattleEngine e, String boss, List<String> classes, {bool tough = false}) {
  final s = e
      .start(
        party: [for (var i = 0; i < classes.length; i++) _member('p${i + 1}', classes[i])],
        enemyTypes: [boss],
      )
      .state;
  if (tough) {
    for (final p in s.party) {
      p
        ..maxHp = 99999
        ..hp = 99999;
    }
  }
  return s;
}

/// Le da el turno a [id] (sin pasar por la línea de tiempo).
/// El turno de [id] sin pasar por `nextTurn` (Pulso lleno: estas pruebas
/// no miden el Pulso, combo_balance.md § 5.2).
BattleState _turnOf(BattleState s, String id) {
  final c = s.copy()..currentId = id;
  for (final p in c.party) {
    p.pulse = BattleEngine.pulseMax;
  }
  return c;
}

Iterable<BossMechanicEvent> _mech(BattleStep s) => s.events.whereType<BossMechanicEvent>();

void main() {
  group('catálogo', () {
    test('ids, mecánicas, ULT, títulos y legendarios', () {
      for (final id in ['arana', 'lobo', 'murcielagoHielo', 'elementalEscarcha', 'esqueleto', 'caballeroCaido']) {
        final d = kEnemies[id]!;
        expect(d.boss, isFalse, reason: id);
        expect(d.breakMax, greaterThan(0), reason: id);
      }
      final legend = {'matriarca': 'susurroVibora', 'sierpe': 'inviernoPerpetuo', 'caballeroHueco': 'egidaPrimerRey'};
      final mech = {'matriarca': 'telarana', 'sierpe': 'escarcha', 'caballeroHueco': 'postura'};
      final ults = {'matriarca': 'eult_nido', 'sierpe': 'eult_aliento', 'caballeroHueco': 'eult_juicio'};
      for (final id in legend.keys) {
        final d = kEnemies[id]!;
        expect([d.boss, d.mechanicId, d.legendaryId, d.ultId], [true, mech[id], legend[id], ults[id]]);
        expect(d.title, isNotEmpty);
        expect(kEnemyUlts, contains(d.ultId));
        // Umbral en puntos (combo_balance.md § 5): jefes 65-95.
        expect(d.breakMax, inInclusiveRange(65, 95), reason: id);
      }
      expect(kEnemies['cristalHielo']!.passive, isTrue);
      expect(kEnemies['matriarca']!.theName, 'la Matriarca Araña');
      expect(kEnemies['reyLimo']!.theName, 'el Rey Limo');
    });
  });

  group('Matriarca Araña: telaraña', () {
    test('cada 3 acciones atrapa a un jugador (golpe ATQ × 0.6)', () {
      final e = _engine([0.5, 0.5, 0.5, 0.0]); // inicio ×3, objetivo: el primero
      var s = _start(e, 'matriarca', ['guerrero', 'maga']);
      s.enemies[0].actions = 2;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      final cast = _mech(st).single;
      expect([cast.phase, cast.targetId], [BossMechanicPhase.webCast, 'p1']);
      expect(st.state.byId('p1')!.webbed, isTrue);
      final act = st.events.whereType<ActionEvent>().single;
      expect([act.kind, act.targetId], [BattleActionKind.enemyAttack, 'p1']);
      expect(st.state.log, contains('Telaraña'));
      // Las otras acciones son ataques normales.
      s = st.state;
      final normal = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(normal), isEmpty);
    });

    test('co-op: el atrapado pierde su turno; un aliado lo libera con Atacar (medio turno)', () {
      final e = _engine();
      final s = _start(e, 'matriarca', ['guerrero', 'maga']);
      s.party[0].webbed = true;
      // Libera p2 atacando a p1.
      final t = _turnOf(s, 'p2');
      final clock = t.clock;
      final free = e.command(t, 'p2', const AttackCommand(targetId: 'p1'))!;
      final ev = _mech(free).single;
      expect([ev.phase, ev.actorId, ev.targetId], [BossMechanicPhase.webFreed, 'p2', 'p1']);
      expect(free.state.byId('p1')!.webbed, isFalse);
      final p2 = free.state.byId('p2')!;
      expect(p2.nextTurn, closeTo(clock + e.interval(p2) * 0.5, 1e-9));
      expect(free.state.enemies[0].hp, free.state.enemies[0].maxHp, reason: 'no daña');
      // No se puede "liberar" a quien no está atrapado ni a uno mismo.
      expect(e.command(_turnOf(free.state, 'p2'), 'p2', const AttackCommand(targetId: 'p1')), isNull);
      // Sin liberar: pierde el turno.
      final s2 = s.copy();
      s2.party[0].nextTurn = -1;
      final skip = e.nextTurn(s2);
      expect(_mech(skip).single.phase, BossMechanicPhase.webSkip);
      expect(skip.state.currentId, isNull);
      expect(skip.state.byId('p1')!.webbed, isFalse);
      expect(skip.state.log, contains('telaraña'));
    });

    test('solo: forcejea y pierde medio turno', () {
      final e = _engine();
      final s = _start(e, 'matriarca', ['guerrero']);
      s.party[0]
        ..webbed = true
        ..nextTurn = -1;
      final st = e.nextTurn(s);
      expect(_mech(st).single.phase, BossMechanicPhase.webStruggle);
      final p = st.state.party[0];
      expect(p.webbed, isFalse);
      expect(p.nextTurn, closeTo(st.state.clock + e.interval(p) * 0.5, 1e-9));
    });

    test('Nido Venenoso: a todos + 3 Veneno y, con grupo, atrapa al de más vida', () {
      final e = _engine();
      final s = _start(e, 'matriarca', ['guerrero', 'maga']);
      s.enemies[0]
        ..ultPending = true
        ..ult = 100;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      final u = st.events.whereType<EnemyUltEvent>().single;
      expect([u.ultId, u.allTargets], ['eult_nido', true]);
      final g = st.state.byId('p1')!, m = st.state.byId('p2')!;
      expect(g.stacks(StatusKind.poison), greaterThanOrEqualTo(3));
      final webbed = g.hp >= m.hp ? g : m;
      expect(webbed.webbed, isTrue);
      expect(_mech(st).single.phase, BossMechanicPhase.webCast);
    });

    test('el aviso dice "La Matriarca Araña"', () {
      final e = _engine();
      final s = _start(e, 'matriarca', ['guerrero']);
      s.enemies[0].ult = 100;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st.state.log, startsWith('¡La Matriarca Araña se prepara para Nido Venenoso!'));
    });
  });

  group('Sierpe de Escarcha: campo helado', () {
    test('2 cristales con grupo, 1 solo; los cristales no tienen turno', () {
      final e = _engine();
      final duo = _start(e, 'sierpe', ['guerrero', 'maga']);
      expect([for (final c in duo.enemies) c.enemyType], ['sierpe', 'cristalHielo', 'cristalHielo']);
      expect([for (final c in duo.enemies) c.id], ['e0', 'e1', 'e2']);
      expect(duo.enemies[1].hasBreak, isFalse);
      expect(duo.enemies[1].ultId, isNull);
      final solo = _start(e, 'sierpe', ['guerrero']);
      expect(solo.enemies, hasLength(2));
      solo.enemies[1].nextTurn = -5;
      final t = e.nextTurn(solo);
      expect(t.state.currentId, isNot('e1'));
    });

    test('cada turno de la Sierpe: −10% de velocidad (tope −50%)', () {
      final e = _engine();
      var s = _start(e, 'sierpe', ['guerrero', 'maga'], tough: true);
      final iv0 = e.interval(s.party[0]);
      for (var k = 1; k <= 6; k++) {
        s.enemies[0].ult = 0;
        final st = e.enemyTurn(_turnOf(s, 'e0'))!;
        final f = _mech(st).firstWhere((m) => m.phase == BossMechanicPhase.frost);
        expect(f.value, closeTo(k <= 5 ? 0.1 * k : 0.5, 1e-9));
        s = st.state;
      }
      final p = s.party[0];
      expect(p.effectTotal(BuffStat.speed), closeTo(-0.5, 1e-9));
      expect(e.interval(p), closeTo(iv0 * 2, 1e-6));
    });

    test('romper los cristales descongela el campo', () {
      final e = _engine();
      var s = _start(e, 'sierpe', ['guerrero', 'maga']);
      s = e.enemyTurn(_turnOf(s, 'e0'))!.state;
      s.enemies[1].hp = 1;
      s.enemies[2].hp = 1;
      var st = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand(targetId: 'e1'))!;
      expect(_mech(st).where((m) => m.phase == BossMechanicPhase.thaw), isEmpty);
      st = e.command(_turnOf(st.state, 'p1'), 'p1', const AttackCommand(targetId: 'e2'))!;
      expect(_mech(st).where((m) => m.phase == BossMechanicPhase.thaw), hasLength(1));
      for (final p in st.state.party) {
        expect(p.effectTotal(BuffStat.speed), 0);
      }
      // Sin cristales, la Sierpe ya no congela.
      final next = e.enemyTurn(_turnOf(st.state, 'e0'))!;
      expect(_mech(next).where((m) => m.phase == BossMechanicPhase.frost), isEmpty);
      expect(st.state.outcome, isNull);
    });

    test('quebrar a la Sierpe rompe un cristal', () {
      final e = _engine();
      final s = _start(e, 'sierpe', ['guerrero', 'maga']);
      s.enemies[0]
        ..breakGauge = s.enemies[0].breakMax
        ..fissured = true;
      final st = e.command(_turnOf(s, 'p1'), 'p1',
          const SkillCommand('quebrar', targetId: 'e0'))!;
      final sh = _mech(st).where((m) => m.phase == BossMechanicPhase.shatter).single;
      expect(sh.targetId, 'e1');
      expect(st.state.enemies[1].alive, isFalse);
      expect(st.state.enemies[2].alive, isTrue);
    });

    test('al caer la Sierpe caen sus cristales: victoria sin XP de cristales', () {
      final e = _engine();
      final s = _start(e, 'sierpe', ['guerrero']);
      s.enemies[0].hp = 1;
      final st = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand(targetId: 'e0'))!;
      expect(st.state.enemies.every((c) => !c.alive), isTrue);
      expect(st.state.outcome!.victory, isTrue);
      expect(st.state.outcome!.xp, kEnemies['sierpe']!.xp);
    });

    test('Aliento Glacial: a todos + 2 Congelación y rearma los cristales rotos', () {
      final e = _engine();
      final s = _start(e, 'sierpe', ['guerrero', 'maga']);
      s.enemies[1].hp = 0;
      s.enemies[0]
        ..ultPending = true
        ..ult = 100;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st.events.whereType<EnemyUltEvent>().single.ultId, 'eult_aliento');
      final r = _mech(st).where((m) => m.phase == BossMechanicPhase.reform).single;
      expect(r.targetId, 'e1');
      expect(st.state.enemies[1].hp, st.state.enemies[1].maxHp);
      expect(st.state.party[0].stacks(StatusKind.freeze), greaterThanOrEqualTo(2));
    });
  });

  group('Caballero Hueco: postura', () {
    int attackDamage(BattleEngine e, BattleState s, BattleCommand cmd) {
      final st = e.command(_turnOf(s, 'p1'), 'p1', cmd)!;
      return st.events.whereType<DamageEvent>().first.amount;
    }

    test('empieza en escudo: −70% al daño físico, nada al mágico', () {
      final e = _engine();
      final s = _start(e, 'caballeroHueco', ['guerrero', 'maga']);
      final boss = s.enemies[0];
      expect([boss.stance, boss.stanceTurns], [1, 2]);
      final atk = s.party[0].attack;
      // × 0.92: mitigación de grupo con 2 jugadores (combo_balance.md § 3.3).
      expect(attackDamage(e, s, const AttackCommand()), jsRound(atk * 0.3 * 0.92));
      final st = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand())!;
      final res = _mech(st).single;
      expect([res.phase, res.value], [BossMechanicPhase.resisted, 0.7]);
      expect(st.state.log, contains('POSTURA'));
      // Espada: el físico entra completo.
      s.enemies[0].stance = 2;
      expect(attackDamage(e, s, const AttackCommand()), jsRound(atk * 0.92));
    });

    test('solo: la postura bloquea 50%', () {
      final e = _engine();
      final s = _start(e, 'caballeroHueco', ['guerrero']);
      expect(attackDamage(e, s, const AttackCommand()), jsRound(s.party[0].attack * 0.5));
    });

    test('quebrado pierde la postura', () {
      final e = _engine();
      final s = _start(e, 'caballeroHueco', ['guerrero', 'maga']);
      s.enemies[0].vulnerable = 2;
      expect(attackDamage(e, s, const AttackCommand()),
          jsRound(s.party[0].attack * 1.5 * 0.92));
    });

    test('cambia cada 2 turnos suyos y avisa 1 antes', () {
      final e = _engine();
      var s = _start(e, 'caballeroHueco', ['guerrero'], tough: true);
      s.enemies[0].ult = -1000; // sin ULT en esta prueba
      var st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(_mech(st), isEmpty);
      expect([st.state.enemies[0].stance, st.state.enemies[0].stanceTurns], [1, 1]);
      st = e.enemyTurn(_turnOf(st.state, 'e0'))!;
      final sh = _mech(st).single;
      expect([sh.phase, sh.value], [BossMechanicPhase.stanceShift, 2]);
      expect([st.state.enemies[0].stance, st.state.enemies[0].stanceTurns], [2, 2]);
      s = st.state;
      st = e.enemyTurn(_turnOf(s, 'e0'))!;
      st = e.enemyTurn(_turnOf(st.state, 'e0'))!;
      expect(st.state.enemies[0].stance, 1);
    });

    test('Juicio Hueco: ATQ × 1.9 a uno + Aturdido y cambia de postura', () {
      final e = _engine();
      final s = _start(e, 'caballeroHueco', ['guerrero'], tough: true);
      s.enemies[0]
        ..ultPending = true
        ..ult = 100
        ..stanceTurns = 2;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      final u = st.events.whereType<EnemyUltEvent>().single;
      expect([u.ultId, u.allTargets], ['eult_juicio', false]);
      // combat.md § "Control sobre jugadores": the stun fills the break bar.
      expect(st.state.party[0].stacks(StatusKind.stun), 0);
      expect(st.state.party[0].breakGauge, greaterThan(0));
      expect(st.state.enemies[0].stance, 2);
    });
  });

  group('comunes', () {
    test('armadura del Caballero Caído (−20%) y del Elemental (−15%)', () {
      final e = _engine();
      for (final (id, k) in [('caballeroCaido', 0.8), ('elementalEscarcha', 0.85)]) {
        final s = e.start(party: [_member('p1', 'guerrero')], enemyTypes: [id]).state;
        final st = e.command(_turnOf(s, 'p1'), 'p1', const AttackCommand())!;
        expect(st.events.whereType<DamageEvent>().first.amount, jsRound(s.party[0].attack * k), reason: id);
        expect(st.state.log, contains('armadura'));
      }
    });

    test('el aturdido del Caballero Caído tiene 25%: si falla, el log no lo dice', () {
      final e = _engine([0.0, 0.99, 0.99]); // objetivo, crítico, aturdido (falla)
      final s = e.start(party: [_member('p1', 'guerrero')], enemyTypes: ['caballeroCaido']).state;
      final st = e.enemyTurn(_turnOf(s, 'e0'))!;
      expect(st.state.party[0].stacks(StatusKind.stun), 0);
      expect(st.state.log, isNot(contains('Aturdido')));
    });
  });

  group('red', () {
    test('Combatant serializa telaraña y postura (opcionales)', () {
      const json = SessionJson();
      final c = Combatant(
          id: 'p1', name: 'X', isPlayer: true, hp: 1, maxHp: 1, speed: 1, attack: 1, critChance: 0,
          webbed: true, stance: 2, stanceTurns: 1);
      final back = json.combatantFromJson(asJson(jsonDecode(jsonEncode(json.combatantToJson(c)))));
      expect([back.webbed, back.stance, back.stanceTurns], [true, 2, 1]);
      final plain = Combatant(id: 'p', name: 'Y', isPlayer: true, hp: 1, maxHp: 1, speed: 1, attack: 1, critChance: 0);
      final raw = json.combatantToJson(plain);
      expect(raw.containsKey('web') || raw.containsKey('stc'), isFalse);
      final b2 = json.combatantFromJson(raw);
      expect([b2.webbed, b2.stance], [false, 0]);
    });

    test('BossMechanicEvent ida y vuelta', () {
      const ej = EventJson();
      for (final ev in const [
        BossMechanicEvent('e0', BossMechanicPhase.webCast, targetId: 'p1'),
        BossMechanicEvent('e0', BossMechanicPhase.frost, value: 0.3),
        BossMechanicEvent('e0', BossMechanicPhase.stanceShift, value: 2),
        BossMechanicEvent('e0', BossMechanicPhase.thaw),
      ]) {
        final back = ej.battleFromJson(asJson(jsonDecode(jsonEncode(ej.battleToJson(ev))))) as BossMechanicEvent;
        expect([back.actorId, back.phase, back.targetId, back.value], [ev.actorId, ev.phase, ev.targetId, ev.value]);
      }
    });

    test('determinista: misma semilla, mismos eventos', () {
      List<String> run() {
        var i = 0;
        final rolls = [0.3, 0.7, 0.1, 0.9, 0.5, 0.2, 0.8, 0.4];
        final e = BattleEngine(stats: _stats, random: () => rolls[i++ % rolls.length]);
        var s = _start(e, 'matriarca', ['guerrero', 'maga']);
        final out = <String>[];
        for (var k = 0; k < 30 && !s.ended; k++) {
          final t = e.nextTurn(s);
          s = t.state;
          out.add(s.log);
          final cur = s.current;
          if (cur == null) continue;
          final st = cur.isPlayer ? e.command(s, cur.id, const AttackCommand())! : e.enemyTurn(s)!;
          s = st.state;
          out.add(s.log);
        }
        return out;
      }

      expect(run(), run());
    });
  });

  test('las ULT nuevas usan su efecto extra', () {
    expect(kEnemyUlts['eult_nido']!.extra, EnemyUltExtra.web);
    expect(kEnemyUlts['eult_aliento']!.extra, EnemyUltExtra.reformCrystals);
    expect(kEnemyUlts['eult_juicio']!.extra, EnemyUltExtra.stanceShift);
  });
}
