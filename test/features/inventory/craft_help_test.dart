import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/app/widgets/action_card.dart';
import 'package:echos_del_tiempo/app/widgets/cost_chip.dart';
import 'package:echos_del_tiempo/features/inventory/domain/craft_help.dart';
import 'package:echos_del_tiempo/features/inventory/domain/shop_guards.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/craft_bench.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

// Tooltips de la mesa de fusión (panels.md § "FUSIÓN (v0.8.3: tooltips)"):
// cada acción explica qué hace, qué cambia, qué cuesta, qué se pierde,
// por qué está bloqueada y un ejemplo; también secciones, migas,
// materiales y las elecciones del paso 3.

const _labels = [
  CraftOpHelp.whatLabel,
  CraftOpHelp.changeLabel,
  CraftOpHelp.costLabel,
  CraftOpHelp.loseLabel,
  CraftOpHelp.exampleLabel,
];

Future<void> _tap(WidgetTester tester, String key) =>
    tapVisible(tester, find.byKey(ValueKey(key)));

Future<void> _toOps(WidgetTester tester, String uid) async {
  await pumpPanel(tester,
      profile: lootWarrior(),
      build: (v, c) =>
          ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.fuse));
  await _tap(tester, 'bench-weapon-$uid');
  await _tap(tester, 'bench-next');
}

/// Un solo mouse por prueba: cada [_hover] lo mueve al centro de [f]
/// (o a [at] dentro de él).
TestGesture? _mouse;

Future<void> _hover(WidgetTester tester, Finder f, {Offset? at}) async {
  await tester.ensureVisible(f);
  await tester.pump();
  var g = _mouse;
  if (g == null) {
    g = _mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() async {
      await _mouse?.removePointer();
      _mouse = null;
    });
  }
  // Afuera primero, para que el tooltip anterior se cierre.
  await g.moveTo(const Offset(1, 1));
  await tester.pump();
  await g.moveTo(at == null ? tester.getCenter(f) : tester.getTopLeft(f) + at);
  await tester.pump();
}

/// Markup del tooltip abierto de la acción [op].
String _tip(WidgetTester tester, CraftOp op) => tester
    .widget<RetroTipText>(find.byKey(ValueKey('bench-op-tip-${op.name}')))
    .markup;

/// Markup de todos los `RetroTipText` abiertos.
String _open(WidgetTester tester) => tester
    .widgetList<RetroTipText>(find.byType(RetroTipText))
    .map((t) => t.markup)
    .join('\n');

void main() {
  final help = CraftHelp(progression.crafting);

  test('cada acción de la mesa tiene las partes con los números del arma',
      () {
    final p = lootWarrior();
    final axe = p.itemByUid('r1')!;
    for (final op in CraftOpText.bench) {
      final h = help.op(p, axe, op);
      for (final s in [h.what, h.change, h.cost, h.lose, h.example]) {
        expect(s, isNotEmpty, reason: '${op.name}: falta una parte');
      }
      final m = h.markup(op.title);
      for (final l in _labels) {
        expect(m, contains(l), reason: '${op.name} sin "$l"');
      }
      expect(m, isNot(contains(CraftOpHelp.blockedLabel)));
    }
    // Números del arma (Raro, 2 mods de 4) y de las reglas.
    expect(help.op(p, axe, CraftOp.addAffix).change, 'Mods 2/4 → 3/4.');
    expect(help.op(p, axe, CraftOp.removeAffix).change, 'Mods 2/4 → 1/4.');
    final up = help.op(p, axe, CraftOp.upgradeRarity);
    expect(up.change, contains('Raro → Épico'));
    expect(up.change, contains('4 → 6 (+2)'));
    expect(up.change, contains('pasiva'));
    final (prismas, credits) = CraftRules.upgradeRarityCost(Rarity.raro)!;
    expect(up.cost, contains('₵$credits (tienes ₵5000)'));
    expect(up.cost, contains('$prismas Prisma Roto (tienes 0)'));
    expect(help.op(p, axe, CraftOp.reroll).cost,
        contains('₵${CraftRules.rerollCost(Rarity.raro)}'));
    expect(help.op(p, axe, CraftOp.reroll).cost,
        contains('1 Esquirla del Eco (tienes 2)'));
    expect(help.op(p, axe, CraftOp.transferAffix).lose,
        contains('se destruye'));
    expect(help.op(p, axe, CraftOp.reforge).cost,
        contains('₵${CraftRules.reforgeCost(axe)!.$1}'));
    // Bloqueada: el motivo completo y una pista.
    final b = help.op(p, axe, CraftOp.upgradeRarity, blocked: 'Falta Prisma Roto');
    expect(b.markup('x'), contains('Bloqueada:</span> Falta Prisma Roto'));
    expect(b.markup('x'), contains('contador de materiales'));
  });

  test('materiales: para qué, dónde y cuántos tienes', () {
    final p = lootWarrior();
    for (final m in [
      CraftMaterial.esquirla,
      CraftMaterial.cristal,
      CraftMaterial.prisma,
      CraftMaterial.ancla,
      CraftMaterial.esencia,
    ]) {
      final t = help.material(m, p);
      expect(t, contains('Para qué:'));
      expect(t, contains('Dónde:'));
      expect(t, contains('Tienes:</span> ${p.material(m)}'));
    }
    expect(help.material(CraftMaterial.esquirla, p), contains('8%'));
    expect(help.material(CraftMaterial.prisma, p), contains('Legendario 1'));
    expect(help.material(CraftMaterial.ancla, p), contains('Ecos'));
    expect(help.material(CraftMaterial.esencia, p),
        contains('Jefes del Abismo'));
  });

  testWidgets('paso 2: cada tarjeta muestra su tooltip con el mouse y el '
      'motivo es el del guard', (tester) async {
    await _toOps(tester, 'r1');
    final guards = ShopGuards(progression, SessionMode.lobby);
    for (final op in CraftOpText.bench) {
      await _hover(tester, find.byKey(ValueKey('bench-op-${op.name}')));
      final m = _tip(tester, op);
      expect(m, contains(op.title));
      for (final l in _labels) {
        expect(m, contains(l), reason: '${op.name} sin "$l"');
      }
      final card =
          tester.widget<ActionCard>(find.byKey(ValueKey('bench-op-${op.name}')));
      if (card.disabled) {
        final chip = tester.widget<CostChip>(find.descendant(
            of: find.byKey(ValueKey('bench-op-why-${op.name}')),
            matching: find.byType(CostChip)));
        expect(m, contains('Bloqueada:</span> ${chip.reason}'));
      } else {
        expect(m, isNot(contains('Bloqueada:')));
      }
    }
    // Sin Prismas: el motivo del guard, entero.
    final why = guards.craft(
        lootWarrior(), const CraftAction(CraftOp.upgradeRarity, 'r1'));
    expect(why, 'Falta Prisma Roto');
    await _hover(tester, find.byKey(const ValueKey('bench-op-upgradeRarity')));
    expect(_tip(tester, CraftOp.upgradeRarity),
        contains('Bloqueada:</span> $why'));
  });

  testWidgets('paso 2: el foco de teclado también abre el tooltip',
      (tester) async {
    await _toOps(tester, 'r1');
    // Foco llegado por teclado (v0.19.1: con el mouse no abre el tip).
    RetroHoverCard.keyboardNav = true;
    addTearDown(() => RetroHoverCard.keyboardNav = false);
    expect(find.byKey(const ValueKey('bench-op-tip-addAffix')), findsNothing);
    final inner = find.descendant(
        of: find.byKey(const ValueKey('bench-op-addAffix')),
        matching: find.byType(GestureDetector));
    Focus.of(tester.element(inner.first)).requestFocus();
    await tester.pump();
    expect(_tip(tester, CraftOp.addAffix), contains('Mods 2/4 → 3/4'));
  });

  testWidgets('secciones, migas y materiales con tooltip', (tester) async {
    await _toOps(tester, 'r1');
    await _hover(tester, find.byKey(const ValueKey('bench-group-improve')),
        at: const Offset(40, 10));
    expect(_open(tester), contains(CraftHelp.groups['improve']!));
    await _hover(tester, find.byKey(const ValueKey('bench-crumb-2')));
    expect(_open(tester), contains(CraftHelp.steps[2]));
    await _hover(tester, find.byKey(const ValueKey('craft-mat-prisma')));
    expect(_open(tester), contains('Subir rareza'));
    expect(plain(tester, 'craft-materials'), contains('Esquirla x2'));
  });

  testWidgets('paso 3: el arma de origen dice qué se destruye', (tester) async {
    await _toOps(tester, 'r1');
    await _tap(tester, 'bench-op-transferAffix');
    await _hover(tester, find.byKey(const ValueKey('craft-source-m1')));
    final m = _open(tester);
    expect(m, contains('Te llevas:'));
    expect(m, contains('Se destruye'));
    expect(m, contains('Mods 2/2'));
  });

  test('reemplazar habilidad: base no, trasladada sí', () {
    expect(CraftHelp.replaceLine(replaceable: false, chosen: false),
        contains('no se reemplaza'));
    expect(CraftHelp.replaceLine(replaceable: true, chosen: true),
        contains('Se reemplaza'));
    expect(CraftHelp.replaceLine(replaceable: true, chosen: false),
        contains('Trasladada'));
  });
}
