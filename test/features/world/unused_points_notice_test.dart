import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/widgets/points_badge.dart';
import 'package:echos_del_tiempo/features/characters/domain/unused_points.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/unused_points_notice.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

// Aviso de puntos sin usar (docs/specs/passive_tree_v4.md § 7).

Widget _app(Widget child) => MaterialApp(
    theme: RetroTheme.build(), home: Scaffold(body: Center(child: child)));

UnusedPointsToast _toast(UnusedPoints p,
        {int level = 5, int asc = 0, bool blocked = false}) =>
    UnusedPointsToast(
        points: p, treeLevel: level, ascensionEarned: asc, blocked: blocked);

void main() {
  group('UnusedPoints', () {
    test('cuenta atributos, árbol (con Maestría) y ascensión', () {
      final p = progression.normalize(PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        level: 6,
        tree: const ['gue_r1'],
        ascension: const AscensionProgress(trials: {1}),
      ));
      final u = UnusedPoints.of(p, progression);
      final attr = p.points;
      expect(attr, greaterThan(0));
      // 2 puntos de árbol por nivel (v0.8): 5 × 2 − 1.
      expect(u, UnusedPoints(attributes: attr, tree: 9, ascension: 2));
      expect(u.total, attr + 11);
      expect(u.parts, [
        '$attr puntos de atributos',
        '9 puntos de árbol',
        '2 puntos de ascensión',
      ]);
      expect(
          UnusedPoints.of(newProfile('Leo', 'maga'), progression).any, isFalse);
    });

    test('texto del aviso', () {
      expect(const UnusedPoints(tree: 2).toastText,
          'Tenés 2 puntos de árbol sin usar · [C]');
      expect(const UnusedPoints(tree: 1).toastText,
          'Tenés 1 punto de árbol sin usar · [C]');
      expect(const UnusedPoints(ascension: 2).toastText,
          'Tenés 2 puntos de ascensión sin usar · Estatua del Tiempo');
      expect(
          const UnusedPoints(tree: 1, ascension: 2).toastText,
          'Tenés 1 punto de árbol y 2 puntos de ascensión sin usar · [C] · '
          'ascensión: Estatua del Tiempo');
      expect(UnusedPoints.none.toastText, isNull);
    });

    test('v0.8.3: cuenta a los compañeros (solo_party.md § 6.3)', () {
      final u = const UnusedPoints(tree: 2)
          .withCompanions([('Leo', 3), ('Mia', 0)]);
      expect(u.total, 5);
      expect(u.own, 2);
      expect(u.companionTotal, 3);
      expect(u.companions, [('Leo', 3)], reason: 'Mia no tiene puntos');
      expect(u.parts, ['2 puntos de árbol', 'Leo: 3 puntos']);
      expect(u.toastText,
          'Tenés 2 puntos de árbol sin usar · Leo tiene 3 puntos sin usar · [C]');
      expect(UnusedPoints.none.withCompanions([('Leo', 1)]).toastText,
          'Leo tiene 1 punto sin usar · [C]');
      expect(UnusedPoints.none.withCompanions([('Leo', 1)]).any, isTrue);
      expect(u, const UnusedPoints(tree: 2).withCompanions([('Leo', 3)]));
      expect(u == const UnusedPoints(tree: 2), isFalse);
    });
  });

  group('insignia del HUD', () {
    testWidgets('sin puntos no se muestra; con puntos, +N que late',
        (tester) async {
      await tester.pumpWidget(_app(
          UnusedPointsButton(points: UnusedPoints.none, onPressed: () {})));
      expect(find.byKey(const ValueKey('hud-points-button')), findsNothing);

      var taps = 0;
      await tester.pumpWidget(_app(UnusedPointsButton(
          points: const UnusedPoints(attributes: 2, tree: 3),
          onPressed: () => taps++)));
      expect(find.byKey(const ValueKey('hud-points-button')), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.byKey(const ValueKey('points-badge-pulse')), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.tap(find.byKey(const ValueKey('hud-points-button')));
      expect(taps, 1);
    });

    testWidgets('Reducir movimiento: quieta (sin animación) y resaltada',
        (tester) async {
      await tester.pumpWidget(_app(UnusedPointsButton(
          points: const UnusedPoints(tree: 1),
          reduceMotion: true,
          onPressed: () {})));
      expect(find.text('+1'), findsOneWidget);
      expect(find.byKey(const ValueKey('points-badge-static')), findsOneWidget);
      expect(find.byKey(const ValueKey('points-badge-pulse')), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      // Borde más grueso en vez del latido.
      final box = tester.widget<Container>(find.descendant(
          of: find.byType(PointsBadge), matching: find.byType(Container)));
      expect((box.decoration! as BoxDecoration).border!.top.width, 2);
    });
  });

  group('aviso al subir de nivel', () {
    testWidgets('una vez por subida, 6 s, solo si quedan puntos',
        (tester) async {
      await tester.pumpWidget(_app(_toast(const UnusedPoints(tree: 1))));
      // Al cargar no avisa (ya los veía en la insignia).
      expect(find.byKey(const ValueKey('hud-points-toast')), findsNothing);

      await tester
          .pumpWidget(_app(_toast(const UnusedPoints(tree: 2), level: 6)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.text('Tenés 2 puntos de árbol sin usar · [C]'), findsOneWidget);
      await tester.pump(UnusedPointsToast.shown);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('hud-points-toast')), findsNothing);

      // Otra subida pero ya sin puntos: nada.
      await tester.pumpWidget(_app(_toast(UnusedPoints.none, level: 7)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('hud-points-toast')), findsNothing);
    });

    testWidgets('v0.8.3: avisa cuando un compañero gana puntos',
        (tester) async {
      await tester.pumpWidget(_app(_toast(UnusedPoints.none)));
      await tester.pumpWidget(_app(
          _toast(UnusedPoints.none.withCompanions([('Leo', 3)]))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leo tiene 3 puntos sin usar · [C]'), findsOneWidget);
    });

    testWidgets('espera a que termine el reparto (bloqueado)', (tester) async {
      await tester.pumpWidget(_app(_toast(const UnusedPoints(tree: 1))));
      await tester.pumpWidget(_app(_toast(
          const UnusedPoints(attributes: 3, tree: 2),
          level: 6,
          blocked: true)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('hud-points-toast')), findsNothing);
      await tester
          .pumpWidget(_app(_toast(const UnusedPoints(tree: 2), level: 6)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.text('Tenés 2 puntos de árbol sin usar · [C]'), findsOneWidget);
      await tester.pump(UnusedPointsToast.shown);
    });

    testWidgets('ganar puntos de ascensión también avisa', (tester) async {
      await tester.pumpWidget(_app(_toast(UnusedPoints.none)));
      await tester
          .pumpWidget(_app(_toast(const UnusedPoints(ascension: 2), asc: 2)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('2 puntos de ascensión'), findsOneWidget);
      await tester.pump(UnusedPointsToast.shown);
    });
  });

  group('en el juego', () {
    testWidgets('HUD: PERSONAJE [C] +N abre el panel; pestañas con +N',
        (tester) async {
      // Nivel 6 sin repartir: 10 de árbol (2 por nivel desde la v0.8; y
      // los de atributos del nivel).
      final c = await pumpPanel(tester,
          profile: progression.normalize(
              PlayerProfile(name: 'Ana', classId: 'guerrero', level: 6)),
          build: (v, c) => Stack(children: [
                WorldHud(view: v, controller: c),
                if (v.panel != null) CharacterPanel(view: v, controller: c),
              ]));
      final me = c.view!.me!.profile;
      final u = UnusedPoints.of(me, c.engine.progression);
      expect(u.tree, 10);
      expect(find.byKey(const ValueKey('hud-points-button')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('hud-points-badge')),
              matching: find.text('+${u.total}')),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('hud-points-button')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CharacterPanel), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(ValueKey('tab-badge-${CharacterTab.tree.index}')),
              matching: find.text('+10')),
          findsOneWidget);
      if (me.points > 0) {
        expect(
            find.byKey(ValueKey('tab-badge-${CharacterTab.attributes.index}')),
            findsOneWidget);
      }
    });

    testWidgets('sin puntos: ni botón ni insignias', (tester) async {
      await pumpPanel(tester,
          profile: newProfile('Leo', 'maga'),
          build: (v, c) => WorldHud(view: v, controller: c));
      expect(find.byKey(const ValueKey('hud-points-button')), findsNothing);
      expect(find.byType(PointsBadge), findsNothing);
    });
  });
}
