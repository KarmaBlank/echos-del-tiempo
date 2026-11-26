import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../app/widgets/cost_chip.dart';
import '../../../../app/widgets/pixel_icon.dart';
import '../../../../game_engine/data/mine_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/mine_work_rules.dart';
import '../../../../game_engine/rules/mining_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Miners of a mine level (docs/specs/mining_smithing.md § 1.7): grid of
/// the hired miners, detail on the right with the pick tier, what it
/// breaks here, its yield against a player and the next tier's cost
/// with MEJORAR. Opened with E on the built station or G next to a
/// miner; the upgrade is the host-validated `MineOp.upgrade`.
class MinerPanel extends StatelessWidget {
  const MinerPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  SessionController get c => controller;

  @override
  Widget build(BuildContext context) {
    final lvl = c.mineLevel;
    final st = c.mineState;
    if (lvl == null || !st.station) {
      return PanelFrame(
          key: const ValueKey('panel-miners'),
          title: context.t('ui.world.miners.title'),
          width: 480,
          onClose: c.closePanel,
          child:
              Text(context.t('ui.world.miners.gone'), style: DsText.detail()));
    }
    final p = view.me?.profile;
    final pct = (MiningRules.t.d('minerYield') * 100).round();
    final rockTier = MiningRules.reqTier(lvl.level).clamp(0, kMineTools.last.tier);
    final deepTier = MiningRules.reqTierOf(MineTile.deep, lvl.level);
    final cells = [
      for (var i = 0; i < st.miners.length; i++)
        _cell(context, i, st.miners[i], p, pct, rockTier, deepTier),
    ];
    return PanelFrame(
      key: const ValueKey('panel-miners'),
      title: context.t('ui.world.miners.title'),
      width: 820,
      onClose: c.closePanel,
      actions: [
        PanelButton(context.t('ui.town.helper.close'),
            key: const ValueKey('miners-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              context.t('ui.world.miners.count', {
                'n': st.miners.length,
                'max': MiningRules.t.i('minerMax'),
              }),
              key: const ValueKey('miners-count'),
              style: DsText.body()),
          DsGoldText(
              context.t('ui.world.miners.have',
                  {'gold': p?.credits ?? 0}),
              style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          SizedBox(
            height: 320,
            child: LifeItemGrid(
              key: const ValueKey('miners-grid'),
              initial: cells.isEmpty
                  ? null
                  : cells[c.minerPanelFocus.clamp(0, cells.length - 1)].id,
              groups: [
                LifeItemGroup(context.t('ui.world.miners.title'), cells),
              ],
              empty: context.t('ui.world.miners.none'),
            ),
          ),
        ],
      ),
    );
  }

  LifeItemCellData _cell(BuildContext context, int i, MinerState m,
      PlayerProfile? p, int pct, int rockTier, int deepTier) {
    final tool = kMineTools[m.tier.clamp(0, kMineTools.length - 1)];
    final toolName = context.t('data.materials.smith.${tool.id}.name');
    final cost = MineWorkRules.upgradeCost(m.tier + 1);
    final max = cost == null;
    final goldOk = cost != null && (p?.credits ?? 0) >= cost.gold;
    final ingotOk = cost != null && (p?.life.ore(cost.ingot) ?? 0) >= cost.n;
    final can = p != null && goldOk && ingotOk;
    String breaks(int need) => context.t(
        m.tier >= need ? 'ui.world.miners.breaks_yes' : 'ui.world.miners.breaks_no',
        {'tier': need});
    final name = context.t('ui.world.miners.name', {'n': i + 1});
    return LifeItemCellData(
      id: 'miner-$i',
      icon: LifeIcon(tool.id, LifeIconKind.herramienta,
          size: LifeItemGrid.iconSize),
      border: max ? DsColors.textTitle : DsColors.border,
      search: name,
      caption: context.t('ui.world.miners.tier_short', {'tier': m.tier}),
      detail: LifeItemDetail(
        name: name,
        nameColor: DsColors.textTitle,
        tags: [
          (toolName,
              DsColors.textSecondary),
        ],
        lines: [
          '${context.t('ui.world.miners.rock')}: ${breaks(rockTier)}',
          '${context.t('ui.world.miners.deep')}: ${breaks(deepTier)}',
          context.t('ui.world.miners.yield', {'pct': pct}),
          if (max)
            context.t('ui.world.miners.max_text')
          else
            context.t('ui.world.miners.next', {
              'tier': m.tier + 1,
              'name': context.t(
                  'data.materials.smith.${kMineTools[m.tier + 1].id}.name'),
            }),
        ],
        actions: [
          if (cost != null)
            CostChip(key: ValueKey('miner-cost-$i'), [
              CostPart(PixelIconKind.coin, '${cost.gold}', ok: goldOk),
              CostPart(PixelIconKind.anvil,
                  '${cost.n} ${context.t('data.materials.smith.${cost.ingot}.name')}',
                  iconColor: DsColors.textSecondary, ok: ingotOk),
            ]),
          DsButton(
              max
                  ? context.t('ui.town.helper.max')
                  : context.t('ui.town.helper.upgrade'),
              key: ValueKey('miner-up-$i'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.primary,
              onPressed: !max && can ? () => c.upgradeMinerAt(i) : null),
        ],
      ),
    );
  }
}
