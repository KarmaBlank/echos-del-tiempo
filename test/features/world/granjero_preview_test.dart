import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/workshop_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/animal_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_skills_view.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/animal_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// Previews of the Granjero reform (animals.md § 14). Written with
/// `PREVIEW=1 flutter test <this file>` to `docs/preview/granjero/`;
/// the sprites of the manifest are loaded so every icon is drawn.
final _on = Platform.environment['PREVIEW'] != null;
const _out = 'docs/preview/granjero';
final _shot = GlobalKey();

PlayerProfile _farmer(int level,
    {Map<String, int> goods = const {},
    Map<String, int> ores = const {},
    List<String> rtools = const ['cubeta', 'tijeras']}) {
  final b = PlayerProfile(name: 'Ana', classId: 'guerrero', level: 25);
  var xp = 0;
  for (var l = 1; l < level; l++) {
    xp += FarmingRules.xpNeed(l);
  }
  return progression.normalize(b.copyWith(
      credits: 9000,
      life: b.life.copyWith(
          ores: ores,
          farm: b.life.farm.copyWith(
              xp: xp, hay: 20, goods: goods, rtools: rtools))));
}

PlayerProfile _upTo(PlayerProfile p, String b, int tier) {
  for (var t = 1; t <= tier; t++) {
    p = LifeTreeRules.take(p, LifeSkillKind.cultivo, 'farm_$b$t') ?? p;
  }
  return p;
}

Future<GameSprites?> _sprites(WidgetTester tester) => tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      return GameSprites.load(cat);
    });

Future<void> _save(WidgetTester tester, String name) async {
  // Let the sprite images decode before the shot.
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.runAsync(() async {
    final b =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
}

void main() {
  testWidgets('preview: Granjero tree with CULTIVOS and ANIMALES',
      (tester) async {
    if (!_on) return;
    var p = _farmer(30);
    p = _upTo(p, 'a', 5);
    p = _upTo(p, 'f', 10);
    await pumpPanel(tester,
        profile: p,
        sprites: await _sprites(tester),
        build: (v, c) => RepaintBoundary(
              key: _shot,
              child: Container(
                color: DsColors.background,
                padding: const EdgeInsets.all(16),
                child: LifeSkillsView(
                    profile: v.me!.profile,
                    onTake: c.takeLifeNode,
                    onReset: c.resetLifeTree),
              ),
            ));
    tester.view.physicalSize = const Size(1280, 960);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('life-row-cultivo')));
    await tester.pump();
    expect(find.byKey(const ValueKey('life-node-farm_f10')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _save(tester, 'tree');
  });

  testWidgets('preview: pen with parts on the floor', (tester) async {
    if (!_on) return;
    const barn = TownBuild('e0', BuildKind.establo, [TownRect(2, 2, 7, 5)],
        hay: 12,
        animals: [
          FarmAnimal(0, 'vaca',
              aff: 500,
              ready: CropQuality.epico,
              drops: ['ap_vaca_cuerno_2', 'cuerno_ancestral@3']),
          FarmAnimal(1, 'cabra', aff: 320, drops: ['ap_cabra_pelaje_1']),
          FarmAnimal(2, 'oveja', aff: 450, ready: CropQuality.raro),
        ]);
    final c = await pumpPanel(tester,
        profile: _farmer(12),
        sprites: await _sprites(tester),
        build: (v, c) => RepaintBoundary(
            key: _shot, child: AnimalPanel(view: v, controller: c)));
    c.session!.town = c.session!.town.copyWith(builds: [barn]);
    c.openAnimals('e0', uid: 0);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('animal-floor')), findsOneWidget);
    expect(find.byKey(const ValueKey('animal-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('animal-dot-2')), findsNothing);
    expect(tester.takeException(), isNull);
    await _save(tester, 'pen_drop');
  });

  testWidgets('preview: forge by parts with animal parts', (tester) async {
    if (!_on) return;
    await pumpPanel(tester,
        profile: _farmer(12, ores: const {
          'ingot_frost': 6,
          'ingot_copper': 4,
          'ap_vaca_cuerno_2': 2,
          'ap_oveja_lana_fina_1': 3,
          'ap_pato_pluma_0': 2,
          'ap_gallina_pluma_2': 1,
        }),
        sprites: await _sprites(tester),
        build: (v, c) => RepaintBoundary(
            key: _shot,
            child: ForgePanel(
                view: v, controller: c, initialTab: ForgeHallTab.smith)));
    await tester.pump();
    await _tap(tester, 'smith-tab-forge');
    await _tap(tester, 'smith-cell-type-hacha');
    await _tap(tester, 'smith-parts-pick-type-hacha');
    await _tap(tester, 'smith-cell-base-ingot_frost');
    await _tap(tester, 'smith-parts-pick-base-ingot_frost');
    await _tap(tester, 'smith-cell-head-ap_vaca_cuerno_2');
    await _tap(tester, 'smith-parts-pick-head-ap_vaca_cuerno_2');
    await _tap(tester, 'smith-cell-grip-ap_oveja_lana_fina_1');
    await _tap(tester, 'smith-parts-pick-grip-ap_oveja_lana_fina_1');
    await _tap(tester, 'smith-cell-setting-ap_pato_pluma_0');
    expect(tester.takeException(), isNull);
    await _save(tester, 'parts_forge');
  });

  testWidgets('preview: Brann legendary animal forge', (tester) async {
    if (!_on) return;
    final p =
        _farmer(14, goods: const {'huevo_dorado@3': 1, 'vellon_eco@3': 1});
    final brann = kBiomeNpcs.firstWhere((n) => n.id == 'brann');
    final c = await pumpPanel(tester,
        profile: p,
        sprites: await _sprites(tester),
        build: (v, c) => RepaintBoundary(
            key: _shot, child: BiomeNpcPanel(view: v, controller: c)));
    c.session!.town = c.session!.town
        .withResident(const ResidentState('brann', invited: true, house: 1));
    c.openResident(brann);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ds-dialogue-text')),
        warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('npc-choice-forja')));
    await tester.pump();
    final cell = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>)
            .value
            .contains('brann-animal-huevo_dorado'));
    await tester.ensureVisible(cell.first);
    await tester.tap(cell.first);
    await tester.pump();
    expect(find.byKey(const ValueKey('brann-animal-go-huevo_dorado')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await _save(tester, 'legend_forge');
  });

  testWidgets('preview: TALLER DE OFICIOS › MÁQUINAS', (tester) async {
    if (!_on) return;
    expect(AnimalRules.t.i('machineLevel'), lessThanOrEqualTo(12));
    await pumpPanel(tester,
        profile: _farmer(12,
            goods: const {
              'leche@0': 6,
              'leche@2': 2,
              'leche_cabra@1': 3,
              'huevo@0': 8,
              'huevo_pato@1': 2,
            },
            rtools: const ['cubeta', 'tijeras', 'quesera']),
        sprites: await _sprites(tester),
        build: (v, c) => RepaintBoundary(
            key: _shot,
            child: WorkshopPanel(view: v, controller: c, tab: 2)));
    await tester.pump();
    final cell = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.contains('machine-in-leche@2'));
    await tester.ensureVisible(cell.first);
    await tester.tap(cell.first);
    await tester.pump();
    expect(find.byKey(const ValueKey('machine-go-leche@2')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _save(tester, 'machines');
  });
}
