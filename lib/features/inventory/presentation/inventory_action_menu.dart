import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/theme/ui_theme.dart';

/// Una fila del menú de acciones del inventario (v0.9.7).
class InventoryMenuEntry {
  const InventoryMenuEntry({
    required this.id,
    required this.label,
    this.reason,
    this.note,
    this.color,
    this.onTap,
  });

  /// Sufijo de la clave (`inv-<id>` en el menú fijo del detalle,
  /// `inv-ctx-<id>` en el del clic derecho).
  final String id;
  final String label;

  /// Motivo en una línea si está desactivada (gris).
  final String? reason;

  /// Lo que se recibe o cuesta (p. ej. `Recibís ₵12`), en `dim`.
  final String? note;
  final Color? color;
  final VoidCallback? onTap;

  bool get enabled => reason == null && onTap != null;
}

/// Lista compacta de acciones: una línea por acción, las desactivadas en
/// gris con el motivo debajo (docs/specs/panels.md § "Inventario ›
/// Acciones"). La misma lista va en el detalle y en el menú del clic
/// derecho ([InventoryContextMenu]).
class InventoryActionList extends StatelessWidget {
  const InventoryActionList(
      {super.key,
      required this.entries,
      this.keyPrefix = 'inv-',
      this.onDone});

  final List<InventoryMenuEntry> entries;
  final String keyPrefix;

  /// Después de elegir (cierra el menú flotante).
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in entries)
            InventoryActionRow(
                key: ValueKey('$keyPrefix${e.id}'),
                entry: e,
                onDone: onDone),
        ],
      );
}

class InventoryActionRow extends StatefulWidget {
  const InventoryActionRow({super.key, required this.entry, this.onDone});

  final InventoryMenuEntry entry;
  final VoidCallback? onDone;

  @override
  State<InventoryActionRow> createState() => _RowState();
}

class _RowState extends State<InventoryActionRow> {
  bool _hover = false;

  void _tap() {
    final e = widget.entry;
    if (!e.enabled) return;
    widget.onDone?.call();
    e.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final on = e.enabled;
    final label = protoColor(
        on ? (e.color ?? ProtoColors.ink) : ProtoColors.dim,
        protoEsc(e.label));
    final note = e.note == null || !on
        ? ''
        : ' ${protoColor(ProtoColors.dim, protoEsc(e.note!))}';
    final reason = on
        ? ''
        : '<br>${protoColor(ProtoColors.dim, protoEsc(e.reason ?? ''))}';
    return FocusableActionDetector(
      enabled: on,
      mouseCursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (h) => setState(() => _hover = h),
      onShowFocusHighlight: (h) => setState(() => _hover = h),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _tap()),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: RetroTheme.minButtonInset,
              vertical: UiTheme.space(4)),
          decoration: BoxDecoration(
            color: _hover && on ? ProtoColors.buttonHover : null,
            border: Border(
                left: BorderSide(
                    color: _hover && on ? ProtoColors.gold : Colors.transparent,
                    width: RetroTheme.thinBorderWidth)),
          ),
          child: ProtoText('$label$note$reason'),
        ),
      ),
    );
  }
}

/// Menú flotante (clic derecho o botón ACCIONES): la misma lista en una
/// caja sobre todo, en [at] (coordenadas globales), que se cierra al
/// elegir, con `Esc` o con un clic afuera.
class InventoryContextMenu {
  InventoryContextMenu._();

  static OverlayEntry? _entry;

  static bool get isOpen => _entry != null;

  static void close() {
    _entry?.remove();
    _entry = null;
  }

  static void show(BuildContext context, Offset at,
      {required List<InventoryMenuEntry> entries, String? title}) {
    close();
    RetroHoverCard.dismissAll();
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (ctx) => _MenuLayer(at: at, entries: entries, title: title),
    );
    overlay.insert(_entry!);
  }
}

class _MenuLayer extends StatelessWidget {
  const _MenuLayer({required this.at, required this.entries, this.title});

  final Offset at;
  final List<InventoryMenuEntry> entries;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          key: const ValueKey('inv-ctx-scrim'),
          behavior: HitTestBehavior.opaque,
          onTap: InventoryContextMenu.close,
          onSecondaryTap: InventoryContextMenu.close,
        ),
      ),
      CustomSingleChildLayout(
        delegate: _MenuLayout(at, size),
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, e) {
            if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
              InventoryContextMenu.close();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            key: const ValueKey('inv-ctx-menu'),
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 340),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: ProtoColors.bg,
              border: Border.all(
                  color: ProtoColors.buttonBorder,
                  width: UiTheme.buttonBorderWidth),
              boxShadow: const [
                BoxShadow(
                    color: ProtoColors.shadow,
                    offset: Offset(0, 4),
                    blurRadius: 18),
              ],
            ),
            child: DefaultTextStyle(
              style: RetroHoverCard.textStyle,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                      child: ProtoText(title!),
                    ),
                  InventoryActionList(
                      entries: entries,
                      keyPrefix: 'inv-ctx-',
                      onDone: InventoryContextMenu.close),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(this.at, this.screen);

  final Offset at;
  final Size screen;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) =>
      BoxConstraints.loose(Size(c.maxWidth - 16, c.maxHeight - 16));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = at.dx.clamp(8.0, (size.width - 8 - child.width).clamp(8.0, double.infinity));
    final y = at.dy.clamp(8.0, (size.height - 8 - child.height).clamp(8.0, double.infinity));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) => old.at != at || old.screen != screen;
}
