import 'dart:io';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/layout/layout_doc.dart';
import 'package:echos_del_tiempo/core/layout/layout_validator.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_bar_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// v0.20.6 (battle_presentation.md § "Barra de abajo" y § "Textos
/// flotantes"; editor_layout.md § 6 fase 6 y § 2.8): la tarjeta propia a
/// la izquierda del menú en una sola fila, por datos, y los textos
/// flotantes siempre a la vista.

BattlePartyMember _member(String classId) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: classId,
    name: cls.name,
    potions: 2,
    ethers: 1,
    build: PlayerBuild(
      classId: classId,
      level: 6,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

BattleState _battle() {
  final engine = BattleEngine(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
    random: () => 0.99,
  );
  final start = engine.start(
    party: [_member('guerrero'), _member('maga'), _member('paladin')],
    enemyTypes: const ['slime', 'bat'],
    triggeredBy: 'guerrero',
  );
  return engine.nextTurn(start.state).state;
}

Future<BattleViewState> _pump(WidgetTester tester, Size size,
    {bool canAct = true, LayoutDoc? layout, TextSize? text}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final b = _battle();
  await tester.pumpWidget(MaterialApp(
    theme: RetroTheme.build(),
    builder: text == null
        ? null
        : (context, child) => RetroTextScale(factor: text.factor, child: child!),
    home: Scaffold(
      body: BattleView(
          battle: b,
          canAct: canAct,
          localId: b.currentId,
          layout: layout,
          onCommand: (_) => true),
    ),
  ));
  await tester.pump();
  return tester.state<BattleViewState>(find.byType(BattleView));
}

void main() {
  group('layout por datos', () {
    test('el YAML del repo reproduce el defecto del código', () {
      final doc = LayoutDoc.parse(
          File('assets/layouts/battle.layout.yaml').readAsStringSync());
      expect(doc.sameAs(BattleBarLayout.spec.defaults), isTrue);
      expect(
          LayoutValidator.validateStatic(doc, BattleBarLayout.spec)
              .where((i) => i.error),
          isEmpty);
      expect(File('assets/layouts/layout_manifest.yaml').readAsStringSync(),
          contains('battle: battle.layout.yaml'));
    });

    test('perillas: defecto, acotadas y de ida y vuelta por YAML', () {
      final s = BattleBarLayout.spec;
      expect(s.param(s.defaults, BattleBarLayout.cameraZoomOut), 0);
      expect(s.param(s.defaults, BattleBarLayout.floatTopMargin), 4);
      final d = s.defaults
          .withParam(BattleBarLayout.cameraZoomOut, 9)
          .withParam(BattleBarLayout.floatTopMargin, 10);
      expect(s.param(d, BattleBarLayout.cameraZoomOut), 3, reason: 'tope');
      final back = LayoutDoc.parse(d.encode());
      expect(back.sameAs(d), isTrue);
      expect(back.params[BattleBarLayout.floatTopMargin], 10);
      expect(d.withParam(BattleBarLayout.floatTopMargin, null).params,
          isNot(contains(BattleBarLayout.floatTopMargin)));
    });
  });

  testWidgets('tarjeta a la izquierda del menú, en la misma fila',
      (tester) async {
    await _pump(tester, const Size(1920, 1080));
    final card = tester.getRect(find.byKey(const ValueKey('battle-card')));
    final menu = tester.getRect(find.byKey(const ValueKey('battle-menu')));
    expect(card.right <= menu.left, isTrue);
    expect(card.top, closeTo(menu.top, 1));
    // Sin la fila aparte de la tarjeta: todo cabe en el alto de la barra.
    expect(card.bottom <= menu.bottom + 1, isTrue);
  });

  testWidgets('fuera del turno: tarjeta a la izquierda y el aviso',
      (tester) async {
    await _pump(tester, const Size(1280, 720), canAct: false);
    final card = tester.getRect(find.byKey(const ValueKey('battle-card')));
    final wait = tester.getRect(find.byKey(const ValueKey('battle-waiting')));
    expect(card.right <= wait.left, isTrue);
  });

  testWidgets('mover la tarjeta a la derecha por datos', (tester) async {
    final doc = BattleBarLayout.spec.defaults
        .move(BattleBarLayout.card, 'description', 1);
    await _pump(tester, const Size(1920, 1080), layout: doc);
    final card = tester.getRect(find.byKey(const ValueKey('battle-card')));
    final desc = tester.getRect(find.byKey(const ValueKey('battle-desc')));
    expect(card.top >= desc.bottom - 1, isTrue, reason: 'apilada debajo');
    expect(card.left, closeTo(desc.left, 1));
  });

  // Matriz: 5 tamaños × texto Normal / Grande / Enorme, sin desbordes.
  for (final size in const [
    Size(1280, 720),
    Size(1920, 1080),
    Size(2560, 1440),
    Size(800, 600),
    Size(600, 900),
  ]) {
    for (final text in const [
      TextSize.normal,
      TextSize.huge,
      TextSize.enormous
    ]) {
      testWidgets('sin desbordes ${size.width.toInt()}x${size.height.toInt()}'
          ' ${text.name}', (tester) async {
        // Solo los desbordes de la barra de abajo (la barra del objetivo,
        // arriba en la escena, es de otro componente).
        final errs = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) {
          final s = d.toString();
          if (!s.contains('TargetBar')) errs.add(s);
        };
        addTearDown(() => FlutterError.onError = prev);
        final s = await _pump(tester, size, text: text);
        for (final c in BattleCategory.values) {
          s.selectCategory(c);
          await tester.pump();
        }
        FlutterError.onError = prev;
        expect(errs, isEmpty);
        final card = tester.getRect(find.byKey(const ValueKey('battle-card')));
        final menu = tester.getRect(find.byKey(const ValueKey('battle-menu')));
        // A la izquierda o, angosto (< 60 tx), arriba de la fila.
        expect(card.right <= menu.left || card.bottom <= menu.top, isTrue);
        expect(menu.right <= size.width + 0.5, isTrue);
        expect(menu.bottom <= size.height + 0.5, isTrue);
      });
    }
  }

  group('textos flotantes', () {
    test('acotar: entra arriba, si no baja y se apila', () {
      expect(BattleScenePainter.clampFloatY(100, 20, 50, 0, 22), 100);
      expect(BattleScenePainter.clampFloatY(30, 20, 50, 0, 22), 70);
      expect(BattleScenePainter.clampFloatY(30, 20, 50, 2, 22), 114);
    });

    for (final size in const [Size(1280, 720), Size(800, 600)]) {
      testWidgets(
          'objetivo en el borde de arriba: todo dentro de la pantalla '
          '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
        final s = await _pump(tester, size);
        final f = s.scene.frame!;
        final e = f.battle.enemies.first;
        final box = f.layout.boxOf(e.id);
        // Mucho más arriba del borde de la escena.
        final y = box.top - 1000;
        s.scene.addEffects([
          BattleFx(FxKind.num, x: box.center.dx, y: y, text: '128', big: true),
          BattleFx(FxKind.num, x: box.center.dx, y: y, text: '64'),
          BattleFx(FxKind.num,
              x: box.center.dx, y: y, text: '999', heavy: true, big: true),
          BattleFx(FxKind.txt, x: box.center.dx, y: y, text: 'COMBUSTIÓN'),
          BattleFx(FxKind.tag,
              x: box.center.dx, y: y, text: 'CONVERGENCIA', who: e.id),
        ]);
        s.scene.advance(150);
        await tester.pump();
        final rects = BattleScenePainter.debugFloatRects;
        expect(rects.length, 5);
        final top = f.geometry.worldRect.top;
        final screen = Offset.zero & size;
        for (final r in rects) {
          expect(r.top >= top, isTrue, reason: '$r sobre la escena');
          expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight),
              isTrue,
              reason: '$r dentro de $screen');
        }
        // Los números acotados no se pisan: se apilan hacia abajo.
        final nums = rects.take(3).toList()
          ..sort((a, b) => a.top.compareTo(b.top));
        for (var i = 1; i < nums.length; i++) {
          expect(nums[i].top >= nums[i - 1].bottom - 0.5, isTrue);
        }
      });
    }
  });
}
