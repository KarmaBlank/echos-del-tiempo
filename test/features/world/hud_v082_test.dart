import 'package:echos_del_tiempo/app/theme/party_box.dart';
import 'package:echos_del_tiempo/app/theme/retro_panel.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/party_store.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

/// HUD v0.8.2: cajas del grupo compactas por defecto, se despliegan con
/// clic o H y se recuerda (docs/specs/exploration.md § "HUD").

/// Ana (líder) + Leo, Mia y Cid en la party, ya en la zona 1.
Future<SessionController> _party4() async {
  final c = SessionController(
    engine: sessionEngine(zones: true),
    store: InMemoryProfileStore(zoneProgression.normalize(
        PlayerProfile(name: 'Ana', classId: 'guerrero', unlockedZone: 1))),
    party: InMemoryPartyStore(slots: {
      's2': zoneProgression
          .normalize(PlayerProfile(name: 'Leo', classId: 'maga')),
      's3': zoneProgression
          .normalize(PlayerProfile(name: 'Mia', classId: 'tirador')),
      's4': zoneProgression
          .normalize(PlayerProfile(name: 'Cid', classId: 'paladin')),
    }, party: const [
      's2',
      's3',
      's4'
    ]),
    clock: const SessionClock(autoStart: false),
  );
  await c.start();
  final e = c.view!.map.entrances.firstWhere((e) => e.zone == 1);
  c.teleport(e.front.x, e.front.y);
  c.advance(0.05);
  c.handleKey(LogicalKeyboardKey.keyE);
  c.advance(0.05);
  c.setReady(true);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.field);
  expect(c.view!.session.playerList.length, 4);
  // Puntos sin usar (chip `+N`).
  final me = c.view!.session.players[c.view!.localId]!;
  me.profile = me.profile.copyWith(points: 3);
  return c;
}

Future<(SessionController, GameSettingsController)> _pumpHud(
    WidgetTester tester,
    {TextSize text = TextSize.normal,
    GameSettings? initial}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await _party4();
  addTearDown(c.dispose);
  final g = GameSettingsController(
      store: InMemoryGameSettingsStore(),
      initial: (initial ?? const GameSettings()).copyWith(textSize: text));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
      gameSettingsProvider.overrideWith((ref) => g),
    ],
    child: MaterialApp(
      theme: RetroTheme.build(),
      builder: (context, child) =>
          RetroTextScale(factor: text.factor, child: child!),
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            ref.watch(gameSettingsProvider);
            return WorldHud(
                view: c.view!, controller: c, chatFocus: FocusNode());
          },
        ),
      ),
    ),
  ));
  await tester.pump();
  return (c, g);
}

void main() {
  setUpAll(loadRealFonts);

  group('ajustes', () {
    test('partyExpanded: por defecto compactas, aditivo y se guarda', () {
      expect(const GameSettings().partyExpanded, isFalse);
      expect(
          GameSettings.fromJson(const {'shake': false}).partyExpanded, isFalse);
      const s = GameSettings(partyExpanded: true);
      expect(s.toJson()['partyExpanded'], true);
      expect(GameSettings.fromJson(s.toJson()), s);
      expect(s, isNot(const GameSettings()));
    });
  });

  testWidgets('compactas por defecto: una fila fina, 4 miembros',
      (tester) async {
    final (c, _) = await _pumpHud(tester);
    final boxes = find.byType(CompactPlayerBox);
    expect(boxes, findsNWidgets(4));
    expect(find.byType(PartyBox), findsNWidgets(4));
    // Sin arma ni pociones en la compacta.
    expect(find.textContaining('Pociones'), findsNothing);
    final area = tester.getRect(find.byKey(const ValueKey('hud-party-boxes')));
    // Una franja fina: menos de 1/10 del alto (antes ~1/3).
    expect(area.height, lessThan(60), reason: '$area');
    final local = c.view!.localId;
    expect(find.byKey(ValueKey('hud-hp-$local')), findsOneWidget);
    expect(find.byKey(ValueKey('hud-mp-$local')), findsOneWidget);
    // Puntos sin usar: chip dorado.
    expect(
        tester
            .widget<Text>(find.byKey(ValueKey('hud-level-$local')))
            .textSpan!
            .toPlainText(),
        contains('+3'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('clic despliega (y se guarda); otro clic compacta',
      (tester) async {
    final (c, g) = await _pumpHud(tester);
    final local = c.view!.localId;
    await tester.tap(find.byKey(ValueKey('hud-party-$local')));
    await tester.pump();
    expect(g.state.partyExpanded, isTrue);
    expect((g.store as InMemoryGameSettingsStore).saved?.partyExpanded, isTrue);
    expect(find.byType(CompactPlayerBox), findsNothing);
    expect(find.byType(PartyBox), findsNWidgets(4));
    expect(find.textContaining('Pociones'), findsNWidgets(4));
    await tester.tap(find.byKey(ValueKey('hud-party-$local')));
    await tester.pump();
    expect(g.state.partyExpanded, isFalse);
    expect(find.byType(CompactPlayerBox), findsNWidgets(4));
  });

  testWidgets('guardado desplegado: arranca desplegado', (tester) async {
    await _pumpHud(tester, initial: const GameSettings(partyExpanded: true));
    expect(find.byType(CompactPlayerBox), findsNothing);
    expect(find.textContaining('Pociones'), findsNWidgets(4));
  });

  for (final text in [TextSize.normal, TextSize.huge, TextSize.enormous]) {
    testWidgets(
        'compactas: no pisan chat, objetivos ni minimapa (${text.name})',
        (tester) async {
      final (_, _) = await _pumpHud(tester, text: text);
      final party = [
        for (final e in find.byType(CompactPlayerBox).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ];
      expect(party, hasLength(4));
      final others = <String, Rect>{
        'chat': tester.getRect(find.byKey(const ValueKey('chat-pill'))),
        'objetivos':
            tester.getRect(find.byKey(const ValueKey('hud-objectives'))),
        'minimapa': tester.getRect(find
            .ancestor(
                of: find.byType(Minimap), matching: find.byType(RetroPanel))
            .first),
      };
      for (final r in party) {
        expect(r.right, lessThanOrEqualTo(1280));
        expect(r.bottom, lessThanOrEqualTo(720));
        for (final MapEntry(:key, :value) in others.entries) {
          expect(r.overlaps(value), isFalse, reason: '$key $value vs $r');
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('H despliega / compacta en el mapa', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late GameSprites sprites;
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine()),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
        gameSpritesProvider.overrideWith((ref) => sprites),
      ],
      child: MaterialApp(theme: RetroTheme.build(), home: const WorldScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(WorldScreen)));
    expect(find.byType(CompactPlayerBox), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(container.read(gameSettingsProvider).partyExpanded, isTrue);
    expect(find.byType(CompactPlayerBox), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    expect(container.read(gameSettingsProvider).partyExpanded, isFalse);
    expect(find.byType(CompactPlayerBox), findsOneWidget);
  });
}
