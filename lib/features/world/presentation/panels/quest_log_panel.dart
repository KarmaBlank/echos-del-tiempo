import 'package:material_ui/material_ui.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../domain/quest_text.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/rules/quest_track_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../hud/tracked_quests_hud.dart' show questProgressText;
import '../session_controller.dart';
import '../session_view.dart';
import 'biome_npc_panel.dart'
    show orderCell, questCells, residentItemIcon, trackButton;
import 'life_icon.dart';
import 'life_item_grid.dart';
import 'profession_journal.dart';
import 'world_event_cells.dart';
import '../world_strings.dart';

/// DIARIO (roles.md § 8.1, antes "registro de encargos"): la subpestaña
/// SEGUIDOS con los encargos que seguís y una por habitante con su orden
/// del día y los pasos de su cadena que ya pidió; el detalle a la
/// derecha. Solo hay pestaña para los
/// habitantes que ya conoció. Se abre con J (pueblo o campo), desde el HUD o la fuente.
class QuestLogPanel extends StatefulWidget {
  const QuestLogPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<QuestLogPanel> createState() => _QuestLogPanelState();
}

class _QuestLogPanelState extends State<QuestLogPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final town = c.town;
    final p = widget.view.me?.profile;
    // Solo los habitantes con los que ya habló (los demás no aparecen).
    final npcs = [
      if (p != null)
        for (final n in kBiomeNpcs)
          if (QuestTrackRules.met(p, n.id)) n
    ];
    // Last tab: the profession journals (cozy_life.md § 4).
    final profTab = npcs.length + 2;
    final tab = _tab.clamp(0, profTab);
    final prof = tab == profTab;
    final events = tab == 1;
    final tracked = p == null
        ? const <ActiveQuest>[]
        : [
            for (final a in QuestTrackRules.active(p, town))
              if (a.tracked) a
          ];
    final n = tab <= 1 || prof ? null : npcs[tab - 2];
    final r = n == null ? null : town.resident(n.id);
    return PanelFrame(
      key: const ValueKey('panel-quest-log'),
      title: context.t('ui.town.journal.title'),
      width: 760,
      onClose: c.closePanel,
      actions: [
        PanelButton(context.t('ui.town.journal.close'),
            key: const ValueKey('quest-log-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsTabBar(
            tabs: [
              DsTab(context.t('ui.town.journal.tracked'),
                  badge: tracked.isEmpty ? null : '${tracked.length}',
                  key: const ValueKey('quest-log-tab-seguidos')),
              DsTab(context.t('ui.town.journal.events'),
                  badge: town.events.active.isEmpty
                      ? null
                      : '${town.events.active.length}',
                  key: const ValueKey('quest-log-tab-eventos')),
              for (var i = 0; i < npcs.length; i++)
                () {
                  final mark = p == null
                      ? NpcMark.none
                      : QuestTrackRules.mark(p, town, npcs[i]);
                  return DsTab(npcs[i].name.toUpperCase(),
                      badge: switch (mark) {
                        NpcMark.news => '!',
                        NpcMark.ready => '?',
                        NpcMark.none => null,
                      },
                      key: ValueKey('quest-log-tab-${npcs[i].id}'));
                }(),
              DsTab(context.t('ui.town.journal.professions'),
                  key: const ValueKey('quest-log-tab-oficios')),
            ],
            index: tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          SizedBox(height: DsSpace.xs),
          if (n != null && r != null)
            Text(
                [
                  context.t('ui.town.journal.status_rep',
                      {'role': n.role.label, 'rep': r.rep}),
                  r.invited
                      ? ResidentRules.stage(r).label
                      : context.t('ui.town.journal.status_lives',
                          {'place': biomeDef(n.biome)?.name ?? n.biome}),
                  if (r.request != null)
                    context.t('ui.town.journal.status_asks',
                        {'what': requestText(r.request!).toLowerCase()}),
                ].join(' · '),
                key: const ValueKey('quest-log-status'),
                softWrap: true,
                style: DsText.detail(DsColors.textSecondary)),
          SizedBox(height: DsSpace.xs),
          if (prof && p != null)
            ProfessionJournalView(
                key: const ValueKey('quest-log-professions'),
                profile: p,
                onCompost: c.compost)
          else
            LifeItemGrid(
              key: ValueKey(
                  'quest-log-grid-${n?.id ?? (events ? 'eventos' : 'seguidos')}'),
              groups: [
                LifeItemGroup(null, [
                  if (events)
                    for (final a in town.events.active)
                      worldEventCell(context, a, town),
                  if (n == null && !events)
                    for (final a in tracked) _trackedCell(a, p),
                  if (n != null && r != null) ...[
                    if (orderCell(worldStrings(context), c, n, r, p,
                            home: c.place == kPueblo)
                        case final o?)
                      o,
                    ...questCells(worldStrings(context), c, n, r, p),
                  ],
                ]),
              ],
              empty: events
                  ? context.t('ui.town.journal.no_events')
                  : n == null
                      ? context.t('ui.town.journal.none_tracked')
                      : context.t('ui.town.journal.no_quests'),
            ),
        ],
      ),
    );
  }

  LifeItemCellData _trackedCell(ActiveQuest a, PlayerProfile? p) =>
      LifeItemCellData(
        id: 'tracked-${a.key}',
        icon: a.item != null
            ? residentItemIcon(a.item!)
            : const LifeIcon('cofre_oficio', LifeIconKind.herramienta,
                size: 32),
        border: a.ready ? DsColors.success : DsColors.selected,
        search: activeQuestWho(a),
        count: a.item == null ? null : a.need,
        detail: LifeItemDetail(
          name: activeQuestWho(a),
          nameColor: DsColors.textTitle,
          tags: [
            (trackKindText(a.kind).toUpperCase(), DsColors.textSecondary),
            if (a.ready) (context.t('ui.town.journal.ready'), DsColors.success),
          ],
          // One line: what and how far (quest_audit.md § 8).
          lines: [questProgressText(worldStrings(context), a)],
          actions: [trackButton(widget.controller, p, a.npc.id, a.kind)],
        ),
      );
}
