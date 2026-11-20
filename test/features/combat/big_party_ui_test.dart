import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';

/// Batalla con grupos de cualquier tamaño (v0.13, battle_presentation.md
/// § "Grupos grandes"): escena, tarjetas y menú sin desbordar.

const _classes = ['guerrero', 'maga', 'tirador', 'paladin'];

BattlePartyMember bigMember(int i) {
  final classId = _classes[i % _classes.length];
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: 'j$i',
    name: '${cls.name} ${i + 1}',
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

BattleState bigBattle(int n) {
  final engine = BattleEngine(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
    random: () => 0.99,
  );
  final start = engine.start(
    party: [for (var i = 0; i < n; i++) bigMember(i)],
    enemyTypes: const ['slime', 'bat', 'golem'],
    triggeredBy: 'j0',
  );
  return engine.nextTurn(start.state).state;
}

void main() {
  const sizes = [1, 2, 4, 6, 8, 12];

  group('formación del grupo', () {
    for (final n in sizes) {
      test('$n: cajas sin superponerse', () {
        final b = bigBattle(n);
        final l = BattleLayout.compute(b, null);
        final boxes = [for (final p in b.party) l.boxes[p.id]!];
        for (var i = 0; i < boxes.length; i++) {
          for (var k = i + 1; k < boxes.length; k++) {
            expect(boxes[i].intersect(boxes[k]).isEmpty ||
                    boxes[i].intersect(boxes[k]).width <= 0 ||
                    boxes[i].intersect(boxes[k]).height <= 0,
                isTrue,
                reason: '$n: ${b.party[i].id} pisa a ${b.party[k].id}');
          }
        }
      });
    }
  });

  test('barra del grupo: 1 fila hasta 4, 2 filas después', () {
    expect(BattlePartyBar.gridFor(1), (1, 4));
    expect(BattlePartyBar.gridFor(4), (1, 4));
    expect(BattlePartyBar.gridFor(6), (2, 4));
    expect(BattlePartyBar.gridFor(8), (2, 4));
    expect(BattlePartyBar.gridFor(12), (2, 6));
  });

  for (final (w, h) in const [(1280.0, 720.0), (1920.0, 1080.0)]) {
    for (final t in TextSize.values) {
      for (final n in sizes) {
        for (final solo in [false, true]) {
          final mode = solo ? 'soloParty' : 'compacto';
          testWidgets('${w.toInt()}×${h.toInt()} ${t.name}: $n jugadores, $mode',
              (tester) async {
            await loadRealFonts(tester);
            tester.view.physicalSize = Size(w, h);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final b = bigBattle(n);
            await tester.pumpWidget(MaterialApp(
              theme: RetroTheme.build(),
              builder: (context, child) =>
                  RetroTextScale(factor: t.factor, child: child!),
              home: Scaffold(
                body: BattleView(
                    battle: b,
                    canAct: true,
                    localId: b.currentId,
                    turnTimeLeft: 20,
                    // soloParty: los demás son compañeros propios.
                    companions: solo
                        ? {for (final p in b.party) if (p.id != b.currentId) p.id}
                        : const {},
                    onCommand: (_) => true),
              ),
            ));
            await tester.pump();
            expect(tester.takeException(), isNull);
            void inside(String key) {
              final r = tester.getRect(find.byKey(ValueKey(key)));
              expect(r.bottom, lessThanOrEqualTo(h + 0.5), reason: key);
              expect(r.right, lessThanOrEqualTo(w + 0.5), reason: key);
            }
            inside('my-panel-${b.currentId}');
            for (final p in b.party) {
              if (p.id == b.currentId) continue;
              if (solo) {
                inside('member-${p.id}');
                expect(find.byKey(ValueKey('ally-row-${p.id}')), findsNothing);
              } else {
                // Grupo compacto: abajo solo la propia; el resto, en la
                // lista de la derecha de la arena.
                expect(find.byKey(ValueKey('member-${p.id}')), findsNothing);
                inside('ally-row-${p.id}');
                final r =
                    tester.getRect(find.byKey(ValueKey('ally-row-${p.id}')));
                final bar = tester.getRect(find.byKey(const ValueKey('party-bar')));
                expect(r.bottom, lessThanOrEqualTo(bar.top), reason: p.id);
              }
            }
            final bv = tester.state<BattleViewState>(find.byType(BattleView));
            for (final c in BattleCategory.values) {
              bv.selectCategory(c);
              await tester.pump();
              expect(tester.takeException(), isNull, reason: c.name);
            }
          });
        }
      }
    }
  }

  testWidgets('grupo compacto: el mouse en una fila señala al aliado',
      (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final b = bigBattle(8);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(
            battle: b,
            canAct: true,
            localId: b.currentId,
            onCommand: (_) => true),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('ally-list')), findsOneWidget);
    expect(find.byKey(ValueKey('my-panel-${b.currentId}')), findsOneWidget);
    final other = b.party.firstWhere((p) => p.id != b.currentId).id;
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    await g.moveTo(
        tester.getCenter(find.byKey(ValueKey('ally-row-$other'))));
    await tester.pump();
    final v = tester.state<BattleViewState>(find.byType(BattleView));
    expect(v.hoveredId, other);
    expect(v.scene.frame!.hoverId, other);
    // Y al revés: el mouse sobre el aliado en la arena resalta su fila.
    final f = v.scene.frame!;
    final vp = SceneViewport(f.geometry.worldRect, v.scene.viewFor(f));
    final third = b.party[2].id;
    await g.moveTo(vp.toScreen(f.layout.boxOf(third).center));
    await tester.pump();
    expect(v.hoveredId, third);
    final row = tester.widget<Container>(find.descendant(
        of: find.byKey(ValueKey('ally-row-$third')),
        matching: find.byType(Container)).first);
    final border = (row.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, ProtoColors.white);
    await g.removePointer();
  });
}
