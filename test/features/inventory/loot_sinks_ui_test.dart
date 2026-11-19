import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

// Inventario: DESARMAR / VENDER un arma y LIMPIAR INVENTARIO (lotes),
// panels.md § "Inventario".

Future<SessionController> _inventory(WidgetTester tester, PlayerProfile p) =>
    pumpPanel(tester,
        profile: p,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));

Future<void> _tap(WidgetTester tester, String key) =>
    tapVisible(tester, find.byKey(ValueKey(key)));

int _cell(PlayerProfile p, String token) =>
    InventoryRules.layout(p).cells.indexOf(token);

/// Dos Comunes más (para los lotes).
PlayerProfile _withCommons() => lootWarrior(extra: const [
      ItemInstance(uid: 'c2', baseId: 'arco_corto', itemLevel: 30),
      ItemInstance(uid: 'c3', baseId: 'espada_ignea', itemLevel: 2),
    ]);

void main() {
  testWidgets('vender un arma: precio en el botón, confirmación y créditos',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    final price = c.engine.progression.crafting.sellPrice(rareAxe);
    await _tap(tester, 'inv-cell-${_cell(me(), 'r1')}');
    await openInventoryActions(tester);
    expect(plain(tester, 'inv-sell'), contains('Vender \$$price'));
    await _tap(tester, 'inv-sell');
    expect(plain(tester, 'inv-craft-question'), contains('¿Vender'));
    expect(plain(tester, 'inv-craft-question'), contains('+\$$price'));
    expect(plain(tester, 'inv-craft-question'), contains('se destruye'));
    await _tap(tester, 'inv-craft-confirm');
    expect(me().itemByUid('r1'), isNull);
    expect(me().credits, 5000 + price);
  });

  testWidgets('desarmar: lo seguro + lo que puede salir; la equipada no',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    // La equipada: deshabilitado con el motivo.
    await _tap(tester, 'inv-equipped');
    await openInventoryActions(tester);
    expect(button(tester, 'inv-salvage').reason,
        'No podés desarmar el arma equipada');
    await openInventoryActions(tester);
    expect(button(tester, 'inv-sell').reason, 'No podés vender el arma equipada');
    // El Épico: 2 Cristales seguros y chance de Prisma.
    await _tap(tester, 'inv-cell-${_cell(me(), 'e1')}');
    await _tap(tester, 'inv-salvage');
    final q = plain(tester, 'inv-craft-question');
    expect(q, contains('+2 Cristal de Era'));
    expect(q, contains('35% de +1 Prisma Roto'));
    await _tap(tester, 'inv-craft-cancel');
    expect(find.byKey(const ValueKey('inv-craft-question')), findsNothing);
    // El Común: determinístico.
    await _tap(tester, 'inv-cell-${_cell(me(), 'c1')}');
    await _tap(tester, 'inv-salvage');
    await _tap(tester, 'inv-craft-confirm');
    expect(me().itemByUid('c1'), isNull);
    expect(me().material(CraftMaterial.esquirla), 3);
  });

  testWidgets('limpiar inventario: elegir verbo y rareza, resumen y confirmar',
      (tester) async {
    final c = await _inventory(tester, _withCommons());
    PlayerProfile me() => c.view!.me!.profile;
    await _tap(tester, 'inv-clean');
    // Por defecto: desarmar Comunes (no la equipada).
    expect(find.text('COMUNES (3)'), findsOneWidget);
    // c1 (Nv 2) 1 + c2 (Nv 30) 2 + c3 1 = 4 Esquirlas.
    expect(plain(tester, 'inv-clean-summary'),
        contains('Vas a desarmar 3 Comunes → +4 Esquirla del Eco'));
    expect(plain(tester, 'inv-clean-list'), contains('Báculo de Fuego'));
    expect(plain(tester, 'inv-clean-list'), isNot(contains('Espada de Bronce')));
    // Vender: suma de precios.
    await _tap(tester, 'inv-clean-sell');
    final crafting = c.engine.progression.crafting;
    final total = [
      for (final it in crafting.batchTargets(me(), Rarity.comun))
        crafting.sellPrice(it)
    ].fold(0, (a, b) => a + b);
    expect(plain(tester, 'inv-clean-summary'),
        contains('Vas a vender 3 Comunes → +\$$total'));
    // Mágicos: chance de Cristal.
    await _tap(tester, 'inv-clean-salvage');
    await _tap(tester, 'inv-clean-rarity-magico');
    expect(plain(tester, 'inv-clean-summary'), contains('1 Mágico'));
    expect(plain(tester, 'inv-clean-summary'), contains('25% de +1 Cristal'));
    // Confirmar desarmar Comunes.
    await _tap(tester, 'inv-clean-rarity-comun');
    await _tap(tester, 'inv-clean-confirm');
    expect(me().items.where((i) => i.rarity == Rarity.comun).map((i) => i.uid),
        ['espada_bronce']);
    expect(me().material(CraftMaterial.esquirla), 2 + 4);
    // Ya no quedan: el botón dice por qué.
    expect(button(tester, 'inv-clean-confirm').reason,
        'No hay armas de rareza Común');
    await _tap(tester, 'inv-clean-cancel');
    expect(find.byKey(const ValueKey('inv-clean-summary')), findsNothing);
  });
}
