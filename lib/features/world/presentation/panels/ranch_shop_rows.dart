import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/animal_rules.dart';
import '../../../inventory/domain/item_names.dart';
import '../session_controller.dart';
import '../world_strings.dart';
import 'life_icon.dart';
import 'life_item_grid.dart';

/// One cell of the GRANJA view of the farm shop (animals.md § 2, § 8):
/// its filter kind, whether it is a sale and the cell.
typedef RanchRow = ({String kind, bool sell, LifeItemCellData cell});

/// Filter kinds of GRANJA, in order (BUY, then SELL).
const kRanchBuyKinds = ['animals', 'hay', 'ranch_tools', 'ranch_homes'];
const kRanchSellKinds = ['animal_goods'];

/// Molecule rows of the GRANJA view: animals, hay, ranch tools and the
/// buildings (bought in EDITAR PUEBLO) to buy, and the animal products
/// to sell. Every disabled button says why in a detail line.
List<RanchRow> ranchShopRows(BuildContext context, SessionController c,
    PlayerProfile? p, TownState town,
    {double icon = 32}) {
  final gold = p?.credits ?? 0;
  final f = p?.life.farm;
  String? why(String? reason) => reason;
  Widget cost(int n) => DsGold(n, affordable: gold >= n);
  return [
    for (final a in kAnimals.values)
      () {
        final reason = p == null ? null : AnimalRules.cannotBuy(p, town, a.id);
        final home = context.t('ui.town.ranch.${a.home.name}.name');
        return (
          kind: 'animals',
          sell: false,
          cell: LifeItemCellData(
            id: 'ranch-animal-${a.id}',
            icon: LifeIcon(a.sprite, LifeIconKind.herramienta, size: icon),
            border: DsColors.border,
            search: a.text,
            caption: context.t('ui.town.trader.price_short', {'n': a.price}),
            detail: LifeItemDetail(
              itemId: a.sprite,
              name: a.text,
              nameColor: DsColors.textPrimary,
              cost: cost(a.price),
              tags: [
                (context.t('ui.town.ranch.tag_animal'), DsColors.textSecondary),
                (home, DsColors.textSecondary),
              ],
              lines: [
                context.t('ui.town.ranch.gives', {
                  'item': a.productDef.text,
                  'n': a.every,
                }),
                if (a.tool case final t?)
                  context.t('ui.town.ranch.needs_tool', {'tool': t.text})
                else
                  context.t('ui.town.ranch.on_floor'),
                context.t('ui.town.ranch.lives_in', {'home': home}),
                context.t('ui.town.ranch.level', {'n': a.level}),
                if (why(reason) case final r?) r,
              ],
              actions: [
                DsButton(context.t('ui.town.ranch.buy'),
                    key: ValueKey('ranch-buy-${a.id}'),
                    size: DsButtonSize.compact,
                    tooltip: reason,
                    onPressed: reason == null ? () => c.buyAnimal(a.id) : null),
              ],
            ),
          ),
        );
      }(),
    (
      kind: 'hay',
      sell: false,
      cell: LifeItemCellData(
        id: 'ranch-hay',
        icon: LifeIcon(kHayId, LifeIconKind.herramienta, size: icon),
        border: DsColors.border,
        search: hayText,
        count: (f?.hay ?? 0) > 0 ? f!.hay : null,
        caption: context.t('ui.town.trader.price_short',
            {'n': AnimalRules.hayPrice}),
        detail: LifeItemDetail(
          itemId: kHayId,
          name: hayText,
          nameColor: DsColors.textPrimary,
          cost: cost(AnimalRules.hayPrice),
          tags: [(context.t('ui.town.ranch.tag_hay'), DsColors.textSecondary)],
          lines: [
            context.t('ui.town.ranch.hay_info'),
            context.t('ui.town.trader.have', {'n': f?.hay ?? 0}),
            context.t('ui.town.ranch.chop_info',
                {'n': AnimalRules.t.i('hayPerCrop')}),
          ],
          actions: [
            for (final q in const [1, 10])
              DsButton(
                  context.t('ui.town.trader.buy_qty',
                      {'qty': q, 'n': AnimalRules.hayPrice * q}),
                  key: ValueKey('ranch-hay-buy$q'),
                  size: DsButtonSize.compact,
                  onPressed: gold >= AnimalRules.hayPrice * q
                      ? () => c.buyHay(q)
                      : null),
            // PICAR FARDOS: the most plentiful crop of the bag.
            if (_chopKey(p) case final k?)
              DsButton(context.t('ui.town.ranch.chop'),
                  key: const ValueKey('ranch-hay-chop'),
                  size: DsButtonSize.compact,
                  tooltip: kCrops[k.split('@').first]?.text ?? k,
                  onPressed: () => c.makeHay(k, 1))
            else
              DsButton(context.t('ui.town.ranch.chop'),
                  key: const ValueKey('ranch-hay-chop'),
                  size: DsButtonSize.compact,
                  tooltip: context.t('ui.town.ranch.chop_none'),
                  onPressed: null),
          ],
        ),
      ),
    ),
    for (final t in RanchTool.values)
      () {
        final reason = p == null ? null : AnimalRules.cannotBuyTool(p, t);
        final has = f?.hasTool(t) ?? false;
        return (
          kind: 'ranch_tools',
          sell: false,
          cell: LifeItemCellData(
            id: 'ranch-tool-${t.id}',
            icon: LifeIcon(t.sprite, LifeIconKind.herramienta, size: icon),
            border: DsColors.border,
            search: t.text,
            equipped: has,
            caption: has
                ? context.t('ui.town.ranch.owned')
                : context.t('ui.town.trader.price_short', {'n': t.price}),
            detail: LifeItemDetail(
              itemId: t.sprite,
              name: t.text,
              nameColor: DsColors.textPrimary,
              cost: has ? null : cost(t.price),
              tags: [
                (context.t('ui.town.ranch.tag_tool'), DsColors.textSecondary)
              ],
              lines: [
                context.t('ui.town.ranch.tool_${t.id}'),
                if (has) context.t('ui.town.ranch.owned_line'),
                if (!has && reason != null) reason,
              ],
              actions: [
                DsButton(context.t('ui.town.ranch.buy'),
                    key: ValueKey('ranch-tool-buy-${t.id}'),
                    size: DsButtonSize.compact,
                    tooltip: has ? null : reason,
                    onPressed:
                        reason == null ? () => c.buyRanchTool(t.id) : null),
              ],
            ),
          ),
        );
      }(),
    for (final h in kAnimalHomes.values)
      () {
        final reason = p == null ? null : AnimalRules.cannotBuild(p, h.id);
        final name = context.t('ui.town.ranch.${h.kind.name}.name');
        return (
          kind: 'ranch_homes',
          sell: false,
          cell: LifeItemCellData(
            id: 'ranch-home-${h.id}',
            icon: LifeIcon(h.sprite, LifeIconKind.herramienta, size: icon),
            border: DsColors.border,
            search: name,
            count: switch (town.builds.where((b) => b.kind == h.kind).length) {
              0 => null,
              final n => n,
            },
            caption: context.t('ui.town.trader.price_short', {'n': h.price}),
            detail: LifeItemDetail(
              itemId: h.sprite,
              name: name,
              nameColor: DsColors.textPrimary,
              cost: cost(h.price),
              tags: [
                (context.t('ui.town.ranch.tag_home'), DsColors.textSecondary)
              ],
              lines: [
                context.t('ui.town.ranch.${h.kind.name}.info',
                    {'cap': h.cap, 'level': h.level}),
                context.t('ui.town.ranch.build_where'),
                if (reason != null) reason,
              ],
              actions: [
                DsButton(context.t('ui.town.ranch.build'),
                    key: ValueKey('ranch-home-build-${h.id}'),
                    size: DsButtonSize.compact,
                    tooltip: reason ?? c.cannotEditTown,
                    onPressed: reason == null && c.cannotEditTown == null
                        ? () {
                            c.closePanel();
                            c.enterTownEdit();
                          }
                        : null),
              ],
            ),
          ),
        );
      }(),
    for (final e in (f?.goods ?? const <String, int>{}).entries)
      if (parseAnimalGoodsKey(e.key) case (final d, final q)?)
        (
          kind: 'animal_goods',
          sell: true,
          cell: LifeItemCellData(
            id: 'ranch-goods-${e.key}',
            icon: LifeIcon(d.sprite, LifeIconKind.cosecha, size: icon),
            border: qualityColor(q),
            search: animalGoodsName(e.key),
            count: e.value,
            caption: context.t('ui.town.trader.price_short',
                {'n': AnimalRules.unitPrice(e.key)}),
            detail: LifeItemDetail(
              itemId: d.sprite,
              name: animalGoodsName(e.key),
              nameColor: qualityColor(q),
              tags: [
                (context.t('ui.town.ranch.tag_goods'), DsColors.textSecondary)
              ],
              lines: [
                context.t('ui.town.trader.have', {'n': e.value}),
                context.t('ui.town.trader.worth_each',
                    {'n': AnimalRules.unitPrice(e.key)}),
              ],
              actions: [
                DsButton(context.t('ui.town.trader.sell_all'),
                    key: ValueKey('ranch-sell-${e.key}'),
                    size: DsButtonSize.compact,
                    onPressed: () => c.sellGoods(e.key)),
              ],
            ),
          ),
        ),
  ];
}

/// Border / name colour of a product quality (normal, plata, oro).
Color qualityColor(CropQuality q) => switch (q) {
      CropQuality.normal => DsColors.border,
      CropQuality.raro => DsColors.textSecondary,
      _ => DsColors.reward,
    };

/// The crop key PICAR FARDOS uses: the one the bag has most of.
String? _chopKey(PlayerProfile? p) {
  final crops = p?.life.farm.crops ?? const <String, int>{};
  String? best;
  var n = 0;
  for (final e in crops.entries) {
    if (e.value > n) {
      n = e.value;
      best = e.key;
    }
  }
  return best;
}
