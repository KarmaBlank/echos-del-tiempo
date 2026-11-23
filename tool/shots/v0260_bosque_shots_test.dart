// Capturas de v0.26.0 (docs/specs/overworld_biomes.md): el camino del sur
// del pueblo, el mapa de viaje, el exterior del Bosque y una mata para
// recolectar. NO es parte de la suite. Correr con
//   flutter test tool/shots/v0260_bosque_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.26.0';
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
  testWidgets('mapa de viaje y Bosque', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester);
    final c = h.c;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(17 * 16.0, 21 * 16.0 + 4);
    await h.frames(20);
    expect(c.nearTravel, isTrue);
    await _shot(tester, 'pueblo_camino_sur');
    c.openPanel(WorldPanel.travel);
    await h.frames(4);
    await _shot(tester, 'mapa_de_viaje');
    expect(c.travelPlace(kBosque), isTrue);
    await h.frames(30);
    expect(c.place, kBosque);
    await _shot(tester, 'bosque_llegada');
    final f = BosqueLayout.forage[6];
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((f.x + 0.5) * 16, (f.y + 1.5) * 16);
    await h.frames(20);
    expect(c.nearForage, 6);
    await _shot(tester, 'bosque_mata');
    expect(c.forage(), isTrue);
    await h.frames(10);
    await _shot(tester, 'bosque_recolectado');
  });
}
