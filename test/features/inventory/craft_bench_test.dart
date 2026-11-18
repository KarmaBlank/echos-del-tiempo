import 'package:echos_del_tiempo/app/widgets/action_card.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

// Mesa de fusión en 3 pasos (panels.md § "FUSIÓN"): 1 ARMA → 2 ACCIÓN →
// 3 CONFIRMAR.

Future<SessionController> _bench(WidgetTester tester, PlayerProfile p) =>
    pumpPanel(tester,
        profile: p,
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.fuse));

Future<void> _tap(WidgetTester tester, String key) =>
    tapVisible(tester, find.byKey(ValueKey(key)));

/// Paso 1 → [uid]; paso 2 → [op] (queda en el paso 3).
Future<void> _choose(WidgetTester tester, String uid, CraftOp op) async {
  await _pickWeapon(tester, uid);
  await _tap(tester, 'bench-op-${op.name}');
}

/// Paso 1 → [uid] → paso 2 (tocar la fila ya elegida también avanza).
Future<void> _pickWeapon(WidgetTester tester, String uid) async {
  await _tap(tester, 'bench-crumb-0');
  await _tap(tester, 'bench-weapon-$uid');
  if (find.byKey(const ValueKey('bench-next')).evaluate().isNotEmpty) {
    await _tap(tester, 'bench-next');
  }
}

/// Recorre el selector de familia de reforjar hasta [label].
Future<void> _family(WidgetTester tester, String label) async {
  for (var i = 0; i < 20 && plain(tester, 'bench-family-value') != label; i++) {
    await _tap(tester, 'bench-family-next');
  }
  expect(plain(tester, 'bench-family-value'), label);
}

/// Valor de la fila del paso 2: costo corto o motivo corto (el completo
/// va en el detalle).
String _why(WidgetTester tester, CraftOp op) =>
    plain(tester, 'bench-op-why-${op.name}');

/// El botón grande de confirmar del paso 3.
ConfirmButton _confirm(WidgetTester tester) =>
    tester.widget<ConfirmButton>(find.byKey(const ValueKey('craft-confirm')));

void main() {
  testWidgets('pasos: arma → acción (con motivo por fila) → confirmar',
      (tester) async {
    await _bench(tester, lootWarrior());
    // Paso 1: la lista de armas y la ficha; materiales con tooltip.
    expect(find.byKey(const ValueKey('bench-weapon-espada_bronce')),
        findsOneWidget);
    expect(plain(tester, 'craft-materials'), contains('Esquirla x2'));
    expect(plain(tester, 'craft-materials'), contains('Cristal x1'));
    await _tap(tester, 'bench-weapon-r1');
    await _tap(tester, 'bench-next');
    // Paso 2: una fila por acción, agrupadas, con el costo o el motivo.
    for (final op in [
      CraftOp.reroll,
      CraftOp.addAffix,
      CraftOp.upgradeRarity,
      CraftOp.transferAffix,
      CraftOp.transferPassive,
      CraftOp.transferSkill,
      CraftOp.removeAffix,
      CraftOp.reforge,
    ]) {
      expect(find.byKey(ValueKey('bench-op-${op.name}')), findsOneWidget);
    }
    expect(find.textContaining('MEJORAR'), findsWidgets);
    expect(find.textContaining('TRASLADAR'), findsWidgets);
    expect(_why(tester, CraftOp.reroll), contains('1 Esquirla'));
    expect(_why(tester, CraftOp.upgradeRarity), 'Falta Prisma Roto');
    expect(_why(tester, CraftOp.transferPassive), 'Solo a un arma Epica');
    expect(plain(tester, 'bench-summary'), contains('Eco Voraz'));
    // Paso 3 y volver.
    await _tap(tester, 'bench-op-reroll');
    expect(find.byKey(const ValueKey('craft-confirm')), findsOneWidget);
    expect(find.byKey(const ValueKey('craft-tier-help')), findsOneWidget);
    await _tap(tester, 'bench-back');
    expect(find.byKey(const ValueKey('bench-op-reroll')), findsOneWidget);
  });

  testWidgets('traer mod: ahora → después, gastas, pierdes y confirmar',
      (tester) async {
    final c = await _bench(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    await _choose(tester, 'r1', CraftOp.transferAffix);
    // La equipada no aparece para sacrificar.
    expect(find.byKey(const ValueKey('craft-source-espada_bronce')),
        findsNothing);
    await _tap(tester, 'craft-source-m1');
    await _tap(tester, 'craft-pick-0');
    expect(plain(tester, 'craft-mods-title'), contains('Mods 3/4'));
    expect(plain(tester, 'craft-mods'), contains('(nuevo)'));
    expect(plain(tester, 'craft-lost'), contains('Katana de Escarcha'));
    expect(plain(tester, 'craft-lost'), contains('se destruye'));
    final cost =
        CraftRules.transferAffixCost(magicKatana.affixes[0], Rarity.raro);
    expect(plain(tester, 'craft-cost'), contains('\$$cost (tienes \$5000)'));
    expect(_confirm(tester).reason, isNull);
    await _tap(tester, 'craft-confirm');
    expect(me().itemByUid('r1')!.affixes.length, 3);
    expect(me().itemByUid('m1'), isNull);
    expect(me().credits, 5000 - cost);
    expect(find.byKey(const ValueKey('craft-last')), findsOneWidget);
  });

  testWidgets('motivos del motor: sin lugar, pasiva única, equipada',
      (tester) async {
    await _bench(tester, lootWarrior());
    await _choose(tester, 'c1', CraftOp.transferAffix);
    await _tap(tester, 'craft-source-m1');
    expect(_confirm(tester).reason,
        startsWith('Sin lugar (Común'));
    expect(plain(tester, 'craft-error'), contains('No se puede'));
    await _choose(tester, 'e1', CraftOp.transferPassive);
    await _tap(tester, 'craft-source-l1');
    expect(_confirm(tester).reason, 'Pasiva única');
    // Reforjar: la equipada y los legendarios no.
    await _pickWeapon(tester, 'espada_bronce');
    expect(_why(tester, CraftOp.reforge), 'Está equipada');
    await _pickWeapon(tester, 'l1');
    expect(_why(tester, CraftOp.reforge), 'Un Legendario no cambia de base');
  });

  testWidgets('traer habilidad y quitar mod', (tester) async {
    final c = await _bench(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    await _choose(tester, 'e1', CraftOp.transferSkill);
    await _tap(tester, 'craft-source-c1');
    await _tap(tester, 'craft-pick-0');
    expect(plain(tester, 'craft-skills'), contains('(nueva)'));
    await _tap(tester, 'craft-confirm');
    expect(me().itemByUid('e1')!.extraSkills, hasLength(1));
    expect(me().itemByUid('c1'), isNull);

    await _choose(tester, 'r1', CraftOp.removeAffix);
    await _tap(tester, 'craft-pick-1');
    expect(plain(tester, 'craft-mods'), contains('(se quita)'));
    expect(plain(tester, 'craft-lost'), contains('Nada'));
    await _tap(tester, 'craft-confirm');
    expect(me().itemByUid('r1')!.affixes.map((a) => a.affixId), ['feroz']);
  });

  testWidgets('cristal, esquirla y prisma: qué puede salir y resultado',
      (tester) async {
    final c = await _bench(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    await _choose(tester, 'c1', CraftOp.addAffix);
    expect(_confirm(tester).reason,
        'Un arma Común no lleva afijos');
    await _choose(tester, 'r1', CraftOp.addAffix);
    expect(plain(tester, 'craft-outcomes'), isNotEmpty);
    expect(plain(tester, 'craft-cost'), contains('1 Cristal de Era (tienes 1)'));
    await _tap(tester, 'craft-confirm');
    expect(me().itemByUid('r1')!.affixes.length, 3);
    expect(me().material(CraftMaterial.cristal), 0);
    expect(plain(tester, 'craft-last'), contains('(nuevo)'));
    expect(_confirm(tester).reason, 'Falta Cristal de Era');

    await _choose(tester, 'r1', CraftOp.reroll);
    expect(plain(tester, 'craft-outcomes'), contains('% ATQ: 5–9'));
    expect(_confirm(tester).reason, isNull);

    await _choose(tester, 'r1', CraftOp.upgradeRarity);
    expect(_confirm(tester).reason, 'Falta Prisma Roto');
    expect(plain(tester, 'craft-outcomes'), contains('Raro → '));
    await _choose(tester, 'e1', CraftOp.upgradeRarity);
    expect(_confirm(tester).reason,
        'Ya está en la rareza máxima');
  });

  testWidgets('reforjar base: antes → después, lo que se pierde y costo',
      (tester) async {
    final c = await _bench(
        tester,
        lootWarrior(materials: const {
          CraftMaterial.cristal: 1,
          CraftMaterial.prisma: 1,
        }));
    PlayerProfile me() => c.view!.me!.profile;
    await _choose(tester, 'e1', CraftOp.reforge);
    // Por defecto, las bases de tu familia; se cambia con el filtro.
    expect(find.byKey(const ValueKey('bench-base-hacha_rompe')), findsOneWidget);
    await _family(tester, 'MAGA');
    await _tap(tester, 'bench-base-baculo_fuego');
    expect(plain(tester, 'craft-base'), contains('Espada Ignea'));
    expect(plain(tester, 'craft-base'), contains('Báculo de Fuego'));
    expect(plain(tester, 'craft-lost'), contains('Pasiva Impetu'));
    expect(plain(tester, 'craft-cost'), contains('\$700'));
    expect(plain(tester, 'craft-cost'), contains('1 Prisma Roto (tienes 1)'));
    expect(_confirm(tester).reason, isNull);
    await _tap(tester, 'craft-confirm');
    final it = me().itemByUid('e1')!;
    expect(it.baseId, 'baculo_fuego');
    expect(it.rarity, Rarity.epico);
    expect(it.affixes, hasLength(4));
    expect(me().material(CraftMaterial.prisma), 0);
    // Sin materiales: el motivo.
    await _tap(tester, 'bench-base-baculo_ponzona');
    expect(_confirm(tester).reason, 'Falta Cristal de Era');
  });

  testWidgets('subir rareza con Prisma: Común → Mágico', (tester) async {
    final c = await _bench(
        tester, lootWarrior(materials: const {CraftMaterial.prisma: 1}));
    await _choose(tester, 'c1', CraftOp.upgradeRarity);
    expect(_confirm(tester).reason, isNull);
    await _tap(tester, 'craft-confirm');
    final it = c.view!.me!.profile.itemByUid('c1')!;
    expect(it.rarity, Rarity.magico);
    expect(it.affixes, isNotEmpty);
  });
}
