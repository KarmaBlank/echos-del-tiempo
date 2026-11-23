import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/light_layer.dart';
import 'package:echos_del_tiempo/game_engine/data/light_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/rules/light_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// La malla de luz oscurece lejos de la luz y deja ver cerca
/// (lighting.md § 4).
void main() {
  testWidgets('la capa multiplica la luz sobre el mapa', (tester) async {
    final map = GameMap(
        width: 40,
        height: 40,
        rows: List.filled(40, '.' * 40),
        theme: 'cavernas',
        spawn: const WorldPoint(0, 0));
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const view = Rect.fromLTWH(0, 0, 320, 320);
    c.drawRect(view, Paint()..color = const Color(0xFFFFFFFF));
    MapLightLayer().draw(c, map, view,
        ambient: MapLightLayer.dungeonAmbient,
        fixed: (a, b, x, y) => const [],
        moving: [LightSource(5.5, 5.5, LightRules.carried(dark: true))],
        t: 0);
    final pic = rec.endRecording();
    final bytes = await tester.runAsync(() async {
      final im = await pic.toImage(320, 320);
      return im.toByteData();
    });
    int red(int x, int y) => bytes!.getUint8((y * 320 + x) * 4);
    expect(red(88, 88), greaterThan(200)); // junto al jugador
    expect(red(300, 300), lessThan(40)); // lejos: casi negro
    expect(kLightDefs, isNotEmpty);
  });
}
