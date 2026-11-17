import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../domain/item_text.dart';
import 'item_widgets.dart';
import 'shop_sections.dart';

/// Pestaña INVENTARIO del personaje (tecla I): grilla de 8 × 5 con la
/// equipada aparte, mover arrastrando o con MOVER, ficha y comparación,
/// EQUIPAR / TIRAR / DAR A y los inventarios de los compañeros en solo
/// lectura. Ver docs/specs/panels.md § "Inventario".
class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key, required this.shop, this.pending = const {}});

  final ShopContext shop;

  /// Reparto de puntos sin confirmar (colorea requisitos y equipar).
  final Map<Attribute, int> pending;

  static const cell = 44.0;
  static const gap = 4.0;
  static const gridWidth =
      InventoryRules.columns * cell + (InventoryRules.columns - 1) * gap;

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  /// Dueño del inventario que se ve (`null` = el local).
  String? _owner;

  /// Token elegido (uid de arma o pila).
  String? _sel;

  /// Casilla de origen en modo MOVER.
  int? _moveFrom;

  /// Casilla del token elegido (para MOVER).
  int? _selCell;
  int _count = 1;
  bool _confirmDrop = false;

  ShopContext get shop => widget.shop;

  CellContent? _content(PlayerProfile p, String? token) {
    if (token == null) return null;
    final st = StackKind.byToken(token);
    if (st != null) {
      final n = InventoryRules.stackCount(p, st);
      return n > 0 ? CellContent.stack(st, n) : null;
    }
    final it = p.itemByUid(token);
    return it == null ? null : CellContent.item(it);
  }

  String _tooltip(PlayerProfile viewer, CellContent c, PlayerAttributes attrs) {
    final it = c.item;
    if (it != null) {
      return itemTooltipMarkup(shop.rules, it,
          level: viewer.level, attributes: attrs);
    }
    return stackTooltipMarkup(c.stack!, c.count);
  }

  void _select(String token, int? cell) => setState(() {
        if (_sel != token) _count = 1;
        _sel = token;
        _selCell = cell;
        _confirmDrop = false;
      });

  @override
  Widget build(BuildContext context) {
    final view = shop.view;
    final me = view.me!;
    final mates = [
      for (final pl in view.session.playerList)
        if (pl.id != view.localId) pl,
    ];
    final owner = view.session.players[_owner] ?? me;
    final mine = owner.id == me.id;
    final p = owner.profile;
    final attrs = me.profile.attributes.add(widget.pending);
    final layout = InventoryRules.layout(p);
    // Selección por defecto: la equipada.
    if (_content(p, _sel) == null) {
      _sel = p.equippedUid;
      _selCell = null;
      _confirmDrop = false;
    }
    final sel = _content(p, _sel);

    final owners = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        PanelButton('TÚ',
            key: ValueKey('inv-owner-${me.id}'),
            selected: mine,
            onPressed: () => setState(() {
                  _owner = null;
                  _sel = null;
                  _moveFrom = null;
                })),
        for (final m in mates)
          PanelButton(m.name.toUpperCase(),
              key: ValueKey('inv-owner-${m.id}'),
              selected: owner.id == m.id,
              onPressed: () => setState(() {
                    _owner = m.id;
                    _sel = null;
                    _moveFrom = null;
                  })),
      ],
    );

    Widget cellAt(int i) {
      final token = layout.cells[i];
      final c = _content(p, token);
      final selected = token != null && token == _sel && _selCell == i;
      Widget w = ItemCell(
        rules: shop.rules,
        content: c,
        selected: selected || _moveFrom == i,
        highlight: _moveFrom != null && _moveFrom != i,
      );
      if (c != null) {
        w = RetroTooltip(message: _tooltip(me.profile, c, attrs), child: w);
      }
      void tap() {
        final from = _moveFrom;
        if (mine && from != null) {
          setState(() => _moveFrom = null);
          if (from != i) {
            shop.controller.moveInventory(from, i);
            _selCell = i;
          }
          return;
        }
        if (token != null) _select(token, i);
      }

      w = _CellButton(onTap: tap, child: w);
      if (mine) {
        if (c != null) {
          w = Draggable<int>(
            data: i,
            feedback: Opacity(
                opacity: 0.8,
                child: ItemCell(rules: shop.rules, content: c, selected: true)),
            childWhenDragging: ItemCell(rules: shop.rules),
            child: w,
          );
        }
        final inner = w;
        w = DragTarget<int>(
          onWillAcceptWithDetails: (d) => d.data != i,
          onAcceptWithDetails: (d) {
            shop.controller.moveInventory(d.data, i);
            setState(() {
              if (_selCell == d.data) _selCell = i;
            });
          },
          builder: (context, cand, _) => cand.isEmpty
              ? inner
              : Stack(children: [
                  inner,
                  Positioned.fill(
                      child: IgnorePointer(
                          child: Container(
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: ProtoColors.sky, width: 2))))),
                ]),
        );
      }
      return KeyedSubtree(key: ValueKey('inv-cell-$i'), child: w);
    }

    final eq = p.equippedItem;
    final eqCell = eq == null
        ? ItemCell(rules: shop.rules)
        : RetroTooltip(
            message: itemTooltipMarkup(shop.rules, eq,
                level: me.profile.level, attributes: attrs, equipped: true),
            child: ItemCell(
                rules: shop.rules,
                content: CellContent.item(eq),
                selected: _sel == eq.uid));
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        owners,
        const SizedBox(height: 8),
        Row(
          children: [
            _CellButton(
                key: const ValueKey('inv-equipped'),
                onTap: () {
                  if (eq != null) _select(eq.uid, null);
                },
                child: eqCell),
            const SizedBox(width: 8),
            Expanded(
              child: ProtoText(
                  '<b style="color:#ffd166">EQUIPADA</b><br>'
                  '${eq == null ? '—' : itemNameMarkup(shop.rules, eq)}'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_moveFrom != null)
          Row(children: [
            const Expanded(
                child: Text('Elige la casilla destino',
                    style: TextStyle(color: ProtoColors.sky))),
            PanelButton('CANCELAR',
                key: const ValueKey('inv-move-cancel'),
                onPressed: () => setState(() => _moveFrom = null)),
          ])
        else if (!mine)
          ProtoText(protoColor(ProtoColors.dim,
              'Inventario de ${protoEsc(owner.name)} (solo lectura)')),
        const SizedBox(height: 4),
        SizedBox(
          width: InventoryTab.gridWidth,
          child: Wrap(
            spacing: InventoryTab.gap,
            runSpacing: InventoryTab.gap,
            children: [
              for (var i = 0; i < InventoryRules.cells; i++) cellAt(i),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ProtoText(
            key: const ValueKey('inv-summary'),
            'Casillas ${InventoryRules.cellsUsed(p)}/${InventoryRules.cells}'
            '${mine ? ' · <b>₵${p.credits}</b>' : ''}'
            '${layout.overflow.isEmpty ? '' : ' · ${protoColor(ProtoColors.orange, '${layout.overflow.length} sin lugar')}'}'),
      ],
    );

    return PanelSplit(
      listWidth: InventoryTab.gridWidth + 4,
      list: [left],
      detail: PanelDetail(
        footer: sel == null || !mine
            ? (mine
                ? const []
                : [
                    const Text('Solo lectura',
                        style: TextStyle(color: ProtoColors.dim))
                  ])
            : _actions(p, me, mates, sel),
        children: sel == null
            ? [
                Text(retroText('Elige una casilla.'),
                    style: const TextStyle(color: ProtoColors.dim)),
              ]
            : _detail(p, me.profile, sel, attrs, mine),
      ),
    );
  }

  List<Widget> _detail(PlayerProfile p, PlayerProfile viewer, CellContent c,
      PlayerAttributes attrs, bool mine) {
    final it = c.item;
    if (it == null) {
      return [ProtoText(stackTooltipMarkup(c.stack!, c.count))];
    }
    final equipped = it.uid == p.equippedUid;
    final rules = shop.rules;
    final eq = rules.equippedItem(viewer);
    return [
      ItemCard(
        rules: rules,
        item: it,
        level: viewer.level,
        attributes: attrs,
        stats: shop.preview.withItem(viewer, it, attributes: attrs),
        equipped: equipped,
      ),
      if (!equipped || !mine)
        StatsCompare(
          title: 'Comparada con '
              '${eq == null ? '-' : protoEsc(rules.items.displayName(eq))}',
          before: shop.preview.current(viewer, attributes: attrs),
          after: shop.preview.withItem(viewer, it, attributes: attrs),
        ),
    ];
  }

  List<Widget> _actions(PlayerProfile p, SessionPlayer me,
      List<SessionPlayer> mates, CellContent c) {
    final g = shop.guards;
    final token = _sel!;
    final it = c.item;
    final count = it == null ? _count.clamp(1, c.count) : 1;
    final name = it == null
        ? '$count ${c.stack!.label}'
        : shop.rules.items.displayName(it);
    if (_confirmDrop) {
      return [
        ProtoText(
            key: const ValueKey('inv-drop-question'),
            '¿Tirar <b>${protoEsc(name)}</b> al piso? Lo puede levantar '
            'cualquiera.'),
        PanelButton('CANCELAR',
            key: const ValueKey('inv-drop-cancel'),
            onPressed: () => setState(() => _confirmDrop = false)),
        PanelButton('TIRAR',
            key: const ValueKey('inv-drop-confirm'),
            accent: ProtoColors.red,
            reason: g.drop(p, token, count: count, alive: me.alive),
            onPressed: () {
              shop.controller.dropItem(token, count: count);
              setState(() => _confirmDrop = false);
            }),
      ];
    }
    return [
      if (it == null && c.count > 1) ...[
        PanelButton('-',
            key: const ValueKey('inv-count-dec'),
            onPressed: count > 1 ? () => setState(() => _count = count - 1) : null),
        Text('x$count', key: const ValueKey('inv-count')),
        PanelButton('+',
            key: const ValueKey('inv-count-inc'),
            onPressed:
                count < c.count ? () => setState(() => _count = count + 1) : null),
      ],
      if (_selCell != null)
        PanelButton('MOVER',
            key: const ValueKey('inv-move'),
            onPressed: () => setState(() => _moveFrom = _selCell)),
      if (mates.isEmpty)
        PanelButton('DAR A...',
            key: const ValueKey('inv-give'),
            reason: g.give(p, token, null, count: count))
      else
        for (final m in mates)
          PanelButton('DAR A ${m.name.toUpperCase()}',
              key: ValueKey('inv-give-${m.id}'),
              reason: g.give(p, token, m, count: count),
              onPressed: () =>
                  shop.controller.give(m.id, token, count: count)),
      PanelButton('TIRAR',
          key: const ValueKey('inv-drop'),
          reason: g.drop(p, token, count: count, alive: me.alive),
          onPressed: () => setState(() => _confirmDrop = true)),
      if (it != null && it.uid != p.equippedUid)
        PanelButton('EQUIPAR',
            key: const ValueKey('inv-equip'),
            accent: ProtoColors.green,
            reason: g.equip(p, it.uid, pending: widget.pending),
            onPressed: () => shop.controller.equip(it.uid)),
    ];
  }
}

/// Casilla clicable con foco de teclado (Enter / Espacio la activan).
class _CellButton extends StatelessWidget {
  const _CellButton({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent:
              CallbackAction<ActivateIntent>(onInvoke: (_) => onTap()),
        },
        child: GestureDetector(
            behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      );
}
