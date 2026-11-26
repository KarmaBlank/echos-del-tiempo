import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/cozy_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/cozy_rules.dart';
import '../map/map_themes.dart' show CozyPalette;
import '../world_strings.dart';
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Raft decorations (cozy_life.md § 1) as grid cells: buy one, or put
/// on / take off one already bought. Cosmetic and cheap.
List<LifeItemCellData> raftDecoCells(
    BuildContext context, PlayerProfile p, bool Function(String id) onTap) {
  final life = p.life;
  return [
    for (final d in kRaftDecos.values)
      () {
        final owned = life.raftDecos.contains(d.id);
        final on = life.raftOn.contains(d.id);
        final cost = CozyRules.raftCost(d.id);
        final short = !owned && p.credits < cost;
        final name = context.t('ui.town.raft.${d.id}.name');
        return LifeItemCellData(
          id: 'raft-deco-${d.id}',
          icon: raftDecoIcon(d),
          border: on ? DsColors.success : DsColors.selected,
          search: name,
          equipped: on,
          caption:
              owned ? null : context.t('ui.town.npc.gold_short', {'n': cost}),
          detail: LifeItemDetail(
            name: name,
            nameColor: DsColors.textTitle,
            tags: [
              (context.t('ui.town.raft.tag'), DsColors.textSecondary),
              if (on) (context.t('ui.town.raft.on'), DsColors.success),
            ],
            lines: [
              context.t('ui.town.raft.${d.id}.info'),
              owned
                  ? context.t('ui.town.raft.owned')
                  : context.t('ui.town.raft.price', {'n': cost}),
            ],
            actions: [
              DsButton(
                  owned
                      ? context.t(
                          on ? 'ui.town.raft.take_off' : 'ui.town.raft.put_on')
                      : context.t('ui.town.trader.buy_price', {'n': cost}),
                  key: ValueKey('raft-deco-act-${d.id}'),
                  size: DsButtonSize.compact,
                  tooltip: short
                      ? context.t('ui.town.raft.no_gold',
                          {'have': p.credits, 'need': cost})
                      : null,
                  onPressed: short ? null : () => onTap(d.id)),
            ],
          ),
        );
      }(),
  ];
}

/// The icon of a raft decoration: its sprite, or the raft tinted with the
/// paint.
Widget raftDecoIcon(RaftDecoDef d, {double size = 32}) {
  if (d.paint case final i?) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
          CozyPalette.paints[i % CozyPalette.paints.length],
          BlendMode.modulate),
      child: LifeIcon('balsa', LifeIconKind.herramienta, size: size),
    );
  }
  if (d.slot == RaftDecoSlot.roof) {
    // The awning: tinted cloth over its two posts (as on the map).
    return SizedBox.square(
      dimension: size,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: size,
          height: size * 6 / 32,
          child: ColorFiltered(
            colorFilter:
                const ColorFilter.mode(CozyPalette.cloth, BlendMode.modulate),
            child: LifeIcon('raft_roof', LifeIconKind.herramienta, size: size),
          ),
        ),
        SizedBox(
          width: size,
          height: size * 18 / 32,
          child: LifeIcon('raft_posts', LifeIconKind.herramienta, size: size),
        ),
      ]),
    );
  }
  return LifeIcon('raft_${d.id}', LifeIconKind.herramienta, size: size);
}
