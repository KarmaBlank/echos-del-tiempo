// Grilla de ítems compartida (design_system.md § 6.2): INVENTARIO es la
// base. Casilla del tamaño de la de INVENTARIO, 6 columnas, detalle de
// ancho fijo y sin desbordes a 1280×720 / 1920×1080 y texto enorme.
import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/design/gallery/ds_examples.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_tab.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/biome_npc_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../features/inventory/loot_fixtures.dart';
import '../features/panel_test_harness.dart';
import '../game_engine/session_test_helpers.dart';

PlayerProfile _profile() => progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: 900,
      life:
          LifeSkills(farm: FarmSkills(xp: 300, seeds: const {'nabo_claro': 6})),
    ));

void _checkGrid(WidgetTester tester, String p, {double? cell}) {
  final grid = tester.getRect(find.byKey(ValueKey('$p-grid')));
  final detail = tester.getRect(find.byKey(ValueKey('$p-pane')));
  final k = grid.width / DsSizes.gridWidth();
  // Exactly 6 columns of cells of side itemCell × k.
  expect(grid.width, closeTo(DsSizes.gridWidth(k), 0.01));
  if (cell != null) expect(DsSizes.itemCell * k, closeTo(cell, 0.01));
  // The actions pane is at least detailPaneWidth and takes the rest of
  // the width; the grid is anchored top-left (v0.49.27, § 6.2).
  expect(detail.width, greaterThanOrEqualTo(DsSizes.detailPaneWidth - 0.01));
  expect(detail.left, greaterThan(grid.right));
  expect(detail.left - grid.right,
      lessThanOrEqualTo(DsSizes.gridDetailGap + DsSizes.gridScrollbar + 0.01));
  expect(find.byKey(ValueKey('$p-scroll')), findsOneWidget);
}

void main() {
  test('inventoryScale mirrors inventoryLayout', () {
    expect(DsSizes.gridWidth(), 6 * 44 + 5 * 4);
    for (final (w, h) in const [
      (962.0, 447.0),
      (1462.0, 723.0),
      (1962.0, 994.0)
    ]) {
      final strip = w * 0.245;
      final l = inventoryLayout(w, h, stripWidth: strip + 8);
      expect(DsSizes.inventoryScale(w, h), l.scale, reason: '$w x $h');
    }
  });

  for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
    for (final t in const [TextSize.normal, TextSize.enormous]) {
      final name = '${size.width.toInt()} ${t.name}';
      testWidgets('caravana COMPRAR = INVENTARIO cell, 6 cols: $name',
          (tester) async {
        await pumpPanel(tester,
            profile: lootWarrior(),
            textSize: t,
            build: (v, c) => CharacterPanel(
                view: v, controller: c, initialTab: CharacterTab.inventory));
        tester.view.physicalSize = size;
        await tester.pump();
        await tester.pump();
        final inv =
            tester.getSize(find.byKey(const ValueKey('inv-cell-0'))).width;
        expect(find.byType(InventoryTab), findsOneWidget);

        final c = await pumpPanel(tester,
            profile: _profile(),
            textSize: t,
            build: (v, c) => BiomeNpcPanel(view: v, controller: c));
        tester.view.physicalSize = size;
        c.openResident(kBiomeNpcs.first);
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('ds-dialogue-text')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('npc-choice-comprar')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        _checkGrid(tester, 'npc-shop', cell: inv);
      });

      testWidgets('gallery templates: $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
          data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(t == TextSize.enormous ? 1.6 : 1)),
          child: const Scaffold(
              body: SingleChildScrollView(child: GridTemplatesMockup())),
        )));
        await tester.pump();
        expect(tester.takeException(), isNull);
        _checkGrid(tester, 'gallery-craft');
        _checkGrid(tester, 'gallery-col');
      });
    }
  }
}
