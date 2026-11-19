// Capturas del inventario (v0.9.11: tooltip de comparaciÃ³n corto,
// plegables y menÃº con filas-botÃ³n; docs/release_shots/v0.9.11). NO es parte de la suite: vive fuera de test/.
// Correr con
//   flutter test tool/shots/ux_shots_test.dart
//
// 1280 Ã— 720 lÃ³gicos Ã— 1.5 = 1920 Ã— 1080, con las fuentes reales.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/inventory/loot_fixtures.dart';
import '../../test/features/panel_test_harness.dart';

const _out = 'docs/release_shots/v0.9.13';
const _size = Size(1280, 720);
const _dpr = 1.5;

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & (_size * _dpr));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _open(WidgetTester tester, PlayerProfile p) => pumpPanel(tester,
    profile: p,
    devicePixelRatio: _dpr,
    build: (v, c) => CharacterPanel(
        view: v, controller: c, initialTab: CharacterTab.inventory));

Offset _cell(WidgetTester tester, PlayerProfile p, String uid) =>
    tester.getCenter(find.byKey(
        ValueKey('inv-cell-${InventoryRules.layout(p).cells.indexOf(uid)}')));

void main() {
  testWidgets('01 tooltip angosto + franja de cambios', (tester) async {
    final p = lootWarrior();
    await _open(tester, p);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(_cell(tester, p, 'e1'));
    await tester.pump();
    await _shot(tester, '01_tooltip_angosto_franja.png');
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('02 Shift: compara con la equipada', (tester) async {
    final p = lootWarrior();
    await _open(tester, p);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(_cell(tester, p, 'e1'));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await _shot(tester, '02_shift_comparar.png');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
