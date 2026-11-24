import '../models/item.dart';

/// String keys of the item-related catalogs (docs/specs/i18n.md § 3.4).
/// The engine keeps ids and these keys; the presentation resolves the text
/// (`CatalogText`). The es-AR tables mirror the catalog literals (a test
/// keeps them in sync), so saves and the network only ever carry ids.
abstract final class ItemKeys {
  static String weaponName(String id) => 'data.items.weapon.$id.name';
  static String uniqueName(String id) => 'data.items.unique.$id.name';
  static String uniqueFlavor(String id) => 'data.items.unique.$id.flavor';
  static String consumableName(String key) =>
      'data.items.consumable.$key.name';
  static String consumableDesc(String key) =>
      'data.items.consumable.$key.desc';
  static String rarity(Rarity r) => 'data.items.rarity.${r.name}';
  static String passiveName(String id) => 'data.items.passive.$id.name';

  /// Label of a mod stat (`ModStat.label`).
  static String modStat(ModStat s) => 'data.crafting.mod.${s.name}';

  /// Tier of a fixed (legendary) mod: "único".
  static const tierUnique = 'data.crafting.tier.unique';

  /// Shapes of `ModStat.format` as ICU (`v` value, `label` the stat label);
  /// es-AR gives the same text as the engine.
  static const modFormats = {
    'pct': '+{v}{label}',
    'flat': '+{v} {label}',
    'stacks': '+{v} {v, plural, one{stack} other{stacks}} de {label}',
    'regen': 'Regenera {v}{label}',
    'minus': '−{v} {label}',
    'plain': '{v}{label}',
    'main_skill': 'Habilidad principal: {label}',
  };
  static String modFormat(String shape) => 'data.crafting.mod_format.$shape';

  static String affixName(String id) => 'data.crafting.affix.$id.name';

  /// Word order of a Magic item's name (`{base} {prefixes} {suffixes}`).
  static const magicName = 'data.crafting.magic_name';

  static String fishName(String id) => 'data.materials.fish.$id.name';
  static String fishLore(String id) => 'data.materials.fish.$id.lore';
  static String rodName(String id) => 'data.materials.rod.$id.name';
  static String cropName(String id) => 'data.materials.crop.$id.name';
  static String cropLore(String id) => 'data.materials.crop.$id.lore';
  static String seedName(String id) => 'data.materials.crop.$id.seed';
  static String mealName(String id) => 'data.materials.meal.$id.name';
  static String mealLore(String id) => 'data.materials.meal.$id.lore';
  static String fertName(String id) => 'data.materials.fert.$id.name';
  static String farmToolName(String id) => 'data.materials.tool.$id.name';
  static String lifeMaterialName(String id) => 'data.materials.life.$id.name';
  static String lifeMaterialDesc(String id) => 'data.materials.life.$id.desc';
}
