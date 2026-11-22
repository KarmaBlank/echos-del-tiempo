import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/menu_focus.dart';
import 'ds_button.dart';
import 'ds_tokens.dart';

/// Botón `<label> ▼` que abre un menú de opciones (docs/specs/
/// design_system.md, molécula). Elegir una llama a [onChanged] y lo
/// cierra; `Esc` o un clic afuera lo cierran sin elegir; las flechas
/// recorren las opciones y `Enter` elige. Con [reason] queda
/// deshabilitado (gris, con el motivo de tooltip). [current] lleva borde
/// dorado en el menú.
class DsMenuButton<T> extends StatefulWidget {
  const DsMenuButton({
    super.key,
    required this.label,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
    this.current,
    this.reason,
    this.buttonKey,
    this.menuKey,
    this.optionKey,
    this.initiallyOpen = false,
  });

  final String label;
  final List<T> options;
  final String Function(T) optionLabel;
  final ValueChanged<T> onChanged;
  final T? current;
  final String? reason;
  final Key? buttonKey;
  final Key? menuKey;
  final Key? Function(T)? optionKey;

  /// Abre el menú al aparecer (capturas y tests).
  final bool initiallyOpen;

  @override
  State<DsMenuButton<T>> createState() => _DsMenuButtonState<T>();
}

class _DsMenuButtonState<T> extends State<DsMenuButton<T>> {
  final _menu = OverlayPortalController();
  final _link = LayerLink();
  final _group = Object();

  @override
  void initState() {
    super.initState();
    if (widget.initiallyOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open();
      });
    }
  }

  void _open() {
    _menu.show();
    setState(() {});
  }

  void _close() {
    if (!_menu.isShowing) return;
    _menu.hide();
    setState(() {});
  }

  void _toggle() => _menu.isShowing ? _close() : _open();

  void _choose(T k) {
    _close();
    widget.onChanged(k);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowDown) {
      focused.nextFocus();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      focused.previousFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _menuBox() => TapRegion(
        groupId: _group,
        onTapOutside: (_) => _close(),
        child: Focus(
          onKeyEvent: _onKey,
          skipTraversal: true,
          canRequestFocus: false,
          child: FocusTraversalGroup(
            child: Container(
              key: widget.menuKey,
              padding: EdgeInsets.all(DsSpace.xs),
              decoration: BoxDecoration(
                color: DsColors.background,
                border: Border.all(
                    color: DsColors.borderControl,
                    width: DsMetrics.controlBorder),
              ),
              // Al abrir, el cursor va a la primera opción.
              child: InitialFocus(
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, k) in widget.options.indexed)
                        Padding(
                          padding:
                              EdgeInsets.only(top: i == 0 ? 0 : DsSpace.xs),
                          child: DsButton(widget.optionLabel(k),
                              key: widget.optionKey?.call(k),
                              kind: DsButtonKind.ghost,
                              size: DsButtonSize.compact,
                              selected: widget.current == k,
                              onPressed: () => _choose(k)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _menu,
          overlayChildBuilder: (_) => Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              offset: const Offset(0, 4),
              child: _menuBox(),
            ),
          ),
          child: TapRegion(
            groupId: _group,
            child: DsButton('${widget.label} ▼',
                key: widget.buttonKey,
                size: DsButtonSize.compact,
                selected: _menu.isShowing,
                tooltip: widget.reason,
                onPressed: widget.reason == null ? _toggle : null),
          ),
        ),
      );
}
