import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/world_events_catalog.dart';
import '../../../../game_engine/data/zones_catalog.dart';
import '../../../../game_engine/rules/world_event_rules.dart';
import '../world_strings.dart';
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Border color per category (DsColors only).
Color worldEventColor(WorldEventCategory c) => switch (c) {
      WorldEventCategory.echoPortal => DsColors.danger,
      WorldEventCategory.lore => DsColors.reward,
      WorldEventCategory.overworldNpc => DsColors.mp,
      WorldEventCategory.visitor || WorldEventCategory.caravan =>
        DsColors.success,
    };

String _x(double v) => v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// One cell of DIARIO → EVENTOS (world_events.md § 6): grid cell with
/// the detail on the right.
LifeItemCellData worldEventCell(
    BuildContext context, ActiveWorldEvent a, int day) {
  final d = kWorldEvents.def(a.def);
  final cat = d?.category ?? WorldEventCategory.visitor;
  final title = d?.title.text ?? a.def;
  final lines = <String>[
    context.t('ui.town.events.where',
        {'place': biomeDef(a.biome)?.name ?? a.biome}),
    context.t('ui.town.events.days_left', {'n': a.daysLeft(day)}),
  ];
  if (d != null && cat == WorldEventCategory.echoPortal) {
    final r = WorldEventRules.rift(d, a.biome);
    if (r != null) {
      final boss =
          kZones.where((z) => z.index == r.zone).firstOrNull?.bossName ??
              r.bossId;
      lines
        ..add(context.t('ui.town.events.rift', {
          'boss': boss,
          'hp': _x(r.hpMult),
          'atk': _x(r.atkMult),
          'lv': r.levelBonus
        }))
        ..add(context.t('ui.town.events.rift_reward', {'n': _x(r.rewardMult)}));
    }
  }
  if (d != null) {
    if (WorldEventRules.loreQuest(d) case final q?) {
      lines
        ..add(context.t('ui.town.events.quest', {
          'npc': biomeNpcName(q.npc),
          'objective': context.t('ui.town.events.obj.${q.objective.name}',
              {'target': q.target, 'n': q.n}),
        }))
        ..add(context.t('ui.town.events.quest_reward',
            {'gold': q.gold, 'rep': q.rep}));
    }
    final disc = d.param('discount');
    if (disc > 0) {
      lines.add(context.t('ui.town.events.discount', {'n': (disc * 100).round()}));
    }
  }
  final catLabel = context.t('ui.town.events.cat.${cat.name}');
  return LifeItemCellData(
    id: 'event-${a.uid}',
    icon: const LifeIcon('cofre_oficio', LifeIconKind.herramienta, size: 32),
    border: worldEventColor(cat),
    search: title,
    caption: '${a.daysLeft(day)}d',
    detail: LifeItemDetail(
      name: title,
      nameColor: DsColors.textTitle,
      tags: [(catLabel, worldEventColor(cat))],
      lines: lines,
      description: d?.body.text,
    ),
  );
}

/// Travel map badge (§ 6) for the events at [place], or `null`.
Widget? worldEventBadge(BuildContext context, WorldEventsState s, String place) {
  final here = s.at(place);
  if (here.isEmpty) return null;
  final titles = [
    for (final a in here) kWorldEvents.def(a.def)?.title.text ?? a.def
  ];
  return DsBadge(
    here.length == 1
        ? context.t('ui.town.events.badge')
        : context.t('ui.town.events.badge_n', {'n': here.length}),
    key: ValueKey('travel-event-$place'),
  ).tip(titles.join(' · '));
}
