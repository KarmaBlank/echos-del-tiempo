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

Future<void> _tab(WidgetTester tester, ArmoryTab t) =>
    tapVisible(tester, find.byKey(ValueKey('tab-${t.index}')));

/// Recorre el selector de familia de COMPRAR hasta [label].
Future<void> _family(WidgetTester tester, String label) async {
  for (var i = 0; i < 20 && plain(tester, 'buy-family-value') != label; i++) {
    await tapVisible(tester, find.byKey(const ValueKey('buy-family-next')));
  }
  expect(plain(tester, 'buy-family-value'), label);
}

void main() {
  testWidgets('armería: comprar (cualquier clase), equipar y forjar',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: richWarrior(),
        build: (v, c) => ArmoryPanel(view: v, controller: c));
    PlayerProfile me() => c.view!.me!.profile;
    expect(find.text('ARMERIA'), findsOneWidget);
    expect(find.textContaining('Armas base para cualquier clase'),
        findsOneWidget);

    // COMPRAR: por defecto la familia propia; comprar la Ígnea ($300).
    await tapVisible(tester, find.byKey(const ValueKey('shop-row-espada_ignea')));
    expect(find.textContaining('Si la equipas'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('buy-espada_ignea')));
    expect(me().items.any((i) => i.baseId == 'espada_ignea'), isTrue);
    expect(me().credits, 700);
    // Otra familia (maga): se vende igual, con "Req" si no cumple.
    await _family(tester, 'MAGA');
    expect(find.byKey(const ValueKey('shop-row-baculo_fuego')), findsOneWidget);
    expect(plain(tester, 'shop-row-baculo_fuego'), contains('Req'));
    await tapVisible(tester, find.byKey(const ValueKey('shop-row-baculo_fuego')));
    expect(button(tester, 'buy-baculo_fuego').reason, isNull);
    // Una que no alcanza: motivo con lo que falta.
    await _family(tester, 'TODAS');
    await tapVisible(tester, find.byKey(const ValueKey('shop-row-mandoble_eco')));
    expect(button(tester, 'buy-mandoble_eco').reason, 'Faltan \$700');

    // FORJA: equipar la Ígnea (por uid) y forjar Poder.
    final uid = me().items.firstWhere((i) => i.baseId == 'espada_ignea').uid;
    await _tab(tester, ArmoryTab.forge);
    await tapVisible(tester, find.byKey(ValueKey('forge-row-$uid')));
    await tapVisible(tester, find.byKey(ValueKey('equip-$uid')));
    expect(me().equippedUid, uid);
    expect(button(tester, 'forge-confirm').reason, 'Elegí una mejora');
    await tapVisible(tester, find.byKey(ValueKey('up-$uid-pow')));
    expect(me().itemByUid(uid)!.forge.level(UpgradeStat.pow), 0);
    await tapVisible(tester, find.byKey(const ValueKey('forge-confirm')));
    expect(me().itemByUid(uid)!.forge.level(UpgradeStat.pow), 1);
    expect(me().credits,
        700 - CraftRules.forgeCost(progression.catalog.weapons['espada_ignea']!, Rarity.comun, 0));
    expect(find.textContaining('Espada Ignea +1'), findsWidgets);
  });

  testWidgets('forja: tope por rareza con pips y la pasiva sube cada 2',
      (tester) async {
    final start = lootWarrior();
    await pumpPanel(tester,
        profile: start,
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.forge));
    // Épico con forja 1: la próxima mejora sube Ímpetu I → II. Nivel de
    // objeto 10: tope min(8, 2 + 10/5) = 4 (combo_balance.md § 2).
    await tapVisible(tester, find.byKey(const ValueKey('forge-row-e1')));
    expect(plain(tester, 'forge-cap'), contains('Forja 1/4'));
    expect(plain(tester, 'forge-passive-note'),
        contains('Sube a nivel II en la próxima mejora'));
    final up = plain(tester, 'forge-passive-up-crit');
    expect(up, contains('La pasiva sube'));
    expect(up, contains('I → II'));
    // Antes → después del stat (crítico) y bono.
    final crit = plain(tester, 'forge-stat-crit');
    expect(crit, contains('Bono +0% → +2%'));
    expect(crit, contains('CRIT'));

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
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.forge));
    await tapVisible(tester, find.byKey(const ValueKey('forge-row-x1')));
    expect(button(tester, 'up-x1-spd').reason, 'Tope de forja (3)');
    expect(find.text('Tope de forja (3)'), findsWidgets);
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
    expect(button(tester, 'item-eter').reason, 'Faltan \$5');
    expect(find.text('Máximo 9'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('item-pot')));
    expect(c.view!.me!.profile.potions, 9);
  });
}
