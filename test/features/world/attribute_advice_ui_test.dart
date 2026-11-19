import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/build_planner/presentation/build_plan_providers.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/attribute_advisor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import '../panel_test_harness.dart';
import '../../app/button_look.dart';

/// Tarjeta SUGERENCIA (ATRIBUTOS) y "Atributos sugeridos" (BUILD):
/// docs/specs/build_planner.md § 8.

Future<void> _applyAdvice(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const ValueKey('apply-advice')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('pick-advice-yes')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('pick-advice-yes')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ATRIBUTOS: la sugerencia se ve y APLICAR gasta los puntos',
      (tester) async {
    final start = progression
        .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 3));
    final c = await pumpPanel(tester,
        profile: start,
        build: (v, c) => CharacterPanel(view: v, controller: c));
    final advice = AttributeAdvisor(c.engine.progression).recommend(start);
    final add = AttributeAdvisor.allocation(advice);
    expect(find.byKey(const ValueKey('attr-advice')), findsOneWidget);
    expect(
        find.text('Sugerencia: ${AttributeAdvisor.split(advice)}'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('attr-advice-fue')), findsOneWidget);
    // APLICAR SUGERENCIA se ve como botón, no como texto suelto.
    expectButtonLook(tester, find.byKey(const ValueKey('apply-advice')));
    expect(find.textContaining('escala FUE×0.6'), findsWidgets);

    // Con un reparto pendiente: "No" no cambia nada.
    await tapVisible(tester, find.byKey(const ValueKey('inc-vit')));
    await tapVisible(tester, find.byKey(const ValueKey('apply-advice')));
    await tester.pumpAndSettle();
    expect(find.textContaining('se descarta el reparto pendiente'),
        findsOneWidget);
    // Las opciones del selector también son botones.
    expectButtonLook(tester, find.byKey(const ValueKey('pick-advice-yes')));
    expectButtonLook(tester, find.byKey(const ValueKey('pick-advice-no')));
    await tester.tap(find.byKey(const ValueKey('pick-advice-no')));
    await tester.pumpAndSettle();
    expect(c.view!.me!.profile.points, 6);

    await _applyAdvice(tester);
    final p = c.view!.me!.profile;
    expect(p.points, 0);
    for (final a in Attribute.values) {
      expect(p.attributes[a], start.attributes[a] + (add[a] ?? 0),
          reason: a.name);
    }
    // Sin puntos la tarjeta desaparece.
    expect(find.byKey(const ValueKey('attr-advice')), findsNothing);
  });

  testWidgets('ATRIBUTOS: APLICAR va al compañero elegido, no al líder',
      (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var a = Account();
    a = a.add(newProfile('Ana', 'guerrero'))!;
    a = a.add(progression
        .normalize(newProfile('Leo', 'maga').copyWith(level: 5)))!;
    final repo =
        AccountRepository(InMemoryAccountStore(a.select('c1').withParty(['c2'])));
    late SessionController c;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine()),
        profileStoreProvider
            .overrideWithValue(SelectedCharacterProfileStore(repo)),
        accountRepositoryProvider.overrideWithValue(repo),
        partyStoreProvider.overrideWithValue(AccountPartyStore(repo)),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
      ],
      child: MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(
          body: Consumer(builder: (context, ref, _) {
            final view = ref.watch(sessionControllerProvider);
            c = ref.read(sessionControllerProvider.notifier);
            if (view == null || view.panel != WorldPanel.character) {
              return const SizedBox.shrink();
            }
            return CharacterPanel(view: view, controller: c);
          }),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    c.openPanel(WorldPanel.character);
    await tester.pump();
    // Ana (líder) no tiene puntos: sin tarjeta.
    expect(find.byKey(const ValueKey('attr-advice')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('member-local-c2')));
    await tester.pump();
    expect(c.view!.actorId, 'local-c2');
    final leo0 = c.session!.players['local-c2']!.profile;
    final ana0 = c.session!.players['local']!.profile;
    expect(leo0.points, 12);
    final add = AttributeAdvisor.allocation(
        AttributeAdvisor(c.engine.progression).recommend(leo0));
    expect(add[Attribute.esp], greaterThan(0), reason: 'maga: ESP');
    expect(find.byKey(const ValueKey('attr-advice')), findsOneWidget);

    await _applyAdvice(tester);
    final leo = c.session!.players['local-c2']!.profile;
    expect(leo.points, 0);
    for (final x in Attribute.values) {
      expect(leo.attributes[x], leo0.attributes[x] + (add[x] ?? 0));
    }
    final ana = c.session!.players['local']!.profile;
    expect(ana.attributes.values, ana0.attributes.values);
    expect(ana.points, ana0.points);
  });

  testWidgets('BUILD: Atributos sugeridos y AGREGAR COMO META',
      (tester) async {
    final start = progression
        .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 3));
    final c = await pumpPanel(tester,
        profile: start,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.build));
    final pts = AttributeAdvisor.horizonPoints(start);
    expect(pts, 6 + 15);
    final s = AttributeAdvisor(c.engine.progression).recommend(start, null, pts);
    expect(
        find.text('Atributos sugeridos ($pts puntos: libres y próximos '
            'niveles): ${AttributeAdvisor.split(s)}'),
        findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('build-advice-goals')));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first));
    final plan = container.read(buildPlanProvider).plan;
    for (final x in s) {
      expect(plan.attributes[x.attribute],
          start.attributes[x.attribute] + x.points);
    }
    expect(find.byKey(const ValueKey('build-goal-attr:fue')), findsOneWidget);
  });
}
