import '../../../core/i18n/catalog_text.dart';
import '../../../game_engine/data/climate_catalog.dart';
import '../../../game_engine/data/fishing_catalog.dart';
import '../../../game_engine/models/world_save.dart';
import '../../../game_engine/rules/life_time_rules.dart';

// Town and world enum labels in the active language (docs/specs/i18n.md
// § 3.8). The engine keeps the es-AR literal; es-AR returns it as is.

// The CLIMA editor's names win (weather_seasons.md § 8.2); else i18n.
extension WeatherText on Weather {
  String get text =>
      kClimateNames[weatherNameKey(this)]?.text ??
      CatalogText.of('ui.town.weather.$name', label);
}

extension SeasonText on Season {
  String get text =>
      kClimateNames[seasonNameKey(this)]?.text ??
      CatalogText.of('ui.town.season.$name', label);
}

/// When a fish bites, in the active language: time of day and, if it
/// asks for one, the weather (fishing.md § 13).
String fishWhenText(String id) {
  final w = LifeTimeRules.fishWeather(id);
  final t = LifeTimeRules.fishTime(id).text;
  return w == null ? t : '$t · ${w.text}';
}

/// "Primavera, verano" or "Todo el año" (weather_seasons.md § 4–5).
String seasonsText(Set<Season> seasons) => seasons.length >= 4
    ? CatalogText.of('ui.town.season.all_year', 'Todo el año')
    : [
        for (final s in Season.values)
          if (seasons.contains(s)) s.text
      ].join(', ');

extension BuildKindText on BuildKind {
  String get text => CatalogText.of('ui.town.build_kind.$name', label);
}

extension HelperTaskText on HelperTask {
  String get text => CatalogText.of('ui.town.helper_task.$name', label);
}

extension DayTimeText on DayTime {
  String get text => CatalogText.of('ui.town.day_time.$name', label);
}

extension CropAffinityText on CropAffinity {
  String get text => CatalogText.of('ui.town.crop_affinity.$name', label);
}

extension FishRarityText on FishRarity {
  String get text => CatalogText.of('ui.town.fish_rarity.$name', label);
}

extension WorldLabelText on WorldLabel {
  String get tr => CatalogText.of('ui.lobby.world_label.$name', text);
}
