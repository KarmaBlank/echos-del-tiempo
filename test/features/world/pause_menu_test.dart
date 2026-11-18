import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import 'world_test_helpers.dart';

GameSprites? _sprites;

/// Cuenta los guardados del perfil.
class _CountingStore extends InMemoryProfileStore {
  int saves = 0;

  @override
  Future<void> save(PlayerProfile profile) {
    saves++;
    return super.save(profile);
  }
}

typedef _World = ({
  SessionController c,
  ProviderContainer container,
  GlobalKey<NavigatorState> nav,
  _CountingStore store,
  List<int> exits,
});

/// `WorldScreen` empujada sobre una pantalla base (para poder volver al
/// título), sesión local sin reloj automático.
Future<_World> _pumpWorld(WidgetTester tester, {NetSession? net}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (_sprites == null) {
    await tester.runAsync(() async {
      _sprites = await GameSprites.load(await SpriteCatalog.load());
    });
  }
  final nav = GlobalKey<NavigatorState>();
  final store = _CountingStore();
  final exits = <int>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider.overrideWithValue(store),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
      gameSpritesProvider.overrideWith((ref) => _sprites!),
      appExitProvider.overrideWithValue(() async => exits.add(1)),
      if (net != null) activeNetSessionProvider.overrideWith((ref) => net),
    ],
    child: MaterialApp(
      navigatorKey: nav,
      theme: RetroTheme.build(),
      home: const Scaffold(body: Text('TITULO-BASE')),
    ),
  ));
  nav.currentState!.push(MaterialPageRoute<String>(
      builder: (_) => const WorldScreen()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final container =
      ProviderScope.containerOf(tester.element(find.byType(WorldScreen)));
  final c = container.read(sessionControllerProvider.notifier);
  return (c: c, container: container, nav: nav, store: store, exits: exits);
}

Finder get _menu => find.byKey(const ValueKey('settings-menu'));

Future<void> _esc(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('Esc abre y cierra la pausa en el lobby; botón ≡ MENÚ',
      (tester) async {
    final w = await _pumpWorld(tester);
    expect(_menu, findsNothing);
    await _esc(tester);
    expect(_menu, findsOneWidget);
    expect(find.text('PAUSA'), findsOneWidget);
    expect(find.text('Juego en pausa'), findsOneWidget, reason: 'solo');
    expect(w.c.menuOpen, isTrue);
    expect(w.c.paused, isTrue);

    // Solo: el reloj de la partida no avanza mientras está abierta.
    final t0 = w.c.session!.time;
    w.c.advance(1);
    expect(w.c.session!.time, t0);

    // No se camina con la pausa abierta (el teclado se lee por frame).
    final x0 = w.c.local.x, y0 = w.c.local.y;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    expect((w.c.local.x, w.c.local.y), (x0, y0));

    await _esc(tester);
    expect(_menu, findsNothing);
    expect(w.c.menuOpen, isFalse);
    w.c.advance(1);
    expect(w.c.session!.time, greaterThan(t0));

    // El botón del HUD también la abre; CONTINUAR la cierra.
    await _tap(tester, 'pause-open');
    expect(_menu, findsOneWidget);
    await _tap(tester, 'settings-close');
    expect(_menu, findsNothing);
  });

  testWidgets('Esc no abre la pausa con un panel abierto ni escribiendo',
      (tester) async {
    final w = await _pumpWorld(tester);
    // Panel de personaje: Esc lo cierra, no abre la pausa.
    w.c.handleKey(LogicalKeyboardKey.keyC);
    await tester.pump();
    await tester.pump();
    expect(w.c.view!.panel, WorldPanel.character);
    await _esc(tester);
    expect(w.c.view!.panel, isNull);
    expect(_menu, findsNothing);

    // Chat: Esc sale del campo, no abre la pausa.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(w.c.typing, isTrue);
    await _esc(tester);
    expect(w.c.typing, isFalse);
    expect(_menu, findsNothing);

    // Ya sin nada abierto, sí.
    await _esc(tester);
    expect(_menu, findsOneWidget);
  });

  testWidgets('batalla: Esc abre la pausa (sin submenú); ajustes en la escena',
      (tester) async {
    final w = await _pumpWorld(tester);
    w.c.proposeMission(w.c.engine.catalog.missions.first.id);
    w.c.advance(0.1);
    w.c.setReady(true);
    w.c.advance(0.1);
    expect(w.c.view!.mode, SessionMode.field);
    startBattleWithFirstGroup(w.c);
    waitForMyTurn(w.c);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(w.c.view!.mode, SessionMode.battle);
    expect(find.byKey(const ValueKey('pause-open')), findsOneWidget,
        reason: '≡ MENÚ también en batalla');

    // Submenú de pociones abierto: Esc vuelve, no pausa.
    final battle = tester.state<BattleViewState>(find.byType(BattleView));
    await tester.tap(find.byKey(const ValueKey('battle-cat-items')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('battle-act-potion')));
    await tester.pump();
    expect(battle.hasSubmenu, isTrue);
    await _esc(tester);
    expect(battle.hasSubmenu, isFalse);
    expect(_menu, findsNothing);

    // Sin submenú: pausa. Con ella abierta, 1-9 no actúan.
    await _esc(tester);
    expect(_menu, findsOneWidget);
    final turn = w.c.view!.session.battle!.state.current?.id;
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    expect(w.c.view!.myTurn, isTrue);
    expect(w.c.view!.session.battle!.state.current?.id, turn);

    // Los ajustes llegan a la escena en vivo.
    expect(battle.scene.options.damageNumbers, isTrue);
    final settings = w.container.read(gameSettingsProvider.notifier);
    await settings.update(const GameSettings(
        screenShake: false,
        flashes: FlashLevel.off,
        damageNumbers: false,
        scale: ScaleMode.pixelPerfect,
        particles: ParticleLevel.low));
    await tester.pump();
    final o = battle.scene.options;
    expect(o.damageNumbers, isFalse);
    expect(o.shake, isFalse);
    expect(o.flash, 0);
    expect(o.pixelPerfect, isTrue);
    expect(o.particles, 0.3);
    // Sin sacudida: la escena la anula en cada frame.
    battle.scene.particles.addShake(7);
    battle.scene.advance(16);
    expect(battle.scene.particles.shake, 0);

    await _esc(tester);
    expect(_menu, findsNothing);
  });

  testWidgets('SALIR AL TÍTULO pide confirmación y deja la sesión',
      (tester) async {
    await _pumpWorld(tester);
    await _esc(tester);
    await _tap(tester, 'pause-exit-title');
    expect(find.byKey(const ValueKey('pause-confirm-question')),
        findsOneWidget);
    // Esc cancela la confirmación (no cierra el menú).
    await _esc(tester);
    expect(find.byKey(const ValueKey('pause-confirm-question')), findsNothing);
    expect(_menu, findsOneWidget);
    await _tap(tester, 'pause-exit-title');
    await _tap(tester, 'pause-confirm-cancel');
    expect(find.byType(WorldScreen), findsOneWidget);
    await _tap(tester, 'pause-exit-title');
    await _tap(tester, 'pause-confirm-yes');
    await tester.pumpAndSettle();
    expect(find.byType(WorldScreen), findsNothing);
    expect(find.text('TITULO-BASE'), findsOneWidget);
  });

  testWidgets('SALIR DEL JUEGO confirma, guarda el perfil y cierra',
      (tester) async {
    final w = await _pumpWorld(tester);
    final before = w.store.saves;
    await _esc(tester);
    await _tap(tester, 'pause-quit');
    expect(w.exits, isEmpty, reason: 'primero pregunta');
    await _tap(tester, 'pause-confirm-yes');
    await tester.pump();
    expect(w.exits, [1]);
    expect(w.store.saves, greaterThan(before), reason: 'guarda antes');
  });

  testWidgets('cartel de pausa de grupo: REANUDAR lo saca', (tester) async {
    final w = await _pumpWorld(tester);
    // Pausada sin el menú (como la ve otro jugador).
    expect(w.c.pauseGroup(true), isTrue);
    await tester.pump();
    expect(find.byKey(const ValueKey('pause-banner')), findsOneWidget);
    expect(find.text('${SessionController.defaultName} pausó el juego'),
        findsOneWidget);
    final t0 = w.c.session!.time;
    w.c.advance(1);
    expect(w.c.session!.time, t0);
    await _tap(tester, 'pause-banner-resume');
    expect(w.c.paused, isFalse);
    expect(find.byKey(const ValueKey('pause-banner')), findsNothing);
  });

  testWidgets('multijugador: el menú no pausa; PAUSAR AL GRUPO sí',
      (tester) async {
    final hn = LoopbackNetSession(LoopbackHub());
    await tester.runAsync(() => hn.connect(
        SessionConfig(profile: newProfile('Host', 'guerrero'))));
    final w = await _pumpWorld(tester, net: hn);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(w.c.role, SessionRole.host);
    await _esc(tester);
    expect(_menu, findsOneWidget);
    expect(w.c.paused, isFalse, reason: 'el mundo sigue');
    expect(find.text('El juego sigue corriendo en multijugador'),
        findsOneWidget);
    await _tap(tester, 'pause-group');
    expect(w.c.paused, isTrue);
    expect(find.text('Grupo en pausa'), findsOneWidget);
    expect(find.text('REANUDAR AL GRUPO'), findsOneWidget);
    // Al cerrar el menú queda el cartel para todos.
    await _esc(tester);
    expect(find.byKey(const ValueKey('pause-banner')), findsOneWidget);
    await _tap(tester, 'pause-banner-resume');
    expect(w.c.paused, isFalse);
    expect(find.byKey(const ValueKey('pause-banner-resumed')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('pause-banner-resumed')), findsNothing);
  });
}
