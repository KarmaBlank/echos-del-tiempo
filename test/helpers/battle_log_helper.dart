import 'package:echos_del_tiempo/core/i18n/battle_log_text.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';

/// The battle log as es-AR text (tests read what the old `log` field
/// held; the engine now keeps a structured [BattleState.logLine]).
extension BattleLogText on BattleState {
  String get log => battleLogText(logLine);
}
