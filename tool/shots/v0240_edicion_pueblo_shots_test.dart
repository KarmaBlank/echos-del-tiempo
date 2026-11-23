// Capturas de la edición del pueblo (v0.24.0, docs/specs/town_editor.md).
// NO es parte de la suite. Correr con
//   flutter test tool/shots/v0240_edicion_pueblo_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.24.0';
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

PlayerProfile _profile() => PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      unlockedZone: 1,
      credits: 60000,
      materials: const {CraftMaterial.esquirla: 90, CraftMaterial.cristal: 30},
      life: LifeSkills(
        bag: const {'carpa_musgo': 3, 'trucha_cobre': 4},
        farm: FarmSkills(seeds: const {'nabo_claro': 6, 'trigo_dorado': 4}),
      ),
    );

void main() {
  testWidgets('edición del pueblo', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await FishingMapHarness.pump(tester, profile: _profile());
    final c = h.c;
    final game = h.game;
    final box = Offset.zero & _size;

    Offset? screenOf((int, int) tile) {
      for (var y = 0.0; y < box.height; y += 3) {
        for (var x = 0.0; x < box.width; x += 3) {
          if (game.tileAtScreen(Offset(x, y)) == tile) {
            return Offset(x + 4, y + 4);
          }
        }
      }
      return null;
    }

    // Algo plantado en la huerta base (para su cartel).
    const bf = TownLayout.baseFarm;
    for (var i = 0; i < 3; i++) {
      // ignore: invalid_use_of_visible_for_testing_member
      c.teleport((bf.x + i + 0.5) * 16, (bf.y + 1.5) * 16);
      await h.frames(4);
      for (var k = 0; k < 2; k++) {
        c.handleKey(LogicalKeyboardKey.keyE);
        await h.frames(10);
      }
    }

    // ---- EDITAR PUEBLO desde la fuente ----
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport(17.0 * 16, 12.4 * 16);
    await h.frames(6);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    await h.frames(2);
    expect(c.enterTownEdit(), isTrue);
    game.editZoom = 1.5;
    game.camX = 22 * 16;
    game.camY = 0;
    await h.frames(4);
    c.editClick(35, 10);
    await h.frames(3);
    await _shot(tester, 'edicion_lados');

    // ---- ampliar al este y elegir qué construir ----
    expect(c.expandTown(TownSide.este), isTrue);
    c.editBack();
    c.editClick(32, 7);
    await h.frames(3);
    await _shot(tester, 'edicion_construir');
    c.editChoose('lago');
    c.editClick(32, 7);
    await h.frames(3);
    expect(c.town.lakes.length, 2);

    // ---- mover el lago base contra el nuevo: se funden ----
    c.editClick(5, 16);
    c.editStartMove();
    final to = screenOf((30, 13))!;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    game.camX = 14 * 16;
    await h.frames(3);
    await mouse.moveTo(screenOf((30, 13)) ?? to);
    await h.frames(3);
    await _shot(tester, 'edicion_fundir_lagos');
    c.editClick(30, 13);
    await h.frames(3);
    expect(c.town.lakes.length, 1);
    c.stockFish('trucha_cobre', c.town.lakes.single.id);
    c.stockFish('trucha_cobre', c.town.lakes.single.id);
    c.stockFish('carpa_musgo', c.town.lakes.single.id);
    c.editClick(33, 9);
    await h.frames(3);
    await _shot(tester, 'edicion_lago_opciones');
    c.editStep(TownEditStep.stocking);
    await h.frames(3);
    await _shot(tester, 'edicion_lago_especies');

    // ---- el pueblo con sus caminos ----
    c.editBack();
    game.editZoom = 2;
    game.camX = -60;
    game.camY = -60;
    await mouse.moveTo(Offset.zero);
    await h.frames(4);
    await _shot(tester, 'pueblo_caminos');
    c.exitTownEdit();
    await h.frames(3);

    // ---- carteles con el mouse ----
    final lake = c.town.lakes.single;
    final (ox, oy) = c.town.origin;
    final ls = (TownPlan.signOf(c.town, lake).$1 + ox,
        TownPlan.signOf(c.town, lake).$2 + oy);
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((ls.$1 + 0.5) * 16, (ls.$2 + 2.5) * 16);
    await h.frames(30);
    await mouse.moveTo(screenOf(ls)!);
    await h.frames(3);
    expect(find.byKey(const ValueKey('sign-tooltip')), findsOneWidget);
    await _shot(tester, 'cartel_lago');
    final farm = c.town.build('h0')!;
    final fs = (TownPlan.signOf(c.town, farm).$1 + ox,
        TownPlan.signOf(c.town, farm).$2 + oy);
    // ignore: invalid_use_of_visible_for_testing_member
    c.teleport((fs.$1 - 0.5) * 16, (fs.$2 + 1.5) * 16);
    await h.frames(30);
    await mouse.moveTo(Offset.zero);
    await h.frames(1);
    await mouse.moveTo(screenOf(fs)!);
    await h.frames(3);
    expect(find.byKey(const ValueKey('sign-tooltip')), findsOneWidget);
    await _shot(tester, 'cartel_huerta');
  });
}
