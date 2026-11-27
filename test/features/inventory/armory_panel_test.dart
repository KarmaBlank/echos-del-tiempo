import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

/// Guerrero Lv5 con FUE 16 / DES 10 (cumple Espada Ígnea), $1000 y el
/// Hacha Rompeturnos.
PlayerProfile richWarrior({int credits = 1000}) =>
    progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      level: 5,
      credits: credits,
      attributes: const PlayerAttributes({
        Attribute.vit: 10,
        Attribute.esp: 4,
        Attribute.agi: 6,
        Attribute.fue: 15,
        Attribute.des: 9,
      }),
      points: 2,
      inventory: const ['espada_bronce', 'hacha_rompe'],
      equipped: 'espada_bronce',
    ));


void main() {
  testWidgets('armería: comprar y vender en la grilla; forja aparte',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: richWarrior(),
        build: (v, c) => ArmoryPanel(view: v, controller: c));
    PlayerProfile me() => c.view!.me!.profile;
    expect(find.text('ARMERIA'), findsOneWidget);
    expect(find.textContaining('Armas base para cualquier clase'),
        findsOneWidget);

    // COMPRAR: la Ígnea (\$300) desde su casilla.
    await tapVisible(
        tester, find.byKey(const ValueKey('armory-buy-cell-espada_ignea')));
    await tapVisible(tester, find.byKey(const ValueKey('buy-espada_ignea')));
    expect(me().items.any((i) => i.baseId == 'espada_ignea'), isTrue);
    expect(me().credits, 700);

    // VENDER: la equipada no; otra sí.
    await tapVisible(tester, find.byKey(const ValueKey('tab-1')));
    final eq = me().equippedUid!;
    await tapVisible(tester, find.byKey(ValueKey('armory-sell-cell-$eq')));
    expect(tester.widget<DsButton>(find.byKey(ValueKey('sell-$eq'))).onPressed,
        isNull);
  });

  testWidgets('armería v0.36.1: ficha, VER DETALLE y franja de cambios',
      (tester) async {
    await pumpPanel(tester,
        profile: richWarrior(),
        build: (v, c) => ArmoryPanel(view: v, controller: c));
    // COMPRAR: detalle con la ficha entera y el plegable VER DETALLE.
    await tapVisible(
        tester, find.byKey(const ValueKey('armory-buy-cell-espada_ignea')));
    final detail = find.byKey(const ValueKey('armory-buy-detail'));
    expect(find.descendant(of: detail, matching: find.byKey(const ValueKey('armory-sheet'))),
        findsOneWidget);
    expect(find.descendant(of: detail, matching: find.textContaining('VER DETALLE', findRichText: true)),
        findsWidgets);
    // Izquierda: la franja del inventario, con CAMBIOS contra la equipada.
    final side = find.byKey(const ValueKey('armory-buy-side'));
    expect(find.descendant(of: side, matching: find.byKey(const ValueKey('inv-strip'))),
        findsOneWidget);
    expect(find.descendant(of: side, matching: find.text('CAMBIOS')),
        findsOneWidget);
    // VENDER: la equipada muestra ACTUAL (no hay cambios).
    await tapVisible(tester, find.byKey(const ValueKey('tab-1')));
    final sell = find.byKey(const ValueKey('armory-sell-side'));
    expect(find.descendant(of: sell, matching: find.text('ACTUAL')),
        findsOneWidget);
  });

  testWidgets('forja: forjar la equipada', (tester) async {
    final c = await pumpPanel(tester,
        profile: richWarrior(),
        build: (v, c) => ForgePanel(view: v, controller: c));
    PlayerProfile me() => c.view!.me!.profile;
    expect(find.text('FORJA'), findsWidgets);
    // FORJA: la equipada (por uid), forjar Poder.
    final uid = me().equippedUid!;
    final base = me().itemByUid(uid)!.baseId;
    await tapVisible(tester, find.byKey(ValueKey('forge-row-$uid')));
    expect(button(tester, 'forge-confirm').reason, 'Elegí una mejora');
    await tapVisible(tester, find.byKey(ValueKey('up-$uid-pow')));
    expect(me().itemByUid(uid)!.forge.level(UpgradeStat.pow), 0);
    await tapVisible(tester, find.byKey(const ValueKey('forge-confirm')));
    expect(me().itemByUid(uid)!.forge.level(UpgradeStat.pow), 1);
    expect(me().credits,
        1000 - CraftRules.forgeCost(progression.catalog.weapons[base]!, Rarity.comun, 0));
  });

  testWidgets('forja: tope por rareza con pips y la pasiva sube cada 2',
      (tester) async {
    final start = lootWarrior();
    await pumpPanel(tester,
        profile: start,
        build: (v, c) =>
            ForgePanel(view: v, controller: c, initialTab: ForgeHallTab.upgrade));
    // Épico con forja 1: la próxima mejora sube Ímpetu I → II. Nivel de
    // objeto 10: tope min(8, 2 + 10/5) = 4 (combo_balance.md § 2).
    await tapVisible(tester, find.byKey(const ValueKey('forge-row-e1')));
    expect(plain(tester, 'forge-cap'), contains('Forja 1/4'));
    expect(plain(tester, 'forge-passive-note'),
        contains('Sube a nivel II en la próxima mejora'));
    // La fila dice lo justo: CRIT antes → después y el costo.
    expect(plain(tester, 'forge-stat-crit'), contains('CRIT'));
    expect(plain(tester, 'forge-stat-crit'), isNot(contains('Bono')));
    // Elegirla y abrir MÁS DETALLE: bono y la pasiva que sube.
    await tapVisible(tester, find.byKey(const ValueKey('up-e1-crit')));
    await openForgeMore(tester);
    final up = plain(tester, 'forge-passive-up-crit');
    expect(up, contains('La pasiva sube'));
    expect(up, contains('I → II'));
    final crit = plain(tester, 'forge-detail-crit');
    expect(crit, contains('Bono +0%'));
    expect(crit, contains('+2%'));

    // Común de nivel 1: tope min(3, 2 + 1/5) = 2.
    await tapVisible(tester, find.byKey(const ValueKey('forge-row-espada_bronce')));
    expect(plain(tester, 'forge-cap'), contains('Forja 0/2'));
    expect(plain(tester, 'forge-passive-note'), contains('Sin pasiva'));
  });

  testWidgets('forja: Común al tope dice el motivo', (tester) async {
    final p = lootWarrior(extra: const [
      ItemInstance(
          uid: 'x1',
          baseId: 'espada_carmesi',
          // Nivel 5: el tope por nivel (2 + 5/5 = 3) iguala al de la rareza.
          itemLevel: 5,
          forge: WeaponUpgradeLevels(pow: 2, crit: 1)),
    ]);
    await pumpPanel(tester,
        profile: p,
        build: (v, c) =>
            ForgePanel(view: v, controller: c, initialTab: ForgeHallTab.upgrade));
    await tapVisible(tester, find.byKey(const ValueKey('forge-row-x1')));
    expect(button(tester, 'up-x1-spd').reason, 'Tope de forja (3)');
    expect(find.text('Tope de forja (3)'), findsWidgets);
    // Bloqueada: tocarla no la elige y FORJAR sigue gris.
    await tapVisible(tester, find.byKey(const ValueKey('up-x1-spd')));
    expect(button(tester, 'forge-confirm').reason, 'Elegí una mejora');
  });

  testWidgets('forja: elegir, costo a la derecha y gris si no alcanza',
      (tester) async {
    final w = progression.catalog.weapons['espada_bronce']!;
    final cost = CraftRules.forgeCost(w, Rarity.comun, 0);
    await pumpPanel(tester,
        profile: lootWarrior(credits: cost - 1),
        build: (v, c) =>
            ForgePanel(view: v, controller: c, initialTab: ForgeHallTab.upgrade));
    await tapVisible(tester, find.byKey(const ValueKey('forge-row-espada_bronce')));
    expect(plain(tester, 'forge-cost-pow'), contains('$cost'));
    final tag = tester.widget<DsTag>(find.byKey(const ValueKey('forge-cost-pow')));
    final reason = button(tester, 'up-espada_bronce-pow').reason;
    // Sin créditos: bloqueada (gris) o el costo en rojo.
    expect(reason != null || tag.color == DsColors.danger, isTrue);
    await tapVisible(tester, find.byKey(const ValueKey('up-espada_bronce-pow')));
    expect(button(tester, 'forge-confirm').reason, isNotNull);
  });

  testWidgets('forja: con créditos, elegir marca la fila y habilita FORJAR',
      (tester) async {
    await pumpPanel(tester,
        profile: lootWarrior(credits: 5000),
        build: (v, c) =>
            ForgePanel(view: v, controller: c, initialTab: ForgeHallTab.upgrade));
    await tapVisible(tester, find.byKey(const ValueKey('forge-row-espada_bronce')));
    expect(button(tester, 'forge-confirm').reason, 'Elegí una mejora');
    await tapVisible(tester, find.byKey(const ValueKey('up-espada_bronce-crit')));
    expect(button(tester, 'forge-confirm').reason, isNull);
    final row = tester.widget<DsActionRow>(find.descendant(
        of: find.byKey(const ValueKey('up-espada_bronce-crit')),
        matching: find.byType(DsActionRow)));
    expect(row.selected, isTrue);
    expect(find.byKey(const ValueKey('forge-more')), findsOneWidget);
  });

  testWidgets('armería: consumibles al máximo y sin créditos', (tester) async {
    final c = await pumpPanel(tester,
        profile: progression.normalize(PlayerProfile(
            name: 'Bo',
            classId: 'maga',
            credits: 35,
            potions: 9,
            ethers: 0)),
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.items));
    expect(button(tester, 'item-pot').reason, 'Máximo 9');
    expect(button(tester, 'item-eter').reason, 'Faltan ₵5');
    expect(find.text('Máximo 9'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('item-pot')));
    expect(c.view!.me!.profile.potions, 9);
  });
}
