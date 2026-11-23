// Capturas de los ayudantes (v0.25.5, docs/specs/farming.md § 8). NO es
// parte de la suite. Correr con
//   flutter test tool/shots/v0254_ayudantes_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/world/fishing_map_harness.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.25.5';

Future<void> _shot(WidgetTester tester, String name, Size size) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _run(WidgetTester tester, Size size, String sfx) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await FishingMapHarness.pump(tester,
      profile: PlayerProfile(
          name: 'Ana',
          classId: 'guerrero',
          unlockedZone: 1,
          credits: 9000,
          life: LifeSkills(
              fishXp: 4000,
              farm: FarmSkills(
                  xp: 4000,
                  seeds: const {'nabo_claro': 14, 'frutilla_rocio': 3, 'trigo_dorado': 5}))));
  final c = h.c;
  final game = h.game;
  final box = Offset.zero & size;
  Offset? screenOf((int, int) tile) {
    for (var y = 0.0; y < box.height; y += 3) {
      for (var x = 0.0; x < box.width; x += 3) {
        if (game.tileAtScreen(Offset(x, y)) == tile) return Offset(x + 4, y + 4);
      }
    }
    return null;
  }

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);

  expect(c.hireHelper('h0'), isTrue);
  expect(c.hireHelper('l0'), isTrue);
  c.giveSeeds('h0', 'nabo_claro', 10);
  await h.frames(3);

  // Granjero y cofre en la huerta.
  final (ox, oy) = c.town.origin;
  // ignore: invalid_use_of_visible_for_testing_member
  c.teleport((19.0 + ox) * 16 - 24, (19.0 + oy) * 16);
  await h.frames(30);
  final g = TownRules.helperPos(c.town, c.town.build('h0')!, 0, c.sessionTime);
  await mouse.moveTo(screenOf(((g.x / 16).floor(), (g.y / 16).floor())) ??
      Offset.zero);
  await h.frames(3);
  await _shot(tester, 'granjero_cofre_$sfx', size);

  // Pescador en la orilla del lago.
  await mouse.moveTo(Offset.zero);
  final l = c.town.build('l0')!;
  final f = TownRules.helperPos(c.town, l, 0, c.sessionTime);
  // ignore: invalid_use_of_visible_for_testing_member
  c.teleport(f.x + 20, f.y);
  await h.frames(30);
  await mouse.moveTo(screenOf(((f.x / 16).floor(), (f.y / 16).floor())) ??
      Offset.zero);
  await h.frames(3);
  await _shot(tester, 'pescador_lago_$sfx', size);

  // Pantalla del granjero: SEMILLAS.
  await mouse.moveTo(Offset.zero);
  c.openHelper('h0', 0);
  await h.frames(4);
  await _shot(tester, 'granjero_semillas_$sfx', size);
}

void main() {
  testWidgets('1280x720', (t) => _run(t, const Size(1280, 720), '1280'));
}
