import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'life_icon.dart';
import 'life_item_grid.dart';
import 'life_tool_text.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import '../world_strings.dart';

/// Puesto del AGROPECUARIO (fishing.md § 5, v0.23.2): primero COMPRAR o
/// VENDER, después PESCA o CULTIVO. Buscador y filtro por tipo siempre a
/// la vista; "Cobrar en" (oro o materiales) solo al VENDER.
class TraderPanel extends StatefulWidget {
  const TraderPanel(
      {super.key,
      required this.view,
      required this.controller,
      this.tab = 0,
      this.mode = 0});

  final SessionView view;
  final SessionController controller;

  /// Pestaña inicial: 0 PESCA, 1 CULTIVO.
  final int tab;

  /// Modo inicial: 0 COMPRAR, 1 VENDER.
  final int mode;

  @override
  State<TraderPanel> createState() => _TraderPanelState();
}

class _TraderPanelState extends State<TraderPanel> {
  bool _materials = false;
  late int _tab = widget.tab;
  late int _mode = widget.mode;
  String _query = '';
  String? _kind;

  /// Categorías de cada vista, en orden (nunca se mezclan).
  /// Label of a filter kind (`null`: all).
  String _kindLabel(String? k) => context.t(switch (k) {
        'cañas' => 'ui.town.trader.kind.rods',
        'semillas' => 'ui.town.trader.kind.seeds',
        'abonos' => 'ui.town.trader.kind.ferts',
        'azadas' => 'ui.town.trader.kind.hoes',
        'regaderas' => 'ui.town.trader.kind.cans',
        'peces' => 'ui.town.trader.kind.fish',
        'basura' => 'ui.town.trader.kind.junk',
        'legendarios' => 'ui.town.trader.kind.legendary',
        'cultivos' => 'ui.town.trader.kind.crops',
        _ => 'ui.town.trader.kind.all',
      });

  List<String> get _kinds => switch ((_mode, _tab)) {
        (0, 0) => const ['cañas'],
        (0, _) => const ['semillas', 'abonos', 'azadas', 'regaderas'],
        (_, 0) => const ['peces', 'basura', 'legendarios'],
        _ => const ['cultivos', 'legendarios'],
      };

  SessionController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final p = widget.view.me?.profile;
    final fishSellAll = p != null &&
        p.life.bag.keys.any((k) => kFish[k]?.rarity != FishRarity.legendario);
    final cropSellAll = p != null &&
        p.life.farm.crops.keys
            .any((k) => parseCropKey(k)?.$1.rarity != FishRarity.legendario);
    return PanelFrame(
      key: const ValueKey('panel-trader'),
      title: context.t('ui.town.trader.title'),
      width: 760,
      onClose: c.closePanel,
      actions: [
        if (_mode == 1)
          PanelButton(context.t('ui.town.trader.sell_all'),
              key: const ValueKey('trade-sell-all'),
              onPressed: (_tab == 0 ? fishSellAll : cropSellAll)
                  ? () => _tab == 0
                      ? c.sellFish(materials: _materials)
                      : c.sellCrop(null, materials: _materials)
                  : null),
        PanelButton(context.t('ui.town.trader.close'),
            key: const ValueKey('trade-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsTabBar(
            tabs: [
              DsTab(context.t('ui.town.trader.buy'), key: const ValueKey('trade-mode-buy')),
              DsTab(context.t('ui.town.trader.sell'), key: const ValueKey('trade-mode-sell')),
            ],
            index: _mode,
            onChanged: (i) => setState(() {
              _mode = i;
              _kind = null;
            }),
          ),
          SizedBox(height: DsSpace.xs),
          DsTabBar(
            tabs: [
              DsTab(context.t('ui.town.trader.tab_fishing'), key: const ValueKey('trade-tab-pesca')),
              DsTab(context.t('ui.town.trader.tab_crops'), key: const ValueKey('trade-tab-cultivo')),
            ],
            index: _tab,
            onChanged: (i) => setState(() {
              _tab = i;
              _kind = null;
            }),
          ),
          SizedBox(height: DsSpace.sm),
          Row(children: [
            DsSearchField(
                key: const ValueKey('trade-search'),
                hint: context.t('ui.town.trader.search'),
                onChanged: (v) => setState(() => _query = v)),
            const Spacer(),
            Text(context.t('ui.town.trader.gold', {'n': p?.credits ?? 0}),
                key: const ValueKey('trade-gold-have'), style: DsText.detail()),
          ]),
          SizedBox(height: DsSpace.xs),
          // Categorías (filtro): nunca se mezclan en la lista.
          Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
            for (final k in [null, ..._kinds])
              DsButton(_kindLabel(k),
                  key: ValueKey('trade-filter-${k ?? 'todo'}'),
                  size: DsButtonSize.compact,
                  selected: _kind == k,
                  onPressed: () => setState(() => _kind = k)),
          ]),
          if (_mode == 1) ...[
            SizedBox(height: DsSpace.xs),
            Row(children: [
              Text(context.t('ui.town.trader.charge_in'), style: DsText.subtitle()),
              SizedBox(width: DsSpace.sm),
              DsButton(context.t('ui.town.trader.gold_button'),
                  key: const ValueKey('trade-gold'),
                  size: DsButtonSize.compact,
                  selected: !_materials,
                  onPressed: () => setState(() => _materials = false)),
              SizedBox(width: DsSpace.xs),
              DsButton(context.t('ui.town.trader.materials'),
                  key: const ValueKey('trade-mats'),
                  size: DsButtonSize.compact,
                  selected: _materials,
                  onPressed: () => setState(() => _materials = true)),
            ]),
            Text(
                _materials
                    ? context.t('ui.town.trader.materials_note', {
                        'pct': ((FishingRules.t.d('matRate') - 1) * 100).round(),
                        'gold': FishingRules.t.i('matValue')
                      })
                    : context.t('ui.town.trader.sell_all_note'),
                style: DsText.detail()),
          ],
          SizedBox(height: DsSpace.sm),
          // Grilla de casillas con el detalle de la elegida (v0.24.4).
          SizedBox(
            height:
                (MediaQuery.sizeOf(context).height * 0.42).clamp(200.0, 440.0),
            child: LifeItemGrid(
              key: ValueKey('trade-grid-$_mode-$_tab'),
              groups: _visible(_tab == 0 ? _fishing() : _farming()),
              empty: _query.isNotEmpty || _kind != null
                  ? context.t('ui.town.trader.no_match')
                  : _mode == 1
                      ? (_tab == 0
                          ? context.t('ui.town.trader.no_fish')
                          : context.t('ui.town.trader.no_crops'))
                      : context.t('ui.town.trader.nothing_to_buy'),
              emptyKey:
                  ValueKey(_tab == 0 ? 'trade-empty' : 'trade-crop-empty'),
            ),
          ),
        ],
      ),
    );
  }

  /// Grupos del modo actual con lo que pasa el buscador y el filtro.
  List<LifeItemGroup> _visible(List<_Row> rows) {
    final q = _query.toLowerCase();
    return [
      for (final k in _kinds)
        if (_kind == null || _kind == k)
          LifeItemGroup(
              k.toUpperCase(),
              [
                for (final r in rows)
                  if (r.sell == (_mode == 1) &&
                      r.kind == k &&
                      (q.isEmpty || r.cell.search.toLowerCase().contains(q)))
                    r.cell
              ],
              headerKey: ValueKey('trade-group-$k')),
    ];
  }

  static const _icon = LifeItemGrid.iconSize;

  /// Botón CANJEAR de un legendario.
  Widget _swap(
          String key, VoidCallback onPressed, int cristales, int prismas) =>
      DsButton(context.t('ui.town.trader.swap'),
          key: ValueKey(key),
          size: DsButtonSize.compact,
          tooltip: context.t('ui.town.trader.swap_tip', {'crystals': cristales, 'prisms': prismas}),
          onPressed: onPressed);

  // ---------------- PESCA ----------------

  List<_Row> _fishing() {
    final p = widget.view.me?.profile;
    final bag = p?.life.bag ?? const <String, int>{};
    final lvl = p == null ? 1 : FishingRules.level(p);
    final t = FishingRules.t;
    final species = [
      for (final f in kFish.values)
        if ((bag[f.id] ?? 0) > 0) f
    ];
    return [
      for (final r in kRods.values)
        _Row(
            'cañas',
            LifeItemCellData(
              id: 'trade-rod-${r.id}',
              icon: LifeIcon(r.id, LifeIconKind.herramienta, size: _icon),
              border: fishRarityColor(r.rarity),
              search: r.name,
              equipped: p?.life.rod == r.id,
              caption: p?.life.rods.contains(r.id) ?? false
                  ? context.t('ui.town.trader.owned')
                  : context.t('ui.town.trader.price_short', {'n': r.price}),
              detail: LifeItemDetail(
                name: r.name,
                nameColor: fishRarityColor(r.rarity),
                tags: [
                  (context.t('ui.town.trader.tag_rod'), DsColors.textSecondary),
                  (r.rarity.label.toUpperCase(), fishRarityColor(r.rarity)),
                ],
                lines: [
                  ...rodLines(r, lvl),
                  context.t('ui.town.trader.price', {'n': r.price}),
                ],
                hoverTip: true,
                compare: p == null
                    ? null
                    : rodCompare(
                        r, kRods[p.life.rod] ?? kRods[kStarterRod]!, lvl),
                actions: [_rodButton(r)],
              ),
            )),
      for (final f in species)
        _Row(
            f.biome == kWaterJunkBiome
                ? 'basura'
                : f.rarity == FishRarity.legendario
                    ? 'legendarios'
                    : 'peces',
            sell: true,
            LifeItemCellData(
              id: 'trade-row-${f.id}',
              icon: LifeIcon(
                  f.id,
                  f.biome == kWaterJunkBiome
                      ? LifeIconKind.basura
                      : LifeIconKind.pescado,
                  size: _icon),
              border: fishRarityColor(f.rarity),
              search: f.name,
              count: bag[f.id],
              caption: context.t('ui.town.trader.price_short', {'n': f.price}),
              detail: LifeItemDetail(
                name: f.name,
                nameColor: fishRarityColor(f.rarity),
                tags: [
                  (
                    f.biome == kWaterJunkBiome ? context.t('ui.town.trader.tag_junk') : context.t('ui.town.trader.tag_fish'),
                    DsColors.textSecondary
                  ),
                  (f.rarity.label.toUpperCase(), fishRarityColor(f.rarity)),
                ],
                lines: [
                  context.t('ui.town.trader.have', {'n': bag[f.id]}),
                  context.t('ui.town.trader.worth_each', {'n': f.price}),
                ],
                actions: [
                  if (f.rarity == FishRarity.legendario)
                    _swap('trade-swap-${f.id}', () => c.exchangeFish(f.id),
                        t.i('legendCristales'), t.i('legendPrismas')),
                  DsButton(context.t('ui.town.trader.sell'),
                      key: ValueKey('trade-sell-${f.id}'),
                      size: DsButtonSize.compact,
                      onPressed: () =>
                          c.sellFish(species: f.id, materials: _materials)),
                ],
              ),
            )),
    ];
  }

  Widget _rodButton(RodDef r) {
    final p = widget.view.me?.profile;
    final owned = p?.life.rods.contains(r.id) ?? false;
    if (p?.life.rod == r.id) {
      return DsButton(context.t('ui.town.trader.equipped'),
          key: ValueKey('trade-rod-eq-${r.id}'),
          size: DsButtonSize.compact,
          onPressed: null);
    }
    if (owned) {
      return DsButton(context.t('ui.town.trader.equip'),
          key: ValueKey('trade-rod-eq-${r.id}'),
          size: DsButtonSize.compact,
          onPressed: () => c.equipRod(r.id));
    }
    return DsButton(context.t('ui.town.trader.buy_price', {'n': r.price}),
        key: ValueKey('trade-rod-buy-${r.id}'),
        size: DsButtonSize.compact,
        onPressed: (p?.credits ?? 0) >= r.price ? () => c.buyRod(r.id) : null);
  }

  // ---------------- CULTIVO ----------------

  List<_Row> _farming() {
    final p = widget.view.me?.profile;
    final f = p?.life.farm;
    final lvl = p == null ? 1 : FarmingRules.level(p);
    final gold = p?.credits ?? 0;
    final t = FarmingRules.t;
    final seeds = [
      for (final s in kCrops.values)
        if (s.seedPrice > 0) s
    ];
    final crops = [
      for (final e in (f?.crops ?? const <String, int>{}).entries)
        if (parseCropKey(e.key) case final pc?) (e.key, pc.$1, pc.$2, e.value)
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return [
      for (final s in seeds)
        _Row(
            'semillas',
            LifeItemCellData(
              id: 'trade-seed-${s.id}',
              icon: LifeIcon('semilla_${s.id}', LifeIconKind.semilla,
                  size: _icon),
              border: fishRarityColor(s.rarity),
              search: s.seedName,
              count: (f?.seedCount(s.id) ?? 0) > 0 ? f!.seedCount(s.id) : null,
              caption: context.t('ui.town.trader.price_short', {'n': s.seedPrice}),
              detail: LifeItemDetail(
                name: s.seedName,
                nameColor: fishRarityColor(s.rarity),
                tags: [
                  (context.t('ui.town.trader.tag_seed'), DsColors.textSecondary),
                  (s.rarity.label.toUpperCase(), fishRarityColor(s.rarity)),
                ],
                lines: [
                  context.t('ui.town.trader.grows_in', {'min': (s.growSec / 60).round()}),
                  context.t('ui.town.trader.have', {'n': f?.seedCount(s.id) ?? 0}),
                  context.t('ui.town.trader.price_each', {'n': s.seedPrice}),
                ],
                actions: [
                  DsButton(context.t('ui.town.trader.buy_qty', {'qty': 1, 'n': s.seedPrice}),
                      key: ValueKey('trade-seed-buy-${s.id}'),
                      size: DsButtonSize.compact,
                      onPressed:
                          gold >= s.seedPrice ? () => c.buySeed(s.id) : null),
                  DsButton(context.t('ui.town.trader.buy_qty', {'qty': 5, 'n': s.seedPrice * 5}),
                      key: ValueKey('trade-seed-buy5-${s.id}'),
                      size: DsButtonSize.compact,
                      onPressed: gold >= s.seedPrice * 5
                          ? () => c.buySeed(s.id, 5)
                          : null),
                ],
              ),
            )),
      for (final d in kFertilizers.values)
        _Row(
            'abonos',
            LifeItemCellData(
              id: 'trade-fert-${d.id}',
              icon: LifeIcon(d.id, LifeIconKind.semilla, size: _icon),
              border: fishRarityColor(d.rarity),
              search: d.name,
              count: (f?.fertCount(d.id) ?? 0) > 0 ? f!.fertCount(d.id) : null,
              caption: context.t('ui.town.trader.price_short', {'n': d.price}),
              detail: LifeItemDetail(
                name: d.name,
                nameColor: fishRarityColor(d.rarity),
                tags: [
                  (context.t('ui.town.trader.tag_fert'), DsColors.textSecondary),
                  (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
                ],
                lines: [
                  context.t('ui.town.trader.fert_bias', {'n': t.d('fert${d.key}Bias')}),
                  context.t('ui.town.trader.fert_speed', {'n': t.d('fert${d.key}Speed')}),
                  context.t('ui.town.trader.have', {'n': f?.fertCount(d.id) ?? 0}),
                  context.t('ui.town.trader.price', {'n': d.price}),
                ],
                description: context.t('ui.town.trader.fert_desc'),
                actions: [
                  DsButton(context.t('ui.town.trader.buy_price', {'n': d.price}),
                      key: ValueKey('trade-fert-buy-${d.id}'),
                      size: DsButtonSize.compact,
                      onPressed:
                          gold >= d.price ? () => c.buyFert(d.id) : null),
                ],
              ),
            )),
      for (final d in kFarmTools.values)
        if (d.price > 0 || _owned(d))
          _Row(
              d.kind == FarmToolKind.azada ? 'azadas' : 'regaderas',
              LifeItemCellData(
                id: 'trade-tool-${d.id}',
                icon: LifeIcon(d.id, LifeIconKind.herramienta, size: _icon),
                border: fishRarityColor(d.rarity),
                search: d.name,
                equipped:
                    (d.kind == FarmToolKind.azada ? f?.hoe : f?.can) == d.id,
                caption: _owned(d)
                    ? context.t('ui.town.trader.owned')
                    : context.t('ui.town.trader.price_short', {'n': d.price}),
                detail: LifeItemDetail(
                  name: d.name,
                  nameColor: fishRarityColor(d.rarity),
                  tags: [
                    (d.kind.label.toUpperCase(), DsColors.textSecondary),
                    (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
                  ],
                  lines: [
                    ...farmToolLines(d, lvl),
                    context.t('ui.town.trader.price', {'n': d.price}),
                  ],
                  hoverTip: true,
                  compare: p == null
                      ? null
                      : farmToolCompare(
                          d,
                          d.kind == FarmToolKind.azada
                              ? FarmingRules.hoeOf(p)
                              : FarmingRules.canOf(p),
                          lvl),
                  actions: [_toolButton(d)],
                ),
              )),
      for (final (key, crop, quality, n) in crops)
        _Row(
            crop.rarity == FishRarity.legendario ? 'legendarios' : 'cultivos',
            sell: true,
            LifeItemCellData(
              id: 'trade-crop-$key',
              icon: LifeIcon('cosecha_${crop.id}', LifeIconKind.cosecha,
                  size: _icon),
              border: fishRarityColor(crop.rarity),
              search: crop.name,
              count: n,
              caption:
                  context.t('ui.town.trader.price_short', {'n': p == null ? crop.price : FarmingRules.unitPrice(p, crop, quality)}),
              detail: LifeItemDetail(
                name: crop.name,
                nameColor: fishRarityColor(crop.rarity),
                tags: [
                  (context.t('ui.town.trader.tag_crop'), DsColors.textSecondary),
                  (
                    context.t('ui.town.trader.tag_quality', {'q': quality.label.toUpperCase()}),
                    DsColors.textSecondary
                  ),
                ],
                lines: [
                  context.t('ui.town.trader.have', {'n': n}),
                  context.t('ui.town.trader.worth_each', {'n': p == null ? crop.price : FarmingRules.unitPrice(p, crop, quality)}),
                ],
                actions: [
                  if (crop.rarity == FishRarity.legendario)
                    _swap('trade-crop-swap-$key', () => c.exchangeCrop(key),
                        t.i('legendCristales'), t.i('legendPrismas')),
                  DsButton(context.t('ui.town.trader.sell'),
                      key: ValueKey('trade-crop-sell-$key'),
                      size: DsButtonSize.compact,
                      onPressed: () => c.sellCrop(key, materials: _materials)),
                ],
              ),
            )),
    ];
  }

  bool _owned(FarmToolDef d) {
    final f = widget.view.me?.profile.life.farm;
    return (d.kind == FarmToolKind.azada ? f?.hoes : f?.cans)?.contains(d.id) ??
        false;
  }

  Widget _toolButton(FarmToolDef d) {
    final f = widget.view.me?.profile.life.farm;
    final gold = widget.view.me?.profile.credits ?? 0;
    final equipped = d.kind == FarmToolKind.azada ? f?.hoe : f?.can;
    if (equipped == d.id) {
      return DsButton(context.t('ui.town.trader.equipped'),
          key: ValueKey('trade-tool-eq-${d.id}'),
          size: DsButtonSize.compact,
          onPressed: null);
    }
    if (_owned(d)) {
      return DsButton(context.t('ui.town.trader.equip'),
          key: ValueKey('trade-tool-eq-${d.id}'),
          size: DsButtonSize.compact,
          onPressed: () => c.equipFarmTool(d.id));
    }
    return DsButton(context.t('ui.town.trader.buy_price', {'n': d.price}),
        key: ValueKey('trade-tool-buy-${d.id}'),
        size: DsButtonSize.compact,
        onPressed: gold >= d.price ? () => c.buyFarmTool(d.id) : null);
  }
}

/// Una casilla del puesto: tipo (filtro), modo y la casilla.
class _Row {
  const _Row(this.kind, this.cell, {this.sell = false});
  final String kind;
  final LifeItemCellData cell;
  final bool sell;
}
