import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/inventory_action_menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

String _plain(WidgetTester tester, String key) => tester
    .widget<Text>(find.descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(Text)))
    .textSpan!
    .toPlainText();

void main() {
  testWidgets('personaje: el reparto muestra antes > después y se confirma',
      (tester) async {
    final start = progression.normalize(PlayerProfile(
        name: 'Ana', classId: 'guerrero', level: 3)); // 2 pts (+3 cada uno)
    final c = await pumpPanel(tester,
        profile: start,
        build: (v, c) => CharacterPanel(view: v, controller: c));
    final before = progression.derivedStats(start);
    expect(_plain(tester, 'stat-HP'), 'HP ${before.maxHp}');
    expect(find.textContaining('Puntos: 2'), findsOneWidget);
    // Sin reparto, confirmar está deshabilitado y dice por qué (en la
    // barra de ATRIBUTOS, al lado del botón principal).
    final confirm =
        tester.widget<DsButton>(find.byKey(const ValueKey('confirm-points')));
    expect(confirm.onPressed, isNull);
    expect(confirm.kind, DsButtonKind.primary);
    expect(confirm.tooltip, 'Reparte algún punto');
    expect(find.text('Reparte algún punto'), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('inc-vit')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-fue')));
    final preview = progression
        .previewAllocation(start, {Attribute.vit: 1, Attribute.fue: 1});
    expect(preview.maxHp, greaterThan(before.maxHp));
    expect(
        _plain(tester, 'stat-HP'), 'HP ${before.maxHp} → ${preview.maxHp} ▲');
    expect(_plain(tester, 'stat-ATQ'),
        'ATQ ${before.attack} → ${preview.attack} ▲');
    expect(find.textContaining('Puntos: 0'), findsOneWidget);
    expect(_plain(tester, 'pending-points'), 'Pendiente: +3 VIT +3 FUE');
    // Nada cambió todavía en el host.
    expect(c.view!.me!.profile.points, 2);

    await tapVisible(tester, find.byKey(const ValueKey('dec-fue')));
    await tapVisible(tester, find.byKey(const ValueKey('confirm-points')));
    final p = c.view!.me!.profile;
    expect(p.attributes[Attribute.vit], start.attributes[Attribute.vit] + 3);
    expect(p.attributes[Attribute.fue], start.attributes[Attribute.fue]);
    expect(p.points, 1);
    expect(c.view!.me!.maxHp,
        progression.previewAllocation(start, {Attribute.vit: 1}).maxHp);
    expect(_plain(tester, 'stat-HP'), 'HP ${c.view!.me!.maxHp}');

    // Reiniciar puntos (en el lobby).
    await tapVisible(tester, find.byKey(const ValueKey('respec')));
    expect(c.view!.me!.profile.points, 2);
  });

  testWidgets('personaje: cambio de clase en el lobby y equipar en Inventario',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: progression.normalize(PlayerProfile(
            name: 'Ana',
            classId: 'guerrero',
            level: 3,
            inventory: const ['espada_bronce', 'espada_ignea'])),
        build: (v, c) => CharacterPanel(view: v, controller: c));
    // Pestaña INVENTARIO con la Ígnea elegida en la grilla.
    Future<void> armas() async {
      await tapVisible(tester, find.byKey(const ValueKey('tab-1')));
      final cell = InventoryRules.layout(c.view!.me!.profile)
          .cells
          .indexOf('espada_ignea');
      await tapVisible(tester, find.byKey(ValueKey('inv-cell-$cell')));
    }

    // Armas: la Ígnea pide FUE 14 / DES 8; Lv3 tiene FUE 12, DES 6.
    await armas();
    expect(find.textContaining('EQUIPADA'), findsWidgets);
    // Sin panel derecho (v0.9.10); las acciones, en el menú.
    expect(find.byKey(const ValueKey('inv-stats')), findsNothing);
    await openInventoryActions(tester);
    expect(
        tester
            .widget<InventoryActionRow>(find.byKey(const ValueKey('inv-equip')))
            .entry
            .reason,
        'No podés equiparla. Requisitos: FUE 14 DES 8');

    // Con el reparto pendiente cumpliría: "Confirma puntos".
    await tapVisible(tester, find.byKey(const ValueKey('tab-0')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-fue')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-des')));
    await armas();
    await openInventoryActions(tester);
    expect(
        tester
            .widget<InventoryActionRow>(find.byKey(const ValueKey('inv-equip')))
            .entry
            .reason,
        'Confirma puntos');
    await tapVisible(tester, find.byKey(const ValueKey('tab-0')));
    await tapVisible(tester, find.byKey(const ValueKey('confirm-points')));
    await armas();
    await tapVisible(tester, find.byKey(const ValueKey('inv-equip')));
    expect(c.view!.me!.profile.equipped, 'espada_ignea');

    // Cambio de clase (solo lobby).
    await tapVisible(tester, find.byKey(const ValueKey('tab-0')));
    await tapVisible(tester, find.byKey(const ValueKey('class-maga')));
    expect(c.view!.me!.profile.classId, 'maga');
    expect(c.view!.me!.profile.equipped, 'baculo_aprendiz');
  });

  testWidgets('personaje: tope blando en el botón, el valor y el tooltip',
      (tester) async {
    var p = progression
        .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 20));
    p = progression.allocate(p, {Attribute.vit: 17})!; // VIT 10 + 51 = 61
    await pumpPanel(tester,
        profile: p, build: (v, c) => CharacterPanel(view: v, controller: c));
    expect(p.attributes[Attribute.vit], 61);
    // v0.10.1: la fila es una línea, sin "tope N" ni la descripción.
    expect(find.textContaining('tope 60'), findsNothing);
    expect(find.textContaining('tope 40'), findsNothing);
    expect(find.text('+3 VIT → +1.5'), findsOneWidget);
    expect(find.text('+3 FUE'), findsOneWidget);
    final row = find.byKey(const ValueKey('attr-row-vit'));
    final line = tester.getSize(find.byKey(const ValueKey('inc-vit'))).height;
    // Una línea: el alto del botón más padding, borde y margen.
    expect(tester.getSize(row).height, lessThan(line * 1.5 + 16));
    // Pasado el tope, el valor en naranja.
    expect(
        tester
            .widget<ProtoText>(find.byKey(const ValueKey('attr-value-vit')))
            .markup,
        contains(protoColor(ProtoColors.orange, '61')));
    // El tooltip: qué da, el tope y que pasado el tope rinde ½.
    final tip = tester.widget<RetroTooltip>(
        find.ancestor(of: row, matching: find.byType(RetroTooltip)).first);
    expect(tip.message, contains('Tope 60: pasado el tope rinde ½'));
    expect(tip.message, contains('+3 Vitalidad'));
  });
}
