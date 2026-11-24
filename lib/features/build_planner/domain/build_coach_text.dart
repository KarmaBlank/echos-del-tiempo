import '../../../core/i18n/catalog_text.dart';
import '../../../game_engine/data/affixes_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/rules/build_coach_rules.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import '../../inventory/domain/item_names.dart';

// Build coach labels in the active language (docs/specs/i18n.md § 3.8,
// domain `ui.build`). [BuildCoach] keeps the es-AR literals; es-AR
// returns them as is.

extension BuildAreaText on BuildArea {
  String get text => CatalogText.of('ui.build.area.$name', label);
}

extension WeaponFitText on WeaponFit {
  String get text => CatalogText.of('ui.build.fit.$name', label);
}

/// [BuildCoach.difficultyLabel] in the active language.
String coachDifficultyText(int d) => CatalogText.of(
    'ui.build.difficulty.${d <= 1 ? 'easy' : d == 2 ? 'medium' : 'advanced'}',
    BuildCoach.difficultyLabel(d));

/// [BuildCoach.attributeName] in the active language.
String coachAttributeName(Attribute a) =>
    CatalogText.of('ui.build.attr.${a.name}', BuildCoach.attributeName(a));

/// [BuildCoach.attributeLabel] in the active language: "Fuerza (FUE)".
String coachAttributeLabel(Attribute a) => CatalogText.of(
    'ui.build.attr.label',
    BuildCoach.attributeLabel(a),
    {'name': coachAttributeName(a), 'short': BuildPlanRules.attributeShort(a)});

/// [BuildCoach.tierText] in the active language.
String coachTierText(int tier) => CatalogText.of(
    'ui.build.tier.${tier <= 1 ? 'best' : tier >= 5 ? 'any' : 'or_better'}',
    BuildCoach.tierText(tier),
    {'n': tier});

extension ModWantedText on ModWanted {
  /// [ModWanted.name] in the active language.
  String get nameText => kAffixes[affixId]?.text ?? affixId;

  /// [ModWanted.text] in the active language: "Arcano, nivel 3 o mejor".
  String get textTr => CatalogText.of('ui.build.mod_wanted', text,
      {'name': nameText, 'tier': coachTierText(minTier)});

  /// [ModWanted.status] in the active language. [reason] and
  /// [suggestion] come from the engine (es-AR).
  String get statusTr => CatalogText.of('ui.build.mod_state.${state.name}',
      status, {
    'source': source ?? '',
    'target': target ?? '',
    'reason': reason ?? '',
    'suggestion': suggestion ?? '',
    'has_suggestion': suggestion == null ? 'no' : 'yes',
  });
}
