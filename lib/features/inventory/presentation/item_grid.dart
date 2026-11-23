import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_type.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../game_engine/rules/progression_rules.dart';
import 'clean_selection.dart' show CleanCellMark;
import 'inventory_strings.dart';
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(invStrings(context).t('ui.inventory.item.new_tag'),
              maxLines: 1,
              softWrap: false,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
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

/// Molécula: la equipada fija arriba de una lista de armas, con la marca
/// `EQUIPADA` (ui_minimal.md § 3). La usan [DsWeaponList] y las listas de
/// catálogo (COMPRAR), que tienen filas en vez de casillas.
class PinnedEquippedRow extends StatelessWidget {
  const PinnedEquippedRow({super.key, required this.cell, this.note});

  final Widget cell;

  /// Una línea opcional al lado (p. ej. el nombre).
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: DsSpace.xs),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          cell,
          SizedBox(width: DsSpace.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(retroText(invStrings(context).t('ui.inventory.bag.equipped')),
                    style: DsText.subtitle()),
                if (note case final n?)
                  Text(n, style: DsText.detail()),
              ],
            ),
          ),
        ]),
      );
}

/// Campo de búsqueda de una grilla: Esc con texto lo limpia (sin texto,
/// el Esc sigue de largo hacia la pantalla).
class ItemGridSearch {
  const ItemGridSearch({
    required this.controller,
    required this.onChanged,
    this.hint,
    this.fieldKey,
    this.width = 320,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  /// `null` = the generic search hint.
  final String? hint;
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
    this.pinned,
    this.pinnedKey,
  });

  final ProgressionRules rules;
  final int count;

  /// Casilla fija arriba de la grilla con la marca `EQUIPADA`
  /// (ui_minimal.md § 3): el índice sale de la grilla y se dibuja solo,
  /// siempre visible aunque no coincida con la búsqueda.
  final int? pinned;
  final Key? pinnedKey;
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

  /// Índice real de la casilla [j] de la grilla (sin la fijada).
  int _at(int j) => pinned == null || j < pinned! ? j : j + 1;

  int get _gridCount =>
      pinned != null && pinned! >= 0 && pinned! < count ? count - 1 : count;

  Widget _grid(int cols) {
    final act = onActivate ?? onTap;
    return FocusGrid(
      count: _gridCount,
      columns: cols,
      spacing: gap,
      width: width,
      keyPrefix: focusKeyPrefix,
      cell: (_, j, focused) => _cell(_at(j), focused),
      onFocusCell: onFocusCell == null ? null : (j) => onFocusCell!(_at(j)),
      onActivate: act == null ? null : (j) => act(_at(j)),
    );
  }

  Widget? _pinnedRow() {
    final i = pinned;
    if (i == null || i < 0 || i >= count) return null;
    // Su propia grilla de 1 (foco, Enter y tooltip iguales al resto).
    final act = onActivate ?? onTap;
    return PinnedEquippedRow(
        key: pinnedKey,
        cell: SizedBox(
          width: cellSize,
          child: FocusGrid(
            count: 1,
            columns: 1,
            spacing: gap,
            width: cellSize,
            keyPrefix: focusKeyPrefix == null ? null : '${focusKeyPrefix}pin-',
            cell: (_, __, focused) => _cell(i, focused),
            onFocusCell: onFocusCell == null ? null : (_) => onFocusCell!(i),
            onActivate: act == null ? null : (_) => act(i),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final s = search;
    final pin = _pinnedRow();
    final Widget grid = _gridCount == 0 && pin == null && empty != null
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
    final body = pin == null
        ? grid
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [pin, if (_gridCount > 0) grid]);
    if (s == null) return body;
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
            hint: s.hint ?? invStrings(context).t('ui.inventory.item.search'),
            width: s.width,
            controller: s.controller,
            onChanged: s.onChanged,
          ),
        ),
        SizedBox(height: DsSpace.xs),
        body,
      ],
    );
  }
}

/// Organismo DsWeaponList (ui_minimal.md § 3): la ÚNICA plantilla de
/// toda lista de armas (FUSIÓN destino y origen, FORJA, ALIJO,
/// trasladar). Es un [DsItemGrid] con el buscador siempre presente y la
/// equipada fija arriba con la marca `EQUIPADA` ([equipped] = su índice
/// en la lista; `null` si la lista no la tiene).
class DsWeaponList extends StatelessWidget {
  const DsWeaponList({
    super.key,
    required this.rules,
    required this.count,
    required this.slot,
    required this.search,
    required this.equipped,
    this.keyPrefix = 'wl-',
    this.cellKey,
    this.focusKeyPrefix,
    this.onTap,
    this.onFocusCell,
    this.tip,
    this.decorate,
    this.empty,
    this.width,
  });

  final ProgressionRules rules;
  final int count;
  final ItemSlotData Function(int i) slot;
  final ItemGridSearch search;
  final int? equipped;

  /// Prefijo de la clave de la fila fijada (`<prefijo>pinned`).
  final String keyPrefix;
  final Key Function(int i)? cellKey;
  final String? focusKeyPrefix;
  final ValueChanged<int>? onTap;
  final ValueChanged<int>? onFocusCell;
  final Widget Function(int i, Widget child, bool focused)? tip;
  final Widget Function(int i, Widget child)? decorate;
  final String? empty;
  final double? width;

  @override
  Widget build(BuildContext context) => DsItemGrid(
        rules: rules,
        count: count,
        slot: slot,
        search: search,
        pinned: equipped,
        pinnedKey: ValueKey('${keyPrefix}pinned'),
        cellKey: cellKey,
        focusKeyPrefix: focusKeyPrefix,
        onTap: onTap,
        onFocusCell: onFocusCell,
        tip: tip,
        decorate: decorate,
        empty: empty,
        width: width,
      );
}
