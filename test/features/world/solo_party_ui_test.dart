import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/party_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_battle_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import 'world_test_helpers.dart';

/// UI de la party jugando solo (docs/specs/solo_party.md § 2 y § 4).

/// Ana (guerrera, elegida), Leo (maga) y Mia (tiradora).
Account _account({List<String> party = const []}) {
  var a = Account();
  a = a.add(newProfile('Ana', 'guerrero'))!;
  a = a.add(newProfile('Leo', 'maga'))!;
  a = a.add(newProfile('Mia', 'tirador'))!;
  return a.select('c1').withParty(party);
}

/// Texto plano de todos los `RichText` (ProtoText) y `Text`.
bool _hasText(String s) =>
    find
        .byWidgetPredicate((w) =>
            (w is RichText && w.text.toPlainText().contains(s)) ||
            (w is Text && (w.data ?? '').contains(s)))
        .evaluate()
        .isNotEmpty;

Future<void> _size(WidgetTester tester) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// La sesión local sobre [repo] dibujando [build].
Future<SessionController> _pumpSession(WidgetTester tester, AccountRepository repo,
    Widget Function(SessionView view, SessionController c) build) async {
  await _size(tester);
  late SessionController controller;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider
          .overrideWithValue(SelectedCharacterProfileStore(repo)),
      accountRepositoryProvider.overrideWithValue(repo),
      partyStoreProvider.overrideWithValue(AccountPartyStore(repo)),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
    ],
    child: MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          final view = ref.watch(sessionControllerProvider);
          controller = ref.read(sessionControllerProvider.notifier);
          if (view == null) return const SizedBox.shrink();
          return build(view, controller);
        }),
      ),
    ),
  ));
  // La sesión carga la cuenta y la party (asíncrono).
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return controller;
}

void main() {
  testWidgets('título: PARTY tú + N, elegir y sacar compañeros', (tester) async {
    await _size(tester);
    final repo = AccountRepository(InMemoryAccountStore(_account()));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine()),
        profileStoreProvider
            .overrideWithValue(SelectedCharacterProfileStore(repo)),
        accountRepositoryProvider.overrideWithValue(repo),
        gameSpritesProvider
            .overrideWith((ref) => Completer<GameSprites>().future),
      ],
      child: MaterialApp(
        theme: RetroTheme.build(),
        home: TitleScreen(onStart: () {}),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('PARTY: tú + 0'), findsOneWidget);
    // El líder no aparece como candidato.
    expect(find.byKey(const ValueKey('party-pick-c1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('party-pick-c2')));
    await tester.pump();
    await tester.pump();
    expect(repo.current!.companions, ['c2']);
    expect(find.text('PARTY: tú + 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('party-solo-note')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('party-pick-c3')));
    await tester.pump();
    await tester.pump();
    expect(repo.current!.companions, ['c2', 'c3']);
    // Sacar a Leo.
    await tester.tap(find.byKey(const ValueKey('party-pick-c2')));
    await tester.pump();
    await tester.pump();
    expect(repo.current!.companions, ['c3']);
    // Elegir a Mia como líder la saca de la party.
    await repo.update((a) => a.select('c3'));
    await tester.pump();
    expect(repo.current!.companions, isEmpty);
    expect(find.text('PARTY: tú + 0'), findsOneWidget);
  });

  testWidgets('pueblo: PARTY [P] agrega, saca y prende AUTO', (tester) async {
    final repo =
        AccountRepository(InMemoryAccountStore(_account(party: ['c2'])));
    final c = await _pumpSession(
        tester,
        repo,
        (view, c) => view.panel == WorldPanel.party
            ? PartyPanel(view: view, controller: c)
            : const SizedBox.shrink());
    expect(c.companionIds, ['local-c2']);
    expect(c.handleKey(LogicalKeyboardKey.keyP), isTrue);
    await tester.pump();
    expect(find.byKey(const ValueKey('panel-party')), findsOneWidget);
    expect(find.text('PARTY: tú + 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('party-pick-c3')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();
    expect(c.companionIds, ['local-c2', 'local-c3']);
    expect(find.text('PARTY: tú + 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('party-auto-c3')));
    await tester.pump();
    expect(c.isAuto('local-c3'), isTrue);
    await tester.tap(find.byKey(const ValueKey('party-pick-c2')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();
    expect(c.companionIds, ['local-c3']);
    // Fuera del pueblo no se abre.
    c.closePanel();
    expect(c.proposeMission('m1'), isTrue);
    expect(c.handleKey(LogicalKeyboardKey.keyP), isFalse);
  });

  testWidgets('batalla: turno del compañero y su AUTO', (tester) async {
    final repo =
        AccountRepository(InMemoryAccountStore(_account(party: ['c2'])));
    final c = await _pumpSession(
        tester,
        repo,
        (view, c) => view.session.battle == null
            ? const SizedBox.shrink()
            : SessionBattleScreen(
                view: view, onCommand: c.battleCommand, onAuto: c.setAuto));
    expect(c.proposeMission('m1'), isTrue);
    c.advance(0.1);
    c.setReady(true);
    c.advance(0.1);
    startBattleWithFirstGroup(c);
    expect(c.session!.mode, SessionMode.battle);
    // Hasta el turno de Leo (el líder defiende en el suyo).
    for (var i = 0; i < 2000; i++) {
      final b = c.session!.battle;
      if (b == null) break;
      if (b.waitingForPlayer && b.state.currentId == 'local-c2') break;
      if (c.view!.myTurn) c.battleCommand(const DefendCommand());
      c.advance(0.05);
    }
    await tester.pump();
    expect(c.view!.myTurn, isTrue);
    expect(_hasText('Turno de Leo (compañero)'), isTrue);
    expect(find.byKey(const ValueKey('battle-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('auto-toggle-local-c2')), findsOneWidget);
    expect(find.byKey(const ValueKey('auto-toggle-local')), findsNothing,
        reason: 'el líder no tiene AUTO');
    await tester.tap(find.byKey(const ValueKey('auto-toggle-local-c2')));
    await tester.pump();
    expect(c.isAuto('local-c2'), isTrue);
    expect(c.view!.myTurn, isFalse);
    expect(_hasText('Turno de Leo (AUTO)'), isTrue);
    // A los 0.5 s actúa solo.
    c.advance(SessionController.autoDelay + 0.1);
    expect(c.session!.battle?.state.currentId, isNot('local-c2'));
  });

  testWidgets('batalla: el compañero manual puede PASAR (v0.8.3)',
      (tester) async {
    final repo =
        AccountRepository(InMemoryAccountStore(_account(party: ['c2'])));
    final c = await _pumpSession(
        tester,
        repo,
        (view, c) => view.session.battle == null
            ? const SizedBox.shrink()
            : SessionBattleScreen(
                view: view, onCommand: c.battleCommand, onAuto: c.setAuto));
    expect(c.proposeMission('m1'), isTrue);
    c.advance(0.1);
    c.setReady(true);
    c.advance(0.1);
    startBattleWithFirstGroup(c);
    for (var i = 0; i < 2000; i++) {
      final b = c.session!.battle;
      if (b == null) break;
      if (b.waitingForPlayer && b.state.currentId == 'local-c2') break;
      if (c.view!.myTurn) c.battleCommand(const DefendCommand());
      c.advance(0.05);
    }
    await tester.pump();
    expect(_hasText('Turno de Leo (compañero)'), isTrue);
    final before = c.session!.battle!.state;
    final leo = before.party.firstWhere((p) => p.id == 'local-c2');
    // Sin buffs de velocidad ni Congelación: IV = 100 / velocidad.
    final iv = 100 / leo.speed;
    await tester.tap(find.byKey(const ValueKey('battle-cat-pass')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('battle-act-pass')));
    await tester.pump();
    final after = c.session!.battle!.state;
    final leo2 = after.party.firstWhere((p) => p.id == 'local-c2');
    expect(after.currentId, isNot('local-c2'));
    expect(leo2.ult, leo.ult);
    expect(leo2.defending, isFalse);
    expect(leo2.nextTurn, closeTo(before.clock + iv * 0.5, 1e-6));
  });
}
