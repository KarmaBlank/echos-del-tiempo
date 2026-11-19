import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/action_card.dart';
import '../../../app/widgets/cost_chip.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../app/widgets/section_panel.dart';
import '../../../core/settings/settings_providers.dart';
import '../../../game_engine/models/attributes.dart';
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
import '../domain/item_text.dart';
import 'clean_selection.dart';
import 'consumables_bar.dart';
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

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

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
      {bool equipped = false}) {
    final it = c.item;
    final mine = owner.id == me.id;
    final using = shop.rules.equippedItem(me.profile)?.uid;
    if (it == null || (mine && it.uid == using)) {
      return RetroTooltip(
          message: it == null
              ? _tooltip(me.profile, c, attrs)
              : itemTooltipMarkup(shop.rules, it,
                      skillDetails: true,
                      level: me.profile.level,
                      attributes: attrs,
                      equipped: equipped) +
                  _fitLine(it),
          child: child);
    }
    final fit = buildFitMarkup(_fit(it));
    final card = HoverCompareCard(
        rules: shop.rules,
        viewer: me.profile,
        item: it,
        attributes: attrs,
        ownerName: mine ? null : owner.name);
    return RetroHoverCard(
      builder: (_) => fit == null
          ? card
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                card,
                Container(
                  key: const ValueKey('inv-build-fit-hover'),
                  padding: const EdgeInsets.all(6),
                  color: ProtoColors.bg,
                  child: ProtoText(fit),
                ),
              ],
            ),
      child: child,
    );
  }

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
    final attrs = me.profile.attributes.add(widget.pending);
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

    final owners = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        PanelButton(view.actingCompanion ? me.name.toUpperCase() : 'TÚ',
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
      if (c != null) w = _withTip(me, owner, c, attrs, w);
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
          behavior: HitTestBehavior.opaque, onTap: tap, child: w);
      if (mine && !pickMode) {
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
        : _withTip(
            me,
            owner,
            CellContent.item(eq),
            attrs,
            ItemCell(
                rules: shop.rules,
                content: CellContent.item(eq),
                selected: _sel == eq.uid,
                buildMatch: _fit(eq).any),
            equipped: true);
    final left = NavSection(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: owners),
            if (mine) ...[
              const SizedBox(width: 6),
              InventorySortButton(
                  current: _lastSort,
                  onSort: (k) {
                    setState(() => _lastSort = k);
                    shop.controller.sortInventory(k);
                  }),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _CellButton(
                key: const ValueKey('inv-equipped'),
                onTap: () {
                  if (eq == null) return;
                  if (_pickB(owner.id, eq.uid, CellContent.item(eq))) return;
                  _select(eq.uid, null);
                },
                child: eqCell),
            const SizedBox(width: 8),
            Expanded(
              child: ProtoText('<b style="color:#ffd166">EQUIPADA</b><br>'
                  '${eq == null ? '—' : itemNameMarkup(shop.rules, eq)}'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_picking)
          Row(children: [
            Expanded(
                child: ProtoText(
                    key: const ValueKey('inv-compare-pick'),
                    protoColor(ProtoColors.sky,
                        'Elige el arma B para comparar con ${_cmpAName()}'))),
            PanelButton('CANCELAR',
                key: const ValueKey('inv-compare-cancel'),
                onPressed: _closeCompare),
          ])
        else if (_moveFrom != null)
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
          // Flechas: el cursor recorre la grilla y elige la casilla;
          // Enter otra vez sobre un arma la equipa (menu_focus.dart).
          child: InitialFocus(
              child: FocusGrid(
            count: InventoryRules.cells,
            columns: InventoryRules.columns,
            spacing: InventoryTab.gap,
            keyPrefix: 'inv-focus-',
            cell: (_, i, __) => cellAt(i),
            onFocusCell: (i) {
              final t = layout.cells[i];
              if (pickMode) return;
              if (_moveFrom == null && !_picking && t != null) _select(t, i);
            },
            // ELEGIR A MANO: Enter / Espacio marcan o desmarcan.
            onActivate: (i) => pickMode
                ? togglePick(layout.cells[i])
                : _activateCell(
                p, layout.cells[i], i, mine, owner.id, cellTap: () {
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
            }),
          )),
        ),
        const SizedBox(height: 8),
        // CONSUMIBLES / MATERIALES (v0.5.1): pilas fuera de la grilla; las
        // flechas bajan desde la grilla y Enter las elige.
        InventoryStacksBar(
          rules: shop.rules,
          profile: p,
          cell: InventoryTab.cell,
          gap: InventoryTab.gap,
          selected: _sel,
          onSelect: pickMode || _picking || _moveFrom != null
              ? null
              : (t) => _select(t, null),
        ),
        const SizedBox(height: 6),
        ProtoText(
            key: const ValueKey('inv-summary'),
            'Casillas ${InventoryRules.cellsUsed(p)}/${InventoryRules.cells}'
            '${mine ? ' · <b>₵${p.credits}</b>' : ''}'
            '${layout.overflow.isEmpty ? '' : ' · ${protoColor(ProtoColors.orange, '${layout.overflow.length} sin lugar')}'}'),
        if (mine) ...[
          const SizedBox(height: 6),
          PanelButton('LIMPIAR INVENTARIO...',
              key: const ValueKey('inv-clean'),
              selected: _cleaning,
              onPressed: () => setState(() {
                    _cleaning = !_cleaning;
                    _picked = const [];
                    _confirmDrop = false;
                    _confirmCraft = null;
                    _moveFrom = null;
                  })),
        ],
      ],
    ));

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
      return PanelSplit(
        listWidth: InventoryTab.gridWidth + 4,
        scaleList: false,
        list: [left],
        detail: _cleaner(p),
      );
    }

    final compareButton = sel?.item == null || _picking
        ? null
        : PanelButton('COMPARAR',
            key: const ValueKey('inv-compare'),
            onPressed: () => _startCompare(WeaponRef(owner.id, _sel!)));
    return Focus(
      focusNode: _keys,
      onKeyEvent: _onKey,
      child: PanelSplit(
        listWidth: InventoryTab.gridWidth + 4,
        scaleList: false,
        list: [left],
        detail: PanelDetail(
          footer: [
            const KeyHints(confirm: 'Elegir / equipar', back: 'Cerrar'),
            if (!mine) ...[
              const Text('Solo lectura',
                  style: TextStyle(color: ProtoColors.dim)),
              if (compareButton != null) compareButton,
            ],
          ],
          children: sel == null
              ? [
                  Text(retroText('Elige una casilla.'),
                      style: const TextStyle(color: ProtoColors.dim)),
                ]
              : _withActions(_detail(p, me.profile, sel, attrs, mine),
                  mine ? _actionsSection(p, me, mates, sel) : null,
                  item: sel.item != null),
        ),
      ),
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
        : 'Vas a ${sell ? 'vender' : 'desarmar'} <b>${protoEsc(what)}</b> → '
            '${protoColor(ProtoColors.green, protoEsc(gainsText(credits: r.gainedCredits, materials: r.gainedMaterials, chances: r.outcomes)))}';
    return PanelDetail(
      footer: [
        PanelButton('CANCELAR',
            key: const ValueKey('inv-clean-cancel'),
            onPressed: () => setState(() => _cleaning = false)),
        PanelButton(
            '${sell ? 'VENDER' : 'DESARMAR'} ${n == 0 ? '' : '$n '}'
            '${rarityPlural(_cleanRarity).toUpperCase()}',
            key: const ValueKey('inv-clean-confirm'),
            accent: ProtoColors.red,
            reason: g.craft(p, a), onPressed: () {
          shop.controller.craft(a);
          setState(() {});
        }),
      ],
      children: [
        const Text('LIMPIAR INVENTARIO',
            style: TextStyle(color: ProtoColors.gold)),
        const SizedBox(height: 4),
        CleanModeToggle(pick: false, onChanged: mode),
        const SizedBox(height: 6),
        ProtoText(protoColor(
            ProtoColors.dim,
            'Desarma o vende de una vez todas las armas de una rareza. Nunca '
            'toca la equipada ni tu última arma inicial.')),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          PanelButton('DESARMAR (materiales)',
              key: const ValueKey('inv-clean-salvage'),
              selected: !sell,
              onPressed: () => setState(() => _cleanOp = CraftOp.salvageAll)),
          PanelButton('VENDER (créditos)',
              key: const ValueKey('inv-clean-sell'),
              selected: sell,
              onPressed: () => setState(() => _cleanOp = CraftOp.sellAll)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final rr in const [Rarity.comun, Rarity.magico, Rarity.raro])
            PanelButton(
                '${rarityPlural(rr).toUpperCase()} '
                '(${rules.crafting.batchTargets(p, rr).length})',
                key: ValueKey('inv-clean-rarity-${rr.name}'),
                selected: _cleanRarity == rr,
                onPressed: () => setState(() => _cleanRarity = rr)),
        ]),
        const SizedBox(height: 8),
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

  /// Las acciones van antes de la ficha (se ven sin bajar).
  List<Widget> _withActions(List<Widget> detail, Widget? actions,
      {required bool item}) {
    if (actions == null) return detail;
    if (!item || detail.isEmpty) return [...detail, actions];
    return [...detail.take(detail.length - 1), actions, detail.last];
  }

  /// Enter sobre una casilla de la grilla: en MOVER / "elige B" es el
  /// clic; sobre el arma ya elegida la equipa si se puede; si no, la
  /// elige.
  void _activateCell(
      PlayerProfile p, String? token, int i, bool mine, String owner,
      {required VoidCallback cellTap}) {
    final it = token == null ? null : p.itemByUid(token);
    if (mine &&
        _moveFrom == null &&
        !_picking &&
        it != null &&
        token == _sel &&
        it.uid != p.equippedUid &&
        shop.guards.equip(p, it.uid, pending: widget.pending) == null) {
      shop.controller.equip(it.uid);
      return;
    }
    cellTap();
  }

  List<Widget> _detail(PlayerProfile p, PlayerProfile viewer, CellContent c,
      PlayerAttributes attrs, bool mine) {
    final it = c.item;
    final eco = c.eco;
    if (eco != null) {
      return [
        SectionPanel(
          icon: PixelIconKind.gem,
          title: 'ECO',
          subtitle: 'ábrelo en el Portal del Eco',
          children: [
            ProtoText(key: const ValueKey('inv-eco-detail'), _ecoTip(eco)),
          ],
        ),
      ];
    }
    if (it == null) {
      return [
        SectionPanel(
          icon: PixelIconKind.shard,
          title: 'OBJETO',
          children: [ProtoText(stackTooltipMarkup(c.stack!, c.count))],
        ),
      ];
    }
    final equipped = it.uid == p.equippedUid;
    final rules = shop.rules;
    final eq = rules.equippedItem(viewer);
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ProtoText(
                key: const ValueKey('inv-detail-title'),
                '${itemNameMarkup(rules, it)}'
                '${equipped ? ' ${protoColor(ProtoColors.gold, 'EQUIPADA')}' : ''}'),
          ),
          BuildFitBadge(item: it, compact: false),
        ],
      ),
      const SizedBox(height: 4),
      if (!equipped || !mine)
        SectionPanel(
          icon: PixelIconKind.arrowIn,
          title: 'SI LA EQUIPAS',
          children: [
            StatsCompare(
              title: 'Comparada con '
                  '${eq == null ? '-' : protoEsc(rules.items.displayName(eq))}',
              before: shop.preview.current(viewer, attributes: attrs),
              after: shop.preview.withItem(viewer, it, attributes: attrs),
            ),
          ],
        ),
      SectionPanel(
        icon: PixelIconKind.sword,
        title: 'FICHA',
        children: [
          ItemCard(
            rules: rules,
            item: it,
            level: viewer.level,
            attributes: attrs,
            stats: shop.preview.withItem(viewer, it, attributes: attrs),
            equipped: equipped,
          ),
          if (buildFitMarkup(_fit(it)) case final fit?)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ProtoText(fit, key: const ValueKey('inv-build-fit')),
            ),
        ],
      ),
    ];
  }

  /// Sección ACCIONES del detalle: una tarjeta por acción (con su costo o
  /// lo que recibes, o el motivo completo si no se puede) o, si hay una
  /// confirmación abierta, la pregunta con CANCELAR y el botón rojo.
  Widget _actionsSection(PlayerProfile p, SessionPlayer me,
      List<SessionPlayer> mates, CellContent c) {
    final confirming =
        _confirmDrop || (_confirmCraft != null && c.item != null);
    final list = _actions(p, me, mates, c);
    return SectionPanel(
      icon: confirming ? PixelIconKind.lock : PixelIconKind.check,
      color: confirming ? ProtoColors.red : ProtoColors.gold,
      title: confirming ? 'CONFIRMAR' : 'ACCIONES',
      subtitle: confirming ? null : 'clic o Enter',
      children: confirming
          ? [
              list.first,
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: list.skip(1).toList(),
              ),
            ]
          : list,
    );
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
            '¿${sell ? 'Vender' : 'Desarmar'} <b>${protoEsc(name)}</b>? '
            'Recibes ${protoColor(ProtoColors.green, protoEsc(gainsText(credits: r.gainedCredits, materials: r.gainedMaterials, chances: r.outcomes)))}. '
            '${protoColor(ProtoColors.red, 'El arma se destruye.')}'
            '${r.lost.isEmpty ? '' : ' ${protoColor(ProtoColors.orange, 'Se pierde: ${protoEsc(r.lost.join(', '))}')}'}'),
        PanelButton('CANCELAR',
            key: const ValueKey('inv-craft-cancel'),
            onPressed: () => setState(() => _confirmCraft = null)),
        PanelButton(sell ? 'VENDER ₵${r.gainedCredits}' : 'DESARMAR',
            key: const ValueKey('inv-craft-confirm'),
            accent: ProtoColors.red,
            reason: g.craft(p, a), onPressed: () {
          shop.controller.craft(a);
          setState(() => _confirmCraft = null);
        }),
      ];
    }
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
    final cards = <Widget>[
      if (it != null && it.uid != p.equippedUid)
        ActionCard(
          key: const ValueKey('inv-equip'),
          icon: _icon(PixelIconKind.check, ProtoColors.green),
          title: '<b>EQUIPAR</b>',
          description: 'Pasa a ser tu arma (fuera de las misiones).',
          reason: g.equip(p, it.uid, pending: widget.pending),
          footer: g.equip(p, it.uid, pending: widget.pending) == null
              ? const CostChip([])
              : null,
          onTap: () {
            if (g.equip(p, it.uid, pending: widget.pending) == null) {
              shop.controller.equip(it.uid);
            }
          },
        ),
      if (it != null && !_picking)
        ActionCard(
          key: const ValueKey('inv-compare'),
          icon: _icon(PixelIconKind.arrowIn, ProtoColors.sky),
          title: '<b>COMPARAR</b>',
          description: 'Elige otra arma y mira las dos lado a lado.',
          onTap: () => _startCompare(WeaponRef(me.id, token)),
        ),
      if (_selCell != null)
        ActionCard(
          key: const ValueKey('inv-move'),
          icon: _icon(PixelIconKind.arrowIn, ProtoColors.gold),
          title: '<b>MOVER</b>',
          description: 'Después elige la casilla destino (o arrastra).',
          onTap: () => setState(() => _moveFrom = _selCell),
        ),
      if (mates.isEmpty)
        ActionCard(
          key: const ValueKey('inv-give'),
          icon: _icon(PixelIconKind.plus, ProtoColors.sky),
          title: '<b>DAR A...</b>',
          description: 'Pásalo a un compañero de la sala.',
          reason: g.give(p, token, null, count: count) ?? 'Sin compañeros',
          onTap: () {},
        )
      else
        for (final m in mates)
          ActionCard(
            key: ValueKey('inv-give-${m.id}'),
            icon: _icon(PixelIconKind.plus, ProtoColors.sky),
            title: '<b>DAR A ${protoEsc(m.name.toUpperCase())}</b>',
            description: 'Lo recibe en su inventario.',
            reason: g.give(p, token, m, count: count),
            onTap: () {
              if (g.give(p, token, m, count: count) == null) {
                shop.controller.give(m.id, token, count: count);
              }
            },
          ),
      ActionCard(
        key: const ValueKey('inv-drop'),
        icon: _icon(PixelIconKind.trash, ProtoColors.orange),
        title: '<b>TIRAR</b>',
        description: 'Queda en el piso: lo puede levantar cualquiera.',
        reason: g.drop(p, token, count: count, alive: me.alive),
        // Ajuste CONFIRMAR AL TIRAR (docs/specs/settings.md § "JUEGO").
        onTap: () {
          if (g.drop(p, token, count: count, alive: me.alive) != null) return;
          ref.read(gameSettingsProvider).confirmDrop
              ? setState(() => _confirmDrop = true)
              : shop.controller.dropItem(token, count: count);
        },
      ),
      if (it != null) ...[
        _craftCard(p, it, CraftOp.salvage),
        _craftCard(p, it, CraftOp.sell),
      ],
    ];
    return [
      if (it == null && c.eco == null && c.count > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(retroText('Cantidad'),
                  style: const TextStyle(color: ProtoColors.sky)),
              const SizedBox(width: 8),
              PanelButton('-',
                  key: const ValueKey('inv-count-dec'),
                  onPressed: count > 1
                      ? () => setState(() => _count = count - 1)
                      : null),
              const SizedBox(width: 6),
              Text('x$count', key: const ValueKey('inv-count')),
              const SizedBox(width: 6),
              PanelButton('+',
                  key: const ValueKey('inv-count-inc'),
                  onPressed: count < c.count
                      ? () => setState(() => _count = count + 1)
                      : null),
            ],
          ),
        ),
      CardGrid(minWidth: 200, children: cards),
    ];
  }

  Widget _icon(PixelIconKind k, Color color) => Builder(
      builder: (context) =>
          PixelIcon(k, size: RetroType.width(context, 20), color: color));

  /// DESARMAR / VENDER: lo que recibes en el pie (o el motivo).
  Widget _craftCard(PlayerProfile p, ItemInstance it, CraftOp op) {
    final g = shop.guards;
    final a = CraftAction(op, it.uid);
    final reason = g.craft(p, a);
    final sell = op == CraftOp.sell;
    final r = g.craftPreview(p, a);
    final gains = gainsText(
        credits: r.gainedCredits,
        materials: r.gainedMaterials,
        chances: r.outcomes);
    return ActionCard(
      key: ValueKey(sell ? 'inv-sell' : 'inv-salvage'),
      icon: _icon(sell ? PixelIconKind.coin : PixelIconKind.anvil,
          sell ? ProtoColors.gold : ProtoColors.sky),
      title: sell
          ? '<b>VENDER ₵${shop.rules.crafting.sellPrice(it)}</b>'
          : '<b>DESARMAR</b>',
      description: sell
          ? 'El arma se destruye y recibes créditos.'
          : 'El arma se destruye y recibes materiales.',
      reason: reason,
      footer: reason == null ? CostChip.note('Recibes $gains') : null,
      onTap: () {
        if (reason == null) setState(() => _confirmCraft = op);
      },
    );
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
