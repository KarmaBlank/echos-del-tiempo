import 'package:material_ui/material_ui.dart';

import '../theme/retro_text.dart';
import '../theme/ui_theme.dart';
import 'ds_focus.dart';
import 'ds_gold.dart';
import 'ds_tokens.dart';

/// Variante de [DsButton] (design_system.md § 6).
enum DsButtonKind { primary, secondary, ghost, icon }

/// Tamaño de [DsButton].
enum DsButtonSize { normal, compact }

/// Botón del sistema de diseño, sobre `FilledButton` (principal),
/// `OutlinedButton` (secundario), `TextButton` (fantasma) e `IconButton`
/// (ícono). Siempre ≥ 8 px libres entre borde y texto, foco de teclado con
/// aro dorado y cursor de mano.
class DsButton extends StatelessWidget {
  const DsButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = DsButtonKind.secondary,
    this.size = DsButtonSize.normal,
    this.leading,
    this.trailing,
    this.selected = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
    this.accent,
    this.previewStates,
    this.details = const [],
  }) : icon = null;

  /// Botón de ícono (cuadrado). [tooltip] es obligatorio: dice qué hace.
  const DsButton.icon(
    Widget this.icon, {
    super.key,
    required String this.tooltip,
    required this.onPressed,
    this.size = DsButtonSize.normal,
    this.selected = false,
    this.focusNode,
    this.autofocus = false,
    this.accent,
    this.previewStates,
  })  : label = '',
        kind = DsButtonKind.icon,
        leading = null,
        trailing = null,
        details = const [];

  final String label;
  final Widget? icon;
  final Widget? leading;

  /// A la derecha del texto, separado `xs` (p. ej. una insignia `+N`):
  /// suma al ancho, nunca tapa el texto.
  final Widget? trailing;
  final VoidCallback? onPressed;
  final DsButtonKind kind;
  final DsButtonSize size;
  final bool selected;
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Color del texto en vez del principal (p. ej. naranja de aviso).
  final Color? accent;

  /// Estados forzados para mostrarlos quietos (solo la galería).
  final Set<WidgetState>? previewStates;

  /// Líneas de detalle debajo del texto (botón-opción: nombre + qué da).
  /// Con detalle el contenido se alinea a la izquierda y las líneas van
  /// en Detalle secundario (jerarquía por color, design_system.md § 6).
  final List<String> details;

  bool get _compact => size == DsButtonSize.compact;

  /// Padding real: aire libre + borde (Material pinta el borde encima).
  EdgeInsets padding() {
    final b = DsMetrics.controlBorder;
    // Regla (design_system.md § 6): ≥ 8 libres en todos los lados y
    // horizontal mayor que vertical: normal 16 × 8, compacto 12 × 8,
    // ícono 8 (cuadrado).
    final v = DsMetrics.inset + b;
    if (kind == DsButtonKind.icon) return EdgeInsets.all(v);
    final h = UiTheme.space(_compact ? 12 : 16) + b;
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  ButtonStyle style(BuildContext context) {
    final primary = kind == DsButtonKind.primary;
    final ghost = kind == DsButtonKind.ghost;
    Color bg(Set<WidgetState> s) {
      if (s.contains(WidgetState.disabled)) return Colors.transparent;
      final hot =
          s.contains(WidgetState.hovered) || s.contains(WidgetState.pressed);
      if (ghost && !hot && !selected) return Colors.transparent;
      return hot ? DsColors.hover : DsColors.surfaceRaised;
    }

    Color fg(Set<WidgetState> s) {
      if (s.contains(WidgetState.disabled)) return DsColors.textDisabled;
      if (primary) return DsColors.actionPrimary;
      if (selected) return DsColors.selected;
      return accent ?? DsColors.textPrimary;
    }

    BorderSide side(Set<WidgetState> s) {
      final w = DsMetrics.controlBorder;
      if (s.contains(WidgetState.disabled)) {
        return BorderSide(color: DsColors.border, width: w);
      }
      final hot = s.contains(WidgetState.hovered);
      final Color c;
      if (s.contains(WidgetState.pressed) || selected) {
        c = primary ? DsColors.textPrimary : DsColors.selected;
      } else if (primary) {
        c = DsColors.actionPrimary;
      } else if (ghost) {
        c = hot ? DsColors.hoverBorder : Colors.transparent;
      } else {
        c = hot ? DsColors.hoverBorder : DsColors.borderControl;
      }
      return BorderSide(color: c, width: w);
    }

    return ButtonStyle(
      animationDuration: Duration.zero,
      elevation: const WidgetStatePropertyAll(0),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
      padding: WidgetStatePropertyAll(padding()),
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: WidgetStatePropertyAll(DsText.subtitle()),
      backgroundColor: WidgetStateProperty.resolveWith(bg),
      foregroundColor: WidgetStateProperty.resolveWith(fg),
      iconColor: WidgetStateProperty.resolveWith(fg),
      side: WidgetStateProperty.resolveWith(side),
      mouseCursor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.disabled)
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = details.isEmpty
        ? style(context)
        : style(context).copyWith(alignment: Alignment.centerLeft);
    final ps = previewStates;
    final sc = ps == null ? null : WidgetStatesController(ps);
    final Widget labelText = DsGoldText.hasGold(label)
        ? DsGoldText(label)
        : Text(retroText(label));
    final Widget text = details.isEmpty
        ? labelText
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              labelText,
              for (final d in details) ...[
                SizedBox(height: DsSpace.xs),
                Text(retroText(d),
                    style: DsText.detail(onPressed == null
                        ? DsColors.textDisabled
                        : DsColors.textSecondary)),
              ],
            ],
          );
    final Widget child = leading == null && trailing == null
        ? text
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[leading!, SizedBox(width: DsSpace.xs)],
            Flexible(child: text),
            if (trailing != null) ...[SizedBox(width: DsSpace.xs), trailing!],
          ]);

    final Widget button = switch (kind) {
      DsButtonKind.primary => FilledButton(
          statesController: sc,
          onPressed: onPressed,
          style: st,
          focusNode: focusNode,
          autofocus: autofocus,
          child: child),
      DsButtonKind.secondary => OutlinedButton(
          statesController: sc,
          onPressed: onPressed,
          style: st,
          focusNode: focusNode,
          autofocus: autofocus,
          child: child),
      DsButtonKind.ghost => TextButton(
          statesController: sc,
          onPressed: onPressed,
          style: st,
          focusNode: focusNode,
          autofocus: autofocus,
          child: child),
      DsButtonKind.icon => IconButton(
          statesController: sc,
          onPressed: onPressed,
          style: st,
          focusNode: focusNode,
          autofocus: autofocus,
          // El tooltip lo pone el envoltorio de abajo (uno solo).
          icon: DefaultTextStyle.merge(style: DsText.subtitle(), child: icon!)),
    };
    final ringed = ps != null
        ? DsFocusRing(
            focused: ps.contains(WidgetState.focused),
            forced: true,
            child: button)
        : DsFocusScope(child: button);
    final tip = tooltip;
    if (tip == null) return ringed;
    // A gold amount in the reason draws the coin, never "\$".
    return DsGoldText.hasGold(tip)
        ? Tooltip(
            richMessage: TextSpan(children: DsGoldText.spans(tip, null)),
            child: ringed)
        : Tooltip(message: tip, child: ringed);
  }
}
