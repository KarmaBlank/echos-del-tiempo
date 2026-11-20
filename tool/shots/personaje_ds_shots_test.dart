// Capturas antes / después del panel PERSONAJE migrado al sistema de
// diseño (v0.11.0, docs/specs/design_system.md). NO es parte de la suite.
// Correr con
//   $env:SHOT_SUFFIX="antes"; flutter test tool/shots/personaje_ds_shots_test.dart
// (en un worktree de main) o con "despues" en la rama.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';

const _out = 'docs/release_shots/v0.11.0';
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

void main() {
  const tabs = {
    CharacterTab.attributes: '01_atributos',
    CharacterTab.inventory: '02_inventario',
    CharacterTab.tree: '03_arbol',
    CharacterTab.filter: '04_filtro',
    CharacterTab.build: '05_build',
    CharacterTab.bestiary: '06_bestiario',
  };
  for (final e in tabs.entries) {
    testWidgets('personaje: ${e.value}', (tester) async {
      await pumpPanel(tester,
          devicePixelRatio: 1.5,
          profile: progression.normalize(
              PlayerProfile(name: 'Ana', classId: 'maga', level: 8, points: 3)),
          build: (v, c) =>
              CharacterPanel(view: v, controller: c, initialTab: e.key));
      await tester.pump();
      await _shot(tester, e.value);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
