// Previews of the overworld cavern (docs/specs/biome_regions.md § 3.1 and
// § 7.2.1) from the real WorldScreen at 1280 × 720: from the mouth, inside
// by the water and the map overview. NOT part of the suite. Run with
//   flutter test tool/shots/cavern_preview_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/sky.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/preview/biomes';
const _size = Size(1280, 720);

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & _size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('caverna del bosque', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester);
    final c = h.c;
    // A world seed whose forest has a cavern.
    var seed = 1;
    for (; seed < 2000; seed++) {
      BiomeRegions.bind(seed);
      if (biomeLayout(kBosque)!.lakes.any((l) => l.cave != null)) break;
    }
    final s = c.session!;
    s.town = s.town.copyWith(
        sky: (s.town.sky.started ? s.town.sky : const SkyState(day: 1))
            .copyWith(seed: seed, clock: 300));
    expect(c.travelPlace(kBosque), isTrue);
    await h.frames(30);
    expect(c.place, kBosque);
    BiomeRegions.bind(seed);
    final lay = biomeLayout(kBosque)!;
    final lake = lay.lakes.firstWhere((l) => l.cave != null);
    final (ax, ay) = lake.approach;
    // Walk out of the mouth to the first open tile past the rim.
    final dir = lay.npc.tile.$1 < ax ? 1 : 1;
    var mx = ax;
    final rows = lay.rows(const {});
    while (mx > 0 &&
        mx < BiomeLayout.width - 1 &&
        (lay.isIndoor(mx, ay) || rows[ay][mx] == Tile.rock)) {
      mx += lake.ellipse.$1 < ax ? dir : -dir;
    }
    mx += lake.ellipse.$1 < ax ? 3 : -3;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((mx + 0.5) * 16, (ay + 0.5) * 16);
    await h.frames(40);
    await _shot(tester, 'cavern_mouth');
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((ax + 0.5) * 16, (ay + 0.5) * 16);
    await h.frames(40);
    await _shot(tester, 'cavern_inside');
    c.openPanel(WorldPanel.map);
    await h.frames(6);
    await _shot(tester, 'cavern_overview');
  });
}
