// Capturas del menú ARMA (v0.20.0, docs/specs/battle_attack_menu.md § 6).
// NO es parte de la suite. Correr con
//   flutter test tool/shots/v0200_menu_arma_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.20.0';

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img =
        await layer.toImage(const Offset(0, 0) & const Size(1920, 1080));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

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

String _first(bool Function(SkillDef) f) => kSkills.values.firstWhere(f).id;

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
  final s = engine.nextTurn(start.state).state;
  final cur = s.current!;
  cur.skillIds = <String>{
    _first((s) => s.kind == SkillKind.physical && !s.allTargets && !s.instant),
    _first((s) => s.kind == SkillKind.magical && s.allTargets && !s.instant),
    ...kSkills.values.where((s) => s.instant && s.pulse == 0).take(2).map((s) => s.id),
    _first((s) => s.kind == SkillKind.heal && s.lowestAlly && !s.instant),
  }.toList();
  cur.mp = 6;
  cur.pulse = 1;
  return s;
}

Future<BattleViewState> _pump(WidgetTester tester, BattleState b) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadRealFonts(tester);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
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
  return tester.state<BattleViewState>(find.byType(BattleView));
}

void main() {
  for (final (i, name) in const [
    (0, '01_arma_atacar'),
    (1, '02_arma_defender'),
    (2, '03_arma_instante'),
  ]) {
    testWidgets('ARMA: $name', (tester) async {
      final menu = await _pump(tester, _battle());
      for (var k = 0; k < i; k++) {
        menu.handleKey(LogicalKeyboardKey.arrowDown);
      }
      await tester.pump();
      await _shot(tester, name);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets('HABILIDADES sin Instante', (tester) async {
    final menu = await _pump(tester, _battle());
    menu.selectCategory(BattleCategory.skills);
    await tester.pump();
    await _shot(tester, '04_habilidades');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
