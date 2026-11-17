import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';

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
  /// Familia declarada en `pubspec.yaml` (bloque `fonts:`).
  static const fontFamily = 'PressStart2P';

  /// Borde de `.panel` (3 px en el prototipo).
  static const borderWidth = 3.0;
  static const thinBorderWidth = 2.0;

  static const _square = RoundedRectangleBorder();

  /// Botón compacto para paneles y HUD (docs/specs/ui_style.md §
  /// "Botón compacto"): texto de 8 px, padding de 8 px y borde de 2 px.
  /// Hereda colores y estados del tema; se pasa como `style:`.
  static ButtonStyle compactButton() => const ButtonStyle(
        // Cambio de color instantáneo (sin la animación de Material).
        animationDuration: Duration.zero,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        minimumSize: WidgetStatePropertyAll(Size(0, 32)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: fontFamily, fontSize: 8),
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
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: fontFamily, fontSize: 16),
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
          width: thinBorderWidth,
          color: s.contains(WidgetState.disabled)
              ? ProtoColors.buttonBorder.withValues(alpha: 0.35)
              : s.contains(WidgetState.focused) ||
                      s.contains(WidgetState.hovered)
                  ? ProtoColors.buttonHoverBorder
                  : ProtoColors.buttonBorder,
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: RetroPalette.night,
      splashFactory: NoSplash.splashFactory,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, height: 1.5),
        headlineMedium: TextStyle(fontSize: 24, height: 1.5),
        titleMedium: TextStyle(fontSize: 16, height: 1.5),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 16, height: 1.5),
        bodySmall: TextStyle(fontSize: 8, height: 1.5),
        labelLarge: TextStyle(fontSize: 16, height: 1.5),
        labelSmall: TextStyle(fontSize: 8, height: 1.5),
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
          borderSide:
              BorderSide(color: ProtoColors.inputBorder, width: thinBorderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:
              BorderSide(color: ProtoColors.inputBorder, width: thinBorderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:
              BorderSide(color: RetroPalette.gold, width: thinBorderWidth),
        ),
      ),
    );
  }
}
