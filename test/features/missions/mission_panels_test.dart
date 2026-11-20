import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/missions/domain/mission_text.dart';
import 'package:echos_del_tiempo/features/missions/presentation/mission_board_panel.dart';
import 'package:echos_del_tiempo/features/missions/presentation/prep_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

String _plain(WidgetTester tester, Finder f) {
  final t = tester.widget<Text>(find
      .descendant(of: f, matching: find.byType(Text), matchRoot: true)
      .first);
  return t.textSpan?.toPlainText() ?? t.data!;
}

void main() {
  const cat = GameCatalog.standard;

  testWidgets('mostrador: tarjetas con objetivo, recompensas y proponer',
      (tester) async {
    String? proposed;
    var closed = 0;
    await _pump(
        tester,
        MissionBoardPanel(
          missions: cat.missions,
          voteOpen: false,
          bossName: (m) => missionBossName(cat, m),
          playerLevel: 1,
          onPropose: (id) => proposed = id,
          onClose: () => closed++,
        ));
    final m1 = cat.missions.first;
    final rewards =
        _plain(tester, find.byKey(ValueKey('mission-rewards-${m1.id}')));
    expect(find.text('RECOMPENSAS'), findsOneWidget);
    expect(rewards, contains('arma de tier 1'));
    expect(rewards, contains('cofres nivel ${m1.chestTier}'));
    // Misión de zona: el objetivo es por piso.
    expect(
        find.textContaining(
            'Derrota ${m1.floorGoal} grupos por piso (${m1.floors} pisos)'),
        findsOneWidget);
    // Nivel por debajo del recomendado: lo avisa.
    // Lista + detalle: la fila dice el nivel; el detalle avisa si estás
    // por debajo del recomendado.
    final m2 = cat.missions[1];
    await tester.tap(find.byKey(ValueKey('mission-${m2.id}')));
    await tester.pump();
    expect(find.textContaining('tu Lv 1'), findsWidgets);
    await tester.tap(find.byKey(ValueKey('mission-${m1.id}')));
    await tester.pump();
    expect(find.byKey(const ValueKey('panel-help')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('propose-${m1.id}')));
    expect(proposed, m1.id);

    // Esc cierra el panel.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closed, 1);
  });

  testWidgets('mostrador: con votación abierta, proponer dice por qué no',
      (tester) async {
    await _pump(
        tester,
        MissionBoardPanel(
          missions: cat.missions,
          voteOpen: true,
          onPropose: (_) {},
          onClose: () {},
        ));
    final b = tester.widget<DsButton>(find.byKey(ValueKey('propose-${cat.missions.first.id}')));
    expect(b.tooltip, 'Ya hay una votación');
    // Un solo PROPONER (el de la elegida), con el motivo al lado.
    expect(find.text('Ya hay una votación'), findsOneWidget);
    // Elegir otra fila cambia el detalle.
    final m2 = cat.missions[1];
    await tester.tap(find.byKey(ValueKey('mission-${m2.id}')));
    await tester.pump();
    expect(find.byKey(ValueKey('propose-${m2.id}')), findsOneWidget);
  });

  testWidgets('preparación: quién está listo y ¡LISTO! abajo a la derecha',
      (tester) async {
    bool? ready;
    await _pump(
        tester,
        PrepPanel(
          mission: cat.missions.first,
          players: const [
            PrepEntry('Ana', 'Guerrero', 3, ready: true, isLocal: true),
            PrepEntry('Bo', 'Maga', 2, ready: false),
          ],
          ready: false,
          credits: 120,
          weaponName: 'Espada de Bronce',
          potions: 2,
          ethers: 1,
          onReady: (v) => ready = v,
          onCancel: () {},
          onCharacter: () {},
        ));
    expect(find.textContaining('1/2 listos'), findsWidgets);
    expect(_plain(tester, find.byKey(const ValueKey('prep-player-Ana'))),
        contains('LISTO'));
    expect(_plain(tester, find.byKey(const ValueKey('prep-player-Bo'))),
        contains('preparando...'));
    expect(find.textContaining('Pociones x2'), findsOneWidget);
    // El primario está a la derecha de los demás botones.
    final readyX = tester.getCenter(find.byKey(const ValueKey('prep-ready'))).dx;
    final charX =
        tester.getCenter(find.byKey(const ValueKey('prep-character'))).dx;
    final cancelX =
        tester.getCenter(find.byKey(const ValueKey('prep-cancel'))).dx;
    expect(readyX, greaterThan(charX));
    expect(charX, greaterThan(cancelX));
    await tester.tap(find.byKey(const ValueKey('prep-ready')));
    expect(ready, isTrue);
  });
}
