// Capturas de la pesca y el comerciante (v0.22.0, docs/specs/fishing.md):
// el lance, la picada, la barra y el puesto. NO es parte de la suite.
// Correr con
//   flutter test tool/shots/v0220_pesca_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/fishing_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/trader_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_minigame.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';

const _out = 'docs/release_shots/v0.22.0';
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

final _hero = newProfile('Ana', 'guerrero').copyWith(
    credits: 1800,
    life: LifeSkills(
        fishXp: 900,
        rods: const ['cana_roble'],
        rod: 'cana_roble',
        bag: const {
          'mojarra_claro': 6,
          'carpa_musgo': 3,
          'trucha_cobre': 2,
          'anguila_runica': 1,
          'carpa_manana': 1,
        }));

Future<void> _pump(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

void main() {
  testWidgets('pesca: lance, picada y barra', (tester) async {
    final g = FishingMinigame(() => 0.5);
    await pumpPanel(tester,
        profile: _hero,
        build: (v, c) => FishingPanel(view: v, controller: c, game: g));
    g.press();
    await _pump(tester, 22);
    await _shot(tester, 'pesca_lance');
    g.release();
    await _pump(tester, 20);
    while (g.phase != FishPhase.bite) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await _pump(tester, 4);
    await _shot(tester, 'pesca_picada');
    g.press();
    g.release();
    g.hook(const FishCatch('trucha_cobre', 41));
    await _pump(tester, 30);
    g.progress = 0.62;
    g.zonePos = (g.fishPos - g.zoneSize / 2).clamp(0.0, 1.0);
    await tester.pump(const Duration(milliseconds: 16));
    await _shot(tester, 'pesca_barra');
    await _pump(tester, 3);
  });

  testWidgets('comerciante', (tester) async {
    await pumpPanel(tester,
        profile: _hero,
        build: (v, c) => TraderPanel(view: v, controller: c));
    await tester.pump();
    await _shot(tester, 'comerciante');
  });
}
