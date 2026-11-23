import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'biome_npc_panel.dart' show orderCell, questCells;
import 'life_item_grid.dart';

/// Registro de encargos (overworld_biomes.md § 10.2): una subpestaña por
/// habitante y, en cada una, la grilla con su orden del día y los pasos
/// de su cadena; el detalle a la derecha.
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
    final tab = _tab.clamp(0, npcs.length - 1);
    final n = npcs[tab];
    final r = town.resident(n.id);
    return PanelFrame(
      key: const ValueKey('panel-quest-log'),
      title: 'REGISTRO DE ENCARGOS',
      width: 680,
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
              for (var i = 0; i < npcs.length; i++)
                () {
                  final s = town.resident(npcs[i].id);
                  final mark = s.request != null || s.order != null;
                  return DsTab(npcs[i].name.toUpperCase(),
                      badge: mark ? '!' : null,
                      key: ValueKey('quest-log-tab-${npcs[i].id}'));
                }(),
            ],
            index: tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          SizedBox(height: DsSpace.xs),
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
            key: ValueKey('quest-log-grid-${n.id}'),
            groups: [
              LifeItemGroup(null, [
                if (orderCell(c, n, r, p, home: c.place == kPueblo)
                    case final o?)
                  o,
                ...questCells(c, n, r, p),
              ]),
            ],
            empty: 'Sin encargos.',
          ),
        ],
      ),
    );
  }
}
