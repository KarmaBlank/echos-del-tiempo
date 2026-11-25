import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/world_events_catalog.dart';
import '../../../../game_engine/data/zones_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
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
    BuildContext context, ActiveWorldEvent a, TownState town) {
  final day = town.sky.day;
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
        ..add(context.t('ui.town.events.progress', {
          'have': WorldEventRules.progressOf(town.events, a),
          'need': q.n
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
  // Marca "!" compacta (§ 6); los títulos en el tooltip.
  return DsMark(key: ValueKey('travel-event-$place'))
      .tip(titles.join(' · '));
}

/// RUMOR badge on the travel map: a place an event NPC told [player]
/// about (world_events.md § 3.6), or `null`.
Widget? rumorBadge(
    BuildContext context, WorldEventsState s, String place, String player) {
  if (!WorldEventRules.rumorMarks(s, player).contains(place)) return null;
  return DsBadge(context.t('ui.town.events.rumor_badge'),
          key: ValueKey('travel-rumor-$place'))
      .tip(context.t('ui.town.events.rumor_tip'));
}

/// The trader banner while a visitor or caravan sells cheaper (§ 3.1),
/// or `null`.
String? eventSaleText(BuildContext context, WorldEventsState s) {
  final disc = WorldEventRules.townDiscount(s, kWorldEvents);
  if (disc <= 0) return null;
  final who = [
    for (final a in s.at(kPueblo))
      if (kWorldEvents.def(a.def) case final d? when d.param('discount') > 0)
        d.title.text
  ].join(' · ');
  return context.t(
      'ui.town.events.trade_banner', {'name': who, 'n': (disc * 100).round()});
}
