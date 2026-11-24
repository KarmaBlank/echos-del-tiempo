import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/battle_log_helper.dart';

// Solo los nodos de inicio del árbol del prototipo (`TREE_START`): cada
// clase siempre los tiene, así que entran en todos los stats.
const _startNodes = PassiveTreeCatalog(
  nodes: {
    's_gue': PassiveNode(id: 's_gue', x: 0, y: -1.1, name: 'Inicio: Guerrero', kind: 'st', effects: {'hp': 0.05, 'atk': 0.04}, links: []),
    's_mag': PassiveNode(id: 's_mag', x: 1.1, y: 0, name: 'Inicio: Maga', kind: 'st', effects: {'mp': 0.08, 'mag': 0.04}, links: []),
    's_tir': PassiveNode(id: 's_tir', x: 0, y: 1.1, name: 'Inicio: Tirador', kind: 'st', effects: {'crit': 0.03, 'spd': 0.3}, links: []),
    's_pal': PassiveNode(id: 's_pal', x: -1.1, y: 0, name: 'Inicio: Paladín', kind: 'st', effects: {'hp': 0.06, 'def': 1}, links: []),
  },
  startNodeByClass: {'guerrero': 's_gue', 'maga': 's_mag', 'tirador': 's_tir', 'paladin': 's_pal'},
  exclusions: {},
);

const _stats = StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(_startNodes));

/// Azar con valores fijos, en el orden en que el prototipo llama a
/// `Math.random`. Cuando se acaban, 0.99: nunca crítico ni probabilidad.
BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(
    stats: _stats,
    random: () => i < rolls.length ? rolls[i++] : 0.99,
  );
}

BattlePartyMember _member(String id, String classId,
    {int? hp, double? mp, double ult = 0, int potions = 0}) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: cls.name,
    hp: hp,
    mp: mp,
    ult: ult,
    potions: potions,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

/// Guerrero solo contra [enemies], con el turno del guerrero ya empezado.
BattleState _warriorTurn(BattleEngine engine, List<String> enemies) {
  final start = engine.start(
    party: [_member('p1', 'guerrero')],
    enemyTypes: enemies,
    triggeredBy: 'p1',
  );
  final turn = engine.nextTurn(start.state).state;
  expect(turn.currentId, 'p1');
  return turn;
}

/// Un jugador de [classId] solo contra un slime, con el turno del slime
/// ya empezado (el slime arranca primero con azar 0).
BattleState _slimeTurn(BattleEngine engine, String classId,
    {String enemy = 'slime'}) {
  final start = engine.start(party: [_member('p1', classId)], enemyTypes: [enemy]);
  final turn = engine.nextTurn(start.state).state;
  expect(turn.currentId, 'e0');
  return turn;
}

void main() {
  group('stats con el catálogo real', () {
    test('Guerrero nivel 1 con Espada de Bronce y su nodo de inicio', () {
      final c = _engine().start(
          party: [_member('p1', 'guerrero')], enemyTypes: ['slime']).state.party.first;
      // 20 + 10*4 + 2 = 62 → ×1.05 = 65.1 → 65
      expect(c.maxHp, 65);
      // round(6 + 12*0.6 + 6*0.2 = 14.4) = 14 → ×1.04 = 14.56 → 15
      expect(c.attack, 15);
      expect(c.speed, 9.6);
      expect(c.defensePercent, closeTo(0.09, 1e-9)); // DEF 3 × 3%
    });

    test('Maga: el maná usa el redondeo de JS (24.5 → 25)', () {
      final c = _engine().start(
          party: [_member('p1', 'maga')], enemyTypes: ['slime']).state.party.first;
      // round(4 + 13*1.5 + 1 = 24.5) = 25 → ×1.08 = 27
      expect(c.maxMp, 27);
      // round(5 + 13*0.75 = 14.75) = 15 → ×1.04 = 15.6 → 16
      expect(c.magic, 16);
    });
  });

  group('inicio de batalla', () {
    test('la vida enemiga escala con el tamaño del grupo', () {
      final s = _engine().start(
        party: [_member('p1', 'guerrero'), _member('p2', 'maga')],
        enemyTypes: ['slime', 'bat'],
      ).state;
      // 0.6 + 0.3*2 = 1.2 (combo_balance.md § 3.3) → Limo 30*1.2 = 36,
      // Murciélago 22*1.2 = 26.4 → 26
      expect(s.enemies.map((e) => e.maxHp), [36, 26]);
      expect(s.log, '¡Emboscada!');
    });

    test('el élite tiene ×2.6 vida, ×1.35 ATQ y ×1.1 velocidad', () {
      final s = _engine().start(
        party: [_member('p1', 'guerrero')],
        enemyTypes: ['golem', 'slime'],
        elite: true,
      ).state;
      final golem = s.enemies[0];
      expect(golem.maxHp, 164); // 70 × 0.9 (solo) × 2.6 = 163.8
      expect(golem.attack, 16); // 12 × 1.35 = 16.2
      expect(golem.speed, closeTo(5.5, 1e-9));
      expect(golem.critChance, 0.15);
      expect(golem.name, 'Gólem Élite');
      expect(s.enemies[1].elite, isFalse, reason: 'solo el primero es élite');
    });

    test('el que tocó al enemigo arranca antes (IV × 0.2)', () {
      final s = _engine().start(
        party: [_member('p1', 'guerrero')],
        enemyTypes: ['slime'],
        triggeredBy: 'p1',
      ).state;
      expect(s.party.first.nextTurn, closeTo(100 / 9.6 * 0.2, 1e-9));
    });
  });

  group('ataque básico', () {
    test('daño = ATQ, con el desglose en el log', () {
      final engine = _engine();
      final step = engine.command(
          _warriorTurn(engine, ['slime']), 'p1', const AttackCommand())!;
      final slime = step.state.enemies.first;
      // Solo: vida × 0.9 (combo_balance.md § 3.3) → 27.
      expect(slime.hp, 27 - 15);
      expect(step.state.log, 'Guerrero ataca → Limo: 15 = ATQ 15 × 1');
      expect(step.state.currentId, isNull);
    });

    test('crítico ×1.5, redondeado como JS', () {
      final engine = _engine([0.99, 0.0]); // inicio del slime, después crítico
      // Vida alta: que no entre el tope por golpe (combo_balance.md § 3.2).
      final turn = _warriorTurn(engine, ['slime']);
      turn.enemies.first
        ..maxHp = 300
        ..hp = 300;
      final step = engine.command(turn, 'p1', const AttackCommand())!;
      expect(step.state.enemies.first.hp, 300 - 23); // 22.5 → 23
      expect(step.state.log, contains('23 = ATQ 15 × 1 × 1.5 CRÍTICO'));
    });

    test('hacer daño carga el ULT: 5 + daño/vida_máx × 30', () {
      final engine = _engine();
      final step = engine.command(
          _warriorTurn(engine, ['slime']), 'p1', const AttackCommand())!;
      expect(step.state.party.first.ult, closeTo(5 + 15 / 27 * 30, 1e-9));
    });

    test('matar al último enemigo termina la batalla con recompensas', () {
      final engine = _engine();
      final turn = _warriorTurn(engine, ['slime']);
      turn.enemies.first.hp = 10;
      final step = engine.command(turn, 'p1', const AttackCommand())!;
      expect(step.state.outcome?.victory, isTrue);
      expect(step.state.outcome?.xp, 6);
      expect(step.state.outcome?.credits, 5);
      expect(step.events.whereType<BattleEndedEvent>(), hasLength(1));
    });
  });

  group('comandos inválidos no cambian nada', () {
    test('no es su turno', () {
      final engine = _engine();
      expect(
          engine.command(_warriorTurn(engine, ['slime']), 'p2', const AttackCommand()),
          isNull);
    });

    test('habilidad que su arma no tiene', () {
      final engine = _engine();
      expect(
          engine.command(_warriorTurn(engine, ['slime']), 'p1', const SkillCommand('bola')),
          isNull);
    });

    test('MP insuficiente', () {
      final engine = _engine();
      final turn = _warriorTurn(engine, ['slime']);
      turn.party.first.mp = 3; // Embestida cuesta 4
      expect(engine.command(turn, 'p1', const SkillCommand('embestida')), isNull);
    });

    test('ULT sin carga completa', () {
      final engine = _engine();
      expect(
          engine.command(_warriorTurn(engine, ['slime']), 'p1', const UltimateCommand()),
          isNull);
    });
  });

  group('habilidades', () {
    test('Embestida: ATQ × 1.2, gasta MP y retrasa al enemigo', () {
      final engine = _engine();
      final turn = _warriorTurn(engine, ['golem']);
      final before = turn.enemies.first.nextTurn;
      final step = engine.command(turn, 'p1', const SkillCommand('embestida'))!;
      final golem = step.state.enemies.first;
      expect(golem.hp, 63 - 18); // 15 × 1.2; vida 70 × 0.9 (solo)
      expect(step.state.party.first.mp, 11 - 4);
      expect(golem.nextTurn, closeTo(before + 100 / 5 * 0.45, 1e-9));
      expect(step.state.log, 'Guerrero · Embestida → Gólem: 18 = ATQ 15 × 1.2 · retrasa');
    });

    test('ULT de espada: ATQ × 3 y vacía la carga sin recargarla', () {
      final engine = _engine();
      final start = engine.start(
        party: [_member('p1', 'guerrero', ult: 100)],
        enemyTypes: ['golem'],
        triggeredBy: 'p1',
      );
      // Vida alta: que no entre el tope por golpe (combo_balance.md § 3.2).
      start.state.enemies.first
        ..maxHp = 700
        ..hp = 700;
      final step = engine.command(
          engine.nextTurn(start.state).state, 'p1', const UltimateCommand())!;
      expect(step.state.enemies.first.hp, 700 - 45);
      expect(step.state.party.first.ult, 0);
      expect(step.events.whereType<UltimateUsedEvent>().single.name, 'Tajo Final');
    });

    test('Defender: el próximo turno llega antes (IV × 0.7)', () {
      final engine = _engine();
      final turn = _warriorTurn(engine, ['slime']);
      final step = engine.command(turn, 'p1', const DefendCommand())!;
      final p = step.state.party.first;
      expect(p.defending, isTrue);
      expect(p.nextTurn, closeTo(turn.clock + 100 / 9.6 * 0.7, 1e-9));
    });

    test('Pasar turno: termina el turno, el próximo en IV × 0.5, sin ULT ni '
        'defensa', () {
      final engine = _engine();
      final turn = _warriorTurn(engine, ['slime']);
      final before = turn.party.first;
      final step = engine.command(turn, 'p1', const PassCommand())!;
      final p = step.state.party.first;
      expect(BattleEngine.passTurnFactor, 0.5);
      expect(step.state.currentId, isNull, reason: 'el turno terminó');
      expect(p.nextTurn, closeTo(turn.clock + 100 / 9.6 * 0.5, 1e-9));
      expect(p.ult, before.ult, reason: 'pasar no carga ULT');
      expect(p.mp, before.mp);
      expect(p.defending, isFalse);
      expect(step.state.enemies.first.hp, turn.enemies.first.hp);
      expect(step.events.whereType<ActionEvent>(), isEmpty);
      expect(step.state.log, 'Guerrero pasa el turno (el próximo llega antes)');
      // Llega antes que defendiendo y que actuando.
      final def = engine.command(turn, 'p1', const DefendCommand())!;
      final atk = engine.command(turn, 'p1', const AttackCommand())!;
      expect(p.nextTurn, lessThan(def.state.party.first.nextTurn));
      expect(p.nextTurn, lessThan(atk.state.party.first.nextTurn));
      // Fuera de turno no vale.
      expect(engine.command(step.state, 'p1', const PassCommand()), isNull);
    });

    test('Poción de vida revive al aliado caído', () {
      final engine = _engine();
      final start = engine.start(
        party: [_member('p1', 'guerrero', potions: 1), _member('p2', 'maga', hp: 0)],
        enemyTypes: ['slime'],
        triggeredBy: 'p1',
      );
      final step = engine.command(engine.nextTurn(start.state).state, 'p1',
          const ItemCommand(BattleItem.potion))!;
      expect(step.state.party[1].hp, 21); // 46 × 0.45 = 20.7
      expect(step.state.party[0].potions, 0);
      expect(step.events.whereType<RevivedEvent>().single.targetId, 'p2');
    });
  });

  group('enemigos', () {
    test('golpe normal: ATQ menos el % de DEF, y aplica su estado', () {
      final engine = _engine([0.0]); // el slime arranca primero
      final step = engine.enemyTurn(_slimeTurn(engine, 'guerrero'))!;
      final p = step.state.party.first;
      expect(p.hp, 65 - 6); // 7 × (1 − 0.09) = 6.37
      expect(p.stacks(StatusKind.poison), 1);
      expect(step.state.log, 'Limo → Guerrero: 6 = ATQ 7 − 9% DEF · +1 Veneno');
    });

    test('defendiendo recibe la mitad', () {
      final engine = _engine([0.0]);
      final turn = _slimeTurn(engine, 'guerrero');
      turn.party.first.defending = true;
      final step = engine.enemyTurn(turn)!;
      expect(step.state.party.first.hp, 65 - 3); // 7 × 0.5 × 0.91 = 3.185
    });

    test('el Paladín recibe +1 stack de estado', () {
      final engine = _engine([0.0]);
      final step = engine.enemyTurn(_slimeTurn(engine, 'paladin'))!;
      expect(step.state.party.first.stacks(StatusKind.poison), 2);
    });

    test('el Paladín recibe ×1.5 de enemigos perforantes', () {
      final engine = _engine([0.0]);
      final step = engine.enemyTurn(_slimeTurn(engine, 'paladin', enemy: 'bat'))!;
      // DEF 6 + 1 (inicio) = 7 → 21%. 9 × 1.5 × 0.79 = 10.665 → 11
      expect(step.state.party.first.hp, 87 - 11);
      expect(step.state.log, contains('× 1.5 perforante'));
    });
  });

  group('estados al empezar el turno', () {
    test('Quemadura: 4% de vida por stack (tope 8 c/u), después la mitad', () {
      final engine = _engine([0.0]);
      final start = engine.start(party: [_member('p1', 'guerrero')], enemyTypes: ['slime']);
      start.state.enemies.first.statuses[StatusKind.burn] = 3;
      final step = engine.nextTurn(start.state);
      final slime = step.state.enemies.first;
      // Vida 27 (30 × 0.9 solo): 27 × 0.04 × 3 = 3.24 → 3
      expect(slime.hp, 27 - 3);
      expect(slime.stacks(StatusKind.burn), 1);
      expect(step.state.log, 'Limo sufre Quemadura 3 = 3 de daño');
    });

    // Hielo v0.7 (elemental_reactions.md § 7): cambio intencional. Con 5
    // pierde el turno y queda Quebradizo (no se descongela en el acto).
    test('Congelación ×5: pierde el turno y queda Quebradizo', () {
      final engine = _engine([0.0]);
      final start = engine.start(party: [_member('p1', 'guerrero')], enemyTypes: ['slime']);
      start.state.enemies.first.statuses[StatusKind.freeze] = 5;
      final step = engine.nextTurn(start.state);
      final slime = step.state.enemies.first;
      expect(step.state.currentId, isNull);
      expect(slime.stacks(StatusKind.freeze), 5);
      expect(slime.brittle, isTrue);
      expect(step.events.whereType<TurnSkippedEvent>().single.cause, StatusKind.freeze);
      expect(step.events.whereType<IceEvent>().single.phase, IcePhase.brittle);
    });

    test('Congelación baja la velocidad 6% por stack', () {
      final engine = _engine();
      final s = engine.start(party: [_member('p1', 'guerrero')], enemyTypes: ['slime']).state;
      final slime = s.enemies.first..statuses[StatusKind.freeze] = 2;
      expect(engine.interval(slime), closeTo(100 / (7 * 0.88), 1e-9));
    });
  });

  group('eventos para la UI (ActionEvent)', () {
    test('ataque: la acción va antes del daño, con actor y objetivo', () {
      final engine = _engine();
      final turn = _warriorTurn(engine, ['slime', 'bat']);
      final step = engine.command(turn, 'p1', const AttackCommand(targetId: 'e1'))!;
      final action = step.events.first as ActionEvent;
      expect(action.actorId, 'p1');
      expect(action.kind, BattleActionKind.attack);
      expect(action.targetId, 'e1');
      expect(action.allTargets, isFalse);
      expect(step.events[1], isA<DamageEvent>());
      expect((step.events[1] as DamageEvent).targetId, 'e1');
    });

    test('habilidad a todos: trae el id de la habilidad', () {
      final engine = _engine();
      final turn = _warriorTurn(engine, ['slime', 'bat']);
      final step = engine.command(turn, 'p1', const SkillCommand('giro'))!;
      final action = step.events.whereType<ActionEvent>().single;
      expect(action.kind, BattleActionKind.skill);
      expect(action.skillId, 'giro');
      expect(action.allTargets, isTrue);
      expect(action.targetId, isNull);
      expect(step.events.whereType<DamageEvent>(), hasLength(2));
    });

    test('ULT: UltimateUsedEvent y después la acción con el id de la ULT', () {
      final engine = _engine();
      final start = engine.start(
        party: [_member('p1', 'guerrero', ult: 100)],
        enemyTypes: ['golem'],
        triggeredBy: 'p1',
      );
      final step = engine.command(
          engine.nextTurn(start.state).state, 'p1', const UltimateCommand())!;
      expect(step.events[0], isA<UltimateUsedEvent>());
      final action = step.events[1] as ActionEvent;
      expect(action.kind, BattleActionKind.ultimate);
      expect(action.skillId, 'ult_espada');
      expect(action.targetId, 'e0');
    });

    test('dúo: actor y compañero', () {
      final engine = _engine();
      final start = engine.start(
        party: [_member('p1', 'guerrero'), _member('p2', 'maga')],
        enemyTypes: ['slime'],
        triggeredBy: 'p1',
      );
      final step = engine.command(
          engine.nextTurn(start.state).state, 'p1', const DualCommand('p2'))!;
      final action = step.events.whereType<ActionEvent>().single;
      expect(action.kind, BattleActionKind.dual);
      expect(action.partnerId, 'p2');
      expect(action.allTargets, isTrue);
    });

    test('poción, defender y tiempo agotado', () {
      final engine = _engine();
      final start = engine.start(
        party: [_member('p1', 'guerrero', potions: 1), _member('p2', 'maga', hp: 0)],
        enemyTypes: ['slime'],
        triggeredBy: 'p1',
      );
      final turn = engine.nextTurn(start.state).state;
      final pot = engine.command(turn, 'p1', const ItemCommand(BattleItem.potion))!;
      final a = pot.events.first as ActionEvent;
      expect(a.kind, BattleActionKind.potion);
      expect(a.targetId, 'p2');

      final def = engine.command(turn, 'p1', const DefendCommand())!;
      expect((def.events.first as ActionEvent).kind, BattleActionKind.defend);
      final out = engine.timeout(turn)!;
      expect((out.events.first as ActionEvent).kind, BattleActionKind.defend);
    });

    test('enemigo: acción con su víctima', () {
      final engine = _engine([0.0]);
      final step = engine.enemyTurn(_slimeTurn(engine, 'guerrero'))!;
      final action = step.events.first as ActionEvent;
      expect(action.actorId, 'e0');
      expect(action.kind, BattleActionKind.enemyAttack);
      expect(action.targetId, 'p1');
    });

    test('Devorador: Colapso Temporal (a todos) en su 3ª acción', () {
      final engine = _engine([0.0]);
      final turn = _slimeTurn(engine, 'guerrero', enemy: 'devorador');
      turn.enemies.first.actions = 2;
      final step = engine.enemyTurn(turn)!;
      final action = step.events.first as ActionEvent;
      expect(action.kind, BattleActionKind.enemyArea);
      expect(action.allTargets, isTrue);
      expect(action.targetId, isNull);
    });

    test('daño de estado: dice qué estado lo causó', () {
      final engine = _engine([0.0]);
      final start = engine.start(party: [_member('p1', 'guerrero')], enemyTypes: ['slime']);
      start.state.enemies.first.statuses[StatusKind.poison] = 2;
      final step = engine.nextTurn(start.state);
      final dmg = step.events.whereType<DamageEvent>().single;
      expect(dmg.fromStatus, isTrue);
      expect(dmg.statusSource, StatusKind.poison);
    });
  });
}
