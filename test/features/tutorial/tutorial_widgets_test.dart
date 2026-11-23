import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart'
    show BattleCommandWindow;
import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/features/missions/presentation/mission_board_panel.dart';
import 'package:echos_del_tiempo/features/tutorial/presentation/tutorial_widgets.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import '../../app/button_look.dart';

/// Sello y batalla del TUTORIAL (docs/specs/combat_tutorial.md § 1, 4, 5).

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: MaterialApp(
    theme: RetroTheme.build(),
    home: Scaffold(body: child),
  )));
  await tester.pump();
}

void main() {
  const cat = GameCatalog.standard;
  const lock = 'Primero, todos tienen que hacer el TUTORIAL. Falta: Beto';

  testWidgets('sello: TUTORIAL primero y las demás misiones desactivadas',
      (tester) async {
    bool? started;
    await _pump(
        tester,
        MissionBoardPanel(
          missions: cat.missions,
          voteOpen: false,
          onPropose: (_) {},
          onClose: () {},
          lockText: lock,
          tutorialDone: false,
          tutorial: TutorialSealDetail(
            rules: const TutorialRules(),
            done: false,
            humans: 1,
            companions: 2,
            isHost: true,
            lockText: lock,
            onStart: (c) => started = c,
          ),
        ));
    // Pendiente: la fila del tutorial está elegida y es la primera.
    expect(find.byKey(const ValueKey('mission-tutorial')), findsOneWidget);
    // Fila del sistema de diseño (DsListRow), elegida.
    expect(
        tester
            .widget<DsListRow>(find.byKey(const ValueKey('mission-tutorial')))
            .selected,
        isTrue);
    expectButtonLook(tester, find.byKey(const ValueKey('tutorial-party')));
    await tester.tap(find.byKey(const ValueKey('tutorial-party')));
    expect(started, isTrue);
    await tester.tap(find.byKey(const ValueKey('tutorial-solo')));
    expect(started, isFalse);
    // Glosario sin pelear.
    await tester.tap(find.byKey(const ValueKey('tutorial-glossary-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tutorial-glossary')), findsOneWidget);
    // Otra misión: PROPONER desactivado con el aviso.
    final m = cat.missions.first;
    await tester.tap(find.byKey(ValueKey('mission-${m.id}')));
    await tester.pump();
    final b = tester.widget<DsButton>(find.byKey(ValueKey('propose-${m.id}')));
    expect(b.tooltip, lock);
    expect(b.onPressed, isNull);
  });

  testWidgets('sello en grupo: solo el host lo inicia', (tester) async {
    await _pump(
        tester,
        SizedBox(
          height: 500,
          child: TutorialSealDetail(
            rules: const TutorialRules(),
            done: true,
            humans: 3,
            companions: 0,
            isHost: false,
            onStart: (_) {},
          ),
        ));
    final b =
        tester.widget<PanelButton>(find.byKey(const ValueKey('tutorial-group')));
    expect(b.label, 'REPETIR EN GRUPO');
    expect(b.reason, 'Lo inicia el host');
  });

  testWidgets('panel lateral: SIGUIENTE, "Esperando" y menú',
      (tester) async {
    var next = 0;
    TutorialControl? op;
    await _pump(
        tester,
        TutorialOverlay(
          battle: const SizedBox.expand(key: ValueKey('arena')),
          banner: const TutorialBanner('TE TOCA: usar Bola de Fuego',
              yourTurn: true, stage: 'Etapa 5/10 · Afinidades'),
          card: const TutorialCard(
              ['Golpe a la debilidad: DÉBIL ×1.5 (35 de daño).'],
              arrow: TutorialArrow.hp,
              effect: true),
          waitingText: 'Esperando: Beto',
          rules: const TutorialRules(),
          onNext: () => next++,
          onControl: (o) => op = o,
        ));
    expect(find.text('Etapa 5/10 · Afinidades'), findsOneWidget);
    expect(find.text('Esperando: Beto'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tutorial-next')));
    expect(next, 1);
    await tester.tap(find.byKey(const ValueKey('tutorial-menu')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tutorial-menu-glossary')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tutorial-glossary')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tutorial-repeatStage')));
    expect(op, TutorialControl.repeatStage);
  });

  testWidgets('panel lateral: votación del final y narrador de ENTRENAR',
      (tester) async {
    String? picked;
    await _pump(
        tester,
        TutorialOverlay(
          battle: const SizedBox.expand(),
          banner: const TutorialBanner('¡Guion completo! Votá cómo seguir en el panel.',
              stage: 'Fin del guion'),
          card: null,
          rules: const TutorialRules(),
          onNext: () {},
          onControl: (_) {},
          options: const [('repeat', 'REPETIR TUTORIAL'), ('train', 'IR A ENTRENAR'), ('exit', 'SALIR')],
          pickLines: const ['Ana: SALIR', 'Beto: eligiendo…'],
          myPick: 'exit',
          onPick: (c) => picked = c,
        ));
    expect(find.text('VOTACION'), findsOneWidget); // DsSectionHeader
    expect(find.text('Beto: eligiendo…'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tutorial-pick-train')));
    expect(picked, 'train');
    await _pump(
        tester,
        TutorialOverlay(
          battle: const SizedBox.expand(),
          banner: const TutorialBanner('ENTRENAR: probá', stage: 'ENTRENAR'),
          card: null,
          rules: const TutorialRules(),
          onNext: () {},
          onControl: (_) {},
          narration: const ['Ana: Golpe a la debilidad (×1.5, 40 de daño).'],
        ));
    expect(find.text('LO QUE PASA'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-narration')), findsOneWidget);
  });

  testWidgets('panel lateral: sin cartel muestra AHORA; ya votado, '
      'SIGUIENTE desactivado', (tester) async {
    await _pump(
        tester,
        TutorialOverlay(
          battle: const SizedBox.expand(),
          banner: const TutorialBanner('MIRÁ: Beto va a defender',
              stage: 'Etapa 1/10 · Línea de tiempo'),
          card: null,
          last: const TutorialCard(['Defender: mitad del daño.'],
              effect: true),
          rules: const TutorialRules(),
          onNext: () {},
          onControl: (_) {},
        ));
    expect(find.textContaining('Beto va a defender'), findsOneWidget);
    expect(find.textContaining('mitad del da'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-next')), findsNothing);
    await _pump(
        tester,
        TutorialOverlay(
          battle: const SizedBox.expand(),
          banner: null,
          card: const TutorialCard(['x']),
          voted: true,
          rules: const TutorialRules(),
          onNext: () {},
          onControl: (_) {},
        ));
    expect(find.byKey(const ValueKey('tutorial-next')), findsNothing);
    expect(find.byKey(const ValueKey('tutorial-voted')), findsOneWidget);

  });

  for (final size in const [Size(1280, 720), Size(1920, 1080), Size(900, 600)]) {
    testWidgets('el panel no se superpone con la escena, el HUD ni el menú '
        '($size)', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Combatant hero(String id, String cls) => Combatant(
          id: id,
          name: id,
          isPlayer: true,
          hp: 150,
          maxHp: 150,
          mp: 40,
          maxMp: 40,
          speed: 10,
          attack: 18,
          critChance: 0,
          classId: cls);
      final b = BattleState(party: [
        hero('p1', 'guerrero'),
        hero('p2', 'maga'),
        hero('p3', 'tirador'),
        hero('p4', 'paladin'),
      ], enemies: [
        const TutorialRules().automaton(4)
      ])
        ..currentId = 'p1';
      await tester.pumpWidget(ProviderScope(child: MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(
          body: TutorialOverlay(
            battle: BattleView(
                battle: b, localId: 'p1', canAct: true, onCommand: (_) => true),
            banner: const TutorialBanner('TE TOCA: usar Bola de Fuego',
                yourTurn: true, stage: 'Etapa 2/9 · MP y Pulso'),
            card: const TutorialCard(['Ana: −3 MP (quedan 37).'],
                arrow: TutorialArrow.mp, effect: true),
            waitingText: 'Esperando: Beto',
            voted: true,
            hud: const {HudHighlight.mp, HudHighlight.pulse},
            rules: const TutorialRules(),
            onNext: () {},
            onControl: (_) {},
          ),
        ),
      )));
      await tester.pump();
      final panel = tester.getRect(find.byKey(const ValueKey('tutorial-panel')));
      final scene = tester.getRect(find.byType(BattleView));
      expect(panel.overlaps(scene), isFalse, reason: '$panel vs $scene');
      expect(panel.right, closeTo(size.width, 0.5));
      // Todo lo de la pelea (combatientes, HUD, menú) cae dentro de la
      // escena, a la izquierda del panel.
      for (final f in [
        find.byKey(const ValueKey('pulse-p1')),
        find.byKey(const ValueKey('pulse-p4')),
        find.byType(BattleCommandWindow),
      ]) {
        for (final e in f.evaluate()) {
          final r = tester.getRect(find.byWidget(e.widget));
          expect(r.overlaps(panel), isFalse, reason: '$r vs $panel');
        }
      }
      // El HUD resalta la barra de MP y los pips de Pulso.
      expect(find.byKey(const ValueKey('hl-mp-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('hl-pulse-p1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}