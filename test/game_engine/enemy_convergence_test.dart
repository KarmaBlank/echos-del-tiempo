import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/enemy_combo_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

// Enemy Convergences (docs/specs/combo_balance.md § "Convergencias
// enemigas").

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine(double r) =>
    BattleEngine(stats: _stats, random: () => r, breakEnabled: false);

Combatant _hero(String id, {Map<StatusKind, int> st = const {}}) => Combatant(
      id: id,
      name: id,
      isPlayer: true,
      hp: 1000,
      maxHp: 1000,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      classId: 'maga',
      weaponType: 'baston',
      nextTurn: 50,
    )..statuses.addAll(st);

Combatant _foe(String id, String type) => Combatant(
      id: id,
      name: id,
      isPlayer: false,
      hp: 1000,
      maxHp: 1000,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: type,
      inflicts: kEnemies[type]!.inflicts,
      nextTurn: 0,
    );

List<ReactionEvent> _reactions(BattleStep s) =>
    s.events.whereType<ReactionEvent>().toList();

void main() {
  tearDown(() =>
      kTuning[TuningId.combatLimits] = kTuningDefaults[TuningId.combatLimits]!);

  test('lone enemies combo only with their own kit', () {
    expect(enemySoloConvergence(_foe('e', 'slime'), kEnemies['slime']), isFalse);
    expect(enemySoloConvergence(_foe('e', 'salamandra'), kEnemies['salamandra']),
        isFalse);
    expect(enemySoloConvergence(_foe('e', 'heraldoEras'), kEnemies['heraldoEras']),
        isTrue);
  });

  test('a lone enemy without a matching pair never detonates', () {
    var s = BattleState(
        party: [_hero('p1', st: {StatusKind.poison: 10})],
        enemies: [_foe('e0', 'slime')],
        currentId: 'e0');
    final e = _engine(0);
    for (var i = 0; i < 12; i++) {
      s.currentId = 'e0';
      final step = e.enemyTurn(s)!;
      expect(_reactions(step), isEmpty);
      s = step.state;
    }
    expect(s.party.first.stacks(StatusKind.poison), greaterThan(10));
  });

  test('a lone enemy with both elements goes for its primed player', () {
    final h = _foe('e0', 'heraldoEras')..actions = 0; // next: Quemadura (Fuego)
    final s = BattleState(
        party: [_hero('p1'), _hero('p2', st: {StatusKind.poison: 8})],
        enemies: [h],
        currentId: 'e0');
    final step = _engine(0).enemyTurn(s)!;
    final r = _reactions(step);
    expect(r.single.kind, ReactionKind.explosionToxica);
    expect(r.single.targetId, 'p2');
  });

  test('group: the detonator focuses the primed player', () {
    BattleState mk() => BattleState(
        party: [_hero('p1', st: {StatusKind.poison: 5}), _hero('p2')],
        enemies: [_foe('e0', 'salamandra'), _foe('e1', 'slime')],
        currentId: 'e0');
    final hit = _engine(0).enemyTurn(mk())!;
    expect(_reactions(hit).single.targetId, 'p1');
    // Focus failed: random target (p2), no Convergence.
    expect(_reactions(_engine(0.99).enemyTurn(mk())!), isEmpty);
  });

  test('group: the primer stacks the player its partner can detonate', () {
    final s = BattleState(
        party: [_hero('p1'), _hero('p2', st: {StatusKind.poison: 2})],
        enemies: [_foe('e0', 'slime'), _foe('e1', 'salamandra')],
        currentId: 'e0');
    final out = _engine(0).enemyTurn(s)!.state;
    expect(out.party[1].stacks(StatusKind.poison), greaterThan(2));
    expect(out.party[0].stacks(StatusKind.poison), 0);
  });

  test('cleansing removes the threat and the detonation', () {
    final p = _hero('p1', st: {StatusKind.poison: 5});
    final s = BattleState(
        party: [p],
        enemies: [_foe('e0', 'salamandra'), _foe('e1', 'slime')],
        currentId: 'e0');
    expect(convergenceThreats(s, kEnemies).single.enemyId, 'e0');
    p.statuses[StatusKind.poison] = 0;
    expect(convergenceThreats(s, kEnemies), isEmpty);
    expect(_reactions(_engine(0).enemyTurn(s)!), isEmpty);
  });

  test('killing the detonator removes the threat', () {
    final s = BattleState(
        party: [_hero('p1', st: {StatusKind.poison: 5})],
        enemies: [_foe('e0', 'salamandra')..hp = 0, _foe('e1', 'slime')],
        currentId: 'e1');
    expect(convergenceThreats(s, kEnemies), isEmpty);
  });

  test('a Convergence on a player respects the player cap', () {
    final s = BattleState(
        party: [_hero('p1', st: {StatusKind.poison: 30}), _hero('p2')],
        enemies: [_foe('e0', 'salamandra'), _foe('e1', 'slime')],
        currentId: 'e0');
    final r = _reactions(_engine(0).enemyTurn(s)!).single;
    final cap = (1000 * EnemyComboTuning.playerCap).round();
    expect(r.amount, cap);
    expect(r.splash['p2'], lessThanOrEqualTo(cap));
  });
}
