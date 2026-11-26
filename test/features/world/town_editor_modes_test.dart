// Town editor tools (town_editor.md § 1.7) and town paths (§ 4.6): the
// CONSTRUIR / MOVER / BORRAR / CAMINOS buttons, their hotkeys, Esc, the
// cursor feedback and the path material picker. With PREVIEW=1 writes
// docs/preview/town_paths/<shot>.png at 1280×720 with the real sprites:
//   $env:PREVIEW = "1"; flutter test test/features/world/town_editor_modes_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/construction_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart' show Tile;
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/renown.dart';
import 'package:echos_del_tiempo/game_engine/models/town_build.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import 'fishing_map_harness.dart';

final _shots = Platform.environment['PREVIEW'] != null;

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  await tester.runAsync(() async {
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final img = await layer.toImage(const Rect.fromLTWH(0, 0, 1280, 720));
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview/town_paths').createSync(recursive: true);
    File('docs/preview/town_paths/$name.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}

PlayerProfile _player() =>
    PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 60000).copyWith(
        life: LifeSkills(crafts: const {'tabla': 20}));

Future<FishingMapHarness> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await FishingMapHarness.pump(tester, profile: _player());
  expect(h.c.enterTownEdit(), isTrue);
  h.c.townEdit!.center = true;
  await h.frames(3);
  return h;
}

/// A house placed by the host with its door free (map coordinates of
/// its corner), via the test hook.
(int, int) _house(SessionController c) {
  for (var y = 2; y < 20; y++) {
    for (var x = 20; x > 3; x--) {
      final r = TownRules.place(c.town, kCasaId, x, y);
      if (r.town == null) continue;
      final b = r.town!.build(r.id!)!;
      final (dx, dy) = TownPlan.doorOf(b.bounds);
      final (ox, oy) = r.town!.origin;
      if (TownPlan.of(c.town).at(dx + ox, dy + oy) != Tile.grass) continue;
      // ignore: invalid_use_of_visible_for_testing_member
      c.debugTown((_) => r.town!);
      return (x, y);
    }
  }
  fail('no spot for a house');
}

void main() {
  setUpAll(() => loadRealFonts());

  test('hotkeys 1-4 pick the tools', () {
    expect(SessionController.editModeKey(LogicalKeyboardKey.digit1),
        TownEditMode.build);
    expect(SessionController.editModeKey(LogicalKeyboardKey.numpad2),
        TownEditMode.move);
    expect(SessionController.editModeKey(LogicalKeyboardKey.digit3),
        TownEditMode.erase);
    expect(SessionController.editModeKey(LogicalKeyboardKey.digit4),
        TownEditMode.paths);
    expect(SessionController.editModeKey(LogicalKeyboardKey.keyW), isNull);
    final e = TownEdit();
    expect(e.buildAvailable, isTrue);
    e.mode = TownEditMode.paths;
    expect(e.buildAvailable, isFalse);
  });

  testWidgets('tools: buttons with hotkeys, Esc back to CONSTRUIR, then out',
      (tester) async {
    final h = await _open(tester);
    for (final m in TownEditMode.values) {
      final b = find.byKey(ValueKey('town-edit-mode-${m.name}'));
      expect(b, findsOneWidget);
      expect(
          find.descendant(of: b, matching: find.textContaining('[${m.hotkey}]')),
          findsOneWidget);
    }
    expect(find.byKey(const ValueKey('town-build-window')), findsOneWidget);
    // The tool buttons work with the CONSTRUIR window open.
    await tester.tap(find.byKey(const ValueKey('town-edit-mode-paths')));
    await h.frames(2);
    expect(h.c.townEdit!.mode, TownEditMode.paths);
    expect(h.c.townEdit!.pathMat, 'dirt');
    expect(find.byKey(const ValueKey('town-build-window')), findsNothing);
    expect(find.byKey(const ValueKey('town-paths-panel')), findsOneWidget);
    expect(h.c.handleKey(LogicalKeyboardKey.digit2), isTrue);
    expect(h.c.townEdit!.mode, TownEditMode.move);
    h.c.handleKey(LogicalKeyboardKey.escape);
    expect(h.c.townEdit!.mode, TownEditMode.build);
    h.c.handleKey(LogicalKeyboardKey.escape);
    expect(h.c.townEdit, isNull);
    await h.frames(2);
  });

  testWidgets('MOVER lifts with a click; BORRAR asks only for buildings',
      (tester) async {
    final h = await _open(tester);
    final (hx, hy) = _house(h.c);
    final id = h.c.town.builds.firstWhere((b) => b.kind == BuildKind.casa).id;
    h.c.setEditMode(TownEditMode.move);
    h.c.editHover(hx + 1, hy + 1);
    expect(h.c.editHoverTarget, id);
    h.c.editClick(hx + 1, hy + 1);
    expect(h.c.townEdit!.step, TownEditStep.moving);
    expect(h.c.townEdit!.selected, id);
    h.c.editBack();
    expect(h.c.townEdit!.mode, TownEditMode.move);
    expect(h.c.townEdit!.step, TownEditStep.browse);

    // A lighthouse goes at once; the house asks first.
    final (ox, oy) = h.c.town.origin;
    // ignore: invalid_use_of_visible_for_testing_member
    h.c.debugTown((t) => t.copyWith(lights: [(hx - ox - 2, hy - oy)]));
    h.c.setEditMode(TownEditMode.erase);
    h.c.editClick(hx - 2, hy);
    expect(h.c.town.lights, isEmpty);
    h.c.editClick(hx + 1, hy + 1);
    expect(h.c.townEdit!.step, TownEditStep.confirmDelete);
    await h.frames(2);
    expect(find.byKey(const ValueKey('town-edit-delete-warn')), findsOneWidget);
    expect(h.c.editRemove(), isTrue);
    expect(h.c.town.builds.any((b) => b.id == id), isFalse);
    h.c.exitTownEdit();
    await h.frames(2);
  });

  testWidgets('CAMINOS: drag paints, locked materials say why',
      (tester) async {
    final h = await _open(tester);
    h.c.setEditMode(TownEditMode.paths);
    await h.frames(2);
    // Level 1 town: stone and runic cobble are locked, dirt is not.
    final stone = find.byKey(const ValueKey('town-paths-mat-stone'));
    await tester.tap(stone);
    await h.frames(1);
    expect(h.c.townEdit!.pathMat, 'dirt');
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(tester.getCenter(stone));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('town-paths-lock-stone')), findsOneWidget);
    expect(find.textContaining('nivel 2'), findsWidgets);
    final (ox, oy) = h.c.town.origin;
    expect(h.c.pathBrush(ox + 6, oy + 4), isTrue);
    expect(h.c.town.paths[(6, 4)], 'dirt');
    expect(h.c.pathBrush(ox + 6, oy + 4, erase: true), isTrue);
    expect(h.c.town.paths, isEmpty);
    h.c.editHover(ox + 7, oy + 4);
    await h.frames(1);
    await _shot(tester, 'caminos_locked_tooltip');
    await g.moveTo(Offset.zero);
    h.c.exitTownEdit();
    await h.frames(2);
  });

  testWidgets('previews', (tester) async {
    final h = await _open(tester);
    await _shot(tester, 'build_window_modes');

    final (hx, hy) = _house(h.c);
    h.c.setEditMode(TownEditMode.erase);
    h.c.editHover(hx + 1, hy + 1);
    await h.frames(2);
    await _shot(tester, 'borrar_hover');

    h.c.setEditMode(TownEditMode.move);
    h.c.editClick(hx + 1, hy + 1);
    var moved = false;
    for (var dx = 6; dx < 14 && !moved; dx++) {
      h.c.editHover(hx + dx, hy + 1);
      moved = h.c.editGhostError == null;
    }
    await h.frames(2);
    expect(moved, isTrue);
    await _shot(tester, 'mover_reroute');
    h.c.editBack();

    // A grown town (Aldea): stone and dirt hand paths beside the auto
    // ones.
    // ignore: invalid_use_of_visible_for_testing_member
    h.c.debugTown((t) => t.copyWith(
          renown: const RenownState(lore: 12),
          paths: {
            for (var x = 3; x < 14; x++) (x, 4): 'stone',
            for (var y = 2; y < 4; y++) (13, y): 'stone',
            for (var x = 4; x < 13; x++) (x, 12): 'dirt',
            for (var y = 9; y < 12; y++) (4, y): 'dirt',
          },
        ));
    // CONSTRUIR with its window closed: the whole town in view.
    h.c.setEditMode(TownEditMode.build, open: false);
    final (ox, oy) = h.c.town.origin;
    h.c.editHover(ox + 9, oy + 10);
    await h.frames(2);
    await _shot(tester, 'town_stone_dirt');
    h.c.exitTownEdit();
    await h.frames(2);
  });
}
