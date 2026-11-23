import 'package:echos_del_tiempo/app/feature_flags.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/presentation/characters_providers.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/loot_filter_tab.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:echos_del_tiempo/features/missions/presentation/results_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_filter_rules.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import '../panel_test_harness.dart';
import 'loot_fixtures.dart';

const _custom = '''
Ocultar # sin comunes
  Rareza Común
Mostrar
  Rareza >= Raro
  Color 255 0 0
''';

void main() {
  // La party jugando solo está detrás de FeatureFlags.soloParty
  // (apagada en la build principal desde v0.9.14).
  setUpAll(() => FeatureFlags.instance = const FeatureFlags(soloParty: true));
  tearDownAll(() => FeatureFlags.instance = const FeatureFlags());
  testWidgets('filtro: errores por línea, guardar y restaurar', (tester) async {
    final c = await pumpPanel(tester,
        profile: lootWarrior(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.filter));
    String? saved() => c.view!.me!.profile.lootFilter;
    // Vista TEXTO (la de entrada es CASILLAS).
    await tapVisible(tester, find.byKey(const ValueKey('filter-view-text')));
    final field = find.byKey(const ValueKey('filter-text'));
    // Arranca con el por defecto, sin errores y sin cambios.
    expect(plain(tester, 'filter-status'), contains('Sin errores'));
    expect(button(tester, 'filter-save').reason, 'Sin cambios');

    // Una línea que no se entiende: error con su número; no se guarda.
    await tester.enterText(field, 'Mostrar\n  Rareza Rarisima\n');
    await tester.pump();
    expect(plain(tester, 'filter-status'), contains('línea 2'));
    expect(button(tester, 'filter-save').reason, 'Corrige 1 error');

    // Un filtro válido: vista previa y guardar.
    await tester.enterText(field, _custom);
    await tester.pump();
    expect(plain(tester, 'filter-status'), contains('2 reglas'));
    // La muestra Común queda oculta por la regla 1.
    expect(plain(tester, 'filter-sample-0'), contains('(oculto)'));
    expect(plain(tester, 'filter-sample-0'), contains('sin comunes'));
    await tapVisible(tester, find.byKey(const ValueKey('filter-save')));
    expect(saved(), _custom);
    expect(button(tester, 'filter-save').reason, 'Sin cambios');

    // Restaurar pone el por defecto en el editor; guardarlo deja `null`.
    await tapVisible(tester, find.byKey(const ValueKey('filter-default')));
    expect(tester.widget<TextField>(field).controller!.text,
        LootFilterRules.defaultText);
    await tapVisible(tester, find.byKey(const ValueKey('filter-save')));
    expect(saved(), isNull);
  });

  testWidgets('casillas: ocultar rápido, apagar y borrar reglas',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: lootWarrior(level: 12),
        textSize: TextSize.normal,
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.filter));
    String text() => tester
        .widget<TextField>(find.byKey(const ValueKey('filter-text')))
        .controller!
        .text;
    Future<void> tap(String key) =>
        tapVisible(tester, find.byKey(ValueKey(key)));
    String title() => plain(tester, 'filter-rules-title');
    String check(String key) =>
        (tester.widget<FilterCheck>(find.byKey(ValueKey(key))).value)
            ? 'x'
            : ' ';

    // Arranca en CASILLAS con las 8 reglas del por defecto.
    expect(find.byKey(const ValueKey('filter-checks')), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-text')), findsNothing);
    expect(title(), 'TUS REGLAS (8)');
    expect(check('filter-quick-rareza-comun'), ' ');
    // La muestra Común de nivel bajo la oculta la regla del por defecto.
    expect(plain(tester, 'filter-sample-0'), contains('Comunes de nivel bajo'));

    // Marcar: regla nueva arriba, la vista previa la usa.
    await tap('filter-quick-rareza-comun');
    expect(check('filter-quick-rareza-comun'), 'x');
    expect(plain(tester, 'filter-status'), contains('9 reglas'));
    expect(plain(tester, 'filter-sample-0'), contains('(oculto)'));
    expect(plain(tester, 'filter-sample-0'), contains('rápido: armas comunes'));
    expect(plain(tester, 'filter-rule-0'), contains('rápido: armas comunes'));
    // Desmarcar la saca: vuelve el por defecto exacto.
    await tap('filter-quick-rareza-comun');
    expect(plain(tester, 'filter-status'), contains('8 reglas'));
    expect(button(tester, 'filter-save').reason, 'Sin cambios');

    // OFF: "Comunes de nivel bajo" (la 7.ª) queda comentada y no aplica.
    expect(plain(tester, 'filter-rule-6'), contains('Comunes de nivel bajo'));
    await tap('filter-rule-on-6');
    expect(check('filter-rule-on-6'), ' ');
    expect(plain(tester, 'filter-status'), contains('7 reglas'));
    expect(plain(tester, 'filter-sample-0'), isNot(contains('(oculto)')));
    expect(title(), 'TUS REGLAS (8)');

    // ✕ borra la primera (Ecos).
    await tap('filter-rule-del-0');
    expect(title(), 'TUS REGLAS (7)');
    expect(plain(tester, 'filter-rule-0'), contains('Legendarios'));

    // Todo pasó por el texto.
    await tap('filter-view-text');
    expect(text(), contains('#OFF Ocultar # Comunes de nivel bajo\n'));
    expect(text(), isNot(contains('Mostrar # Ecos')));
    await tap('filter-save');
    expect(c.view!.me!.profile.lootFilter, text());
    expect(tester.takeException(), isNull);
  });

  testWidgets('compañero: el editor muestra y guarda SU filtro',
      (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var a = Account();
    a = a.add(newProfile('Ana', 'guerrero'))!;
    a = a.add(newProfile('Leo', 'maga'))!;
    final repo = AccountRepository(
        InMemoryAccountStore(a.select('c1').withParty(['c2'])));
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
            return CharacterPanel(
                view: view, controller: c, initialTab: CharacterTab.filter);
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
    bool checked(String id) => tester
        .widget<FilterCheck>(find.byKey(ValueKey('filter-quick-$id')))
        .value;

    // La líder marca algo sin guardar y cambia a Leo.
    await tapVisible(
        tester, find.byKey(const ValueKey('filter-quick-rareza-comun')));
    expect(checked('rareza-comun'), isTrue);
    await tester.tap(find.byKey(const ValueKey('member-local-c2')));
    await tester.pump();
    expect(c.view!.actorId, 'local-c2');
    // Leo arranca con SU filtro (el por defecto), no con el de Ana.
    expect(checked('rareza-comun'), isFalse);
    expect(button(tester, 'filter-save').reason, 'Sin cambios');

    await tapVisible(
        tester, find.byKey(const ValueKey('filter-quick-pociones')));
    await tapVisible(tester, find.byKey(const ValueKey('filter-save')));
    expect(c.session!.players['local-c2']!.profile.lootFilter,
        contains('rápido: pociones'));
    expect(c.session!.players['local']!.profile.lootFilter, isNull);
    // El host lo usa para Leo: las pociones de Leo quedan ocultas.
    const pot = LootDrop.stack(StackKind.potion, 1);
    expect(c.lootVerdictFor('local-c2', pot)!.visible, isFalse);
    expect(c.lootVerdictFor('local', pot)!.visible, isTrue);

    // De vuelta en Ana: su editor, sin la casilla de Leo.
    await tester.tap(find.byKey(const ValueKey('member-local')));
    await tester.pump();
    expect(checked('pociones'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resultado: tus drops con el estilo del filtro', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final style = LootFilterRules.defaultStyle(
        const LootDrop.item(ItemInstance(uid: 'a', baseId: 'espada_bronce')));
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: ResultsPanel(
          result: MissionResult(
            id: 1,
            missionId: 'm1',
            missionName: 'Prueba',
            success: true,
            rank: MissionRank.a,
            time: 100,
            xp: 10,
            credits: 10,
            bonus: 5,
            bonusPercent: 0.25,
            kos: 0,
            elites: 0,
            eliteDrops: const [],
            drops: const {},
          ),
          localId: 'p0',
          playerName: (_) => 'Ana',
          weaponName: (id) => id,
          onBack: () {},
          loot: [
            ResultDrop('Filo del Alba', FilterVerdict(true, style)),
            ResultDrop('Espada de Bronce', FilterVerdict(false, style)),
          ],
        ),
      ),
    )));
    expect(find.text('TUS DROPS (2)'), findsOneWidget);
    expect(find.byType(LootLabel), findsNWidgets(2));
    expect(find.textContaining('(oculto por tu filtro)'), findsOneWidget);
  });

  test('etiqueta: tamaño de letra según el filtro', () {
    expect(LootLabel.fontSizeFor(32), RetroType.small);
    expect(LootLabel.fontSizeFor(42), RetroType.title);
    expect(RarityColors.of(Rarity.legendario), const Color(0xFFFF8C28));
  });
}
