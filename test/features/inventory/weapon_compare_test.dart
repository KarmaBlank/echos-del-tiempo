import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/inventory/domain/weapon_compare.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/weapon_compare_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

/// Comparar armas en el inventario: docs/specs/panels.md § "Comparar
/// armas".

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

int _cell(PlayerProfile p, String token) =>
    InventoryRules.layout(p).cells.indexOf(token);

/// `ATQ 21 → 30 +9` como lo escribe la comparación (o `ATQ 21`).
String _statText(StatDelta s) => s.changed
    ? '${s.label} ${s.format(s.before)} → ${s.format(s.after)} ${s.diffText}'
    : '${s.label} ${s.format(s.before)}';

/// `ATQ 21 → 30 ▲9` del tooltip corto.
String _shortText(StatDelta s) => '${s.label} ${s.format(s.before)} → '
    '${s.format(s.after)} ${s.better ? '▲' : '▼'}${s.diffText.substring(1)}';

Future<TestGesture> _hover(WidgetTester tester, Finder f) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(f));
  await tester.pump();
  return mouse;
}

void main() {
  group('compareWeapons (motor)', () {
    test('equipada Común vs Épico: stats = previewEquip / derivedStats', () {
      final p = lootWarrior();
      final cmp = compareWeapons(progression, p, to: epicSword);
      final now = progression.derivedStats(p);
      final then = progression.previewEquip(p, 'e1');
      expect(cmp.from!.uid, 'espada_bronce');
      expect([for (final s in cmp.stats) s.label],
          ['ATQ', 'MAG', 'Crítico', 'VEL', 'Peso', 'Vida', 'Maná', 'DEF']);
      final byLabel = {for (final s in cmp.stats) s.label: s};
      expect(byLabel['ATQ']!.before, now.attack);
      expect(byLabel['ATQ']!.after, then.attack);
      expect(byLabel['MAG']!.after, then.magic);
      expect(byLabel['Crítico']!.after, then.critChance);
      expect(byLabel['VEL']!.after, then.speed);
      expect(byLabel['Vida']!.before, now.maxHp);
      expect(byLabel['Vida']!.after, then.maxHp);
      expect(byLabel['Maná']!.after, then.maxMp);
      expect(byLabel['DEF']!.after, then.defense);
      expect(byLabel['ATQ']!.better, isTrue, reason: 'Épico con Feroz');
      // Qué cambia.
      final items = progression.items;
      expect(cmp.modsGained,
          [for (final a in epicSword.affixes) items.affixText(a)]);
      expect(cmp.modsGained.first, contains('(T5)'));
      expect(cmp.modsLost, isEmpty);
      expect(cmp.passiveBefore, isNull);
      expect(cmp.passiveAfter, items.passiveText(epicSword));
      final bronze = p.itemByUid('espada_bronce')!;
      String name(String id) => progression.catalog.skills[id]!.name;
      expect(cmp.skillsGained, [
        for (final s in items.skillsOf(epicSword))
          if (!items.skillsOf(bronze).contains(s)) name(s),
      ]);
      expect(cmp.skillsLost, [
        for (final s in items.skillsOf(bronze))
          if (!items.skillsOf(epicSword).contains(s)) name(s),
      ]);
      expect(cmp.meetsRequirements, isTrue);
    });

    test('A vs B: mods ganados y perdidos con tier, ULT y requisitos', () {
      final p = lootWarrior();
      final cmp = compareWeapons(progression, p, from: epicSword, to: rareAxe);
      final pre = progression.previewEquip(p, 'e1');
      final post = progression.previewEquip(p, 'r1');
      expect(cmp.stats.first.before, pre.attack);
      expect(cmp.stats.first.after, post.attack);
      final items = progression.items;
      // Feroz 7 → Feroz 6: el mismo mod con otro valor se pierde y se gana.
      expect(cmp.modsGained, [
        items.affixText(rareAxe.affixes[0]),
        items.affixText(rareAxe.affixes[1]),
      ]);
      expect(cmp.modsLost,
          [for (final a in epicSword.affixes) items.affixText(a)]);
      expect(cmp.passiveAfter, isNull);
      expect(cmp.passiveBefore, isNotNull);
      final ult = progression.catalog.ultimates;
      expect(cmp.ultBefore,
          ult[progression.catalog.weapons['espada_ignea']!.type]?.name);
      expect(cmp.ultAfter,
          ult[progression.catalog.weapons['hacha_rompe']!.type]?.name);
      // El báculo pide ESP 14.
      expect(compareWeapons(progression, p, to: commonStaff).meetsRequirements,
          isFalse);
    });
  });

  testWidgets('mouse sobre un arma: ficha + EQUIPADA + Si la equipas',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    final p = c.view!.me!.profile;
    final mouse = await _hover(
        tester, find.byKey(ValueKey('inv-cell-${_cell(p, 'e1')}')));
    final tip = find.byKey(const ValueKey('inv-cmp-tip'));
    expect(tip, findsOneWidget);
    final text = plain(tester, 'inv-cmp-tip');
    expect(text, contains('Filo del Alba'));
    // v0.9.13: una columna; la equipada aparece con Shift.
    expect(find.byKey(const ValueKey('inv-cmp-tip-equipped')), findsNothing);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(plain(tester, 'inv-cmp-tip-equipped'), contains('EQUIPADA'));
    expect(plain(tester, 'inv-cmp-tip-equipped'), contains('Espada de Bronce'));
    var delta = plain(tester, 'inv-cmp-tip-delta');
    expect(delta, contains('Si la equipas:'));
    final cmp = compareWeapons(progression, p, to: epicSword);
    // Corto (v0.9.11): solo las stats que cambian, `ATQ 21 → 30 ▲9`.
    for (final s in cmp.stats) {
      if (s.changed) {
        expect(delta, contains(_shortText(s)));
      } else {
        expect(find.byKey(ValueKey('cmp-stat-${s.label}')), findsNothing);
      }
    }
    // Sin turno, habilidades, mods ni pasiva fuera de `▸ Cambios`.
    for (final t in [
      'Tu turno llega',
      '+ Mod:',
      '- Mod:',
      'Habilidad:',
      'Pasiva:',
      'ULT:',
      'Requiere'
    ]) {
      expect(delta, isNot(contains(t)), reason: t);
    }
    // A lo sumo 10 líneas visibles.
    final lineH =
        RetroHoverCard.textStyle.fontSize! * RetroHoverCard.textStyle.height!;
    expect(
        tester.getSize(find.byKey(const ValueKey('inv-cmp-tip-delta'))).height,
        lessThanOrEqualTo(lineH * 10 + 1));
    expect(plain(tester, 'inv-cmp-tip'), isNot(contains('Tu turno llega')));
    await tester.tap(find.byKey(ValueKey('inv-cell-${_cell(p, 'e1')}')),
        kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(RetroHoverCard.pinned, isTrue);
    await tester.tap(find.byKey(const ValueKey('tip-fold-Cambios')));
    await tester.pump();
    delta = plain(tester, 'inv-cmp-tip-delta');
    expect(delta, contains('+ Mod:'));
    expect(delta, contains(cmp.modsGained.first));
    expect(delta, contains('+ Pasiva:'));
    // La caja queda dentro de la pantalla.
    final r = tester.getRect(tip);
    expect(r.left, greaterThanOrEqualTo(0));
    expect(r.right, lessThanOrEqualTo(1280));
    expect(r.bottom, lessThanOrEqualTo(720));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    // Sobre la equipada: la ficha simple.
    await mouse
        .moveTo(tester.getCenter(find.byKey(const ValueKey('inv-equipped'))));
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-cmp-tip')), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('COMPARAR A vs B: vista, números del motor, equipar y vender',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    await _tap(tester, 'inv-cell-${_cell(me(), 'r1')}');
    await _tap(tester, 'inv-compare');
    expect(plain(tester, 'inv-compare-pick'),
        contains('Elige el arma B para comparar con Eco Voraz'));
    // Una pila no sirve como B.
    await _tap(tester, 'inv-stack-mat:esquirla');
    expect(find.byKey(const ValueKey('cmp-view')), findsNothing);
    await _tap(tester, 'inv-cell-${_cell(me(), 'e1')}');
    expect(find.byKey(const ValueKey('cmp-view')), findsOneWidget);
    expect(plain(tester, 'cmp-card-a'), contains('Eco Voraz'));
    expect(plain(tester, 'cmp-card-b'), contains('Filo del Alba'));
    final cmp = compareWeapons(progression, me(), from: rareAxe, to: epicSword);
    final delta = plain(tester, 'cmp-delta');
    for (final s in cmp.stats) {
      expect(delta, contains(_statText(s)));
    }
    expect(delta, contains('+ Pasiva:'));
    expect(delta, contains('- Mod:'));

    // INTERCAMBIAR.
    await _tap(tester, 'cmp-swap');
    expect(plain(tester, 'cmp-card-a'), contains('Filo del Alba'));
    await _tap(tester, 'cmp-swap');

    // EQUIPAR B.
    await _tap(tester, 'cmp-equip-b');
    expect(me().equippedUid, 'e1');
    expect(plain(tester, 'cmp-card-b'), contains('EQUIPADA'));
    expect(find.byKey(const ValueKey('cmp-equip-b')), findsNothing);
    expect(button(tester, 'cmp-sell-b').reason, isNotNull,
        reason: 'la equipada no se vende');

    // VENDER A: pide confirmación; al venderla la vista se cierra.
    await _tap(tester, 'cmp-sell-a');
    expect(plain(tester, 'cmp-craft-question'), contains('¿Vender A'));
    await _tap(tester, 'cmp-craft-cancel');
    expect(me().itemByUid('r1'), isNotNull);
    await _tap(tester, 'cmp-sell-a');
    await _tap(tester, 'cmp-craft-confirm');
    await tester.pump();
    expect(me().itemByUid('r1'), isNull);
    expect(find.byKey(const ValueKey('cmp-view')), findsNothing);
    expect(find.byKey(const ValueKey('inv-summary')), findsOneWidget);
  });

  testWidgets('Esc: cancela "elige B" y cierra la vista sin cerrar el panel',
      (tester) async {
    final c = await _inventory(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    await _tap(tester, 'inv-cell-${_cell(me(), 'm1')}');
    await _tap(tester, 'inv-compare');
    expect(find.byKey(const ValueKey('inv-compare-pick')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('inv-compare-pick')), findsNothing);
    expect(find.byKey(const ValueKey('inv-summary')), findsOneWidget);

    await _tap(tester, 'inv-compare');
    await _tap(tester, 'inv-equipped');
    expect(find.byKey(const ValueKey('cmp-view')), findsOneWidget);
    expect(plain(tester, 'cmp-card-b'), contains('Espada de Bronce'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const ValueKey('cmp-view')), findsNothing);
    expect(find.byKey(const ValueKey('inv-summary')), findsOneWidget);
    expect(find.byType(CharacterPanel), findsOneWidget);

    // CERRAR también vuelve.
    await _tap(tester, 'inv-compare');
    await _tap(tester, 'inv-cell-${_cell(me(), 'e1')}');
    await _tap(tester, 'cmp-close');
    expect(find.byKey(const ValueKey('cmp-view')), findsNothing);
  });

  testWidgets('compañero: A de su inventario (solo lectura) vs la tuya',
      (tester) async {
    final mate = newProfile('Beto', 'maga');
    final c = await _inventory(tester, lootWarrior(),
        view: (v, c) => SessionView(
              session: c.engine.addPlayer(v.session, 'p9', mate)!.state,
              localId: v.localId,
              map: v.map,
            ));
    await _tap(tester, 'inv-owner-p9');
    // Su equipada: comparada con la tuya al pasar el mouse.
    final mouse =
        await _hover(tester, find.byKey(const ValueKey('inv-equipped')));
    expect(plain(tester, 'inv-cmp-tip'), contains('de Beto'));
    await mouse.removePointer();
    // Caja fijable (v0.9.7): espera un toque por si el mouse va a ella.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('inv-cmp-tip')), findsNothing);
    await _tap(tester, 'inv-equipped');
    await _tap(tester, 'inv-compare');
    await _tap(tester, 'inv-owner-${c.view!.localId}');
    final p = c.view!.me!.profile;
    await _tap(tester, 'inv-cell-${_cell(p, 'e1')}');
    expect(find.byKey(const ValueKey('cmp-view')), findsOneWidget);
    expect(plain(tester, 'cmp-card-a'), contains('de Beto'));
    expect(plain(tester, 'cmp-card-a'), contains('Solo lectura'));
    expect(find.byKey(const ValueKey('cmp-equip-a')), findsNothing);
    expect(find.byKey(const ValueKey('cmp-equip-b')), findsOneWidget);
  });

  group('tooltip corto (v0.9.11)', () {
    for (final (size, text) in const [
      (Size(1280, 720), TextSize.normal),
      (Size(1920, 1080), TextSize.normal),
      (Size(1280, 720), TextSize.enormous),
      (Size(1920, 1080), TextSize.enormous),
    ]) {
      testWidgets(
          'ancho máximo en ${size.width.toInt()}×${size.height.toInt()} '
          '${text.name}', (tester) async {
        final c = await pumpPanel(tester,
            profile: lootWarrior(),
            textSize: text,
            build: (v, c) => CharacterPanel(
                view: v, controller: c, initialTab: CharacterTab.inventory));
        tester.view.physicalSize = size * tester.view.devicePixelRatio;
        await tester.pumpAndSettle();
        final p = c.view!.me!.profile;
        final cell = find.byKey(ValueKey('inv-cell-${_cell(p, 'e1')}'));
        await tester.ensureVisible(cell);
        await tester.pump();
        final mouse = await _hover(tester, cell);
        final tip = tester.getRect(find.byKey(const ValueKey('inv-cmp-tip')));
        expect(tip.width,
            lessThanOrEqualTo(size.width * HoverCompareCard.maxScreenShare),
            reason: '$tip');
        // Cada columna: ~40 letras escaladas por el texto.
        // En pantallas anchas, menos de la mitad del ancho.
        if (size.width >= 1920 && text == TextSize.normal) {
          expect(tip.width, lessThan(size.width / 2));
        }
        expect(
            (Offset.zero & size).inflate(1).contains(tip.bottomRight), isTrue);
        expect(tester.takeException(), isNull);
        await mouse.removePointer();
        await tester.pump(const Duration(milliseconds: 300));
      });
    }

    testWidgets('Esc y clic fuera lo cierran (también fijado)', (tester) async {
      final c = await _inventory(tester, lootWarrior());
      final p = c.view!.me!.profile;
      final cell = find.byKey(ValueKey('inv-cell-${_cell(p, 'e1')}'));
      final tip = find.byKey(const ValueKey('inv-cmp-tip'));
      // Esc.
      var mouse = await _hover(tester, cell);
      expect(tip, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(tip, findsNothing);
      expect(find.byType(CharacterPanel), findsOneWidget,
          reason: 'el primer Esc es del tooltip');
      await mouse.removePointer();
      // Fijado (mouse encima de la caja) y clic fuera.
      mouse = await _hover(tester, cell);
      await mouse.moveTo(tester.getCenter(tip));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tip, findsOneWidget, reason: 'fijado');
      final out = await tester.createGesture(kind: PointerDeviceKind.touch);
      await out.down(const Offset(4, 710));
      await out.up();
      await tester.pump();
      expect(tip, findsNothing);
      expect(RetroHoverCard.anyShowing, isFalse);
      await mouse.removePointer();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
