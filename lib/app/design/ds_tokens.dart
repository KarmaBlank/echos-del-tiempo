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

  static const textPrimary = ProtoColors.title;
  static const text = ProtoColors.ink;
  static const textSecondary = ProtoColors.dim;
  static Color get textDisabled => ProtoColors.dim.withValues(alpha: 0.6);

  static const actionPrimary = ProtoColors.gold;
  static const onActionPrimary = ProtoColors.bg;
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
        'texto principal': textPrimary,
        'texto': text,
        'texto secundario': textSecondary,
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

/// Estilos de texto con nombre (design_system.md § 3.2).
abstract final class DsText {
  /// Título: Press Start 2P 16 nominal.
  static TextStyle title([Color? c]) =>
      RetroType.style(RetroType.title, color: c ?? DsColors.textPrimary);

  /// Subtítulo: Press Start 2P 9 nominal (etiquetas, botones, pestañas).
  static TextStyle subtitle([Color? c]) =>
      RetroType.style(RetroType.label, color: c ?? DsColors.textSecondary);

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
          textColor: DsColors.onActionPrimary,
        ),
      );

  @override
  DsTheme copyWith({bool? highContrast}) =>
      DsTheme(highContrast: highContrast ?? this.highContrast);

  @override
  DsTheme lerp(DsTheme? other, double t) => t < 0.5 ? this : (other ?? this);
}
