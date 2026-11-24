import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/rules/life_time_rules.dart';
import '../../domain/town_names.dart';
import '../world_strings.dart';

/// Player-facing name of a biome (`zona1` is the town).
String lifeBiomeLabel(BuildContext context, String id) => id == 'zona1'
    ? context.t('ui.town.bag.town')
    : kBiomes.where((b) => b.id == id).firstOrNull?.name ?? id.toUpperCase();

/// Grow-time bucket of a seed (fishing.md § 5): short < 5 min,
/// medium < 15 min, long otherwise.
enum GrowBucket {
  short,
  medium,
  long;

  static GrowBucket of(CropDef c) => c.growSec < 300
      ? GrowBucket.short
      : c.growSec < 900
          ? GrowBucket.medium
          : GrowBucket.long;

  String label(BuildContext context) =>
      context.t('ui.town.trader.grow.$name');
}

/// Seed data lines shared by every seed tooltip/detail: grow time, biome
/// of origin and time-of-day affinity.
List<String> seedInfoLines(BuildContext context, CropDef s) => [
      context.t('ui.town.trader.grows_in', {'min': (s.growSec / 60).round()}),
      context.t('ui.town.bag.origin',
          {'place': lifeBiomeLabel(context, s.biome).toLowerCase()}),
      LifeTimeRules.cropAffinity(s.id).text,
    ];
