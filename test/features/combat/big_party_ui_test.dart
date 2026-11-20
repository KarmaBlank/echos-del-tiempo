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
        testWidgets('${w.toInt()}×${h.toInt()} ${t.name}: $n jugadores',
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
                  onCommand: (_) => true),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
          for (final p in b.party) {
            final key = p.id == b.currentId ? 'my-panel-${p.id}' : 'member-${p.id}';
            final r = tester.getRect(find.byKey(ValueKey(key)));
            expect(r.bottom, lessThanOrEqualTo(h + 0.5), reason: key);
            expect(r.right, lessThanOrEqualTo(w + 0.5), reason: key);
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
