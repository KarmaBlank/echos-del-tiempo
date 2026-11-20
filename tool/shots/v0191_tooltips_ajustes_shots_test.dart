// Captura del fix de tooltips "?" en AJUSTES (v0.19.1). La de "antes"
// (Tooltip de Material con el tema sin `textStyle`: franja negra vacía)
// se sacó con el código de v0.19.0. NO es parte de la suite:
//   flutter test tool/shots/v0191_tooltips_ajustes_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/audio/audio_settings.dart';
import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:echos_del_tiempo/core/audio/presentation/audio_providers.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/settings/presentation/settings_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/core/settings/fake_window_mode.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.19.1';

class _MuteSfx implements SfxPlayer {
  @override
  Future<void> play(Uint8List wav, {double volume = 1}) async {}
}

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img =
        await layer.toImage(const Offset(0, 0) & const Size(1280, 720));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _run(WidgetTester tester, ThemeData theme, String name) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadRealFonts(tester);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      audioSettingsProvider.overrideWith((ref) => AudioSettingsController(
          store: InMemoryAudioSettingsStore(),
          music: MusicService(autoTick: false),
          sfx: SfxService(player: _MuteSfx()))),
      windowModeProvider.overrideWithValue(FakeWindowMode()),
      gameSettingsProvider.overrideWith((ref) => GameSettingsController(
          store: InMemoryGameSettingsStore(),
          window: ref.watch(windowModeProvider))),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
          body: SettingsMenu(
              onClose: () {}, inGame: true, initialTab: SettingsTab.game)),
    ),
  ));
  await tester.pumpAndSettle();
  final tip = find.byWidgetPredicate((w) =>
      w is RetroTooltip &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('setting-hint-'));
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(tip.first));
  await tester.pumpAndSettle();
  await _shot(tester, name);
  await mouse.removePointer();
}

void main() {
  testWidgets('despues', (tester) async {
    await _run(tester, RetroTheme.build(), 'tooltip_ajustes_despues');
  });
}
