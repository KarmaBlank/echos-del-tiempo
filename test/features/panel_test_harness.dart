import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_action_menu.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas_store.dart';
import 'package:echos_del_tiempo/game_engine/models/bestiary.dart';
import 'package:echos_del_tiempo/game_engine/models/party_store.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../game_engine/session_test_helpers.dart';
import '../real_fonts.dart';

/// Un panel dibujado sobre la sesión local real (motor + controlador),
/// sin el mapa: cada acción del panel pasa por `SessionController`.
///
/// Con [textSize] aplica el "Tamaño del texto" como la app
/// (`MaterialApp.builder` → `RetroTextScale`); [devicePixelRatio] cambia
/// la escala de la pantalla (la ventana sigue siendo 1280×720 lógicos).
Future<SessionController> pumpPanel(
  WidgetTester tester, {
  required PlayerProfile profile,
  required Widget Function(SessionView view, SessionController c) build,
  SessionEngine? engine,
  AtlasStore? atlas,
  BestiaryStore? bestiary,
  GameSprites? sprites,
  PartyStore? party,
  TextSize? textSize,
  ReadingFont readingFont = ReadingFont.vt323,
  bool readingTitles = false,
  bool wideLetters = false,
  double devicePixelRatio = 1,
  List<Override> extraOverrides = const [],
}) async {
  // Fuentes reales: el desborde depende del ancho de los glifos.
  await loadRealFonts(tester);
  // El tema lee los estáticos al armarse.
  RetroType.font = readingFont;
  RetroType.readingTitles = readingTitles;
  RetroType.wideLetters = wideLetters;
  addTearDown(RetroType.reset);
  tester.view.physicalSize =
      Size(1280 * devicePixelRatio, 720 * devicePixelRatio);
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
  final store = InMemoryProfileStore(profile);
  late SessionController controller;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(engine ?? sessionEngine()),
      profileStoreProvider.overrideWithValue(store),
      atlasStoreProvider.overrideWithValue(atlas ?? InMemoryAtlasStore()),
      bestiaryStoreProvider
          .overrideWithValue(bestiary ?? InMemoryBestiaryStore()),
      if (sprites != null) gameSpritesProvider.overrideWith((ref) => sprites),
      // Party jugando solo (solo_party.md): los compañeros cargan async.
      if (party != null) partyStoreProvider.overrideWithValue(party),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
      ...extraOverrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RetroTheme.build(),
      builder: textSize == null
          ? null
          : (context, child) => RetroTextScale(
              factor: textSize.factor,
              font: readingFont,
              readingTitles: readingTitles,
              wideLetters: wideLetters,
              child: child!),
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
  await tester.pump();
  await tester.pump();
  return controller;
}

/// Hace visible y toca [finder].
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  // Las acciones del inventario viven en el menú (v0.9.9): si no está a
  // la vista, se abre con "Acciones ▾".
  final menu = find.byKey(const ValueKey('inv-ctx-menu'));
  if (finder.evaluate().isEmpty) {
    await openInventoryActions(tester);
  } else if (menu.evaluate().isNotEmpty &&
      find.descendant(of: menu, matching: finder).evaluate().isEmpty) {
    // Un clic afuera del menú lo cierra (y no llega a la casilla).
    InventoryContextMenu.close();
    await tester.pump();
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Abre el menú de acciones del inventario (v0.9.9: ya no hay lista en
/// el panel derecho) con clic derecho sobre la casilla elegida, si no
/// está abierto ya.
Future<void> openInventoryActions(WidgetTester tester) async {
  if (find.byKey(const ValueKey('inv-ctx-menu')).evaluate().isNotEmpty) {
    return;
  }
  final sel = find.byWidgetPredicate((w) => w is ItemCell && w.selected);
  if (sel.evaluate().isEmpty) return;
  final f = sel.first;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f, buttons: kSecondaryButton);
  await tester.pump();
  await tester.pump();
}
