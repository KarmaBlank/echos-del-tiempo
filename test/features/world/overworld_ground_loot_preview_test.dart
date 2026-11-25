// Overworld ground loot preview (docs/specs/loot.md § 4c). With
// PREVIEW_SHOTS=1 writes docs/preview/overworld_ground_loot.png: a wilds
// chest and a shrine of the forest with their loot spilled on the floor.
//   $env:PREVIEW_SHOTS = "1"; flutter test test/features/world/overworld_ground_loot_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/loot_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/goods_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

final _shots = Platform.environment['PREVIEW_SHOTS'] != null;

void main() {
  tearDown(() => BiomeRegions.bind(0));

  testWidgets('map: shrine blessing and chest loot on the floor',
      (tester) async {
    late BiomeLayout lay;
    for (var seed = 0; seed < 50; seed++) {
      BiomeRegions.bind(seed);
      lay = bosqueLayout;
      if (lay.shrines.isNotEmpty) break;
    }
    final e = sessionEngine(zones: true, groundLoot: true);
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!
        .state;
    s = act(e, s, 'p0', const TravelAction(kBosque));
    final map = e.mapFor(s);
    final (sx, sy) = lay.shrines.first;
    (double, double) beside(int x, int y) {
      for (final (dx, dy) in const [(0, 1), (1, 0), (-1, 0), (0, -1)]) {
        if (Tile.isWalkable(map.tileAt(x + dx, y + dy))) {
          return ((x + dx + 0.5) * 16, (y + dy + 0.5) * 16);
        }
      }
      return ((x + 0.5) * 16, (y + 1.5) * 16);
    }

    final at = beside(sx, sy);
    s = moveTo(e, s, 'p0', at.$1, at.$2);
    s = act(e, s, 'p0', const WildLootAction(0, shrine: true));
    final loot = visibleLoot(s, 'p0', (d) => e.lootVerdict(
        s.players['p0']!.profile, d));
    expect(loot.map((l) => l.ground.drop.goods), contains(GoodsRules.gold));

    final painter = LootPainter(
        nameOf: GoodsRules.name, weaponTypeOf: (_) => null);
    const w = 220.0, h = 130.0, scale = 4.0;
    final view = Rect.fromCenter(
        center: Offset((sx + 0.5) * 16, (sy + 1.5) * 16), width: w, height: h);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(-view.left, -view.top);
    final tiles = TilePainter();
    for (var y = (view.top / 16).floor(); y <= (view.bottom / 16).ceil(); y++) {
      for (var x = (view.left / 16).floor();
          x <= (view.right / 16).ceil();
          x++) {
        if (!map.contains(x, y)) continue;
        tiles.draw(c, map.tileAt(x, y), x * 16.0, y * 16.0, map.theme, x, y,
            t: 1000, gateOpen: false, lobby: true);
      }
    }
    for (final l in loot) {
      painter.drawItem(c, l, 1000);
    }
    // Labels need the game fonts (not loaded in tests): icons only.
    final pic = rec.endRecording();
    if (!_shots) {
      pic.dispose();
      return;
    }
    await tester.runAsync(() async {
      final img = await pic.toImage((w * scale).round(), (h * scale).round());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('docs/preview/overworld_ground_loot.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
