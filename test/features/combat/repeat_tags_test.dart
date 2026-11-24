// Identificador de repetidos y marca de élite en la línea de tiempo
// (docs/specs/battle_presentation.md § "Identificador de repetidos").
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import '../../helpers/battle_log_helper.dart';

BattlePartyMember _member(String id, String classId, [String? name]) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: id,
    name: name ?? cls.name,
    potions: 2,
    ethers: 1,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

BattleEngine _engine() => BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99,
    );

/// Avanza hasta que le toque a un jugador.
BattleState _toPlayer(BattleEngine engine, BattleState s) {
  for (var i = 0; i < 50; i++) {
    if (s.current == null) {
      s = engine.nextTurn(s).state;
    } else if (!s.current!.isPlayer) {
      s = engine.enemyTurn(s)!.state;
    } else {
      return s;
    }
  }
  fail('nunca le tocó a un jugador');
}

void main() {
  test('dos del mismo tipo reciben A y B; el tipo único, sin letra', () {
    final s = _engine()
        .start(
            party: [_member('p1', 'guerrero')],
            enemyTypes: const ['lobo', 'lobo', 'slime'])
        .state;
    expect(s.enemies.map((e) => e.tag), ['A', 'B', null]);
    expect(s.enemies.map((e) => e.name), ['Lobo A', 'Lobo B', 'Limo']);
  });

  test('el log nombra al repetido con su letra', () {
    final engine = _engine();
    var s = engine
        .start(
            party: [_member('p1', 'guerrero')],
            enemyTypes: const ['lobo', 'lobo'],
            triggeredBy: 'p1')
        .state;
    s = _toPlayer(engine, s);
    s = engine
        .command(s, s.currentId!, const AttackCommand(targetId: 'e1'))!
        .state;
    expect(s.log, contains('Lobo B'));
    expect(s.log, isNot(contains('Lobo A')));
  });

  test('élite: letra estable y marca; aliados repetidos también', () {
    final s = _engine()
        .start(party: [
          _member('p1', 'guerrero', 'Héroe'),
          _member('p2', 'maga', 'Héroe'),
        ], enemyTypes: const [
          'lobo',
          'lobo'
        ], elite: true)
        .state;
    expect(s.enemies.first.elite, isTrue);
    expect(s.enemies.first.name, 'Lobo Élite A');
    expect(s.enemies[1].name, 'Lobo B');
    expect(s.party.map((p) => p.name), ['Héroe A', 'Héroe B']);
    // Un tercero que entra después recibe la letra libre siguiente.
    final j = _engine().join(s, _member('p3', 'tirador', 'Héroe')).state;
    expect(j.party.map((p) => p.name), ['Héroe A', 'Héroe B', 'Héroe C']);
    // La copia (y la red) conserva la letra.
    expect(s.copy().enemies[1].tag, 'B');
  });

  testWidgets(
      'arena, línea y caja del objetivo: letra y élite; '
      'el mouse en la línea resalta en la arena', (tester) async {
    final engine = _engine();
    var s = engine
        .start(
            party: [_member('p1', 'guerrero')],
            enemyTypes: const ['lobo', 'lobo'],
            elite: true,
            triggeredBy: 'p1')
        .state;
    s = _toPlayer(engine, s);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(
            battle: s,
            canAct: true,
            localId: s.currentId,
            onCommand: (_) => true),
      ),
    ));
    await tester.pump();
    // Arena: la vida lleva la letra.
    final b = s.enemies[1];
    expect(BattleScenePainter.hpLine(b), 'B ${b.hp}/${b.maxHp}');
    // Línea de tiempo: están los dos lobos, cada uno con su letra.
    final slots = BattleScenePainter.timelineSlots(s);
    final ids = slots.map((e) => e.id).toSet();
    expect(ids, containsAll(['e0', 'e1']));
    expect(s.byId('e0')!.tag, 'A');
    expect(s.byId('e0')!.elite, isTrue);
    // Caja del objetivo: el élite (primer objetivo) con nombre y marca.
    expect(find.text('Lobo Élite A'), findsWidgets);
    expect(find.byKey(const ValueKey('target-rank')), findsOneWidget);

    // Mouse sobre el ícono de B en la línea: se resalta en la arena.
    final view = tester.state<BattleViewState>(find.byType(BattleView));
    final scale = view.scene.frame!.geometry.scale;
    final slot = slots.firstWhere((e) => e.id == 'e1');
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(slot.rect.center * scale);
    await tester.pump();
    expect(view.hoveredId, 'e1');
    expect(view.scene.frame!.hoverId, 'e1');
    expect(view.scene.frame!.highlightIds, contains('e1'));
    // Sin mouse encima, deja de resaltarse.
    await g.moveTo(const Offset(640, 300));
    await tester.pump();
    expect(view.scene.frame!.highlightIds, isNot(contains('e1')));
  });
}
