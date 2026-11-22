import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_panel.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';

// v0.10.1 (exploration.md § "HUD"): sin barra de ayuda en el pueblo y la
// fila de arriba (botones, línea de misión, minimapa, objetivos) sin
// superponerse con ningún tamaño de texto.

Future<SessionController> _controller() async {
  final c = SessionController(
    engine: sessionEngine(zones: true),
    // Nivel alto sin repartir: PERSONAJE [C] con su insignia.
    store: InMemoryProfileStore(zoneProgression.normalize(PlayerProfile(
        name: 'Ana', classId: 'guerrero', level: 30, unlockedZone: 1))),
    clock: const SessionClock(autoStart: false),
  );
  await c.start();
  return c;
}

void _startZone1(SessionController c) {
  // v0.21.0: sin overworld, la zona sale del tablero.
  c.proposeMission(c.zoneStatus(1)!.mission!.id);
  c.advance(0.05);
  c.setReady(true);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.field);
}

void main() {
  setUpAll(loadRealFonts);

  for (final field in [false, true]) {
    for (final text in TextSize.values) {
      testWidgets(
          'fila de arriba sin superposiciones '
          '(${field ? 'misión' : 'pueblo'}, ${text.name})', (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = await _controller();
        addTearDown(c.dispose);
        if (field) _startZone1(c);
        final g = GameSettingsController(
            store: InMemoryGameSettingsStore(),
            initial: GameSettings(textSize: text));
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
              body: WorldHud(
                  view: c.view!,
                  controller: c,
                  chatFocus: FocusNode(),
                  onExit: () {},
                  onMenu: () {}),
            ),
          ),
        ));
        await tester.pump();

        // Sin la barra de ayuda del pueblo.
        expect(find.textContaining('Mostrador [E]'), findsNothing);
        final rects = <String, Rect>{};
        void add(String name, Finder f) {
          for (final (i, e) in f.evaluate().indexed) {
            final r = tester.getRect(find.byWidget(e.widget).first);
            if (r.isEmpty) continue;
            rects['$name$i'] = r;
          }
        }

        add('botón', find.byType(DsButton));
        expect(find.byType(DsButton), findsWidgets);
        add('barra', find.byKey(const ValueKey('hud-mission-bar')));
        // v0.21.0: sin overworld, el pueblo no tiene minimapa.
        if (field) {
          add(
              'minimapa',
              find
                  .ancestor(
                      of: find.byType(Minimap),
                      matching: find.byType(RetroPanel))
                  .first);
        } else {
          expect(find.byType(Minimap), findsNothing);
        }
        add('objetivos', find.byKey(const ValueKey('hud-objectives')));
        if (field) {
          expect(rects.keys.where((k) => k.startsWith('barra')), isNotEmpty);
        }
        expect(find.byKey(const ValueKey('hud-points-badge')), findsOneWidget);
        // Solo lo de arriba (los botones del minimapa van dentro de él).
        final top = {
          for (final MapEntry(:key, :value) in rects.entries)
            if (value.top < 300) key: value
        };
        final keys = top.keys.toList();
        final mini = top.entries
            .where((e) => e.key.startsWith('minimapa'))
            .map((e) => e.value)
            .toList();
        for (var i = 0; i < keys.length; i++) {
          for (var j = i + 1; j < keys.length; j++) {
            final a = top[keys[i]]!, b = top[keys[j]]!;
            // Un botón dentro del minimapa (zoom, MAPA [M]) no cuenta.
            bool inMini(Rect r) => mini.any((m) => m.expandToInclude(r) == m);
            if (keys[i].startsWith('botón') && inMini(a)) continue;
            if (keys[j].startsWith('botón') && inMini(b)) continue;
            if (keys[i].startsWith('objetivos') &&
                    keys[j].startsWith('botón') ||
                keys[j].startsWith('objetivos') &&
                    keys[i].startsWith('botón')) {
              // El plegado de los objetivos es un botón de la propia caja.
              final o = keys[i].startsWith('objetivos') ? a : b;
              final btn = keys[i].startsWith('objetivos') ? b : a;
              if (o.expandToInclude(btn) == o) continue;
            }
            expect(a.overlaps(b), isFalse,
                reason: '${keys[i]} $a vs ${keys[j]} $b');
          }
        }
      });
    }
  }
}
