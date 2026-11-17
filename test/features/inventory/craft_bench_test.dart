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

Future<SessionController> _bench(WidgetTester tester, PlayerProfile p) =>
    pumpPanel(tester,
        profile: p,
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.fuse));

Future<void> _tap(WidgetTester tester, String key) =>
    tapVisible(tester, find.byKey(ValueKey(key)));

void main() {
  testWidgets('trasladar mod: vista previa (nuevo, se pierde, costo) y confirmar',
      (tester) async {
    final c = await _bench(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    // Materiales a la vista.
    expect(plain(tester, 'craft-materials'), contains('Esquirla x2'));
    expect(plain(tester, 'craft-materials'), contains('Cristal x1'));
    // Destino: el Raro (2/4 mods); origen: el Mágico; mod: Afilado.
    await _tap(tester, 'craft-op-transferAffix');
    await _tap(tester, 'craft-target-r1');
    await _tap(tester, 'craft-source-m1');
    await _tap(tester, 'craft-pick-0');
    expect(plain(tester, 'craft-mods-title'), contains('Mods 3/4'));
    expect(plain(tester, 'craft-mods'), contains('(nuevo)'));
    expect(plain(tester, 'craft-lost'), contains('Katana de Escarcha'));
    expect(button(tester, 'craft-confirm').reason, isNull);
    final cost = CraftRules.transferAffixCost(
        magicKatana.affixes[0], Rarity.raro);
    expect(find.textContaining('Costo \$$cost'), findsOneWidget);
    await _tap(tester, 'craft-confirm');
    expect(me().itemByUid('r1')!.affixes.length, 3);
    expect(me().itemByUid('m1'), isNull);
    expect(me().credits, 5000 - cost);
  });

  testWidgets('errores del motor como motivo: sin lugar, no Épica, equipada',
      (tester) async {
    await _bench(tester, lootWarrior());
    // A un Común no entra ningún mod.
    await _tap(tester, 'craft-op-transferAffix');
    await _tap(tester, 'craft-target-c1');
    await _tap(tester, 'craft-source-m1');
    expect(button(tester, 'craft-confirm').reason,
        startsWith('Sin lugar (Común'));
    // La pasiva solo va a un arma Épica.
    await _tap(tester, 'craft-op-transferPassive');
    await _tap(tester, 'craft-target-r1');
    await _tap(tester, 'craft-source-e1');
    expect(button(tester, 'craft-confirm').reason, 'Solo a un arma Épica');
    // La equipada no aparece para sacrificar.
    expect(find.byKey(const ValueKey('craft-source-espada_bronce')),
        findsNothing);
    // Las pasivas únicas no se trasladan.
    await _tap(tester, 'craft-target-e1');
    await _tap(tester, 'craft-source-l1');
    expect(button(tester, 'craft-confirm').reason, 'Pasiva única');
  });

  testWidgets('trasladar habilidad y quitar mod', (tester) async {
    final c = await _bench(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    await _tap(tester, 'craft-op-transferSkill');
    await _tap(tester, 'craft-target-e1');
    await _tap(tester, 'craft-source-c1');
    await _tap(tester, 'craft-pick-0');
    expect(plain(tester, 'craft-skills'), contains('(nueva)'));
    await _tap(tester, 'craft-confirm');
    expect(me().itemByUid('e1')!.extraSkills, hasLength(1));
    expect(me().itemByUid('c1'), isNull);

    await _tap(tester, 'craft-op-removeAffix');
    await _tap(tester, 'craft-target-r1');
    await _tap(tester, 'craft-pick-1');
    expect(plain(tester, 'craft-mods'), contains('(se quita)'));
    await _tap(tester, 'craft-confirm');
    expect(me().itemByUid('r1')!.affixes.map((a) => a.affixId), ['feroz']);
  });

  testWidgets('cristal, esquirla y prisma: costo, qué puede salir y resultado',
      (tester) async {
    final c = await _bench(tester, lootWarrior());
    PlayerProfile me() => c.view!.me!.profile;
    // Agregar mod: Común no; Raro sí, con lo que puede salir.
    await _tap(tester, 'craft-op-addAffix');
    await _tap(tester, 'craft-target-c1');
    expect(button(tester, 'craft-confirm').reason,
        'Un arma Común no lleva afijos');
    await _tap(tester, 'craft-target-r1');
    expect(plain(tester, 'craft-outcomes'), contains('Puede salir'));
    expect(find.textContaining('1 Cristal de Era (tienes 1)'), findsOneWidget);
    await _tap(tester, 'craft-confirm');
    expect(me().itemByUid('r1')!.affixes.length, 3);
    expect(me().material(CraftMaterial.cristal), 0);
    expect(find.byKey(const ValueKey('craft-last')), findsOneWidget);
    // Sin cristales: el motivo es el material.
    expect(button(tester, 'craft-confirm').reason, 'Falta Cristal de Era');

    // Re-tirar: rangos por tier.
    await _tap(tester, 'craft-op-reroll');
    expect(plain(tester, 'craft-outcomes'), contains('% ATQ: 5–9'));
    expect(button(tester, 'craft-confirm').reason, isNull);

    // Subir rareza: sin Prisma; un Épico ya no sube (Legendario se encuentra).
    await _tap(tester, 'craft-op-upgradeRarity');
    expect(button(tester, 'craft-confirm').reason, 'Falta Prisma Roto');
    expect(plain(tester, 'craft-outcomes'), contains('Raro → '));
    await _tap(tester, 'craft-target-e1');
    expect(button(tester, 'craft-confirm').reason,
        'Ya está en la rareza máxima');
  });

  testWidgets('subir rareza con Prisma: Común → Mágico', (tester) async {
    final c = await _bench(
        tester, lootWarrior(materials: const {CraftMaterial.prisma: 1}));
    await _tap(tester, 'craft-op-upgradeRarity');
    await _tap(tester, 'craft-target-c1');
    expect(button(tester, 'craft-confirm').reason, isNull);
    await _tap(tester, 'craft-confirm');
    final it = c.view!.me!.profile.itemByUid('c1')!;
    expect(it.rarity, Rarity.magico);
    expect(it.affixes, isNotEmpty);
  });
}
