import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../core/procedural/item_icons.dart' show procKeyForType;
import '../../../game_engine/data/mine_catalog.dart';
import '../../../game_engine/data/smithing_catalog.dart';
import '../../../game_engine/models/elements.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/gear_v2_rules.dart';
import '../../../game_engine/rules/life_tree_rules.dart' show SmithRules;
import '../../../game_engine/rules/profession_gear_rules.dart' show gearTypeKey;
import '../../../game_engine/rules/mining_rules.dart';
import '../../world/presentation/panels/life_icon.dart';
import '../domain/item_names.dart';
import 'inventory_strings.dart';
import 'item_widgets.dart';
import 'shop_sections.dart';

/// FORJA → HERRERÍA (mining_smithing.md § 3–5): the workshop template
/// (grid like the INVENTORY, detail on the right) with the recipes as
/// sub-tabs: SMELT, the forge-by-parts steps (TYPE, BASE, HEAD, GRIP,
/// SETTING; profession_gear_v2.md § 3) and MINE. Brann's commissions live in his own
/// NPC menu (mining_smithing.md § 5.1). The host validates everything.
class SmithBench extends StatefulWidget {
  const SmithBench({super.key, required this.shop});

  final ShopContext shop;

  @override
  State<SmithBench> createState() => _SmithBenchState();
}

class _SmithBenchState extends State<SmithBench> {
  /// Forge by parts: the chosen type and part per step.
  String? _type;
  final _parts = <PartSlot, String>{};

  ShopContext get shop => widget.shop;

  @override
  Widget build(BuildContext context) {
    final s = invStrings(context);
    final p = shop.profile;
    final session = shop.view.session;
    String name(String id) => s.t(kSmithMaterials[id]!.textKey);
    String typeName(String t) => s.t('data.items.gear.type.${gearTypeKey(t)}');
    String? why(SmithBlock? b) =>
        b == null ? null : s.t('ui.inventory.smith.why.${b.name}');
    final inWorld = session.run == null;
    final smithLv = SmithRules.level(p);
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
                ? () =>
                    shop.controller.smith(SmithAction(SmithOp.smelt, ore, n: n))
                : null);
      }

      return DsCraftItem(
        id: 'smelt-$ore',
        // The ingot it makes (each one has its own art, not the anvil).
        icon: LifeIcon(ingotOf(ore)!, LifeIconKind.herramienta, size: 32),
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
          // Why it is 0 when there is ore: say what is missing.
          if (max > 0)
            s.t('ui.inventory.smith.have', {'n': p.life.ore(ore), 'max': max})
          else if (p.life.ore(ore) < per)
            s.t('ui.inventory.smith.have_short',
                {'n': p.life.ore(ore), 'per': per})
          else
            s.t('ui.inventory.smith.have_gold',
                {'n': p.life.ore(ore), 'gold': gold}),
        ],
        actions: [go(1), go(5)],
      );
    }

    // Forge by parts (profession_gear_v2.md § 3): one sub-tab per step,
    // the grid shows what fits that step, the detail the weapon so far.
    final type = _type;
    final full = type != null &&
        _parts[PartSlot.base] != null &&
        _parts[PartSlot.head] != null &&
        _parts[PartSlot.grip] != null;
    final parts = full
        ? [
            _parts[PartSlot.base]!,
            _parts[PartSlot.head]!,
            _parts[PartSlot.grip]!,
            if (_parts[PartSlot.setting] case final st?) st,
          ]
        : const <String>[];
    final plan = full ? GearV2Rules.plan(p, type, parts) : null;
    final partsBlock = !inWorld
        ? s.t('ui.inventory.smith.world_only')
        : !full
            ? s.t('ui.inventory.smith.parts.why.badPart')
            : switch (GearV2Rules.cannotForge(p, type, parts)) {
                null => null,
                final b => s.t('ui.inventory.smith.parts.why.${b.name}'),
              };
    String partName(String? id) => id == null
        ? '—'
        : kSmithMaterials[id] == null
            ? id
            : name(id);
    String elementName(GameElement e) =>
        s.t('data.elements.element.${e.name}');
    List<String> summary() => [
          s.t('ui.inventory.smith.parts.line.type',
              {'v': type == null ? '—' : typeName(type)}),
          for (final sl in PartSlot.values)
            s.t('ui.inventory.smith.parts.line.${sl.name}',
                {'v': partName(_parts[sl])}),
          if (plan != null) ...[
            s.t('ui.inventory.smith.parts.line.affinity',
                {'v': elementName(plan.affinity)}),
            s.t('ui.inventory.smith.parts.line.quality',
                {'q': (plan.quality * 100).round()}),
            s.t('ui.inventory.smith.parts.line.rarity', {
              'r': plan.rarity.text,
              'cap': SmithCraftRules.maxRarity(smithLv).text
            }),
            s.t('ui.inventory.smith.forge_desc',
                {'type': typeName(type!), 'il': plan.itemLevel}),
            if (plan.masterwork)
              s.t('ui.inventory.smith.parts.line.masterwork'),
            for (final e in plan.need.entries)
              s.t('ui.inventory.smith.cost_ingots', {
                'n': e.value,
                'ingot': partName(e.key),
                'have': p.life.ore(e.key)
              }),
            s.t('ui.inventory.smith.cost_gold', {'gold': plan.gold}),
          ],
        ];
    Widget forgeButton() => DsButton(s.t('ui.inventory.smith.go_forge'),
        key: const ValueKey('smith-parts-go'),
        size: DsButtonSize.compact,
        kind: DsButtonKind.primary,
        tooltip: partsBlock,
        onPressed: partsBlock == null
            ? () => shop.controller.smith(SmithAction(
                SmithOp.forgeParts, parts.first,
                base: type, parts: parts.sublist(1)))
            : null);
    DsCraftItem typeCell(String t) => DsCraftItem(
          id: 'type-${gearTypeKey(t)}',
          icon: PixelIcon(iconKeyForType(t),
              accent: DsColors.textSecondary, procKey: procKeyForType(t)),
          border: t == _type ? DsColors.selected : DsColors.border,
          name: typeName(t),
          tag: 'type',
          lines: summary(),
          actions: [
            DsButton(s.t('ui.inventory.smith.parts.pick'),
                key: ValueKey('smith-parts-pick-type-${gearTypeKey(t)}'),
                size: DsButtonSize.compact,
                selected: t == _type,
                onPressed: () => setState(() => _type = t)),
            forgeButton(),
          ],
        );
    GameElement affinityOf(PartSlot sl, String id) => switch (sl) {
          PartSlot.base => GearV2Rules.partsAffinity([id]),
          PartSlot.setting =>
            GearV2Rules.partsAffinity(['ingot_copper', '', '', id]),
          _ => GearV2Rules.partsAffinity([id]),
        };
    DsCraftItem partCell(PartSlot sl, String id) {
      final have = p.life.ore(id);
      final fish = parseFishPart(id);
      final mine = _parts[sl] == id;
      return DsCraftItem(
        id: '${sl.name}-$id',
        icon: fish != null
            ? LifeIcon(fish.$1, LifeIconKind.pescado, size: 32)
            : LifeIcon(id, LifeIconKind.herramienta, size: 32),
        border: mine ? DsColors.selected : DsColors.border,
        name: partName(id),
        tag: sl.name,
        count: have,
        search: partName(id),
        description: sl == PartSlot.base || sl == PartSlot.setting
            ? s.t('ui.inventory.smith.parts.affinity_of',
                {'v': elementName(affinityOf(sl, id))})
            : s.t('ui.inventory.smith.parts.colour_of'),
        lines: summary(),
        actions: [
          DsButton(
              mine
                  ? s.t('ui.inventory.smith.parts.drop')
                  : s.t('ui.inventory.smith.parts.pick'),
              key: ValueKey('smith-parts-pick-${sl.name}-$id'),
              size: DsButtonSize.compact,
              selected: mine,
              tooltip:
                  have <= 0 ? s.t('ui.inventory.smith.why.noIngots') : null,
              onPressed: have <= 0 && !mine
                  ? null
                  : () => setState(() {
                        if (mine) {
                          _parts.remove(sl);
                        } else {
                          _parts[sl] = id;
                        }
                      })),
          forgeButton(),
        ],
      );
    }

    final owned = [
      for (final e in p.life.ores.entries)
        if (e.value > 0) e.key
    ];
    final stepItems = [
      for (final t in kForgeWeaponTypes) typeCell(t),
      for (final sl in PartSlot.values)
        for (final id in {
          if (sl != PartSlot.setting)
            for (final b in kBiomeOres.values) b.ingot,
          if (sl == PartSlot.setting)
            for (final b in kBiomeOres.values) b.rare,
          ...owned,
        })
          if (GearV2Rules.fits(sl, id)) partCell(sl, id),
    ];

    DsCraftItem tool(String id) {
      final ores = [for (final b in kBiomeOres.values) b.ore];
      final ore = ores.firstWhere(
          (o) => (MiningRules.recipe(id, o)?.mats.entries ?? const [])
              .every((e) => p.life.ore(e.key) >= e.value),
          orElse: () => ores.first);
      final rec = MiningRules.recipe(id, ore)!;
      final owned = mineTool(id) != null && p.life.ore(id) > 0;
      final short = rec.mats.entries.any((e) => p.life.ore(e.key) < e.value);
      final block = !inWorld
          ? s.t('ui.inventory.smith.world_only')
          : owned
              ? s.t('ui.inventory.smith.mine_owned')
              : short
                  ? s.t('ui.inventory.smith.why.noOre')
                  : p.credits < rec.gold
                      ? s.t('ui.inventory.smith.why.noGold')
                      : null;
      final t = mineTool(id);
      return DsCraftItem(
        id: 'mine-$id',
        icon: LifeIcon(id, LifeIconKind.herramienta, size: 32),
        border: DsColors.border,
        name: name(id),
        tag: 'mine',
        count: p.life.ore(id),
        description: t == null
            ? s.t('ui.inventory.smith.mine_desc.$id')
            : s.t('ui.inventory.smith.mine_tool_desc', {
                'tier': t.tier,
                'power': t.power,
                'swing': t.swing.toStringAsFixed(2),
              }),
        lines: [
          for (final e in rec.mats.entries)
            s.t('ui.inventory.smith.cost_ingots', {
              'n': e.value,
              'ingot': name(e.key),
              'have': p.life.ore(e.key)
            }),
          if (rec.gold > 0)
            s.t('ui.inventory.smith.cost_gold', {'gold': rec.gold}),
          if (rec.n > 1) s.t('ui.inventory.smith.mine_batch', {'n': rec.n}),
        ],
        actions: [
          DsButton(s.t('ui.inventory.smith.go_make'),
              key: ValueKey('smith-make-$id'),
              size: DsButtonSize.compact,
              kind: DsButtonKind.primary,
              tooltip: block,
              onPressed: block == null
                  ? () => shop.controller.craftMine(id, ore)
                  : null),
        ],
      );
    }

    return DsCraftGridTemplate(
      key: const ValueKey('smith-grid'),
      keyPrefix: 'smith',
      searchHint: s.t('ui.inventory.smith.search'),
      empty: s.t('ui.inventory.smith.empty'),
      filters: [
        DsTransferFilter(s.t('ui.inventory.smith.tab.smelt'), 'smelt'),
        DsTransferFilter(s.t('ui.inventory.smith.tab.type'), 'type'),
        for (final sl in PartSlot.values)
          DsTransferFilter(
              s.t('ui.inventory.smith.tab.${sl.name}'), sl.name),
        DsTransferFilter(s.t('ui.inventory.smith.tab.mine'), 'mine'),
      ],
      items: [
        for (final b in kBiomeOres.values) smelt(b.ore),
        ...stepItems,
        for (final t in kMineTools)
          if (t.ingot != null) tool(t.id),
        for (final id in kMineSupplies) tool(id),
      ],
    );
  }
}
