import 'dart:async';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/lobby/presentation/title_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

Future<void> _pumpTitle(WidgetTester tester, ProfileStore store,
    {required VoidCallback onStart}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider.overrideWithValue(store),
      // Sin sprites (las tarjetas se dibujan igual).
      gameSpritesProvider
          .overrideWith((ref) => Completer<GameSprites>().future),
    ],
    child: MaterialApp(
      theme: RetroTheme.build(),
      home: TitleScreen(onStart: onStart),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('título: nombre y clase crean el perfil local', (tester) async {
    final store = InMemoryProfileStore();
    var started = 0;
    await _pumpTitle(tester, store, onStart: () => started++);
    expect(find.text('ECOS DEL TIEMPO'), findsOneWidget);
    // P2P todavía no: crear sala / unirse deshabilitados.
    expect(find.text('P2P: próximamente'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(find.ancestor(
                of: find.text('CREAR SALA'),
                matching: find.byType(ElevatedButton)))
            .onPressed,
        isNull);

    await tester.enterText(
        find.byKey(const ValueKey('title-name')), 'Anastasia Larga');
    await tester.tap(find.byKey(const ValueKey('class-card-maga')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('title-start')));
    await tester.pump();
    await tester.pump();

    expect(started, 1);
    final saved = (await store.load())!;
    expect(saved.name, 'Anastasia'); // máx. 10 caracteres y sin espacios
    expect(saved.classId, 'maga');
    expect(saved.equipped, 'baculo_aprendiz');
    expect(saved.inventory, contains('baculo_aprendiz'));
    expect(progression.normalize(saved).classId, 'maga');
  });

  testWidgets('título: carga el perfil guardado y nombre vacío es Héroe',
      (tester) async {
    final store = InMemoryProfileStore(progression.normalize(
        PlayerProfile(name: 'Bo', classId: 'tirador', level: 4)));
    await _pumpTitle(tester, store, onStart: () {});
    expect(find.textContaining('Tu nivel guardado: 4'), findsOneWidget);
    expect(find.text('Bo'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('title-name')), '   ');
    await tester.tap(find.byKey(const ValueKey('title-start')));
    await tester.pump();
    await tester.pump();
    final saved = (await store.load())!;
    expect(saved.name, SessionController.defaultName);
    expect(saved.classId, 'tirador');
    expect(saved.level, 4);
  });
}
