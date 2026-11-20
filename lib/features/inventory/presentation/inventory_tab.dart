import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/inventory_sort.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import '../../build_planner/presentation/build_fit_badge.dart';
import '../../build_planner/presentation/build_plan_providers.dart';
import '../domain/inventory_menu.dart';
import '../domain/item_text.dart';
import '../domain/weapon_compare.dart' show stripStats;
import 'clean_selection.dart';
import 'consumables_bar.dart';
import 'inventory_action_menu.dart';
import 'inventory_sort_button.dart';
import 'item_widgets.dart' hide PixelIcon;
import 'shop_sections.dart';
import 'weapon_compare_view.dart';

/// Pestaña INVENTARIO del personaje (tecla I): grilla de 8 × 5 con la
/// equipada aparte, mover arrastrando o con MOVER, ficha y comparación,
/// EQUIPAR / TIRAR / DAR A y los inventarios de los compañeros en solo
/// lectura. Ver docs/specs/panels.md § "Inventario".
class InventoryTab extends ConsumerStatefulWidget {
  const InventoryTab({super.key, required this.shop, this.pending = const {}});

  final ShopContext shop;

  /// Reparto de puntos sin confirmar (colorea requisitos y equipar).
  final Map<Attribute, int> pending;

  static const cell = 44.0;
  static const gap = 4.0;
  static const gridWidth =
      InventoryRules.columns * cell + (InventoryRules.columns - 1) * gap;

  @override
  ConsumerState<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends ConsumerState<InventoryTab> {
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

  /// Confirmación de VENDER / DESARMAR del arma elegida.
  CraftOp? _confirmCraft;

  /// LIMPIAR INVENTARIO abierto en el detalle (lotes).
  bool _cleaning = false;
  CraftOp _cleanOp = CraftOp.salvageAll;
  Rarity _cleanRarity = Rarity.comun;

  /// LIMPIAR › ELEGIR A MANO (v0.5.1): la grilla marca armas.
  bool _cleanPick = false;
  bool _cleanSell = false;
  List<String> _picked = const [];

  /// Última clave de ORDENAR (borde dorado en el menú).
  InventorySortKey? _lastSort;

  /// COMPARAR: arma A elegida (esperando B) y B (vista abierta).
  WeaponRef? _cmpA;
  WeaponRef? _cmpB;
  bool get _picking => _cmpA != null && _cmpB == null;

  /// Plan de build del jugador local y sus reglas (★ Tu build,
  /// build_planner.md § 4.1); se leen en cada `build`.
  BuildPlan _plan = BuildPlan.empty;
  BuildPlanRules? _fitRules;

  ItemFit _fit(ItemInstance it) => _plan.goalCount == 0 || _fitRules == null
      ? ItemFit.none
      : _fitRules!.itemFit(_plan, it);

  /// La línea "★ Tu build — Cumple: ..." de la ficha, con salto antes.
  String _fitLine(ItemInstance it) {
    final m = buildFitMarkup(_fit(it));
    return m == null ? '' : '<br>$m';
  }

  /// Foco propio: `Esc` cancela "elige B" sin cerrar el panel.
  final _keys = FocusNode(debugLabel: 'inventory');

  final _searchKey = GlobalKey(debugLabel: 'inv-search');

  /// Grilla y panel: los tooltips se abren solo en la columna de la
  /// grilla (sin tapar la franja de CAMBIOS ni la EQUIPADA / pilas).
  final _gridKey = GlobalKey(debugLabel: 'inv-grid');
  final _panelKey = GlobalKey(debugLabel: 'inv-panel');

  /// Zona de los tooltips (panels.md § "Inventario"): el ancho de la
  /// grilla, desde su borde de arriba (o el del panel si así queda muy
  /// baja) hasta el pie del panel.
  /// Alto mínimo de la zona de los tooltips.
  static const minTipAreaHeight = 200.0;

  Rect? _tipBounds() {
    final g = _gridKey.currentContext?.findRenderObject();
    final p = _panelKey.currentContext?.findRenderObject();
    if (g is! RenderBox || p is! RenderBox || !g.hasSize || !p.hasSize) {
      return null;
    }
    final gr = g.localToGlobal(Offset.zero) & g.size;
    final pr = p.localToGlobal(Offset.zero) & p.size;
    // Si debajo del borde de la grilla queda poco (pantalla baja), todo el
    // alto del panel: la franja y la EQUIPADA siguen fuera (a los lados).
    // Y si el panel mismo es bajo, todo el alto de la pantalla.
    var top = pr.bottom - gr.top >= pr.height / 2 ? gr.top : pr.top;
    var bottom = pr.bottom;
    if (bottom - top < minTipAreaHeight) {
      top = -double.maxFinite;
      bottom = double.maxFinite;
    }
    return Rect.fromLTRB(gr.left, top, gr.right, bottom);
  }

  /// Escala de la grilla: casilla de `cell × _scale` px. La calcula
  /// [inventoryLayout] desde el espacio que da el `LayoutBuilder`.
  double _scale = 1;

  /// Disposición según el ancho (v0.12.0, panels.md § "Inventario").
  InventoryLayoutMode _mode = InventoryLayoutMode.medium;

  /// Con lugar a lo ancho, la EQUIPADA y las pilas van al lado.
  bool get _wide => _mode == InventoryLayoutMode.wide;
  double get _cellSize => InventoryTab.cell * _scale;
  double get _gap => InventoryTab.gap * _scale;
  double get _gridW => InventoryTab.gridWidth * _scale;

  /// Buscador (v0.9.7): nombre, tipo, rareza, mod, pasiva, habilidad.
  final _search = TextEditingController();
  String _query = '';

  /// Menú de LIMPIAR INVENTARIO abierto debajo del botón.
  bool _cleanMenu = false;

  /// Marcas NUEVO ya mandadas a sacar (no repetir mientras llega).
  final _seenSent = <String>{};

  @override
  void dispose() {
    InventoryContextMenu.close();
    _keys.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Saca la marca NUEVO de [uid] al pasar el mouse (loot.md § 17.4).
  void _seen(PlayerProfile p, String uid) {
    if (!p.fresh.contains(uid) || !_seenSent.add(uid)) return;
    shop.controller.markSeen([uid]);
  }

  bool _matches(CellContent c) =>
      _query.trim().isEmpty ||
      inventoryMatches(shop.rules, _query,
          item: c.item, eco: c.eco, label: c.stack?.label);

  void _startCompare(WeaponRef a) {
    setState(() {
      _cmpA = a;
      _cmpB = null;
      _moveFrom = null;
      _confirmDrop = false;
      _confirmCraft = null;
      _cleaning = false;
    });
    _keys.requestFocus();
  }

  void _closeCompare() => setState(() {
        _cmpA = null;
        _cmpB = null;
      });

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (_picking &&
        e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.escape) {
      _closeCompare();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Ficha del mouse: comparada con la equipada si es un arma que no
  /// usás (§ "Comparar armas"); si no, la ficha simple.
  Widget _withTip(SessionPlayer me, SessionPlayer owner, CellContent c,
      PlayerAttributes attrs, Widget child,
      {bool equipped = false, bool focused = false}) {
    final it = c.item;
    final mine = owner.id == me.id;
    final using = shop.rules.equippedItem(me.profile)?.uid;
    if (it == null) {
      return RetroTooltip(
          message: _tooltip(me.profile, c, attrs),
          keyboardFocus: focused,
          child: child);
    }
    if (mine && it.uid == using) {
      // La equipada: resumen + secciones plegables (ui_style.md §
      // "Tooltips cortos").
      final parts = itemTipParts(shop.rules, it,
          level: me.profile.level, attributes: attrs, equipped: equipped);
      return RetroHoverCard(
        placement: RetroTipPlacement.below,
        gap: 4,
        interactive: true,
        pinOnClick: true,
        hint: _tipHint,
        keyboardFocus: focused,
        builder: (ctx) => RetroTipFolds(
            key: const ValueKey('inv-tip-folds'),
            summary: parts.summary + _fitLine(it),
            sections: parts.sections,
            maxWidth: RetroType.width(ctx, RetroHoverCard.textWidth)),
        child: child,
      );
    }
    final fit = buildFitMarkup(_fit(it));
    final card = HoverCompareCard(
        rules: shop.rules,
        viewer: me.profile,
        item: it,
        attributes: attrs,
        ownerName: mine ? null : owner.name,
        // Del ancho de la ficha: antes iba en una Column con `stretch`
        // y la caja tomaba todo el ancho de la pantalla.
        footer: fit == null
            ? null
            : Container(
                key: const ValueKey('inv-build-fit-hover'),
                padding: const EdgeInsets.all(6),
                color: ProtoColors.bg,
                child: ProtoText(fit),
              ));
    return RetroHoverCard(
      interactive: true,
      pinOnClick: true,
      hint: _tipHint,
      keyboardFocus: focused,
      builder: (_) => card,
      child: child,
    );
  }

  /// Ayuda al pie de la ficha del mouse (ui_style.md § "Tooltips cortos").
  static const _tipHint = 'Alt: detalle · Shift: comparar · clic: fijar';

  /// Arma no equipada bajo el mouse o el cursor de teclado (franja de
  /// cambios, panels.md § "Inventario").
  String? _hoverUid;

  void _hover(String? uid) {
    if (_hoverUid != uid) setState(() => _hoverUid = uid);
  }

  Widget _strip(SessionPlayer me, PlayerAttributes attrs) {
    final p = me.profile;
    final it = _hoverUid == null ? null : _hoverItem;
    final using = shop.rules.equippedItem(p)?.uid;
    final to = it != null && it.uid != using ? it : null;
    return ChangeStrip(
        stats: stripStats(shop.rules, p, to: to, attributes: attrs),
        hovering: to != null);
  }

  ItemInstance? _hoverItem;

  /// La franja arranca a la altura de la grilla (debajo de la EQUIPADA si
  /// va arriba).
  double get _stripTop =>
      _mode == InventoryLayoutMode.medium ? _cellSize + DsSpace.sm : 0;

  /// En "elige B": toma [token] como B si es un arma.
  bool _pickB(String owner, String? token, CellContent? c) {
    if (!_picking || token == null || c?.item == null) return false;
    setState(() => _cmpB = WeaponRef(owner, token));
    return true;
  }

  /// Nombre de A (en "elige B").
  String _cmpAName() {
    final a = _cmpA;
    final it = a == null
        ? null
        : shop.view.session.players[a.owner]?.profile.itemByUid(a.uid);
    return it == null ? '?' : itemNameMarkup(shop.rules, it);
  }

  ShopContext get shop => widget.shop;

  CellContent? _content(PlayerProfile p, String? token) {
    if (token == null) return null;
    final st = StackKind.byToken(token);
    if (st != null) {
      final n = InventoryRules.stackCount(p, st);
      return n > 0 ? CellContent.stack(st, n) : null;
    }
    final eco = p.ecoByUid(token);
    if (eco != null) return CellContent.eco(eco);
    final it = p.itemByUid(token);
    return it == null ? null : CellContent.item(it);
  }

  /// Ficha de un Eco con el Atlas y el grupo de la sala.
  String _ecoTip(EcoItem e) => ecoTooltipMarkup(shop.rules, e,
      atlas: shop.controller.engine.atlasOf(shop.view.session),
      players: shop.view.session.players.length);

  String _tooltip(PlayerProfile viewer, CellContent c, PlayerAttributes attrs) {
    final it = c.item;
    if (it != null) {
      return itemTooltipMarkup(shop.rules, it,
          skillDetails: true, level: viewer.level, attributes: attrs);
    }
    final eco = c.eco;
    if (eco != null) return _ecoTip(eco);
    return stackTooltipMarkup(c.stack!, c.count);
  }

  /// Usa la poción [token] si es una y se puede; `true` si la mandó.
  bool _usePotion(String token) {
    final item = token == StackKind.potion.token
        ? BattleItem.potion
        : token == StackKind.ether.token
            ? BattleItem.ether
            : null;
    return item != null && shop.controller.useItem(item);
  }

  void _select(String token, int? cell) => setState(() {
        if (_sel != token) _count = 1;
        _sel = token;
        _selCell = cell;
        _confirmDrop = false;
        _confirmCraft = null;
        _cleaning = false;
      });

  @override
  Widget build(BuildContext context) {
    final view = shop.view;
    // El miembro activo (el local o el compañero elegido; solo_party.md
    // § 6): DAR A lista a los demás, también al líder.
    final me = view.actor!;
    final mates = [
      for (final pl in view.session.playerList)
        if (pl.id != me.id) pl,
    ];
    _plan = ref.watch(buildPlanProvider).planFor(shop.controller.slotOf(me.id));
    _fitRules = ref.watch(buildPlanRulesProvider);
    final owner = view.session.players[_owner] ?? me;
    final mine = owner.id == me.id;
    final p = owner.profile;
    final attrs =
        me.profile.attributes.add(ProgressionRules.rawOf(widget.pending));
    final layout = InventoryRules.layout(p);
    // Selección por defecto: la equipada.
    if (_content(p, _sel) == null) {
      _sel = p.equippedUid;
      _selCell = null;
      _confirmDrop = false;
      _confirmCraft = null;
    }
    final sel = _content(p, _sel);
    // ELEGIR A MANO: la grilla marca armas en vez de elegir.
    final pickMode = _cleaning && _cleanPick && mine;
    if (pickMode) _picked = prunePicked(shop.rules, p, _picked);
    void togglePick(String? token) {
      if (token == null || p.itemByUid(token) == null) return;
      setState(() => _picked = togglePicked(shop.rules, p, _picked, token));
    }

    final owners = [
      DsButton(view.actingCompanion ? me.name.toUpperCase() : 'TÚ',
          key: ValueKey('inv-owner-${me.id}'),
          size: DsButtonSize.compact,
          selected: mine,
          onPressed: () => setState(() {
                _owner = null;
                _sel = null;
                _moveFrom = null;
              })),
      for (final m in mates)
        DsButton(m.name.toUpperCase(),
            key: ValueKey('inv-owner-${m.id}'),
            size: DsButtonSize.compact,
            selected: owner.id == m.id,
            onPressed: () => setState(() {
                  _owner = m.id;
                  _sel = null;
                  _moveFrom = null;
                })),
    ];

    Widget cellAt(int i, [bool focused = false]) {
      final token = layout.cells[i];
      final c = _content(p, token);
      final selected = token != null && token == _sel && _selCell == i;
      Widget w = ItemCell(
        rules: shop.rules,
        content: c,
        size: _cellSize,
        selected: selected || _moveFrom == i,
        highlight: _moveFrom != null && _moveFrom != i,
        buildMatch: c?.item != null && _fit(c!.item!).any,
      );
      if (pickMode && token != null) {
        final picked = _picked.contains(token);
        w = CleanCellMark(
            picked: picked,
            locked: !picked &&
                cleanLockReason(shop.rules, p, token, _picked) != null,
            child: w);
      }
      if (c != null) {
        final fresh = mine && token != null && p.fresh.contains(token);
        final match = _matches(c);
        if (fresh || !match) {
          w = Stack(children: [
            Opacity(opacity: match ? 1 : 0.25, child: w),
            if (fresh)
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                      child: NewItemTag(key: ValueKey('inv-new-$i')))),
          ]);
        }
        w = _withTip(me, owner, c, attrs, w, focused: focused);
        if (c.item case final it?) {
          final inner = w;
          w = MouseRegion(
              onEnter: (_) {
                _hoverItem = it;
                _hover('$_owner/${it.uid}');
              },
              onExit: (_) {
                if (_hoverItem == it) {
                  _hoverItem = null;
                  _hover(null);
                }
              },
              child: inner);
        }
        if (fresh) {
          final inner = w;
          w = MouseRegion(onEnter: (_) => _seen(p, token), child: inner);
        }
      }
      void tap() {
        if (pickMode) return togglePick(token);
        if (_pickB(owner.id, token, c)) return;
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

      w = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          // Clic derecho: el menú de acciones (v0.9.7).
          onSecondaryTapUp: mine && !pickMode && token != null && c != null
              ? (d) => _openMenu(p, me, mates, token, i, d.globalPosition)
              : null,
          child: w);
      if (mine && !pickMode) {
        if (c != null) {
          w = Draggable<int>(
            data: i,
            feedback: Opacity(
                opacity: 0.8,
                child: ItemCell(
                    rules: shop.rules,
                    content: c,
                    size: _cellSize,
                    selected: true)),
            childWhenDragging: ItemCell(rules: shop.rules, size: _cellSize),
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
    Widget buildLeft() {
      final eqCell = eq == null
          ? ItemCell(rules: shop.rules, size: _cellSize)
          : _withTip(
              me,
              owner,
              CellContent.item(eq),
              attrs,
              ItemCell(
                  rules: shop.rules,
                  size: _cellSize,
                  content: CellContent.item(eq),
                  selected: _sel == eq.uid,
                  buildMatch: _fit(eq).any),
              equipped: true);
      final eqRow = Row(
        children: [
          _CellButton(
              key: const ValueKey('inv-equipped'),
              // El menú de la EQUIPADA se abre debajo del buscador (no lo
              // tapa).
              onSecondaryTap: mine && eq != null && !pickMode
                  ? (at) => _openMenu(p, me, mates, eq.uid, null, at,
                      avoid: _searchRect())
                  : null,
              onTap: () {
                if (eq == null) return;
                if (_pickB(owner.id, eq.uid, CellContent.item(eq))) return;
                _select(eq.uid, null);
              },
              child: eqCell),
          SizedBox(width: DsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(retroText('EQUIPADA'), style: DsText.subtitle()),
                ProtoText(eq == null ? '—' : itemNameMarkup(shop.rules, eq)),
              ],
            ),
          ),
        ],
      );
      final notes = <Widget>[
        if (_picking)
          Row(children: [
            Expanded(
                child: ProtoText(
                    key: const ValueKey('inv-compare-pick'),
                    style: DsText.body(DsColors.textSubtitle),
                    'Elige el arma B para comparar con ${_cmpAName()}')),
            DsButton('CANCELAR',
                key: const ValueKey('inv-compare-cancel'),
                size: DsButtonSize.compact,
                onPressed: _closeCompare),
          ])
        else if (_moveFrom != null)
          Row(children: [
            Expanded(
                child: Text('Elige la casilla destino',
                    style: DsText.body(DsColors.textSubtitle))),
            DsButton('CANCELAR',
                key: const ValueKey('inv-move-cancel'),
                size: DsButtonSize.compact,
                onPressed: () => setState(() => _moveFrom = null)),
          ])
        else if (!mine)
          Text('Inventario de ${owner.name} (solo lectura)',
              style: DsText.detail()),
      ];
      final gridBox = SizedBox(
        key: _gridKey,
        width: _gridW,
        // Flechas: el cursor recorre la grilla y elige la casilla;
        // Enter otra vez sobre un arma la equipa (menu_focus.dart).
        child: InitialFocus(
            child: FocusGrid(
          count: InventoryRules.cells,
          columns: InventoryRules.columns,
          spacing: _gap,
          keyPrefix: 'inv-focus-',
          cell: (_, i, focused) => cellAt(i, focused),
          onFocusCell: (i) {
            final t = layout.cells[i];
            if (pickMode) return;
            if (_moveFrom == null && !_picking && t != null) _select(t, i);
            _hoverItem = t == null ? null : p.itemByUid(t);
            _hover(_hoverItem == null ? null : '$_owner/$t');
          },
          // ELEGIR A MANO: Enter / Espacio marcan o desmarcan.
          onActivate: (i) => pickMode
              ? togglePick(layout.cells[i])
              : _activateCell(p, layout.cells[i], i, mine, owner.id,
                  cellTap: () {
                  final c = _content(p, layout.cells[i]);
                  if (_pickB(owner.id, layout.cells[i], c)) return;
                  final from = _moveFrom;
                  if (mine && from != null) {
                    setState(() => _moveFrom = null);
                    if (from != i) {
                      shop.controller.moveInventory(from, i);
                      _selCell = i;
                    }
                    return;
                  }
                  if (layout.cells[i] case final t?) _select(t, i);
                }, openMenu: () {
                  if (layout.cells[i] case final t?) {
                    _openMenuAtFocus(p, me, mates, t, i);
                  }
                }),
        )),
      );
      final stacksBar = InventoryStacksBar(
        rules: shop.rules,
        profile: p,
        cell: _cellSize,
        gap: _gap,
        selected: _sel,
        onSelect: pickMode || _picking || _moveFrom != null
            ? null
            // Clic sobre la poción ya elegida: la usa (loot.md § 17.5).
            : (t) {
                if (mine && t == _sel && _usePotion(t)) return;
                _select(t, null);
              },
        onMenu: !mine || pickMode || _picking || _moveFrom != null
            ? null
            : (t, at) => at == null
                ? _openMenuAtFocus(p, me, mates, t, null)
                : _openMenu(p, me, mates, t, null, at),
      );
      final summary = KeyedSubtree(
          key: const ValueKey('inv-summary'),
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: 'Casillas ${InventoryRules.cellsUsed(p)}/'
                    '${InventoryRules.cells}',
                style: DsText.detail()),
            if (mine)
              TextSpan(
                  text: retroText(' · ₵${p.credits}'),
                  style: DsText.body(DsColors.reward)),
            if (layout.overflow.isNotEmpty)
              TextSpan(
                  text: ' · ${layout.overflow.length} sin lugar',
                  style: DsText.body(DsColors.warning)),
          ])));
      final tail = <Widget>[
        if (mine && sel != null && _sel != null)
          if (_selectionBar(p, me, mates, sel) case final bar?) bar,
        if (mine && _cleaning && _cleanMenu) ...[
          SizedBox(height: DsSpace.xs),
          _cleanMenuBox(p),
        ],
      ];
      if (_wide) {
        // Ancho (v0.9.10): la grilla a la izquierda y, al lado, la
        // EQUIPADA, las pilas y LIMPIAR (así la grilla puede crecer más).
        return NavSection(
            child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _gridW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...notes,
                  if (notes.isNotEmpty) SizedBox(height: DsSpace.xs),
                  gridBox,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                key: const ValueKey('inv-side'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  eqRow,
                  const SizedBox(height: 8),
                  stacksBar,
                  const SizedBox(height: 6),
                  summary,
                  ...tail,
                ],
              ),
            ),
          ],
        ));
      }
      return NavSection(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          eqRow,
          SizedBox(height: DsSpace.sm),
          ...notes,
          if (notes.isNotEmpty) SizedBox(height: DsSpace.xs),
          gridBox,
          const SizedBox(height: 8),
          stacksBar,
          const SizedBox(height: 6),
          summary,
          ...tail,
        ],
      ));
    }

    // Barra de herramientas (design_system.md § 4): de quién es el
    // inventario, búsqueda, ORDENAR y LIMPIAR en una fila.
    final toolbar = Padding(
      key: const ValueKey('inv-toolbar'),
      padding: EdgeInsets.only(bottom: DsSpace.sm),
      child: Wrap(
        spacing: DsSpace.xs,
        runSpacing: DsSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...owners,
          SizedBox(width: DsSpace.md),
          KeyedSubtree(
            key: _searchKey,
            child: KeyedSubtree(
              key: const ValueKey('inv-search'),
              child: DsSearchField(
                hint: 'BUSCAR: nombre, tipo, mod',
                width: 280,
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            DsButton.icon(const Text('×'),
                key: const ValueKey('inv-search-clear'),
                tooltip: 'Borrar la búsqueda',
                size: DsButtonSize.compact,
                onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    })),
          if (mine) ...[
            SizedBox(width: DsSpace.md),
            InventorySortButton(
                current: _lastSort,
                onSort: (k) {
                  setState(() => _lastSort = k);
                  shop.controller.sortInventory(k);
                }),
            DsButton('LIMPIAR',
                key: const ValueKey('inv-clean'),
                size: DsButtonSize.compact,
                selected: _cleaning,
                tooltip: 'Desarmar o vender varias armas de una vez',
                onPressed: () => setState(() {
                      _cleaning = !_cleaning;
                      _cleanMenu = _cleaning;
                      _picked = const [];
                      _confirmDrop = false;
                      _confirmCraft = null;
                      _moveFrom = null;
                    })),
            DsButton('ALIJO',
                key: const ValueKey('inv-stash'),
                size: DsButtonSize.compact,
                tooltip: shop.controller.stashBlock ??
                    'Abrir el alijo de la cuenta [B]',
                onPressed: shop.controller.stashBlock == null
                    ? shop.controller.openStash
                    : null),
          ],
        ],
      ),
    );

    final cmpA = _cmpA, cmpB = _cmpB;
    if (cmpA != null && cmpB != null) {
      return WeaponCompareView(
        key:
            ValueKey('cmp-${cmpA.owner}-${cmpA.uid}-${cmpB.owner}-${cmpB.uid}'),
        shop: shop,
        a: cmpA,
        b: cmpB,
        pending: widget.pending,
        onClose: _closeCompare,
        onSwap: () => setState(() {
          _cmpA = cmpB;
          _cmpB = cmpA;
        }),
      );
    }

    if (_cleaning && mine) {
      _scale = 1;
      _mode = InventoryLayoutMode.medium;
      return _withToolbar(
          toolbar,
          PanelSplit(
            listWidth: InventoryTab.gridWidth + 4,
            scaleList: false,
            list: [buildLeft()],
            detail: _cleaner(p),
          ));
    }

    final compareButton = sel?.item == null || _picking
        ? null
        : DsButton('COMPARAR',
            key: const ValueKey('inv-compare'),
            size: DsButtonSize.compact,
            onPressed: () => _startCompare(WeaponRef(owner.id, _sel!)));
    // Sin panel derecho (v0.9.10): la ficha del mouse ya compara con la
    // equipada. La grilla escala para llenar el ancho (panels.md §
    // "Inventario").
    final body = Focus(
      focusNode: _keys,
      onKeyEvent: _onKey,
      child: RetroTipArea(
        bounds: _tipBounds,
        child: LayoutBuilder(builder: (context, box) {
          // Puntos de quiebre según el ancho del panel (panels.md §
          // "Inventario"): la casilla sale del espacio disponible.
          final stripW = ChangeStrip.widthOf(context) + 8;
          final l = inventoryLayout(box.maxWidth, box.maxHeight,
              stripWidth: stripW,
              sideMin: MediaQuery.textScalerOf(context).scale(240));
          _mode = l.mode;
          _scale = l.scale;
          final strip = _strip(me, attrs);
          final main = SizedBox(
              key: const ValueKey('inv-main'),
              width: l.mainWidth,
              child: buildLeft());
          return Column(
            key: _panelKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                // Solo scroll vertical: a lo ancho todo entra.
                child: SingleChildScrollView(
                  child: l.mode == InventoryLayoutMode.narrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: strip),
                            SizedBox(height: DsSpace.sm),
                            main,
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: stripW,
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                    padding: EdgeInsets.only(top: _stripTop),
                                    child: strip),
                              ),
                            ),
                            main,
                          ],
                        ),
                ),
              ),
              if (!mine)
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text('Solo lectura', style: DsText.detail()),
                    if (compareButton != null) compareButton,
                  ],
                ),
            ],
          );
        }),
      ),
    );
    return _withToolbar(toolbar, body);
  }

  /// La barra arriba y [body] debajo. Con texto ENORME la barra (que baja
  /// de línea) se limita al 40 % del alto y se desplaza.
  Widget _withToolbar(Widget toolbar, Widget body) => LayoutBuilder(
      builder: (context, c) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: c.maxHeight.isFinite
                        ? c.maxHeight * 0.4
                        : double.infinity),
                child: SingleChildScrollView(child: toolbar),
              ),
              Expanded(child: body),
            ],
          ));

  /// Menú de LIMPIAR INVENTARIO (v0.9.7), debajo del botón: elegir a
  /// mano o desarmar / vender todos los Comunes, Mágicos o Raros. Elegir
  /// una opción la deja lista en el detalle para confirmar.
  Widget _cleanMenuBox(PlayerProfile p) {
    final rules = shop.rules;
    InventoryMenuEntry batch(CraftOp op, Rarity r) {
      final n = rules.crafting.batchTargets(p, r).length;
      final sell = op == CraftOp.sellAll;
      return InventoryMenuEntry(
        id: 'clean-menu-${sell ? 'sell' : 'salvage'}-${r.name}',
        label: '${sell ? 'Vender' : 'Desarmar'} todos los '
            '${rarityPlural(r)} ($n)',
        color: sell ? ProtoColors.gold : ProtoColors.sky,
        reason: n == 0
            ? 'No tenés ${rarityPlural(r).toLowerCase()} para '
                '${sell ? 'vender' : 'desarmar'}'
            : null,
        onTap: () => setState(() {
          _cleanPick = false;
          _cleanOp = op;
          _cleanRarity = r;
        }),
      );
    }

    const rs = [Rarity.comun, Rarity.magico, Rarity.raro];
    return Container(
      key: const ValueKey('inv-clean-menu'),
      constraints: BoxConstraints(maxWidth: _gridW),
      decoration: BoxDecoration(
        color: DsColors.background,
        border: Border.all(
            color: DsColors.borderControl, width: DsMetrics.controlBorder),
      ),
      child: InventoryActionList(keyPrefix: 'inv-', entries: [
        InventoryMenuEntry(
          id: 'clean-menu-pick',
          label: 'Elegir a mano',
          note: 'marcá armas en la grilla',
          onTap: () => setState(() => _cleanPick = true),
        ),
        for (final r in rs) batch(CraftOp.salvageAll, r),
        for (final r in rs) batch(CraftOp.sellAll, r),
      ]),
    );
  }

  /// LIMPIAR INVENTARIO: desarmar o vender de una vez todas las armas de
  /// una rareza, con el resumen antes de confirmar.
  Widget _cleaner(PlayerProfile p) {
    final rules = shop.rules;
    final g = shop.guards;
    void mode(bool pick) => setState(() => _cleanPick = pick);
    if (_cleanPick) {
      return CleanSelectionPanel(
        rules: rules,
        guards: g,
        profile: p,
        picked: _picked,
        sell: _cleanSell,
        onMode: mode,
        onSell: (v) => setState(() => _cleanSell = v),
        onAdd: (r) =>
            setState(() => _picked = addRarityPicked(rules, p, _picked, r)),
        onClear: () => setState(() => _picked = const []),
        onConfirm: (a) {
          shop.controller.craft(a);
          setState(() => _picked = const []);
        },
        onCancel: () => setState(() => _cleaning = false),
      );
    }
    final sell = _cleanOp == CraftOp.sellAll;
    final a = CraftAction.batch(_cleanOp, _cleanRarity);
    final r = g.craftPreview(p, a);
    final targets = rules.crafting.batchTargets(p, _cleanRarity);
    final n = targets.length;
    final what =
        '$n ${n == 1 ? _cleanRarity.label : rarityPlural(_cleanRarity)}';
    final summary = n == 0
        ? protoColor(ProtoColors.dim,
            'No tienes armas ${rarityPlural(_cleanRarity)} para ${sell ? 'vender' : 'desarmar'}.')
        : 'Vas a ${sell ? 'vender' : 'desarmar'} ${protoEsc(what)} → '
            '${protoColor(ProtoColors.green, protoEsc(gainsText(credits: r.gainedCredits, materials: r.gainedMaterials, chances: r.outcomes)))}';
    return PanelDetail(
      footer: [
        DsButton('CANCELAR',
            key: const ValueKey('inv-clean-cancel'),
            size: DsButtonSize.compact,
            onPressed: () => setState(() => _cleaning = false)),
        DsButton(
            '${sell ? 'VENDER' : 'DESARMAR'} ${n == 0 ? '' : '$n '}'
            '${rarityPlural(_cleanRarity).toUpperCase()}',
            key: const ValueKey('inv-clean-confirm'),
            size: DsButtonSize.compact,
            accent: DsColors.danger,
            tooltip: g.craft(p, a),
            onPressed: g.craft(p, a) != null
                ? null
                : () {
                    shop.controller.craft(a);
                    setState(() {});
                  }),
      ],
      children: [
        const DsSectionHeader('LIMPIAR INVENTARIO'),
        CleanModeToggle(pick: false, onChanged: mode),
        SizedBox(height: DsSpace.sm),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          DsButton('DESARMAR',
              key: const ValueKey('inv-clean-salvage'),
              size: DsButtonSize.compact,
              tooltip: 'Recibís materiales',
              selected: !sell,
              onPressed: () => setState(() => _cleanOp = CraftOp.salvageAll)),
          DsButton('VENDER',
              key: const ValueKey('inv-clean-sell'),
              size: DsButtonSize.compact,
              tooltip: 'Recibís créditos',
              selected: sell,
              onPressed: () => setState(() => _cleanOp = CraftOp.sellAll)),
        ]),
        SizedBox(height: DsSpace.xs),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final rr in const [Rarity.comun, Rarity.magico, Rarity.raro])
            DsButton(
                '${rarityPlural(rr).toUpperCase()} '
                '(${rules.crafting.batchTargets(p, rr).length})',
                key: ValueKey('inv-clean-rarity-${rr.name}'),
                size: DsButtonSize.compact,
                selected: _cleanRarity == rr,
                onPressed: () => setState(() => _cleanRarity = rr)),
        ]),
        SizedBox(height: DsSpace.sm),
        ProtoText(summary, key: const ValueKey('inv-clean-summary')),
        if (r.lost.isNotEmpty)
          ProtoText(protoColor(
              ProtoColors.orange, 'Se pierde: ${protoEsc(r.lost.join(', '))}')),
        if (n > 0) ...[
          const SizedBox(height: 6),
          ProtoText(
              key: const ValueKey('inv-clean-list'),
              '${protoColor(ProtoColors.red, 'Se destruyen:')}<br>'
              '${[
                for (final it in targets)
                  '• ${itemNameMarkup(rules, it)}'
                      '${sell ? ' <small>₵${rules.crafting.sellPrice(it)}</small>' : ''}'
              ].join('<br>')}'),
        ],
      ],
    );
  }

  /// Enter sobre una casilla de la grilla: en MOVER / "elige B" es el
  /// clic; sobre la casilla ya elegida abre el menú de acciones (v0.9.9;
  /// Enter otra vez sobre "Equipar" la equipa); si no, la elige.
  void _activateCell(
      PlayerProfile p, String? token, int i, bool mine, String owner,
      {required VoidCallback cellTap, required VoidCallback openMenu}) {
    if (mine &&
        _moveFrom == null &&
        !_picking &&
        token != null &&
        token == _sel) {
      openMenu();
      return;
    }
    cellTap();
  }

  /// Debajo de la grilla (v0.9.9): la cantidad de una pila elegida y,
  /// con una confirmación abierta (TIRAR, VENDER, DESARMAR), la pregunta
  /// con CANCELAR y el botón rojo. Nada si no hace falta.
  Widget? _selectionBar(PlayerProfile p, SessionPlayer me,
      List<SessionPlayer> mates, CellContent c) {
    final confirming =
        _confirmDrop || (_confirmCraft != null && c.item != null);
    final list = _actions(p, me, mates, c);
    if (list.isEmpty) return null;
    if (!confirming) {
      return Padding(padding: const EdgeInsets.only(top: 6), child: list.first);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _gridW),
      // Franja roja a la izquierda (como un aviso), sin caja anidada.
      child: Container(
        key: const ValueKey('inv-confirm'),
        margin: EdgeInsets.only(top: DsSpace.sm),
        padding: EdgeInsets.all(DsSpace.sm),
        decoration: const BoxDecoration(
          color: DsColors.surface,
          border: Border(left: BorderSide(color: DsColors.danger, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            list.first,
            SizedBox(height: DsSpace.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: DsSpace.sm,
              runSpacing: DsSpace.xs,
              children: list.skip(1).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Abre el menú de acciones junto a la casilla con el cursor de
  /// teclado (Enter sobre la casilla ya elegida).
  void _openMenuAtFocus(PlayerProfile p, SessionPlayer me,
      List<SessionPlayer> mates, String token, int? cell) {
    final box = FocusManager.instance.primaryFocus?.context?.findRenderObject();
    final at = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset(box.size.width, 0))
        : (context.findRenderObject() as RenderBox?)
                ?.localToGlobal(Offset.zero)
                .translate(40, 40) ??
            Offset.zero;
    _openMenu(p, me, mates, token, cell, at);
  }

  List<Widget> _actions(PlayerProfile p, SessionPlayer me,
      List<SessionPlayer> mates, CellContent c) {
    final g = shop.guards;
    final token = _sel!;
    final it = c.item;
    final count = it == null ? _count.clamp(1, c.count) : 1;
    final name = it != null
        ? shop.rules.items.displayName(it)
        : c.eco != null
            ? shop.rules.ecos.fullName(c.eco!)
            : '$count ${c.stack!.label}';
    final confirmCraft = _confirmCraft;
    if (it != null && confirmCraft != null) {
      final a = CraftAction(confirmCraft, it.uid);
      final r = g.craftPreview(p, a);
      final sell = confirmCraft == CraftOp.sell;
      return [
        ProtoText(
            key: const ValueKey('inv-craft-question'),
            '¿${sell ? 'Vender' : 'Desarmar'} ${protoEsc(name)}? '
            'Recibes ${protoColor(ProtoColors.green, protoEsc(gainsText(credits: r.gainedCredits, materials: r.gainedMaterials, chances: r.outcomes)))}. '
            '${protoColor(ProtoColors.red, 'El arma se destruye.')}'
            '${r.lost.isEmpty ? '' : ' ${protoColor(ProtoColors.orange, 'Se pierde: ${protoEsc(r.lost.join(', '))}')}'}'),
        DsButton('CANCELAR',
            key: const ValueKey('inv-craft-cancel'),
            size: DsButtonSize.compact,
            onPressed: () => setState(() => _confirmCraft = null)),
        DsButton(sell ? 'VENDER ₵${r.gainedCredits}' : 'DESARMAR',
            key: const ValueKey('inv-craft-confirm'),
            size: DsButtonSize.compact,
            accent: DsColors.danger,
            tooltip: g.craft(p, a),
            onPressed: g.craft(p, a) != null
                ? null
                : () {
                    shop.controller.craft(a);
                    setState(() => _confirmCraft = null);
                  }),
      ];
    }
    if (_confirmDrop) {
      return [
        ProtoText(
            key: const ValueKey('inv-drop-question'),
            '¿Tirar ${protoEsc(name)} al piso? Lo puede levantar '
            'cualquiera.'),
        DsButton('CANCELAR',
            key: const ValueKey('inv-drop-cancel'),
            size: DsButtonSize.compact,
            onPressed: () => setState(() => _confirmDrop = false)),
        DsButton('TIRAR',
            key: const ValueKey('inv-drop-confirm'),
            size: DsButtonSize.compact,
            accent: DsColors.danger,
            tooltip: g.drop(p, token, count: count, alive: me.alive),
            onPressed: g.drop(p, token, count: count, alive: me.alive) != null
                ? null
                : () {
                    shop.controller.dropItem(token, count: count);
                    setState(() => _confirmDrop = false);
                  }),
      ];
    }
    return [
      if (it == null && c.eco == null && c.count > 1)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(retroText('Cantidad'), style: DsText.detail()),
            SizedBox(width: DsSpace.sm),
            DsButton.icon(const Text('-'),
                key: const ValueKey('inv-count-dec'),
                tooltip: 'Uno menos',
                size: DsButtonSize.compact,
                onPressed: count > 1
                    ? () => setState(() => _count = count - 1)
                    : null),
            SizedBox(width: DsSpace.xs),
            Text('x$count',
                key: const ValueKey('inv-count'),
                style: DsText.body(DsColors.textPrimary)),
            SizedBox(width: DsSpace.xs),
            DsButton.icon(const Text('+'),
                key: const ValueKey('inv-count-inc'),
                tooltip: 'Uno más',
                size: DsButtonSize.compact,
                onPressed: count < c.count
                    ? () => setState(() => _count = count + 1)
                    : null),
          ],
        ),
    ];
  }

  /// Acciones del token elegido como filas de menú (v0.9.7): Equipar,
  /// Comparar, Mover, Dar a..., Tirar, Desarmar, Vender. Las que no se
  /// pueden, en gris con el motivo en una línea (`inventoryReasonLine`).
  /// La misma lista va en el detalle y en el menú del clic derecho.
  /// Nombre del compañero; si se repite, con clase y nivel
  /// (`Héroe (Maga, Nv 6)`).
  String _mateLabel(SessionPlayer m, List<SessionPlayer> mates) {
    if (mates.where((o) => o.name == m.name).length < 2) return m.name;
    final p = m.profile;
    final cls = shop.rules.catalog.classes[p.classId]?.name ?? p.classId;
    return '${m.name} ($cls, Nv ${p.level})';
  }

  List<InventoryMenuEntry> _menuEntries(PlayerProfile p, SessionPlayer me,
      List<SessionPlayer> mates, CellContent c) {
    final g = shop.guards;
    final token = _sel!;
    final it = c.item;
    final count = it == null ? _count.clamp(1, c.count) : 1;
    String? why(InventoryMenuAction a, String? r) =>
        r == null ? null : inventoryReasonLine(a, r);
    String? short(InventoryMenuAction a, String? r) =>
        r == null ? null : inventoryReasonShort(a, r);
    InventoryMenuEntry craft(ItemInstance it, CraftOp op) {
      final act = CraftAction(op, it.uid);
      final sell = op == CraftOp.sell;
      final r = g.craftPreview(p, act);
      final ma = sell ? InventoryMenuAction.sell : InventoryMenuAction.salvage;
      final gains = gainsText(
          credits: r.gainedCredits,
          materials: r.gainedMaterials,
          chances: r.outcomes);
      final why2 = g.craft(p, act);
      return InventoryMenuEntry(
        id: sell ? 'sell' : 'salvage',
        shortReason: short(ma, why2),
        label: sell ? 'Vender ₵${shop.rules.crafting.sellPrice(it)}' : ma.label,
        note: sell ? null : gains,
        color: ProtoColors.orange,
        reason: why(ma, why2),
        onTap: () => setState(() => _confirmCraft = op),
      );
    }

    final eqReason =
        it == null ? null : g.equip(p, it.uid, pending: widget.pending);
    // Pociones fuera de batalla (loot.md § 17.5).
    final usable = token == StackKind.potion.token
        ? BattleItem.potion
        : token == StackKind.ether.token
            ? BattleItem.ether
            : null;
    return [
      if (usable != null)
        InventoryMenuEntry(
          id: 'use',
          label: 'Usar',
          color: ProtoColors.green,
          reason: shop.controller.useItemBlock(usable),
          onTap: () => shop.controller.useItem(usable),
        ),
      if (it != null)
        InventoryMenuEntry(
          id: 'equip',
          label: InventoryMenuAction.equip.label,
          color: ProtoColors.green,
          reason: why(InventoryMenuAction.equip, eqReason),
          shortReason: short(InventoryMenuAction.equip, eqReason),
          onTap: () => shop.controller.equip(it.uid),
        ),
      if (it != null && !_picking)
        InventoryMenuEntry(
          id: 'compare',
          label: InventoryMenuAction.compare.label,
          color: ProtoColors.sky,
          onTap: () => _startCompare(WeaponRef(me.id, token)),
        ),
      if (it != null || c.eco != null)
        InventoryMenuEntry(
          id: 'move',
          label: InventoryMenuAction.move.label,
          note: 'o arrastrá',
          reason: _selCell == null
              ? (it != null && it.uid == p.equippedUid
                  ? 'Está en su ranura de equipada'
                  : 'Va en su sección fija')
              : null,
          shortReason: _selCell == null
              ? (it != null && it.uid == p.equippedUid
                  ? 'equipada'
                  : 'lugar fijo')
              : null,
          onTap: () => setState(() => _moveFrom = _selCell),
        ),
      if (mates.isEmpty)
        InventoryMenuEntry(
          id: 'give',
          label: InventoryMenuAction.give.label,
          reason: why(
              InventoryMenuAction.give,
              g.give(p, token, null, count: count) ??
                  'No hay compañeros en la sala'),
          shortReason: short(
              InventoryMenuAction.give,
              g.give(p, token, null, count: count) ??
                  'No hay compañeros en la sala'),
        )
      else
        for (final m in mates)
          InventoryMenuEntry(
            id: 'give-${m.id}',
            label: 'Dar a ${_mateLabel(m, mates)}',
            color: ProtoColors.sky,
            reason: why(
                InventoryMenuAction.give, g.give(p, token, m, count: count)),
            shortReason: short(
                InventoryMenuAction.give, g.give(p, token, m, count: count)),
            onTap: () => shop.controller.give(m.id, token, count: count),
          ),
      InventoryMenuEntry(
        id: 'drop',
        label: InventoryMenuAction.drop.label,
        note: 'queda en el piso',
        color: ProtoColors.orange,
        reason: why(InventoryMenuAction.drop,
            g.drop(p, token, count: count, alive: me.alive)),
        shortReason: short(InventoryMenuAction.drop,
            g.drop(p, token, count: count, alive: me.alive)),
        // Ajuste CONFIRMAR AL TIRAR (docs/specs/settings.md § "JUEGO").
        onTap: () => ref.read(gameSettingsProvider).confirmDrop
            ? setState(() => _confirmDrop = true)
            : shop.controller.dropItem(token, count: count),
      ),
      // Alijo de la cuenta (characters.md § 3.2).
      InventoryMenuEntry(
        id: 'stash',
        label: 'Guardar en alijo',
        color: ProtoColors.sky,
        reason: shop.controller.stashPutReason(token),
        onTap: () => shop.controller.stashPut([token]),
      ),
      if (it != null) ...[
        craft(it, CraftOp.salvage),
        craft(it, CraftOp.sell),
      ],
    ];
  }

  /// Clic derecho sobre una casilla: la elige y abre el menú de acciones
  /// donde está el mouse.
  /// Rect global del buscador (el menú de la EQUIPADA no lo tapa).
  Rect? _searchRect() {
    final box = _searchKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _openMenu(PlayerProfile p, SessionPlayer me, List<SessionPlayer> mates,
      String token, int? cell, Offset at,
      {Rect? avoid}) {
    _select(token, cell);
    final c = _content(p, token);
    if (c == null) return;
    final title = c.item != null
        ? itemNameMarkup(shop.rules, c.item!)
        : c.eco != null
            ? protoEsc(shop.rules.ecos.fullName(c.eco!))
            : protoEsc(c.stack!.label);
    InventoryContextMenu.show(context, at,
        title: title, entries: _menuEntries(p, me, mates, c), avoid: avoid);
  }
}

/// Casilla clicable con foco de teclado (Enter / Espacio la activan).
class _CellButton extends StatelessWidget {
  const _CellButton(
      {super.key,
      required this.onTap,
      required this.child,
      this.onSecondaryTap});

  final VoidCallback onTap;
  final ValueChanged<Offset>? onSecondaryTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: {
          ActivateIntent:
              CallbackAction<ActivateIntent>(onInvoke: (_) => onTap()),
        },
        child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onSecondaryTapUp: onSecondaryTap == null
                ? null
                : (d) => onSecondaryTap!(d.globalPosition),
            child: child),
      );
}

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

/// Disposición del INVENTARIO según el ancho del panel (v0.12.0).
enum InventoryLayoutMode {
  /// Franja CAMBIOS | grilla | columna (EQUIPADA, pilas, casillas).
  wide,

  /// Franja CAMBIOS | grilla con la columna debajo.
  medium,

  /// Todo apilado: la franja arriba, la grilla y la columna debajo.
  narrow,
}

/// Resultado de [inventoryLayout]: disposición, escala de la casilla
/// (`InventoryTab.cell × scale`) y ancho del bloque grilla + columna.
typedef InventoryLayout = ({
  InventoryLayoutMode mode,
  double scale,
  double mainWidth,
});

/// Elige la disposición para un área de [w] × [h] px (panels.md §
/// "Inventario"): ancha si entran la franja ([stripWidth]), la grilla a
/// escala 1 y la columna de al lado ([sideMin]); media si entran la
/// franja y la grilla; si no, angosta. La escala es la mayor con la que
/// la grilla entra en el ancho que le queda y a lo alto (sin las pilas
/// en la ancha; con la EQUIPADA y las pilas debajo en las otras):
/// entera desde ×2 (nitidez del pixel art), en cuartos entre ×1 y ×2 y,
/// si ni ×1 entra a lo ancho, la que entre. Nunca más ancho que [w].
InventoryLayout inventoryLayout(double w, double h,
    {required double stripWidth, double sideMin = 240}) {
  const base = InventoryTab.gridWidth;
  const unit = InventoryTab.cell + InventoryTab.gap;
  const rows = InventoryRules.cells / InventoryRules.columns;
  const sep = 16.0;
  final width = w.isFinite ? w - 8 : stripWidth + base + sep + sideMin;
  double snap(double byW, double byH) {
    final k = byW < byH ? byW : byH;
    if (k < 1) return byW < 1 ? (byW > 0.3 ? byW : 0.3) : 1;
    return k >= 2 ? k.floorToDouble() : (k * 4).floorToDouble() / 4;
  }

  if (width >= stripWidth + base + sep + sideMin) {
    final byW = (width - stripWidth - sep - sideMin) / base;
    var k = snap(byW, h.isFinite ? (h - 30) / (rows * unit) : byW);
    // La columna de al lado lleva 4 pilas por fila al tamaño de la
    // casilla: si no entran, la grilla baja de escala (hasta ×1).
    double side(double k) => 4 * unit * k > sideMin ? 4 * unit * k : sideMin;
    while (k > 1 && base * k + sep + side(k) > width - stripWidth) {
      k = k > 2 ? k.ceilToDouble() - 1 : k - 0.25;
    }
    final gridW = base * k;
    final room = width - stripWidth - gridW - sep;
    final want = 6 * unit * k > sideMin ? 6 * unit * k : sideMin;
    return (
      mode: InventoryLayoutMode.wide,
      scale: k,
      mainWidth: gridW + sep + (room < want ? room : want),
    );
  }
  final byH = h.isFinite ? (h - 120) / ((rows + 2) * unit) : double.infinity;
  if (width >= stripWidth + base) {
    final k = snap((width - stripWidth) / base, byH);
    return (mode: InventoryLayoutMode.medium, scale: k, mainWidth: base * k);
  }
  final k = snap(width / base, byH);
  return (mode: InventoryLayoutMode.narrow, scale: k, mainWidth: width);
}
