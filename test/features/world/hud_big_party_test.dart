import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import '../../game_engine/session_test_helpers.dart';
import 'big_room_fixture.dart';

/// HUD del mundo con grupos grandes (v0.13, exploration.md § "HUD"):
/// cajas del grupo en hasta 2 filas (compactas si desplegadas no entran),
/// sin desbordes en ninguna resolución ni tamaño de texto.
void main() {
  setUpAll(loadRealFonts);

  for (final n in const [1, 2, 4, 6, 8, 12]) {
    for (final (w, h) in const [(1280.0, 720.0), (1920.0, 1080.0)]) {
      for (final t in TextSize.values) {
        for (final expanded in const [false, true]) {
          testWidgets(
              '$n jugadores ${w.toInt()}×${h.toInt()} ${t.name}'
              '${expanded ? ' desplegadas' : ''}', (tester) async {
            tester.view.physicalSize = Size(w, h);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            late List<SessionController> all;
            await tester.runAsync(() async {
              (all, _) = await bigRoom(n);
            });
            addTearDown(() {
              for (final c in all.reversed) {
                if (c.mounted) c.dispose();
              }
            });
            final host = all.first;
            final g = GameSettingsController(
                store: InMemoryGameSettingsStore(),
                initial: GameSettings(textSize: t, partyExpanded: expanded));
            await tester.pumpWidget(ProviderScope(
              overrides: [
                sessionEngineProvider
                    .overrideWithValue(sessionEngine(zones: true)),
                profileStoreProvider
                    .overrideWithValue(InMemoryProfileStore()),
                sessionClockProvider.overrideWithValue(
                    const SessionClock(autoStart: false)),
                gameSettingsProvider.overrideWith((ref) => g),
              ],
              child: MaterialApp(
                theme: RetroTheme.build(),
                builder: (context, child) =>
                    RetroTextScale(factor: t.factor, child: child!),
                home: Scaffold(
                  body: WorldHud(
                      view: host.view!,
                      controller: host,
                      chatFocus: FocusNode()),
                ),
              ),
            ));
            await tester.pump();
            expect(tester.takeException(), isNull);
            final area =
                tester.getRect(find.byKey(const ValueKey('hud-party-boxes')));
            expect(area.left, greaterThanOrEqualTo(0));
            for (final p in host.view!.session.playerList) {
              final r = tester.getRect(find.byKey(ValueKey('hud-party-${p.id}')));
              expect(r.top, greaterThanOrEqualTo(0), reason: p.id);
              expect(r.bottom, lessThanOrEqualTo(h), reason: p.id);
            }
            // Hasta 8 con texto normal, a lo sumo 2 filas de cajas.
            final rects = [
              for (final p in host.view!.session.playerList)
                tester.getRect(find.byKey(ValueKey('hud-party-${p.id}')))
            ]..sort((a, b) => a.top.compareTo(b.top));
            var rows = 0;
            var rowBottom = double.negativeInfinity;
            for (final r in rects) {
              if (r.top >= rowBottom - 1) {
                rows++;
                rowBottom = r.bottom;
              } else if (r.bottom > rowBottom) {
                rowBottom = r.bottom;
              }
            }
            if (n <= 8 && t == TextSize.normal) {
              expect(rows, lessThanOrEqualTo(2), reason: 'filas: $rows');
            }
          });
        }
      }
    }
  }
}
