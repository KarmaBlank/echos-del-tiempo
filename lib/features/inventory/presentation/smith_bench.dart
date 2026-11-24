import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../core/procedural/item_icons.dart' show procKeyForType;
import '../../../game_engine/data/smithing_catalog.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/life_tree_rules.dart' show SmithRules;
import '../../../game_engine/rules/mining_rules.dart';
import '../../../game_engine/rules/resident_rules.dart' show ResidentRules;
import '../../../game_engine/rules/farming_rules.dart';
import '../../../game_engine/rules/fishing_rules.dart';
import '../../world/presentation/panels/life_icon.dart';
import '../domain/item_names.dart';
import 'inventory_strings.dart';
import 'item_widgets.dart';
import 'shop_sections.dart';

/// FORJA → HERRERÍA (mining_smithing.md § 3–5): the workshop template
/// (grid like the INVENTORY, detail on the right) with the recipes as
/// sub-tabs: SMELT, FORGE and BRANN. The host validates everything.
class SmithBench extends StatefulWidget {
  const SmithBench({super.key, required this.shop});

  final ShopContext shop;

  @override
  State<SmithBench> createState() => _SmithBenchState();
}

class _SmithBenchState extends State<SmithBench> {
  String? _ingot;
  Rarity _rarity = Rarity.comun;

  ShopContext get shop => widget.shop;

  @override
  Widget build(BuildContext context) {
    final s = invStrings(context);
    final p = shop.profile;
    final session = shop.view.session;
    final ingots = [for (final b in kBiomeOres.values) b.ingot];
    final ingot = _ingot ??
        ingots.lastWhere((i) => p.life.ore(i) > 0, orElse: () => ingots.first);
    String name(String id) => s.t(kSmithMaterials[id]!.textKey);
    String? why(SmithBlock? b) =>
        b == null ? null : s.t('ui.inventory.smith.why.${b.name}');
    final inWorld = session.run == null;
    final smithLv = SmithRules.level(p);
    final brann = session.town.resident('brann');
    final brannCap = Rarity.values[ResidentRules.commissionRarity(brann,
        fishLv: FishingRules.level(p),
        farmLv: FarmingRules.level(p),
        smithLv: smithLv)];

    DsCraftItem smelt(String ore) {
      final (per, gold) = SmithCraftRules.smeltCost(ore)!;
      final max = SmithCraftRules.smeltMax(p, ore);
      Widget go(int n) {
        final w = !inWorld
            ? s.t('ui.inventory.smith.world_only')
            : why(SmithCraftRules.cannotSmelt(p, ore, n));
        final label = '×$n';
        return DsButton(label,
            key: ValueKey('smith-smelt-$ore-$n'),
            size: DsButtonSize.compact,
            kind: DsButtonKind.primary,
            tooltip: w,
            onPressed: w == null
                ? () => shop.controller.smith(SmithAction(SmithOp.smelt, ore, n: n))
                : null);
      }

      return DsCraftItem(
        id: 'smelt-$ore',
        icon: LifeIcon(ore, LifeIconKind.herramienta, size: 32),
        border: DsColors.border,
        name: name(ingotOf(ore)!),
        tag: 'smelt',
        count: p.life.ore(ingotOf(ore)!),
        lines: [
          s.t('ui.inventory.smith.smelt_recipe', {
            'n': per,
            'ore': name(ore),
            'gold': gold,
          }),
          s.t('ui.inventory.smith.have', {'n': p.life.ore(ore), 'max': max}),
        ],
        actions: [go(1), go(5)],
      );
    }

    DsCraftItem forge(String id, bool byBrann) {
      final w = shop.rules.catalog.weapons[id]!;
      final cap = byBrann ? brannCap : SmithCraftRules.maxRarity(smithLv);
      final c = SmithCraftRules.cost(p.level, ingot, _rarity, brann: byBrann)!;
      final block = !inWorld
          ? s.t('ui.inventory.smith.world_only')
          : why(SmithCraftRules.cannotForge(p, w, ingot, _rarity,
              maxRarity: cap,
              brann: byBrann,
              brannHome: brann.invited && brann.house > 0));
      final tag = byBrann ? 'brann' : 'forge';
      return DsCraftItem(
        id: '$tag-$id',
        icon: PixelIcon(iconKeyForType(w.type),
            accent: RarityColors.of(_rarity), procKey: procKeyForType(w.type)),
        border: RarityColors.of(_rarity),
        name: w.text,
        tag: tag,
        search: '${w.text} ${w.type}',
        description: s.t('ui.inventory.smith.forge_desc',
            {'type': w.type, 'il': c.itemLevel}),
        body: Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          for (final i in ingots)
            DsButton(name(i),
                key: ValueKey('smith-ingot-$i'),
                size: DsButtonSize.compact,
                selected: i == ingot,
                onPressed: () => setState(() => _ingot = i)),
          for (final r in Rarity.values)
            DsButton(r.text,
                key: ValueKey('smith-rarity-${r.name}'),
                size: DsButtonSize.compact,
                selected: r == _rarity,
                onPressed: () => setState(() => _rarity = r)),
        ]),
        lines: [
          s.t('ui.inventory.smith.cost_ingots',
              {'n': c.ingots, 'ingot': name(ingot), 'have': p.life.ore(ingot)}),
          if (c.rares > 0)
            s.t('ui.inventory.smith.cost_rare', {
              'n': c.rares,
              'rare': name(c.rare),
              'have': p.life.ore(c.rare)
            }),
          if (c.recipe) s.t('ui.inventory.smith.cost_recipe'),
          s.t('ui.inventory.smith.cost_gold', {'gold': c.gold}),
          s.t('ui.inventory.smith.cap', {'rarity': cap.text}),
        ],
        actions: [
          DsButton(
              s.t(byBrann
                  ? 'ui.inventory.smith.go_brann'
                  : 'ui.inventory.smith.go_forge'),
              key: ValueKey('smith-go-$tag-$id'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.primary,
              tooltip: block,
              onPressed: block == null
                  ? () => shop.controller.smith(SmithAction(
                      byBrann ? SmithOp.brann : SmithOp.forge, ingot,
                      base: id, rarity: _rarity.index))
                  : null),
        ],
      );
    }

    final bases = SmithCraftRules.bases(
        shop.rules.catalog.weapons.values, p.level, ingot);
    return DsCraftGridTemplate(
      key: const ValueKey('smith-grid'),
      keyPrefix: 'smith',
      searchHint: s.t('ui.inventory.smith.search'),
      empty: s.t('ui.inventory.smith.empty'),
      filters: [
        DsTransferFilter(s.t('ui.inventory.smith.tab.smelt'), 'smelt'),
        DsTransferFilter(s.t('ui.inventory.smith.tab.forge'), 'forge'),
        DsTransferFilter(s.t('ui.inventory.smith.tab.brann'), 'brann'),
      ],
      items: [
        for (final b in kBiomeOres.values) smelt(b.ore),
        for (final w in bases) forge(w.id, false),
        for (final w in bases) forge(w.id, true),
      ],
    );
  }
}
