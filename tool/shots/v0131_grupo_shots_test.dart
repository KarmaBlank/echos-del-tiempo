// Capturas antes / después de la batalla con 8 jugadores sin compañeros
// propios (v0.13.1, docs/specs/battle_presentation.md § "Grupo
// compacto") a 1920×1080. NO es parte de la suite. Correr con
//   $env:SHOT_SUFFIX="antes"; flutter test tool/shots/v0131_grupo_shots_test.dart
// (con lib/ de la rama base) o con "despues" en la rama.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
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
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.13.1';
final _suffix = Platform.environment['SHOT_SUFFIX'] ?? 'despues';
const _classes = ['guerrero', 'maga', 'tirador', 'paladin'];

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

BattlePartyMember _member(int i) {
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

void main() {
  for (final size in const [Size(1920, 1080), Size(1280, 720)]) {
    testWidgets('8 jugadores ${size.width.toInt()}', (tester) async {
      tester.view.physicalSize = size;
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
        party: [for (var i = 0; i < 8; i++) _member(i)],
        enemyTypes: const ['lobo', 'lobo', 'golem'],
        elite: true,
        triggeredBy: 'j0',
      );
      final b = engine.nextTurn(start.state).state;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: RetroTheme.build(),
        home: Scaffold(
          body: BattleView(
              battle: b,
              sprites: sprites,
              canAct: b.currentId == 'j0',
              localId: 'j0',
              onCommand: (_) => true),
        ),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await _shot(tester, 'batalla_grupo_${size.width.toInt()}', size);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
