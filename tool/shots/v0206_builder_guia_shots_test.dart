// Capturas de la guía del builder (v0.20.6, docs/specs/build_planner.md
// § 9): orden del árbol, armas que te sirven y la armería. NO es parte de
// la suite. Antes / después con SHOT_OUT:
//   SHOT_OUT=antes flutter test tool/shots/v0206_builder_guia_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/build_planner/presentation/build_planner_view.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_plan_providers.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/build_templates_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_guide_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_plan_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';
import '../../test/helpers/build_templates_fixture.dart';

final _out =
    'docs/release_shots/v0.20.6/builder/${Platform.environment['SHOT_OUT'] ?? 'despues'}';

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img =
        await layer.toImage(const Offset(0, 0) & const Size(1920, 1080));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

const _items = [
  ItemInstance(
      uid: 'h1',
      baseId: 'hacha_tronante',
      rarity: Rarity.raro,
      itemLevel: 36,
      affixes: [AffixRoll('feroz', 3, 22), AffixRoll('del_toro', 3, 9)]),
  ItemInstance(uid: 'c1', baseId: 'espada_coral', rarity: Rarity.magico),
  ItemInstance(
      uid: 'v1',
      baseId: 'hacha_volcanica',
      rarity: Rarity.raro,
      itemLevel: 30,
      affixes: [AffixRoll('letal', 3, 6)]),
  ItemInstance(uid: 'b1', baseId: 'baculo_fuego', rarity: Rarity.magico),
];

PlayerProfile _profile() => progression
    .normalize(PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        level: 34,
        credits: 9000,
        items: _items,
        equipped: 'h1'))
    .copyWith(
        attributes: const PlayerAttributes(
            {Attribute.fue: 46, Attribute.vit: 20, Attribute.des: 12}));

BuildPlan _plan() => BuildPlanRules(progression)
    .applyTemplate(BuildPlan.empty, buildTemplate('gue_tormenta_filo')!);

Future<void> _view(WidgetTester tester) async {
  final p = _profile();
  var plan = _plan();
  await pumpPanel(tester,
      devicePixelRatio: 1.5,
      profile: p,
      build: (v, c) => StatefulBuilder(
          builder: (context, set) => BuildPlannerView(
                key: const ValueKey('build-planner'),
                rules: BuildPlanRules(progression),
                profile: p,
                plan: plan,
                onChanged: (x) => set(() => plan = x),
              )));
  await tester.pump();
}

Future<void> _panel(WidgetTester tester, Widget Function(dynamic v, dynamic c) b,
    {CharacterTab? tab}) async {
  await pumpPanel(tester,
      devicePixelRatio: 1.5,
      profile: _profile(),
      build: (v, c) => tab == null
          ? BuyTab(shop: ShopContext(v, c))
          : CharacterPanel(view: v, controller: c, initialTab: tab));
  final container =
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  await container.read(buildPlanProvider.notifier).save(_plan());
  await tester.pump();
}

void main() {
  setUpAll(installBuildTemplates);

  testWidgets('01 BUILD', (tester) async {
    await _view(tester);
    await _shot(tester, '01_build');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('01b BUILD: orden del árbol', (tester) async {
    await _view(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('build-tree-small'),
        skipOffstage: false));
    await tester.pumpAndSettle();
    await _shot(tester, '01b_build_tarjeta_arbol');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('02 BUILD en el árbol', (tester) async {
    await _view(tester);
    await tapVisible(tester, find.byKey(const ValueKey('build-open-tree')));
    await tester.pumpAndSettle();
    await _shot(tester, '02_build_arbol');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('03 árbol del personaje', (tester) async {
    await _panel(tester, (v, c) => const SizedBox(), tab: CharacterTab.tree);
    await _shot(tester, '03_personaje_arbol');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('04 armería', (tester) async {
    await _panel(tester, (v, c) => const SizedBox());
    final picks = BuildGuideRules(progression).rankBases(_plan(), _profile(),
        kWeapons.values.where((w) => w.classId == 'guerrero'));
    final best = picks.firstWhere((w) => w.recommended);
    final rec = find.byKey(ValueKey('shop-row-${best.base.id}'));
    if (rec.evaluate().isNotEmpty) {
      await tester.ensureVisible(rec);
      await tapVisible(tester, rec);
      await tester.pump();
    }
    await _shot(tester, '04_armeria');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('05 inventario', (tester) async {
    await _panel(tester, (v, c) => const SizedBox(),
        tab: CharacterTab.inventory);
    await _shot(tester, '05_inventario');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
