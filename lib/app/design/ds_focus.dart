import 'package:material_ui/material_ui.dart';

import 'ds_tokens.dart';

/// Aro de foco del sistema (design_system.md § 5): 2 px [DsColors.focus]
/// por fuera, separado 2 px, solo con foco de TECLADO (no al clickear).
/// Siempre reserva el lugar: prenderlo no mueve nada.
class DsFocusRing extends StatelessWidget {
  const DsFocusRing(
      {super.key,
      required this.focused,
      required this.child,
      this.forced = false});

  final bool focused;

  /// Mostrarlo aunque el foco no venga del teclado (galería).
  final bool forced;
  final Widget child;

  static const extent = DsMetrics.focusWidth + DsMetrics.focusGap;

  /// El foco viene del teclado (no del mouse ni del tacto).
  static bool get keyboard =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  Widget build(BuildContext context) {
    final on = focused && (forced || keyboard);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
            color: on ? DsColors.focus : Colors.transparent,
            width: DsMetrics.focusWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DsMetrics.focusGap),
        child: child,
      ),
    );
  }
}

/// Envuelve un control estándar y le pone [DsFocusRing] cuando él (o algo
/// adentro) tiene el foco.
class DsFocusScope extends StatefulWidget {
  const DsFocusScope({super.key, required this.child});

  final Widget child;

  @override
  State<DsFocusScope> createState() => _DsFocusScopeState();
}

class _DsFocusScopeState extends State<DsFocusScope> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => _focused = f),
        child: DsFocusRing(focused: _focused, child: widget.child),
      );
}

/// Base de los elementos clickeables que no son botones (tarjetas, filas):
/// un `InkWell` sin salpicadura con hover, foco, presionado, cursor de mano
/// y `Enter` / `Espacio`. [builder] recibe el estado.
class DsPressable extends StatefulWidget {
  const DsPressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, DsPressState state) builder;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<DsPressable> createState() => _DsPressableState();
}

/// Estado visual de un [DsPressable].
class DsPressState {
  const DsPressState(
      {this.hovered = false,
      this.focused = false,
      this.pressed = false,
      this.enabled = true});

  final bool hovered;
  final bool focused;
  final bool pressed;
  final bool enabled;

  /// Hover o foco de teclado: se resalta.
  bool get hot => enabled && (hovered || (focused && DsFocusRing.keyboard));
}

class _DsPressableState extends State<DsPressable> {
  bool _hover = false;
  bool _focus = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final state = DsPressState(
        hovered: _hover, focused: _focus, pressed: _down, enabled: enabled);
    return DsFocusRing(
      focused: _focus,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hover = h),
          onFocusChange: (f) => setState(() => _focus = f),
          onHighlightChanged: (d) => setState(() => _down = d),
          mouseCursor:
              enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: widget.builder(context, state),
        ),
      ),
    );
  }
}
