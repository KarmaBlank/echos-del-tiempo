// Capturas del arreglo de tamaño de HAZAÑAS (v0.19.1): pestaña HAZAÑAS
// frente a BESTIARIO y el toast, en 1280×720, 1920×1080 y 2560×1440, con
// y sin títulos con fuente de lectura. NO es parte de la suite. Correr con
//   flutter test tool/shots/v0191_hazanas_tamano_shots_test.dart
// (SHOT_TAG=antes|despues elige el prefijo de los archivos).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/achievements/presentation/achievement_feed.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/features/achievements/presentation/achievements_view.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';

const _out = 'docs/release_shots/v0.19.1';
final _tag = Platform.environment['SHOT_TAG'] ?? 'despues';

Future<void> _shot(WidgetTester tester, String name, double dpr) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img =
        await layer.toImage(Offset.zero & (const Size(1280, 720) * dpr));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/${_tag}_$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

/// Ventana real de 1280×720 × [k] a dpr 1 (como el juego en Windows):
/// ahí entra el factor de ventana del texto.
Future<void> _window(WidgetTester tester, double k) async {
  tester.view.physicalSize = const Size(1280, 720) * k;
  await tester.pumpAndSettle();
}

PlayerProfile _profile() => progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'maga',
      level: 14,
      achievements: AchievementProgress(done: {
        'forge_first': 1763000000,
        'fuse_first': 1763100000,
        'fuse_skill': 1763100500,
        'combat_break': 1763300000,
      }, counters: {
        'forgeLevels': 7,
        'fusions': 3,
      }),
    ));

void main() {
  for (final dpr in [1.0, 1.5, 2.0]) {
    for (final rt in [true, false]) {
      final res = '${(1280 * dpr).round()}';
      final t = rt ? 'titlect' : 'titpix';
      for (final tab in [CharacterTab.achievements, CharacterTab.bestiary]) {
        testWidgets('${tab.name} $res $t', (tester) async {
          await pumpPanel(tester,
              devicePixelRatio: 1,
              readingTitles: rt,
              textSize: TextSize.normal,
              profile: _profile(),
              build: (v, c) =>
                  CharacterPanel(view: v, controller: c, initialTab: tab));
          await _window(tester, dpr);
          await _shot(tester, '${tab.name}_${res}_$t', dpr);
        }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
      }
      testWidgets('toast $res $t', (tester) async {
        await pumpPanel(tester,
            devicePixelRatio: 1,
            readingTitles: rt,
              textSize: TextSize.normal,
            profile: _profile(),
            build: (v, c) => Stack(children: [
                  Positioned.fill(
                      child: CharacterPanel(
                          view: v,
                          controller: c,
                          initialTab: CharacterTab.inventory)),
                  Positioned(
                      top: 56,
                      right: 12,
                      child: AchievementToasts(feed: _feed())),
                ]));
        await _window(tester, dpr);
        await tester.pump(const Duration(milliseconds: 500));
        await _shot(tester, 'toast_${res}_$t', dpr);
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
      testWidgets('pantalla del titulo $res $t', (tester) async {
        await pumpPanel(tester,
            devicePixelRatio: 1,
            readingTitles: rt,
            textSize: TextSize.normal,
            profile: _profile(),
            build: (v, c) => PanelFrame(
                title: 'HAZAÑAS',
                width: 1000,
                fill: true,
                help: AchievementsView.help,
                onClose: () {},
                child: AchievementsView(
                    progress: _profile().achievements)));
        await _window(tester, dpr);
        await _shot(tester, 'pantalla_${res}_$t', dpr);
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    }
  }
}

/// Tres hazañas seguidas (se apilan) y una cuarta en espera.
AchievementFeed _feed() {
  final f = AchievementFeed(clock: () => 1)..durationFactor = double.infinity;
  for (final id in ['fuse_skill', 'salvage_50', 'forge_first', 'sell_first']) {
    f.push(id);
  }
  return f;
}
