import 'dart:convert';

import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/features/inventory/domain/inventory_menu.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_tab.dart';
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
import 'package:flutter/services.dart';
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
      // Corto, para la misma línea del menú (v0.9.9).
      expect(inventoryReasonShort(InventoryMenuAction.drop, 'Equipada'),
          'equipada');
      expect(
          inventoryReasonShort(
              InventoryMenuAction.give, 'No hay compañeros en la sala'),
          'sin compañeros');
      expect(inventoryReasonShort(InventoryMenuAction.sell, 'Arma inicial'),
          'arma inicial');
    });

    test('buscador: nombre, tipo, rareza y mod, sin tildes', () {
      final rules = progression;
      expect(inventoryMatches(rules, '', item: rareAxe), isTrue);
      expect(inventoryMatches(rules, 'hacha', item: rareAxe), isTrue);
      expect(inventoryMatches(rules, 'RARO', item: rareAxe), isTrue);
      expect(inventoryMatches(rules, 'hacha zzz', item: rareAxe), isFalse);
      expect(inventoryMatches(rules, 'baculo', item: commonStaff), isTrue);
      expect(
          inventoryMatches(rules, 'pocion', label: 'Poción de vida'), isTrue);
    });

    test('NUEVO: se marca al levantar, se saca al mirar y viaja en el JSON',
        () {
      final p0 = lootWarrior();
      final p1 = InventoryRules.receive(p0, const LootDrop.item(epicSword))!;
      final uid = p1.items.last.uid;
      expect(p1.fresh, {uid});
      // El alijo no marca.
      expect(
          InventoryRules.receive(p0, const LootDrop.item(epicSword),
                  markNew: false)!
              .fresh,
          isEmpty);
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

  testWidgets('clic derecho: menú compacto, motivo corto en la línea',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    // v0.9.9: sin panel de ACCIONES ni FICHA a la derecha.
    expect(find.text('ACCIONES'), findsNothing);
    expect(find.text('FICHA'), findsNothing);
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsNothing);
    expect(find.byKey(const ValueKey('inv-equip')), findsNothing);
    // La equipada: no se desarma.
    await tester.tap(find.byKey(const ValueKey('inv-equipped')),
        buttons: kSecondaryButton);
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsOneWidget);
    expect(button(tester, 'inv-salvage').reason,
        'No podés desarmar el arma equipada');
    // Una línea por acción: el motivo corto al lado, sin salto.
    final line = plain(tester, 'inv-salvage');
    expect(line, contains('Desarmar · equipada'));
    expect(line, isNot(contains('\n')));
    expect(plain(tester, 'inv-give'), contains('Dar a... · sin compañeros'));
    final rowH = tester.getSize(find.byKey(const ValueKey('inv-equip'))).height;
    expect(
        tester.getSize(find.byKey(const ValueKey('inv-salvage'))).height, rowH,
        reason: 'la desactivada ocupa una línea, como las demás');
    // Ancho ajustado al contenido, no medio panel.
    expect(tester.getSize(find.byKey(const ValueKey('inv-ctx-menu'))).width,
        lessThan(361));
    // Una desactivada no hace nada; una activa cierra el menú.
    await tester.tap(find.byKey(const ValueKey('inv-salvage')));
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inv-compare')));
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsNothing);
    expect(c.view!.me!.profile.items, hasLength(6));
  });

  testWidgets('teclado: Enter sobre la casilla elegida abre el menú',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    final i = _cell(c.view!.me!.profile, 'e1');
    await _tap(tester, 'inv-cell-$i');
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsOneWidget);
    // El cursor arranca en Equipar: Enter otra vez equipa.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.view!.me!.profile.equippedUid, 'e1');
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsNothing);
  });

  testWidgets('sin panel derecho: la grilla llena el ancho', (tester) async {
    await _inventory(tester, lootWarrior());
    expect(find.byKey(const ValueKey('inv-stats')), findsNothing);
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pumpAndSettle();
    final grid = tester.getRect(find.byKey(const ValueKey('inv-cell-0')));
    expect(grid.width, greaterThan(InventoryTab.cell));
    final last = tester.getRect(
        find.byKey(const ValueKey('inv-cell-${InventoryRules.columns - 1}')));
    expect(last.right - grid.left, greaterThan(InventoryTab.gridWidth));
    // En cuartos (o entera desde ×2): nitidez del pixel art.
    expect((grid.width / InventoryTab.cell * 4) % 1, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el tooltip de un arma compara las stats con la equipada',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    // Shift: la columna de la ficha de la equipada (v0.10.1).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    for (final uid in ['e1', 'l1', 'c1']) {
      final i = _cell(c.view!.me!.profile, uid);
      await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('inv-cell-$i'))));
      await tester.pump();
      final tip = tester.getRect(find.byKey(const ValueKey('inv-cmp-tip')));
      expect((Offset.zero & screen).inflate(1).contains(tip.topLeft), isTrue);
      expect(
          (Offset.zero & screen).inflate(1).contains(tip.bottomRight), isTrue,
          reason: '$uid: $tip');
      // v0.10.1: al lado va la ficha de la equipada; los cambios están
      // en la franja de CAMBIOS (no se repiten en el tooltip).
      expect(
          find.byKey(const ValueKey('inv-cmp-tip-equipped')), findsOneWidget);
      expect(find.byKey(const ValueKey('cmp-stat-ATQ')), findsNothing);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 300));
  });

  for (final size in const [
    Size(1024, 600),
    Size(1280, 720),
    Size(1920, 1080),
    Size(2560, 1440)
  ]) {
    testWidgets('sin overflow en ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
      await _inventory(tester, lootWarrior());
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el menú de la EQUIPADA no tapa el buscador', (tester) async {
    await _inventory(tester, lootWarrior());
    await tester.tap(find.byKey(const ValueKey('inv-equipped')),
        buttons: kSecondaryButton);
    await tester.pump();
    final menu = tester.getRect(find.byKey(const ValueKey('inv-ctx-menu')));
    final search = tester.getRect(find.byKey(const ValueKey('inv-search')));
    expect(menu.overlaps(search), isFalse, reason: '$menu vs $search');
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
        (Offset.zero & screen).contains(menu.bottomRight - const Offset(1, 1)),
        isTrue);
  });

  testWidgets('menú y tooltip nunca a la vez', (tester) async {
    await _inventory(tester, lootWarrior());
    final eq = find.byKey(const ValueKey('inv-equipped'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(eq));
    await tester.pump();
    expect(RetroHoverCard.anyShowing, isTrue);
    await tester.tap(eq, buttons: kSecondaryButton);
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-ctx-menu')), findsOneWidget);
    expect(RetroHoverCard.anyShowing, isFalse);
    await mouse.moveTo(tester.getCenter(eq) + const Offset(1, 1));
    await tester.pump();
    expect(RetroHoverCard.anyShowing, isFalse);
    await mouse.removePointer();
    await tester.pump(const Duration(milliseconds: 300));
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
