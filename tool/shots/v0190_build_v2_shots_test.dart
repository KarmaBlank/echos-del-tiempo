// Capturas de BUILD v2 (v0.19.0, docs/specs/build_planner_v2.md): plan
// con armas objetivo, detalle con el alijo aparte, buscador de bases,
// vista de plantilla y el filtro SOLO SI MEJORA. NO es parte de la suite:
//   flutter test tool/shots/v0190_build_v2_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/build_planner/presentation/build_planner_view.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_plan_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/build_templates_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/build_plan_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';
import '../../test/helpers/build_templates_fixture.dart';

const _out = 'docs/release_shots/v0.19.0';

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
];

const _stash = [
  ItemInstance(
      uid: 's1',
      baseId: 'hacha_rompe',
      rarity: Rarity.raro,
      itemLevel: 40,
      affixes: [AffixRoll('feroz', 1, 31), AffixRoll('afilado', 2, 7)]),
  ItemInstance(
      uid: 's2',
      baseId: 'hacha_tronante',
      rarity: Rarity.epico,
      itemLevel: 40,
      passiveId: 'espinas'),
];

PlayerProfile _profile() => progression.normalize(PlayerProfile(
    name: 'Ana',
    classId: 'guerrero',
    level: 34,
    credits: 9000,
    materials: const {CraftMaterial.cristal: 6, CraftMaterial.prisma: 2},
    items: _items,
    equipped: 'h1'));

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
                stash: _stash,
                onChanged: (x) => set(() => plan = x),
              )));
  await tester.pump();
}

void main() {
  setUpAll(installBuildTemplates);

  testWidgets('01 plan con armas objetivo', (tester) async {
    await _view(tester);
    await _shot(tester, '01_build_armas_objetivo');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('02 detalle con el alijo aparte', (tester) async {
    await _view(tester);
    await tapVisible(tester, find.byKey(const ValueKey('build-target-1')));
    await tester.pumpAndSettle();
    await _shot(tester, '02_objetivo_que_te_falta_alijo');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('03 buscador de bases', (tester) async {
    await _view(tester);
    await tapVisible(tester, find.byKey(const ValueKey('build-add-target')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('base-search-field')),
            matching: find.byType(EditableText)),
        'trueno');
    await tester.pumpAndSettle();
    await _shot(tester, '03_buscador_de_bases');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('04 vista de plantilla', (tester) async {
    await _view(tester);
    await tapVisible(tester, find.byKey(const ValueKey('build-template')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('tpl-compare')));
    await tester.pump();
    await _shot(tester, '04_vista_de_plantilla');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('05 filtro SOLO SI MEJORA', (tester) async {
    await pumpPanel(tester,
        devicePixelRatio: 1.5,
        profile: _profile(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.filter));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await container.read(buildPlanProvider.notifier).save(_plan());
    await tester.pump();
    await tapVisible(
        tester, find.byKey(const ValueKey('filter-build-kind-upgrade')));
    await tester.pump();
    await _shot(tester, '05_filtro_solo_si_mejora');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
