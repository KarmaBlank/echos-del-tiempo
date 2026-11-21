import 'package:echos_del_tiempo/features/inventory/presentation/armory_panel.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/inventory/domain/battle_impact.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/features/inventory/domain/skill_tip.dart';
import 'package:echos_del_tiempo/features/inventory/domain/shop_preview.dart';
import 'package:echos_del_tiempo/game_engine/rules/js_math.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

/// Fichas de habilidad fuera de la batalla (panels.md § "Ficha de
/// habilidad (v0.5.1)"): tooltip al pasar el mouse y descripción en línea
/// en la fusión; elegir qué trasladada se reemplaza.

Future<void> _tap(WidgetTester tester, String key) =>
    tapVisible(tester, find.byKey(ValueKey(key)));

Future<void> _choose(WidgetTester tester, String uid, CraftOp op) async {
  await _tap(tester, 'bench-crumb-0');
  await _tap(tester, 'bench-weapon-$uid');
  if (find.byKey(const ValueKey('bench-next')).evaluate().isNotEmpty) {
    await _tap(tester, 'bench-next');
  }
  await _tap(tester, 'bench-op-${op.name}');
}

Future<TestGesture> _hover(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  await g.moveTo(tester.getCenter(f));
  await tester.pump();
  return g;
}

int _count(String text) =>
    find.textContaining(text, findRichText: true).evaluate().length;

void main() {
  testWidgets('fusión paso 3: la habilidad elegida se explica en línea y con '
      'tooltip', (tester) async {
    await pumpPanel(tester,
        profile: lootWarrior(),
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.fuse));
    await _choose(tester, 'e1', CraftOp.transferSkill);
    await _tap(tester, 'craft-source-c1');
    await _tap(tester, 'craft-pick-0');
    // En línea, debajo de la elegida: tipo, MP y el texto de batalla.
    final desc = plain(tester, 'craft-pick-desc');
    expect(desc, contains('MP'));
    expect(desc, matches(RegExp('Físico|Mágico|Curación|Apoyo')));
    // v0.9.7: sin tooltip en la lista (la ficha ya está debajo de la
    // elegida; antes salía dos veces).
    final before = _count(' · a ');
    await _hover(tester, find.byKey(const ValueKey('craft-pick-1')));
    expect(_count(' · a '), before);
  });

  testWidgets('fusión: con los cupos llenos se elige qué trasladada '
      'reemplazar (las base no)', (tester) async {
    final c = await pumpPanel(tester,
        profile: lootWarrior(),
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.fuse));
    PlayerProfile me() => c.view!.me!.profile;
    // El Mágico tiene 1 cupo: la primera entra sin preguntar.
    await _choose(tester, 'm1', CraftOp.transferSkill);
    await _tap(tester, 'craft-source-c1');
    expect(find.byKey(const ValueKey('craft-replace')), findsNothing);
    await _tap(tester, 'craft-confirm');
    final first = me().itemByUid('m1')!.extraSkills.single;
    // La segunda: hay que elegir cuál se va.
    await _choose(tester, 'm1', CraftOp.transferSkill);
    final src = me()
        .items
        .where((i) => i.uid != 'm1' && i.uid != me().equippedUid)
        .map((i) => i.uid)
        .firstWhere((u) =>
            find.byKey(ValueKey('craft-source-$u')).evaluate().isNotEmpty);
    await _tap(tester, 'craft-source-$src');
    // El clic deja la ficha del arma abierta; que no tape los botones.
    RetroHoverCard.dismissAll();
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      final k = find.byKey(ValueKey('craft-pick-$i'));
      if (k.evaluate().isEmpty) break;
      await _tap(tester, 'craft-pick-$i');
      if (find.byKey(const ValueKey('craft-replace')).evaluate().isNotEmpty &&
          button(tester, 'craft-confirm').reason != null &&
          button(tester, 'craft-confirm').reason!.contains('reemplazar')) {
        break;
      }
    }
    expect(find.byKey(const ValueKey('craft-replace')), findsOneWidget);
    expect(button(tester, 'craft-confirm').reason, contains('reemplazar'));
    // Una base: bloqueada con su motivo.
    final base = me().itemByUid('m1')!.baseId;
    final baseSkill =
        progression.catalog.weapons[base]!.skillIds.first;
    expect(button(tester, 'craft-replace-$baseSkill').reason, 'Habilidad base');
    await _tap(tester, 'craft-replace-$first');
    expect(button(tester, 'craft-confirm').reason, isNull);
    expect(plain(tester, 'craft-skills'), contains('(nueva)'));
    await _tap(tester, 'craft-confirm');
    expect(me().itemByUid('m1')!.extraSkills, isNot(contains(first)));
    expect(me().itemByUid('m1')!.extraSkills, hasLength(1));
  });

  testWidgets('inventario: la ficha de la casilla explica cada habilidad',
      (tester) async {
    final p = lootWarrior();
    await pumpPanel(tester,
        profile: p,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    // La equipada: ficha simple (las demás armas, la comparada).
    expect(InventoryRules.layout(p).cells, isNotEmpty);
    expect(_count(' MP)'), 0);
    await _hover(tester, find.byKey(const ValueKey('inv-equipped')));
    // Tooltip corto (v0.9.7): las habilidades van plegadas; al
    // desplegarlas, una línea cada una: `Nombre (8 MP) Daño...` (v0.9.11).
    expect(_count(' MP)'), 0);
    // Clic: fija la caja (v0.9.13) para poder abrir los ▸.
    await tester.tap(find.byKey(const ValueKey('inv-equipped')),
        kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tip-fold-Habilidades')));
    await tester.pump();
    expect(_count(' MP)'), greaterThan(0));
  });

  testWidgets('tooltip de un arma no equipada: sus habilidades, plegadas',
      (tester) async {
    // v0.9.9: sin ficha a la derecha; lo que daban los chips con "?"
    // está en el tooltip de la casilla (sección plegada).
    final p = lootWarrior();
    await pumpPanel(tester,
        profile: p,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    final cell = InventoryRules.layout(p).cells.indexOf('e1');
    await _hover(tester, find.byKey(ValueKey('inv-cell-$cell')));
    expect(_count(' MP)'), 0);
    await tester.tap(find.byKey(ValueKey('inv-cell-$cell')),
        kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tip-fold-Habilidades')).first);
    await tester.pump();
    expect(_count(' MP)'), greaterThan(0));
  });

  testWidgets('forja: VEL dice cada cuánto llega tu turno (motor de batalla)',
      (tester) async {
    final p = lootWarrior();
    await pumpPanel(tester,
        profile: p,
        build: (v, c) =>
            ArmoryPanel(view: v, controller: c, initialTab: ArmoryTab.forge));
    final it = p.itemByUid(p.equippedUid!)!;
    final after = progression.crafting.forge(p, it.uid, UpgradeStat.spd).after!;
    final b = ShopPreview(progression).withItem(p, it);
    final a = ShopPreview(progression).withItem(p, after);
    final engine = BattleEngine(stats: progression.stats);
    String f(double x) => x == x.roundToDouble()
        ? '${x.round()}'
        : x.toStringAsFixed(1);
    final ib = engine.interval(tipUser(b)!), ia = engine.interval(tipUser(a)!);
    final text = plain(tester, 'forge-impact-spd');
    expect(text, contains('En batalla'));
    expect(text, contains('Tu turno llega cada ${f(ib)} → ${f(ia)}'));
    expect(text, contains('${jsRound((ib / ia - 1) * 100)}% más seguido'));
    expect(battleImpactLines(progression, b, b), isEmpty);
  });

  testWidgets('atributos: el tooltip de cada atributo dice qué cambia en '
      'batalla', (tester) async {
    await pumpPanel(tester,
        profile: progression.normalize(
            PlayerProfile(name: 'Ana', classId: 'guerrero', level: 3)),
        build: (v, c) => CharacterPanel(view: v, controller: c));
    expect(_count('Tu turno llega cada'), 0);
    await _hover(tester, find.byKey(const ValueKey('attr-row-agi')));
    expect(_count('Tu turno llega cada'), greaterThan(0));
  });
}
