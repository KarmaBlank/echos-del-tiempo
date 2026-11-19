// Capturas de la pasada de UX del inventario v0.9.7
// (docs/release_shots/ux). NO es parte de la suite: vive fuera de test/.
// Correr con
//   flutter test tool/shots/ux_shots_test.dart
//
// 1280 × 720 lógicos × 1.5 = 1920 × 1080, con las fuentes reales.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/inventory/loot_fixtures.dart';
import '../../test/features/panel_test_harness.dart';

const _out = 'docs/release_shots/ux';
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
  testWidgets('01 inventario: buscador y NUEVO', (tester) async {
    final p = lootWarrior().copyWith(fresh: {'r1', 'l1'});
    await _open(tester, p);
    await tester.enterText(find.byKey(const ValueKey('inv-search')), 'hacha');
    await tester.pump();
    await _shot(tester, '01_buscador_nuevo.png');
  });

  testWidgets('02 menú contextual con una acción desactivada',
      (tester) async {
    final p = lootWarrior();
    await _open(tester, p);
    await tester.tap(find.byKey(const ValueKey('inv-equipped')),
        buttons: kSecondaryButton);
    await tester.pump();
    await _shot(tester, '02_menu_contextual.png');
  });

  testWidgets('03 tooltip compacto con una sección desplegada',
      (tester) async {
    final p = lootWarrior();
    await _open(tester, p);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(_cell(tester, p, 'l1'));
    await tester.pump();
    final fold = find.byKey(const ValueKey('tip-fold-Mods')).first;
    await mouse.moveTo(tester.getCenter(fold));
    await tester.pump(const Duration(milliseconds: 100));
    await mouse.down(tester.getCenter(fold));
    await mouse.up();
    await tester.pump();
    await _shot(tester, '03_tooltip_plegable.png');
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('04 LIMPIAR INVENTARIO', (tester) async {
    await _open(tester, lootWarrior());
    await tapVisible(tester, find.byKey(const ValueKey('inv-clean')));
    await tester.ensureVisible(
        find.byKey(const ValueKey('inv-clean-menu-sell-raro')));
    await tester.pump();
    await _shot(tester, '04_limpiar.png');
  });
}
