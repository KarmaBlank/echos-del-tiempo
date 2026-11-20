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
import '../../app/square_ui_audit.dart';

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
    // Regla pixel: ninguna pestaña de PERSONAJE tiene redondeos.
    for (var i = 0; i < CharacterTab.values.length; i++) {
      await tester.tap(find.byKey(ValueKey('tab-$i')));
      await tester.pumpAndSettle();
      expect(roundedUi(tester), isEmpty, reason: 'pestaña $i');
    }
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await tester.pumpAndSettle();
    final before = progression.derivedStats(start);
    // DsStatLine sin cambio: solo `HP 100` (design_system.md § 6).
    DsStatLine line(String k) =>
        tester.widget<DsStatLine>(find.byKey(ValueKey(k)));
    expect(line('stat-HP').from, before.maxHp);
    expect(line('stat-HP').to, before.maxHp);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('stat-HP')),
            matching: find.text('▲')),
        findsNothing);
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
    // `HP 100 → 120 ▲20`: el después en principal, flecha y diferencia.
    expect(line('stat-HP').to, preview.maxHp);
    expect(line('stat-ATQ').from, before.attack);
    expect(line('stat-ATQ').to, preview.attack);
    for (final k in ['stat-HP', 'stat-ATQ']) {
      expect(
          find.descendant(
              of: find.byKey(ValueKey(k)), matching: find.text('▲')),
          findsOneWidget,
          reason: k);
    }
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('stat-HP')),
            matching: find.text('${preview.maxHp - before.maxHp}')),
        findsOneWidget);
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
    expect(line('stat-HP').from, c.view!.me!.maxHp);
    expect(line('stat-HP').to, c.view!.me!.maxHp);

    // Reiniciar puntos (en el lobby).
    await tapVisible(tester, find.byKey(const ValueKey('respec')));
    expect(c.view!.me!.profile.points, 2);
  });

  testWidgets(
      'personaje: "−" quita lo pendiente; sin pendiente se ve apagado y '
      'explica REINICIAR PUNTOS', (tester) async {
    final start = progression.normalize(
        PlayerProfile(name: 'Ana', classId: 'guerrero', level: 3));
    final c = await pumpPanel(tester,
        profile: start,
        build: (v, c) => CharacterPanel(view: v, controller: c));
    DsButton dec() =>
        tester.widget<DsButton>(find.byKey(const ValueKey('dec-fue')));
    Color? decColor() => tester
        .widget<Text>(find.descendant(
            of: find.byKey(const ValueKey('dec-fue')),
            matching: find.text('-')))
        .style
        ?.color;
    // Sin pendiente: apagado (color desactivado) y dice cómo reasignar.
    expect(dec().onPressed, isNull);
    expect(decColor(), DsColors.textDisabled);
    expect(dec().tooltip, contains('REINICIAR PUNTOS'));

    await tapVisible(tester, find.byKey(const ValueKey('inc-fue')));
    await tapVisible(tester, find.byKey(const ValueKey('inc-fue')));
    expect(find.textContaining('Puntos: 0'), findsOneWidget);
    expect(dec().onPressed, isNotNull);
    expect(decColor(), DsColors.textPrimary);
    await tapVisible(tester, find.byKey(const ValueKey('dec-fue')));
    expect(find.textContaining('Puntos: 1'), findsOneWidget);
    expect(_plain(tester, 'pending-points'), 'Pendiente: +3 FUE');
    await tapVisible(tester, find.byKey(const ValueKey('dec-fue')));
    expect(find.textContaining('Puntos: 2'), findsOneWidget);
    // No baja de 0 pendiente: vuelve a apagarse.
    expect(dec().onPressed, isNull);
    expect(c.view!.me!.profile.attributes[Attribute.fue],
        start.attributes[Attribute.fue]);

    // El host no acepta repartos negativos (no baja del base).
    final p = c.view!.me!.profile;
    expect(progression.allocate(p, {Attribute.fue: -1}), isNull);
    expect(progression.allocate(p, {Attribute.fue: -1, Attribute.vit: 1})
        ?.attributes[Attribute.fue], p.attributes[Attribute.fue]);
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
