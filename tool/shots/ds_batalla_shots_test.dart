// Capturas antes / después de la pantalla de batalla migrada al sistema de
// diseño (v0.12.0, docs/specs/design_system.md § 10.3). NO es parte de la
// suite. Correr con
//   $env:SHOT_SUFFIX="antes"; flutter test tool/shots/ds_batalla_shots_test.dart
// (en un worktree de main) o con "despues" en la rama.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/tutorial/presentation/tutorial_widgets.dart';
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
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.12.0';
final _suffix = Platform.environment['SHOT_SUFFIX'] ?? 'despues';

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img =
        await layer.toImage(const Offset(0, 0) & const Size(1920, 1080));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/${name}_$_suffix.png');
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
    _first((s) => s.instant && s.pulse == 0),
    _first((s) => s.kind == SkillKind.heal && s.lowestAlly && !s.instant),
    _first((s) => s.pulse >= 2 && !s.instant),
  }.toList();
  cur.mp = 6;
  cur.pulse = 1;
  return s;
}

Future<BattleViewState> _pump(
    WidgetTester tester, Widget Function(Widget) wrap, BattleState b) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadRealFonts(tester);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RetroTheme.build(),
    home: Scaffold(
      body: wrap(BattleView(
          battle: b,
          canAct: true,
          localId: b.currentId,
          onCommand: (_) => true)),
    ),
  ));
  await tester.pump();
  return tester.state<BattleViewState>(find.byType(BattleView));
}

void main() {
  testWidgets('batalla: comandos con HABILIDADES', (tester) async {
    final menu = await _pump(tester, (w) => w, _battle());
    menu.selectCategory(BattleCategory.skills);
    await tester.pump();
    await _shot(tester, '01_comandos');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('batalla: objetivo, tarjetas y desactivada', (tester) async {
    final menu = await _pump(tester, (w) => w, _battle());
    menu.selectCategory(BattleCategory.skills);
    await tester.pump();
    for (var i = 0; i < 1; i++) {
      menu.handleKey(LogicalKeyboardKey.arrowDown);
    }
    await tester.pump();
    await _shot(tester, '03_objetivo_tarjetas');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('batalla: tutorial con panel', (tester) async {
    await _pump(
        tester,
        (w) => TutorialOverlay(
              battle: w,
              banner: const TutorialBanner('TE TOCA: usar una habilidad',
                  yourTurn: true, stage: 'Etapa 5/10 · Afinidades'),
              card: const TutorialCard([
                'Golpe a la debilidad: DÉBIL ×1.5 (35 de daño).',
                'Las Instante no terminan tu turno.',
              ], arrow: TutorialArrow.pulse, effect: true),
              waitingText: 'Esperando: Beto',
              rules: const TutorialRules(),
              onNext: () {},
              onControl: (_) {},
            ),
        _battle());
    await _shot(tester, '02_tutorial');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
