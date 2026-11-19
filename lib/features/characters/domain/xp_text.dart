import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../endgame/domain/endgame_text.dart';

/// Progreso de XP para subir (panels.md § "XP para subir", v0.8.6): del
/// nivel, o de la Maestría en el nivel máximo. `null` con la Maestría
/// completa (no hay nada que llenar).
({int value, int max, int left, bool mastery})? xpProgress(PlayerProfile prof) {
  final mastery = prof.level >= ProgressionRules.maxLevel;
  if (mastery && prof.mastery >= PlayerProfile.maxMastery) return null;
  final max = mastery
      ? ProgressionRules.masteryNeed(prof.mastery)
      : ProgressionRules.xpNeed(prof.level);
  final value = prof.xp.clamp(0, max);
  return (value: value, max: max, left: max - value, mastery: mastery);
}

/// `XP 120/300 · faltan 180` (y `para el nivel 13`, con [next]). Con la
/// Maestría completa, el texto de la Maestría.
String xpProgressText(PlayerProfile prof, {bool next = false}) {
  final x = xpProgress(prof);
  if (x == null) return masteryText(prof);
  final goal = x.mastery
      ? 'para la Maestría ${prof.mastery + 1}'
      : 'para el nivel ${prof.level + 1}';
  return 'XP ${x.value}/${x.max} · faltan ${x.left}${next ? ' $goal' : ''}';
}
