import 'package:echos_del_tiempo/app/theme/pixel_label.dart';
import 'package:echos_del_tiempo/app/theme/proto_markup.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'dart:io';

/// Tamaño de las etiquetas (docs/specs/accessibility.md § 1 "Ventanas
/// grandes", ui_style.md § "Etiquetas en el mundo" y "Sin pesos").
void main() {
  group('ventana', () {
    test('la UI crece con la ventana (de a 0.25, hasta ×2)', () {
      expect(RetroTextScale.windowFactor(const Size(1280, 720)), 1);
      expect(RetroTextScale.windowFactor(const Size(1000, 600)), 1);
      expect(RetroTextScale.windowFactor(const Size(1600, 900)), 1.25);
      expect(RetroTextScale.windowFactor(const Size(1920, 1080)), 1.5);
      expect(RetroTextScale.windowFactor(const Size(2560, 1440)), 2);
      expect(RetroTextScale.windowFactor(const Size(3840, 2160)), 2);
      // Las dos direcciones: una ventana ancha y baja no agranda.
      expect(RetroTextScale.windowFactor(const Size(1920, 720)), 1);
    });

    testWidgets('VT323 a 30 px a 1920×1080 Normal', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late double body, label;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) =>
            RetroTextScale(factor: TextSize.normal.factor, child: child!),
        home: Builder(builder: (context) {
          body = MediaQuery.textScalerOf(context).scale(RetroType.small);
          label = MediaQuery.textScalerOf(context).scale(RetroType.label);
          return const SizedBox();
        }),
      ));
      expect(body, 30);
      expect(label, 16);
    });
  });

  group('escena de batalla', () {
    test('las etiquetas crecen con el zoom de la escena y con el texto', () {
      // 1280×720 Normal: 16 px; 1920×1080 (texto ×1.5 por la ventana): 24.
      final small = SceneGeometry.fit(const Size(1280, 470));
      final big = SceneGeometry.fit(const Size(1920, 705), textFactor: 1.5);
      expect(small.labelUnit, 2);
      expect(big.labelUnit, 3);
      expect(8 * big.labelUnit, greaterThan(8 * small.labelUnit));
      // GRANDE / MUY GRANDE a 1280×720.
      expect(
          SceneGeometry.fit(const Size(1280, 470), textFactor: 1.25).labelUnit,
          3);
      expect(SceneGeometry.fit(const Size(1280, 470), textFactor: 1.5).labelUnit,
          3);
      // Una escena enorme nunca queda por debajo de la de las tarjetas.
      final huge = SceneGeometry.fit(const Size(3840, 1400));
      expect(huge.labelUnit, greaterThanOrEqualTo(huge.hudUnit));
    });
  });

  group('mapa', () {
    test('las etiquetas van a px de pantalla en la grilla de 8', () {
      // 1280×720: el lienzo de 480 px a ×2.67 → 16 px (no 6 × 2.67).
      expect(PixelLabelPen.screenSize(6, 1280 / 480), 16);
      expect(PixelLabelPen.screenSize(7, 1280 / 480), 16);
      expect(PixelLabelPen.screenSize(8, 1280 / 480), 32);
      expect(PixelLabelPen.screenSize(6, 1.5), 8);
      for (final k in [1.0, 1.5, 2.67, 4.0]) {
        expect(PixelLabelPen.screenSize(6, k) % 8, 0);
      }
    });
  });

  group('sin pesos (las fuentes pixel no tienen negrita)', () {
    bool heavy(TextStyle? s) =>
        s?.fontWeight != null && s!.fontWeight!.value > 400;

    test('el tema no pide negrita', () {
      final t = RetroTheme.build();
      final tt = t.textTheme;
      for (final s in [
        tt.displayLarge, tt.displayMedium, tt.displaySmall, //
        tt.headlineLarge, tt.headlineMedium, tt.headlineSmall,
        tt.titleLarge, tt.titleMedium, tt.titleSmall,
        tt.bodyLarge, tt.bodyMedium, tt.bodySmall,
        tt.labelLarge, tt.labelMedium, tt.labelSmall,
      ]) {
        expect(heavy(s), isFalse, reason: '$s');
      }
      final btn = t.elevatedButtonTheme.style?.textStyle?.resolve({});
      expect(heavy(btn), isFalse);
    });

    test('`<b>` del markup resalta con color, sin peso', () {
      void walk(InlineSpan s) {
        if (s is TextSpan) {
          expect(heavy(s.style), isFalse, reason: s.toPlainText());
          for (final c in s.children ?? const <InlineSpan>[]) {
            walk(c);
          }
        }
      }

      final span = protoSpan('<b>Hola</b> <b style="color:#ff6b81">rojo</b>');
      walk(span);
      final b = (span.children!.first as TextSpan);
      expect(b.style?.color, isNotNull, reason: 'el resaltado es el color');
    });

    test('las etiquetas del mundo usan peso normal', () {
      final tp = PixelLabelPen().layout('Karmona', const Color(0xFFFFFFFF), 16);
      expect(heavy((tp.text! as TextSpan).style), isFalse);
    });

    test('una negrita que se escape usa la misma fuente regular', () {
      final pub = File('pubspec.yaml').readAsStringSync();
      for (final f in ['PressStart2P-Regular.ttf', 'VT323-Regular.ttf']) {
        expect(RegExp('asset: assets/fonts/$f\\s+weight: 700').hasMatch(pub),
            isTrue,
            reason: f);
      }
    });
  });
}
