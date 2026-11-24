import 'package:material_ui/material_ui.dart';

import '../design/design.dart';

/// Small badge with how many other players are at a destination; hovering
/// lists their names (free_movement.md § 4.1). The tooltip card has the
/// fixed max width and font (ui_style.md § "Tooltips anclados").
class PlayersHereBadge extends StatelessWidget {
  const PlayersHereBadge(
      {super.key, required this.names, required this.title});

  final List<String> names;

  /// Tooltip title (already translated), e.g. "Players here".
  final String title;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    return DsTooltip(
      card: DsTooltipCard(
        title: title,
        children: [
          for (final n in names) Text(n, style: DsText.detail()),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, size: 14, color: DsColors.textSecondary),
          DsBadge('${names.length}', neutral: true),
        ],
      ),
    );
  }
}
