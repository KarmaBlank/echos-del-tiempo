import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/bestiary/domain/bestiary_text.dart';
import 'package:echos_del_tiempo/features/bestiary/presentation/bestiary_view.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/bestiary.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

BattlePartyMember _member(String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: classId,
    name: cls.name,
    build: PlayerBuild(
      classId: classId,
      level: 1,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

Finder _text(String s) => find.textContaining(s, findRichText: true);

void main() {
  late BattleState state;

  setUp(() {
    final engine = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99,
    );
    final start = engine.start(
      party: [_member('guerrero')],
      enemyTypes: const ['slime', 'esqueleto'],
      triggeredBy: 'guerrero',
    );
    state = engine.nextTurn(start.state).state;
  });

  Future<GlobalKey<BattleViewState>> pumpBattle(
      WidgetTester tester, BestiaryProgress best,
      {bool canAct = false}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<BattleViewState>();
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(
            key: key,
            battle: state,
            canAct: canAct,
            localId: 'guerrero',
            bestiary: best,
            enemyLevel: 3,
            onCommand: (_) => true),
      ),
    ));
    await tester.pump();
    return key;
  }

  /// Pasa el mouse sobre el enemigo [id] de la escena.
  Future<TestGesture> hover(
      WidgetTester tester, GlobalKey<BattleViewState> key, String id) async {
    final f = key.currentState!.scene.frame!;
    final vp = SceneViewport(f.geometry.worldRect, key.currentState!.scene.viewFor(f));
    final at = vp.toScreen(f.layout.of(id) + const Offset(0, -5));
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(at);
    await tester.pump();
    return g;
  }

  group('ficha al pasar el mouse', () {
    testWidgets('sin matarlo: ??? y cómo agregarlo', (tester) async {
      final key = await pumpBattle(tester, BestiaryProgress.empty);
      await hover(tester, key, 'e1');
      expect(key.currentState!.hoveredEnemy, 'e1');
      expect(find.byKey(const ValueKey('enemy-info-unknown')), findsOneWidget);
      expect(_text('???'), findsOneWidget);
      expect(_text(kBestiaryUnknownHint), findsOneWidget);
      expect(_text('No muerto'), findsNothing);
    });

    testWidgets('conocido: familia, debilidades con motivo, nivel y muertes',
        (tester) async {
      final key =
          await pumpBattle(tester, BestiaryProgress({'esqueleto': 4}));
      await hover(tester, key, 'e1');
      expect(find.byKey(const ValueKey('enemy-info-known')), findsOneWidget);
      expect(_text('Esqueleto'), findsWidgets);
      expect(_text('[NM] No muerto'), findsOneWidget);
      expect(_text('las curas le hacen daño (100% de la cura)'), findsOneWidget);
      expect(_text('Sagrado ×1.5'), findsOneWidget);
      expect(_text('Inmune:'), findsOneWidget);
      expect(_text('Nv 3'), findsOneWidget);
      expect(_text('Derrotados: 4'), findsOneWidget);
    });

    testWidgets('fuera del enemigo la ficha se va', (tester) async {
      final key =
          await pumpBattle(tester, BestiaryProgress({'esqueleto': 1}));
      final g = await hover(tester, key, 'e1');
      expect(find.byKey(const ValueKey('enemy-info-known')), findsOneWidget);
      await g.moveTo(const Offset(640, 710)); // la barra de abajo
      await tester.pump();
      expect(key.currentState!.hoveredEnemy, isNull);
      expect(find.byKey(const ValueKey('enemy-info-known')), findsNothing);
    });

    test('markup de jefe: mecánica, sin textos de ambientación', () {
      final m = enemyInfoMarkup(kEnemies['caballeroHueco']!,
          BestiaryProgress({'caballeroHueco': 1}),
          description: true);
      expect(m, contains('Postura'));
      expect(m, contains('No muerto'));
      // Ni título del jefe ni descripción (pendientes del dueño).
      expect(m, isNot(contains('Juramento sin alma')));
    });
  });

  group('pestaña BESTIARIO', () {
    Future<void> pumpView(WidgetTester tester, BestiaryProgress b) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(body: BestiaryView(bestiary: b)),
      ));
      await tester.pump();
    }

    testWidgets('grilla por zona: descubiertos, siluetas y detalle',
        (tester) async {
      await pumpView(tester, BestiaryProgress({'slime': 5, 'lobo': 1}));
      final total = bestiaryEntries().length;
      expect(_text('Descubiertos 2/$total'), findsOneWidget);
      expect(_text('Zona 1 · Pradera Esmeralda'), findsOneWidget);
      // Elige la primera conocida.
      expect(find.byKey(const ValueKey('bestiary-detail-slime')), findsOneWidget);
      expect(_text('Derrotados: 5'), findsOneWidget);
      expect(_text('Fuego ×1.5'), findsOneWidget);
      expect(_text('Masa viva'), findsNothing, reason: 'sin ambientación');
      // Una desconocida: ??? en la tarjeta y en el detalle.
      await tester.tap(find.byKey(const ValueKey('bestiary-card-bat')));
      await tester.pump();
      expect(find.byKey(const ValueKey('bestiary-detail-bat')), findsOneWidget);
      expect(_text(kBestiaryUnknownHint), findsOneWidget);
      expect(_text('Murciélago'), findsNothing);
    });

    testWidgets('filtro por familia y búsqueda solo ven lo descubierto',
        (tester) async {
      await pumpView(tester, BestiaryProgress({'slime': 1, 'lobo': 1, 'bat': 2}));
      await tester.tap(find.byKey(const ValueKey('bestiary-filter-beast')));
      await tester.pump();
      expect(find.byKey(const ValueKey('bestiary-card-lobo')), findsOneWidget);
      expect(find.byKey(const ValueKey('bestiary-card-bat')), findsOneWidget);
      expect(find.byKey(const ValueKey('bestiary-card-slime')), findsNothing);
      // La bestia que falta (Murciélago de Hielo) no aparece.
      expect(find.byKey(const ValueKey('bestiary-card-murcielagoHielo')),
          findsNothing);
      await tester.tap(find.byKey(const ValueKey('bestiary-filter-all')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const ValueKey('bestiary-search')), 'lob');
      await tester.pump();
      expect(find.byKey(const ValueKey('bestiary-card-lobo')), findsOneWidget);
      expect(find.byKey(const ValueKey('bestiary-card-bat')), findsNothing);
    });

    testWidgets('teclado: flechas mueven la ficha elegida', (tester) async {
      await pumpView(tester, BestiaryProgress({'slime': 1, 'bat': 1}));
      await tester.tap(find.byKey(const ValueKey('bestiary-card-slime')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.byKey(const ValueKey('bestiary-detail-bat')), findsOneWidget);
    });

    testWidgets('pestaña del panel de personaje', (tester) async {
      await pumpPanel(tester,
          profile: newProfile('Ana', 'guerrero'),
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.bestiary));
      expect(find.byKey(const ValueKey('bestiary-view')), findsOneWidget);
      expect(_text('BESTIARIO'), findsWidgets);
      expect(_text('Descubiertos 0/'), findsOneWidget);
    });
  });
}
