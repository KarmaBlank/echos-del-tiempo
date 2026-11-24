// Defender con valor (docs/specs/battle_attack_menu.md § 6): +2 Pulso
// (+1 si defendió a mano el turno anterior), +6 de ULT al defender y +6
// al primer golpe recibido defendiendo. La defensa automática por tiempo
// agotado no se premia.

import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/companion_ai.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine() => BattleEngine(
    stats: _stats,
    random: () => 0.99,
    familiesEnabled: false,
    breakEnabled: false);

Combatant _hero({int pulse = 0, double ult = 0, bool streak = false}) =>
    Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      pulse: pulse,
      ult: ult,
      guardStreak: streak,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      classId: 'maga',
      weaponType: 'báculo',
      nextTurn: 10,
    );

Combatant _foe() => Combatant(
      id: 'e0',
      name: 'Foe',
      isPlayer: false,
      hp: 500,
      maxHp: 500,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: 'slime', // not a tank: it must hit, not defend
      nextTurn: 50,
    );

BattleState _battle(Combatant hero) =>
    BattleState(party: [hero], enemies: [_foe()], clock: 10, currentId: 'p1');

/// El enemigo actúa ahora contra el héroe.
BattleStep _foeHits(BattleState s) {
  final t = s.copy()..currentId = 'e0';
  return _engine().enemyTurn(t)!;
}

void main() {
  test('constantes del spec', () {
    expect(BattleEngine.defendPulse, 2);
    expect(BattleEngine.defendPulseRepeat, 1);
    expect(BattleEngine.defendUlt, 6);
    expect(BattleEngine.defendHitUlt, 6);
  });

  test('Defender: +2 Pulso, +6 ULT, ½ daño y queda la racha', () {
    final p = _engine()
        .command(_battle(_hero(pulse: 1)), 'p1', const DefendCommand())!
        .state
        .byId('p1')!;
    expect(p.defending, isTrue);
    expect(p.pulse, 3);
    expect(p.ult, 6);
    expect(p.guardStreak, isTrue);
    expect(p.guardHitPending, isTrue);
  });

  test('defender dos turnos seguidos: el segundo da +1 (rendimiento '
      'decreciente)', () {
    final p = _engine()
        .command(_battle(_hero(pulse: 1, streak: true)), 'p1',
            const DefendCommand())!
        .state
        .byId('p1')!;
    expect(p.pulse, 2);
    expect(p.ult, 6, reason: 'la carga de ULT no decrece');
  });

  test('la racha sigue solo si viene de un Defender', () {
    final e = _engine();
    // Defendió: al empezar su turno la racha sigue.
    final defended = BattleState(
        party: [_hero(streak: true)..defending = true],
        enemies: [_foe()],
        clock: 0);
    final a = e.nextTurn(defended).state.byId('p1')!;
    expect(a.guardStreak, isTrue);
    expect(a.defending, isFalse);
    // Hizo otra cosa: se corta.
    final other =
        BattleState(party: [_hero(streak: true)], enemies: [_foe()], clock: 0);
    expect(e.nextTurn(other).state.byId('p1')!.guardStreak, isFalse);
  });

  test('+6 de ULT al primer golpe recibido defendiendo, una sola vez', () {
    final def =
        _engine().command(_battle(_hero()), 'p1', const DefendCommand())!.state;
    final before = def.byId('p1')!;
    final hit = _foeHits(def);
    final p = hit.state.byId('p1')!;
    final taken = before.hp - p.hp;
    expect(taken, greaterThan(0));
    expect(
        p.ult,
        closeTo(
            before.ult + taken / p.maxHp * 110 + BattleEngine.defendHitUlt,
            1e-9));
    expect(p.guardHitPending, isFalse);
    // Segundo golpe: solo la carga normal por daño.
    final again = _foeHits(hit.state).state.byId('p1')!;
    final t2 = p.hp - again.hp;
    expect(again.ult, closeTo(p.ult + t2 / p.maxHp * 110, 1e-9));
  });

  test('tiempo agotado: defiende con +1 Pulso, sin ULT ni racha', () {
    final s = _battle(_hero(pulse: 1, streak: true));
    final out = _engine().timeout(s)!.state;
    final p = out.byId('p1')!;
    expect(p.defending, isTrue);
    expect(p.pulse, 2);
    expect(p.ult, 0);
    expect(p.guardStreak, isFalse);
    expect(p.guardHitPending, isFalse);
    // Y el golpe recibido tampoco da el +6.
    final hit = _foeHits(out).state.byId('p1')!;
    final taken = p.hp - hit.hp;
    expect(hit.ult, closeTo(taken / hit.maxHp * 110, 1e-9));
  });

  test('co-op: la racha y el +6 pendiente viajan en el estado (opcionales)',
      () {
    const js = SessionJson();
    final c = _hero(streak: true)..guardHitPending = true;
    final back = js.combatantFromJson(
        asJson(jsonDecode(jsonEncode(js.combatantToJson(c)))));
    expect(back.guardStreak, isTrue);
    expect(back.guardHitPending, isTrue);
    final plain = js.combatantToJson(_hero());
    expect(plain.containsKey('gst'), isFalse);
    expect(plain.containsKey('ghp'), isFalse);
    final old = js.combatantFromJson(asJson(jsonDecode(jsonEncode(plain))));
    expect(old.guardStreak, isFalse);
  });

  test('el AUTO sigue cayendo en Defender como respaldo', () {
    expect(CompanionAi.fallbacks, contains(isA<DefendCommand>()));
  });
}
