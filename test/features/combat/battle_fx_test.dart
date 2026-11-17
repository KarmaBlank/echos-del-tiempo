import 'dart:math' as math;

import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

BattlePartyMember _member(String id, String classId,
    {String? weapon, double ult = 0, int? hp}) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: cls.name,
    ult: ult,
    hp: hp,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[weapon ?? cls.startWeaponId]!,
    ),
  );
}

BattleEngine _engine(List<double> rolls) {
  var i = 0;
  return BattleEngine(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
    random: () => i < rolls.length ? rolls[i++] : 0.99,
  );
}

/// Posiciones fijas y fáciles de leer: x = 100·índice, y = 200.
Offset Function(String) _positions(BattleState s) {
  final ids = [...s.party.map((p) => p.id), ...s.enemies.map((e) => e.id)];
  return (id) => Offset(100.0 * ids.indexOf(id), 200);
}

Iterable<BattleFx> _of(List<BattleFx> fx, FxKind k) => fx.where((f) => f.kind == k);

void main() {
  test('ataque crítico cuerpo a cuerpo: lanza, número grande, texto y tajo', () {
    final engine = _engine([0.5, 0.0]); // azar del golem, crítico
    final start = engine.start(
        party: [_member('p1', 'guerrero')],
        enemyTypes: ['golem'],
        triggeredBy: 'p1');
    final turn = engine.nextTurn(start.state).state;
    final step = engine.command(turn, 'p1', const AttackCommand())!;
    final fx = mapBattleEvents(step.events, step.state, _positions(step.state));

    final act = _of(fx, FxKind.act).single;
    expect(act.who, 'p1');
    expect(_of(fx, FxKind.proj), isEmpty);

    final dmg = step.events.whereType<DamageEvent>().single;
    expect(dmg.critical, isTrue);
    final num = _of(fx, FxKind.num).single;
    expect(num.text, '${dmg.amount}');
    expect(num.big, isTrue);
    expect(num.color, const Color(0xFFFFD166));
    expect(num.y, 200 - 20);
    expect(num.x, 100); // e0 es el segundo id
    expect(num.delayMs, 0);

    final txt = _of(fx, FxKind.txt).single;
    expect(txt.text, '¡CRÍTICO ×1.5!');
    expect(txt.y, 200 - 34);

    final slash = _of(fx, FxKind.slash).single;
    expect(slash.who, 'e0');
    expect(slash.y, 200 - 8);
    expect(slash.el, FxElement.phys);
  });

  test('ataque a distancia: proyectil y números retrasados 280 ms', () {
    final engine = _engine([]);
    final start = engine.start(
        party: [_member('p1', 'tirador')], enemyTypes: ['golem'], triggeredBy: 'p1');
    final step = engine.command(
        engine.nextTurn(start.state).state, 'p1', const AttackCommand())!;
    final fx = mapBattleEvents(step.events, step.state, _positions(step.state));
    final proj = _of(fx, FxKind.proj).single;
    expect(proj.x, 0);
    expect(proj.y, 200 - 10);
    expect(proj.tx, 100);
    expect(_of(fx, FxKind.num).single.delayMs, BattleFx.projMs);
    expect(_of(fx, FxKind.num).single.big, isFalse);
    expect(_of(fx, FxKind.num).single.color, fxWhite);
  });

  test('golpe que mata: poof en el enemigo', () {
    final engine = _engine([]);
    final start = engine.start(
        party: [_member('p1', 'guerrero')], enemyTypes: ['slime'], triggeredBy: 'p1');
    final turn = engine.nextTurn(start.state).state;
    turn.enemies.first.hp = 1;
    final step = engine.command(turn, 'p1', const AttackCommand())!;
    final fx = mapBattleEvents(step.events, step.state, _positions(step.state));
    final poof = _of(fx, FxKind.poof).single;
    expect(poof.x, 100);
    expect(poof.y, 200 - 6);
    // Victoria: créditos sobre el jugador.
    expect(_of(fx, FxKind.txt).map((f) => f.text), contains('+₵5'));
  });

  test('habilidad a todos: anillo del color de la habilidad', () {
    final engine = _engine([]);
    final start = engine.start(
        party: [_member('p1', 'guerrero')],
        enemyTypes: ['slime', 'bat'],
        triggeredBy: 'p1');
    final step = engine.command(
        engine.nextTurn(start.state).state, 'p1', const SkillCommand('giro'))!;
    final fx = mapBattleEvents(step.events, step.state, _positions(step.state));
    final ring = _of(fx, FxKind.ring).single;
    expect(ring.color, kSkillColors['giro']);
    expect(ring.big, isFalse);
    expect(ring.y, 200 - 8);
    expect(_of(fx, FxKind.slash).map((f) => f.who), ['e0', 'e1']);
  });

  test('ultimate: cinemática con guion y números en el impacto de cada '
      'objetivo', () {
    final engine = _engine([]);
    final start = engine.start(
        party: [_member('p1', 'maga', ult: 100)],
        enemyTypes: ['golem', 'golem'],
        triggeredBy: 'p1');
    final step = engine.command(
        engine.nextTurn(start.state).state, 'p1', const UltimateCommand())!;
    final fx = mapBattleEvents(step.events, step.state, _positions(step.state));
    final ult = _of(fx, FxKind.ult).single;
    expect(ult.ult!.name, 'Meteoro');
    expect(ult.ult!.casterName, 'Maga');
    expect(ult.el, FxElement.burn);
    expect(ult.color, const Color(0xFFFF7B29));
    expect(_of(fx, FxKind.ring), isEmpty); // la ULT no pone anillo
    expect(_of(fx, FxKind.proj), isEmpty);
    final script = kUltScripts['ult_baculo']!;
    expect(ult.ult!.script, same(script));
    expect(ult.ult!.targets, ['e0', 'e1']);
    final nums = _of(fx, FxKind.num).toList();
    expect(nums.map((n) => n.delayMs),
        [script.impactFor(0), script.impactFor(1)]);
    expect(nums.every((n) => n.heavy), isTrue);
    // Estados aplicados con el mismo retraso que el golpe.
    final st = _of(fx, FxKind.txt).where((f) => f.text!.startsWith('Q+'));
    expect(st, hasLength(2));
    expect(st.map((f) => f.delayMs),
        [script.impactFor(0), script.impactFor(1)]);
    // El lanzador se lanza al descargar.
    expect(_of(fx, FxKind.act).single.delayMs, script.buildMs);
  });

  test('enemigo crítico a un jugador: número rojo grande y hurt', () {
    final engine = _engine([0.0, 0.99, 0.0, 0.0]); // slime primero, víctima 0, crítico
    final start = engine.start(party: [_member('p1', 'guerrero')], enemyTypes: ['slime']);
    final turn = engine.nextTurn(start.state).state;
    expect(turn.currentId, 'e0');
    final step = engine.enemyTurn(turn)!;
    final fx = mapBattleEvents(step.events, step.state, _positions(step.state));
    expect(_of(fx, FxKind.act).single.who, 'e0');
    final n = _of(fx, FxKind.num).single;
    expect(n.hurt, isTrue);
    expect(n.big, isTrue);
    expect(n.color, const Color(0xFFFF4757));
    expect(n.y, 200 - 18);
    // El limo envenena: tajo con elemento veneno.
    expect(_of(fx, FxKind.slash).single.el, FxElement.poison);
  });

  test('K.O. de jugador y daño de estado', () {
    final state = BattleState(party: [
      Combatant(id: 'p1', name: 'A', isPlayer: true, hp: 0, maxHp: 10,
          speed: 5, attack: 1, critChance: 0),
    ], enemies: []);
    final fx = mapBattleEvents(const [
      DamageEvent('p1', 4, fromStatus: true, statusSource: StatusKind.burn),
      KnockedOutEvent('p1'),
    ], state, (_) => const Offset(10, 50));
    expect(_of(fx, FxKind.aura).single.el, FxElement.burn);
    expect(_of(fx, FxKind.num).single.color, const Color(0xFFFF9F43));
    expect(_of(fx, FxKind.txt).single.text, 'K.O.');
    expect(_of(fx, FxKind.txt).single.y, 50 - 28);
  });

  group('BattleSceneController', () {
    BattleState two() => BattleState(party: [
          Combatant(id: 'p1', name: 'A', isPlayer: true, hp: 10, maxHp: 10,
              speed: 5, attack: 1, critChance: 0),
        ], enemies: [
          Combatant(id: 'e0', name: 'B', isPlayer: false, hp: 10, maxHp: 10,
              speed: 5, attack: 1, critChance: 0, enemyType: 'slime'),
        ]);

    test('cada eventSeq se anima una sola vez; el primero se da por visto', () {
      final s = two();
      final layout = BattleLayout.compute(s, null);
      final c = BattleSceneController(random: math.Random(1));
      const ev = [DamageEvent('e0', 3)];
      c.sync(battleId: 1, eventSeq: 5, events: ev, state: s, layout: layout);
      expect(c.fx, isEmpty);
      c.sync(battleId: 1, eventSeq: 6, events: ev, state: s, layout: layout);
      expect(c.fx, isNotEmpty);
      final n = c.fx.length;
      c.sync(battleId: 1, eventSeq: 6, events: ev, state: s, layout: layout);
      expect(c.fx, hasLength(n));
      // Dos pasos seguidos: se superponen.
      c.sync(battleId: 1, eventSeq: 7, events: ev, state: s, layout: layout);
      expect(c.fx, hasLength(n * 2));
      // Otra batalla: limpio.
      c.sync(battleId: 2, eventSeq: 8, events: ev, state: s, layout: layout);
      expect(c.fx, isEmpty);
    });

    test('los efectos disparan partículas al empezar y caducan', () {
      final s = two();
      final layout = BattleLayout.compute(s, null);
      final c = BattleSceneController(random: math.Random(1));
      c.frame = SceneFrame(
          battle: s,
          geometry: SceneGeometry.fit(const Size(960, 684)),
          layout: layout);
      c.addEffects(const [
        BattleFx(FxKind.slash, x: 10, y: 10, who: 'e0', delayMs: 100),
        BattleFx(FxKind.num, text: '9', big: true, hurt: true),
      ]);
      c.advance(16);
      expect(c.particles.shake, 7);
      expect(c.particles.hurtFlash, 0.45);
      expect(c.flashing('e0'), isFalse); // todavía en su retraso
      c.advance(100);
      expect(c.flashing('e0'), isTrue);
      for (var i = 0; i < 100; i++) {
        c.advance(16);
      }
      expect(c.fx, isEmpty);
    });
  });
}
