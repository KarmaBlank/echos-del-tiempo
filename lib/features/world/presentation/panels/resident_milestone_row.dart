import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/resident_milestone_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../world_strings.dart';

/// Icon of a milestone reward (roles.md § 9.5).
IconData milestoneIcon(MilestoneReward r, {bool endgame = false}) =>
    switch (r) {
      MilestoneReward.chestWood ||
      MilestoneReward.chestSilver =>
        Icons.inventory_2,
      MilestoneReward.ecoOrGold =>
        endgame ? Icons.blur_circular : Icons.inventory_2,
      MilestoneReward.material => Icons.grass,
      MilestoneReward.meal => Icons.restaurant,
      MilestoneReward.weapon => Icons.gavel,
      MilestoneReward.unique => Icons.auto_awesome,
      MilestoneReward.perk => Icons.trending_up,
    };

/// The visible milestone track of a resident: one cell per milestone
/// (relationship → reward icon), claimed / claimable / next / locked,
/// with a fixed-size tooltip and claim on tap (roles.md § 9.5).
class ResidentMilestoneRow extends StatelessWidget {
  const ResidentMilestoneRow(
      {super.key, required this.resident, this.profile, this.onClaim});

  final ResidentState resident;
  final PlayerProfile? profile;

  /// Claim milestone index; `null` = read-only.
  final void Function(int index)? onClaim;

  static const cellSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final s = worldStrings(context);
    final endgame = profile?.ecosUnlocked ?? false;
    return Wrap(
      key: const ValueKey('npc-milestones'),
      spacing: DsSpace.xs,
      runSpacing: DsSpace.xs,
      children: [
        for (final m in ResidentMilestoneRules.track)
          _cell(s, m, ResidentMilestoneRules.state(profile, resident, m),
              endgame),
      ],
    );
  }

  Widget _cell(
      Strings s, MilestoneDef m, MilestoneState st, bool endgame) {
    final color = switch (st) {
      MilestoneState.claimable => DsColors.reward,
      MilestoneState.claimed || MilestoneState.reached => DsColors.statusOk,
      MilestoneState.next => DsColors.mp,
      MilestoneState.locked => DsColors.textDisabled,
    };
    final canClaim = st == MilestoneState.claimable && onClaim != null;
    final name = s.t('ui.town.npc.ms.${_rewardKey(m.reward, endgame)}',
        {'n': m.amount});
    final extra = profile == null
        ? (material: null, n: 0)
        : ResidentMilestoneRules.endgameExtra(profile!, m);
    final cell = Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        color: canClaim ? DsColors.surfaceRaised : DsColors.surfaceSunken,
        border: Border.all(color: color, width: 2),
      ),
      child: Stack(children: [
        Center(
            child: Icon(milestoneIcon(m.reward, endgame: endgame),
                size: 20, color: color)),
        Positioned(
            left: 2,
            bottom: 0,
            child: Text(m.rep.toString(), style: DsText.detail(color))),
        if (st == MilestoneState.claimed)
          const Positioned(
              right: 1,
              top: 0,
              child: Icon(Icons.check, size: 12, color: DsColors.statusOk)),
      ]),
    );
    final tip = DsTooltipCard(
      title: name,
      titleColor: color,
      children: [
        Text(s.t('ui.town.npc.ms.need', {'n': m.rep})),
        if (extra.material != null)
          Text(s.t('ui.town.npc.ms.endgame_extra',
              {'n': extra.n, 'what': extra.material!.label})),
        Text(s.t('ui.town.npc.ms.state_${st.name}'),
            style: DsText.detail(color)),
      ],
    );
    return DsTooltip(
      card: tip,
      child: GestureDetector(
        key: ValueKey('npc-ms-${m.index}'),
        behavior: HitTestBehavior.opaque,
        onTap: canClaim ? () => onClaim!(m.index) : null,
        child: MouseRegion(
            cursor:
                canClaim ? SystemMouseCursors.click : MouseCursor.defer,
            child: cell),
      ),
    );
  }

  static String _rewardKey(MilestoneReward r, bool endgame) => switch (r) {
        MilestoneReward.ecoOrGold => endgame ? 'eco' : 'chest_gold',
        MilestoneReward.chestWood => 'chest_wood',
        MilestoneReward.chestSilver => 'chest_silver',
        _ => r.name,
      };
}
