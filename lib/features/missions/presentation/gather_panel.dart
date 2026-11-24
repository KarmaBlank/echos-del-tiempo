import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/session_action.dart';

/// Open gathering card (free_movement.md § 2.1): who called it, who is
/// going and the buttons. The proposer gets IR (always enabled) and
/// CANCELAR; the others UNIRSE / SALIR. Presentation only: [onOp] sends
/// the choice.
class GatherPanel extends ConsumerWidget {
  const GatherPanel({
    super.key,
    required this.gather,
    required this.localId,
    required this.onOp,
  });

  final Gathering gather;
  final String localId;
  final ValueChanged<GatherOp> onOp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = gather;
    final mine = g.byId == localId;
    final joined = g.joined.any((j) => j.id == localId);
    final going = [g.byName, for (final j in g.joined) j.name];
    return RetroPanel(
      key: const ValueKey('gather-panel'),
      selected: true,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ref.t('ui.missions.gather.title'),
              style: const TextStyle(color: ProtoColors.gold)),
          Text(
              retroText(mine
                  ? ref.t('ui.missions.gather.mine', {'mission': g.label})
                  : ref.t('ui.missions.gather.by',
                      {'name': g.byName, 'mission': g.label})),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
              retroText(mine && g.joined.isEmpty
                  ? ref.t('ui.missions.gather.nobody')
                  : ref.t('ui.missions.gather.joined',
                      {'names': going.join(', ')})),
              style: const TextStyle(color: RetroPalette.green)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: mine
                ? [
                    PanelButton(ref.t('ui.missions.gather.go'),
                        key: const ValueKey('gather-go'),
                        accent: RetroPalette.green,
                        onPressed: () => onOp(GatherOp.go)),
                    PanelButton(ref.t('ui.missions.gather.cancel'),
                        key: const ValueKey('gather-cancel'),
                        onPressed: () => onOp(GatherOp.cancel)),
                  ]
                : joined
                    ? [
                        PanelButton(ref.t('ui.missions.gather.leave'),
                            key: const ValueKey('gather-leave'),
                            onPressed: () => onOp(GatherOp.leave)),
                      ]
                    : [
                        PanelButton(ref.t('ui.missions.gather.join'),
                            key: const ValueKey('gather-join'),
                            accent: RetroPalette.green,
                            onPressed: () => onOp(GatherOp.join)),
                      ],
          ),
        ],
      ),
    );
  }
}
