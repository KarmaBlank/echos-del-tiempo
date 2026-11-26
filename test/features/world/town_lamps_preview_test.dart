// Town lamps at night (cozy_life.md § 2, lighting.md § 3): the small
// decor lamp (farolito) lights the night around it in the real map
// render. With PREVIEW=1 writes, with the real sprites,
// docs/preview/town_lamps/<name>.png:
//   $env:PREVIEW = "1"; flutter test test/features/world/town_lamps_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/sky_rules.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

final _shots = Platform.environment['PREVIEW'] == '1';
final _name = Platform.environment['TOWN_LAMPS_SHOT'] ?? 'after';
const _dir = 'docs/preview/town_lamps';

void main() {
  testWidgets('a town lamp lights the night around it', (tester) async {
    late GameSprites sprites;
    await tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      sprites = await GameSprites.load(cat);
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore(
            progression.normalize(
                PlayerProfile(name: 'Ana', classId: 'guerrero', level: 10)))),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
        gameSpritesProvider.overrideWith((ref) => sprites),
        gameSettingsProvider.overrideWith((ref) => GameSettingsController(
            store: InMemoryGameSettingsStore(),
            initial: GameSettings(
                worldZoom: int.parse(Platform.environment['ZOOM'] ?? '0')))),
      ],
      child: MaterialApp(theme: RetroTheme.build(), home: const WorldScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final c =
        ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
            .read(sessionControllerProvider.notifier);
    final game = tester
        .widget<GameWidget<MapGame>>(find.byType(GameWidget<MapGame>))
        .game!;
    final map = c.map;
    final (ox, oy) = map.townOrigin;
    // A grass tile a few tiles from the player, for the lamp.
    final px = (c.local.x / 16).floor(), py = (c.local.y / 16).floor();
    (int, int)? spot;
    for (var r = 3; r < 12 && spot == null; r++) {
      for (var dx = -r; dx <= r && spot == null; dx++) {
        final x = px + dx, y = py - r;
        if (map.tileAt(x, y) == Tile.grass) spot = (x, y);
      }
    }
    expect(spot, isNotNull);
    final (lx, ly) = spot!;
    c.debugTown((t) => t.copyWith(
        decor: [...t.decor, ('lamp', lx - ox, ly - oy)],
        sky: t.sky.copyWith(seed: 3, day: 1, clock: SkyRules.daySec + 60)));
    expect(SkyRules.darkness(c.session!.town.sky), greaterThan(0.9));
    c.teleport((lx + 0.5) * 16, (ly + 7.5) * 16);
    for (var i = 0; i < 20; i++) {
      c.advance(0.033);
      game.update(0.033);
      await tester.pump(const Duration(milliseconds: 33));
    }
    final rec = ui.PictureRecorder();
    game.drawWorld(
        Canvas(rec,
            Rect.fromLTWH(0, 0, MapGame.vw.toDouble(), MapGame.vh.toDouble())),
        c.view!);
    final pic = rec.endRecording();
    late double near, far;
    await tester.runAsync(() async {
      final frame = await pic.toImage(MapGame.vw, MapGame.vh);
      final bytes = (await frame.toByteData())!;
      final z = game.zoom;
      double lum(double wx, double wy) {
        final sx = ((wx - game.camDrawX) / z).round().clamp(0, MapGame.vw - 1);
        final sy = ((wy - game.camDrawY) / z).round().clamp(0, MapGame.vh - 1);
        final i = (sy * MapGame.vw + sx) * 4;
        return (bytes.getUint8(i) +
                bytes.getUint8(i + 1) +
                bytes.getUint8(i + 2)) /
            3;
      }

      // Average a 3 x 3 tile patch of ground just below the lamp vs. one
      // far from any light.
      double patch(double cx, double cy) {
        var s = 0.0;
        for (var k = 0; k < 9; k++) {
          s += lum(cx + (k % 3 - 1) * 5.0, cy + (k ~/ 3 - 1) * 5.0);
        }
        return s / 9;
      }

      near = patch((lx - 0.5) * 16, (ly + 0.5) * 16);
      far = patch((lx - 6.5) * 16, (ly + 0.5) * 16);
      if (_shots) {
        const cw = 480.0, ch = 270.0, k = 2.0;
        final cx = (((lx + 0.5) * 16 - game.camDrawX) / z)
            .clamp(cw / 2, MapGame.vw - cw / 2);
        final cy = (((ly + 1.5) * 16 - game.camDrawY) / z)
            .clamp(ch / 2, MapGame.vh - ch / 2);
        final r2 = ui.PictureRecorder();
        Canvas(r2).drawImageRect(
            frame,
            Rect.fromCenter(
                center: Offset(cx.toDouble(), cy.toDouble()),
                width: cw,
                height: ch),
            const Rect.fromLTWH(0, 0, cw * k, ch * k),
            SpriteCatalog.pixelPaint());
        final img =
            await r2.endRecording().toImage((cw * k).round(), (ch * k).round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$_dir/$_name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      }
    });
    expect(near, greaterThan(far + 12),
        reason: 'lamp ground $near vs dark ground $far');
  });
}
