import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/app/theme/retro_text.dart';
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

import '../core/settings/fake_window_mode.dart';

class _MuteSfx implements SfxPlayer {
  @override
  Future<void> play(Uint8List wav, {double volume = 1}) async {}
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Regresión v0.19.1: los "?" de AJUSTES usan el `Tooltip` estándar y
/// salían como una franja negra vacía (texto negro de Material sobre la
/// caja oscura del tema).
void main() {
  for (final tab in SettingsTab.values) {
    testWidgets('tooltips "?" legibles en la pausa — ${tab.label}',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
          theme: RetroTheme.build(),
          home: Scaffold(
              body: SettingsMenu(
                  onClose: () {}, inGame: true, initialTab: tab)),
        ),
      ));
      await tester.pumpAndSettle();

      final tips = find.byWidgetPredicate((w) =>
          w is RetroTooltip &&
          (w.key is ValueKey<String>) &&
          (w.key! as ValueKey<String>).value.startsWith('setting-hint-'));
      final n = tips.evaluate().length;
      if (tab == SettingsTab.game) expect(n, greaterThanOrEqualTo(4));

      const bg = ProtoColors.bg;
      RetroHoverCard.keyboardNav = false;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      for (var i = 0; i < n; i++) {
        final tip = tester.widget<RetroTooltip>(tips.at(i));
        await tester.ensureVisible(tips.at(i));
        await tester.pumpAndSettle();
        await mouse.moveTo(tester.getCenter(tips.at(i)));
        await tester.pumpAndSettle();

        final text = find.textContaining(retroText(tip.message), findRichText: true);
        expect(text, findsOneWidget, reason: tip.message);
        final para = tester.renderObject<RenderParagraph>(text).text;
        final cs = <Color>[if (para.style?.color != null) para.style!.color!];
        tester.renderObject<RenderParagraph>(text).text.visitChildren((s) {
          final c = s.style?.color;
          if (c != null) cs.add(c);
          return true;
        });
        final p = tester.renderObject<RenderParagraph>(text);
        expect(p.text.toPlainText().trim(), isNotEmpty);
        final color = cs.first;
        expect(_contrast(color, bg), greaterThan(4.5),
            reason: 'texto $color sobre $bg');
        expect(color, ProtoColors.ink);
        final r = tester.getRect(text);
        expect(r.left >= 0 && r.top >= 0 && r.right <= 1280 && r.bottom <= 720,
            isTrue,
            reason: '$r');

        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
    });
  }
}
