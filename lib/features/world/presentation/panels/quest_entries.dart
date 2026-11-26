import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/quest_track_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../../domain/quest_text.dart';
import '../hud/tracked_quests_hud.dart' show questProgressText;
import '../session_controller.dart';
import '../world_strings.dart';
import 'biome_npc_panel.dart'
    show orderCell, questCells, requestCell, residentItemIcon, residentItemName;
import 'life_item_grid.dart';

/// Quest screens (design_system.md § "Encargos"): the resident's quests,
/// orders and requests as [DsQuestEntry] rows of the shared
/// [DsQuestTemplate]. The detail data (rewards, flavor, buttons with
/// their keys) comes from the same builders the item cells used; this
/// file adds the giver, the checklist and the required-items grid.

/// The required item [id] as a cell of the objectives grid.
DsCostEntry questItem(Strings s, String id, int have, int need) => DsCostEntry(
      id: id,
      icon: residentItemIcon(id),
      need: need,
      have: have,
      card: DsTooltipCard(title: residentItemName(id), children: [
        Text(s.t('ui.town.npc.have_of', {'have': have, 'need': need}),
            style: DsText.body()),
      ]),
    );

/// "Trucha de río — tenés 2 / pide 5" as a checklist line.
DsQuestObjective itemObjective(Strings s, String id, int have, int need) =>
    DsQuestObjective(
        s.t('ui.town.quest.obj_items',
            {'item': residentItemName(id), 'have': have, 'need': need}),
        done: have >= need,
        key: ValueKey('quest-obj-$id'));

/// Builds the entry from a cell's detail (rewards, flavor, actions).
DsQuestEntry _fromCell(
  LifeItemCellData c, {
  required String? giver,
  required String status,
  required Color statusColor,
  required List<DsQuestObjective> objectives,
  List<DsCostEntry> items = const [],
  List<String> notes = const [],
  bool done = false,
}) {
  final d = c.detail;
  return DsQuestEntry(
    id: c.id,
    title: d.name,
    status: status,
    statusColor: statusColor,
    giver: giver,
    flavor: d.info ?? d.description,
    objectives: objectives,
    items: items,
    rewards: d.chips,
    notes: notes,
    actions: d.actions,
    done: done,
  );
}

String _giver(Strings s, BiomeNpcDef n) =>
    s.t('ui.town.quest.giver', {'name': n.name});

/// The delivery order of [r] as a quest, or `null`.
DsQuestEntry? orderEntry(Strings s, SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p,
    {required bool home}) {
  final cell = orderCell(s, c, n, r, p, home: home);
  final o = r.order;
  if (cell == null || o == null) return null;
  if (ResidentRules.isForgeOrder(o)) {
    final have =
        p == null ? 0 : ResidentRules.forgeOrderMatches(p, o, r.orderQ).length;
    return _fromCell(cell,
        giver: _giver(s, n),
        status: '${have.clamp(0, 1)}/1',
        statusColor: have > 0 ? DsColors.success : DsColors.textDisabled,
        objectives: [
          DsQuestObjective(cell.detail.lines.first,
              done: have > 0, key: ValueKey('quest-obj-$o')),
        ],
        notes: cell.detail.lines.skip(1).toList());
  }
  final have = p == null ? 0 : ResidentRules.orderHave(p, o, r.orderQ);
  final need = r.orderN;
  return _fromCell(cell,
      giver: _giver(s, n),
      status: '$have/$need',
      statusColor: have >= need ? DsColors.success : DsColors.textDisabled,
      objectives: [itemObjective(s, o, have, need)],
      items: [questItem(s, o, have, need)],
      // The quality / size condition ("5 × trucha desde 30 cm").
      notes: [if (r.orderQ > 0) cell.detail.lines.first]);
}

/// The resident's quest chain steps already asked for, as quests.
List<DsQuestEntry> questEntries(Strings s, SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p) {
  final chain = kResidentQuests[n.id] ?? const <QuestStepDef>[];
  final cells = questCells(s, c, n, r, p);
  return [
    for (var i = 0; i < cells.length; i++)
      () {
        final q = chain[i];
        final done = i < r.quest;
        final have = p == null ? 0 : ResidentRules.questHave(p, q);
        final left = q.n - r.progress;
        if (q.kind.delivered) {
          final h = done ? q.n : have;
          final need = done ? q.n : left;
          return _fromCell(cells[i],
              giver: _giver(s, n),
              status: done ? s.t('ui.town.npc.done') : '$h/$need',
              statusColor:
                  done || h >= need ? DsColors.success : DsColors.textDisabled,
              done: done,
              objectives: [itemObjective(s, q.target, h, need)],
              items: [questItem(s, q.target, h, need)]);
        }
        final n0 = done ? q.n : r.progress;
        return _fromCell(cells[i],
            giver: _giver(s, n),
            status: done ? s.t('ui.town.npc.done') : '$n0/${q.n}',
            statusColor: done ? DsColors.success : DsColors.textDisabled,
            done: done,
            objectives: [
              DsQuestObjective(
                  s.t('ui.town.quest.obj_progress', {
                    'what': cells[i].detail.lines.first,
                    'n': n0,
                    'goal': q.n
                  }),
                  done: n0 >= q.n,
                  key: ValueKey('quest-obj-${n.id}-$i')),
            ]);
      }(),
  ];
}

/// The resident's request (a house, a service…) as a quest, or `null`.
DsQuestEntry? requestEntry(Strings s, SessionController c, BiomeNpcDef n,
    ResidentState r, PlayerProfile? p, TownState town,
    {required bool home}) {
  final req = r.request;
  if (req == null) return null;
  final cell = requestCell(s, c, n, r, p, town, home: home);
  final why = ResidentRules.requestUnmet(town, n.id);
  return _fromCell(cell,
      giver: _giver(s, n),
      status: r.unhappy
          ? s.t('ui.town.npc.unhappy_tag')
          : why == null
              ? s.t('ui.town.journal.ready')
              : s.t('ui.town.npc.request'),
      statusColor: r.unhappy
          ? DsColors.danger
          : why == null
              ? DsColors.success
              : DsColors.textDisabled,
      objectives: [
        DsQuestObjective(why ?? requestText(req),
            done: why == null, key: ValueKey('quest-obj-request-${n.id}')),
      ],
      notes: cell.detail.lines.take(2).toList());
}

/// Everything [n] has asked of you: order, request, quest chain.
List<DsQuestEntry> residentEntries(Strings s, SessionController c,
        BiomeNpcDef n, ResidentState r, PlayerProfile? p, TownState town,
        {required bool home, bool quests = true, bool requests = true}) =>
    [
      if (requests) ...[
        if (orderEntry(s, c, n, r, p, home: home) case final o?) o,
        if (requestEntry(s, c, n, r, p, town, home: home) case final q?) q,
      ],
      if (quests) ...questEntries(s, c, n, r, p),
    ];

/// A tracked quest of the DIARIO (any resident), as a quest.
DsQuestEntry trackedEntry(Strings s, ActiveQuest a, List<Widget> actions) {
  final item = a.item;
  final have = a.have;
  return DsQuestEntry(
    id: 'tracked-${a.key}',
    title: activeQuestWho(a),
    status: a.ready ? s.t('ui.town.journal.ready') : trackKindText(a.kind),
    statusColor: a.ready ? DsColors.success : DsColors.textDisabled,
    giver: s.t('ui.town.quest.giver', {'name': a.npc.name}),
    objectives: [
      if (item != null)
        itemObjective(s, item, have, a.need)
      else
        DsQuestObjective(questProgressText(s, a),
            done: a.ready, key: ValueKey('quest-obj-${a.key}')),
    ],
    items: [if (item != null) questItem(s, item, have, a.need)],
    actions: actions,
    done: a.ready,
  );
}

/// A generic cell (world events) shown in the quest template: its data
/// lines become meta notes.
DsQuestEntry cellEntry(LifeItemCellData c, {String? status, Color? color}) =>
    DsQuestEntry(
      id: c.id,
      title: c.detail.name,
      status: status ?? c.caption,
      statusColor: color ?? DsColors.textDisabled,
      flavor: c.detail.description ?? c.detail.info,
      notes: c.detail.lines,
      rewards: c.detail.chips,
      actions: c.detail.actions,
    );
