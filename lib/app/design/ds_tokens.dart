import 'dart:ui' show ColorSpace;

import 'package:material_ui/material_ui.dart';

import '../theme/proto_colors.dart';
import '../theme/retro_theme.dart';
import '../theme/ui_theme.dart';

/// Escala de espaciado del sistema de diseño (docs/specs/design_system.md
/// § 3.1). Pasa por [UiTheme.space]: ×1.5 en ESPACIADO AMPLIO.
abstract final class DsSpace {
  static double get xs => UiTheme.space(4);
  static double get sm => UiTheme.space(8);
  static double get md => UiTheme.space(16);
  static double get lg => UiTheme.space(24);
  static double get xl => UiTheme.space(32);

  /// Valores base (NORMAL), para la galería.
  static const base = {
    'xs': 4.0,
    'sm': 8.0,
    'md': 16.0,
    'lg': 24.0,
    'xl': 32.0
  };
}

/// Roles de color (design_system.md § 3.3). Todos salen de [ProtoColors]:
/// siguen al tema de interfaz y al modo daltónico.
abstract final class DsColors {
  static const surface = ProtoColors.panel;
  static const surfaceRaised = ProtoColors.button;
  static const surfaceSunken = ProtoColors.input;
  static const background = ProtoColors.bg;
  static const border = ProtoColors.panelBorder;
  static const borderControl = ProtoColors.buttonBorder;
  static const hover = ProtoColors.buttonHover;
  static const hoverBorder = ProtoColors.buttonHoverBorder;

  /// Jerarquía del texto por COLOR (no hay pesos: sin negritas).
  static const textTitle = DsTextColor(DsTextRole.title);
  static const textSubtitle = DsTextColor(DsTextRole.subtitle);

  /// Cuerpo: blanco tinta (nombres, valores, etiquetas de botones).
  static const textPrimary = DsTextColor(DsTextRole.body);
  static const text = textPrimary;

  /// Detalle / secundario: lavanda.
  static const textSecondary = DsTextColor(DsTextRole.detail);
  static Color get textDisabled => textSecondary.withValues(alpha: 0.55);

  /// Acción principal: misma caja que el resto, borde y texto dorados.
  static const actionPrimary = ProtoColors.gold;
  static const focus = ProtoColors.gold;
  static const selected = ProtoColors.gold;

  static const danger = ProtoColors.red;
  static const success = ProtoColors.green;
  static const reward = ProtoColors.gold;
  static const pulse = ProtoColors.gold;
  static const mp = ProtoColors.ice;
  static const warning = ProtoColors.orange;

  /// Instante: celeste fijo (el de Congelación súbita, en `UiTheme.keep`).
  static const instant = Color(0xFF81ECEC);

  /// Para la galería: nombre del rol → color.
  static Map<String, Color> get roles => {
        'superficie': surface,
        'superficie elevada': surfaceRaised,
        'superficie hundida': surfaceSunken,
        'borde': border,
        'borde de control': borderControl,
        'Título': textTitle,
        'Subtítulo': textSubtitle,
        'Cuerpo': textPrimary,
        'Detalle': textSecondary,
        'texto desactivado': textDisabled,
        'acción principal': actionPrimary,
        'acción secundaria': surfaceRaised,
        'foco': focus,
        'peligro': danger,
        'éxito': success,
        'recompensa': reward,
        'Pulso': pulse,
        'MP': mp,
        'Instante': instant,
      };
}

/// Rol de un color de texto del sistema.
enum DsTextRole { title, subtitle, body, detail }

/// Color de texto por rol que sigue al tema de interfaz activo
/// (design_system.md § 3.3). `const` como `ThemeColor`.
class DsTextColor extends Color {
  const DsTextColor(this.role) : super(0);

  final DsTextRole role;

  /// ARGB por tema, en el orden de [DsTextRole].
  static const table = <InterfaceTheme, List<int>>{
    InterfaceTheme.blue: [0xFFFFE3A8, 0xFF8FD3F4, 0xFFE8ECFF, 0xFFB3ACE6],
    InterfaceTheme.dark: [0xFFF5D99A, 0xFF8EC5E6, 0xFFEDEDED, 0xFFB8B2DC],
    InterfaceTheme.highContrast: [
      0xFFFFF1A8,
      0xFF9FE7FF,
      0xFFFFFFFF,
      0xFFD4CCFF
    ],
  };

  /// El color de [role] en [t].
  static Color inTheme(InterfaceTheme t, DsTextRole role) =>
      Color(table[t]![role.index]);

  Color get _c => inTheme(UiTheme.kind, role);

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
      'DsTextColor(${role.name}: ${_c.toARGB32().toRadixString(16)})';
}

/// Estilos de texto con nombre (design_system.md § 3.2).
abstract final class DsText {
  /// Título: Press Start 2P 16 nominal.
  static TextStyle title([Color? c]) =>
      RetroType.style(RetroType.title, color: c ?? DsColors.textTitle);

  /// Subtítulo: Press Start 2P 9 nominal (etiquetas, botones, pestañas).
  static TextStyle subtitle([Color? c]) =>
      RetroType.style(RetroType.label, color: c ?? DsColors.textSubtitle);

  /// Texto: fuente de lectura 11 nominal.
  static TextStyle body([Color? c]) =>
      RetroType.style(RetroType.body, color: c ?? DsColors.text);

  /// Detalle: fuente de lectura 10 nominal, secundario.
  static TextStyle detail([Color? c]) =>
      RetroType.style(RetroType.small, color: c ?? DsColors.textSecondary);
}

/// Medidas fijas de los componentes (px nominales).
abstract final class DsMetrics {
  /// Aire libre mínimo entre el borde y el contenido de un botón.
  static const inset = RetroTheme.minButtonInset;
  static double get controlBorder => UiTheme.buttonBorderWidth;
  static const focusWidth = 2.0;
  static const focusGap = 2.0;
  static const minHeight = 40.0;
  static const minHeightCompact = 32.0;
  static const tooltipWidth = 360.0;
}

/// Extensión de tema con los roles (para quien prefiera
/// `Theme.of(context).extension<DsTheme>()`).
@immutable
class DsTheme extends ThemeExtension<DsTheme> {
  const DsTheme({this.highContrast = false});

  final bool highContrast;

  static DsTheme of(BuildContext context) =>
      Theme.of(context).extension<DsTheme>() ?? const DsTheme();

  /// El tema retro con la extensión y los temas de los widgets estándar
  /// que usa el sistema (pestañas, tooltip, búsqueda, insignia).
  static ThemeData apply(ThemeData base) => base.copyWith(
        extensions: [
          DsTheme(highContrast: UiTheme.kind == InterfaceTheme.highContrast)
        ],
        tabBarTheme: const TabBarThemeData(
          dividerColor: DsColors.border,
          indicatorColor: DsColors.selected,
          labelColor: DsColors.selected,
          unselectedLabelColor: DsColors.text,
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          mouseCursor: WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: DsColors.background,
            border: Border.all(color: DsColors.borderControl, width: 2),
          ),
          textStyle: DsText.detail(DsColors.text),
          waitDuration: const Duration(milliseconds: 300),
        ),
        badgeTheme: const BadgeThemeData(
          backgroundColor: DsColors.actionPrimary,
          textColor: ProtoColors.bg,
        ),
      );

  @override
  DsTheme copyWith({bool? highContrast}) =>
      DsTheme(highContrast: highContrast ?? this.highContrast);

  @override
  DsTheme lerp(DsTheme? other, double t) => t < 0.5 ? this : (other ?? this);
}
