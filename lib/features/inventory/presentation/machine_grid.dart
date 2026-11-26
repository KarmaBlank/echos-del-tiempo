import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/animal_rules.dart';
import '../../world/presentation/panels/life_icon.dart';
import '../../world/presentation/panels/life_item_grid.dart';
import '../../world/presentation/panels/ranch_shop_rows.dart'
    show qualityColor;
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/world_strings.dart';
import '../domain/item_names.dart';

/// TALLER DE OFICIOS › MÁQUINAS (animals.md § 11): the cheese press and
/// the mayonnaise machine to buy, and every product of the bag one of
/// them can turn into a dearer one of the same quality. INVENTARIO cells
/// anchored top-left (icon only, the rest in the tooltip and the detail);
/// buttons grey with the reason in the tooltip when they cannot be used.
class MachineGrid extends StatelessWidget {
  const MachineGrid(
      {super.key, required this.profile, required this.controller});

  final PlayerProfile profile;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final p = profile, c = controller;
    const icon = LifeItemGrid.iconSize;
    final f = p.life.farm;
    String? why(MachineBlock? b) => switch (b) {
          null => null,
          MachineBlock.noMachine =>
            context.t('ui.town.ranch.machine.why.none'),
          MachineBlock.level => context.t('ui.town.ranch.machine.why.level',
              {'n': AnimalRules.t.i('machineLevel')}),
          MachineBlock.nothing ||
          MachineBlock.notProcessable =>
            context.t('ui.town.ranch.machine.why.nothing'),
        };
    final machines = [
      for (final t in RanchTool.values)
        if (t.machine) _machine(context, p, t),
    ];
    final inputs = [
      for (final e in f.goods.entries)
        if (e.value > 0 && AnimalRules.processedKey(e.key) != null) e,
    ]..sort((a, b) => a.key.compareTo(b.key));
    final goods = [
      for (final e in inputs)
        () {
          final pk = parseAnimalGoodsKey(e.key)!;
          final out = AnimalRules.processedKey(e.key)!;
          final name = animalGoodsName(e.key);
          final one = why(AnimalRules.cannotProcess(p, e.key, 1));
          return LifeItemCellData(
            id: 'machine-in-${e.key}',
            icon: LifeIcon(pk.$1.sprite, LifeIconKind.cosecha, size: icon),
            border: qualityColor(pk.$2),
            search: name,
            count: e.value,
            detail: LifeItemDetail(
              itemId: pk.$1.sprite,
              name: name,
              nameColor: qualityColor(pk.$2),
              lines: [
                context.t('ui.town.ranch.machine.makes', {
                  'item': animalGoodsName(out),
                  'from': AnimalRules.unitPrice(e.key),
                  'to': AnimalRules.unitPrice(out),
                }),
              ],
              actions: [
                DsButton(context.t('ui.town.ranch.machine.process'),
                    key: ValueKey('machine-go-${e.key}'),
                    size: DsButtonSize.compact,
                    kind: DsButtonKind.primary,
                    tooltip: one,
                    onPressed:
                        one == null ? () => c.processGoods(e.key, 1) : null),
                DsButton(context.t('ui.town.ranch.machine.process_all'),
                    key: ValueKey('machine-all-${e.key}'),
                    size: DsButtonSize.compact,
                    tooltip: one,
                    onPressed: one == null
                        ? () => c.processGoods(e.key, e.value)
                        : null),
              ],
            ),
          );
        }(),
    ];
    return LifeItemGrid(
      key: const ValueKey('machine-grid'),
      groups: [LifeItemGroup(null, [...machines, ...goods])],
      empty: context.t('ui.town.ranch.machine.empty'),
    );
  }

  LifeItemCellData _machine(
      BuildContext context, PlayerProfile p, RanchTool t) {
    final has = p.life.farm.hasTool(t);
    final reason = AnimalRules.cannotBuyTool(p, t);
    final name = context.t('data.materials.ranch_tool.${t.id}.name');
    return LifeItemCellData(
      id: 'machine-${t.id}',
      icon: LifeIcon(t.sprite, LifeIconKind.herramienta,
          size: LifeItemGrid.iconSize),
      border: has ? DsColors.success : DsColors.border,
      search: name,
      equipped: has,
      detail: LifeItemDetail(
        itemId: t.sprite,
        name: name,
        nameColor: DsColors.textPrimary,
        tags: [
          (context.t('ui.town.ranch.machine.tag'), DsColors.textSecondary)
        ],
        lines: [
          context.t('ui.town.ranch.machine.${t.id}'),
          has
              ? context.t('ui.town.ranch.owned_line')
              : context.t('ui.town.trader.price_short', {'n': t.price}),
        ],
        actions: [
          if (!has)
            DsButton(context.t('ui.town.ranch.buy'),
                key: ValueKey('machine-buy-${t.id}'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                tooltip: reason,
                onPressed:
                    reason == null ? () => controller.buyRanchTool(t.id) : null),
        ],
      ),
    );
  }
}
