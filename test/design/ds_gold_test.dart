// DsGold / DsGoldText (design_system.md § 6, DsGold) and the HUD flame
// slot (lighting.md § 3.1.1). Preview PNG only with PREVIEW_SHOTS=1:
//   $env:PREVIEW_SHOTS = "1"; flutter test test/design/ds_gold_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/widgets/pixel_icon.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/potion_shortcuts.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';

final _shots = Platform.environment['PREVIEW_SHOTS'] != null;

Widget _host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: RepaintBoundary(child: child))));

String _plain(WidgetTester tester, Finder f) => tester
    .widgetList<RichText>(find.descendant(of: f, matching: find.byType(RichText)))
    .map((r) => r.text.toPlainText())
    .join(' ');

void main() {
  testWidgets('DsGold renders the coin left of the amount', (tester) async {
    await tester.pumpWidget(_host(const DsGold(4)));
    expect(find.byKey(DsGold.coinKey), findsOneWidget);
    final coin = tester.getRect(find.byKey(DsGold.coinKey));
    final txt = tester.getRect(find.byType(DsGold));
    expect(coin.left, lessThan(txt.center.dx));
    expect(find.byType(PixelIcon), findsOneWidget);
  });

  testWidgets('buy button shows the coin, never a bare "COMPRAR 4"',
      (tester) async {
    await tester.pumpWidget(_host(DsButton('COMPRAR · ₵4', onPressed: () {})));
    final b = find.byType(DsButton);
    expect(find.descendant(of: b, matching: find.byKey(DsGold.coinKey)),
        findsOneWidget);
    final text = _plain(tester, b);
    expect(text, isNot(contains('COMPRAR 4')));
    expect(text, isNot(contains(r'$')));
  });

  test('i18n buy/sell buttons carry the coin mark', () {
    for (final loc in ['es-AR', 'en', 'zh-Hans']) {
      final town = jsonDecode(
              File('assets/i18n/$loc/ui.town.json').readAsStringSync())
          as Map<String, dynamic>;
      String v(String k) {
        final x = town[k];
        return x is Map ? x['text'] as String : x as String;
      }

      expect(v('ui.town.trader.buy_price'), contains('₵{n}'), reason: loc);
      expect(v('ui.town.trader.buy_qty'), contains('×{qty}'), reason: loc);
      expect(v('ui.town.trader.buy_qty'), contains('₵{n}'), reason: loc);
      expect(v('ui.town.trader.price'), isNot(contains('oro')), reason: loc);
    }
  });

  testWidgets('HUD flame slot: key L, disabled outdoors, shows lit state',
      (tester) async {
    final tick = ValueNotifier(0);
    final c = await pumpPanel(tester,
        profile: progression.normalize(
            PlayerProfile(name: 'Ana', classId: 'guerrero')),
        build: (v, c) => ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (_, __, ___) =>
                PotionShortcuts(controller: c, player: v.me!)));
    final slot = find.byKey(const ValueKey('hud-flame'));
    expect(slot, findsOneWidget);
    expect(_plain(tester, slot), contains('[L]'));
    // Town = outdoors: the flame goes by itself, so the slot is grey.
    var b = tester.widget<DsButton>(slot);
    expect(b.onPressed, isNull);
    expect(b.tooltip, isNotNull);
    expect(b.selected, isFalse);
    c.session!.players[c.localId]!.wisp = true;
    tick.value++;
    await tester.pump();
    b = tester.widget<DsButton>(slot);
    expect(b.selected, isTrue);
  });

  testWidgets('preview: shop detail with gold', (tester) async {
    final c = await pumpPanel(tester,
        profile: progression.normalize(
            PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 120)),
        build: (v, c) => RepaintBoundary(
            child: Center(
                child: SizedBox(
                    width: 360,
                    child: DsDetailPane(
                        body: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Antorcha de mina', style: DsText.subtitle()),
                              DsGoldText('Precio: ₵4', style: DsText.body()),
                              Row(children: [
                                Text('Tu oro ', style: DsText.detail()),
                                DsGold(v.me!.profile.credits),
                              ]),
                            ]),
                        actions: Wrap(spacing: 8, children: [
                          DsButton('COMPRAR · ₵4', onPressed: () {}),
                          DsButton('COMPRAR ×3 · ₵12', onPressed: () {}),
                        ]))))));
    expect(c, isNotNull);
    await tester.runAsync(() async {
      final b = tester.renderObjectList(find.byType(RepaintBoundary)).first
          as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('docs/preview/gold_price.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
      img.dispose();
    });
  }, skip: !_shots);

}
