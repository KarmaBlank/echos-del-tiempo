import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/i18n/catalog_text.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/bait_rules.dart';
import '../../../../game_engine/rules/life_time_rules.dart';
import '../../../inventory/domain/item_names.dart';
import '../../domain/town_names.dart';
import '../world_strings.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'seed_text.dart';

// OFICIOS → PESCA / CULTIVO → COLECCIÓN (weather_seasons.md § 7): every
// fish and every planted crop on the shared collection template.
// Undiscovered entries show a grey "?" and no info.

/// Season subtabs shared by both collections.
List<(String, String)> _seasonTabs(BuildContext context) => [
      ('all', context.t('ui.town.collection.tab_all')),
      for (final s in Season.values) (s.name, s.text.toUpperCase()),
    ];

String _progress(BuildContext context, int found, int total) =>
    context.t('ui.town.collection.progress', {'found': found, 'total': total});

/// The fish of the collection (no junk, no bundle).
Iterable<FishDef> get collectionFish =>
    kFish.values.where((f) => f.biome != kWaterJunkBiome);

/// The planted crops of the collection (no wild products).
Iterable<CropDef> get collectionCrops =>
    kCrops.values.where((c) => c.biome != 'silvestre');

String _water(BuildContext context, String biome) =>
    context.t('ui.town.collection.water.$biome');

DsCollectionEntry fishEntry(BuildContext context, PlayerProfile p, FishDef d) {
  final rec = p.life.log[d.id];
  final seasons = LifeTimeRules.fishSeasons(d.id);
  final bait = BaitRules.bestFor(d.id);
  return DsCollectionEntry(
    id: d.id,
    discovered: rec != null,
    icon: LifeIcon(d.id, LifeIconKind.pescado,
        size: DsCollectionTemplate.iconSize),
    title: d.text,
    titleColor: fishRarityColor(d.rarity),
    border: fishRarityColor(d.rarity),
    groups: {for (final s in seasons) s.name},
    tags: [
      (d.rarity.text.toUpperCase(), fishRarityColor(d.rarity)),
    ],
    rows: rec == null
        ? const []
        : [
            context.t('ui.town.collection.where', {
              'place': lifeBiomeLabel(context, d.biome),
              'water': _water(context, d.biome),
            }),
            context.t('ui.town.bag.bites', {'time': fishWhenText(d.id)}),
            context.t('ui.town.bag.seasons', {'list': seasonsText(seasons)}),
            context.t('ui.town.bag.record', {'n': rec}),
            if (bait != null)
              context.t('ui.town.collection.best_bait',
                  {'bait': CatalogText.of(baitNameKey(bait), kBaits[bait]!.name)}),
          ],
  );
}

String _quality(CropQuality q) =>
    CatalogText.of('ui.town.crop_quality.${q.name}', q.label);

DsCollectionEntry cropEntry(BuildContext context, PlayerProfile p, CropDef d) {
  final best = p.life.farm.cropLog[d.id];
  final seasons = LifeTimeRules.cropSeasons(d.id);
  return DsCollectionEntry(
    id: d.id,
    discovered: best != null,
    icon: LifeIcon('cosecha_${d.id}', LifeIconKind.cosecha,
        size: DsCollectionTemplate.iconSize),
    title: d.text,
    titleColor: fishRarityColor(d.rarity),
    border: fishRarityColor(d.rarity),
    groups: {for (final s in seasons) s.name},
    tags: [(d.rarity.text.toUpperCase(), fishRarityColor(d.rarity))],
    rows: best == null
        ? const []
        : [
            ...seedSeasonLines(context, d),
            context.t('ui.town.trader.grows_in',
                {'min': (d.growSec / 60).round()}),
            d.seedPrice > 0
                ? context.t('ui.town.collection.seeds_shop')
                : context.t('ui.town.collection.seeds_wild',
                    {'place': lifeBiomeLabel(context, d.biome)}),
            context.t('ui.town.bag.origin',
                {'place': lifeBiomeLabel(context, d.biome).toLowerCase()}),
            context.t('ui.town.collection.uses', {'n': d.price}),
            context.t('ui.town.collection.best_quality', {
              'q': _quality(CropQuality.values[best.clamp(0, 3)]),
            }),
          ],
  );
}

Widget fishCollection(BuildContext context, PlayerProfile p) =>
    DsCollectionTemplate(
      key: const ValueKey('fish-collection'),
      keyPrefix: 'fish-col',
      entries: [for (final d in collectionFish) fishEntry(context, p, d)],
      filters: _seasonTabs(context),
      progressLabel: (f, t) => _progress(context, f, t),
      unknownTitle: context.t('ui.town.bag.undiscovered'),
      unknownHint: context.t('ui.town.collection.unknown_fish'),
    );

Widget cropCollection(BuildContext context, PlayerProfile p) =>
    DsCollectionTemplate(
      key: const ValueKey('crop-collection'),
      keyPrefix: 'crop-col',
      entries: [for (final d in collectionCrops) cropEntry(context, p, d)],
      filters: _seasonTabs(context),
      progressLabel: (f, t) => _progress(context, f, t),
      unknownTitle: context.t('ui.town.bag.undiscovered'),
      unknownHint: context.t('ui.town.collection.unknown_crop'),
    );
