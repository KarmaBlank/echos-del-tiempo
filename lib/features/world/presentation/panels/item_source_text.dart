import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/i18n/catalog_text.dart';
import '../../../../game_engine/data/bait_catalog.dart';
import '../../../../game_engine/data/cooking_catalog.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/data/smithing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/item_source_rules.dart';
import '../../../../game_engine/rules/life_craft_rules.dart';
import '../../../inventory/domain/item_names.dart';
import '../../domain/town_names.dart';
import '../world_strings.dart';
import 'life_icon.dart';
import 'seed_text.dart';

/// Player-facing name of any trade item id (crop, fish, material, meal,
/// bait, seed `semilla_<crop>`, tool or fertilizer).
String lifeItemText(String id) {
  if (id.startsWith('semilla_')) {
    return kCrops[id.substring(8)]?.seedText ?? id;
  }
  return kCrops[id]?.text ??
      kFish[id]?.text ??
      _smithName(id) ??
      kLifeMaterials[id]?.text ??
      kMeals[id]?.text ??
      kBaits[id]?.name ??
      kFertilizers[id]?.text ??
      kFarmTools[id]?.text ??
      id;
}

String? _smithName(String id) {
  final m = kSmithMaterials[id];
  return m == null ? null : CatalogText.of(m.textKey, m.name);
}

/// The sprite of any trade item id (via [LifeIcon], so the manifest).
Widget lifeItemIcon(String id, {double size = 32}) {
  if (id.startsWith('semilla_')) {
    return LifeIcon(id, LifeIconKind.semilla, size: size);
  }
  if (kCrops.containsKey(id)) {
    return LifeIcon('cosecha_$id', LifeIconKind.cosecha, size: size);
  }
  if (kFish.containsKey(id)) return LifeIcon(id, LifeIconKind.pescado, size: size);
  if (kLifeMaterials.containsKey(id)) {
    return LifeIcon('mat_$id', LifeIconKind.herramienta, size: size);
  }
  if (kMeals.containsKey(id)) {
    return LifeIcon('comida_$id', LifeIconKind.cosecha, size: size);
  }
  if (kBaits.containsKey(id)) {
    return LifeIcon('cebo_$id', LifeIconKind.pescado, size: size);
  }
  return LifeIcon(id, LifeIconKind.herramienta, size: size);
}

String _place(BuildContext context, String? biome) =>
    biome == null ? '' : lifeBiomeLabel(context, biome);

/// "Where to get it" lines of [id] (docs/specs/item_sources.md), shared
/// by item tooltips and cost grids. Empty if the item has no known source.
List<String> itemSourceLines(BuildContext context, String id) => [
      for (final s in ItemSourceRules.of(id))
        switch (s.kind) {
          ItemSourceKind.farmShop => context.t('ui.town.source.farm_shop'),
          ItemSourceKind.crop => context.t('ui.town.source.crop', {
              'place': _place(context, s.biome),
              'seasons': seasonsText(s.seasons ?? const {}),
            }),
          ItemSourceKind.forage => s.biome == null
              ? s.seasons == null
                  ? context.t('ui.town.source.forage_any')
                  : context.t('ui.town.source.forage_season',
                      {'seasons': seasonsText(s.seasons!)})
              : context.t('ui.town.source.forage',
                  {'place': _place(context, s.biome)}),
          ItemSourceKind.fishing => context.t('ui.town.source.fishing', {
              'place': _place(context, s.biome),
              'seasons': seasonsText(s.seasons ?? const {}),
            }),
          ItemSourceKind.mine =>
            context.t('ui.town.source.mine', {'place': _place(context, s.biome)}),
          ItemSourceKind.dungeonVein => context.t('ui.town.source.dungeon_vein'),
          ItemSourceKind.bossDrop => context.t('ui.town.source.boss_drop'),
          ItemSourceKind.smelting => context.t('ui.town.source.smelting',
              {'item': lifeItemText(s.from ?? '')}),
          ItemSourceKind.smithing => context.t('ui.town.source.smithing'),
          ItemSourceKind.workshop => context.t('ui.town.source.workshop'),
          ItemSourceKind.cooking => context.t('ui.town.source.cooking'),
          ItemSourceKind.baitCraft => context.t('ui.town.source.bait_craft'),
        }
    ];

/// The standard item card of [id]: name, have/need and where it is
/// obtained.
Widget itemSourceCard(BuildContext context, String id,
        {int? have, int? need}) =>
    DsTooltipCard(
      title: lifeItemText(id),
      children: [
        if (have != null && need != null)
          Text(context.t('ui.town.source.have_need', {'have': have, 'need': need}),
              style: DsText.body(have >= need ? DsColors.success : DsColors.danger)),
        for (final l in itemSourceLines(context, id))
          Text(l, style: DsText.body()),
      ],
    );

/// Cost grid of [items] (id → amount) with what [p] owns.
Widget itemCostGrid(BuildContext context, PlayerProfile? p,
    Map<String, int> items, {Key? key}) {
  return DsCostGrid(key: key, [
    for (final e in items.entries)
      if (e.value > 0)
        () {
          final have = p == null ? 0 : ItemSourceRules.owned(p, e.key);
          return DsCostEntry(
            id: e.key,
            icon: lifeItemIcon(e.key),
            need: e.value,
            have: have,
            card: itemSourceCard(context, e.key, have: have, need: e.value),
          );
        }(),
  ]);
}
