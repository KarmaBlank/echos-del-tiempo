import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/core/procedural/item_icons.dart';
import 'package:echos_del_tiempo/core/procedural/weapon_look.dart';
import 'package:echos_del_tiempo/features/inventory/domain/item_text.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_icon.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/elements.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/gear_v2_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/profession_gear_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/profession_parity_sim.dart';
import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

// profession_gear_v2.md § 3–6: the forge-by-parts steps, taking a fish
// apart at Brann's and a living weapon's detail. With `GEAR_V2_PREVIEW=1`
// it writes docs/preview/forge_ui_smelt.png, forge_ui_tools.png,
// forge_ui_steps.png, brann_fish_split.png and
// living_weapon_detail.png.

final _preview = Platform.environment['GEAR_V2_PREVIEW'] != null;
final _shot = GlobalKey();

Future<void> _save(WidgetTester tester, String name) async {
  if (!_preview) return;
  await tester.runAsync(() async {
    final b =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview').createSync(recursive: true);
    File('docs/preview/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

PlayerProfile _smith() {
  final p = parityProfile(LifeSkillKind.herreria, 20);
  return progression.normalize(p.copyWith(
      level: 25,
      credits: 9000,
      life: p.life.copyWith(ores: const {
        'ingot_frost': 12,
        'ingot_copper': 4,
        'ingot_ember': 3,
        'rare_rime': 1,
      })));
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pump();
}

void main() {
  testWidgets('forge by parts: steps, detail and FORJAR', (tester) async {
    final c = await pumpPanel(tester,
        profile: _smith(),
        build: (v, c) => RepaintBoundary(
            key: _shot,
            child: ForgePanel(
                view: v, controller: c, initialTab: ForgeHallTab.smith)));
    await tester.pump();
    // Top tabs say what each activity is (mining_smithing.md § 3.1).
    for (final (k, label) in [
      ('smelt', 'FUNDIR'),
      ('forge', 'FORJAR ARMA'),
      ('tools', 'HERRAMIENTAS DE MINA'),
    ]) {
      expect(
          find.descendant(
              of: find.byKey(ValueKey('smith-tab-$k')),
              matching: find.text(label)),
          findsOneWidget);
    }
    await _save(tester, 'forge_ui_smelt');
    await _tap(tester, 'smith-tab-tools');
    await _save(tester, 'forge_ui_tools');
    await _tap(tester, 'smith-tab-forge');
    // Numbered stepper: 1 Tipo › 2 Base › 3 Cabeza › 4 Mango › 5 Engaste.
    DsButton step(int i) =>
        tester.widget<DsButton>(find.byKey(ValueKey('smith-step-$i')));
    for (final (i, label) in [
      (0, '1 Tipo'),
      (1, '2 Base'),
      (2, '3 Cabeza'),
      (3, '4 Mango'),
      (4, '5 Engaste (opcional)'),
    ]) {
      expect(step(i).label, label);
    }
    expect(step(0).selected, isTrue);
    // FORJAR is grey (with its reason) until every required step is chosen.
    await _tap(tester, 'smith-cell-type-espada');
    DsButton go() =>
        tester.widget<DsButton>(find.byKey(const ValueKey('smith-parts-go')));
    expect(go().onPressed, isNull);
    expect(go().tooltip, isNotNull);
    // Picking moves on to the next step.
    await _tap(tester, 'smith-parts-pick-type-espada');
    expect(step(1).selected, isTrue);
    for (final (slot, id) in [
      ('base', 'ingot_frost'),
      ('head', 'ingot_ember'),
      ('grip', 'ingot_copper'),
      ('setting', 'rare_rime'),
    ]) {
      // No empty cell: every cell has its icon and a name tooltip.
      final cells = find.byWidgetPredicate((w) =>
          w is DsItemCell &&
          (w.key! as ValueKey<String>).value.startsWith('smith-cell-'));
      expect(cells, findsWidgets);
      for (final e in cells.evaluate()) {
        expect(
            find.ancestor(
                of: find.byWidget(e.widget), matching: find.byType(DsTooltip)),
            findsWidgets);
        expect(
            find.descendant(
                of: find.byWidget(e.widget), matching: find.byType(LifeIcon)),
            findsOneWidget);
      }
      await _tap(tester, 'smith-cell-$slot-$id');
      await _tap(tester, 'smith-parts-pick-$slot-$id');
    }
    expect(go().onPressed, isNotNull);
    expect(find.textContaining('· Hielo'), findsWidgets);
    expect(find.byKey(const ValueKey('smith-preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _save(tester, 'forge_ui_steps');
    final before = c.view!.me!.profile.items.length;
    await _tap(tester, 'smith-parts-go');
    final me = c.view!.me!.profile;
    expect(me.items.length, before + 1);
    final w = me.items.last;
    expect(GearV2Rules.partsType(w), 'espada');
    expect(w.parts, ['ingot_frost', 'ingot_ember', 'ingot_copper', 'rare_rime']);
    expect(me.life.ore('rare_rime'), 0);
  });

  testWidgets('Brann takes an Epic fish apart', (tester) async {
    final epic =
        kFish.values.firstWhere((f) => f.rarity == FishRarity.epico);
    final legend =
        kFish.values.firstWhere((f) => f.rarity == FishRarity.legendario);
    final base = parityProfile(LifeSkillKind.pesca, 20);
    final profile = progression.normalize(base.copyWith(
        level: 20,
        credits: 5000,
        life: base.life.copyWith(bag: {epic.id: 1, legend.id: 1})));
    final brann = kBiomeNpcs.firstWhere((n) => n.id == 'brann');
    final c = await pumpPanel(tester,
        profile: profile,
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
    // Epic: no whole forge, only DESARMAR; Legendary: both.
    final cell = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.contains('brann-fish-${epic.id}'));
    await tester.ensureVisible(cell.first);
    await tester.tap(cell.first);
    await tester.pump();
    expect(find.byKey(ValueKey('brann-fish-go-${epic.id}')), findsNothing);
    expect(find.byKey(ValueKey('brann-fish-split-${epic.id}')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _save(tester, 'brann_fish_split');
    await tester.tap(find.byKey(ValueKey('brann-fish-split-${epic.id}')));
    await tester.pump();
    final me = c.view!.me!.profile;
    expect(me.life.count(epic.id), 0);
    expect(me.life.ore(fishPartId(epic.id, FishPart.scale)),
        GearV2Rules.t.i('fishScaleEpic'));
  });

  testWidgets('living weapon detail: affinity, origin and colours',
      (tester) async {
    await tester.runAsync(() async {
      Future<ui.Image> img(String k) async {
        final codec = await ui.instantiateImageCodec(
            File('assets/sprites/items/$k.png').readAsBytesSync());
        return (await codec.getNextFrame()).image;
      }

      for (final k in ['espada', 'hacha', 'lanza']) {
        ItemIconImages.put(k, await img(k));
        ItemIconImages.put('${k}_acento', await img('${k}_acento'));
        for (final l in ['head', 'grip']) {
          final b = await (await img('${k}_$l'))
              .toByteData(format: ui.ImageByteFormat.rawRgba);
          ItemIconImages.putLayer('${k}_$l', Uint8List.view(b!.buffer));
        }
      }
    });
    addTearDown(ItemIconImages.clear);
    final base = prototypeCatalog.weapons.values
        .firstWhere((w) => w.type == 'espada')
        .id;
    final living = ItemInstance(
        uid: GearRules.uidFor('vivo_espada'),
        baseId: base,
        rarity: Rarity.epico,
        itemLevel: 20,
        element: GameElement.fuego,
        masterwork: true,
        parts: const ['living', 'fuego']);
    final forged = [
      for (final head in ['ingot_copper', 'ingot_frost', 'ingot_echo'])
        ItemInstance(
            uid: GearRules.uidFor('parts_espada'),
            baseId: base,
            rarity: Rarity.raro,
            parts: [head, head, 'fp_pez_paradoja_bone']),
    ];
    final origin = gearOriginMarkup(living)!;
    expect(origin, contains('Arma viva'));
    expect(origin, contains('Fuego'));
    expect(origin, contains('Obra maestra'));
    expect(gearOriginMarkup(const ItemInstance(uid: 'a', baseId: 'b')),
        isNull);
    tester.view.physicalSize = const Size(640, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: RepaintBoundary(
      key: _shot,
      child: Container(
        color: DsColors.background,
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            PixelIcon('espada',
                size: 96,
                accent: RarityColors.of(Rarity.epico),
                look: WeaponLook.of(living)),
            for (final f in forged)
              PixelIcon('espada', size: 48, look: WeaponLook.of(f)),
          ]),
          const SizedBox(width: 16),
          Expanded(child: ProtoText(origin)),
        ]),
      ),
    )));
    expect(tester.takeException(), isNull);
    await _save(tester, 'living_weapon_detail');
  });
}
