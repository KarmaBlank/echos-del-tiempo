// Capturas de v0.25.6 (TEXTOS en el inventario, MEJORAR de la ULT y
// herramientas de oficio). NO es parte de la suite. Correr con
//   flutter test tool/shots/v0255_textos_ult_shots_test.dart
// Todo en memoria (no toca %APPDATA%).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/text_detail_scope.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/characters/presentation/ult_repertoire_view.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/weapon_compare_view.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ult_def.dart';
import 'package:echos_del_tiempo/game_engine/rules/ult_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/inventory/loot_fixtures.dart';
import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.25.6';

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final size = tester.view.physicalSize;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  tearDown(() => TextDetail.current = TextDetail.full);

  for (final mode in TextDetail.values) {
    final tag = mode == TextDetail.summary ? 'resumido' : 'detallado';
    testWidgets('inventario $tag', (tester) async {
      TextDetail.current = mode;
      await loadRealFonts(tester);
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final viewer = progression.normalize(newProfile('Ana', 'guerrero'));
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RetroTheme.build(),
        home: Scaffold(
            body: TextDetailScope(
                mode: mode,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final it in [epicSword, rareAxe]) ...[
                          HoverCompareCard(
                              rules: progression,
                              viewer: viewer,
                              item: it,
                              attributes: viewer.attributes,
                              showEquipped: false),
                          const SizedBox(width: 24),
                        ],
                      ]),
                ))),
      ));
      await tester.pumpAndSettle();
      await _shot(tester, 'inventario_$tag.png');
    });
  }

  for (final size in const [Size(1280, 720), Size(1024, 640)]) {
    testWidgets('ULT mejorar ${size.width.toInt()}', (tester) async {
      await loadRealFonts(tester);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final u = kUltV2List.firstWhere(
          (u) => u.source == UltSource.boss && u.classes.isEmpty);
      final p = UltRules.learn(newProfile('Ana', 'guerrero'), u.id)
          .copyWith(credits: 99999, ultLevels: {u.id: 2});
      await pumpPanel(tester,
          profile: p,
          build: (v, c) {
            final rules = c.engine.progression;
            return UltRepertoireView(
                profile: p,
                weapon: rules.equippedWeapon(p),
                item: rules.equippedItem(p),
                editable: true,
                onSelect: (_) => true,
                onUpgrade: (_) => true);
          });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('ult-row-${u.id}')));
      await tester.pumpAndSettle();
      final diff = find.byKey(const ValueKey('ult-upgrade-diff'));
      expect(diff, findsOneWidget);
      expect(tester.getBottomLeft(diff).dy, lessThan(size.height));
      await _shot(tester,
          size.width == 1280 ? 'ult_mejorar.png' : 'ult_mejorar_1024.png');
    });
  }
}
