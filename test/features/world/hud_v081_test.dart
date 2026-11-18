import 'package:echos_del_tiempo/app/theme/party_box.dart';
import 'package:echos_del_tiempo/app/theme/retro_panel.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/chat_box.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

/// HUD v0.8.1: chat plegado por defecto y caja de objetivos plegable
/// (docs/specs/exploration.md § "Chat" y § "HUD").

Future<SessionController> _controller() async {
  final c = SessionController(
    engine: sessionEngine(zones: true),
    store: InMemoryProfileStore(zoneProgression.normalize(
        PlayerProfile(name: 'Ana', classId: 'guerrero', unlockedZone: 1))),
    clock: const SessionClock(autoStart: false),
  );
  await c.start();
  return c;
}

/// Entra a la zona 1 (dos pisos) y la arranca.
void _startZone1(SessionController c) {
  final e = c.view!.map.entrances.firstWhere((e) => e.zone == 1);
  c.teleport(e.front.x, e.front.y);
  c.advance(0.05);
  c.handleKey(LogicalKeyboardKey.keyE);
  c.advance(0.05);
  c.setReady(true);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.field);
}

void _size(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _chat(List<ChatLine> lines, FocusNode focus,
        {bool notices = true, VoidCallback? onDone}) =>
    MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: 300,
            child: ChatBox(
              lines: lines,
              focusNode: focus,
              onSend: (_) {},
              onDone: onDone ?? focus.unfocus,
              collapsible: true,
              notices: notices,
              localName: 'Yo',
            ),
          ),
        ),
      ),
    );

void main() {
  // Medidas con las fuentes de verdad (VT323 / Press Start 2P).
  setUpAll(loadRealFonts);

  group('ajustes', () {
    test('por defecto: chat oculto, avisos sí, objetivos desplegados', () {
      const d = GameSettings();
      expect(d.chat, ChatVisibility.hidden);
      expect(d.chatNotices, isTrue);
      expect(d.objectivesCollapsed, isFalse);
      // game.json viejo (sin las claves): los de por defecto.
      final old = GameSettings.fromJson({'shake': false});
      expect(old.chat, ChatVisibility.hidden);
      expect(old.chatNotices, isTrue);
      expect(old.objectivesCollapsed, isFalse);
    });

    test('se guardan y cargan (aditivo)', () {
      const s = GameSettings(
          chat: ChatVisibility.always,
          chatNotices: false,
          objectivesCollapsed: true);
      final j = s.toJson();
      expect(j['chat'], 'always');
      expect(j['chatNotices'], false);
      expect(j['objectivesCollapsed'], true);
      expect(GameSettings.fromJson(j), s);
      expect(
          GameSettings.fromJson({'chat': 'raro'}).chat, ChatVisibility.hidden);
    });
  });

  group('chat plegado', () {
    testWidgets('píldora, contador, avisos de 4 s y abrir/cerrar',
        (tester) async {
      _size(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final lines = <ChatLine>[const ChatLine('Ana', 'viejo')];
      await tester.pumpWidget(_chat(List.of(lines), focus));
      // Plegado: píldora sí; registro y campo fuera de escena.
      expect(find.byKey(const ValueKey('chat-pill')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-input')), findsNothing);
      expect(find.byKey(const ValueKey('chat-input'), skipOffstage: false),
          findsOneWidget);
      expect(find.byKey(const ValueKey('chat-unread')), findsNothing);

      // Llegan: 2 de otros, 1 propio, 1 de sistema común, 1 importante.
      lines.addAll([
        const ChatLine('Ana', 'hola'),
        const ChatLine('Yo', 'mío'),
        const ChatLine('Beto', 'vamos'),
        const ChatLine.system('Ana compró Espada'),
        const ChatLine.system('¡Misión aceptada! Fase de preparación'),
      ]);
      await tester.pumpWidget(_chat(List.of(lines), focus));
      expect(find.text('+2'), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-toast-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-toast-1')), findsNothing);
      expect(find.textContaining('¡Misión aceptada!', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('compró', findRichText: true), findsNothing);
      // El aviso dura 4 s.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('chat-toast-0')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1, milliseconds: 50));
      expect(find.byKey(const ValueKey('chat-toast-0')), findsNothing);

      // Clic en la píldora: se despliega con el foco en el campo y el
      // contador a 0.
      await tester.tap(find.byKey(const ValueKey('chat-pill')));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-pill')), findsNothing);
      expect(find.textContaining('vamos', findRichText: true), findsOneWidget);

      // Enter con el campo vacío lo pliega.
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(find.byKey(const ValueKey('chat-pill')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-unread')), findsNothing);
    });

    testWidgets('sin AVISOS DEL CHAT no hay avisos', (tester) async {
      _size(tester);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_chat(const [], focus, notices: false));
      await tester.pumpWidget(_chat([
        const ChatLine.system('¡Piso 1 despejado! Se abrió el paso.')
      ], focus, notices: false));
      expect(find.byKey(const ValueKey('chat-toast-0')), findsNothing);
    });

    test('líneas importantes', () {
      expect(
          isImportantChat(const ChatLine.system('¡Subida de nivel! Esperando')),
          isTrue);
      expect(
          isImportantChat(const ChatLine.system('Misión opcional fallida: x.')),
          isTrue);
      expect(isImportantChat(const ChatLine.system('Ana propone: X. ¡Voten!')),
          isTrue);
      expect(
          isImportantChat(const ChatLine.system('Ana soltó Espada')), isFalse);
      expect(isImportantChat(const ChatLine('Ana', '¡hola!')), isFalse);
    });

    testWidgets(
        'en el juego: oculto por defecto, Enter abre, Esc cierra, '
        'SIEMPRE VISIBLE', (tester) async {
      _size(tester);
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
        child:
            MaterialApp(theme: RetroTheme.build(), home: const WorldScreen()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final container =
          ProviderScope.containerOf(tester.element(find.byType(WorldScreen)));
      final c = container.read(sessionControllerProvider.notifier);
      expect(find.byKey(const ValueKey('chat-pill')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-input')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(c.typing, isTrue);
      expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-pill')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(c.typing, isFalse);
      expect(find.byKey(const ValueKey('chat-pill')), findsOneWidget);
      // Esc cerró el chat, no abrió la pausa.
      expect(find.byKey(const ValueKey('chat-input')), findsNothing);

      // SIEMPRE VISIBLE: registro + campo, sin píldora.
      final g = container.read(gameSettingsProvider.notifier);
      await g.update(container
          .read(gameSettingsProvider)
          .copyWith(chat: ChatVisibility.always));
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-pill')), findsNothing);
      expect(find.byKey(const ValueKey('chat-input')), findsOneWidget);
    });
  });

  group('objetivos', () {
    Future<(SessionController, GameSettingsController)> pumpHud(
        WidgetTester tester,
        {TextSize text = TextSize.normal}) async {
      final c = await _controller();
      addTearDown(c.dispose);
      _startZone1(c);
      final store = InMemoryGameSettingsStore();
      final g = GameSettingsController(
          store: store, initial: GameSettings(textSize: text));
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

    testWidgets('pliega con clic, resumen de una línea, se recuerda',
        (tester) async {
      _size(tester);
      final (c, g) = await pumpHud(tester);
      // Desplegada por defecto.
      expect(find.text('[-]'), findsOneWidget);
      expect(find.textContaining('Grupos del piso'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('hud-objectives-summary')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('hud-objectives-header')));
      await tester.pump();
      expect(g.state.objectivesCollapsed, isTrue);
      expect((g.store as InMemoryGameSettingsStore).saved?.objectivesCollapsed,
          isTrue);
      expect(find.text('[+]'), findsOneWidget);
      expect(find.textContaining('Grupos del piso'), findsNothing);
      final summary = tester
          .widget<Text>(find.byKey(const ValueKey('hud-objectives-summary')))
          .data!;
      expect(summary, startsWith('Piso 1/2 · Grupos 0/'));
      expect(objectivesSummaryText(c.view!.session.mission!, null),
          startsWith('Piso 1/2 · Grupos 0/'));
      // Una sola línea.
      final h = tester
          .getSize(find.byKey(const ValueKey('hud-objectives-summary')))
          .height;
      final line = tester
          .getSize(find.byKey(const ValueKey('hud-objectives-toggle')))
          .height;
      expect(h, lessThanOrEqualTo(line + 2 + 0.5));

      await tester.tap(find.byKey(const ValueKey('hud-objectives-header')));
      await tester.pump();
      expect(g.state.objectivesCollapsed, isFalse);
      expect(find.textContaining('Grupos del piso'), findsOneWidget);
    });

    for (final text in [TextSize.normal, TextSize.huge]) {
      for (final collapsed in [false, true]) {
        testWidgets(
            'no pisa minimapa, barra, grupo ni chat '
            '(${text.name}, ${collapsed ? 'plegada' : 'desplegada'})',
            (tester) async {
          _size(tester);
          final (_, g) = await pumpHud(tester, text: text);
          if (collapsed) {
            await g.update(g.state.copyWith(objectivesCollapsed: true));
            await tester.pump();
            // El resumen entra en una línea también con texto grande.
            expect(
                tester
                    .getSize(
                        find.byKey(const ValueKey('hud-objectives-summary')))
                    .height,
                lessThanOrEqualTo(tester
                        .getSize(
                            find.byKey(const ValueKey('hud-objectives-toggle')))
                        .height +
                    2.5));
          }
          final obj =
              tester.getRect(find.byKey(const ValueKey('hud-objectives')));
          final others = <String, Rect>{
            'minimapa': tester.getRect(find
                .ancestor(
                    of: find.byType(Minimap), matching: find.byType(RetroPanel))
                .first),
            'barra':
                tester.getRect(find.byKey(const ValueKey('hud-mission-bar'))),
            'chat': tester.getRect(find.byKey(const ValueKey('chat-pill'))),
            for (final (i, e) in find.byType(PartyBox).evaluate().indexed)
              'grupo $i': tester.getRect(find.byWidget(e.widget)),
          };
          expect(obj.right, lessThanOrEqualTo(1280));
          expect(obj.bottom, lessThanOrEqualTo(720));
          for (final MapEntry(:key, :value) in others.entries) {
            expect(obj.overlaps(value), isFalse,
                reason: '$key $value vs objetivos $obj');
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('J pliega / despliega en el campo', (tester) async {
      _size(tester);
      late GameSprites sprites;
      await tester.runAsync(() async {
        sprites = await GameSprites.load(await SpriteCatalog.load());
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
          profileStoreProvider.overrideWithValue(InMemoryProfileStore(
              zoneProgression.normalize(PlayerProfile(
                  name: 'Ana', classId: 'guerrero', unlockedZone: 1)))),
          sessionClockProvider
              .overrideWithValue(const SessionClock(autoStart: false)),
          gameSpritesProvider.overrideWith((ref) => sprites),
        ],
        child:
            MaterialApp(theme: RetroTheme.build(), home: const WorldScreen()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final container =
          ProviderScope.containerOf(tester.element(find.byType(WorldScreen)));
      final c = container.read(sessionControllerProvider.notifier);
      _startZone1(c);
      await tester.pump();
      expect(find.text('[-]'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pump();
      expect(container.read(gameSettingsProvider).objectivesCollapsed, isTrue);
      expect(find.text('[+]'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pump();
      expect(container.read(gameSettingsProvider).objectivesCollapsed, isFalse);
    });
  });
}
