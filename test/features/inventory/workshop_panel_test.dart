// TALLER DE OFICIOS (CRAFTEO / HERRAMIENTAS) y AGROPECUARIO sin
// herramientas (town_loop.md § 2.1, v0.48.5). Con PREVIEW_SHOTS=1 guarda
// docs/preview/{oficio_house_craft,oficio_house_tools,agropecuario}.png a
// 1280×720:
//   $env:PREVIEW_SHOTS = "1"; flutter test test/features/inventory/workshop_panel_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/workshop_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/trader_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart' show CraftMaterial;
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'armory_panel_test.dart' show richWarrior;

final _shots = Platform.environment['PREVIEW_SHOTS'] != null;

PlayerProfile _farmer() => richWarrior(credits: 3000).copyWith(
    materials: const {CraftMaterial.esquirla: 30},
        life: LifeSkills(
      fishXp: 400,
      bag: const {'mojarra_claro': 4},
      rods: const [kStarterRod],
      farm: FarmSkills(
        xp: 300,
        hoes: const [kStarterHoe],
        cans: const [kStarterCan],
        crops: const {'nabo_claro@0': 7, 'papa_piedra@0': 3},
      ),
    ));

Future<GameSprites?> _sprites(WidgetTester tester) => tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      return GameSprites.load(cat);
    });

Future<void> _shot(WidgetTester tester, String key, String name) async {
  if (!_shots) return;
  await tester.runAsync(() async {
    final b = tester.renderObject<RenderRepaintBoundary>(find
        .ancestor(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(RepaintBoundary))
        .last);
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview').createSync(recursive: true);
    File('docs/preview/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('taller: CRAFTEO con grilla, costo en casillas y CRAFTEAR',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: _farmer(),
        sprites: await _sprites(tester),
        build: (v, c) => WorkshopPanel(view: v, controller: c));
    expect(find.byKey(const ValueKey('workshop-cell-fibra')), findsOneWidget);
    expect(find.byKey(const ValueKey('workshop-cell-cebo')), findsOneWidget);
    expect(find.byKey(const ValueKey('workshop-detail')), findsOneWidget);
    // Ingredientes como casillas (tenés/necesitás), nunca texto plano.
    expect(find.byKey(const ValueKey('cost-any_crop')), findsOneWidget);
    expect(find.byKey(const ValueKey('cost-gold')), findsOneWidget);
    final before = c.view!.me!.profile.life.craft('fibra');
    final craft = find.byKey(const ValueKey('workshop-craft'));
    expect(tester.widget<DsButton>(craft).onPressed, isNotNull);
    await _shot(tester, 'panel-workshop', 'oficio_house_craft');
    // ×5 no alcanza (10 cosechas): CRAFTEAR queda gris.
    await tapVisible(tester, find.byKey(const ValueKey('workshop-qty-5')));
    expect(tester.widget<DsButton>(craft).onPressed, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('workshop-qty-1')));
    await tapVisible(tester, craft);
    expect(c.view!.me!.profile.life.craft('fibra'), before + 1);
    // PESCA: solo el cebo.
    await tapVisible(tester, find.byKey(const ValueKey('workshop-filter-2')));
    expect(find.byKey(const ValueKey('workshop-cell-fibra')), findsNothing);
    expect(find.byKey(const ValueKey('workshop-cell-cebo')), findsOneWidget);
    expect(find.byKey(const ValueKey('cost-any_fish')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taller: HERRAMIENTAS vende cañas, azadas, regaderas y picos',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: _farmer(),
        sprites: await _sprites(tester),
        build: (v, c) => WorkshopPanel(view: v, controller: c));
    await tapVisible(tester, find.byKey(const ValueKey('workshop-tab-tools')));
    final rod = kRods.values.firstWhere((r) => r.price > 0);
    expect(find.byKey(ValueKey('tools-rod-${rod.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('tools-filter-hoes')), findsOneWidget);
    expect(find.byKey(const ValueKey('tools-filter-picks')), findsOneWidget);
    await tapVisible(tester, find.byKey(ValueKey('tools-rod-${rod.id}')));
    await _shot(tester, 'panel-workshop', 'oficio_house_tools');
    await tapVisible(tester, find.byKey(ValueKey('tools-rod-${rod.id}-buy')));
    expect(c.view!.me!.profile.life.rods, contains(rod.id));
    expect(tester.takeException(), isNull);
  });

  testWidgets('agropecuario: sin herramientas, solo insumos', (tester) async {
    await pumpPanel(tester,
        profile: _farmer(),
        sprites: await _sprites(tester),
        build: (v, c) => TraderPanel(view: v, controller: c, tab: 1));
    for (final tab in ['pesca', 'cultivo', 'mina']) {
      await tapVisible(tester, find.byKey(ValueKey('trade-tab-$tab')));
      for (final k in ['cañas', 'azadas', 'regaderas', 'mine_tools']) {
        expect(find.byKey(ValueKey('trade-filter-$k')), findsNothing);
      }
      for (final id in [...kRods.keys, ...kFarmTools.keys]) {
        expect(find.byKey(ValueKey('trade-rod-$id')), findsNothing);
        expect(find.byKey(ValueKey('trade-tool-$id')), findsNothing);
      }
      expect(
          find.byKey(const ValueKey('trade-mine-pick_copper')), findsNothing);
    }
    await tapVisible(tester, find.byKey(const ValueKey('trade-tab-cultivo')));
    expect(find.byKey(const ValueKey('trade-filter-semillas')), findsOneWidget);
    expect(find.byKey(const ValueKey('trade-filter-abonos')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shot(tester, 'panel-trader', 'agropecuario');
  });
}
