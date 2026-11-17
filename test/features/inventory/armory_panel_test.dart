import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// Guerrero Lv5 con FUE 16 / DES 10 (cumple Espada Ígnea), $1000 y el
/// Hacha Rompeturnos para sacrificar.
PlayerProfile richWarrior() => progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      level: 5,
      credits: 1000,
      attributes: const PlayerAttributes({
        Attribute.vit: 10,
        Attribute.esp: 4,
        Attribute.agi: 6,
        Attribute.fue: 16,
        Attribute.des: 10,
      }),
      points: 4,
      inventory: const ['espada_bronce', 'hacha_rompe'],
      equipped: 'espada_bronce',
    ));

PanelButton _button(WidgetTester tester, String key) =>
    tester.widget<PanelButton>(find.byKey(ValueKey(key)));

void main() {
  testWidgets('armería: comprar, equipar, mejorar y fusionar', (tester) async {
    final c = await pumpPanel(tester,
        profile: richWarrior(),
        build: (v, c) => ArmoryPanel(view: v, controller: c));
    PlayerProfile me() => c.view!.me!.profile;
    expect(find.text('ARMERIA'), findsOneWidget);
    expect(me().attributes[Attribute.fue], 16);

    // Comprar un arma ($300).
    await tapVisible(tester, find.byKey(const ValueKey('buy-espada_ignea')));
    expect(me().inventory, contains('espada_ignea'));
    expect(me().credits, 700);
    expect(find.text('TIENES'), findsWidgets);
    // Una que no alcanza: deshabilitada con el motivo.
    expect(_button(tester, 'buy-mandoble_eco').reason, 'Faltan \$700');
    expect(find.text('Faltan \$700'), findsOneWidget);

    // Consumible ($30).
    final pots = me().potions;
    await tapVisible(tester, find.byKey(const ValueKey('item-pot')));
    expect(me().potions, pots + 1);
    expect(me().credits, 670);

    // Equipar desde la herrería.
    await tapVisible(tester, find.byKey(const ValueKey('equip-espada_ignea')));
    expect(me().equipped, 'espada_ignea');

    // Mejorar Poder: round(300 × 0.22 × 1) = 66.
    await tapVisible(
        tester, find.byKey(const ValueKey('up-espada_ignea-pow')));
    expect(me().upgradesFor('espada_ignea').level(UpgradeStat.pow), 1);
    expect(me().credits, 604);
    expect(find.textContaining('Espada Ignea +1'), findsWidgets);

    // Fusión: la base por defecto es la que estaba equipada al abrir
    // (`fuseA` del prototipo); se elige la Ígnea, se sacrifica el hacha y
    // hereda su 1ª habilidad (Golpe Sísmico) por $200.
    await tapVisible(
        tester, find.byKey(const ValueKey('fuse-base-espada_ignea')));
    await tapVisible(tester, find.byKey(const ValueKey('fuse-sac-hacha_rompe')));
    expect(_button(tester, 'fuse').reason, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('fuse')));
    expect(me().fused['espada_ignea'], 'sismo');
    expect(me().inventory, isNot(contains('hacha_rompe')));
    expect(me().credits, 404);
    // Ya no hay nada para sacrificar.
    expect(find.text('(no hay armas disponibles)'), findsOneWidget);
    expect(_button(tester, 'fuse').reason, 'Elige un arma a sacrificar');
  });

  testWidgets('armería: consumibles al máximo y sin créditos', (tester) async {
    final c = await pumpPanel(tester,
        profile: progression.normalize(PlayerProfile(
            name: 'Bo',
            classId: 'maga',
            credits: 35,
            potions: 9,
            ethers: 0)),
        build: (v, c) => ArmoryPanel(view: v, controller: c));
    expect(_button(tester, 'item-pot').reason, 'Máximo 9');
    expect(_button(tester, 'item-eter').reason, 'Faltan \$5');
    // El motivo es solo informativo: tocar no hace nada.
    await tapVisible(tester, find.byKey(const ValueKey('item-pot')));
    expect(c.view!.me!.profile.potions, 9);
  });
}
