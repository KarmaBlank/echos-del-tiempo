import 'package:material_ui/material_ui.dart';
import '../../../../game_engine/models/player_profile.dart';

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

/// DIARIO (roles.md § 8.1, antes "registro de encargos"): la subpestaña
/// SEGUIDOS con los encargos que seguís y una por habitante con su orden
/// del día y los pasos de su cadena que ya pidió; el detalle a la
/// derecha. Se abre con J en el pueblo, desde el HUD o la fuente.
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
    final npcs = kBiomeNpcs;
    final tab = _tab.clamp(0, npcs.length);
    final tracked = p == null
        ? const <ActiveQuest>[]
        : [
            for (final a in QuestTrackRules.active(p, town))
              if (a.tracked) a
          ];
    final n = tab == 0 ? null : npcs[tab - 1];
    final r = n == null ? null : town.resident(n.id);
    return PanelFrame(
      key: const ValueKey('panel-quest-log'),
      title: 'DIARIO',
      width: 760,
      onClose: c.closePanel,
      actions: [
        PanelButton('CERRAR',
            key: const ValueKey('quest-log-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsTabBar(
            tabs: [
              DsTab('SEGUIDOS',
                  badge: tracked.isEmpty ? null : '${tracked.length}',
                  key: const ValueKey('quest-log-tab-seguidos')),
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
            ],
            index: tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          SizedBox(height: DsSpace.xs),
          if (n != null && r != null)
            Text(
                '${n.role.label} · relación ${r.rep} · '
                '${ResidentRules.stage(r).label}'
                '${r.invited ? '' : ' · vive en ${biomeDef(n.biome)?.name ?? n.biome}'}'
                '${r.request != null ? ' · pide: ${r.request!.label.toLowerCase()}' : ''}',
                key: const ValueKey('quest-log-status'),
                softWrap: true,
                style: DsText.detail(DsColors.textSecondary)),
          SizedBox(height: DsSpace.xs),
          LifeItemGrid(
            key: ValueKey('quest-log-grid-${n?.id ?? 'seguidos'}'),
            groups: [
              LifeItemGroup(null, [
                if (n == null)
                  for (final a in tracked) _trackedCell(a, p),
                if (n != null && r != null) ...[
                  if (orderCell(c, n, r, p, home: c.place == kPueblo)
                      case final o?)
                    o,
                  ...questCells(c, n, r, p),
                ],
              ]),
            ],
            empty: n == null
                ? 'No seguís ningún encargo. Marcá SEGUIR en uno activo.'
                : 'Sin encargos.',
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
        search: a.who,
        caption:
            a.item == null ? a.kind.label.toUpperCase() : '${a.have}/${a.need}',
        detail: LifeItemDetail(
          name: a.who,
          nameColor: DsColors.textTitle,
          tags: [
            (a.kind.label.toUpperCase(), DsColors.textSecondary),
            if (a.ready) ('LISTO', DsColors.success),
          ],
          lines: [a.title, questProgressText(a)],
          actions: [trackButton(widget.controller, p, a.npc.id, a.kind)],
        ),
      );
}
