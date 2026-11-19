import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/inventory/domain/shop_guards.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

Future<SessionController> _inventory(WidgetTester tester, PlayerProfile p,
        {SessionView Function(SessionView v, SessionController c)? view}) =>
    pumpPanel(tester,
        profile: p,
        build: (v, c) => CharacterPanel(
            view: view == null ? v : view(v, c),
            controller: c,
            initialTab: CharacterTab.inventory));

Future<void> _tap(WidgetTester tester, String key) =>
    tapVisible(tester, find.byKey(ValueKey(key)));

/// Casilla de la grilla donde está [token].
int cellOf(PlayerProfile p, String token) =>
    InventoryRules.layout(p).cells.indexOf(token);

void main() {
  testWidgets('grilla: equipada aparte, pilas con cantidad y ficha',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    final p = c.view!.me!.profile;
    expect(find.byKey(const ValueKey('inv-equipped')), findsOneWidget);
    for (var i = 0; i < InventoryRules.cells; i++) {
      expect(find.byKey(ValueKey('inv-cell-$i')), findsOneWidget);
    }
    // 5 armas (v0.5.1: las pilas van en CONSUMIBLES / MATERIALES).
    expect(plain(tester, 'inv-summary'), contains('Casillas 5/40'));
    // Elegir el Épico muestra su ficha y la comparación.
    await _tap(tester, 'inv-cell-${cellOf(p, 'e1')}');
    expect(find.textContaining('Filo del Alba'), findsWidgets);
    expect(find.textContaining('Comparada con Espada de Bronce'), findsOneWidget);
    // Una pila: cantidad en la casilla y en la ficha.
    await _tap(tester, 'inv-stack-mat:esquirla');
    expect(find.textContaining('Esquirla del Eco x2'), findsOneWidget);
  });

  testWidgets('mover: con MOVER y arrastrando', (tester) async {
    final c = await _inventory(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    final from = cellOf(me(), 'r1');
    await _tap(tester, 'inv-cell-$from');
    await _tap(tester, 'inv-move');
    expect(find.text('Elige la casilla destino'), findsOneWidget);
    await _tap(tester, 'inv-cell-30');
    expect(cellOf(me(), 'r1'), 30);
    expect(InventoryRules.layout(me()).cells[from], isNull);

    // Arrastrar el Mágico a la casilla 39.
    final m = cellOf(me(), 'm1');
    final start = tester.getCenter(find.byKey(ValueKey('inv-cell-$m')));
    final end = tester.getCenter(find.byKey(const ValueKey('inv-cell-39')));
    final g = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(Offset.lerp(start, end, 0.5)!);
    await tester.pump();
    await g.moveTo(end);
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(cellOf(me(), 'm1'), 39);
  });

  testWidgets('equipar: cualquier clase con nivel y requisitos', (tester) async {
    // Guerrero Lv5 con ESP 4: el báculo de maga pide ESP 14.
    final c = await _inventory(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    await _tap(tester, 'inv-cell-${cellOf(me(), 'c1')}');
    expect(button(tester, 'inv-equip').reason,
        'No podés equiparla. Requisitos: ESP 14');
    expect(plain(tester, 'inv-equip'), contains('Requisitos: ESP 14'));
    // El Épico (Nv 2, FUE 14, DES 8) sí.
    await _tap(tester, 'inv-cell-${cellOf(me(), 'e1')}');
    expect(button(tester, 'inv-equip').reason, isNull);
    await _tap(tester, 'inv-equip');
    expect(me().equippedUid, 'e1');
  });

  testWidgets('equipar: nivel de la base y arma de otra clase que cumple',
      (tester) async {
    // Guerrero con ESP 14 (Lv7): equipa el báculo de maga.
    final low = lootWarrior(level: 7, esp: 14);
    final c = await _inventory(tester, low);
    PlayerProfile me() => c.view!.me!.profile;
    await _tap(tester, 'inv-cell-${cellOf(me(), 'c1')}');
    expect(button(tester, 'inv-equip').reason, isNull);
    await _tap(tester, 'inv-equip');
    expect(me().equippedUid, 'c1', reason: 'un guerrero equipa un báculo');
    final g = ShopGuards(progression, SessionMode.lobby);
    final lv1 = me().copyWith(level: 1);
    expect(g.equip(lv1, 'e1'), 'Nivel 2');
    expect(ShopGuards(progression, SessionMode.field).equip(me(), 'e1'),
        ShopGuards.notShopping);
    // Desarmar / vender / limpiar: también en la aventura, no en batalla.
    final field = ShopGuards(progression, SessionMode.field);
    expect(field.craft(me(), const CraftAction(CraftOp.salvage, 'c1')),
        isNot(ShopGuards.notDiscarding));
    expect(
        ShopGuards(progression, SessionMode.battle)
            .craft(me(), const CraftAction(CraftOp.salvage, 'c1')),
        ShopGuards.notDiscarding);
    expect(field.craft(me(), const CraftAction.reforge('c1', 'espada_ignea')),
        ShopGuards.notShopping);
  });

  testWidgets('tirar: pide confirmación; dar: deshabilitado solo', (tester) async {
    final c = await _inventory(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    await _tap(tester, 'inv-cell-${cellOf(me(), 'm1')}');
    // Sin compañeros: DAR A... con el motivo.
    expect(button(tester, 'inv-give').reason, 'No hay compañeros en la sala');
    await _tap(tester, 'inv-drop');
    expect(plain(tester, 'inv-drop-question'), contains('al piso'));
    expect(me().itemByUid('m1'), isNotNull, reason: 'todavía no');
    await _tap(tester, 'inv-drop-confirm');
    expect(me().itemByUid('m1'), isNull);
    expect(c.session!.ground, hasLength(1));
    // La equipada no se tira.
    await _tap(tester, 'inv-equipped');
    expect(button(tester, 'inv-drop').reason, 'No podés tirar el arma equipada');
    // Pilas: elegir cuántas.
    await _tap(tester, 'inv-stack-mat:esquirla');
    await _tap(tester, 'inv-count-inc');
    expect(find.text('x2'), findsOneWidget);
    await _tap(tester, 'inv-drop');
    await _tap(tester, 'inv-drop-confirm');
    expect(me().material(CraftMaterial.esquirla), 0);
  });

  testWidgets('compañeros: pestaña de solo lectura y DAR A habilitado',
      (tester) async {
    final mate = newProfile('Beto', 'maga');
    final c = await _inventory(tester, lootWarrior(),
        view: (v, c) => SessionView(
              session: c.engine.addPlayer(v.session, 'p9', mate)!.state,
              localId: v.localId,
              map: v.map,
            ));
    final p = c.view!.me!.profile;
    await _tap(tester, 'inv-cell-${cellOf(p, 'm1')}');
    expect(button(tester, 'inv-give-p9').reason, isNull);
    // La equipada no se da.
    await _tap(tester, 'inv-equipped');
    expect(button(tester, 'inv-give-p9').reason,
        'No podés dársela a otro jugador: está equipada');
    // Inventario del compañero: solo lectura, sin botones.
    await _tap(tester, 'inv-owner-p9');
    expect(find.textContaining('(solo lectura)'), findsOneWidget);
    expect(find.text('Solo lectura'), findsOneWidget);
    expect(find.byKey(const ValueKey('inv-drop')), findsNothing);
  });

  test('dar: motivos = rechazos del motor (lleno, batalla)', () {
    final e = sessionEngine();
    var s = e.addPlayer(e.create(), 'p0', lootWarrior())!.state;
    // Compañero con la grilla llena.
    var full = newProfile('Beto', 'maga');
    for (var i = 0; InventoryRules.freeCells(full) > 0; i++) {
      full = InventoryRules.addItem(
              full, ItemInstance.common('x$i', 'baculo_aprendiz'))
          .$1;
    }
    s = e.addPlayer(s, 'p1', full)!.state;
    final g = ShopGuards(e.progression, s.mode);
    final me = s.players['p0']!.profile;
    final mate = s.players['p1']!;
    expect(g.give(me, 'm1', mate), 'Beto: Inventario lleno');
    expect(e.apply(s, 'p0', const GiveItemAction('p1', 'm1')), isNull);
    // Una pila que ya tiene: entra.
    expect(g.give(me, 'pot', mate), isNull);
    expect(e.apply(s, 'p0', const GiveItemAction('p1', 'pot')), isNotNull);
    expect(ShopGuards(e.progression, SessionMode.battle).give(me, 'm1', mate),
        'No en batalla');
  });

  testWidgets('tecla I abre el inventario y lo cierra', (tester) async {
    final c = await pumpPanel(tester,
        profile: lootWarrior(), build: (v, c) => const SizedBox.shrink());
    expect(c.handleKey(LogicalKeyboardKey.keyI), isTrue);
    expect(c.view!.panel, WorldPanel.inventory);
    c.handleKey(LogicalKeyboardKey.keyI);
    expect(c.view!.panel, isNull);
  });

  testWidgets('CONFIRMAR AL TIRAR en NO: TIRAR tira enseguida',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    final container = ProviderScope.containerOf(
        tester.element(find.byType(CharacterPanel)));
    final settings = container.read(gameSettingsProvider.notifier);
    await settings.update(settings.state.copyWith(confirmDrop: false));
    await _tap(tester, 'inv-cell-${cellOf(me(), 'm1')}');
    await _tap(tester, 'inv-drop');
    expect(find.byKey(const ValueKey('inv-drop-question')), findsNothing);
    expect(me().itemByUid('m1'), isNull);
    expect(c.session!.ground, hasLength(1));
  });
}
