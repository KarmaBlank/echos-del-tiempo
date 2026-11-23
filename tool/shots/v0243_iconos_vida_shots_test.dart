// Capturas de los íconos de oficio (v0.24.3). NO es parte de la suite.
// Correr con
//   flutter test tool/shots/v0243_iconos_vida_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.24.3';
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
  testWidgets('íconos de oficio', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester,
        profile: PlayerProfile(
          name: 'Ana',
          classId: 'guerrero',
          unlockedZone: 1,
          credits: 5000,
          materials: const {CraftMaterial.esquirla: 10},
          life: LifeSkills(
            bag: const {'carpa_musgo': 3, 'trucha_cobre': 4, 'botas_viejas': 1},
            farm: FarmSkills(
              seeds: const {'nabo_claro': 6, 'trigo_dorado': 4},
              hoes: const ['azada_rama', 'azada_hierro'],
              cans: const ['regadera_lata'],
            ),
          ),
        ));
    final c = h.c;
    const bf = TownLayout.baseFarm;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
    await h.frames(8);
    c.selectFarmHand(FarmHand.seed);
    await h.frames(3);
    await _shot(tester, 'hud_huerta');
    c.openPanel(WorldPanel.trader);
    await h.frames(3);
    await _shot(tester, 'comerciante');
    for (final t in ['CULTIVO', 'VENDER']) {
      final f = find.text(t);
      if (f.evaluate().isEmpty) continue;
      await tester.tap(f.first);
      await h.frames(3);
      await _shot(tester, 'comerciante_${t.toLowerCase()}');
    }
  });
}
