// Capturas antes / después de la línea de tiempo con repetidos (dos lobos
// y un lobo élite; v0.13.1, docs/specs/battle_presentation.md
// § "Identificador de repetidos") a 1920×1080. NO es parte de la suite.
// Correr con
//   $env:SHOT_SUFFIX="antes"; flutter test tool/shots/v0131_timeline_shots_test.dart
// (con lib/ de main) o con "despues" en la rama.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
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
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.13.1';
final _suffix = Platform.environment['SHOT_SUFFIX'] ?? 'despues';

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & const Size(1920, 1080));
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

void main() {
  testWidgets('línea de tiempo: dos lobos y un élite', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadRealFonts(tester);
    late GameSprites sprites;
    await tester.runAsync(() async {
      sprites = await GameSprites.load(await SpriteCatalog.load());
    });
    final engine = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.5,
    );
    final start = engine.start(
      party: [_member('guerrero'), _member('maga')],
      enemyTypes: const ['lobo', 'lobo', 'lobo'],
      elite: true,
      triggeredBy: 'guerrero',
    );
    final b = engine.nextTurn(start.state).state;
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RetroTheme.build(),
      home: Scaffold(
        body: BattleView(
            battle: b,
            sprites: sprites,
            canAct: true,
            localId: b.currentId,
            onCommand: (_) => true),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _shot(tester, '01_linea_de_tiempo');
    // Mouse sobre el tercer ícono de la franja.
    final v = tester.state<BattleViewState>(find.byType(BattleView));
    final fr = v.scene.frame!;
    final s = fr.geometry.scale;
    final slot = BattleScenePainter.timelineSlots(
        fr.battle, fr.geometry.virtualWidth.toDouble())[2];
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    await g.moveTo(slot.rect.center * s);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _shot(tester, '02_mouse_en_la_linea');
    await g.removePointer();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
