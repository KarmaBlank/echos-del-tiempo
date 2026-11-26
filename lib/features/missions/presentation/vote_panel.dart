import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/ds_tokens.dart';
import '../../../app/theme/proto_colors.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../core/i18n/i18n_providers.dart';

/// Un jugador en la votación.
class VoteEntry {
  const VoteEntry(this.name, {required this.yes});
  final String name;
  final bool yes;
}

/// Votación de misión (`renderVote`, líneas 1364-1375): quién propone,
/// quién ya votó y los botones. Ver docs/specs/panels.md § "Votación".
class VotePanel extends ConsumerWidget {
  const VotePanel({
    super.key,
    required this.proposedBy,
    required this.missionName,
    required this.rank,
    required this.players,
    required this.voted,
    required this.onVote,
  });

  final String proposedBy;
  final String missionName;
  final String rank;
  final List<VoteEntry> players;

  /// El jugador local ya votó que sí.
  final bool voted;
  final ValueChanged<bool> onVote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RetroPanel(
      selected: true,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: ref.t('ui.missions.vote.title'),
                  style: const TextStyle(color: ProtoColors.gold)),
              TextSpan(
                  text: retroText(ref.t('ui.missions.vote.proposes',
                      {'name': proposedBy}))),
              TextSpan(
                  text: retroText(missionName),
                  style: const TextStyle(color: DsColors.text)),
              TextSpan(text: ref.t('ui.missions.vote.rank', {'rank': rank})),
              TextSpan(
                  text:
                      ref.t('ui.missions.vote.yes_count', {
                    'yes': players.where((p) => p.yes).length,
                    'total': players.length,
                  }),
                  style: const TextStyle(color: ProtoColors.green)),
            ]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              for (final p in players)
                Text(retroText('${p.yes ? '> ' : '... '}${p.name}'),
                    style: TextStyle(
                        color:
                            p.yes ? RetroPalette.green : RetroPalette.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: voted
                ? [
                    Text(ref.t('ui.missions.vote.waiting'),
                        style: const TextStyle(color: RetroPalette.muted)),
                    PanelButton(ref.t('ui.missions.vote.cancel'),
                        key: const ValueKey('vote-no'),
                        onPressed: () => onVote(false)),
                  ]
                : [
                    PanelButton(ref.t('ui.missions.vote.yes'),
                        key: const ValueKey('vote-yes'),
                        accent: RetroPalette.green,
                        onPressed: () => onVote(true)),
                    PanelButton(ref.t('ui.missions.vote.no'),
                        key: const ValueKey('vote-no'),
                        onPressed: () => onVote(false)),
                  ],
          ),
        ],
      ),
    );
  }
}
