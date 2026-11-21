// Capturas antes / después de v0.20.6 (battle_presentation.md § "Textos
// flotantes" y § "Barra de abajo"): la tarjeta propia a la izquierda del
// menú y los textos flotantes que nunca se van por arriba. NO es parte de
// la suite. Correr con
//   $env:SHOT_SUFFIX="antes"; flutter test tool/shots/v0206_batalla_shots_test.dart
// (en main) o con "despues" en la rama.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/enemy_live_info.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/real_fonts.dart';

final _out = Platform.environment['SHOT_DIR'] ??
    'docs/release_shots/v0.20.6/batalla';
final _suffix = Platform.environment['SHOT_SUFFIX'] ?? 'despues';

Future<void> _shot(WidgetTester tester, String name, Size size) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & size);
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

Future<BattleViewState> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadRealFonts(tester);
  final b = _battle();
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
  for (final (name, size) in const [
    ('01_barra_1920x1080', Size(1920, 1080)),
    ('02_barra_1280x720', Size(1280, 720)),
  ]) {
    testWidgets('batalla: $name', (tester) async {
      final s = await _pump(tester, size);
      s.selectCategory(BattleCategory.skills);
      await tester.pump();
      await _shot(tester, name, size);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets('batalla: ARMA con una Instante bajo el foco', (tester) async {
    const size = Size(1280, 720);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadRealFonts(tester);
    final b = _battle();
    b.current!.skillIds = [
      kSkills.values.firstWhere((s) => s.instant && s.pulse == 0).id,
    ];
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
    final s = tester.state<BattleViewState>(find.byType(BattleView));
    s.selectCategory(BattleCategory.weapon);
    s.handleKey(LogicalKeyboardKey.arrowDown);
    s.handleKey(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await _shot(tester, '05_arma_instante', size);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('batalla: tooltip del enemigo con estados', (tester) async {
    const size = Size(900, 500);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadRealFonts(tester);
    final e = _battle().enemies.first
      ..statuses[StatusKind.burn] = 2
      ..statuses[StatusKind.poison] = 1
      ..statuses[StatusKind.holy] = 3;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RetroTheme.build(),
      home: Scaffold(
        body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final open in [false, true])
            Container(
              width: 420,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF151A33),
              child: EnemyLiveInfo(enemy: e, open: open),
            ),
        ]),
      ),
    ));
    await tester.pump();
    await _shot(tester, '04_tooltip_estados', size);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('batalla: flotantes con el objetivo arriba', (tester) async {
    const size = Size(1280, 720);
    final s = await _pump(tester, size);
    final f = s.scene.frame!;
    final e = f.battle.enemies.first;
    final box = f.layout.boxOf(e.id);
    // Muy arriba del objetivo: el caso que antes se perdía detrás del
    // borde de la escena.
    final y = box.top - 400;
    s.scene.addEffects([
      BattleFx(FxKind.num, x: box.center.dx, y: y, text: '128', big: true),
      BattleFx(FxKind.num,
          x: box.center.dx + 6, y: y, text: '64', color: const Color(0xFFFF6B81)),
      BattleFx(FxKind.txt, x: box.center.dx, y: y, text: 'COMBUSTIÓN'),
      BattleFx(FxKind.tag,
          x: box.center.dx, y: y, text: 'CONVERGENCIA', who: e.id),
    ]);
    s.scene.advance(120);
    await tester.pump();
    await _shot(tester, '03_flotantes_arriba', size);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
