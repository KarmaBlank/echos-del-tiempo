// Pulso, precondiciones e Instante (docs/specs/combo_balance.md § 5.2,
// paso 7; combat.md § "Pulso e Instante"). Combatientes a mano, azar fijo
// (0.99: nunca crítico ni probabilidad), familias y quiebre apagados salvo
// que la prueba los pida.

import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/skill_requirements.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart' show newProfile, progression;

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine() => BattleEngine(
    stats: _stats,
    random: () => 0.99,
    familiesEnabled: false,
    breakEnabled: false);

Combatant _hero({int pulse = 0, List<String> skills = const [], int hp = 100}) =>
    Combatant(
      id: 'p1',
      name: 'Ana',
      isPlayer: true,
      pulse: pulse,
      hp: hp,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: skills,
      classId: 'maga',
      weaponType: 'báculo',
      nextTurn: 10,
    );

Combatant _foe(String id,
        {Map<StatusKind, int>? st, bool fissured = false, String type = 'golem'}) =>
    Combatant(
      id: id,
      name: 'Foe $id',
      isPlayer: false,
      hp: 500,
      maxHp: 500,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: type,
      statuses: st,
      fissured: fissured,
      nextTurn: 50,
    );

BattleState _battle(Combatant hero, List<Combatant> foes) =>
    BattleState(party: [hero], enemies: foes, clock: 10, currentId: 'p1');

BattleStep? _do(BattleState s, BattleCommand c, [BattleEngine? e]) =>
    (e ?? _engine()).command(s, 'p1', c);

Combatant _p(BattleStep s) => s.state.byId('p1')!;

void main() {
  group('Pulso', () {
    test('arranca en 1 y suma 1 al empezar el turno', () {
      final e = BattleEngine(stats: _stats, random: () => 0.5);
      final start = e.start(party: [
        BattlePartyMember(
            id: 'p1',
            name: 'Ana',
            build: progression.buildOf(newProfile('Ana', 'guerrero'))),
      ], enemyTypes: const ['slime'], triggeredBy: 'p1');
      expect(start.state.party.single.pulse, BattleEngine.pulseStart);
      expect(BattleEngine.pulseStart, 1);
      final turn = e.nextTurn(start.state).state;
      expect(turn.currentId, 'p1');
      expect(turn.party.single.pulse, 2);
    });

    test('+1 por ataque básico, con tope 5', () {
      expect(_p(_do(_battle(_hero(pulse: 0), [_foe('e0')]),
                  const AttackCommand())!)
              .pulse,
          1);
      expect(
          _p(_do(_battle(_hero(pulse: 5), [_foe('e0')]), const AttackCommand())!)
              .pulse,
          BattleEngine.pulseMax);
    });

    test('+2 al defender (battle_attack_menu.md § 6); la defensa '
        'automática del tiempo, +1', () {
      final s = _battle(_hero(pulse: 2), [_foe('e0')]);
      expect(_p(_do(s, const DefendCommand())!).pulse, 4);
      expect(_engine().timeout(s)!.state.party.single.pulse, 3);
    });

    test('Pasar no da Pulso', () {
      final s = _battle(_hero(pulse: 2), [_foe('e0')]);
      expect(_p(_do(s, const PassCommand())!).pulse, 2);
    });

    test('+1 por reacción, una vez por acción (área a dos preparados)', () {
      // Llamarada (fuego, a todos) sobre dos enemigos con Veneno: dos
      // Explosiones tóxicas, un solo +1.
      final s = _battle(_hero(pulse: 0, skills: ['llamarada']), [
        _foe('e0', st: {StatusKind.poison: 3}),
        _foe('e1', st: {StatusKind.poison: 3}),
      ]);
      expect(_p(_do(s, const SkillCommand('llamarada'))!).pulse, 1);
    });

    test('+1 por golpe a una debilidad (familias)', () {
      // Lobo (bestia): débil al Fuego. Bola de Fuego suma; Embestida
      // (física, sin debilidad) no.
      final e = BattleEngine(stats: _stats, random: () => 0.99);
      BattleState s() => _battle(_hero(pulse: 0, skills: ['bola', 'embestida']),
          [_foe('e0', type: 'lobo')]);
      expect(_p(e.command(s(), 'p1', const SkillCommand('bola'))!).pulse, 1);
      expect(
          _p(e.command(s(), 'p1', const SkillCommand('embestida'))!).pulse, 0);
    });

    test('la habilidad cobra su Pulso además del MP', () {
      final s = _battle(_hero(pulse: 3, skills: ['ignicionEco']),
          [_foe('e0', st: {StatusKind.poison: 6})]);
      final step = _do(s, const SkillCommand('ignicionEco', targetId: 'e0'))!;
      // 3 − 2 de costo + 1 por la reacción (Explosión tóxica).
      expect(_p(step).pulse, 2);
      expect(_p(step).mp, 47);
    });
  });

  group('precondiciones', () {
    test('Quebrar: Pulso 2, sin MP, pide objetivo Fisurado', () {
      final q = kSkills[kQuebrarId]!;
      expect([q.pulse, q.mp, q.requires.single.kind],
          [2, 0, SkillReqKind.targetFissured]);
      final e = BattleEngine(stats: _stats, random: () => 0.99, familiesEnabled: false);
      // Sin Fisurado: rechazada.
      expect(
          e.command(_battle(_hero(pulse: 5, skills: ['quebrar']), [_foe('e0')]),
              'p1', const SkillCommand('quebrar')),
          isNull);
      // Fisurado sin Pulso: rechazada.
      expect(
          e.command(
              _battle(_hero(pulse: 1, skills: ['quebrar']),
                  [_foe('e0', fissured: true)..breakBase = 10]),
              'p1',
              const SkillCommand('quebrar')),
          isNull);
      // Fisurado y Pulso 2: quiebra y gasta el Pulso.
      final ok = e.command(
          _battle(_hero(pulse: 2, skills: ['quebrar']),
              [_foe('e0', fissured: true)..breakBase = 10]),
          'p1',
          const SkillCommand('quebrar'))!;
      expect(ok.state.enemies.single.broken, isTrue);
      expect(_p(ok).pulse, 0);
    });

    test('objetivo con N+ stacks: con 4 no, con 5 sí', () {
      final h = _hero(pulse: 5, skills: ['ignicionEco']);
      expect(
          _do(_battle(h, [_foe('e0', st: {StatusKind.poison: 4})]),
              const SkillCommand('ignicionEco')),
          isNull);
      expect(
          _do(_battle(h.copy(), [_foe('e0', st: {StatusKind.poison: 5})]),
              const SkillCommand('ignicionEco')),
          isNotNull);
    });

    test('objetivo con Marca y vida propia bajo el 50% (reglas)', () {
      const marked = SkillDef(
          id: 'x',
          name: 'X',
          kind: SkillKind.physical,
          requires: [SkillReq.targetMarked(), SkillReq.selfHpBelow(0.5)]);
      final foe = _foe('e0');
      final full = _hero(hp: 100);
      expect(SkillRequirements.missing(marked, full, foe),
          ['objetivo con Marca', 'tu vida bajo el 50%']);
      foe.effects = [
        const TimedEffect(
            sourceId: 'm', stat: BuffStat.damageTaken, value: 0.2, turns: 2),
      ];
      expect(SkillRequirements.missing(marked, _hero(hp: 40), foe), isEmpty);
    });

    test('falta de MP y Pulso entra en el "Necesita: …"', () {
      final q = kSkills['ignicionEco']!;
      final h = _hero(pulse: 1)..mp = 1;
      final m = SkillRequirements.missing(q, h, _foe('e0'));
      expect(m, ['3 MP', 'Pulso 2', 'objetivo con 5+ de Veneno']);
      expect(SkillRequirements.needsText(m),
          'Necesita: 3 MP · Pulso 2 · objetivo con 5+ de Veneno');
      expect(SkillRequirements.needsText(const []), isNull);
    });

    test('a todos: la precondición de objetivo vale si la cumple alguno', () {
      const area = SkillDef(
          id: 'a',
          name: 'A',
          kind: SkillKind.magical,
          allTargets: true,
          requires: [SkillReq.targetStacks(StatusKind.burn, 5)]);
      final foes = [_foe('e0'), _foe('e1', st: {StatusKind.burn: 5})];
      expect(
          SkillRequirements.missing(area, _hero(), foes.first, foes: foes),
          isEmpty);
    });
  });

  group('Instante', () {
    test('no termina el turno; la acción siguiente sí', () {
      final s = _battle(_hero(pulse: 0, skills: ['brasaEco']), [_foe('e0')]);
      final a = _do(s, const SkillCommand('brasaEco'))!;
      expect(a.state.currentId, 'p1');
      expect(_p(a).chained, isTrue);
      expect(_p(a).nextTurn, 10); // no se movió
      expect(a.state.enemies.single.stacks(StatusKind.burn), 3);
      final b = _do(a.state, const AttackCommand())!;
      expect(b.state.currentId, isNull);
      expect(_p(b).nextTurn, greaterThan(10));
    });

    test('una sola por turno: la segunda Instante termina el turno', () {
      final s = _battle(_hero(skills: ['brasaEco']), [_foe('e0')]);
      final a = _do(s, const SkillCommand('brasaEco'))!;
      final b = _do(a.state, const SkillCommand('brasaEco'))!;
      expect(b.state.currentId, isNull);
    });

    test('preparar + detonar en el mismo turno', () {
      // Flecha Venenosa (Instante) a un enemigo con 3 de Veneno y después
      // Ignición Convergente: Explosión tóxica en el mismo turno.
      final h = _hero(pulse: 2, skills: ['venenosa', 'ignicionEco']);
      final s = _battle(h, [_foe('e0', st: {StatusKind.poison: 3})]);
      final a = _do(s, const SkillCommand('venenosa'))!;
      expect(a.state.enemies.single.stacks(StatusKind.poison), 6);
      final b = _do(a.state, const SkillCommand('ignicionEco'))!;
      expect(b.state.enemies.single.stacks(StatusKind.poison), 0);
      expect(b.state.log, contains('EXPLOSIÓN TÓXICA'));
      expect(b.state.currentId, isNull);
    });

    test('Pasar después de una Instante: termina sin el adelanto', () {
      final s = _battle(_hero(skills: ['brasaEco']), [_foe('e0')]);
      final e = _engine();
      final iv = e.interval(s.party.single);
      final a = _do(s, const SkillCommand('brasaEco'), e)!;
      final pass = _do(a.state, const PassCommand(), e)!;
      expect(_p(pass).nextTurn, closeTo(10 + iv, 1e-9));
      expect(pass.state.log, contains('termina el turno'));
      // Sin Instante, Pasar adelanta (× 0.5).
      final plain = _do(s, const PassCommand(), e)!;
      expect(_p(plain).nextTurn, closeTo(10 + iv * 0.5, 1e-9));
    });

    test('el tiempo agotado después de una Instante defiende y termina', () {
      final s = _battle(_hero(skills: ['brasaEco']), [_foe('e0')]);
      final a = _do(s, const SkillCommand('brasaEco'))!;
      final t = _engine().timeout(a.state)!;
      expect(t.state.currentId, isNull);
      expect(_p(t).defending, isTrue);
    });

    test('el turno siguiente vuelve a permitir encadenar', () {
      final e = _engine();
      final s = _battle(_hero(skills: ['brasaEco']), [_foe('e0')]);
      final a = e.command(s, 'p1', const SkillCommand('brasaEco'))!;
      final b = e.command(a.state, 'p1', const AttackCommand())!;
      expect(_p(b).chained, isTrue); // se limpia al empezar el próximo
      b.state.enemies.single.nextTurn = 1e9;
      final c = e.nextTurn(b.state);
      expect(c.state.currentId, 'p1');
      expect(c.state.party.single.chained, isFalse);
    });

    test('matar con la Instante termina la batalla', () {
      final s = _battle(_hero(skills: ['brasaEco']), [_foe('e0')..hp = 1]);
      final a = _do(s, const SkillCommand('brasaEco'))!;
      expect(a.state.outcome?.victory, isTrue);
      expect(a.state.currentId, isNull);
    });
  });

  group('kits (combo_balance.md § 5.2)', () {
    test('cada clase tiene sus combos de clase al final, antes de Quebrar',
        () {
      final e = BattleEngine(stats: _stats, random: () => 0.5);
      for (final cls in kClassComboSkill.keys) {
        final s = e.start(party: [
          BattlePartyMember(
              id: 'p1',
              name: 'X',
              build: progression.buildOf(newProfile('X', cls))),
        ], enemyTypes: const ['slime']).state;
        final ids = s.party.single.skillIds;
        final combo = kClassComboSkill[cls]!;
        expect(ids.sublist(ids.length - 1 - combo.length, ids.length - 1),
            combo,
            reason: cls);
        expect(kBaseQuebrarIds, contains(ids.last));
      }
    });

    test('el grupo puede preparar y detonar las dos Convergencias', () {
      final skills = GameCatalog.standard.skills;
      // Cada clase prepara con una Instante: Guerrero y Maga Quemadura,
      // Tirador Veneno, Paladín Marca.
      for (final (id, st) in [
        ('brasaEco', StatusKind.burn),
        ('ascuaEco', StatusKind.burn),
        ('puaEco', StatusKind.poison),
      ]) {
        expect(skills[id]!.status!.kind, st, reason: id);
        expect([skills[id]!.instant, skills[id]!.pulse], [true, 0], reason: id);
      }
      expect(skills['selloInstante']!.instant, isTrue);
      // Maga detona Veneno (Explosión tóxica); Tirador, Quemadura
      // (Combustión). Cuestan 2 de Pulso.
      expect(skills['ignicionEco']!.requires.single.status, StatusKind.poison);
      expect(skills['ponzonaEco']!.requires.single.status, StatusKind.burn);
      expect([skills['ignicionEco']!.pulse, skills['ponzonaEco']!.pulse], [2, 2]);
    });
  });

  group('red', () {
    test('Pulso y encadenado viajan en el estado (ida y vuelta JSON)', () {
      const js = SessionJson();
      final c = _hero(pulse: 4)..chained = true;
      final back = js.combatantFromJson(
          asJson(jsonDecode(jsonEncode(js.combatantToJson(c)))));
      expect([back.pulse, back.chained], [4, true]);
      // Opcionales: un estado viejo (sin `pls` ni `chn`) lee 0 y false.
      final raw = js.combatantToJson(_hero(pulse: 0));
      expect(raw.containsKey('pls'), isFalse);
      expect(raw.containsKey('chn'), isFalse);
      final old = js.combatantFromJson(asJson(jsonDecode(jsonEncode(raw))));
      expect([old.pulse, old.chained], [0, false]);
    });
  });
}
