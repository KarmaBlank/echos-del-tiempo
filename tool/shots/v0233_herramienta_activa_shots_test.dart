// Capturas del HUD de herramienta, PESCA Y CULTIVO y el comerciante
// (v0.23.3: herramienta activa de la huerta). NO es parte de
// la suite. Correr con
//   flutter test tool/shots/v0233_herramienta_activa_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.23.3';
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

int _xp(int level, int Function(int) need) {
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += need(l);
  }
  return xp;
}

PlayerProfile _profile() => PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      unlockedZone: 1,
      credits: 30000,
      materials: const {CraftMaterial.esquirla: 60, CraftMaterial.cristal: 20},
      life: LifeSkills(
        fishXp: _xp(8, FishingRules.xpNeed),
        bag: const {'carpa_musgo': 3, 'trucha_cobre': 2},
        fishTree: const ['p_a1', 'p_a3'],
        rods: const ['cana_rama', 'cana_roble'],
        farm: FarmSkills(
          xp: _xp(12, FarmingRules.xpNeed),
          seeds: const {'nabo_claro': 6, 'trigo_dorado': 4, 'frutilla_rocio': 2},
          crops: const {
            'nabo_claro@0': 5,
            'trigo_dorado@1': 2,
            'frutilla_rocio@2': 1,
            'trigo_manana@3': 1,
          },
          ferts: const {'abono': 3, 'abono_runico': 1},
          tree: const ['c_b1', 'c_m'],
          hoes: const ['azada_rama', 'azada_hierro'],
          cans: const ['regadera_lata', 'regadera_cobre'],
        ),
      ),
    );

void main() {
  testWidgets('herramienta activa de la huerta', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester, profile: _profile());
    final c = h.c;
    await h.frames(4);
    await _shot(tester, 'pesca_cana_sin_arma');
    const bf = TownLayout.baseFarm;
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((bf.x + 1.5) * 16, (bf.y + 1.5) * 16);
    await h.frames(6);
    await _shot(tester, 'hud_herramientas');
    await _shot(tester, 'herramienta_azada');
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue); // arar
    await h.frames(6);
    c.selectFarmHand(FarmHand.seed);
    await h.frames(4);
    await _shot(tester, 'herramienta_semilla');
    c.selectFarmHand(FarmHand.can);
    await h.frames(4);
    await _shot(tester, 'herramienta_regadera_no_sirve');
    c.selectFarmHand(FarmHand.seed);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue); // plantar
    await h.frames(4);
    c.selectFarmHand(FarmHand.can);
    await h.frames(4);
    await _shot(tester, 'herramienta_regadera');
  });
}
