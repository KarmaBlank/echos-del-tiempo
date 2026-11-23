import '../../support/legacy_solo_mode.dart';
import 'dart:async';

import 'package:echos_del_tiempo/app/feature_flags.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/party_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_battle_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
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
  useTimelineSoloDefault();
  // La party jugando solo está detrás de FeatureFlags.soloParty
  // (apagada en la build principal desde v0.9.14).
  setUpAll(() => FeatureFlags.instance = const FeatureFlags(soloParty: true));
  tearDownAll(() => FeatureFlags.instance = const FeatureFlags());
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

  // v0.8.3: el selector de miembro (solo_party.md § 6).
  testWidgets('personaje: el selector elige a quién se le reparten los '
      'puntos; Ctrl+←/→ cambia', (tester) async {
    var a = Account();
    a = a.add(newProfile('Ana', 'guerrero'))!;
    a = a.add(progression
        .normalize(newProfile('Leo', 'maga').copyWith(level: 5)))!;
    a = a.add(newProfile('Mia', 'tirador'))!;
    final repo = AccountRepository(
        InMemoryAccountStore(a.select('c1').withParty(['c2', 'c3'])));
    final c = await _pumpSession(
        tester,
        repo,
        (view, c) => view.panel == WorldPanel.character
            ? CharacterPanel(view: view, controller: c)
            : const SizedBox.shrink());
    c.openPanel(WorldPanel.character);
    await tester.pump();
    expect(find.byKey(const ValueKey('party-member-bar')), findsOneWidget);
    expect(find.text('Ana (vos)'), findsOneWidget);
    expect(find.byKey(const ValueKey('member-local-c2')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-local-c3')), findsOneWidget);
    // Leo tiene puntos: su insignia +N; Ana y Mia no.
    expect(find.byKey(const ValueKey('member-points-local-c2')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-points-local')), findsNothing);
    expect(c.view!.actorId, 'local');

    await tester.tap(find.byKey(const ValueKey('member-local-c2')));
    await tester.pump();
    expect(c.view!.actorId, 'local-c2');
    expect(_hasText('Leo'), isTrue);
    final leo0 = c.session!.players['local-c2']!.profile;
    final ana0 = c.session!.players['local']!.profile;
    await tester.tap(find.byKey(const ValueKey('inc-vit')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-points')));
    await tester.pump();
    final leo = c.session!.players['local-c2']!.profile;
    expect(leo.attributes[Attribute.vit], leo0.attributes[Attribute.vit] + 3);
    expect(leo.points, leo0.points - 1);
    final ana = c.session!.players['local']!.profile;
    expect(ana.attributes[Attribute.vit], ana0.attributes[Attribute.vit],
        reason: 'el punto fue para Leo, no para Ana');
    expect(ana.points, ana0.points);

    // Teclado: Ctrl+→ siguiente (Mia), Ctrl+← anterior (en círculo).
    Future<void> ctrl(LogicalKeyboardKey k) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(k);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    await ctrl(LogicalKeyboardKey.arrowRight);
    expect(c.view!.actorId, 'local-c3');
    await ctrl(LogicalKeyboardKey.arrowRight);
    expect(c.view!.actorId, 'local', reason: 'en círculo');
    await ctrl(LogicalKeyboardKey.arrowLeft);
    expect(c.view!.actorId, 'local-c3');
    // Las pestañas siguen con Q / E.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(find.byKey(const ValueKey('party-member-bar')), findsOneWidget);
    expect(c.view!.actorId, 'local-c3');
  });

  testWidgets('sin compañeros no hay selector', (tester) async {
    final repo = AccountRepository(InMemoryAccountStore(_account()));
    final c = await _pumpSession(
        tester,
        repo,
        (view, c) => view.panel == WorldPanel.character
            ? CharacterPanel(view: view, controller: c)
            : const SizedBox.shrink());
    c.openPanel(WorldPanel.character);
    await tester.pump();
    expect(find.byKey(const ValueKey('party-member-bar')), findsNothing);
    expect(c.setActing('local-c2'), isFalse);
    expect(c.view!.actorId, 'local');
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
    // A los 0.5 s actúa solo. Si prepara con una Instante (combo_balance.md
    // § 5.2) el turno sigue y hace una acción más.
    c.advance(SessionController.autoDelay + 0.1);
    for (var i = 0;
        i < 20 && c.session!.battle?.state.currentId == 'local-c2';
        i++) {
      c.advance(0.25);
    }
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

  group('sin FeatureFlags.soloParty (build principal, v0.9.14)', () {
    setUp(() => FeatureFlags.instance = const FeatureFlags());
    tearDown(
        () => FeatureFlags.instance = const FeatureFlags(soloParty: true));

    testWidgets('título: no hay sección PARTY', (tester) async {
      await _size(tester);
      final repo = AccountRepository(
          InMemoryAccountStore(_account(party: ['c2'])));
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
      expect(_hasText('PARTY'), isFalse);
      expect(find.byKey(const ValueKey('party-pick-c2')), findsNothing);
      expect(find.byKey(const ValueKey('party-solo-note')), findsNothing);
      // La party guardada no se borra: solo se ignora.
      expect(repo.current!.companions, ['c2']);
    });

    testWidgets('sesión: la party guardada se ignora, sin compañeros',
        (tester) async {
      final repo = AccountRepository(
          InMemoryAccountStore(_account(party: ['c2', 'c3'])));
      final c = await _pumpSession(
          tester,
          repo,
          (view, c) => view.panel == WorldPanel.character
              ? CharacterPanel(view: view, controller: c)
              : const SizedBox.shrink());
      expect(c.companionIds, isEmpty);
      expect(c.view!.companions, isEmpty);
      // El sello del tutorial cuenta compañeros de la sala: ninguno.
      expect(c.view!.session.playerList.where((p) => p.isCompanion),
          isEmpty);
      expect(c.canEditParty, isFalse);
      expect(c.handleKey(LogicalKeyboardKey.keyP), isFalse);
      c.openPanel(WorldPanel.character);
      await tester.pump();
      expect(find.byKey(const ValueKey('party-member-bar')), findsNothing);
      expect(repo.current!.companions, ['c2', 'c3']);
    });
  });
}
