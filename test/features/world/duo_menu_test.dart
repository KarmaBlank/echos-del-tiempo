import 'package:echos_del_tiempo/app/design/ds_components.dart';
import 'package:echos_del_tiempo/app/feature_flags.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_battle_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import '../../support/legacy_solo_mode.dart';
import 'world_test_helpers.dart';

/// DUOS in battle with a solo-party companion: tapping a duo must perform
/// it (it used to only reset the menu to WEAPON).

/// Ana (warrior, selected) and Leo (mage) as her companion.
Account _account() {
  var a = Account();
  a = a.add(newProfile('Ana', 'guerrero'))!;
  a = a.add(newProfile('Leo', 'maga'))!;
  return a.select('c1').withParty(['c2']);
}

Future<SessionController> _pumpBattle(WidgetTester tester) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = AccountRepository(InMemoryAccountStore(_account()));
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
          if (view == null || view.session.battle == null) {
            return const SizedBox.shrink();
          }
          return SessionBattleScreen(
              view: view,
              onCommand: controller.battleCommand,
              onAuto: controller.setAuto);
        }),
      ),
    ),
  ));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  final c = controller;
  expect(c.proposeMission('m1'), isTrue);
  c.advance(0.1);
  c.setReady(true);
  c.advance(0.1);
  startBattleWithFirstGroup(c);
  for (var i = 0; i < 2000 && c.session!.battle != null; i++) {
    if (c.view!.myTurn) break;
    c.advance(0.05);
  }
  await tester.pump();
  expect(c.view!.myTurn, isTrue);
  return c;
}

void main() {
  setUpAll(() => FeatureFlags.instance = const FeatureFlags(soloParty: true));
  tearDownAll(() => FeatureFlags.instance = const FeatureFlags());

  Finder duoRows() => find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('battle-act-duo-'));

  Future<void> tapDuo(WidgetTester tester) async {
    final c = await _pumpBattle(tester);
    final st = c.session!.battle!.state;
    await tester.tap(find.byKey(const ValueKey('battle-cat-duos')));
    await tester.pump();
    expect(duoRows(), findsWidgets);
    final mpBefore = {for (final p in st.party) p.id: p.mp};
    await tester.tap(duoRows().first);
    await tester.pump();
    final after = c.session!.battle!.state;
    expect(after.party.where((p) => p.mp < mpBefore[p.id]!), hasLength(2),
        reason: 'the duo spends MP from both partners');
  }

  testWidgets('DUOS: tapping a duo performs it (default: Por fases)', tapDuo);

  testWidgets(
      'DUOS (Por fases): a partner who already acted this phase is not '
      'offered as an enabled duo', (tester) async {
    final c = await _pumpBattle(tester);
    // The leader acts first; then it's the companion's turn in the phase.
    expect(c.battleCommand(const DefendCommand()), isTrue);
    for (var i = 0; i < 100 && !c.view!.myTurn; i++) {
      c.advance(0.05);
    }
    await tester.pump();
    final st = c.session!.battle!.state;
    expect(c.view!.groupActor, 'local-c2');
    expect(st.acted, contains('local'));
    // The only duo (with Ana) is unavailable: DUOS is grayed out
    // (disabled-buttons rule) instead of an enabled row the engine rejects.
    final tab = find.byKey(const ValueKey('battle-cat-duos'));
    expect(tester.widget<DsListRow>(tab).enabled, isFalse,
        reason: 'Ana already acted: the engine would reject the duo');
    // Keyboard/selection path: the duo row itself is disabled too.
    final bv = tester.state<BattleViewState>(find.byType(BattleView));
    bv.selectCategory(BattleCategory.duos);
    await tester.pump();
    final row = find.byKey(const ValueKey('battle-act-duo-local'));
    expect(row, findsOneWidget);
    expect(
        tester
            .widget<DsListRow>(
                find.descendant(of: row, matching: find.byType(DsListRow)))
            .enabled,
        isFalse);
    await tester.tap(row);
    await tester.pump();
    expect(c.session!.battle!.state.logLine, st.logLine);
  });

  group('timeline', () {
    useTimelineSoloDefault();
    testWidgets('DUOS: tapping a duo performs it (timeline)', tapDuo);
  });
}
