import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

// UI mínima (docs/specs/ui_minimal.md): plantilla de listas de armas
// (buscador + equipada fija), pasos de FUSIÓN y FORJA y LIMPIAR como único
// lugar de las acciones en lote.

Future<void> _tap(WidgetTester tester, String key) =>
    tapVisible(tester, find.byKey(ValueKey(key)));

Finder _k(String key) => find.byKey(ValueKey(key));

/// La fila fijada [pinned] muestra la equipada (`espada_bronce`) y la
/// marca EQUIPADA.
void _expectPinned(String pinned, {String uidKey = ''}) {
  expect(_k(pinned), findsOneWidget, reason: pinned);
  expect(find.descendant(of: _k(pinned), matching: find.text('EQUIPADA')),
      findsOneWidget);
  if (uidKey.isNotEmpty) {
    expect(find.descendant(of: _k(pinned), matching: _k(uidKey)),
        findsOneWidget);
  }
}

Future<void> _armory(WidgetTester tester, ForgeHallTab tab,
        [PlayerProfile? p]) =>
    pumpPanel(tester,
        profile: p ?? lootWarrior(),
        build: (v, c) => ForgePanel(view: v, controller: c, initialTab: tab));

void main() {
  group('listas de armas: buscador + equipada fija', () {
    testWidgets('FUSIÓN destino: la equipada queda fija al buscar',
        (tester) async {
      await _armory(tester, ForgeHallTab.fuse);
      expect(_k('bench-weapon-search'), findsOneWidget);
      _expectPinned('bench-weapon-pinned', uidKey: 'bench-weapon-espada_bronce');
      await tester.enterText(_k('bench-weapon-search'), 'hacha');
      await tester.pump();
      // No coincide con "hacha" pero sigue arriba.
      _expectPinned('bench-weapon-pinned', uidKey: 'bench-weapon-espada_bronce');
      expect(_k('bench-weapon-m1'), findsNothing);
    });

    testWidgets('FUSIÓN origen: buscador y equipada fija con candado',
        (tester) async {
      await _armory(tester, ForgeHallTab.fuse);
      await _tap(tester, 'bench-weapon-r1');
      await _tap(tester, 'bench-next');
      await _tap(tester, 'bench-op-${CraftOp.transferAffix.name}');
      expect(_k('craft-source-search'), findsOneWidget);
      _expectPinned('craft-source-pinned');
      expect(
          find.descendant(
              of: _k('craft-source-pinned'), matching: _k('clean-lock')),
          findsOneWidget);
    });

    testWidgets('FORJA: buscador y equipada fija', (tester) async {
      await _armory(tester, ForgeHallTab.upgrade);
      expect(_k('forge-search'), findsOneWidget);
      _expectPinned('forge-pinned', uidKey: 'forge-row-espada_bronce');
      await tester.enterText(_k('forge-search'), 'hacha');
      await tester.pump();
      _expectPinned('forge-pinned', uidKey: 'forge-row-espada_bronce');
      expect(_k('forge-row-m1'), findsNothing);
      expect(_k('forge-row-r1'), findsOneWidget);
    });

    testWidgets('ARMERÍA COMPRAR: grilla con buscador (v0.32.3)',
        (tester) async {
      await pumpPanel(tester,
          profile: lootWarrior(),
          build: (v, c) => ArmoryPanel(view: v, controller: c));
      expect(_k('armory-buy-search'), findsOneWidget);
      final cells = find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('armory-buy-cell-'));
      final before = cells.evaluate().length;
      expect(before, greaterThan(0));
      expect(_k('armory-buy-detail'), findsOneWidget);
      await tester.enterText(_k('armory-buy-search'), 'zzz');
      await tester.pump();
      expect(cells.evaluate().length, lessThan(before));
    });
  });

  group('pasos', () {
    testWidgets('FUSIÓN: 1 DESTINO › 2 ACCIÓN › 3 PREVIA',
        (tester) async {
      await _armory(tester, ForgeHallTab.fuse);
      expect(plain(tester, 'bench-crumb-0'), '1 DESTINO');
      expect(plain(tester, 'bench-crumb-1'), startsWith('2 ACCI'));
      expect(plain(tester, 'bench-crumb-2'), '3 PREVIA');
      expect(_k('bench-step-0'), findsOneWidget);
      await _tap(tester, 'bench-weapon-r1');
      await _tap(tester, 'bench-next');
      expect(_k('bench-step-1'), findsOneWidget);
      await _tap(tester, 'bench-op-${CraftOp.reroll.name}');
      expect(_k('bench-step-2'), findsOneWidget);
      // Volver un paso desde las migas.
      await _tap(tester, 'bench-crumb-1');
      expect(_k('bench-step-1'), findsOneWidget);
    });

    testWidgets('FORJA: elegir mejora y después FORJAR', (tester) async {
      final c = await pumpPanel(tester,
          profile: lootWarrior(),
          build: (v, c) => ForgePanel(
              view: v, controller: c, initialTab: ForgeHallTab.upgrade));
      PlayerProfile me() => c.view!.me!.profile;
      expect(plain(tester, 'forge-crumb-0'), '1 ARMA');
      expect(plain(tester, 'forge-crumb-1'), '2 MEJORA');
      expect(button(tester, 'forge-confirm').reason, 'Elegí una mejora');
      await _tap(tester, 'up-espada_bronce-pow');
      expect(me().itemByUid('espada_bronce')!.forge.level(UpgradeStat.pow), 0);
      expect(button(tester, 'forge-confirm').reason, isNull);
      await _tap(tester, 'forge-confirm');
      expect(me().itemByUid('espada_bronce')!.forge.level(UpgradeStat.pow), 1);
    });
  });

  testWidgets('LIMPIAR: un solo lugar para las acciones en lote',
      (tester) async {
    await pumpPanel(tester,
        profile: lootWarrior(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    // Cerrado: no hay caja de lotes en ningún otro lado.
    expect(_k('inv-clean-menu'), findsNothing);
    expect(_k('inv-clean-summary'), findsNothing);
    await _tap(tester, 'inv-clean');
    expect(_k('inv-clean-menu'), findsOneWidget);
    await _tap(tester, 'inv-clean-menu-sell-comun');
    expect(_k('inv-clean-menu'), findsNothing);
    expect(_k('inv-clean-summary'), findsOneWidget);
    // El detalle no repite selectores de modo ni de rareza.
    expect(_k('inv-clean-mode-pick'), findsNothing);
    expect(_k('inv-clean-rarity-comun'), findsNothing);
    expect(find.text('LIMPIAR ▼'), findsOneWidget);
  });
}
