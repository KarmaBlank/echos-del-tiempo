import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_feed.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_plan_providers.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/craft_bench.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/shop_sections.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

String _text(WidgetTester tester, String key) {
  final f = find.descendant(
      of: find.byKey(ValueKey(key)), matching: find.byType(RichText));
  return tester
      .widgetList<RichText>(f)
      .map((r) => r.text.toPlainText())
      .join(' ');
}

void main() {
  testWidgets('BUILD: plantilla, progreso, siguiente paso y quitar metas',
      (tester) async {
    final start = progression
        .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 6));
    await pumpPanel(tester,
        profile: start,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.build));
    expect(find.byKey(const ValueKey('build-planner')), findsOneWidget);
    expect(_text(tester, 'build-next'), contains('plantilla'));

    await tapVisible(tester, find.byKey(const ValueKey('build-template')));
    await tester.pumpAndSettle();
    // Solo las plantillas del Guerrero.
    expect(
        find.byKey(const ValueKey('pick-tpl-gue_berserker')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-tpl-mag_brasa')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pick-tpl-gue_berserker')));
    await tester.pumpAndSettle();

    final plan = _container(tester).read(buildPlanProvider).plan;
    expect(plan.templateId, 'gue_berserker');
    expect(plan.attributes[Attribute.fue], 40);
    expect(_text(tester, 'build-name'), contains('Berserker sangrado'));
    // Tiene 15 puntos sin repartir: el siguiente paso es FUE.
    expect(_text(tester, 'build-next'), contains('según tu build, FUE'));
    expect(find.byKey(const ValueKey('build-goal-attr:fue')), findsOneWidget);
    expect(_text(tester, 'build-goal-attr:fue'), contains('12/40'));
    expect(
        find.byKey(const ValueKey('build-goal-node:sangre_k')), findsOneWidget);
    expect(_text(tester, 'build-tree-small'), contains('/'));

    // Quitar una meta.
    await tapVisible(
        tester, find.byKey(const ValueKey('build-remove-skill:hendir')));
    expect(_container(tester).read(buildPlanProvider).plan.skills, ['sangria']);
    // −5 / +5 al objetivo de un atributo.
    await tapVisible(tester, find.byKey(const ValueKey('build-inc-fue')));
    expect(
        _container(tester)
            .read(buildPlanProvider)
            .plan
            .attributes[Attribute.fue],
        45);

    // Árbol en modo planificar.
    await tapVisible(tester, find.byKey(const ValueKey('build-open-tree')));
    expect(find.byKey(const ValueKey('build-tree')), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('build-tree-back')));
    expect(find.byKey(const ValueKey('build-tree')), findsNothing);
  });

  testWidgets('ATRIBUTOS: "según tu build" con el objetivo', (tester) async {
    final start = progression
        .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 3));
    await pumpPanel(tester,
        profile: start,
        build: (v, c) => CharacterPanel(view: v, controller: c));
    await _container(tester)
        .read(buildPlanProvider.notifier)
        .save(const BuildPlan(attributes: {Attribute.fue: 30}));
    await tester.pump();
    expect(find.byKey(const ValueKey('build-attr-hint')), findsOneWidget);
    expect(find.text('★ 12/30'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('inc-fue')));
    expect(find.text('★ 13/30'), findsOneWidget);
  });

  testWidgets('COMPRAR: ★ en la fila y "Tu build" en el detalle',
      (tester) async {
    final start = progression
        .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 5));
    await pumpPanel(tester,
        profile: start, build: (v, c) => BuyTab(shop: ShopContext(v, c)));
    String row(String id) => _text(tester, 'shop-row-$id');
    expect(row('hacha_rompe'), isNot(contains('★')));
    await _container(tester)
        .read(buildPlanProvider.notifier)
        .save(const BuildPlan(weaponBases: ['hacha_rompe'], skills: ['sismo']));
    await tester.pump();
    expect(row('hacha_rompe'), contains('★'));
    expect(row('espada_bronce'), isNot(contains('★')));
    await tapVisible(
        tester, find.byKey(const ValueKey('shop-row-hacha_rompe')));
    final fit = _text(tester, 'shop-build-fit');
    expect(fit, contains('Tu build'));
    expect(fit, contains('base del plan'));
    expect(fit, contains(protoPlain('Golpe Sísmico')));
  });

  testWidgets('avisos: cartel y línea de chat al repartir; ajuste apagado',
      (tester) async {
    final start = progression
        .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 3));
    final c = await pumpPanel(tester,
        profile: start,
        build: (v, c) => Consumer(
            builder: (context, ref, _) =>
                BuildToasts(feed: ref.watch(buildFeedProvider))));
    final container = _container(tester);
    await container
        .read(buildPlanProvider.notifier)
        .save(const BuildPlan(attributes: {Attribute.fue: 30}));
    await tester.pump();
    expect(c.allocate({Attribute.fue: 2}), isTrue);
    await tester.pump();
    await tester.pump();
    expect(find.text('Build: FUE 14/30'), findsOneWidget);
    expect(c.view!.chat.last.text, 'Build: FUE 14/30');
    expect(c.view!.chat.last.system, isTrue);

    // Con el ajuste apagado no hay aviso nuevo.
    final settings = container.read(gameSettingsProvider.notifier);
    await settings.update(
        container.read(gameSettingsProvider).copyWith(buildNotices: false));
    expect(c.allocate({Attribute.fue: 1}), isTrue);
    await tester.pump();
    await tester.pump();
    expect(c.view!.chat.last.text, 'Build: FUE 14/30');
    // Fuera la pantalla: se cancela el refresco de los carteles.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('FUSIÓN: ★ en la tarjeta del arma que cumple el plan',
      (tester) async {
    final start = progression.normalize(
        PlayerProfile(name: 'Ana', classId: 'guerrero', level: 5, items: [
      ItemInstance.common('espada_bronce', 'espada_bronce'),
      const ItemInstance(
          uid: 'm',
          baseId: 'espada_bronce',
          rarity: Rarity.magico,
          affixes: [AffixRoll('feroz', 5, 3)]),
    ]));
    await pumpPanel(tester,
        profile: start, build: (v, c) => CraftBench(shop: ShopContext(v, c)));
    expect(find.byKey(const ValueKey('build-fit-badge')), findsNothing);
    await _container(tester)
        .read(buildPlanProvider.notifier)
        .save(const BuildPlan(mods: [ModGoal('feroz', 5)]));
    await tester.pump();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('bench-weapon-m')),
            matching: find.byKey(const ValueKey('build-fit-badge'))),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('bench-weapon-espada_bronce')),
            matching: find.byKey(const ValueKey('build-fit-badge'))),
        findsNothing);
  });
}
