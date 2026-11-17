import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/audio/presentation/audio_settings_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('SONIDO abre el panel: sliders, silenciar y cerrar',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: RetroTheme.build(),
        home: const Scaffold(body: Center(child: AudioSettingsButton())),
      ),
    ));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

    await tester.tap(find.byKey(const ValueKey('audio-settings')));
    await tester.pumpAndSettle();
    expect(find.text('SONIDO'), findsWidgets);
    expect(find.text('60%'), findsOneWidget); // música por defecto
    expect(find.text('80%'), findsOneWidget); // efectos por defecto

    // Arrastrar el slider de música al mínimo.
    await tester.drag(
        find.byKey(const ValueKey('audio-music')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(container.read(audioSettingsProvider).musicVolume, 0);
    expect(container.read(musicServiceProvider).volume, 0);

    await tester.tap(find.byKey(const ValueKey('audio-mute')));
    await tester.pumpAndSettle();
    expect(container.read(audioSettingsProvider).muted, isTrue);
    expect(find.text('ACTIVAR SONIDO'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('audio-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('audio-mute')), findsNothing);
  });
}
