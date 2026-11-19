import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/missions/presentation/mission_board_panel.dart';
import 'package:echos_del_tiempo/features/tutorial/presentation/tutorial_widgets.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Sello y batalla del TUTORIAL (docs/specs/combat_tutorial.md § 1, 4, 5).

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: RetroTheme.build(),
    home: Scaffold(body: child),
  ));
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
    final b = tester.widget<PanelButton>(find.byKey(ValueKey('propose-${m.id}')));
    expect(b.reason, lock);
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

  testWidgets('batalla: cartel del paso, cartel de efecto y menú',
      (tester) async {
    var closed = 0;
    TutorialControl? op;
    await _pump(
        tester,
        TutorialOverlay(
          banner: const TutorialBanner('TE TOCA: usar Bola de Fuego',
              yourTurn: true, stage: 'Etapa 3/10 · Afinidades'),
          card: const TutorialCard(
              ['Golpe a la debilidad: DÉBIL ×1.5 (35 de daño).'],
              arrow: TutorialArrow.hp,
              effect: true),
          rules: const TutorialRules(),
          attemptText: 'Intento 2: esta vez quebrás vos.',
          onCloseCard: () => closed++,
          onControl: (o) => op = o,
        ));
    expect(find.text('TE TOCA: usar Bola de Fuego'), findsOneWidget);
    expect(find.text('Intento 2: esta vez quebrás vos.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tutorial-card')));
    expect(closed, 1);
    await tester.tap(find.byKey(const ValueKey('tutorial-menu')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tutorial-menu-glossary')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tutorial-glossary')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tutorial-repeatStage')));
    expect(op, TutorialControl.repeatStage);
  });
}
