// Capturas de la vista previa de ULT (release). Solo corre con la
// variable ULT_SHOTS=<carpeta>:
//   $env:ULT_SHOTS = "docs\release_shots\v0.19.1"; flutter test test/features/characters/ult_preview_screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/fx/fx_catalog.dart';
import 'package:echos_del_tiempo/features/characters/presentation/ult_preview_panel.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_bridge.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_preview_scene.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

final _out = Platform.environment['ULT_SHOTS'];

void main() {
  testWidgets('capturas de la vista previa de ULT', (tester) async {
    UltPreviewPanel.autoplayOverride = true;
    addTearDown(() => UltPreviewPanel.autoplayOverride = null);
    addTearDown(() => FxCatalog.active = null);
    final sprites = await tester.runAsync(() async {
      await installFx();
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      return GameSprites.load(cat);
    });
    final key = GlobalKey();
    await pumpPanel(tester,
        profile: newProfile('Ana', 'guerrero'),
        sprites: sprites,
        build: (v, c) => RepaintBoundary(
            key: key, child: CharacterPanel(view: v, controller: c)));
    final tab = CharacterTab.values.indexOf(CharacterTab.ults);
    await tester.tap(find.byKey(ValueKey('tab-$tab')));
    await tester.pump();
    final picks = [
      kUltV2List.firstWhere((u) =>
          u.skill.allTargets && u.skill.kind == SkillKind.magical),
      kUltV2List.firstWhere((u) => u.skill.kind == SkillKind.heal),
      kUltV2List.firstWhere((u) =>
          !u.skill.allTargets &&
          u.skill.kind == SkillKind.physical &&
          u.skill.status != null),
    ];
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    var n = 0;
    for (final u in picks) {
      // Solo el clic elige la ULT de la vista previa (el hover no).
      final row = find.byKey(ValueKey('ult-row-${u.id}'));
      await tester.ensureVisible(row);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(row));
      await tester.tap(row);
      await tester.pump();
      // Hasta un poco después del primer impacto.
      final hit = ultPreviewImpact(ultPreviewTimeline(u.id)) + 260;
      for (var ms = 0; ms < hit; ms += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      n++;
      final out = _out;
      if (out == null) continue;
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(out).createSync(recursive: true);
        File('$out/0${n}_ult_preview_${u.id}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    expect(n, 3);
  });
}
