import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/farm_layer.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// v0.36.4: el cofre de oficio al lado de cada LAGO / HUERTA se dibuja.

Future<ui.Image> _solid() async {
  final r = ui.PictureRecorder();
  Canvas(r).drawRect(const Rect.fromLTWH(0, 0, 16, 16),
      Paint()..color = const Color(0xFF00FF00));
  return r.endRecording().toImage(16, 16);
}

void main() {
  testWidgets('el cofre vacío de cada lago y huerta se ve (opaco)',
      (tester) async {
    const town = TownState();
    final chest = (await tester.runAsync(_solid))!;
    final asked = <String>[];
    final (ox, oy) = town.origin;
    final rec = ui.PictureRecorder();
    MapFarmLayer().drawHelpers(Canvas(rec), town, 0, 0, (id) {
      asked.add(id);
      return id == 'cofre_oficio' ? chest : null;
    }, (_, __, ___, ____, _____) {});
    const w = 16 * 120, h = 16 * 120;
    final img =
        (await tester.runAsync(() => rec.endRecording().toImage(w, h)))!;
    final data = (await tester.runAsync(img.toByteData))!;
    final builds = town.builds.where((b) => b.kind != BuildKind.casa).toList();
    expect(builds, isNotEmpty);
    expect(asked.where((i) => i == 'cofre_oficio').length, builds.length);
    for (final b in builds) {
      final (cx, cy) = TownRules.chestOf(town, b);
      final px = ((cx + ox + 0.5) * 16).floor(),
          py = ((cy + oy + 0.5) * 16).floor();
      final a = data.getUint8((py * w + px) * 4 + 3);
      // Vacío pero opaco: con alfa 0x80 se fundía con el pasto.
      expect(b.chestTotal, 0);
      expect(a, 255, reason: '${b.id} at $px,$py');
      expect(data.getUint8((py * w + px) * 4 + 1), lessThan(255),
          reason: 'vacío se ve apagado');
    }
  });
}
