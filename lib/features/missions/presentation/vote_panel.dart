import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_colors.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';

/// Un jugador en la votación.
class VoteEntry {
  const VoteEntry(this.name, {required this.yes});
  final String name;
  final bool yes;
}

/// Votación de misión (`renderVote`, líneas 1364-1375): quién propone,
/// quién ya votó y los botones. Ver docs/specs/panels.md § "Votación".
class VotePanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return RetroPanel(
      selected: true,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(
                  text: 'Votación',
                  style: TextStyle(
                      color: ProtoColors.gold, fontWeight: FontWeight.bold)),
              TextSpan(text: retroText(' · $proposedBy propone ')),
              TextSpan(
                  text: retroText(missionName),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: ' (rango $rank)'),
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
                    const Text('Esperando al resto...',
                        style: TextStyle(color: RetroPalette.muted)),
                    PanelButton('CANCELAR',
                        key: const ValueKey('vote-no'),
                        onPressed: () => onVote(false)),
                  ]
                : [
                    PanelButton('SÍ [Y]',
                        key: const ValueKey('vote-yes'),
                        accent: RetroPalette.green,
                        onPressed: () => onVote(true)),
                    PanelButton('NO [N]',
                        key: const ValueKey('vote-no'),
                        onPressed: () => onVote(false)),
                  ],
          ),
        ],
      ),
    );
  }
}
