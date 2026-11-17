import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../game_engine/session_test_helpers.dart';

/// Un panel dibujado sobre la sesión local real (motor + controlador),
/// sin el mapa: cada acción del panel pasa por `SessionController`.
Future<SessionController> pumpPanel(
  WidgetTester tester, {
  required PlayerProfile profile,
  required Widget Function(SessionView view, SessionController c) build,
}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = InMemoryProfileStore(profile);
  late SessionController controller;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider.overrideWithValue(store),
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
  await tester.pump();
  await tester.pump();
  return controller;
}

/// Hace visible y toca [finder].
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
