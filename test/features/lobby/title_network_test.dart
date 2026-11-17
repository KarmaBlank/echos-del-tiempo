import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session_factory.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

Future<void> _pump(WidgetTester tester, NetSessionFactory factory) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
      gameSpritesProvider
          .overrideWith((ref) => Completer<GameSprites>().future),
      netSessionFactoryProvider.overrideWithValue(factory),
    ],
    child: MaterialApp(theme: RetroTheme.build(), home: const TitleScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

VoidCallback? _onPressed(WidgetTester tester, String label) => tester
    .widget<ElevatedButton>(find.ancestor(
        of: find.text(label), matching: find.byType(ElevatedButton)))
    .onPressed;

void main() {
  testWidgets('P2P sin Firebase: deshabilitado con el motivo', (tester) async {
    await _pump(tester,
        NetSessionFactory.unavailable('P2P', 'P2P por internet: falta configurar Firebase'));
    expect(find.text('P2P por internet: falta configurar Firebase'), findsOneWidget);
    expect(_onPressed(tester, 'CREAR SALA'), isNull);
    expect(_onPressed(tester, 'UNIRSE'), isNull);
  });

  testWidgets('red disponible: unirse exige código y muestra el error',
      (tester) async {
    final hub = LoopbackHub();
    await _pump(
        tester,
        NetSessionFactory(
            label: 'LAN',
            codeHint: 'IP:PUERTO',
            create: () => LoopbackNetSession(hub)));
    expect(find.text('Red: LAN'), findsOneWidget);
    expect(find.text('IP:PUERTO'), findsOneWidget);
    expect(_onPressed(tester, 'CREAR SALA'), isNotNull);

    await tester.tap(find.text('UNIRSE'));
    await tester.pump();
    expect(find.text('Escribe el código de la sala.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('title-code')), 'ZZZZ9');
    await tester.tap(find.text('UNIRSE'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('title-net-status')), findsOneWidget);
    expect(find.textContaining('no encontrada'), findsOneWidget);
    // Se puede volver a intentar.
    expect(_onPressed(tester, 'UNIRSE'), isNotNull);
  });
}
