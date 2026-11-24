import 'package:material_ui/material_ui.dart';

import '../../../../core/i18n/catalog_text.dart';
import '../../../../game_engine/rules/bait_rules.dart';
import '../../domain/town_names.dart';
import '../world_strings.dart';

/// Name of a bait in the active language.
String baitText(String id) =>
    CatalogText.of(baitNameKey(id), kBaits[id]?.name ?? id);

/// What a bait does (fishing.md § 14.2), one line per effect, shared by
/// the trader, the trade bag and the tooltips.
List<String> baitLines(BuildContext context, String id) {
  final b = kBaits[id];
  if (b == null) return const [];
  String pct(double v) => '${(v * 100).round()}';
  final attracts = [
    if (b.attractsRarity != null) b.attractsRarity!.text,
    if (b.weather != null) b.weather!.text,
    if (b.season != null) b.season!.text,
  ];
  return [
    if (BaitRules.bite(id) > 0)
      context.t('ui.town.bait.bite', {'n': pct(BaitRules.bite(id))}),
    if (BaitRules.rare(id) > 0)
      context.t('ui.town.bait.rare', {'n': pct(BaitRules.rare(id))}),
    if (BaitRules.size(id) > 0)
      context.t('ui.town.bait.size', {'n': pct(BaitRules.size(id))}),
    if (attracts.isNotEmpty)
      context.t('ui.town.bait.attracts', {'list': attracts.join(', ')}),
    context.t('ui.town.bait.per_catch'),
  ];
}

/// The recipe line: "Receta: 1 Cebo prensado + 1 Hongo ámbar + 10 oro → 2".
String baitRecipeLine(BuildContext context, String id, String itemName) {
  final r = kBaits[id]!.recipe;
  return context.t('ui.town.bait.recipe', {
    'cebo': r.cebo,
    'item': r.item == null ? '' : ' + ${r.n} $itemName',
    'gold': BaitRules.gold(id),
    'n': r.yield,
  });
}
