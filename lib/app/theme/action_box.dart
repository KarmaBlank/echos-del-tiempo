import 'package:material_ui/material_ui.dart';

import 'proto_colors.dart';
import 'retro_theme.dart';

/// Decoración de botón del tema (docs/specs/ui_style.md § "Toda acción se
/// ve como botón"): fondo `button` y borde fino `buttonBorder`; con hover
/// o foco `buttonHover` / `buttonHoverBorder`; elegida, borde `gold`.
/// Desactivada: sin fondo ni borde.
BoxDecoration actionDecoration(
    {required bool enabled, bool hot = false, bool selected = false}) {
  if (!enabled && !selected) {
    return BoxDecoration(
      border: Border.all(
          color: hot ? ProtoColors.buttonBorder : Colors.transparent,
          width: RetroTheme.thinBorderWidth),
    );
  }
  return BoxDecoration(
    color: hot ? ProtoColors.buttonHover : ProtoColors.button,
    border: Border.all(
        color: selected
            ? ProtoColors.gold
            : hot
                ? ProtoColors.buttonHoverBorder
                : ProtoColors.buttonBorder,
        width: RetroTheme.thinBorderWidth),
  );
}

/// Caja clickeable con aspecto de botón para acciones que no son un
/// `ElevatedButton` (opciones de un selector, `×`, `−` / `+`...). Cursor de
/// mano, hover / foco resaltado y `Enter` / `Espacio` la activan; con
/// [onTap] `null` queda desactivada (sin fondo ni borde, texto `dim`).
class ActionBox extends StatefulWidget {
  const ActionBox({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(RetroTheme.minButtonInset),
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool selected;

  @override
  State<ActionBox> createState() => _ActionBoxState();
}

class _ActionBoxState extends State<ActionBox> {
  bool _hover = false, _focus = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = widget.child;
    if (!enabled) {
      child = DefaultTextStyle.merge(
          style: const TextStyle(color: ProtoColors.dim), child: child);
    }
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call()),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: widget.padding,
          decoration: actionDecoration(
              enabled: enabled,
              hot: enabled && (_hover || _focus),
              selected: widget.selected),
          child: child,
        ),
      ),
    );
  }
}

/// Link de texto plegable (`▸ Más`, `[+]`): sin caja, pero con cursor de
/// mano y el texto en `buttonHoverBorder` con hover o foco.
class ActionLink extends StatefulWidget {
  const ActionLink({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<ActionLink> createState() => _ActionLinkState();
}

class _ActionLinkState extends State<ActionLink> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
        enabled: widget.onTap != null,
        mouseCursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        onShowFocusHighlight: (v) => setState(() => _hot = v),
        onShowHoverHighlight: (v) => setState(() => _hot = v),
        actions: {
          ActivateIntent:
              CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call()),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: _hot && widget.onTap != null
              ? DefaultTextStyle.merge(
                  style: const TextStyle(
                      color: ProtoColors.buttonHoverBorder,
                      decoration: TextDecoration.underline),
                  child: widget.child)
              : widget.child,
        ),
      );
}
