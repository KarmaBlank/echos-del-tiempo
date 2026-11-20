import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_labels.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'big_party_ui_test.dart' show bigMember;

/// [n] jugadores contra 4 enemigos (por el motor real).
BattleState _battle(int n) {
  final engine = BattleEngine(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
    random: () => 0.99,
  );
  final start = engine.start(
    party: [for (var i = 0; i < n; i++) bigMember(i)],
    enemyTypes: const ['slime', 'bat', 'golem', 'slime'],
    triggeredBy: 'j0',
  );
  return engine.nextTurn(start.state).state;
}

const _names = ['Guerrero', 'Maga', 'Tirador', 'Paladín'];

/// 4 contra 4, con estados en todos (etiquetas anchas).
BattleState _fourVsFour({bool boss = false}) => BattleState(
      party: [
        for (var i = 0; i < 4; i++)
          Combatant(
            id: 'p$i',
            name: _names[i],
            isPlayer: true,
            hp: 50,
            maxHp: 50,
            speed: 10,
            attack: 10,
            critChance: 0,
            statuses: {StatusKind.burn: 2, StatusKind.regen: 1},
          ),
      ],
      enemies: [
        for (var i = 0; i < 4; i++)
          Combatant(
            id: 'e$i',
            name: 'Gólem',
            isPlayer: false,
            hp: 120,
            maxHp: 120,
            speed: 7,
            attack: 7,
            critChance: 0,
            boss: boss && i == 0,
            elite: i == 3,
            enemyType: 'golem',
            statuses: {StatusKind.poison: 3, StatusKind.freeze: 1},
          ),
      ],
    );

/// PressStart2P es monoespaciada: cada letra mide lo que el tamaño.
double _measure(String s, double size) => s.length * size;

void main() {
  for (final arena in <String, BattleArena?>{
    'sin mapa': null,
    'en el mapa': const BattleArena(
        anchorX: 300, anchorY: 200, side: 1, worldWidth: 960, worldHeight: 640),
    'en el borde del mapa': const BattleArena(
        anchorX: 40, anchorY: 30, side: 1, worldWidth: 400, worldHeight: 300),
  }.entries) {
    for (final size in const [Size(1280, 446), Size(1920, 780), Size(960, 400)]) {
      test('4 contra 4 ${arena.key} en $size: la pelea llena el área del mundo '
          'y entra entera', () {
        final s = _fourVsFour(boss: true);
        final g = SceneGeometry.fit(size);
        final layout = BattleLayout.compute(s, arena.value,
            vw: g.virtualWidth,
            enemySize: (e) => e.boss
                ? const Size(36, 32)
                : e.elite
                    ? const Size(23, 20)
                    : const Size(16, 14));
        final view = layout.frame(g, arena.value);
        expect(view.zoom, view.zoom.roundToDouble()); // entero: nítido
        final vp = SceneViewport(g.worldRect, view);
        for (final id in layout.boxes.keys) {
          final r = vp.rectToScreen(layout.boxOf(id));
          expect(g.worldRect.inflate(0.5).contains(r.topLeft), isTrue,
              reason: '$id $r fuera de ${g.worldRect}');
          expect(g.worldRect.inflate(0.5).contains(r.bottomRight), isTrue,
              reason: '$id $r fuera de ${g.worldRect}');
        }
        // La pelea ocupa buena parte del área (no chiquita en el medio).
        final fight = vp.rectToScreen(layout.fightBox);
        final fill = (fight.width / g.worldRect.width) >
                (fight.height / g.worldRect.height)
            ? fight.width / g.worldRect.width
            : fight.height / g.worldRect.height;
        expect(fill, greaterThan(0.55), reason: '$fight en ${g.worldRect}');
        if (size == const Size(1280, 446)) expect(view.zoom, 3);
      });
    }
  }

  test('las etiquetas de un 4 contra 4 no se superponen y quedan en el área',
      () {
    for (final size in const [Size(1280, 446), Size(1920, 780)]) {
      final s = _fourVsFour();
      final g = SceneGeometry.fit(size);
      final layout = BattleLayout.compute(s, null, vw: g.virtualWidth);
      final f = SceneFrame(battle: s, geometry: g, layout: layout);
      final vp = SceneViewport(g.worldRect, layout.frame(g, null));
      final rects = BattleScenePainter.labelRects(f, vp, measure: _measure);
      expect(rects, hasLength(8));
      final list = rects.entries.toList();
      for (var i = 0; i < list.length; i++) {
        expect(g.worldRect.contains(list[i].value.topLeft), isTrue);
        expect(g.worldRect.contains(list[i].value.bottomRight), isTrue);
        for (var j = i + 1; j < list.length; j++) {
          expect(list[i].value.overlaps(list[j].value), isFalse,
              reason: '${list[i].key} ${list[i].value} y '
                  '${list[j].key} ${list[j].value}');
        }
      }
    }
  });

  group('franja adaptable', () {
    double zoomOf(BattleState s, SceneGeometry g) =>
        BattleLayout.compute(s, null, vw: g.virtualWidth).frame(g, null).zoom;

    test('nunca baja el zoom respecto de la franja chica', () {
      final s = _fourVsFour(boss: true);
      for (final size in const [
        Size(1280, 300), Size(1280, 330), Size(1280, 446), Size(1920, 780),
        Size(960, 400),
      ]) {
        final small = SceneGeometry.fit(size, strip: SceneGeometry.stripSmall);
        final g = SceneGeometry.adaptive(size, zoomOf: (g) => zoomOf(s, g));
        expect(zoomOf(s, g), zoomOf(s, small), reason: '$size');
        expect(g.strip, inInclusiveRange(54, 74));
        expect(g.bigIcon, inInclusiveRange(28, 46));
      }
    });

    test('1920×780: franja grande, mismo zoom que antes', () {
      final s = _fourVsFour(boss: true);
      const size = Size(1920, 780);
      final g = SceneGeometry.adaptive(size, zoomOf: (g) => zoomOf(s, g));
      expect(g.strip, SceneGeometry.stripHeight);
      expect((g.bigIcon, g.smallIcon), (46, 40));
      expect(zoomOf(s, g), zoomOf(s, SceneGeometry.fit(size)));
    });

    test('con la franja chica: íconos 28 / 22 y log en [38, 54)', () {
      final g = SceneGeometry.fit(const Size(1280, 400), strip: 54);
      expect((g.bigIcon, g.smallIcon, g.iconBand, g.logTop), (28, 22, 32, 38));
    });

    Future<BattleViewState> pumpBattle(WidgetTester tester, Size size, int n,
        {required bool solo, double text = 1}) async {
      await loadRealFonts(tester);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final b = _battle(n);
      expect(b.enemies.length, 4);
      await tester.pumpWidget(MaterialApp(
        theme: RetroTheme.build(),
        builder: (context, child) => RetroTextScale(factor: text, child: child!),
        home: Scaffold(
          body: BattleView(
              battle: b,
              canAct: true,
              localId: b.currentId,
              turnTimeLeft: 20,
              companions: solo
                  ? {for (final p in b.party) if (p.id != b.currentId) p.id}
                  : const {},
              onCommand: (_) => true),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      return tester.state<BattleViewState>(find.byType(BattleView));
    }

    double zoomIn(BattleViewState v) {
      final f = v.scene.frame!;
      return f.layout.frame(f.geometry, null).zoom;
    }

    for (final (name, solo, text) in [
      ('soloParty', true, 1.0),
      ('texto Grande', false, TextSize.large.factor),
      ('soloParty y texto Grande', true, TextSize.large.factor),
    ]) {
      testWidgets('4 contra 4 en 1280×720 con $name: arena ×3', (tester) async {
        final v = await pumpBattle(tester, const Size(1280, 720), 4,
            solo: solo, text: text);
        expect(zoomIn(v), 3);
        final f = v.scene.frame!;
        final small = SceneGeometry.fit(f.geometry.size,
            textFactor: f.geometry.textFactor, strip: SceneGeometry.stripSmall);
        expect(zoomIn(v), f.layout.frame(small, null).zoom);
      });
    }

    testWidgets('1920×1080: franja grande', (tester) async {
      final v = await pumpBattle(tester, const Size(1920, 1080), 4, solo: true);
      final g = v.scene.frame!.geometry;
      expect(g.strip, SceneGeometry.stripHeight);
      expect(zoomIn(v), v.scene.frame!.layout
          .frame(SceneGeometry.fit(g.size, textFactor: g.textFactor), null)
          .zoom);
    });

    testWidgets('8 jugadores, grupo compacto en 1280×720', (tester) async {
      final v = await pumpBattle(tester, const Size(1280, 720), 8, solo: false);
      expect(find.byKey(const ValueKey('ally-list')), findsOneWidget);
      final g = v.scene.frame!.geometry;
      expect(g.strip, inInclusiveRange(54, 74));
    });
  });

  test('placeLabels corre las que chocan y respeta los bordes', () {
    final r = placeLabels(const [
      LabelRequest('a', Offset(100, 50), Size(60, 10)),
      LabelRequest('b', Offset(110, 52), Size(60, 10)),
      LabelRequest('c', Offset(5, 8), Size(40, 10)),
    ], const Rect.fromLTWH(0, 0, 300, 200));
    expect(r['a']!.overlaps(r['b']!), isFalse);
    expect(r['c']!.left, greaterThanOrEqualTo(0));
    expect(r['c']!.top, greaterThanOrEqualTo(0));
  });
}
