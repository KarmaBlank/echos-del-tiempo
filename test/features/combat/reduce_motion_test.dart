import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/ascension/presentation/ascension_cinematic.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/arena/arena_transition.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'battle_screen_test.dart' show member;

/// Cuenta lo que se dibuja (rectángulos, caminos y su color).
class _CountCanvas implements Canvas {
  final rects = <(Rect, Color)>[];
  int paths = 0;

  @override
  void drawRect(Rect rect, Paint paint) => rects.add((rect, paint.color));

  @override
  void drawPath(Path path, Paint paint) => paths++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// REDUCIR MOVIMIENTO (docs/specs/accessibility.md § 4) y las barras de
/// los enemigos sin color (§ 3).
void main() {
  group('entrada a la arena', () {
    const area = Rect.fromLTWH(0, 0, 1280, 720);

    test('normal: destello blanco y bloques', () {
      final c = _CountCanvas();
      ArenaWipe.paintEnter(c, area, 10, 2, 1);
      expect(c.paths, 1, reason: 'los bloques');
      expect(c.rects, hasLength(1), reason: 'el destello');
      expect(c.rects.single.$2.r, 1.0);
    });

    test('reducir movimiento: solo un fundido corto, sin destello ni bloques',
        () {
      final c = _CountCanvas();
      ArenaWipe.paintEnter(c, area, 10, 2, 1, fade: true);
      expect(c.paths, 0);
      expect(c.rects, hasLength(1));
      expect(c.rects.single.$1, area);
      expect(c.rects.single.$2.r, lessThan(0.1), reason: 'negro, no blanco');
      final after = _CountCanvas();
      ArenaWipe.paintEnter(after, area, ArenaWipe.fadeMs + 1, 2, 1,
          fade: true);
      expect(after.rects, isEmpty);
      expect(ArenaWipe.fadeMs, lessThan(ArenaWipe.ms));
    });

    testWidgets('salida de la batalla: fundido de ${ArenaWipe.fadeMs} ms',
        (tester) async {
      Future<void> pump(bool inBattle) => tester.pumpWidget(
          MaterialApp(home: BattleExitWipe(inBattle: inBattle, fade: true)));
      await pump(true);
      await pump(false);
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pump(Duration(milliseconds: ArenaWipe.fadeMs.round() + 20));
      expect(
          find.descendant(
              of: find.byType(BattleExitWipe), matching: find.byType(CustomPaint)),
          findsNothing,
          reason: 'terminó antes que el barrido de bloques');
    });
  });

  group('escena', () {
    test('sin sacudida: la cámara no tiembla', () {
      final s = BattleSceneController()
        ..options = const SceneOptions(shake: false, reduceMotion: true);
      s.particles.addShake(10);
      s.advance(16);
      expect(s.particles.shakeOffset(), Offset.zero);
    });

    testWidgets('ascensión: sin destello ni temblor con REDUCIR MOVIMIENTO',
        (tester) async {
      Future<int> whiteRects(double flash, bool reduce) async {
        tester.view.physicalSize = const Size(640, 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: RetroTheme.build(),
          home: AscensionCinematic(
              key: UniqueKey(),
              playerName: 'Ana',
              classId: 'maga',
              ascensionId: 'cronomante',
              at: AscensionCinematicTiming.revealMs + 40,
              flash: flash,
              reduceMotion: reduce),
        ));
        final paint = tester.widget<CustomPaint>(
            find.byKey(const ValueKey('asc-cinematic')));
        final c = _CountCanvas();
        paint.painter!.paint(c, const Size(640, 360));
        return c.rects
            .where((r) =>
                r.$1 == const Rect.fromLTWH(0, 0, 640, 360) &&
                r.$2.r == 1 &&
                r.$2.g == 1 &&
                r.$2.b == 1 &&
                r.$2.a > 0)
            .length;
      }

      expect(await whiteRects(1, false), 1);
      expect(await whiteRects(0, true), 0);
    });
  });

  group('barras de los enemigos sin color', () {
    test('la de quiebre lleva cortes y un rombo (la vida es lisa)', () {
      final c = _CountCanvas();
      BattleScenePainter.breakStripes(c, 0, 0, 48, 2);
      // Un corte cada 3·u.
      expect(c.rects.length, greaterThanOrEqualTo(7));
      final d = _CountCanvas();
      BattleScenePainter.breakDiamond(d, 10, 10, 2, Colors.yellow);
      expect(d.rects, hasLength(4));
    });
  });

  group('barra del grupo', () {
    final engine = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99,
    );

    for (final (n, w) in [(1, 1920.0), (4, 1920.0), (2, 1280.0)]) {
      testWidgets('$n en el grupo a $w px: cada tarjeta mide 1/4', (tester) async {
        tester.view.physicalSize = Size(w, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final classes = ['guerrero', 'maga', 'tirador', 'paladin'].take(n);
        final st = engine
            .start(
                party: [for (final c in classes) member(c)],
                enemyTypes: const ['slime'],
                triggeredBy: 'guerrero')
            .state;
        if (st.party.length > 1) st.party[1].statuses = {StatusKind.poison: 2};
        await tester.pumpWidget(MaterialApp(
          theme: RetroTheme.build(),
          builder: (context, child) =>
              RetroTextScale(factor: TextSize.normal.factor, child: child!),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                width: w,
                child: BattlePartyBar(battle: st, localId: 'guerrero'),
              ),
            ),
          ),
        ));
        const gaps = (BattlePartyBar.slotCount - 1) * BattlePartyBar.gap;
        final quarter = (w - gaps) / BattlePartyBar.slotCount;
        final card = tester.getRect(find.byKey(const ValueKey('my-panel-guerrero')));
        expect(card.width, closeTo(quarter, 0.5));
        expect(card.left, 0, reason: 'desde la izquierda');
        for (final p in st.party.skip(1)) {
          final r = tester.getRect(find.byKey(ValueKey('member-${p.id}')));
          expect(r.width, closeTo(quarter, 0.5));
          // Una fila: mismo arriba y mismo alto (sin escalera).
          expect(r.top, card.top, reason: p.id);
          expect(r.height, card.height, reason: p.id);
        }
        // Entera en la pantalla.
        expect(card.bottom, lessThanOrEqualTo(300));
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('sin imports sin usar', () => expect(ui.Offset.zero, Offset.zero));
}
