import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/core/i18n/catalog_text.dart';
import 'package:echos_del_tiempo/core/i18n/locale_id.dart';
import 'package:echos_del_tiempo/core/i18n/string_tables.dart';
import 'package:echos_del_tiempo/game_engine/data/affixes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/bait_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/cooking_catalog.dart' show kMeals;
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/items_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/smithing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapon_passives.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/i18n/item_keys.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_craft_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// es-AR text of the item catalogs, taken from the catalog literals
/// (docs/specs/i18n.md § 3.4). `I18N_UPDATE_CATALOGS=1` rewrites the
/// es-AR files (and adds empty en / zh-Hans entries for new keys).
Map<String, Map<String, String>> catalogSource() {
  final items = <String, String>{
    for (final w in kWeapons.values) ItemKeys.weaponName(w.id): w.name,
    for (final u in kUniques.values) ...{
      ItemKeys.uniqueName(u.id): u.name,
      if (u.flavor.isNotEmpty) ItemKeys.uniqueFlavor(u.id): u.flavor,
    },
    for (final i in kItems.values) ...{
      ItemKeys.consumableName(i.key): i.name,
      ItemKeys.consumableDesc(i.key): i.description,
    },
    for (final r in Rarity.values) ItemKeys.rarity(r): r.label,
    for (final p in kWeaponPassives.values) ItemKeys.passiveName(p.id): p.name,
  };
  final crafting = <String, String>{
    for (final a in kAffixes.values) ItemKeys.affixName(a.id): a.name,
    ItemKeys.magicName: '{base} {prefixes} {suffixes}',
    for (final s in ModStat.values) ItemKeys.modStat(s): s.label,
    for (final e in ItemKeys.modFormats.entries)
      ItemKeys.modFormat(e.key): e.value,
    ItemKeys.tierUnique: 'único',
  };
  final materials = <String, String>{
    for (final f in kFish.values) ...{
      ItemKeys.fishName(f.id): f.name,
      if (f.lore.isNotEmpty) ItemKeys.fishLore(f.id): f.lore,
    },
    for (final r in kRods.values) ItemKeys.rodName(r.id): r.name,
    for (final c in kCrops.values) ...{
      ItemKeys.cropName(c.id): c.name,
      ItemKeys.seedName(c.id): c.seedName,
      if (c.lore.isNotEmpty) ItemKeys.cropLore(c.id): c.lore,
    },
    for (final m in kMeals.values) ...{
      ItemKeys.mealName(m.id): m.name,
      if (m.lore.isNotEmpty) ItemKeys.mealLore(m.id): m.lore,
    },
    for (final f in kFertilizers.values) ItemKeys.fertName(f.id): f.name,
    for (final b in kBaits.values) baitNameKey(b.id): b.name,
    for (final t in kFarmTools.values) ItemKeys.farmToolName(t.id): t.name,
    for (final m in kLifeMaterials.values) ...{
      ItemKeys.lifeMaterialName(m.id): m.name,
      ItemKeys.lifeMaterialDesc(m.id): m.description,
    },
    for (final m in kSmithMaterials.values) m.textKey: m.name,
  };
  return {
    'data.items': items,
    'data.crafting': crafting,
    'data.materials': materials,
  };
}

Map<String, dynamic> _read(File f) => f.existsSync()
    ? (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)
    : <String, dynamic>{};

void _write(File f, Map<String, dynamic> m) {
  final sorted = {for (final k in m.keys.toList()..sort()) k: m[k]};
  f.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
}

void main() {
  final source = catalogSource();

  if (Platform.environment['I18N_UPDATE_CATALOGS'] == '1') {
    for (final MapEntry(key: domain, value: entries) in source.entries) {
      _write(File('assets/i18n/es-AR/$domain.json'), entries);
      for (final tag in ['en', 'zh-Hans']) {
        final f = File('assets/i18n/$tag/$domain.json');
        final m = _read(f)..removeWhere((k, _) => !entries.containsKey(k));
        for (final k in entries.keys) {
          m.putIfAbsent(k, () => '');
        }
        _write(f, m);
      }
    }
  }

  test('es-AR item catalogs mirror the catalog literals', () {
    for (final MapEntry(key: domain, value: entries) in source.entries) {
      final onDisk = _read(File('assets/i18n/es-AR/$domain.json'));
      expect(onDisk, entries, reason: '$domain out of sync: '
          'I18N_UPDATE_CATALOGS=1 flutter test $_self');
    }
  });

  test('CatalogText falls back to the literal and resolves English', () {
    final tables = StringTables.loadDirectorySync(StringTables.assetRoot)!;
    addTearDown(() => CatalogText.active = null);
    const key = 'data.items.rarity.legendario';
    CatalogText.active = tables.strings(LocaleId.esAR);
    expect(CatalogText.of(key, 'Legendario'), 'Legendario');
    CatalogText.active = tables.strings(LocaleId.en);
    expect(CatalogText.of(key, 'Legendario'), 'Legendary');
    expect(CatalogText.of('data.items.nope', 'X'), 'X');
  });
}

const _self = 'test/i18n/item_catalog_keys_test.dart';
