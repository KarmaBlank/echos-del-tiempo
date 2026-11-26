import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/theme/ui_theme.dart';

/// Una fila del menú de acciones del inventario (v0.9.7).
class InventoryMenuEntry {
  const InventoryMenuEntry({
    required this.id,
    required this.label,
    this.reason,
    this.shortReason,
    this.note,
    this.color,
    this.onTap,
  });

  /// Sufijo de la clave (`inv-<id>`).
  final String id;
  final String label;

  /// Motivo completo si está desactivada (gris); va en el tooltip.
  final String? reason;

  /// Motivo corto en la misma línea ("equipada", "sin compañeros"); si
  /// falta, se usa [reason].
  final String? shortReason;

  /// Lo que se recibe o cuesta (p. ej. `Recibís ₵12`), en `dim`.
  final String? note;
  final Color? color;
  final VoidCallback? onTap;

  bool get enabled => reason == null && onTap != null;
}

/// Lista compacta de acciones: una línea por acción; las desactivadas en
/// gris con el motivo corto en la misma línea y el completo en el
/// tooltip (docs/specs/panels.md § "Inventario › Acciones").
class InventoryActionList extends StatelessWidget {
  const InventoryActionList(
      {super.key,
      required this.entries,
      this.keyPrefix = 'inv-',
      this.onDone,
      this.autofocusFirst = false});

  final List<InventoryMenuEntry> entries;
  final String keyPrefix;

  /// Después de elegir (cierra el menú flotante).
  final VoidCallback? onDone;

  /// El cursor de teclado arranca en la primera acción disponible.
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    final first = autofocusFirst ? entries.indexWhere((e) => e.enabled) : -1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          InventoryActionRow(
              key: ValueKey('$keyPrefix${entries[i].id}'),
              entry: entries[i],
              autofocus: i == first,
              onDone: onDone),
      ],
    );
  }
}

class InventoryActionRow extends StatefulWidget {
  const InventoryActionRow(
      {super.key, required this.entry, this.onDone, this.autofocus = false});

  final InventoryMenuEntry entry;
  final VoidCallback? onDone;
  final bool autofocus;

  @override
  State<InventoryActionRow> createState() => _RowState();
}

class _RowState extends State<InventoryActionRow> {
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
    final tail = on ? e.note : (e.shortReason ?? e.reason);
    final full = e.reason;
    // Fila de una línea del sistema de diseño (design_system.md § 6): sin
    // borde, fondo con hover / foco; la desactivada atenuada con el
    // motivo corto al lado y el completo en el tooltip.
    return KeyedSubtree(
      key: ValueKey(on ? 'menu-row-on' : 'menu-row-off'),
      child: DsListRow(
        title: retroText(e.label),
        titleColor: e.color,
        detail: tail == null ? null : retroText(tail),
        enabled: on,
        autofocus: widget.autofocus,
        onTap: on ? _tap : null,
        tooltip: !on && full != null && full != tail
            ? DsTooltipCard(title: retroText(e.label), children: [
                Text(retroText(full), style: DsText.detail(DsColors.danger)),
              ])
            : null,
      ),
    );
  }
}

/// Menú flotante (clic derecho o Enter sobre la casilla elegida): una línea
/// por acción, ancho ajustado al contenido, junto a [at] (coordenadas
/// globales) sin salirse de la pantalla. Se cierra al elegir, con `Esc`
/// o con un clic afuera.
class InventoryContextMenu {
  InventoryContextMenu._();

  static OverlayEntry? _entry;

  static bool get isOpen => _entry != null;

  static void close() {
    RetroHoverCard.suppressed = false;
    _entry?.remove();
    _entry = null;
  }

  static void show(BuildContext context, Offset at,
      {required List<InventoryMenuEntry> entries, String? title, Rect? avoid}) {
    close();
    RetroHoverCard.dismissAll();
    RetroHoverCard.suppressed = true;
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (ctx) =>
          _MenuLayer(at: at, entries: entries, title: title, avoid: avoid),
    );
    overlay.insert(_entry!);
  }
}

class _MenuLayer extends StatelessWidget {
  const _MenuLayer(
      {required this.at, required this.entries, this.title, this.avoid});

  final Offset at;

  /// Rect global que el menú no tapa si puede (el buscador).
  final Rect? avoid;
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
        delegate: _MenuLayout(at, size, avoid),
        child: Focus(
          onKeyEvent: (_, e) {
            if (e is KeyDownEvent &&
                e.logicalKey == LogicalKeyboardKey.escape) {
              InventoryContextMenu.close();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: FocusScope(
            autofocus: true,
            child: IntrinsicWidth(
              child: Container(
                key: const ValueKey('inv-ctx-menu'),
                padding: EdgeInsets.symmetric(vertical: UiTheme.space(4)),
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
                      // Encabezado no clickeable, separado con una línea.
                      if (title != null) ...[
                        Padding(
                          key: const ValueKey('inv-ctx-title'),
                          padding: const EdgeInsets.fromLTRB(
                              RetroTheme.minButtonInset,
                              2,
                              RetroTheme.minButtonInset,
                              4),
                          child: DefaultTextStyle.merge(
                              style: const TextStyle(color: DsColors.selected),
                              child: ProtoText(title!)),
                        ),
                        Container(
                            height: 1,
                            margin: const EdgeInsets.only(bottom: 4),
                            color: ProtoColors.panelBorder),
                      ],
                      InventoryActionList(
                          entries: entries,
                          autofocusFirst: true,
                          onDone: InventoryContextMenu.close),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(this.at, this.screen, [this.avoid]);

  final Offset at;
  final Size screen;
  final Rect? avoid;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) =>
      BoxConstraints.loose(
          Size(math.min(c.maxWidth - 16, 360), c.maxHeight - 16));

  @override
  Offset getPositionForChild(Size size, Size child) {
    // Junto al cursor; si no entra abajo se abre hacia arriba (y si no
    // entra a la derecha, hacia la izquierda) en vez de taparlo.
    var ax = at.dx + 2, ay = at.dy + 2;
    if (ay + child.height > size.height - 8 && at.dy - child.height >= 8) {
      ay = at.dy - child.height;
    }
    if (ax + child.width > size.width - 8 && at.dx - child.width >= 8) {
      ax = at.dx - child.width;
    }
    // Si tapa [avoid] (el buscador), se corre:
    final av = avoid;
    if (av != null && (Offset(ax, ay) & child).overlaps(av)) {
      // Debajo del buscador (sobre la grilla, sin tapar ESTADÍSTICAS);
      // si ahí no entra, a su derecha.
      if (av.bottom + 4 + child.height <= size.height - 8) {
        ay = av.bottom + 4;
      } else {
        ax = av.right + 4;
      }
    }
    final x = ax.clamp(
        8.0, (size.width - 8 - child.width).clamp(8.0, double.infinity));
    final y = ay.clamp(
        8.0, (size.height - 8 - child.height).clamp(8.0, double.infinity));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.at != at || old.screen != screen || old.avoid != avoid;
}
