import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/mine_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Preview of the town cart station next to the exit
/// (docs/specs/mining_smithing.md § 1.8), written to
/// docs/preview/mining_v2 with `MINING_PREVIEW=1 flutter test <this file>`.
final _on = Platform.environment['MINING_PREVIEW'] != null;

void main() {
  testWidgets('preview: estación de vagonetas del pueblo', (tester) async {
    const now = 1000.0;
    final travel = MiningRules.t.d('cartTravelSec');
    final town = const TownState()
        .withMine(
            MiningRules.placeOf(kBosque, 0),
            const MineLevelState(
                station: true,
                cart: MineCart(phase: CartPhase.town, t: now - 30)))
        .withMine(
            MiningRules.placeOf(kBosque, 0, 1),
            MineLevelState(
                station: true,
                cart: MineCart(
                    phase: CartPhase.toTown, t: now - travel + 2)));
    final map = MapGenerator.townOf(town);
    final st = TownPlan.landmarkOf(town, TownSpot.carts);
    final rail = TownPlan.of(town).cartRail(st, town.lights);
    const ts = 16.0, w = 224.0, h = 128.0, scale = 3.0;
    final view = Rect.fromLTWH(
        (st.x - 5) * ts, map.height * ts - h, w, h);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)
      ..scale(scale)
      ..translate(-view.left, -view.top);
    final tiles = TilePainter();
    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        tiles.draw(c, map.tileAt(x, y), x * ts, y * ts, map.theme, x, y,
            t: 0, gateOpen: false, lobby: true);
      }
    }
    void text(String s, double x, double y, Color col, double size) {
      final tp = TextPainter(
          text: TextSpan(text: s, style: TextStyle(color: col, fontSize: size)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    MineLayer().drawTown(
        c,
        town.mines,
        now,
        Rect.fromLTWH(st.x * ts, st.y * ts, st.w * ts, st.h * ts),
        (rail.last.$2 + 1) * ts,
        0,
        text: text,
        label: (p) => 'MINA 1');
    final pic = rec.endRecording();
    if (!_on) {
      pic.dispose();
      return;
    }
    await tester.runAsync(() async {
      final img = await pic.toImage((w * scale).round(), (h * scale).round());
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview/mining_v2').createSync(recursive: true);
      File('docs/preview/mining_v2/05_town_cart_station.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
