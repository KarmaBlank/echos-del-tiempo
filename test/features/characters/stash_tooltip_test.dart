// v0.13.1: en el alijo los tooltips de las armas son los MISMOS que en
// el inventario (ui_style.md § "Tooltips cortos", characters.md § 3):
// una columna `HoverCompareCard`, Shift muestra la equipada y nunca tapa
// la otra grilla. Capturas con STASH_SHOTS=<carpeta>.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/features/characters/presentation/stash_board.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/weapon_compare_view.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import '../inventory/loot_fixtures.dart';

final _shots = Platform.environment['STASH_SHOTS'];

class _Host implements StashBoardHost {
  _Host(this.profile, this.stash);
  @override
  ProgressionRules get rules => progression;
  @override
  PlayerProfile profile;
  @override
  Stash stash;
  @override
  bool get busy => false;
  @override
  String? get notice => null;
  @override
  String? put(List<String> tokens, int tab) => null;
  @override
  String? take(List<int> cells) => null;
  @override
  bool moveStash(int from, int to) => false;
  @override
  bool moveCharacter(int from, int to) => false;
  @override
  void achievement(String id) {}
}

PlayerProfile _hero() {
  var p = newProfile('Ana', 'guerrero');
  p = InventoryRules.addItem(p, epicSword).$1;
  return InventoryRules.relayout(p);
}

final _shotKey = GlobalKey();

Future<_Host> _pump(WidgetTester tester, TextSize size) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final host = _Host(_hero(), Stash.empty().put(0, const StashEntry.item(epicSword)));
  await tester.pumpWidget(RepaintBoundary(
    key: _shotKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RetroTheme.build(),
      builder: (context, child) =>
          RetroTextScale(factor: size.factor, child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StashBoard(host: host))),
    ),
  ));
  await tester.pump();
  return host;
}

Finder get _tipBox => find.byKey(const ValueKey('retro-tip-scroll'));

int _charCell(PlayerProfile p) =>
    InventoryRules.layout(p)
        .cells
        .indexOf(p.items.firstWhere((i) => i.baseId == epicSword.baseId).uid);

Future<void> _shot(WidgetTester tester, String name) async {
  final out = _shots;
  if (out == null) return;
  await tester.runAsync(() async {
    final b =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(out).createSync(recursive: true);
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    img.dispose();
  });
}

void main() {
  for (final size in [TextSize.normal, TextSize.large, TextSize.enormous]) {
    testWidgets('alijo: ficha de una columna, sin tapar la otra grilla ($size)',
        (tester) async {
      final host = await _pump(tester, size);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final sides = {
        'stash-char-${_charCell(host.profile)}': 'stash-cell-',
        'stash-cell-0': 'stash-char-',
      };
      for (final e in sides.entries) {
        final cell = find.byKey(ValueKey(e.key));
        await tester.ensureVisible(cell);
        await tester.pump();
        await mouse.moveTo(tester.getCenter(cell));
        await tester.pump();
        expect(_tipBox, findsOneWidget, reason: e.key);
        final card = find.byKey(const ValueKey('inv-cmp-tip'));
        expect(card, findsOneWidget, reason: e.key);
        final col =
            RetroType.width(tester.element(card), HoverCompareCard.cardWidth);
        final r = tester.getRect(_tipBox);
        expect(r.width, lessThanOrEqualTo(col + 1), reason: '${e.key} $size');
        // Nunca tapa la otra grilla.
        for (final el in find
            .byWidgetPredicate((w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith(e.value) &&
                RegExp(r'\d+$')
                    .hasMatch((w.key as ValueKey<String>).value))
            .evaluate()) {
          final o = tester.getRect(find.byWidget(el.widget));
          expect(r.overlaps(o), isFalse,
              reason: '${e.key} ($size) tapa ${el.widget.key}');
        }
        if (size == TextSize.normal && e.key.startsWith('stash-cell')) {
          await _shot(tester, 'alijo_tooltip_despues');
        }
        await mouse.moveTo(Offset.zero);
        await tester.pump(const Duration(milliseconds: 400));
      }
      await mouse.removePointer();
    });
  }

  testWidgets('alijo: Shift muestra la equipada', (tester) async {
    await _pump(tester, TextSize.normal);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('stash-cell-0'))));
    await tester.pump();
    final before = tester.getSize(_tipBox).width;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(RetroHoverCard.shiftHeld.value, isTrue);
    expect(tester.getSize(_tipBox).width, greaterThan(before + 20));
    await _shot(tester, 'alijo_tooltip_shift');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await mouse.removePointer();
  });
}
