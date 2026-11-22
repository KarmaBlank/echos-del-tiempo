// Capturas de la pesca en el mapa (v0.22.2, docs/specs/fishing.md § 4 y
// § 8): carga y lance, la picada con "!", la barra al lado del personaje
// y el pez que salta. NO es parte de la suite. Correr con
//   flutter test tool/shots/v0222_pesca_mapa_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/game_engine/rules/fishing_minigame.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.22.2';
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
  testWidgets('pesca en el mapa', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester);
    expect(h.c.startFishing(), isTrue);
    h.c.fishPress();
    await h.frames(18);
    await _shot(tester, 'pesca_mapa_carga');
    h.c.fishRelease();
    await h.frames(24);
    await _shot(tester, 'pesca_mapa_boya');
    await h.forceBite();
    await h.frames(3);
    await _shot(tester, 'pesca_mapa_picada');
    h.c.fishPress();
    await h.frames(3);
    h.f.game.hook(FishingMapHarness.sample);
    await h.frames(50);
    if (h.f.phase == FishPhase.reel) {
      h.f.game.progress = 0.6;
      h.f.game.zonePos =
          (h.f.game.fishPos - h.f.game.zoneSize / 2).clamp(0.0, 1.0);
    }
    await h.frames(1);
    await _shot(tester, 'pesca_mapa_barra');
    h.f.game.progress = 1.2;
    await h.frames(14);
    await _shot(tester, 'pesca_mapa_captura');
    h.c.fishRelease();
    h.c.stopFishing();
    await h.frames(40);
  });
}
