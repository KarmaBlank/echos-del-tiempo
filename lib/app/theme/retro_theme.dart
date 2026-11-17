import 'package:material_ui/material_ui.dart';

/// Paleta de 8 colores del estilo 8 bits (ver docs/specs/ui_style.md).
/// Ningún widget debería usar colores fuera de esta lista.
abstract final class RetroPalette {
  static const night = Color(0xFF0F0F1B);
  static const panel = Color(0xFF1D2B53);
  static const panelDark = Color(0xFF111A33);
  static const ink = Color(0xFFFFF1E8);
  static const muted = Color(0xFF8B93AF);
  static const gold = Color(0xFFFFCC33);
  static const red = Color(0xFFE43B44);
  static const green = Color(0xFF63C74D);
}

/// Tema global estilo 8 bits: fuente pixel, esquinas rectas, bordes
/// gruesos, sin sombras suaves ni ripples.
abstract final class RetroTheme {
  /// Familia declarada en `pubspec.yaml` (bloque `fonts:`).
  static const fontFamily = 'PressStart2P';

  static const borderWidth = 4.0;
  static const thinBorderWidth = 2.0;

  static const _square = RoundedRectangleBorder();

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
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.pressed)
            ? RetroPalette.panelDark
            : RetroPalette.panel,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? RetroPalette.muted
            : RetroPalette.ink,
      ),
      side: WidgetStateProperty.resolveWith(
        (s) => BorderSide(
          width: borderWidth,
          color: s.contains(WidgetState.focused) ||
                  s.contains(WidgetState.hovered)
              ? RetroPalette.gold
              : RetroPalette.ink,
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
          side: BorderSide(color: RetroPalette.ink, width: borderWidth),
        ),
      ),
      dialogTheme: const DialogThemeData(
        elevation: 0,
        backgroundColor: RetroPalette.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: RetroPalette.ink, width: borderWidth),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: RetroPalette.panelDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:
              BorderSide(color: RetroPalette.ink, width: thinBorderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide:
              BorderSide(color: RetroPalette.ink, width: thinBorderWidth),
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
