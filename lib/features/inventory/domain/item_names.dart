import '../../../core/i18n/catalog_text.dart';
import '../../../game_engine/data/cooking_catalog.dart' show MealDef;
import '../../../game_engine/data/farming_catalog.dart';
import '../../../game_engine/data/fishing_catalog.dart';
import '../../../game_engine/i18n/item_keys.dart';
import '../../../game_engine/data/bait_catalog.dart';
import '../../../game_engine/data/smithing_catalog.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/rules/goods_rules.dart';
import '../../../game_engine/models/item_def.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/models/weapon_passive.dart';
import '../../../game_engine/rules/item_rules.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/life_craft_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../game_engine/rules/gear_v2_rules.dart';
import '../../../game_engine/rules/profession_gear_rules.dart';

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

extension MealDefText on MealDef {
  String get text => CatalogText.of(ItemKeys.mealName(id), name);
  String get loreText => CatalogText.of(ItemKeys.mealLore(id), lore);
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
  if (_gearName(i) case final gear?) {
    final t = i.forgeLevel;
    return '$gear${t > 0 ? ' +$t' : ''}';
  }
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

extension ModStatText on ModStat {
  /// [label] in the active language.
  String get text => CatalogText.of(ItemKeys.modStat(this), label);

  /// [format] in the active language (`data.crafting.mod_format.*`).
  String formatText(int value) {
    if (!CatalogText.isTranslated) return format(value);
    final shape = switch (this) {
      ModStat.atkPct ||
      ModStat.magPct ||
      ModStat.critChance ||
      ModStat.critMulti ||
      ModStat.ultCharge ||
      ModStat.healReceived ||
      ModStat.healPower ||
      ModStat.summonDamage ||
      ModStat.breakPower =>
        'pct',
      ModStat.burnStacks ||
      ModStat.poisonStacks ||
      ModStat.freezeStacks =>
        'stacks',
      ModStat.regen => 'regen',
      ModStat.statusResist => 'minus',
      ModStat.lifeSteal => 'plain',
      ModStat.breakSkill => 'main_skill',
      _ => 'flat',
    };
    final v = this == ModStat.speed ? (value / 10).toStringAsFixed(1) : value;
    return CatalogText.of(ItemKeys.modFormat(shape), format(value),
        {'v': v, 'n': value, 'label': text});
  }
}

extension ItemModText on ItemMod {
  /// [ItemMod.text] in the active language.
  String get tr => stat.formatText(value);
}

/// [ItemRules.affixText] in the active language.
String localAffixText(ItemRules items, AffixRoll r, {ItemInstance? on}) {
  if (!CatalogText.isTranslated) return items.affixText(r, on: on);
  final m = items.modOf(r);
  if (m == null) return r.affixId;
  final tier = r.fixed
      ? CatalogText.of(ItemKeys.tierUnique, 'único')
      : 'T${r.tier}';
  if (m.stat == ModStat.breakSkill && on != null) {
    if (items.breakSkillText(on) case final t?) return '$t ($tier)';
  }
  return '${m.tr} ($tier)';
}

extension WeaponPassiveDefText on WeaponPassiveDef {
  /// Name of a weapon passive in the active language.
  String get text => CatalogText.of(ItemKeys.passiveName(id), name);

  /// [nameAt] in the active language.
  String nameAtText(int level) => '$text ${WeaponPassiveDef.roman(level)}';
}

/// Localized name of a profession weapon (profession_gear.md § 6):
/// `data.gear.<id>.name` / `.legend`, or `data.gear.fish.name` with the
/// weapon type and the legendary fish it was forged from.
String? _gearName(ItemInstance i) {
  final def = GearRules.defOf(i);
  if (def != null) {
    return i.rarity == Rarity.legendario
        ? CatalogText.of('data.items.gear.${def.id}.legend', def.legend)
        : CatalogText.of('data.items.gear.${def.id}.name', def.name);
  }
  // Forged by parts (profession_gear_v2.md § 3): "<type> de <metal>".
  if (GearV2Rules.partsType(i) case final type?) {
    final base = i.parts.isEmpty ? '' : i.parts.first;
    return CatalogText.of('data.items.gear.parts.name', '{type} de {metal}', {
      'type': CatalogText.of('data.items.gear.type.${gearTypeKey(type)}',
          kGearTypeNames[type] ?? type),
      'metal': CatalogText.of('data.items.gear.metal.$base',
          GearV2Rules.metalName(base)),
    });
  }
  final fish = GearRules.fishOf(i);
  if (fish == null) return null;
  final type = fishForgeType(fish);
  return CatalogText.of('data.items.gear.fish.name', '{type} de {fish}', {
    'type': CatalogText.of(
        'data.items.gear.type.${gearTypeKey(type)}', kGearTypeNames[type] ?? type),
    'fish': CatalogText.of(ItemKeys.fishName(fish), kFish[fish]?.name ?? fish),
  });
}

/// Name of an overworld goods drop (loot.md § 4c) in the active
/// language: `120 gold`, `2 Copper ore`, `Clear turnip`…
String localGoodsName(LootDrop d) {
  final (kind, id) = GoodsRules.split(d.goods ?? '');
  final n = d.count;
  if (kind == GoodsRules.gold) {
    return CatalogText.of('ui.world.loot.gold', '₵$n', {'n': n});
  }
  final base = switch (kind) {
    'ore' => CatalogText.of(
        'data.materials.smith.$id.name', kSmithMaterials[id]?.name ?? id),
    'crop' => parseCropKey(id)?.$1.text ?? id,
    'seed' => kCrops[id]?.seedText ?? id,
    'wseed' => kWeaponSeedNames[id] ?? id,
    'bait' =>
      CatalogText.of('data.materials.bait.$id.name', kBaits[id]?.name ?? id),
    'fert' => kFertilizers[id]?.text ?? id,
    _ => id,
  };
  return n > 1 ? '$n $base' : base;
}
