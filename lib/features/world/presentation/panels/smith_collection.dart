import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart' show kBosque;
import '../../../../game_engine/data/smithing_catalog.dart';
import '../../../../game_engine/models/item.dart' show Rarity;
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/mining_rules.dart';
import '../../../inventory/presentation/item_widgets.dart' show RarityColors;
import '../world_strings.dart';
import 'life_icon.dart';
import 'seed_text.dart' show lifeBiomeLabel;

// OFICIOS → HERRERÍA → COLECCIÓN (mining_smithing.md § 2.1): every
// smithing material on the shared collection template
// (design_system.md § 6.1). Undiscovered entries show a grey "?".

/// Rarity color of a material kind.
Color smithKindColor(SmithMatKind k) => RarityColors.of(switch (k) {
      SmithMatKind.ore || SmithMatKind.ingot => Rarity.comun,
      SmithMatKind.rare => Rarity.raro,
      SmithMatKind.special => Rarity.epico,
    });

/// Where a material was first found (`mine:<biome>`, `dungeon:<zone>`,
/// `smelt`, `boss`).
String smithSourceText(BuildContext context, String source) {
  final parts = source.split(':');
  switch (parts.first) {
    case 'mine' when parts.length > 1:
      return context.t('ui.inventory.smith.col.src.mine',
          {'biome': lifeBiomeLabel(context, parts[1])});
    case 'dungeon' when parts.length > 1:
      final zone = int.tryParse(parts[1]) ?? 0;
      return context.t('ui.inventory.smith.col.src.dungeon', {
        'biome': lifeBiomeLabel(context, biomeOfZone(zone) ?? kBosque),
        'zone': zone,
      });
    case 'smelt':
      return context.t('ui.inventory.smith.col.src.smelt');
    case 'boss':
      return context.t('ui.inventory.smith.col.src.boss');
  }
  return source;
}

String _name(BuildContext context, String id) =>
    context.t(kSmithMaterials[id]?.textKey ?? id);

DsCollectionEntry smithEntry(BuildContext context, PlayerProfile p,
    SmithCollectionEntry e) {
  final d = kSmithMaterials[e.id]!;
  final f = p.life.oreLog[e.id];
  final color = smithKindColor(d.kind);
  return DsCollectionEntry(
    id: e.id,
    discovered: e.discovered,
    icon: LifeIcon(e.icon.replaceFirst('vida_', ''), LifeIconKind.herramienta,
        size: DsCollectionTemplate.iconSize),
    title: context.t(e.nameKey),
    titleColor: color,
    border: color,
    groups: {d.kind.name},
    tags: [(context.t(SmithCollection.rarityKey(d)).toUpperCase(), color)],
    rows: f == null
        ? const []
        : [
            context.t('ui.inventory.smith.col.found',
                {'source': smithSourceText(context, f.source)}),
            context.t('ui.inventory.smith.col.day', {'n': f.day}),
            for (final u in SmithCollection.usesOf(e.id))
              context.t('ui.inventory.smith.col.use.${u.$1}',
                  {'id': _name(context, u.$2)}),
            context.t(SmithCollection.rarityKey(d)),
            context.t('ui.inventory.smith.col.count', {'n': f.count}),
            context.t('ui.inventory.smith.col.have', {'n': p.life.ore(e.id)}),
          ],
  );
}

Widget smithCollection(BuildContext context, PlayerProfile p) =>
    DsCollectionTemplate(
      key: const ValueKey('smith-collection'),
      keyPrefix: 'smith-col',
      entries: [
        for (final e in SmithCollection.entries(p)) smithEntry(context, p, e)
      ],
      filters: [
        ('all', context.t('ui.town.collection.tab_all')),
        for (final k in SmithMatKind.values)
          (k.name, context.t('ui.inventory.smith.col.tab.${k.name}')),
      ],
      progressLabel: (f, t) => context
          .t('ui.town.collection.progress', {'found': f, 'total': t}),
      unknownTitle: context.t('ui.town.bag.undiscovered'),
      unknownHint: context.t('ui.inventory.smith.col.unknown'),
    );
