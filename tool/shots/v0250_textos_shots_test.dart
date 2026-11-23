// Capturas de TEXTOS RESUMIDO vs DETALLADO (v0.25.0,
// docs/release_shots/v0.25.0). NO es parte de la suite: vive fuera de
// test/. Correr con
//   flutter test tool/shots/v0250_textos_shots_test.dart
//
// Todo con stores en memoria (no toca %APPDATA%).
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_hover_card.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/theme/text_detail_scope.dart';
import 'package:echos_del_tiempo/core/audio/audio_settings.dart';
import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:echos_del_tiempo/core/audio/presentation/audio_providers.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/item_hover_tip.dart';
import 'package:echos_del_tiempo/features/inventory/presentation/skill_chip.dart';
import 'package:echos_del_tiempo/features/settings/presentation/settings_menu.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/core/settings/fake_window_mode.dart';
import '../../test/features/panel_test_harness.dart';
import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.25.0';

class _NoSfx implements SfxPlayer {
  @override
  Future<void> play(Uint8List wav, {double volume = 1}) async {}
}

String _tag(TextDetail m) => m == TextDetail.summary ? 'resumido' : 'detallado';

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final size = tester.view.physicalSize;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & size);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final m = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await m.addPointer(location: Offset.zero);
  addTearDown(m.removePointer);
  return m;
}

Widget _app(TextDetail mode, Widget body) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: RetroTheme.build(),
      home: Scaffold(body: TextDetailScope(mode: mode, child: body)),
    );

void main() {
  tearDown(() => TextDetail.current = TextDetail.full);

  for (final mode in TextDetail.values) {
    testWidgets('habilidad y arma ${_tag(mode)}', (tester) async {
      TextDetail.current = mode;
      await loadRealFonts(tester);
      tester.view.physicalSize = const Size(1200, 690);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      final sk = prototypeCatalog.skills.values.firstWhere((s) =>
          s.kind == SkillKind.magical && s.status != null && s.charge == 0);
      final viewer = progression.normalize(newProfile('Ana', 'guerrero'));
      final item = progression.equippedItem(viewer)!;
      final stats = progression.derivedStats(viewer);
      await tester.pumpWidget(_app(
          mode,
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkillChip(skill: sk, stats: stats),
              const SizedBox(width: 330),
              itemHoverTip(
                rules: progression,
                viewer: viewer,
                item: item,
                attributes: viewer.attributes,
                child: Container(
                    key: const ValueKey('weapon'),
                    width: 48,
                    height: 48,
                    color: RetroTheme.build().colorScheme.surface),
              ),
            ]),
          )));
      final m = await _mouse(tester);
      await m.moveTo(
          tester.getCenter(find.byKey(ValueKey('skill-chip-${sk.id}'))));
      await tester.pumpAndSettle();
      await _shot(tester, '01_habilidad_${_tag(mode)}.png');
      if (mode == TextDetail.summary) {
        // Alt despliega MÁS DETALLE (y los demás plegables).
        RetroHoverCard.altHeld.value = true;
        await tester.pumpAndSettle();
        await _shot(tester, '01_habilidad_resumido_mas_detalle.png');
        RetroHoverCard.altHeld.value = false;
        await tester.pumpAndSettle();
      }
      await m.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await m.moveTo(tester.getCenter(find.byKey(const ValueKey('weapon'))));
      await tester.pumpAndSettle();
      await _shot(tester, '02_arma_${_tag(mode)}.png');
      if (mode == TextDetail.summary) {
        // Clic fija la ficha; después se abre MÁS DETALLE.
        await m.down(tester.getCenter(find.byKey(const ValueKey('weapon'))));
        await m.up();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('tip-fold-MÁS DETALLE')));
        await tester.pumpAndSettle();
        await _shot(tester, '02_arma_resumido_mas_detalle.png');
      }
    });

    testWidgets('ULT ${_tag(mode)}', (tester) async {
      TextDetail.current = mode;
      await pumpPanel(tester,
          profile: newProfile('Ana', 'guerrero'),
          build: (v, c) => CharacterPanel(view: v, controller: c));
      final tab = CharacterTab.values.indexOf(CharacterTab.ults);
      await tester.tap(find.byKey(ValueKey('tab-$tab')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _shot(tester, '03_ult_${_tag(mode)}.png');
    });

    testWidgets('ajustes ${_tag(mode)}', (tester) async {
      await loadRealFonts(tester);
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final window = FakeWindowMode();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          audioSettingsProvider.overrideWith((ref) => AudioSettingsController(
              store: InMemoryAudioSettingsStore(),
              music: MusicService(autoTick: false),
              sfx: SfxService(player: _NoSfx()))),
          windowModeProvider.overrideWithValue(window),
          gameSettingsProvider.overrideWith((ref) => GameSettingsController(
              store: InMemoryGameSettingsStore(),
              window: window,
              initial: GameSettings(textDetail: mode))),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: RetroTheme.build(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  key: const ValueKey('open'),
                  onPressed: () => showSettingsDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('a11y-textdetail-RESUMIDO'));
      await tester.scrollUntilVisible(row, 200,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await _shot(tester, '04_ajustes_${_tag(mode)}.png');
    });
  }
}
