import 'dart:ui' show ColorSpace;

import 'package:material_ui/material_ui.dart';

import '../../core/settings/game_settings.dart'
    show InterfaceTheme, TextColorMode, UiSpacing;
import 'vision_palette.dart';

export '../../core/settings/game_settings.dart'
    show InterfaceTheme, TextColorMode, UiSpacing;

/// Cada color "de interfaz" que cambia con el tema
/// (docs/specs/accessibility.md § 8). El arte (arenas, mapa, sprites) usa
/// sus propios hex y no cambia.
enum UiSlot {
  /// Fondo general y caja de los tooltips.
  bg,

  /// Texto de lectura (rol `body`).
  ink,

  /// Nombres y títulos (rol `title`). Con los colores COMPLETOS es el
  /// dorado de siempre ([gold]).
  title,

  /// Paneles.
  panel,
  panelBorder,

  /// Botones (superficie "elevada").
  button,
  buttonBorder,
  buttonHover,
  buttonHoverBorder,

  /// Campos y cajitas hundidas.
  input,
  inputBorder,

  /// Selección, foco y acento (valores, costos, `<b>`).
  gold,

  /// Etiquetas (`.k`, `small`).
  sky,

  /// Texto atenuado (rol `muted`: líneas de tipo · nivel · cluster).
  dim,

  /// Chat.
  chat,

  /// Fondo de las barras.
  barBg,

  /// MP, éter, Congelación.
  ice,

  /// Arma equipada, avisos.
  orange,

  /// ULT cargando.
  violet,

  /// ULT lista.
  pink,
}

/// El tema de interfaz activo y sus tokens. Lo fija [UiThemeScope] (la
/// app) con los ajustes; en tests, a mano.
///
/// Los valores por defecto de estos estáticos son los de AZUL + COMPLETO
/// + NORMAL (el aspecto de v0.8.0, el que esperan los tests de siempre);
/// el valor por defecto del JUGADOR está en `GameSettings` (OSCURO +
/// REDUCIDO desde v0.8.1).
abstract final class UiTheme {
  static InterfaceTheme kind = InterfaceTheme.blue;
  static TextColorMode textColors = TextColorMode.full;
  static UiSpacing spacing = UiSpacing.normal;

  /// Pone los tres de vuelta como en v0.8.0 (tests).
  static void reset() {
    kind = InterfaceTheme.blue;
    textColors = TextColorMode.full;
    spacing = UiSpacing.normal;
  }

  /// El markup se pinta por roles (REDUCIDO; ALTO CONTRASTE siempre).
  static bool get roles =>
      textColors == TextColorMode.reduced ||
      kind == InterfaceTheme.highContrast;

  /// Espaciado AMPLIO.
  static bool get wide => spacing == UiSpacing.wide;

  /// Borde de los paneles (`RetroPanel`): grueso en ALTO CONTRASTE.
  static double get panelBorderWidth =>
      kind == InterfaceTheme.highContrast ? 4 : 3;

  /// Borde de los botones del tema.
  static double get buttonBorderWidth =>
      kind == InterfaceTheme.highContrast ? 3 : 2;

  /// [v] px de aire (padding, margen) con el espaciado activo: ×1.5 en
  /// AMPLIO.
  static double space(double v) => wide ? (v * 1.5).roundToDouble() : v;

  /// Separación extra entre las líneas (`<br>`) de un markup en AMPLIO.
  static double get paragraphGap => wide ? 4 : 0;

  /// El color de [s] en el tema activo.
  static Color of(UiSlot s) => inTheme(kind, s, roles: roles);

  /// El color de [s] en [t] (con los colores por roles si [roles]).
  static Color inTheme(InterfaceTheme t, UiSlot s, {bool roles = false}) {
    final slot = s == UiSlot.title && !roles ? UiSlot.gold : s;
    return Color(table[t]![slot.index]);
  }

  /// ARGB por tema, en el orden de [UiSlot].
  static const table = <InterfaceTheme, List<int>>{
    // v0.5-v0.8.0: azul marino con los tokens suavizados (§ 2).
    InterfaceTheme.blue: [
      0xFF0B0E1A, // bg
      0xFFB0BAE5, // ink
      0xFFE8ECFF, // title
      0xFF121936, // panel
      0xFF2E3B6B, // panelBorder
      0xFF22305A, // button
      0xFF5B74C9, // buttonBorder
      0xFF2E4280, // buttonHover
      0xFF9FB4FF, // buttonHoverBorder
      0xFF0F1530, // input
      0xFF3A4A85, // inputBorder
      0xFFD3AC4F, // gold
      0xFF8FA1DF, // sky
      0xFF929ABA, // dim
      0xFFC8D2FF, // chat
      0xFF222A48, // barBg
      0xFF77A7D7, // ice
      0xFFD1975F, // orange
      0xFF9E99E0, // violet
      0xFFCF85A8, // pink
    ],
    // Escala neutra (tipo Tailwind neutral) + un acento ámbar: jerarquía
    // por brillo (título > cuerpo > atenuado), no por tono.
    InterfaceTheme.dark: [
      0xFF0A0A0A, // bg
      0xFFD4D4D4, // ink (body)
      0xFFF5F5F5, // title
      0xFF141414, // panel
      0xFF2E2E2E, // panelBorder
      0xFF1F1F1F, // button (raised)
      0xFF525252, // buttonBorder
      0xFF2A2A2A, // buttonHover
      0xFF8A8A8A, // buttonHoverBorder
      0xFF0F0F0F, // input
      0xFF404040, // inputBorder
      0xFFF5C451, // gold (accent, foco)
      0xFFA3A3A3, // sky (etiquetas = muted)
      0xFFA3A3A3, // dim (muted)
      0xFFE5E5E5, // chat
      0xFF262626, // barBg
      0xFF8DB4D9, // ice
      0xFFE0A262, // orange
      0xFFB4AEDD, // violet
      0xFFD696B5, // pink
    ],
    // Negro / blanco; amarillo fuerte para foco y acento.
    InterfaceTheme.highContrast: [
      0xFF000000, // bg
      0xFFF0F0F0, // ink
      0xFFFFFFFF, // title
      0xFF000000, // panel
      0xFFBDBDBD, // panelBorder
      0xFF000000, // button
      0xFFFFFFFF, // buttonBorder
      0xFF262626, // buttonHover
      0xFFFFE600, // buttonHoverBorder
      0xFF000000, // input
      0xFFFFFFFF, // inputBorder
      0xFFFFE600, // gold
      0xFFE0E0E0, // sky
      0xFFC8C8C8, // dim
      0xFFFFFFFF, // chat
      0xFF333333, // barBg
      0xFFB8DCFF, // ice
      0xFFFFD0A0, // orange
      0xFFE2DDFF, // violet
      0xFFFFD1E6, // pink
    ],
  };

  /// Colores de markup que se quedan como están con los colores por
  /// roles: estados alterados y elementos (`statusHex`, `elementHex`,
  /// `reactionHex`, los de `ProtoColors`) y la rareza Común.
  static const keep = <int>{
    0xFFFF7B29, // Quemadura
    0xFF74B9FF, // Congelación
    0xFFFFEAA7, // Aturdir / Protege
    0xFFFFF3B0, // Sagrado
    0xFF55EFC4, // Regeneración
    0xFF3FA9F5, // Mojado
    0xFFC77DFF, // Cargado
    0xFFDFE6E9, // Físico
    0xFFBADC58, // Explosión tóxica
    0xFF81ECEC, // Congelación súbita / Quebradizo
    0xFFFF7675, // Provoca
    0xFFDCDCDC, // rareza Común
  };

  /// Rol de un color de markup con los colores por roles
  /// (accessibility.md § 8.2). [bold]: es un `<b>`; [lineStart]: abre la
  /// línea (un nombre / título).
  ///
  /// - con significado (mejora / empeora, HP / MP, rarezas: [VisionColor])
  ///   y estados / elementos ([keep], `ice`): igual;
  /// - etiquetas y atenuados (`sky`, `dim`): `muted`;
  /// - `<b>` al principio de la línea: `title`; otro `<b>`, el dorado o un
  ///   aviso naranja: `accent`;
  /// - el resto (violeta, rosa, celestes de mods, turquesas…): `body`.
  static Color role(Color c, {required bool bold, required bool lineStart}) {
    if (c is VisionColor) return c;
    final emphasis = bold
        ? (lineStart
            ? const ThemeColor(UiSlot.title)
            : const ThemeColor(UiSlot.gold))
        : const ThemeColor(UiSlot.ink);
    if (c is ThemeColor) {
      return switch (c.slot) {
        UiSlot.sky || UiSlot.dim => const ThemeColor(UiSlot.dim),
        UiSlot.ice => c,
        UiSlot.title => c,
        // El dorado que abre la línea es un nombre (`protoColor(gold,
        // nombre)` de las fichas de enemigos, p. ej.).
        UiSlot.gold => lineStart
            ? const ThemeColor(UiSlot.title)
            : const ThemeColor(UiSlot.gold),
        UiSlot.orange => bold && lineStart
            ? const ThemeColor(UiSlot.title)
            : const ThemeColor(UiSlot.gold),
        _ => emphasis,
      };
    }
    final argb = c.toARGB32() | 0xFF000000;
    // Estados, elementos y (con el modo daltónico apagado, cuando el hex
    // no pasa a VisionColor) los colores con significado y las rarezas.
    if (keep.contains(argb) || VisionPalette.byDefault.containsKey(argb)) {
      return c;
    }
    return emphasis;
  }
}

/// Un color de interfaz que sigue al tema activo ([UiTheme.kind]). Es
/// `const` (como [VisionColor]): se lee del tema al pintar y
/// [UiThemeScope] reconstruye todo al cambiar.
class ThemeColor extends Color {
  const ThemeColor(this.slot) : super(0);

  final UiSlot slot;

  Color get _c => UiTheme.of(slot);

  /// El valor en AZUL (el del markup: `ProtoColors.hex`).
  Color get base => UiTheme.inTheme(InterfaceTheme.blue, slot);

  @override
  double get a => _c.a;

  @override
  double get r => _c.r;

  @override
  double get g => _c.g;

  @override
  double get b => _c.b;

  @override
  ColorSpace get colorSpace => ColorSpace.sRGB;

  @override
  String toString() =>
      'ThemeColor(${slot.name}: ${_c.toARGB32().toRadixString(16)})';
}

/// Aplica tema, colores del texto y espaciado a toda la app (en
/// `MaterialApp.builder`, como `ColorVisionScope`). Al cambiar reconstruye
/// y vuelve a medir todo sin perder estado.
class UiThemeScope extends StatefulWidget {
  const UiThemeScope({
    super.key,
    required this.theme,
    required this.textColors,
    required this.spacing,
    required this.child,
  });

  final InterfaceTheme theme;
  final TextColorMode textColors;
  final UiSpacing spacing;
  final Widget child;

  @override
  State<UiThemeScope> createState() => _UiThemeScopeState();
}

class _UiThemeScopeState extends State<UiThemeScope> {
  @override
  void didUpdateWidget(UiThemeScope old) {
    super.didUpdateWidget(old);
    if (old.theme != widget.theme ||
        old.textColors != widget.textColors ||
        old.spacing != widget.spacing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // ignore: invalid_use_of_protected_member
        PaintingBinding.instance.handleSystemMessage(
            const <String, Object?>{'type': 'fontsChange'});
        WidgetsBinding.instance.reassembleApplication();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    UiTheme.kind = widget.theme;
    UiTheme.textColors = widget.textColors;
    UiTheme.spacing = widget.spacing;
    return widget.child;
  }
}
