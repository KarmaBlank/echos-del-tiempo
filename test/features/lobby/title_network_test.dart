import 'package:echos_del_tiempo/app/design/design.dart';
import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
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
import 'title_flow.dart';

Future<void> _pump(WidgetTester tester, NetSessionFactory factory) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
      // Con un personaje: la sala se arma desde la lista.
      accountRepositoryProvider.overrideWithValue(AccountRepository(
          InMemoryAccountStore(
              CharacterRules(progression).create(Account(), 'Ana', 'maga')))),
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
    .widget<DsButton>(find.ancestor(
        of: find.text(label), matching: find.byType(DsButton)))
    .onPressed;

void main() {
  testWidgets('P2P sin Firebase: deshabilitado con el motivo', (tester) async {
    await _pump(tester,
        NetSessionFactory.unavailable('P2P', 'P2P por internet: falta configurar Firebase'));
    await goToCoop(tester);
    expect(find.text('P2P por internet: falta configurar Firebase'), findsOneWidget);
    expect(_onPressed(tester, 'CREAR SALA'), isNull);
    expect(_onPressed(tester, 'UNIRSE'), isNull);
  });

  testWidgets('red disponible: unirse pide el código y muestra el error',
      (tester) async {
    final hub = LoopbackHub();
    await _pump(
        tester,
        NetSessionFactory(
            label: 'LAN',
            codeHint: 'IP:PUERTO',
            create: () => LoopbackNetSession(hub)));
    await goToCoop(tester);
    expect(find.text('Red: LAN'), findsOneWidget);
    expect(_onPressed(tester, 'CREAR SALA'), isNotNull);

    // UNIRSE: un paso con solo el campo del código.
    await tapTitleKey(tester, 'title-join-step');
    expect(find.byKey(const ValueKey('title-code')), findsOneWidget);
    expect(find.text('IP:PUERTO'), findsOneWidget);
    await tapTitleKey(tester, 'title-join-next');
    expect(find.text('Escribí el código de la sala.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('title-code')), 'ZZZZ9');
    await tapTitleKey(tester, 'title-join-next');
    expect(find.byKey(const ValueKey('char-play')), findsOneWidget);
    expect(find.text('> UNIRSE'), findsOneWidget);
    await tapTitleKey(tester, 'char-play');
    await tester.pump();
    expect(find.byKey(const ValueKey('title-net-status')), findsOneWidget);
    expect(find.textContaining('no encontrada'), findsOneWidget);
    // Se puede volver a intentar.
    expect(_onPressed(tester, '> UNIRSE'), isNotNull);
  });

  testWidgets('VOLVER deshace cada paso hasta el menú', (tester) async {
    await _pump(
        tester,
        NetSessionFactory(
            label: 'LAN',
            codeHint: 'IP:PUERTO',
            create: () => LoopbackNetSession(LoopbackHub())));
    await goToHostCharacters(tester);
    expect(find.text('> CREAR SALA'), findsOneWidget);
    for (final step in ['worlds', 'coop', 'mode', 'menu']) {
      await tapTitleKey(tester, 'title-back');
      expect(find.byKey(ValueKey('title-step-$step')), findsOneWidget,
          reason: step);
    }
  });
}