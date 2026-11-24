import '../../../core/i18n/catalog_text.dart';
import '../../../game_engine/data/fishing_catalog.dart';
import '../../../game_engine/models/world_save.dart';
import '../../../game_engine/rules/life_time_rules.dart';

// Town and world enum labels in the active language (docs/specs/i18n.md
// § 3.8). The engine keeps the es-AR literal; es-AR returns it as is.

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
