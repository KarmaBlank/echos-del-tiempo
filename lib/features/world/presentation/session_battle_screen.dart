import 'package:material_ui/material_ui.dart';

import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/rules/session_engine.dart';
import '../../combat/presentation/battle_screen.dart';
import '../../combat/presentation/game_sprites.dart';
import 'session_view.dart';

/// La batalla de la sesión (`S.battle`): dibuja `session.battle.state`
/// con [BattleView] y manda los comandos del jugador local como
/// `BattleAction` cuando el host espera su turno. Ver
/// docs/specs/exploration.md § "Batalla".
///
/// Fase 4 la reemplaza por una escena Flame; la conexión con la sesión
/// (este widget) es la misma.
class SessionBattleScreen extends StatelessWidget {
  const SessionBattleScreen({
    super.key,
    required this.view,
    required this.onCommand,
    this.sprites,
    this.battleKey,
  });

  final SessionView view;
  final bool Function(BattleCommand command) onCommand;
  final GameSprites? sprites;

  /// Para mandarle las teclas de batalla (1-9, Q/Tab, Esc).
  final GlobalKey<BattleViewState>? battleKey;

  @override
  Widget build(BuildContext context) {
    final b = view.session.battle;
    if (b == null) return const SizedBox.shrink();
    final myTurn = view.myTurn;
    return BattleView(
      key: battleKey,
      battle: b.state,
      events: view.battleEvents,
      canAct: myTurn,
      turnTimeLeft:
          b.waitingForPlayer ? SessionEngine.turnLimit - b.turnTime : null,
      sprites: sprites,
      onCommand: onCommand,
    );
  }
}
