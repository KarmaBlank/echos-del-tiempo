import '../../../core/i18n/data_text.dart';
import '../../../core/i18n/game_text.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/rules/eco_rules.dart';

/// Player-facing name of [e] in the active language: its own name, or
/// `ui.endgame.eco_name` with the localized zone (the engine's
/// [EcoRules.displayName] is es-AR source text).
String ecoNameText(EcoRules rules, EcoItem e) {
  if (e.name case final n?) return n;
  final z = rules.zoneOf(e);
  final zone =
      z == null ? '?' : GameText.strings.data(DataKeys.zoneName(z.id), z.name);
  return GameText.t('ui.endgame.eco_name', {'zone': zone});
}

/// [ecoNameText] plus its tier: `Echo of Deep Forest · T5`.
String ecoFullText(EcoRules rules, EcoItem e) =>
    '${ecoNameText(rules, e)} · T${e.tier}';
