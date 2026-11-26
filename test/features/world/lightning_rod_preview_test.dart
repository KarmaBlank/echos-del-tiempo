// Lightning rod previews (docs/specs/cozy_life.md § 2.1). With PREVIEW=1
// writes docs/preview/lightning_rod/{tooltip,coverage,redirect}.png:
//   $env:PREVIEW = "1"; flutter test test/features/world/lightning_rod_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/cozy_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/farm_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/sky_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/town_edit_layer.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/sky_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import 'fishing_map_harness.dart';

final _shots = Platform.environment['PREVIEW'] != null;
const _dir = 'docs/preview/lightning_rod';

Future<GameSprites?> _sprites(WidgetTester tester) => tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      return GameSprites.load(cat);
    });

Future<void> _picShot(
    WidgetTester tester, ui.Picture pic, int w, int h, String name) async {
  if (!_shots) {
    pic.dispose();
    return;
  }
  await tester.runAsync(() async {
    final img = await pic.toImage(w, h);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void _tiles(Canvas c, GameMap map, Rect view) {
  final tiles = TilePainter();
  for (var y = (view.top / 16).floor(); y <= (view.bottom / 16).ceil(); y++) {
    for (var x = (view.left / 16).floor(); x <= (view.right / 16).ceil(); x++) {
      if (!map.contains(x, y)) continue;
      tiles.draw(c, map.tileAt(x, y), x * 16.0, y * 16.0, map.theme, x, y,
          t: 1000, gateOpen: false, lobby: true);
    }
  }
}

/// The base farm, fully planted, with a rod on its right side.
TownState _town() {
  final f = kBaseFarm.parts.first;
  return TownState(
    builds: [
      kBaseLake,
      kBaseFarm.copyWith(plots: {
        for (var y = 0; y < f.h; y++)
          for (var x = 0; x < f.w; x++)
            '$x,$y': FarmingRules.plant(FarmingRules.till(), 'nabo_claro')!
                .copyWith(grow: 40),
      }),
    ],
    decor: [('lightning_rod', f.x + f.w, f.y + 1)],
  );
}

void main() {
  testWidgets('tooltip: the PARARRAYOS card says it protects', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (_shots) await loadRealFonts(tester);
    final h = await FishingMapHarness.pump(tester,
        profile: PlayerProfile(
            name: 'Ana',
            classId: 'guerrero',
            credits: 6000,
            life: LifeSkills(farm: FarmSkills(xp: 5000))));
    expect(h.c.enterTownEdit(), isTrue);
    await h.frames(3);
    final cell = find.byKey(const ValueKey('town-edit-build-lightning_rod'));
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await h.frames(3);
    expect(find.textContaining('Protege las parcelas de los rayos en un radio de'),
        findsOneWidget);
    if (_shots) {
      await tester.runAsync(() async {
        final b = tester.renderObject<RenderRepaintBoundary>(find
            .ancestor(
                of: find.byKey(const ValueKey('town-build-window')),
                matching: find.byType(RepaintBoundary))
            .first);
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$_dir/tooltip.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    h.c.exitTownEdit();
    await h.frames(2);
  });

  Future<(TownState, GameMap, Rect, int, int)> scene() async {
    final town = _town();
    final map = MapGenerator.town(town);
    final (ox, oy) = map.townOrigin;
    final f = kBaseFarm.parts.first;
    final view = Rect.fromLTWH((f.x + ox - 4) * 16.0, (f.y + oy - 7) * 16.0,
        (f.w + 11) * 16.0, (f.h + 8) * 16.0);
    return (town, map, view, ox, oy);
  }

  testWidgets('map: placed rod with its coverage on the farm', (tester) async {
    final sprites = await _sprites(tester);
    final cozy = CozyLayer((id) => sprites?.lifeIcon(id, ''));
    final farm = MapFarmLayer()..icon = (id) => sprites?.lifeIcon(id, '');
    final (town, map, view, ox, oy) = await scene();
    const scale = 4.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(-view.left, -view.top);
    _tiles(c, map, view);
    farm.drawPlots(c, town, view, 1000);
    final d = town.decor.single;
    TownEditLayer.drawRodCoverage(c, d.$2 + ox, d.$3 + oy);
    cozy.drawDecor(c, town, ox, oy);
    await _picShot(tester, rec.endRecording(), (view.width * scale).round(),
        (view.height * scale).round(), 'coverage');
  });

  testWidgets('map: a storm bolt redirected to the rod', (tester) async {
    final sprites = await _sprites(tester);
    final cozy = CozyLayer((id) => sprites?.lifeIcon(id, ''));
    final farm = MapFarmLayer()..icon = (id) => sprites?.lifeIcon(id, '');
    final (town, map, view, ox, oy) = await scene();
    final sky = MapSkyLayer();
    final d = town.decor.single;
    sky.addBolt(d.$2 + ox, d.$3 + oy, 0, rod: true);
    const scale = 4.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(-view.left, -view.top);
    _tiles(c, map, view);
    farm.drawPlots(c, town, view, 1000);
    cozy.drawDecor(c, town, ox, oy);
    final SkyState st = SkyRules.start(() => 0.5);
    sky.draw(c, st, view, 120,
        lights: const [], weather: Weather.tormenta, flash: 0.4, tint: false);
    await _picShot(tester, rec.endRecording(), (view.width * scale).round(),
        (view.height * scale).round(), 'redirect');
  });
}
