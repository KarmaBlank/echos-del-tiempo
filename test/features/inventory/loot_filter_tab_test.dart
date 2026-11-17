import 'package:echos_del_tiempo/features/inventory/presentation/item_widgets.dart';
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
  testWidgets('filtro: errores por línea, guardar y restaurar', (tester) async {
    final c = await pumpPanel(tester,
        profile: lootWarrior(),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.filter));
    String? saved() => c.view!.me!.profile.lootFilter;
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

  testWidgets('resultado: tus drops con el estilo del filtro', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final style = LootFilterRules.defaultStyle(
        const LootDrop.item(ItemInstance(uid: 'a', baseId: 'espada_bronce')));
    await tester.pumpWidget(MaterialApp(
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
    ));
    expect(find.text('TUS DROPS (2)'), findsOneWidget);
    expect(find.byType(LootLabel), findsNWidgets(2));
    expect(find.textContaining('(oculto por tu filtro)'), findsOneWidget);
  });

  test('etiqueta: tamaño de letra según el filtro', () {
    expect(LootLabel.fontSizeFor(32), 8);
    expect(LootLabel.fontSizeFor(42), 16);
    expect(RarityColors.of(Rarity.legendario), const Color(0xFFFF8C28));
  });
}
