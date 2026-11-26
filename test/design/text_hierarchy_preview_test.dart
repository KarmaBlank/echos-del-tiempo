// Previews of the text roles (design_system.md § 3.4). Only runs with
// PREVIEW=1 (or PREVIEW_SHOTS=1):
//   $env:PREVIEW = "1"; flutter test test/design/text_hierarchy_preview_test.dart
// Writes docs/preview/text_hierarchy/*.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/design/gallery/ds_gallery_screen.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_icon.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_item_grid.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/fishing_widgets.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_names.dart';
import 'package:echos_del_tiempo/features/world/domain/town_names.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/seed_text.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_strings.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_time_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../app/text_size_test.dart' show legendWand;
import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';

final _on = Platform.environment['PREVIEW'] != null ||
    Platform.environment['PREVIEW_SHOTS'] != null;

const _dir = 'docs/preview/text_hierarchy';

Future<GameSprites?> _sprites(WidgetTester tester) => tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      return GameSprites.load(cat);
    });

/// Saves [rect] of the whole screen (overlays included).
Future<void> _save(WidgetTester tester, String name, Rect rect) async {
  await tester.runAsync(() async {
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final img = await layer.toImage(rect, pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    img.dispose();
  });
}

/// A target cell at the top-left with [tip] around it; hovers it.
Future<void> _hover(
    WidgetTester tester, Widget Function(BuildContext, Widget) tip,
    {GameSprites? sprites, Widget? icon, String hover = 'target'}) async {
  await pumpPanel(tester,
      profile: progression
          .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero')),
      sprites: sprites,
      build: (v, c) => ColoredBox(
            color: DsColors.surface,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Builder(
                    builder: (context) => tip(
                        context,
                        Container(
                          key: const ValueKey('target'),
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: DsColors.surfaceSunken,
                              border: Border.all(
                                  color: DsColors.borderControl, width: 2)),
                          child: icon,
                        ))),
              ),
            ),
          ));
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  await g.moveTo(tester.getCenter(find.byKey(ValueKey(hover))));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
}

const _shot = Rect.fromLTWH(0, 0, 560, 260);

void main() {
  testWidgets('farm helper tooltip (after)', (tester) async {
    await _hover(tester, (context, child) {
      final s = worldStrings(context);
      return DsTooltip(
          card: DsTooltipCard(
            title:
                s.t('ui.world.ctl.helper.farmer_title', {'n': 1, 'level': 3}),
            children: [
              for (final l in [
                s.t('ui.world.ctl.helper.farmer_area', {'n': 12}),
                s.t('ui.world.ctl.helper.farmer_seeds', {'n': 8}),
                s.t('ui.world.ctl.helper.farmer_tasks',
                    {'list': 'Plantar, Regar, Cosechar'}),
                s.t('ui.town.helper.next_cycle', {'task': 'regar', 's': 14}),
              ])
                DsRichText(l),
            ],
          ),
          child: child);
    });
    await _save(tester, 'farm_helper_after', _shot);
  }, skip: !_on);

  testWidgets('item tooltip', (tester) async {
    await _hover(
        tester,
        (context, child) => RetroTooltip(
            message: itemTooltipMarkup(progression, legendWand,
                level: 5,
                attributes:
                    PlayerProfile(name: 'Ana', classId: 'guerrero').attributes),
            child: child));
    await _save(tester, 'item_tooltip', const Rect.fromLTWH(0, 0, 640, 300));
  }, skip: !_on);

  testWidgets('seed tooltip', (tester) async {
    final sprites = await _sprites(tester);
    final d = kCrops.values.firstWhere(
        (c) => LifeTimeRules.cropWinterOnly(c.id),
        orElse: () => kCrops.values.first);
    await _hover(
        tester,
        (context, child) => DsTooltip(
            card: lifeTooltipCard(
                context,
                LifeItemDetail(
                  itemId: 'semilla_${d.id}',
                  name: d.seedText,
                  nameColor: DsColors.textTitle,
                  tags: [
                    (
                      context.t('ui.town.trader.tag_seed'),
                      DsColors.textSecondary
                    ),
                    (d.rarity.text.toUpperCase(), fishRarityColor(d.rarity)),
                  ],
                  lines: [
                    context.t('ui.town.trader.have', {'n': 6}),
                    ...seedInfoLines(context, d),
                  ],
                )),
            child: child),
        sprites: sprites,
        icon: LifeIcon('semilla_${d.id}', LifeIconKind.semilla, size: 32));
    await _save(tester, 'seed_tooltip', _shot);
  }, skip: !_on);

  testWidgets('disabled button tooltip', (tester) async {
    await _hover(
        tester,
        (context, child) => Row(mainAxisSize: MainAxisSize.min, children: [
              child,
              const SizedBox(width: 8),
              const DsButton('MEJORAR',
                  key: ValueKey('disabled-btn'),
                  onPressed: null,
                  tooltip: 'Pide nivel 4 del ayudante'),
            ]),
        hover: 'disabled-btn');
    await _save(tester, 'disabled_button_tooltip', _shot);
  }, skip: !_on);

  testWidgets('gallery: text roles and reserved palettes', (tester) async {
    await pumpPanel(tester,
        profile: progression
            .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero')),
        build: (v, c) => const ColoredBox(
            color: DsColors.surface,
            child: SingleChildScrollView(
                padding: EdgeInsets.all(24), child: PalettePage())));
    tester.view.physicalSize = const Size(1280, 1500);
    await tester.pump();
    await tester.pump();
    await _save(
        tester, 'gallery_text_roles', const Rect.fromLTWH(0, 0, 1280, 980));
  }, skip: !_on);
}
