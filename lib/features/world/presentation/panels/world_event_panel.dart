import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/world_events_catalog.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';
import 'world_event_cells.dart';

/// A world event actor (world_events.md § 6): what the visitor, wanderer
/// or caravan says (the BORRADOR texts of the catalog), with COMERCIAR
/// for visitors and caravans and ENTRAR for an open echo rift.
class WorldEventPanel extends StatelessWidget {
  const WorldEventPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final a = c.worldEvent;
    final d = a == null ? null : kWorldEvents.def(a.def);
    final cell = a == null ? null : worldEventCell(context, a, c.town);
    final rift = d?.category == WorldEventCategory.echoPortal;
    final shop = d?.category == WorldEventCategory.visitor ||
        d?.category == WorldEventCategory.caravan;
    return PanelFrame(
      key: const ValueKey('panel-world-event'),
      title: d?.title.text.toUpperCase() ?? context.t('ui.town.journal.events'),
      width: 520,
      onClose: c.closePanel,
      actions: [
        if (a != null && shop)
          PanelButton(context.t('ui.town.events.trade'),
              key: const ValueKey('world-event-trade'),
              onPressed: () => c.openPanel(WorldPanel.trader)),
        if (a != null && rift)
          PanelButton(context.t('ui.town.events.enter'),
              key: const ValueKey('world-event-enter'),
              onPressed: () => c.enterRift(a.uid)),
        PanelButton(context.t('ui.town.events.close'),
            key: const ValueKey('world-event-close'), onPressed: c.closePanel),
      ],
      child: a == null || d == null || cell == null
          ? Text(context.t('ui.town.journal.no_events'), style: DsText.detail())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(d.notice.text,
                    key: const ValueKey('world-event-notice'),
                    softWrap: true,
                    style: DsText.body()),
                SizedBox(height: DsSpace.sm),
                Text(d.body.text, softWrap: true, style: DsText.body()),
                SizedBox(height: DsSpace.sm),
                for (final l in cell.detail.lines)
                  Text(l, softWrap: true, style: DsText.detail()),
              ],
            ),
    );
  }
}
