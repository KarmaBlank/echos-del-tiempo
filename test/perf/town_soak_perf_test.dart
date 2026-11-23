import 'dart:convert';

import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/core/perf/frame_stats.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../game_engine/session_test_helpers.dart';
import '../real_fonts.dart';

/// Pueblo de un mundo jugado: 3 huertas con ayudante, 3 lagos, una
/// habitante y tormenta (el caso del reporte de v0.34.0).
const _town = r'''{"sides":{"e":2,"o":1,"n":1},"builds":[{"id":"l0","k":"lago","p":[[3,10,8,6],[4,6,6,6]]},{"id":"h0","k":"huerta","p":[[21,17,4,3]],"pl":{"0,2":{},"1,0":{"s":"helecho_dulce","g":260.5,"wg":234.6,"wr":0.6,"wb":"Granjero"},"3,0":{"s":"trigo_dorado","g":200.5,"wg":174.6,"wr":0.6,"wb":"Granjero"},"2,2":{},"3,1":{"wr":0.6},"1,1":{},"3,2":{}},"hp":1,"ch":{"calabaza_sendero@0":1},"tk":[3],"cr":[{"x":12}]},{"id":"h1","k":"huerta","p":[[33,8,6,4],[38,8,4,3]],"pl":{"1,0":{},"0,0":{},"3,0":{},"4,0":{},"5,0":{},"5,2":{},"3,3":{},"0,1":{},"1,1":{},"0,2":{},"1,3":{}},"hp":3},{"id":"l2","k":"lago","p":[[30,-4,4,4],[26,-6,6,6]]},{"id":"h3","k":"huerta","p":[[39,15,4,3]],"pl":{"0,1":{},"2,1":{},"3,0":{}}},{"id":"l4","k":"lago","p":[[0,-5,4,4],[3,-3,4,4],[-3,-4,6,6]]}],"wild":{"bosque:6":240},"sky":{"d":40,"c":64.0,"m":"tormenta"},"res":[{"n":"ilda","r":2,"q":1,"gd":1}]}''';

void main() {
  setUpAll(loadRealFonts);

  testWidgets('pueblo: el cuadro no crece con el tiempo', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late GameSprites sprites;
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    final g = GameSettingsController(
        store: InMemoryGameSettingsStore(), initial: const GameSettings());
    var dir = (0.0, 0.0);
    await tester.pumpWidget(EcosApp(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore(
            zoneProgression.normalize(PlayerProfile(
                name: 'Ana', classId: 'guerrero', unlockedZone: 1)))),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
        gameSpritesProvider.overrideWith((ref) => sprites),
        gameSettingsProvider.overrideWith((ref) => g),
      ],
      home: WorldScreen(moveInput: () => dir),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final c = ProviderScope.containerOf(
            tester.element(find.byType(WorldScreen)))
        .read(sessionControllerProvider.notifier);
    expect(c.view!.mode, SessionMode.lobby);
    c.session!.town = TownState.fromJson(jsonDecode(_town));
    // A la entrada del pueblo nuevo (el lugar de antes puede ser agua).
    final sp = c.engine.mapFor(c.session!).spawn;
    c.session!.players[c.localId]!
      ..x = sp.x
      ..y = sp.y;
    c.local
      ..x = sp.x
      ..y = sp.y;
    c.advance(0.05);
    await tester.pump();

    final start = (c.local.x, c.local.y);
    var moved = false;
    final render = <int>[];
    MapGame.debugRenderTiming = render.add;
    addTearDown(() => MapGame.debugRenderTiming = null);
    final windows = <(double, double)>[];
    // 3 ventanas de 15 s de juego (host a 20 Hz, cuadros a 60 Hz).
    for (var w = 0; w < 3; w++) {
      render.clear();
      final pump = <int>[];
      for (var i = 0; i < 900; i++) {
        dir = switch ((i ~/ 120) % 4) {
          0 => (1.0, 0.0),
          1 => (0.0, 1.0),
          2 => (-1.0, 0.0),
          _ => (0.0, -1.0),
        };
        if (i % 3 == 0) c.advance(0.05);
        final sw = Stopwatch()..start();
        await tester.pump(const Duration(microseconds: 16667));
        pump.add(sw.elapsedMicroseconds);
        if ((c.local.x, c.local.y) != start) moved = true;
      }
      final p = FrameStats(pump), r = FrameStats(render);
      windows.add((p.p50, r.p50));
      // ignore: avoid_print
      print('ventana $w: pump ${p.summary} · render ${r.summary}'
          ' · chat ${c.view!.chat.length}');
    }
    // Plano: la última ventana no puede costar el doble que la primera.
    final first = windows.first, last = windows.last;
    // v0.35.1: con un lugar tardío reubicado, cada cofre y pescador
    // recorría el pueblo entero por cuadro (render p50 ~14 ms en JIT).
    expect(last.$2, lessThan(8.0));
    final town = c.session!.town;
    expect(identical(TownPlan.landmarksOf(town), TownPlan.landmarksOf(town)),
        isTrue);
    // La entrada no se queda sin cuadros: el jugador caminó.
    expect(moved, isTrue);
    expect(last.$1, lessThan(first.$1 * 2 + 1.0));
    expect(last.$2, lessThan(first.$2 * 2 + 1.0));
  });
}
