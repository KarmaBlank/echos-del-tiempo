import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import '../domain/stash.dart';
import 'stash_board.dart';
import 'stash_screen.dart' show stashHelp;

/// Panel ALIJO dentro de la partida (tecla B; lobby y misión, fuera de
/// batalla): el mismo tablero que fuera de la sesión, pero cada
/// movimiento pasa por el anfitrión (`stashPut` / `stashTake`). Ver
/// docs/specs/characters.md § 3.2.
class StashPanel extends StatelessWidget {
  const StashPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final me = view.session.players[view.localId];
    final stash = controller.stash;
    final rules = controller.engine.progression;
    final p = me?.profile;
    final cls =
        p == null ? '' : rules.catalog.classes[p.classId]?.name ?? p.classId;
    return PanelFrame(
      key: const ValueKey('panel-stash'),
      title: 'ALIJO',
      width: 1000,
      onClose: controller.closePanel,
      help: stashHelp,
      actions: [
        PanelButton('CERRAR [B]',
            key: const ValueKey('stash-close'), onPressed: controller.closePanel),
      ],
      child: p == null || stash == null
          ? const Text('Sin alijo')
          : StashBoard(
              key: const ValueKey('stash-board'),
              host: _SessionStashHost(controller, rules, p, stash),
              title: '${p.name} · $cls · Nv ${p.level}'),
    );
  }
}

class _SessionStashHost implements StashBoardHost {
  _SessionStashHost(this.c, this.rules, this.profile, this.stash);

  final SessionController c;
  @override
  final ProgressionRules rules;
  @override
  final PlayerProfile profile;
  @override
  final Stash stash;

  @override
  bool get busy => c.stashBusy;
  @override
  String? get notice => c.stashNotice;

  @override
  String? put(List<String> tokens, int tab) => c.stashPut(tokens, tab: tab);
  @override
  String? take(List<int> cells) => c.stashTake(cells);
  @override
  bool moveStash(int from, int to) => c.stashMove(from, to);
  @override
  bool moveCharacter(int from, int to) =>
      c.moveInventory(from, to);
}
