import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_type.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../game_engine/rules/progression_rules.dart';
import 'clean_selection.dart' show CleanCellMark;
import 'item_widgets.dart' hide PixelIcon;

// Sistema de diseño atómico (docs/specs/design_system.md § "Estructura
// atómica"): todo lo de este archivo es presentacional. Recibe datos ya
// calculados (qué hay, si está elegida, si coincide con la búsqueda) y
// callbacks; la lógica de juego queda en la pantalla que lo usa.

/// Marca NUEVO de una casilla (loot.md § 17.4): franja `gold` abajo.
class NewItemTag extends StatelessWidget {
  const NewItemTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        color: ProtoColors.bg.withValues(alpha: 0.85),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        // Siempre en una línea dentro de la casilla (44 px).
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('NUEVO',
              maxLines: 1,
              softWrap: false,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                  fontFamily: RetroType.pixelFamily,
                  fontSize: 8,
                  height: 1,
                  color: ProtoColors.gold)),
        ),
      );
}

/// Estado visual de una casilla, ya resuelto por la pantalla.
class ItemSlotData {
  const ItemSlotData({
    this.content,
    this.selected = false,
    this.highlight = false,
    this.buildMatch = false,
    this.fresh = false,
    this.dimmed = false,
    this.picked = false,
    this.locked = false,
  });

  final CellContent? content;

  /// Borde dorado de elegida.
  final bool selected;

  /// Fondo de destino posible (arrastre, MOVER).
  final bool highlight;

  /// ★ de tu build.
  final bool buildMatch;

  /// Marca NUEVO.
  final bool fresh;

  /// No coincide con la búsqueda: atenuada.
  final bool dimmed;

  /// Selección múltiple: `✓` (elegida) o candado (no se puede).
  final bool picked;
  final bool locked;
}

/// Molécula casilla de ítem: [ItemCell] (rareza, ícono, ★) con la marca
/// NUEVO, la atenuación de búsqueda y la marca de selección múltiple.
class ItemSlot extends StatelessWidget {
  const ItemSlot({
    super.key,
    required this.rules,
    required this.data,
    this.size = 44,
    this.freshKey,
  });

  final ProgressionRules rules;
  final ItemSlotData data;
  final double size;

  /// Clave de la marca NUEVO (para tests).
  final Key? freshKey;

  @override
  Widget build(BuildContext context) {
    Widget w = ItemCell(
      rules: rules,
      content: data.content,
      size: size,
      selected: data.selected,
      highlight: data.highlight,
      buildMatch: data.buildMatch,
    );
    if (data.picked || data.locked) {
      w = CleanCellMark(picked: data.picked, locked: data.locked, child: w);
    }
    if (data.content != null && (data.fresh || data.dimmed)) {
      w = Stack(children: [
        Opacity(opacity: data.dimmed ? 0.25 : 1, child: w),
        if (data.fresh)
          Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(child: NewItemTag(key: freshKey))),
      ]);
    }
    return w;
  }
}

/// Campo de búsqueda de una grilla: Esc con texto lo limpia (sin texto,
/// el Esc sigue de largo hacia la pantalla).
class ItemGridSearch {
  const ItemGridSearch({
    required this.controller,
    required this.onChanged,
    this.hint = 'BUSCAR',
    this.fieldKey,
    this.width = 320,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final Key? fieldKey;
  final double width;
}

/// Organismo DsItemGrid: grilla de casillas de ítem con buscador
/// opcional, cursor de teclado (flechas, Enter), clic, clic derecho
/// (menú contextual) y tooltip. Lo usan INVENTARIO, ALIJO, FUSIÓN y
/// FORJA (design_system.md § "Estructura atómica").
///
/// Presentacional: [slot] da el estado de cada casilla, [tip] envuelve
/// con la ficha (normalmente `itemHoverTip`) y [decorate] permite a la
/// pantalla agregar arrastre u otros envoltorios sin tocar la grilla.
class DsItemGrid extends StatelessWidget {
  const DsItemGrid({
    super.key,
    required this.rules,
    required this.count,
    required this.slot,
    this.columns,
    this.cellSize = 44,
    this.gap = 4,
    this.width,
    this.cellKey,
    this.focusKeyPrefix,
    this.freshKey,
    this.onTap,
    this.onMenu,
    this.onActivate,
    this.onFocusCell,
    this.tip,
    this.decorate,
    this.search,
    this.empty,
  });

  final ProgressionRules rules;
  final int count;
  final ItemSlotData Function(int i) slot;

  /// Columnas para las flechas (`null`: las que entren en el ancho).
  final int? columns;
  final double cellSize;
  final double gap;
  final double? width;
  final Key Function(int i)? cellKey;
  final String? focusKeyPrefix;
  final Key Function(int i)? freshKey;
  final ValueChanged<int>? onTap;

  /// Clic derecho en [i] (posición global).
  final void Function(int i, Offset at)? onMenu;

  /// Enter / Espacio (por defecto, lo mismo que [onTap]).
  final ValueChanged<int>? onActivate;
  final ValueChanged<int>? onFocusCell;
  final Widget Function(int i, Widget child, bool focused)? tip;
  final Widget Function(int i, Widget child)? decorate;
  final ItemGridSearch? search;

  /// Texto si no hay casillas (p. ej. "Ninguna arma coincide").
  final String? empty;

  Widget _cell(int i, bool focused) {
    final d = slot(i);
    Widget w =
        ItemSlot(rules: rules, data: d, size: cellSize, freshKey: freshKey?.call(i));
    if (d.content != null && tip != null) w = tip!(i, w, focused);
    w = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : () => onTap!(i),
        onSecondaryTapUp: onMenu == null || d.content == null
            ? null
            : (e) => onMenu!(i, e.globalPosition),
        child: w);
    if (decorate != null) w = decorate!(i, w);
    return KeyedSubtree(key: cellKey?.call(i), child: w);
  }

  Widget _grid(int cols) => FocusGrid(
        count: count,
        columns: cols,
        spacing: gap,
        width: width,
        keyPrefix: focusKeyPrefix,
        cell: (_, i, focused) => _cell(i, focused),
        onFocusCell: onFocusCell,
        onActivate: onActivate ?? onTap,
      );

  @override
  Widget build(BuildContext context) {
    final s = search;
    final Widget grid = count == 0 && empty != null
        ? Text(empty!, style: DsText.detail())
        : columns != null
            ? _grid(columns!)
            : LayoutBuilder(builder: (context, box) {
                final w = width ?? box.maxWidth;
                final cols = w.isFinite
                    ? ((w + gap) / (cellSize + gap)).floor().clamp(1, 99)
                    : 8;
                return _grid(cols);
              });
    if (s == null) return grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, e) {
            if (e is KeyDownEvent &&
                e.logicalKey == LogicalKeyboardKey.escape &&
                s.controller.text.isNotEmpty) {
              s.controller.clear();
              s.onChanged('');
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: DsSearchField(
            key: s.fieldKey,
            hint: s.hint,
            width: s.width,
            controller: s.controller,
            onChanged: s.onChanged,
          ),
        ),
        SizedBox(height: DsSpace.xs),
        grid,
      ],
    );
  }
}
