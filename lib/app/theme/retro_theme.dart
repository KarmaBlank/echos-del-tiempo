import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';
import 'retro_type.dart';
import 'ui_theme.dart';

export 'retro_type.dart';

/// Constantes de conveniencia para el chrome neutro, con los valores del
/// prototipo (docs/specs/ui_style.md § "Paleta"). No es una regla: donde
/// el prototipo usa otro color se usa [ProtoColors].
abstract final class RetroPalette {
  static const night = ProtoColors.bg;
  static const panel = ProtoColors.panel;
  static const panelDark = ProtoColors.input;
  static const ink = ProtoColors.ink;
  static const muted = ProtoColors.dim;
  static const gold = ProtoColors.gold;
  static const red = ProtoColors.red;
  static const green = ProtoColors.green;
}

/// Tema global pixel art con los estilos del prototipo: fuente pixel,
/// esquinas rectas, botones `#22305a`/`#5b74c9`, sin sombras ni ripples.
abstract final class RetroTheme {
  /// Press Start 2P (`pubspec.yaml`, bloque `fonts:`): la de las
  /// etiquetas pintadas en los lienzos (mundo, escena). La de títulos y
  /// botones de la UI es [RetroType.titleFamily] (puede ser la de lectura).
  static const fontFamily = RetroType.pixelFamily;

  /// Borde de `.panel` (3 px en el prototipo).
  static const borderWidth = 3.0;
  static const thinBorderWidth = 2.0;

  static const _square = RoundedRectangleBorder();

  /// Aire mínimo entre el borde de un botón y su texto (ui_style.md §
  /// "Padding de botones", v0.9.7): 8 px **libres**, sin contar el borde.
  static const minButtonInset = 8.0;

  /// Padding de un botón con [inset] px libres entre el borde (que
  /// Material pinta encima del padding) y el contenido; nunca menos de
  /// [minButtonInset].
  static EdgeInsets buttonPadding(double inset) => EdgeInsets.all(
      (inset < minButtonInset ? minButtonInset : inset) +
          UiTheme.buttonBorderWidth);

  /// Botón compacto para paneles y HUD (docs/specs/ui_style.md §
  /// "Botón compacto"): texto [RetroType.small], padding de 8 px y borde
  /// de 2 px.
  /// Hereda colores y estados del tema; se pasa como `style:`.
  static ButtonStyle compactButton() => ButtonStyle(
        // Cambio de color instantáneo (sin la animación de Material).
        animationDuration: Duration.zero,
        padding: WidgetStatePropertyAll(buttonPadding(8)),
        minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(
          RetroType.titleStyle(RetroType.label),
        ),
      );

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: RetroPalette.gold,
      onPrimary: RetroPalette.night,
      secondary: RetroPalette.green,
      onSecondary: RetroPalette.night,
      error: RetroPalette.red,
      onError: RetroPalette.ink,
      surface: RetroPalette.panel,
      onSurface: RetroPalette.ink,
      outline: RetroPalette.ink,
    );

    final buttonStyle = ButtonStyle(
      // Sin transiciones: el feedback es el cambio instantáneo.
      animationDuration: Duration.zero,
      elevation: const WidgetStatePropertyAll(0),
      shape: const WidgetStatePropertyAll(_square),
      padding: WidgetStatePropertyAll(buttonPadding(14)),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: WidgetStatePropertyAll(
        RetroType.titleStyle(RetroType.title),
      ),
      // `button` / `button:hover` / `button:disabled` del prototipo.
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? ProtoColors.button.withValues(alpha: 0.35)
            : s.contains(WidgetState.hovered) ||
                    s.contains(WidgetState.focused) ||
                    s.contains(WidgetState.pressed)
                ? ProtoColors.buttonHover
                : ProtoColors.button,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? ProtoColors.white.withValues(alpha: 0.35)
            : ProtoColors.white,
      ),
      side: WidgetStateProperty.resolveWith(
        (s) => BorderSide(
          // 3 px en ALTO CONTRASTE (accessibility.md § 8.1).
          width: UiTheme.buttonBorderWidth,
          color: s.contains(WidgetState.disabled)
              ? ProtoColors.buttonBorder.withValues(alpha: 0.35)
              // Foco de teclado: el mismo dorado del aro de los menús
              // (`FocusRing`, lib/app/widgets/menu_focus.dart).
              : s.contains(WidgetState.focused)
                  ? ProtoColors.gold
                  : s.contains(WidgetState.hovered)
                      ? ProtoColors.buttonHoverBorder
                      : ProtoColors.buttonBorder,
        ),
      ),
    );

    // Interlineado de los títulos (Press Start 1.5; menos con "Títulos con
    // la fuente de lectura").
    final tl = RetroType.titleLine;
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: RetroType.titleFamily,
      fontFamilyFallback:
          RetroType.titlesInReading ? RetroType.bodyFallback : null,
      scaffoldBackgroundColor: RetroPalette.night,
      splashFactory: NoSplash.splashFactory,
      // Escala tipográfica: docs/specs/ui_style.md § "Tipografía".
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: RetroType.display, height: tl),
        headlineMedium: TextStyle(fontSize: RetroType.heading, height: tl),
        titleMedium: TextStyle(fontSize: RetroType.title, height: tl),
        bodyLarge: TextStyle(fontSize: RetroType.title, height: tl),
        bodyMedium: TextStyle(fontSize: RetroType.title, height: tl),
        // Texto de lectura: VT323 (RetroType.bodyFamily).
        bodySmall: RetroType.smallStyle,
        labelLarge: TextStyle(fontSize: RetroType.title, height: tl),
        labelSmall: RetroType.smallStyle,
      ).apply(
        bodyColor: RetroPalette.ink,
        displayColor: RetroPalette.ink,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: RetroPalette.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: ProtoColors.buttonBorder, width: borderWidth),
        ),
      ),
      dialogTheme: const DialogThemeData(
        elevation: 0,
        backgroundColor: RetroPalette.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: ProtoColors.buttonBorder, width: borderWidth),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: ProtoColors.input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
              color: ProtoColors.inputBorder, width: thinBorderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
              color: ProtoColors.inputBorder, width: thinBorderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:
              BorderSide(color: RetroPalette.gold, width: thinBorderWidth),
        ),
      ),
    );
    // `fontFamily` de ThemeData pisa la familia de todo el textTheme: el
    // texto de lectura vuelve a VT323 después.
    final t = theme.textTheme;
    TextStyle body(TextStyle? s) => s!.copyWith(
        fontFamily: RetroType.bodyFamily,
        fontFamilyFallback: const [RetroType.pixelFamily],
        letterSpacing: RetroType.letterSpacing);
    return theme.copyWith(
      textTheme: t.copyWith(
          bodySmall: body(t.bodySmall), labelSmall: body(t.labelSmall)),
    );
  }
}
