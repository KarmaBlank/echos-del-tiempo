import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/vision_palette.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Contraste WCAG 2.x entre dos colores opacos.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

/// Accesibilidad § 1 (docs/specs/accessibility.md): todo color de texto
/// llega a AA (4.5:1) sobre los fondos donde va texto.
void main() {
  const text = {
    'ink': ProtoColors.ink,
    'gold': ProtoColors.gold,
    'sky': ProtoColors.sky,
    'dim': ProtoColors.dim,
    'chat': ProtoColors.chat,
    'green': ProtoColors.green,
    'ice': ProtoColors.ice,
    'red': ProtoColors.red,
    'crimson': ProtoColors.crimson,
    'orange': ProtoColors.orange,
    'amber': ProtoColors.amber,
    'pink': ProtoColors.pink,
    'violet': ProtoColors.violet,
    'cream': ProtoColors.cream,
    'holy': ProtoColors.holy,
    'mint': ProtoColors.mint,
    'burn': ProtoColors.burn,
    'taunt': ProtoColors.taunt,
    'white': ProtoColors.white,
  };
  const backgrounds = {
    'bg': ProtoColors.bg,
    'panel': ProtoColors.panel,
    'input': ProtoColors.input,
    'button': ProtoColors.button,
  };

  // Con cada modo daltónico (accessibility.md § 3): los tokens con
  // significado cambian de color y siguen en AA.
  tearDown(() => VisionPalette.mode = ColorVision.off);
  for (final mode in ColorVision.values) {
    test('texto AA (≥ 4.5:1) sobre fondo, panel, campo y botón · ${mode.name}',
        () {
      VisionPalette.mode = mode;
      for (final t in text.entries) {
        for (final b in backgrounds.entries) {
          expect(contrast(t.value, b.value), greaterThanOrEqualTo(4.5),
              reason: '${t.key} sobre ${b.key} (${mode.name})');
        }
      }
    });

    test('rarezas AA (≥ 4.5:1) sobre fondo, panel y campo · ${mode.name}',
        () {
      VisionPalette.mode = mode;
      // Épico del prototipo (#be6eff) no llega sobre botón: las rarezas
      // van sobre fichas y paneles, no sobre botones.
      for (final s in const [
        VisionSlot.magic,
        VisionSlot.rare,
        VisionSlot.epic,
        VisionSlot.legendary,
      ]) {
        for (final b in const [
          ProtoColors.bg,
          ProtoColors.panel,
          ProtoColors.input,
        ]) {
          expect(contrast(VisionColor(s), b), greaterThanOrEqualTo(4.5),
              reason: '${s.name} (${mode.name})');
        }
      }
    });
  }

  test('el markup con los hex viejos del prototipo usa el token AA', () {
    expect(ProtoColors.parse('#7d8bc4'), ProtoColors.dim);
    expect(ProtoColors.parse('#ff4757'), ProtoColors.crimson);
    expect(ProtoColors.parse('#e84393'), ProtoColors.pink);
    expect(ProtoColors.parse('#9fb4ff'), ProtoColors.sky);
    expect(ProtoColors.parse('#ffd166'), ProtoColors.gold);
    expect(ProtoColors.parse('#ffeaa7'), const Color(0xFFFFEAA7));
  });
}
