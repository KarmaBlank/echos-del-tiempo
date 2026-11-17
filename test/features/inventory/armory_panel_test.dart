import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// Guerrero Lv5 con FUE 16 / DES 10 (cumple Espada Ígnea), $1000 y el
/// Hacha Rompeturnos para sacrificar.
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
        Attribute.fue: 16,
        Attribute.des: 10,
      }),
      points: 4,
      inventory: const ['espada_bronce', 'hacha_rompe'],
      equipped: 'espada_bronce',
    ));

PanelButton _button(WidgetTester tester, String key) =>
    tester.widget<PanelButton>(find.byKey(ValueKey(key)));

/// Texto plano de los `Text` / `ProtoText` debajo de [key].
String _plain(WidgetTester tester, String key) => tester
    .widgetList<Text>(find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(Text)))
    .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
    .join(' ');

Future<void> _tab(WidgetTester tester, ArmoryTab t) =>
    tapVisible(tester, find.byKey(ValueKey('tab-${t.index}')));

void main() {
  testWidgets('armería: comprar, equipar, mejorar y fusionar', (tester) async {
    final c = await pumpPanel(tester,
        profile: richWarrior(),
        build: (v, c) => ArmoryPanel(view: v, controller: c));
    PlayerProfile me() => c.view!.me!.profile;
    expect(find.text('ARMERIA'), findsOneWidget);
    // La pestaña explica qué hace.
    expect(find.textContaining('Puedes comprarlas sin cumplir'), findsOneWidget);

    // COMPRAR: elegir en la lista y comprar desde el detalle ($300).
    await tapVisible(tester, find.byKey(const ValueKey('shop-row-espada_ignea')));
    expect(find.textContaining('Si la equipas'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('buy-espada_ignea')));
    expect(me().inventory, contains('espada_ignea'));
    expect(me().credits, 700);
    expect(find.text('TIENES'), findsWidgets);
    // Una que no alcanza: deshabilitada con el motivo y el costo.
    await tapVisible(tester, find.byKey(const ValueKey('shop-row-mandoble_eco')));
    expect(_button(tester, 'buy-mandoble_eco').reason, 'Faltan \$700');
    expect(find.text('Faltan \$700'), findsOneWidget);

    // CONSUMIBLES ($30).
    await _tab(tester, ArmoryTab.items);
    final pots = me().potions;
    await tapVisible(tester, find.byKey(const ValueKey('item-pot')));
    expect(me().potions, pots + 1);
    expect(me().credits, 670);

    // FORJA: equipar y mejorar Poder: round(300 × 0.22 × 1) = 66.
    await _tab(tester, ArmoryTab.forge);
    await tapVisible(tester, find.byKey(const ValueKey('forge-row-espada_ignea')));
    await tapVisible(tester, find.byKey(const ValueKey('equip-espada_ignea')));
    expect(me().equipped, 'espada_ignea');
    await tapVisible(
        tester, find.byKey(const ValueKey('up-espada_ignea-pow')));
    expect(me().upgradesFor('espada_ignea').level(UpgradeStat.pow), 1);
    expect(me().credits, 604);
    expect(find.textContaining('Espada Ignea +1'), findsWidgets);

    // FUSIÓN: base Ígnea, se sacrifica el hacha y hereda su 1ª habilidad
    // (Golpe Sísmico) por $200.
    await _tab(tester, ArmoryTab.fuse);
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

  testWidgets('fusión: la vista previa muestra habilidades, costo y pérdida',
      (tester) async {
    // La base ya tenía una fusión: la nueva la reemplaza.
    final start = richWarrior(credits: 150).copyWith(
      fused: const {'espada_bronce': 'tajoT'},
      upgrades: const {'hacha_rompe': WeaponUpgradeLevels(pow: 2)},
    );
    await pumpPanel(tester,
        profile: start,
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.fuse));
    final cat = progression.catalog;
    final base = cat.weapons['espada_bronce']!;
    final sismo = cat.skills['sismo']!.name;

    final skills = _plain(tester, 'fuse-result-skills');
    for (final id in base.skillIds) {
      expect(skills, contains(protoPlain(cat.skills[id]!.name)));
    }
    expect(skills, contains('${protoPlain(sismo)} (nueva)'));
    final old = cat.skills[start.fused['espada_bronce']];
    expect(old, isNotNull);
    {
      expect(_plain(tester, 'fuse-replaces'), contains(protoPlain(old!.name)));
    }
    // Lo que se pierde: el hacha y sus mejoras.
    final lost = _plain(tester, 'fuse-lost');
    expect(lost, contains('Hacha'));
    expect(lost, contains('Poder +2'));
    // Costo y motivo: no alcanza ($150 de $200).
    expect(find.textContaining('Costo \$${ProgressionRules.fuseCost}'),
        findsOneWidget);
    expect(_button(tester, 'fuse').reason, 'Faltan \$50');
  });

  testWidgets('forja: cada estadística muestra antes → después', (tester) async {
    final start = richWarrior();
    await pumpPanel(tester,
        profile: start,
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.forge));
    // Arma equipada elegida por defecto: Poder 0 → +12% y ATQ sube.
    final before = progression.derivedStats(start);
    final up = progression.stats.calculate(progression
        .buildOf(start.copyWith(upgrades: {
      'espada_bronce': const WeaponUpgradeLevels(pow: 1),
    })));
    expect(up.attack, greaterThan(before.attack));
    final pow = _plain(tester, 'forge-stat-pow');
    expect(pow, contains('Bono +0% → +12%'));
    expect(pow, contains('ATQ ${before.attack} → ${up.attack}'));
    expect(pow, contains('0/${ProgressionRules.upgradeMax}'));
    expect(_plain(tester, 'forge-stat-crit'), contains('CRIT'));
    expect(_plain(tester, 'forge-stat-spd'), contains('VEL'));
    expect(_button(tester, 'up-espada_bronce-pow').label,
        '+1 \$${progression.upgradeCost('espada_bronce', 0)}');
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
    expect(_button(tester, 'item-pot').reason, 'Máximo 9');
    expect(_button(tester, 'item-eter').reason, 'Faltan \$5');
    // El motivo se ve escrito, sin pasar el mouse.
    expect(find.text('Máximo 9'), findsOneWidget);
    // El motivo es solo informativo: tocar no hace nada.
    await tapVisible(tester, find.byKey(const ValueKey('item-pot')));
    expect(c.view!.me!.profile.potions, 9);
  });
}
