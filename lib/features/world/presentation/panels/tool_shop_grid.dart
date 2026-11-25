import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/data/mine_catalog.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../../game_engine/rules/mining_rules.dart';
import '../../../inventory/domain/item_names.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';
import 'life_tool_text.dart';

/// TALLER DE OFICIOS › HERRAMIENTAS (town_loop.md § 2.1, v0.48.5): the
/// only place that sells trade tools (rods, hoes, cans, picks). One
/// inventory grid with a chip per tool kind and the detail on the right.
/// Buying and equipping use the same host-validated actions as before.
class ToolShopGrid extends StatelessWidget {
  const ToolShopGrid({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  static const _icon = LifeItemGrid.iconSize;

  @override
  Widget build(BuildContext context) => LifeItemGrid(
        key: const ValueKey('tools-grid'),
        maxDetail: 420,
        groups: [
          LifeItemGroup(context.t('ui.town.trader.kind.rods'), _rods(context),
              headerKey: const ValueKey('tools-filter-rods')),
          LifeItemGroup(
              context.t('ui.town.trader.kind.hoes'),
              _farm(context, FarmToolKind.azada),
              headerKey: const ValueKey('tools-filter-hoes')),
          LifeItemGroup(
              context.t('ui.town.trader.kind.cans'),
              _farm(context, FarmToolKind.regadera),
              headerKey: const ValueKey('tools-filter-cans')),
          LifeItemGroup(context.t('ui.town.trader.kind.mine_tools'),
              _picks(context),
              headerKey: const ValueKey('tools-filter-picks')),
        ],
        empty: context.t('ui.town.trader.nothing_to_buy'),
        emptyKey: const ValueKey('tools-empty'),
      );

  SessionController get c => controller;

  DsButton _button(BuildContext context, String key,
          {required bool equipped,
          required bool owned,
          required int price,
          required VoidCallback onBuy,
          VoidCallback? onEquip}) =>
      equipped
          ? DsButton(context.t('ui.town.trader.equipped'),
              key: ValueKey('$key-eq'),
              size: DsButtonSize.compact,
              onPressed: null)
          : owned
              ? DsButton(context.t('ui.town.trader.equip'),
                  key: ValueKey('$key-eq'),
                  size: DsButtonSize.compact,
                  onPressed: onEquip)
              : DsButton(context.t('ui.town.trader.buy_price', {'n': price}),
                  key: ValueKey('$key-buy'),
                  size: DsButtonSize.compact,
                  kind: DsButtonKind.primary,
                  tooltip: (view.me?.profile.credits ?? 0) >= price
                      ? null
                      : context.t('ui.inventory.workshop.not_enough'),
                  onPressed:
                      (view.me?.profile.credits ?? 0) >= price ? onBuy : null);

  List<LifeItemCellData> _rods(BuildContext context) {
    final p = view.me?.profile;
    final lvl = p == null ? 1 : FishingRules.level(p);
    return [
      for (final r in kRods.values)
        LifeItemCellData(
          id: 'tools-rod-${r.id}',
          icon: LifeIcon(r.id, LifeIconKind.herramienta, size: _icon),
          border: fishRarityColor(r.rarity),
          search: r.text,
          equipped: p?.life.rod == r.id,
          detail: LifeItemDetail(
            name: r.text,
            nameColor: fishRarityColor(r.rarity),
            itemId: r.id,
            tags: [
              (context.t('ui.town.trader.tag_rod'), DsColors.textSecondary),
              (r.rarity.label.toUpperCase(), fishRarityColor(r.rarity)),
            ],
            lines: [
              ...rodLines(r, lvl),
              context.t('ui.town.trader.price', {'n': r.price}),
            ],
            compare: p == null
                ? null
                : rodCompare(r, kRods[p.life.rod] ?? kRods[kStarterRod]!, lvl),
            actions: [
              _button(context, 'tools-rod-${r.id}',
                  equipped: p?.life.rod == r.id,
                  owned: p?.life.rods.contains(r.id) ?? false,
                  price: r.price,
                  onBuy: () => c.buyRod(r.id),
                  onEquip: () => c.equipRod(r.id)),
            ],
          ),
        ),
    ];
  }

  List<LifeItemCellData> _farm(BuildContext context, FarmToolKind kind) {
    final p = view.me?.profile;
    final f = p?.life.farm;
    final lvl = p == null ? 1 : FarmingRules.level(p);
    bool owned(FarmToolDef d) =>
        (d.kind == FarmToolKind.azada ? f?.hoes : f?.cans)?.contains(d.id) ??
        false;
    return [
      for (final d in kFarmTools.values)
        if (d.kind == kind && (d.price > 0 || owned(d)))
          LifeItemCellData(
            id: 'tools-farm-${d.id}',
            icon: LifeIcon(d.id, LifeIconKind.herramienta, size: _icon),
            border: fishRarityColor(d.rarity),
            search: d.text,
            equipped: (kind == FarmToolKind.azada ? f?.hoe : f?.can) == d.id,
            detail: LifeItemDetail(
              name: d.text,
              nameColor: fishRarityColor(d.rarity),
              itemId: d.id,
              tags: [
                (d.kind.label.toUpperCase(), DsColors.textSecondary),
                (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
              ],
              lines: [
                ...farmToolLines(d, lvl),
                context.t('ui.town.trader.price', {'n': d.price}),
              ],
              compare: p == null
                  ? null
                  : farmToolCompare(
                      d,
                      kind == FarmToolKind.azada
                          ? FarmingRules.hoeOf(p)
                          : FarmingRules.canOf(p),
                      lvl),
              actions: [
                _button(context, 'tools-farm-${d.id}',
                    equipped:
                        (kind == FarmToolKind.azada ? f?.hoe : f?.can) == d.id,
                    owned: owned(d),
                    price: d.price,
                    onBuy: () => c.buyFarmTool(d.id),
                    onEquip: () => c.equipFarmTool(d.id)),
              ],
            ),
          ),
    ];
  }

  List<LifeItemCellData> _picks(BuildContext context) {
    final p = view.me?.profile;
    return [
      for (final t in kMineTools)
        if (t.tier > 0)
          () {
            final name = context.t('data.materials.smith.${t.id}.name');
            final have = p?.life.ore(t.id) ?? 0;
            final price = MiningRules.price(t.id);
            return LifeItemCellData(
              id: 'tools-pick-${t.id}',
              icon: LifeIcon(t.id, LifeIconKind.herramienta, size: _icon),
              border: DsColors.border,
              search: name,
              equipped: have > 0,
              detail: LifeItemDetail(
                name: name,
                nameColor: DsColors.textPrimary,
                itemId: t.id,
                tags: [
                  (context.t('ui.town.trader.kind.mine_tools'),
                      DsColors.textSecondary),
                  (context.t('ui.inventory.workshop.tier', {'n': t.tier}),
                      DsColors.textSecondary),
                ],
                lines: [
                  context.t('ui.town.trader.price', {'n': price}),
                ],
                actions: [
                  _button(context, 'tools-pick-${t.id}',
                      equipped: have > 0,
                      owned: false,
                      price: price,
                      onBuy: () => c.buyMine(t.id)),
                ],
              ),
            );
          }(),
    ];
  }
}
