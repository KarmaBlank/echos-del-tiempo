import 'package:echos_del_tiempo/features/run/presentation/run_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Pantallas de la Travesía (roguelike.md, "MVP implementado"): se arman
/// sin errores de layout y el personaje de la run no se guarda.
void main() {
  SessionEngine engine() => SessionEngine(
        battles: BattleEngine(stats: statsCalc, random: () => 0.5),
        progression: zoneProgression,
        random: mulberry32(3),
        seeds: () => 777,
        achievementsEnabled: false,
        gameMode: GameModeKind.travesia,
      );

  testWidgets('sala → mapa → pelea → recompensa, sin guardar la cuenta',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final real = zoneProgression.normalize(
        PlayerProfile(name: 'Ana', classId: 'guerrero', level: 20));
    final store = InMemoryProfileStore(real);
    final c = SessionController(
      engine: engine(),
      store: store,
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(c.dispose);
    await c.start();
    Future<void> show() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: RunScreen(view: c.view!, controller: c, onExit: () {}))));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await show();
    expect(find.byKey(const ValueKey('run-start')), findsOneWidget);
    expect(c.startRun(), isTrue);
    await show();
    final s = c.session!;
    final first = RunRules.reachable(s.run!).first;
    expect(find.byKey(ValueKey('run-node-$first')), findsOneWidget);
    expect(c.voteRunNode(first), isTrue);
    c.advance(0.05);
    expect(c.session!.mode, SessionMode.battle);
    for (final en in c.session!.battle!.state.enemies) {
      en.hp = 1;
    }
    for (var i = 0; i < 4000 && c.session!.mode == SessionMode.battle; i++) {
      final b = c.session!.battle!;
      if (b.waitingForPlayer) c.battleCommand(const AttackCommand());
      c.advance(0.05);
    }
    expect(c.session!.run!.phase, RunPhase.reward);
    await show();
    expect(find.byKey(const ValueKey('run-reward-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('run-offer-OBJETOS-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('run-reward-confirm')));
    await tester.pump();
    expect(c.session!.players[c.localId]!.profile.tree, hasLength(1));
    await c.saveNow();
    // La cuenta sigue intacta: nivel 20, árbol vacío.
    final saved = await store.load();
    expect(saved!.level, 20);
    expect(saved.tree, isEmpty);

    // Tienda y fin de la run también se arman.
    final r = c.session!.run!;
    r
      ..phase = RunPhase.stop
      ..node = RunRules.floorOf(r)
          .nodes
          .firstWhere((n) => n.type == RunNodeType.tienda)
          .id;
    await show();
    expect(find.byKey(const ValueKey('run-ready')), findsOneWidget);
    r
      ..phase = RunPhase.over
      ..victory = false;
    await show();
    expect(find.byKey(const ValueKey('run-exit')), findsOneWidget);
  });
}
