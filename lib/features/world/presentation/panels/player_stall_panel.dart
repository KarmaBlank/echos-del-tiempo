import 'package:material_ui/material_ui.dart';
import '../../../inventory/domain/item_names.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/data/smithing_catalog.dart' show kSmithMaterials;
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/life_give_rules.dart';
import '../../../../game_engine/rules/stall_rules.dart';
import '../../../../game_engine/rules/weather_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';
import 'life_items_view.dart' show cropQualityColor;

/// The player's own stall (docs/specs/player_shop.md § 5): MY STALL
/// (listings and the bag to list from), the teammates' stalls and the
/// sales log. Grid + detail, tabs never stacked.
class PlayerStallPanel extends StatefulWidget {
  const PlayerStallPanel(
      {super.key, required this.view, required this.controller, this.tab = 0});

  final SessionView view;
  final SessionController controller;

  /// 0 MY STALL, 1 TEAM STALLS, 2 LOG.
  final int tab;

  @override
  State<PlayerStallPanel> createState() => _PlayerStallPanelState();
}

class _PlayerStallPanelState extends State<PlayerStallPanel> {
  late int _tab = widget.tab;

  /// MY STALL filter: false = on sale, true = the bag.
  bool _bag = false;

  /// Picked price step per cell (index in [StallRules.priceSteps]).
  final Map<String, int> _step = {};

  SessionController get c => widget.controller;

  static const _icon = LifeItemGrid.iconSize;

  /// Name, icon and border color of a stall cell.
  ({String name, Widget icon, Color color})? _look(String cell, [double? size]) {
    final i = cell.indexOf(':');
    final kind = cell.substring(0, i), id = cell.substring(i + 1);
    final s = size ?? _icon;
    switch (kind) {
      case 'fish':
        final f = kFish[id];
        if (f == null) return null;
        return (
          name: f.text,
          icon: LifeIcon(f.id, LifeIconKind.pescado, size: s),
          color: fishRarityColor(f.rarity)
        );
      case 'crop':
        final pc = parseCropKey(id);
        if (pc == null) return null;
        return (
          name: pc.$1.text,
          icon: LifeIcon('cosecha_${pc.$1.id}', LifeIconKind.cosecha, size: s),
          color: cropQualityColor(pc.$2)
        );
      case 'ore':
        final d = kSmithMaterials[id];
        if (d == null) return null;
        return (
          name: context.t(d.textKey),
          icon: LifeIcon('mat_${d.id}', LifeIconKind.herramienta, size: s),
          color: DsColors.border
        );
    }
    return null;
  }

  /// Bag cells that can be listed.
  List<(String, int)> _bagCells(PlayerProfile p) => [
        for (final e in p.life.bag.entries) ('fish:${e.key}', e.value),
        for (final e in p.life.farm.crops.entries) ('crop:${e.key}', e.value),
        for (final e in p.life.ores.entries) ('ore:${e.key}', e.value),
      ].where((x) => StallRules.refPrice(x.$1) > 0).toList();

  String _demand(String cell) {
    final d = StallRules.demand(
        cell, WeatherRules.season(c.town.sky.day));
    return context.t('ui.town.stall.demand', {'pct': (d * 100).round()});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.view.me?.profile;
    return PanelFrame(
      key: const ValueKey('panel-stall'),
      title: context.t('ui.town.stall.title'),
      width: 760,
      fill: true,
      onClose: c.closePanel,
      actions: [
        PanelButton(context.t('ui.town.trader.close'),
            key: const ValueKey('stall-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsTabBar(
            tabs: [
              DsTab(context.t('ui.town.stall.tab_mine'),
                  key: const ValueKey('stall-tab-mine')),
              DsTab(context.t('ui.town.stall.tab_team'),
                  key: const ValueKey('stall-tab-team')),
              DsTab(context.t('ui.town.stall.tab_log'),
                  key: const ValueKey('stall-tab-log')),
            ],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          SizedBox(height: DsSpace.sm),
          Row(children: [
            if (_tab == 0) ...[
              DsButton(context.t('ui.town.stall.on_sale'),
                  key: const ValueKey('stall-filter-sale'),
                  size: DsButtonSize.compact,
                  selected: !_bag,
                  onPressed: () => setState(() => _bag = false)),
              SizedBox(width: DsSpace.xs),
              DsButton(context.t('ui.town.stall.bag'),
                  key: const ValueKey('stall-filter-bag'),
                  size: DsButtonSize.compact,
                  selected: _bag,
                  onPressed: () => setState(() => _bag = true)),
              SizedBox(width: DsSpace.sm),
              Text(
                  context.t('ui.town.stall.slots', {
                    'n': p?.life.stall.listings.length ?? 0,
                    'max': StallRules.slots
                  }),
                  key: const ValueKey('stall-slots'),
                  style: DsText.detail()),
            ],
            if (_tab == 2)
              DsGoldText(
                  context.t('ui.town.stall.earned',
                      {'n': p?.life.stall.earned ?? 0}),
                  key: const ValueKey('stall-earned'),
                  style: DsText.detail()),
            const Spacer(),
            Text(context.t('ui.town.trader.gold', {'n': p?.credits ?? 0}),
                key: const ValueKey('stall-gold'), style: DsText.detail()),
          ]),
          SizedBox(height: DsSpace.xs),
          Text(context.t('ui.town.stall.note'), style: DsText.detail()),
          SizedBox(height: DsSpace.sm),
          Expanded(
            child: LifeItemGrid(
              key: ValueKey('stall-grid-$_tab-$_bag'),
              groups: [
                LifeItemGroup(null, switch (_tab) {
                  0 => p == null ? const [] : _mine(p),
                  1 => p == null ? const [] : _team(p),
                  _ => p == null ? const [] : _log(p),
                }),
              ],
              empty: context.t(switch (_tab) {
                0 => _bag ? 'ui.town.stall.empty_bag' : 'ui.town.stall.empty_mine',
                1 => 'ui.town.stall.empty_team',
                _ => 'ui.town.stall.empty_log',
              }),
              emptyKey: const ValueKey('stall-empty'),
            ),
          ),
        ],
      ),
    );
  }

  /// Price-step chips for [cell] (selected = the picked one).
  List<Widget> _priceChips(String cell, int picked) => [
        for (var i = 0; i < StallRules.priceSteps.length; i++)
          DsButton(
              context.t('ui.town.trader.price_short',
                  {'n': StallRules.stepPrice(cell, StallRules.priceSteps[i])}),
              key: ValueKey('stall-step-$i-$cell'),
              size: DsButtonSize.compact,
              selected: picked == i,
              onPressed: () => setState(() => _step[cell] = i)),
      ];

  int _picked(String cell, int? current) {
    if (_step[cell] case final i?) return i;
    if (current != null) {
      for (var i = 0; i < StallRules.priceSteps.length; i++) {
        if (StallRules.stepPrice(cell, StallRules.priceSteps[i]) == current) {
          return i;
        }
      }
    }
    return 1;
  }

  String? _blockText(StallBlock? b) => switch (b) {
        null => null,
        StallBlock.full => context.t('ui.town.stall.block_full'),
        StallBlock.gold => context.t('ui.town.stall.block_gold'),
        StallBlock.bagFull => context.t('ui.town.stall.block_bag'),
        _ => null,
      };

  List<LifeItemCellData> _mine(PlayerProfile p) {
    final st = p.life.stall;
    final cells = _bag
        ? _bagCells(p)
        : [for (final l in st.listings) (l.cell, l.qty)];
    return [
      for (final (cell, n) in cells)
        if (_look(cell) case final look?) _mineCell(p, cell, n, look),
    ];
  }

  LifeItemCellData _mineCell(PlayerProfile p, String cell, int n,
      ({String name, Widget icon, Color color}) look) {
    final cur = p.life.stall.listing(cell);
    final picked = _picked(cell, cur?.price);
    final price = StallRules.stepPrice(cell, StallRules.priceSteps[picked]);
    final have = LifeGiveRules.have(p, cell);
    final b1 = StallRules.listBlock(p, cell, 1, price);
    final ball = have < 1
        ? StallBlock.missing
        : StallRules.listBlock(p, cell, have, price);
    final id = cell.replaceAll(':', '-').replaceAll('@', '-');
    return LifeItemCellData(
      id: 'stall-mine-$id',
      icon: look.icon,
      border: look.color,
      search: look.name,
      count: n,
      caption: cur == null
          ? null
          : context.t('ui.town.trader.price_short', {'n': cur.price}),
      detail: LifeItemDetail(
        name: look.name,
        nameColor: look.color,
        tags: [
          if (cur != null)
            (context.t('ui.town.stall.tag_listed'), DsColors.success),
        ],
        lines: [
          context.t('ui.town.trader.have', {'n': have}),
          if (cur != null)
            context.t('ui.town.stall.listed', {'n': cur.qty, 'p': cur.price}),
          context.t('ui.town.stall.ref', {'n': StallRules.refPrice(cell)}),
          _demand(cell),
        ],
        chips: const [],
        actions: [
          Wrap(
              spacing: DsSpace.xs,
              runSpacing: DsSpace.xs,
              children: _priceChips(cell, picked)),
          DsButton(context.t('ui.town.stall.put_one'),
              key: ValueKey('stall-put1-$id'),
              size: DsButtonSize.compact,
              tooltip: _blockText(b1),
              onPressed: b1 == null ? () => c.stallList(cell, 1, price) : null),
          DsButton(context.t('ui.town.stall.put_all'),
              key: ValueKey('stall-putall-$id'),
              size: DsButtonSize.compact,
              tooltip: _blockText(ball),
              onPressed:
                  ball == null ? () => c.stallList(cell, have, price) : null),
          if (cur != null && cur.price != price)
            DsButton(context.t('ui.town.stall.reprice'),
                key: ValueKey('stall-reprice-$id'),
                size: DsButtonSize.compact,
                onPressed: () => c.stallList(cell, 0, price)),
          if (cur != null)
            DsButton(context.t('ui.town.stall.take_back'),
                key: ValueKey('stall-unlist-$id'),
                size: DsButtonSize.compact,
                onPressed: () => c.stallUnlist(cell)),
        ],
      ),
    );
  }

  List<LifeItemCellData> _team(PlayerProfile me) {
    final out = <LifeItemCellData>[];
    for (final o in widget.view.session.players.values) {
      if (o.id == widget.view.localId || o.isCompanion) continue;
      for (final l in o.profile.life.stall.listings) {
        final look = _look(l.cell);
        if (look == null) continue;
        final id = '${o.id}-${l.cell.replaceAll(':', '-').replaceAll('@', '-')}';
        StallBlock? block(int n) =>
            StallRules.buyBlock(o.profile, me, l.cell, n);
        final b1 = block(1), ball = block(l.qty);
        out.add(LifeItemCellData(
          id: 'stall-team-$id',
          icon: look.icon,
          border: look.color,
          search: '${look.name} ${o.name}',
          count: l.qty,
          caption: context.t('ui.town.trader.price_short', {'n': l.price}),
          detail: LifeItemDetail(
            name: look.name,
            nameColor: look.color,
            tags: [(o.name.toUpperCase(), DsColors.textSecondary)],
            lines: [
              context.t('ui.town.stall.seller', {'name': o.name}),
              context.t('ui.town.stall.listed', {'n': l.qty, 'p': l.price}),
              context.t('ui.town.stall.ref', {'n': StallRules.refPrice(l.cell)}),
            ],
            actions: [
              DsButton(
                  context.t('ui.town.trader.buy_qty', {'qty': 1, 'n': l.price}),
                  key: ValueKey('stall-buy1-$id'),
                  size: DsButtonSize.compact,
                  tooltip: _blockText(b1),
                  onPressed:
                      b1 == null ? () => c.stallBuy(o.id, l.cell, 1) : null),
              if (l.qty > 1)
                DsButton(
                    context.t('ui.town.trader.buy_qty',
                        {'qty': l.qty, 'n': l.price * l.qty}),
                    key: ValueKey('stall-buyall-$id'),
                    size: DsButtonSize.compact,
                    tooltip: _blockText(ball),
                    onPressed: ball == null
                        ? () => c.stallBuy(o.id, l.cell, l.qty)
                        : null),
            ],
          ),
        ));
      }
    }
    return out;
  }

  List<LifeItemCellData> _log(PlayerProfile p) {
    final log = p.life.stall.log.reversed.toList();
    return [
      for (var i = 0; i < log.length; i++)
        if (_look(log[i].cell) case final look?)
          LifeItemCellData(
            id: 'stall-log-$i',
            icon: look.icon,
            border: look.color,
            search: look.name,
            count: log[i].qty,
            caption: context.t('ui.town.trader.price_short', {'n': log[i].gold}),
            detail: LifeItemDetail(
              name: look.name,
              nameColor: look.color,
              tags: [
                (
                  log[i].byVisitor
                      ? context.t('ui.town.stall.visitor')
                      : log[i].buyer.toUpperCase(),
                  DsColors.textSecondary
                ),
              ],
              lines: [
                context.t('ui.town.stall.log_day', {'n': log[i].day}),
                context.t('ui.town.stall.log_sold',
                    {'n': log[i].qty, 'gold': log[i].gold}),
              ],
            ),
          ),
    ];
  }
}
