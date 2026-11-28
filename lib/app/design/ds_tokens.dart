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
  /// KEY INFO: the rule, limit or number that matters (rose; never an
  /// element or rarity colour, design_system.md § 3.4).
  static const textKey = DsTextColor(DsTextRole.key);

  /// Muted / meta text (stats, flavour, who / when).
  static const textMuted = textSecondary;
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

  /// Borde de una acción cuya condición especial se está cumpliendo
  /// (habilidad con precondición lista; battle_presentation.md). Distinto
  /// del dorado de selección.
  static const conditionReady = ProtoColors.sky;

  /// What an editor is acting on: selection box and handles on a canvas,
  /// the selected key and the changed values (game_editor.md § 7.7).
  static const editSelection = ProtoColors.green;

  /// The 1 px silhouette outline of the E / click target on the map
  /// (controls.md § Cursor de acción).
  static const targetOutline = ProtoColors.white;

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
        'selección de editor': editSelection,
      };
}

/// Rol de un color de texto del sistema.
///
/// The colours never reuse an element, rarity or status colour
/// (design_system.md § 3.4); `test/design/ds_text_roles_test.dart`
/// checks it.
enum DsTextRole { title, subtitle, body, detail, key }

/// Color de texto por rol que sigue al tema de interfaz activo
/// (design_system.md § 3.3). `const` como `ThemeColor`.
class DsTextColor extends Color {
  const DsTextColor(this.role) : super(0);

  final DsTextRole role;

  /// ARGB por tema, en el orden de [DsTextRole].
  static const table = <InterfaceTheme, List<int>>{
    // title, subtitle, body, detail (muted), key
    InterfaceTheme.blue: [
      0xFFFFFFFF,
      0xFFB0BEE8,
      0xFFE8ECFF,
      0xFFA0A8C8,
      0xFFFF70C8
    ],
    InterfaceTheme.dark: [
      0xFFFFFFFF,
      0xFFB0BEE8,
      0xFFE8ECFF,
      0xFFA0A8C8,
      0xFFFF70C8
    ],
    InterfaceTheme.highContrast: [
      0xFFFFFFFF,
      0xFFB0BEE8,
      0xFFFFFFFF,
      0xFFB4B4D8,
      0xFFFF8AD8
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
  /// Display: Press Start 2P 32 nominal (nombre del juego en el título).
  static TextStyle display([Color? c]) =>
      RetroType.style(RetroType.display, color: c ?? DsColors.textTitle);

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

  /// Descripción: fuente de lectura 11 en el color del Cuerpo (texto
  /// propio de un objeto o encargo: "Necesito…").
  static TextStyle description([Color? c]) =>
      RetroType.style(RetroType.body, color: c ?? DsColors.text);

  /// Meta / apagado: fuente de lectura 10 en gris (quién lo pide, día,
  /// estado corto de una fila). El escalón más bajo de la jerarquía.
  static TextStyle meta([Color? c]) =>
      RetroType.style(RetroType.small, color: c ?? DsColors.textDisabled);

  /// KEY INFO: reading font 11 in [DsColors.textKey]. The restriction,
  /// limit or requirement a player must not miss ("only 12 plots").
  /// Inline: `**…**` or `<key>…</key>` in any markup ([DsRichText]).
  static TextStyle key([Color? c]) =>
      RetroType.style(RetroType.body, color: c ?? DsColors.textKey);

  /// Muted: alias of [detail] (stats, flavour).
  static TextStyle muted([Color? c]) => detail(c);

  /// Compact title (tooltip / card name): pixel font 9 in the title
  /// colour. Same role as [title], sized for a tooltip.
  static TextStyle heading([Color? c]) =>
      RetroType.style(RetroType.label, color: c ?? DsColors.textTitle);

  /// Acento / recompensa: fuente de lectura 11 en dorado (oro, rep,
  /// lo que se gana).
  static TextStyle accent([Color? c]) =>
      RetroType.style(RetroType.body, color: c ?? DsColors.reward);

  /// La jerarquía de texto completa, para la galería: nombre → estilo.
  static Map<String, TextStyle> get hierarchy => {
        'Título': title(),
        'Título compacto': heading(),
        'Subtítulo': subtitle(),
        'Cuerpo': body(),
        'Descripción': description(),
        'Apagado / stats': muted(),
        'Meta': meta(),
        'CLAVE': key(),
        'Acento (oro)': accent(),
      };
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

  /// Tope del ancho de todo tooltip: [tooltipWidth] × factor de texto,
  /// nunca más del 45 % del ancho de la ventana (regla global, v0.20.1).
  static double tooltipMaxWidth(BuildContext context) {
    final w = RetroType.width(context, tooltipWidth);
    final cap = MediaQuery.sizeOf(context).width * 0.45;
    return w < cap ? w : cap;
  }
}

/// Item grid sizes (design_system.md § "Grilla de ítems"). INVENTARIO
/// is the reference: every screen that shows items uses these.
abstract final class DsSizes {
  /// Base cell, gap and icon (same as `InventoryTab.cell` / `gap`).
  static const itemCell = 44.0, itemGap = 4.0, itemIcon = 32.0;

  /// Every item grid is exactly this many columns wide.
  static const gridColumns = 6;

  /// Rows the cell scale is fitted to (INVENTARIO's 5 rows).
  static const gridRows = 5;

  /// Minimum width of the actions pane on the right of a grid (it
  /// grows to fill whatever the grid leaves).
  static const detailPaneWidth = 340.0;

  /// Separation between grid and detail, and room for the scrollbar.
  static const gridDetailGap = 8.0, gridScrollbar = 10.0;

  /// Width of the grid at scale [k].
  static double gridWidth([double k = 1]) =>
      (gridColumns * itemCell + (gridColumns - 1) * itemGap) * k;

  /// Same steps as INVENTARIO (`inventoryLayout`): whole from ×2,
  /// quarters between ×1 and ×2.
  static double snap(double k) {
    if (k < 1) return k > 0.3 ? k : 0.3;
    return k >= 2 ? k.floorToDouble() : (k * 4).floorToDouble() / 4;
  }

  /// INVENTARIO's cell scale for a panel body of [w] × [h] at text
  /// factor [text]: the same rule as `inventoryLayout` (8 × 5 grid, the
  /// CAMBIOS strip — about a quarter of the width, more with big text —
  /// and the side column of 240 × text), so every item grid gets the
  /// inventory's cell size in the same panel.
  static double inventoryScale(double w, double h, {double text = 1}) {
    const base = 8 * itemCell + 7 * itemGap;
    const unit = itemCell + itemGap;
    const sep = 16.0;
    final sideMin = 240 * text;
    final width = w - 8;
    final strip = w * (0.245 + 0.145 * (text - 1)) + 8;
    double fit(double byW, double byH) {
      final k = byW < byH ? byW : byH;
      if (k < 1) return byW < 1 ? (byW > 0.3 ? byW : 0.3) : 1;
      return snap(k);
    }

    if (width >= strip + base + sep + sideMin) {
      final byW = (width - strip - sep - sideMin) / base;
      var k = fit(byW, h.isFinite ? (h - 30) / (gridRows * unit) : byW);
      double side(double k) =>
          4 * unit * k > sideMin ? 4 * unit * k : sideMin;
      while (k > 1 && base * k + sep + side(k) > width - strip) {
        k = k > 2 ? k.ceilToDouble() - 1 : k - 0.25;
      }
      return k;
    }
    final byH = h.isFinite
        ? (h - 120) / ((gridRows + 2) * unit)
        : double.infinity;
    if (width >= strip + base) return fit((width - strip) / base, byH);
    return fit(width / base, byH);
  }

  static (Size, double, double)? _inventory;

  /// INVENTARIO reports the cell scale it laid out with, for the screen
  /// size and text width (`scale(240)`) it saw: [itemScale] reuses that
  /// exact scale on the same screen, so every item grid matches it.
  /// Until INVENTARIO has been shown, [inventoryScale] estimates it.
  static void rememberInventoryScale(Size screen, double text240, double k) =>
      _inventory = (screen, text240, k);

  /// Body of the character panel (where INVENTARIO lives) on a screen
  /// of [screen]: measured at 1280×720, 1920×1080 and 2560×1440.
  static Size inventoryBodyFor(Size screen) =>
      Size(screen.width * 0.78 - 36, screen.height * 0.767 - 105);

  /// Cell scale of a grid + detail area of [w] × [h]: INVENTARIO's
  /// ([inventoryScale]) for the same [screen] (so every item screen gets
  /// the inventory's cell even when its own body is shorter — the grid
  /// scrolls), lowered only if 6 columns plus the detail do not fit
  /// across. Without [screen] the area itself is used.
  static double itemScale(double w, double h,
      {double text = 1, Size? screen}) {
    if (!w.isFinite) return 1;
    final body = screen == null || screen.isEmpty
        ? Size(w, h)
        : inventoryBodyFor(screen);
    final known = _inventory;
    final inv = known != null &&
            screen != null &&
            known.$1 == screen &&
            (known.$2 - text * 240).abs() < 0.01
        ? known.$3
        : inventoryScale(body.width, body.height, text: text);
    final byW =
        (w - detailPaneWidth - gridDetailGap - gridScrollbar) / gridWidth();
    if (inv <= byW) return inv;
    return byW >= 1 ? snap(byW) : byW;
  }

  /// Width from which the detail goes on the right (scale ×1).
  static double get gridDetailWideFrom =>
      gridWidth() + gridDetailGap + gridScrollbar + detailPaneWidth;
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
          constraints: const BoxConstraints(maxWidth: 720),
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
