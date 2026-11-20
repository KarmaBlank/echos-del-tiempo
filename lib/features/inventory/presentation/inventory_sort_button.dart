import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../game_engine/models/inventory_sort.dart';

/// `ORDENAR ▼` del inventario (v0.5.1, loot.md § 17.2, panels.md §
/// "Inventario"): abre un menú con las claves de [InventorySortKey]
/// (`inv-sort-<clave>`); elegir una llama a [onSort] y lo cierra. `Esc`
/// o un clic afuera lo cierran sin ordenar; las flechas recorren las
/// opciones y `Enter` elige. Con [reason] queda deshabilitado.
class InventorySortButton extends StatefulWidget {
  const InventorySortButton({
    super.key,
    required this.onSort,
    this.reason,
    this.current,
    this.initiallyOpen = false,
  });

  final ValueChanged<InventorySortKey> onSort;
  final String? reason;

  /// Última clave usada (borde dorado en el menú).
  final InventorySortKey? current;

  /// Abre el menú al aparecer (capturas y tests).
  final bool initiallyOpen;

  @override
  State<InventorySortButton> createState() => _InventorySortButtonState();
}

class _InventorySortButtonState extends State<InventorySortButton> {
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

  void _choose(InventorySortKey k) {
    _close();
    widget.onSort(k);
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
              key: const ValueKey('inv-sort-menu'),
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
                      for (final (i, k) in InventorySortKey.values.indexed)
                        Padding(
                          padding:
                              EdgeInsets.only(top: i == 0 ? 0 : DsSpace.xs),
                          child: DsButton(k.label,
                              key: ValueKey('inv-sort-${k.name}'),
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
            child: DsButton('ORDENAR ▼',
                key: const ValueKey('inv-sort'),
                size: DsButtonSize.compact,
                selected: _menu.isShowing,
                tooltip: widget.reason,
                onPressed: widget.reason == null ? _toggle : null),
          ),
        ),
      );
}
