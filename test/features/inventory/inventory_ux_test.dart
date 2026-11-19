import 'dart:convert';

import 'package:echos_del_tiempo/features/inventory/domain/inventory_menu.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/inventory_sort.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

// UX del inventario v0.9.7 (docs/specs/panels.md § "Inventario", loot.md
// § 17.4): buscador, marca NUEVO, menú de acciones, LIMPIAR y la equipada
// fuera de la grilla.

Future<SessionController> _inventory(WidgetTester tester, PlayerProfile p) =>
    pumpPanel(tester,
        profile: p,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));

Future<void> _tap(WidgetTester tester, String key) =>
    tapVisible(tester, find.byKey(ValueKey(key)));

int _cell(PlayerProfile p, String token) =>
    InventoryRules.layout(p).cells.indexOf(token);

void main() {
  group('dominio', () {
    test('motivos en una línea', () {
      expect(inventoryReasonLine(InventoryMenuAction.salvage, 'Está equipada'),
          'No podés desarmar el arma equipada');
      expect(inventoryReasonLine(InventoryMenuAction.give, 'Equipada'),
          'No podés dársela a otro jugador: está equipada');
      expect(inventoryReasonLine(InventoryMenuAction.drop, 'Arma inicial'),
          'No podés tirar tu última arma inicial');
      expect(inventoryReasonLine(InventoryMenuAction.give, 'No en batalla'),
          'No en batalla');
    });

    test('buscador: nombre, tipo, rareza y mod, sin tildes', () {
      final rules = progression;
      expect(inventoryMatches(rules, '', item: rareAxe), isTrue);
      expect(inventoryMatches(rules, 'hacha', item: rareAxe), isTrue);
      expect(inventoryMatches(rules, 'RARO', item: rareAxe), isTrue);
      expect(inventoryMatches(rules, 'hacha zzz', item: rareAxe), isFalse);
      expect(inventoryMatches(rules, 'baculo', item: commonStaff), isTrue);
      expect(inventoryMatches(rules, 'pocion', label: 'Poción de vida'),
          isTrue);
    });

    test('NUEVO: se marca al levantar, se saca al mirar y viaja en el JSON',
        () {
      final p0 = lootWarrior();
      final p1 = InventoryRules.receive(p0, const LootDrop.item(epicSword))!;
      final uid = p1.items.last.uid;
      expect(p1.fresh, {uid});
      // El alijo no marca.
      expect(InventoryRules.receive(p0, const LootDrop.item(epicSword),
              markNew: false)!
          .fresh, isEmpty);
      final back = PlayerProfile.fromJson(
          jsonDecode(jsonEncode(p1.toJson())) as Map<String, Object?>);
      expect(back.fresh, {uid});
      expect(p1.toJson()['pv'], 4);
      expect(InventoryRules.markSeen(p1, [uid])!.fresh, isEmpty);
      expect(InventoryRules.markSeen(p1, ['nada']), isNull);
      // Lo que se va pierde la marca.
      expect(InventoryRules.removeItem(p1, uid).fresh, isEmpty);
      // `seen` por la red.
      final a = ActionJson.fromJson(ActionJson.toJson(SeenItemsAction([uid])));
      expect((a as SeenItemsAction).uids, [uid]);
      expect(kProtocolVersion, greaterThanOrEqualTo(18));
      expect(InventorySortKey.recent.label, 'Últimos levantados');
    });

    test('la equipada no ocupa casilla', () {
      final p = lootWarrior();
      expect(InventoryRules.tokens(p), isNot(contains(p.equippedUid)));
      expect(InventoryRules.cellsUsed(p), p.items.length - 1);
    });
  });

  testWidgets('buscador: atenúa lo que no coincide', (tester) async {
    final c = await _inventory(tester, lootWarrior());
    final p = c.view!.me!.profile;
    await tester.enterText(find.byKey(const ValueKey('inv-search')), 'hacha');
    await tester.pump();
    double op(String uid) => tester
        .widget<Opacity>(find.descendant(
            of: find.byKey(ValueKey('inv-cell-${_cell(p, uid)}')),
            matching: find.byType(Opacity)))
        .opacity;
    expect(op('m1'), lessThan(1));
    expect(
        find.descendant(
            of: find.byKey(ValueKey('inv-cell-${_cell(p, 'r1')}')),
            matching: find.byType(Opacity)),
        findsNothing,
        reason: 'el hacha coincide');
  });

  testWidgets('NUEVO: marca en la casilla y se saca al pasar el mouse',
      (tester) async {
    final fresh = lootWarrior().copyWith(fresh: {'r1'});
    final c = await _inventory(tester, fresh);
    final i = _cell(c.view!.me!.profile, 'r1');
    expect(find.byKey(ValueKey('inv-new-$i')), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('inv-cell-$i'))));
    await tester.pump();
    expect(c.view!.me!.profile.fresh, isEmpty);
    expect(find.byKey(ValueKey('inv-new-$i')), findsNothing);
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('clic derecho: menú con la acción desactivada y su motivo',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    // La equipada: no se desarma.
    await tester.tap(find.byKey(const ValueKey('inv-equipped')),
        buttons: kSecondaryButton);
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsOneWidget);
    expect(button(tester, 'inv-ctx-salvage').reason,
        'No podés desarmar el arma equipada');
    expect(plain(tester, 'inv-ctx-salvage'),
        contains('No podés desarmar el arma equipada'));
    // Una desactivada no hace nada; una activa cierra el menú.
    await tester.tap(find.byKey(const ValueKey('inv-ctx-salvage')));
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inv-ctx-compare')));
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsNothing);
    expect(c.view!.me!.profile.items, hasLength(6));
  });

  testWidgets('LIMPIAR: menú con elegir a mano y lotes por rareza',
      (tester) async {
    await _inventory(tester, lootWarrior());
    await _tap(tester, 'inv-clean');
    expect(find.byKey(const ValueKey('inv-clean-menu')), findsOneWidget);
    for (final k in [
      'inv-clean-menu-pick',
      'inv-clean-menu-salvage-comun',
      'inv-clean-menu-sell-raro',
    ]) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    await _tap(tester, 'inv-clean-menu-sell-magico');
    expect(plain(tester, 'inv-clean-summary'), contains('vender'));
  });
}
