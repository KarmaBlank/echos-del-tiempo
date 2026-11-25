import '../../../core/i18n/catalog_text.dart';
import '../../../core/i18n/data_text.dart';
import '../../../game_engine/data/cooking_catalog.dart' show kMeals;
import '../../../game_engine/data/farming_catalog.dart';
import '../../../game_engine/data/fishing_catalog.dart';
import '../../../game_engine/data/smithing_catalog.dart';
import '../../../game_engine/data/zones_catalog.dart';
import '../../inventory/domain/item_names.dart';
import '../../../game_engine/rules/quest_track_rules.dart';
import '../../../game_engine/rules/resident_rules.dart';

// Quest text in the active language (docs/specs/quest_audit.md § 7):
// the engine keeps ids and es-AR literals; the quest menus show these.

/// Key of the flavor text of step [i] (0-based) of [npc]'s chain.
String questTextKey(String npc, int i) => 'ui.town.quest.$npc.$i';

/// Flavor text of step [i] of [npc]'s chain.
String questFlavor(String npc, int i, QuestStepDef q) =>
    CatalogText.of(questTextKey(npc, i), q.text);

/// RECOLECTAR, PESCAR... in the active language.
String questKindText(QuestKind k) =>
    CatalogText.of('ui.town.npc.kind.${k.name}', k.label);

/// Encargo / pedido / orden in the active language.
String trackKindText(QuestTrackKind k) =>
    CatalogText.of('ui.town.track.kind.${k.name}', k.label);

String relicName(ResidentRelicDef r) =>
    CatalogText.of('ui.town.relic.${r.id}.name', r.name);

String relicLore(ResidentRelicDef r) =>
    CatalogText.of('ui.town.relic.${r.id}.lore', r.lore);

/// Name of the zone a dungeon or elite step asks for (never the number).
String questZoneName(QuestStepDef q) {
  final z = int.tryParse(q.target);
  if (z == null || z < 1 || z > kZones.length) return q.target;
  final d = kZones[z - 1];
  return CatalogText.of(DataKeys.zoneName(d.id), d.name);
}

/// "Ilda · encargo 3" / "Ilda · orden" in the active language.
String activeQuestWho(ActiveQuest a) {
  final k = trackKindText(a.kind).toLowerCase();
  return a.step > 0 ? '${a.npc.name} · $k ${a.step}' : '${a.npc.name} · $k';
}

/// Name of anything a quest or order asks for (meal, fish, crop or
/// smithing item), never the raw id. Forged weapon orders: `questItemText`.
String questItemName(String id) {
  if (kMeals[id] case final m?) return m.text;
  if (kFish[id] case final f?) return f.text;
  if (kCrops[id] case final c?) return c.text;
  if (kSmithMaterials[id] case final m?) return CatalogText.of(m.textKey, m.name);
  // Tools / supplies and unknown ids: readable es-AR name, never the id.
  return QuestTrackRules.itemName(id);
}

/// What a resident asks to build, in the active language.
String requestText(ResidentRequest r) =>
    CatalogText.of('ui.town.request.${r.name}', r.label);

/// Crop quality name in the active language.
String cropQualityText(CropQuality q) =>
    CatalogText.of('ui.town.crop_quality.${q.name}', q.label);
