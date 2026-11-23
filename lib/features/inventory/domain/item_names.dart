import '../../../core/i18n/catalog_text.dart';
import '../../../game_engine/data/farming_catalog.dart';
import '../../../game_engine/data/fishing_catalog.dart';
import '../../../game_engine/i18n/item_keys.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/item_def.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/item_rules.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/life_craft_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';

/// Item-catalog text in the active language (docs/specs/i18n.md § 3.4).
/// The engine keeps the es-AR literal (host notices, saves keep ids); the
/// presentation shows these. In es-AR they return the literal as is.

extension RarityText on Rarity {
  String get text => CatalogText.of(ItemKeys.rarity(this), label);
}

extension WeaponDefText on WeaponDef {
  String get text => CatalogText.of(ItemKeys.weaponName(id), name);
}

extension UniqueDefText on UniqueDef {
  String get text => CatalogText.of(ItemKeys.uniqueName(id), name);
  String get flavorText => CatalogText.of(ItemKeys.uniqueFlavor(id), flavor);
}

extension AffixDefText on AffixDef {
  String get text => CatalogText.of(ItemKeys.affixName(id), name);
}

extension ItemDefText on ItemDef {
  String get text => CatalogText.of(ItemKeys.consumableName(key), name);
  String get descriptionText =>
      CatalogText.of(ItemKeys.consumableDesc(key), description);
}

extension FishDefText on FishDef {
  String get text => CatalogText.of(ItemKeys.fishName(id), name);
  String get loreText => CatalogText.of(ItemKeys.fishLore(id), lore);
}

extension RodDefText on RodDef {
  String get text => CatalogText.of(ItemKeys.rodName(id), name);
}

extension CropDefText on CropDef {
  String get text => CatalogText.of(ItemKeys.cropName(id), name);
  String get seedText => CatalogText.of(ItemKeys.seedName(id), seedName);
  String get loreText => CatalogText.of(ItemKeys.cropLore(id), lore);
}

extension FertDefText on FertDef {
  String get text => CatalogText.of(ItemKeys.fertName(id), name);
}

extension FarmToolDefText on FarmToolDef {
  String get text => CatalogText.of(ItemKeys.farmToolName(id), name);
}

/// [ItemRules.displayName] in the active language. Rare and Epic names
/// are rolled text stored in the save, so they stay as rolled.
String localItemName(ItemRules items, ItemInstance i) {
  if (!CatalogText.isTranslated) return items.displayName(i);
  final base = items.baseOf(i)?.text ?? i.baseId;
  String mods(AffixSlot side) => [
        for (final a in i.affixes)
          if (items.affixOf(a) case final d? when d.slot == side) d.text,
      ].join(' ');
  final name = switch (i.rarity) {
    Rarity.comun => base,
    Rarity.magico => CatalogText.of(ItemKeys.magicName,
            '{base} {prefixes} {suffixes}', {
          'base': base,
          'prefixes': mods(AffixSlot.prefix),
          'suffixes': mods(AffixSlot.suffix),
        }).replaceAll(RegExp(r' {2,}'), ' ').trim(),
    Rarity.raro || Rarity.epico => i.name ?? base,
    Rarity.legendario => items.uniqueOf(i)?.text ?? i.name ?? base,
  };
  final t = i.forgeLevel;
  return '$name${t > 0 ? ' +$t' : ''}';
}

extension LifeMaterialDefText on LifeMaterialDef {
  String get text => CatalogText.of(ItemKeys.lifeMaterialName(id), name);
  String get descriptionText =>
      CatalogText.of(ItemKeys.lifeMaterialDesc(id), description);
}

/// [ProgressionRules.weaponDisplayName] in the active language.
String localWeaponDisplayName(
    ProgressionRules rules, PlayerProfile p, String weaponId) {
  final it = p.item(weaponId);
  if (it == null) return rules.catalog.weapons[weaponId]?.text ?? weaponId;
  return localItemName(rules.items, it);
}
