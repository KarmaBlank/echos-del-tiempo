import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = StatsCalculator(
    classes: kClasses,
    treeRules: PassiveTreeRules(PassiveTreeCatalog(
        nodes: {}, startNodeByClass: {}, exclusions: {})));

BattleEngine _engine() =>
    BattleEngine(stats: _stats, random: () => 0.99, breakEnabled: false);

BattlePartyMember _member(String id, String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: id,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

/// Turnos porBando (docs/specs/roguelike.md § 6).
void main() {
  final engine = _engine();

  BattleState start(TurnRule rule) => engine
      .start(
        party: [_member('a', 'guerrero'), _member('b', 'maga')],
        enemyTypes: ['slime', 'slime'],
        turnRule: rule,
      )
      .state;

  test('la ronda empieza con el turno del grupo y nadie tiene el turno', () {
    final s = engine.nextTurn(start(TurnRule.porBando)).state;
    expect(s.groupPhase, isTrue);
    expect(s.currentId, isNull);
    expect(s.awaitingGroup, isTrue);
    expect([for (final p in s.pendingGroup) p.id], ['a', 'b']);
  });

  test('cualquiera del grupo actúa primero; nadie actúa dos veces', () {
    var s = engine.nextTurn(start(TurnRule.porBando)).state;
    // Actúa primero el segundo de la lista.
    s = engine.command(s, 'b', const DefendCommand())!.state;
    expect(s.acted, contains('b'));
    expect(s.awaitingGroup, isTrue);
    expect(engine.command(s, 'b', const DefendCommand()), isNull);
    s = engine.command(s, 'a', const DefendCommand())!.state;
    expect(s.pendingGroup, isEmpty);
  });

  test('después del grupo actúan todos los enemigos en orden y vuelve el '
      'grupo', () {
    var s = engine.nextTurn(start(TurnRule.porBando)).state;
    s = engine.command(s, 'a', const DefendCommand())!.state;
    s = engine.command(s, 'b', const DefendCommand())!.state;
    final order = <String>[];
    for (var i = 0; i < 2; i++) {
      s = engine.nextTurn(s).state;
      expect(s.groupPhase, isFalse);
      final cur = s.current!;
      expect(cur.isPlayer, isFalse);
      order.add(cur.id);
      s = engine.enemyTurn(s)!.state;
    }
    expect(order, [for (final e in s.enemies) e.id]);
    s = engine.nextTurn(s).state;
    expect(s.groupPhase, isTrue);
    expect(s.round, 2);
    expect(s.pendingGroup.length, 2);
  });

  test('la velocidad no cambia el orden', () {
    final base = start(TurnRule.porBando);
    base.party.first.speed = 999;
    var s = engine.nextTurn(base).state;
    // Aunque sea rapidísimo, después de actuar espera a la próxima ronda.
    s = engine.command(s, 'a', const DefendCommand())!.state;
    expect(engine.command(s, 'a', const DefendCommand()), isNull);
    expect(s.pendingGroup.single.id, 'b');
  });

  test('tiempo agotado: los que faltaban se defienden', () {
    var s = engine.nextTurn(start(TurnRule.porBando)).state;
    s = engine.command(s, 'a', const DefendCommand())!.state;
    s = engine.timeout(s)!.state;
    expect(s.pendingGroup, isEmpty);
    expect(s.party.last.defending, isTrue);
  });

  test('aturdido al empezar la ronda: pierde su acción del grupo', () {
    final base = start(TurnRule.porBando);
    base.party.first.statuses = {StatusKind.stun: 1};
    final s = engine.nextTurn(base).state;
    expect(s.acted, contains('a'));
    expect([for (final p in s.pendingGroup) p.id], ['b']);
  });

  test('el estado viaja por la red y el Mundo no manda nada nuevo', () {
    final s = engine.nextTurn(start(TurnRule.porBando)).state;
    final j = const SessionJson().battleStateToJson(s);
    final back = const SessionJson().battleStateFromJson(j);
    expect(back.turnRule, TurnRule.porBando);
    expect(back.groupPhase, isTrue);
    expect(back.round, 1);
    final mundo = const SessionJson().battleStateToJson(start(TurnRule.velocidad));
    expect(mundo.keys, isNot(contains('tr')));
    expect(mundo.keys, isNot(contains('gp')));
  });

  test('velocidad: la de siempre (un actor con el turno)', () {
    final s = engine.nextTurn(start(TurnRule.velocidad)).state;
    expect(s.currentId, isNotNull);
    expect(s.awaitingGroup, isFalse);
  });
}
