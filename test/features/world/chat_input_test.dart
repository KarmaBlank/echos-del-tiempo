import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

void main() {
  testWidgets('chat: escribir no mueve al jugador ni dispara atajos',
      (tester) async {
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
    final c = ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
        .read(sessionControllerProvider.notifier);
    final x0 = c.local.x, y0 = c.local.y;

    // Enter enfoca el campo de chat.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.typing, isTrue);

    // Flechas, WASD y C mientras se escribe: ni movimiento ni panel.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    expect(c.local.x, x0);
    expect(c.local.y, y0);
    expect(c.view!.panel, isNull);

    // Enter manda el mensaje (eco local del host) y devuelve el foco.
    await tester.enterText(
        find.byKey(const ValueKey('chat-input')), 'hola equipo');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    final last = c.view!.chat.last;
    expect(last.from, SessionController.defaultName);
    expect(last.text, 'hola equipo');
    // Chat oculto por defecto (v0.8.1): mandar lo pliega; la línea queda
    // en el registro (fuera de escena) y el propio mensaje no suma `+N`.
    expect(find.textContaining('hola equipo', skipOffstage: false),
        findsOneWidget);
    expect(find.byKey(const ValueKey('chat-pill')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-unread')), findsNothing);
    expect(c.typing, isFalse);

    // Sin foco en el chat, las flechas vuelven a mover.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(c.local.y, lessThan(y0));

    // Esc cierra el chat sin mandar nada.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.typing, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(c.typing, isFalse);
    expect(c.view!.chat.last.text, 'hola equipo');
  });
}
