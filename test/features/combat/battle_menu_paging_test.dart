import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// El menú de batalla v0.5 va por categorías; dentro de una categoría
/// nunca hay más de 9 acciones numeradas (teclas 1-9): con más, se pagina
/// (`battleMenuPage`, docs/specs/battle_presentation.md § "Barra de
/// batalla (v0.5)").

/// Todas las páginas de [battleMenuPage] (siguiendo los `Más`).
List<List<String>> _pages(List<String> head, List<String> middle, List<String> tail) {
  final out = <List<String>>[];
  for (var p = 0; p < 20; p++) {
    final page = battleMenuPage(head, middle, tail, p,
        more: (n) => 'MAS+$n', back: 'VOLVER');
    if (out.isNotEmpty && _eq(out.last, page)) break;
    out.add(page);
  }
  return out;
}

bool _eq(List<String> a, List<String> b) =>
    a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

void main() {
  group('battleMenuPage', () {
    test('9 o menos: todo junto, sin Más', () {
      final p = _pages(['A', 'U'], ['s1', 's2', 's3', 's4'], ['V', 'M', 'D']);
      expect(p, [
        ['A', 'U', 's1', 's2', 's3', 's4', 'V', 'M', 'D']
      ]);
    });

    test('Guardián solo, arma de 3 + 2 trasladadas + kit de 3 = 13 opciones', () {
      final skills = [for (var i = 1; i <= 8; i++) 's$i'];
      final p = _pages(['A', 'U'], skills, ['V', 'M', 'D']);
      expect(p, [
        ['A', 'U', 's1', 's2', 's3', 'MAS+5', 'V', 'M', 'D'],
        ['s4', 's5', 's6', 's7', 's8', 'VOLVER'],
      ]);
    });

    test('todas las combinaciones posibles: ≤ 9 por página y nada se pierde',
        () {
      // Peor caso: Atacar + 3 Liberar + ULT; 3 de arma + 2 trasladadas +
      // 3 de kit + 3 dúos; 2 pociones + Defender.
      for (var h = 1; h <= 5; h++) {
        for (var m = 0; m <= 11; m++) {
          final head = [for (var i = 0; i < h; i++) 'h$i'];
          final middle = [for (var i = 0; i < m; i++) 'm$i'];
          const tail = ['V', 'M', 'D'];
          final pages = _pages(head, middle, tail);
          final seen = <String>[];
          for (final page in pages) {
            expect(page.length, lessThanOrEqualTo(kBattleMenuKeys),
                reason: 'h=$h m=$m');
            seen.addAll(page.where((x) => !x.startsWith('MAS') && x != 'VOLVER'));
          }
          expect(seen.toSet(), {...head, ...middle, ...tail}, reason: 'h=$h m=$m');
          expect(seen, hasLength(h + m + 3), reason: 'h=$h m=$m');
          // Las fijas (Atacar, ULT, pociones, Defender) en la página 1.
          expect(pages.first, containsAll([...head, ...tail]));
        }
      }
    });

    test('el máximo real de técnicas: 3 de arma + 2 trasladadas + kit', () {
      final maxWeapon =
          kWeapons.values.map((w) => w.skillIds.length).reduce((a, b) => a > b ? a : b);
      final maxKit = kAscensions.values
          .map((a) => a.skillIds.length)
          .reduce((a, b) => a > b ? a : b);
      expect(maxWeapon, 3);
      expect(Rarity.legendario.skillSlots, 2);
      expect(maxKit, 3); // el Guardián
      // Atacar + ULT + 8 técnicas + 2 pociones + Defender = 13 > 9.
      expect(1 + 1 + maxWeapon + 2 + maxKit + 3, 13);
    });
  });

  group('en pantalla', () {
    late BattleEngine engine;
    late BattleState state;

    setUp(() {
      engine = BattleEngine(
        stats: StatsCalculator(
            classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
        random: () => 0.99,
      );
      final cls = kClasses['paladin']!;
      final base = PlayerAttributes.base(cls.baseAttributes);
      final start = engine.start(
        party: [
          BattlePartyMember(
            id: 'g',
            name: 'Gua',
            potions: 2,
            ethers: 1,
            build: PlayerBuild(
              classId: 'paladin',
              level: 50,
              attributes: base,
              equippedWeapon: kWeapons['maza_escudo_sagrada']!,
              item: const ItemInstance(
                  uid: 'w',
                  baseId: 'maza_escudo_sagrada',
                  rarity: Rarity.epico,
                  extraSkills: ['provocar', 'bendicion']),
              ascension: const AscensionProgress(trials: {1}, id: 'guardian'),
            ),
          ),
        ],
        enemyTypes: const ['slime'],
        triggeredBy: 'g',
      );
      state = engine.nextTurn(start.state).state;
    });

    Future<BattleViewState> pump(WidgetTester tester,
        void Function(BattleCommand) onCommand) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(
          body: BattleView(
              battle: state,
              canAct: true,
              onCommand: (c) {
                onCommand(c);
                return true;
              }),
        ),
      ));
      return tester.state<BattleViewState>(find.byType(BattleView));
    }

    testWidgets(
        'Guardián con 13 opciones: categorías, todas sus técnicas sin '
        'paginar, teclas 1-9 dentro de la categoría', (tester) async {
      final skills = state.party.single.skillIds;
      // 8 + la Quebrar base del arma (combo_balance.md § 5.1): entra justo
      // en las 9 teclas.
      expect(skills, hasLength(9));
      BattleCommand? sent;
      final menu = await pump(tester, (c) => sent = c);
      expect(menu.hasSubmenu, isFalse);
      // Las pociones van juntas en OBJETOS: Habilidades entra sin "Más".
      menu.selectCategory(BattleCategory.skills);
      await tester.pump();
      for (final id in skills) {
        expect(find.byKey(ValueKey('battle-act-skill-$id')), findsOneWidget,
            reason: id);
      }
      expect(find.byKey(const ValueKey('battle-act-more')), findsNothing);
      expect(menu.menuPage, 0);
      // 7 = la séptima técnica de la lista.
      menu.handleKey(LogicalKeyboardKey.digit7);
      await tester.pump();
      expect((sent! as SkillCommand).skillId, skills[6]);
      // Después de actuar, el menú vuelve a ATACAR.
      expect(menu.category, BattleCategory.attack);
    });
  });
}
