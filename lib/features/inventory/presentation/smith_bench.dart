import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../core/procedural/item_icons.dart' show procKeyForType;
import '../../../core/procedural/weapon_look.dart';
import '../../../core/procedural/weapon_parts.dart' show materialColor;
import '../../../game_engine/data/animals_catalog.dart' show parseAnimalPart;
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

/// One activity of the smithy (mining_smithing.md § 3.1): each is its own
/// top tab with a verb, never mixed with the forge steps.
enum SmithTab { smelt, forge, tools }

/// Icon of a smithing material: fish parts show their fish, animal parts
/// their part (`vida_ap_<species>_<part>`, animals.md § 9), everything
/// else its own `vida_<id>` sprite (category icon as fallback).
Widget smithMaterialIcon(String id, {double size = 32}) {
  if (parseAnimalPart(id) case (final sp, final part, _)?) {
    return LifeIcon('ap_${sp}_${part.id}', LifeIconKind.herramienta,
        size: size);
  }
  return switch (parseFishPart(id)) {
    (final sp, _) => LifeIcon(sp, LifeIconKind.pescado, size: size),
    null => LifeIcon(id, LifeIconKind.herramienta, size: size),
  };
}

/// FORJA → HERRERÍA (mining_smithing.md § 3–5, § 3.1): three top tabs —
/// SMELT (ore → ingots), FORGE WEAPON (numbered steps TYPE › BASE › HEAD ›
/// GRIP › SETTING; profession_gear_v2.md § 3) and MINING TOOLS (make picks
/// and supplies). Each one is the workshop template (grid like the
/// INVENTORY, detail on the right). The host validates everything.
class SmithBench extends StatefulWidget {
  const SmithBench({super.key, required this.shop});

  final ShopContext shop;

  @override
  State<SmithBench> createState() => _SmithBenchState();
}

class _SmithBenchState extends State<SmithBench> {
  SmithTab _tab = SmithTab.smelt;

  /// Forge by parts: current step (0 = type, 1.. = [PartSlot]).
  int _step = 0;
  String? _type;
  final _parts = <PartSlot, String>{};

  ShopContext get shop => widget.shop;

  @override
  Widget build(BuildContext context) {
    final s = invStrings(context);
    final p = shop.profile;
    final session = shop.view.session;
    String name(String id) =>
        kSmithMaterials[id] == null ? id : s.t(kSmithMaterials[id]!.textKey);
    String typeName(String t) => s.t('data.items.gear.type.${gearTypeKey(t)}');
    String? why(SmithBlock? b) =>
        b == null ? null : s.t('ui.inventory.smith.why.${b.name}');
    Widget Function(Widget) tipOf(String text) =>
        (c) => c.tip(text);
    final inWorld = session.run == null;
    final smithLv = SmithRules.level(p);

    // ---------------- SMELT ----------------
    DsCraftItem smelt(String ore) {
      final (per, gold) = SmithCraftRules.smeltCost(ore)!;
      final max = SmithCraftRules.smeltMax(p, ore);
      final ingot = ingotOf(ore)!;
      Widget go(int n) {
        final w = !inWorld
            ? s.t('ui.inventory.smith.world_only')
            : why(SmithCraftRules.cannotSmelt(p, ore, n));
        final label = '×$n';
        return DsButton(
          label,
          key: ValueKey('smith-smelt-$ore-$n'),
          size: DsButtonSize.compact,
          kind: DsButtonKind.primary,
          tooltip: w,
          onPressed: w == null
              ? () =>
                    shop.controller.smith(SmithAction(SmithOp.smelt, ore, n: n))
              : null,
        );
      }

      return DsCraftItem(
        id: 'smelt-$ore',
        icon: smithMaterialIcon(ingot),
        border: DsColors.border,
        name: name(ingot),
        cellWrap: tipOf(name(ingot)),
        count: p.life.ore(ingot),
        lines: [
          s.t('ui.inventory.smith.smelt_recipe', {
            'n': per,
            'ore': name(ore),
            'gold': gold,
          }),
          if (max > 0)
            s.t('ui.inventory.smith.have', {'n': p.life.ore(ore), 'max': max})
          else if (p.life.ore(ore) < per)
            s.t('ui.inventory.smith.have_short', {
              'n': p.life.ore(ore),
              'per': per,
            })
          else
            s.t('ui.inventory.smith.have_gold', {
              'n': p.life.ore(ore),
              'gold': gold,
            }),
        ],
        actions: [go(1), go(5)],
      );
    }

    // ---------------- FORGE WEAPON ----------------
    final type = _type;
    final full =
        type != null &&
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
    String partName(String? id) => id == null ? '—' : name(id);
    String elementName(GameElement e) => s.t('data.elements.element.${e.name}');

    // Live preview: the weapon icon with the chosen materials' colours.
    Widget preview() {
      final head = _parts[PartSlot.head];
      final grip = _parts[PartSlot.grip];
      return Row(
        children: [
          PixelIcon(
            iconKeyForType(type ?? 'espada'),
            key: const ValueKey('smith-preview'),
            size: 64,
            accent: DsColors.textSecondary,
            procKey: procKeyForType(type ?? 'espada'),
            look: WeaponLook(
              element: plan?.affinity,
              headColor: head == null ? null : materialColor(head),
              gripColor: grip == null ? null : materialColor(grip),
            ),
          ),
          SizedBox(width: DsSpace.sm),
          Expanded(
            child: Text(
              plan == null
                  ? s.t('ui.inventory.smith.parts.preview_pending')
                  : s.t('ui.inventory.smith.parts.preview', {
                      'q': (plan.quality * 100).round(),
                      'r': plan.rarity.text,
                      'v': elementName(plan.affinity),
                    }),
              style: DsText.detail(),
            ),
          ),
        ],
      );
    }

    List<String> summary() => [
      s.t('ui.inventory.smith.parts.line.type', {
        'v': type == null ? '—' : typeName(type),
      }),
      for (final sl in PartSlot.values)
        s.t('ui.inventory.smith.parts.line.${sl.name}', {
          'v': partName(_parts[sl]),
        }),
      if (plan != null) ...[
        s.t('ui.inventory.smith.parts.line.rarity', {
          'r': plan.rarity.text,
          'cap': SmithCraftRules.maxRarity(smithLv).text,
        }),
        s.t('ui.inventory.smith.forge_desc', {
          'type': typeName(type!),
          'il': plan.itemLevel,
        }),
        if (plan.masterwork) s.t('ui.inventory.smith.parts.line.masterwork'),
        for (final e in plan.need.entries)
          s.t('ui.inventory.smith.cost_ingots', {
            'n': e.value,
            'ingot': partName(e.key),
            'have': p.life.ore(e.key),
          }),
        s.t('ui.inventory.smith.cost_gold', {'gold': plan.gold}),
      ],
    ];
    Widget forgeButton() => DsButton(
      s.t('ui.inventory.smith.go_forge'),
      key: const ValueKey('smith-parts-go'),
      size: DsButtonSize.compact,
      kind: DsButtonKind.primary,
      tooltip: partsBlock,
      onPressed: partsBlock == null
          ? () => shop.controller.smith(
              SmithAction(
                SmithOp.forgeParts,
                parts.first,
                base: type,
                parts: parts.sublist(1),
              ),
            )
          : null,
    );
    void next() {
      if (_step < PartSlot.values.length) _step++;
    }

    DsCraftItem typeCell(String t) {
      final mine = t == _type;
      return DsCraftItem(
        id: 'type-${gearTypeKey(t)}',
        icon: PixelIcon(
          iconKeyForType(t),
          accent: DsColors.textSecondary,
          procKey: procKeyForType(t),
        ),
        border: mine ? DsColors.selected : DsColors.border,
        name: typeName(t),
        cellWrap: tipOf(typeName(t)),
        description: s.t('ui.inventory.smith.parts.type_desc'),
        body: preview(),
        lines: summary(),
        actions: [
          DsButton(
            s.t('ui.inventory.smith.parts.pick'),
            key: ValueKey('smith-parts-pick-type-${gearTypeKey(t)}'),
            size: DsButtonSize.compact,
            selected: mine,
            onPressed: () => setState(() {
              _type = t;
              next();
            }),
          ),
          forgeButton(),
        ],
      );
    }

    GameElement affinityOf(PartSlot sl, String id) => switch (sl) {
      PartSlot.setting => GearV2Rules.partsAffinity([
        'ingot_copper',
        '',
        '',
        id,
      ]),
      _ => GearV2Rules.partsAffinity([id]),
    };
    DsCraftItem partCell(PartSlot sl, String id) {
      final have = p.life.ore(id);
      final mine = _parts[sl] == id;
      final tier = kSmithMaterials[id]?.tier ?? 0;
      return DsCraftItem(
        id: '${sl.name}-$id',
        icon: smithMaterialIcon(id),
        border: mine ? DsColors.selected : DsColors.border,
        name: partName(id),
        cellWrap: tipOf(partName(id)),
        count: have,
        search: partName(id),
        description: switch (sl) {
          PartSlot.base => s.t('ui.inventory.smith.parts.effect.base', {
            'v': elementName(affinityOf(sl, id)),
            'tier': tier,
          }),
          PartSlot.setting => s.t('ui.inventory.smith.parts.effect.setting', {
            'v': elementName(affinityOf(sl, id)),
          }),
          _ => s.t('ui.inventory.smith.parts.effect.colour', {'tier': tier}),
        },
        body: preview(),
        lines: summary(),
        actions: [
          DsButton(
            mine
                ? s.t('ui.inventory.smith.parts.drop')
                : s.t('ui.inventory.smith.parts.pick'),
            key: ValueKey('smith-parts-pick-${sl.name}-$id'),
            size: DsButtonSize.compact,
            selected: mine,
            tooltip: have <= 0 ? s.t('ui.inventory.smith.why.noIngots') : null,
            onPressed: have <= 0 && !mine
                ? null
                : () => setState(() {
                    if (mine) {
                      _parts.remove(sl);
                    } else {
                      _parts[sl] = id;
                      next();
                    }
                  }),
          ),
          forgeButton(),
        ],
      );
    }

    final owned = [
      for (final e in p.life.ores.entries)
        if (e.value > 0) e.key,
    ];
    List<DsCraftItem> stepItems(int step) {
      if (step == 0) return [for (final t in kForgeWeaponTypes) typeCell(t)];
      final sl = PartSlot.values[step - 1];
      return [
        for (final id in {
          if (sl != PartSlot.setting)
            for (final b in kBiomeOres.values) b.ingot,
          if (sl == PartSlot.setting)
            for (final b in kBiomeOres.values) b.rare,
          ...owned,
        })
          if (GearV2Rules.fits(sl, id)) partCell(sl, id),
      ];
    }

    const stepKeys = ['type', 'base', 'head', 'grip', 'setting'];
    final steps = [
      DsStep(
        s.t('ui.inventory.smith.step.type'),
        icon: type == null
            ? null
            : PixelIcon(
                iconKeyForType(type),
                size: 16,
                accent: DsColors.textSecondary,
                procKey: procKeyForType(type),
              ),
      ),
      for (final sl in PartSlot.values)
        DsStep(
          s.t('ui.inventory.smith.step.${sl.name}'),
          icon: _parts[sl] == null
              ? null
              : smithMaterialIcon(_parts[sl]!, size: 16),
        ),
    ];

    // ---------------- MINING TOOLS ----------------
    DsCraftItem tool(String id) {
      final ores = [for (final b in kBiomeOres.values) b.ore];
      final ore = ores.firstWhere(
        (o) => (MiningRules.recipe(id, o)?.mats.entries ?? const []).every(
          (e) => p.life.ore(e.key) >= e.value,
        ),
        orElse: () => ores.first,
      );
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
        icon: smithMaterialIcon(id),
        border: DsColors.border,
        name: name(id),
        cellWrap: tipOf(name(id)),
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
              'have': p.life.ore(e.key),
            }),
          if (rec.gold > 0)
            s.t('ui.inventory.smith.cost_gold', {'gold': rec.gold}),
          if (rec.n > 1) s.t('ui.inventory.smith.mine_batch', {'n': rec.n}),
        ],
        actions: [
          DsButton(
            s.t('ui.inventory.smith.go_make'),
            key: ValueKey('smith-make-$id'),
            size: DsButtonSize.compact,
            kind: DsButtonKind.primary,
            tooltip: block,
            onPressed: block == null
                ? () => shop.controller.craftMine(id, ore)
                : null,
          ),
        ],
      );
    }

    final (hint, items) = switch (_tab) {
      SmithTab.smelt => (
        s.t('ui.inventory.smith.hint.smelt'),
        [for (final b in kBiomeOres.values) smelt(b.ore)],
      ),
      SmithTab.forge => (
        s.t('ui.inventory.smith.hint.${stepKeys[_step]}'),
        stepItems(_step),
      ),
      SmithTab.tools => (
        s.t('ui.inventory.smith.hint.tools'),
        [
          for (final t in kMineTools)
            if (t.ingot != null) tool(t.id),
          for (final id in kMineSupplies) tool(id),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsTabBar(
          tabs: [
            for (final t in SmithTab.values)
              DsTab(
                s.t('ui.inventory.smith.tab.${t.name}'),
                key: ValueKey('smith-tab-${t.name}'),
              ),
          ],
          index: _tab.index,
          onChanged: (i) => setState(() => _tab = SmithTab.values[i]),
        ),
        SizedBox(height: DsSpace.xs),
        if (_tab == SmithTab.forge) ...[
          DsStepper(
            keyPrefix: 'smith',
            steps: steps,
            index: _step,
            onChanged: (i) => setState(() => _step = i),
          ),
          SizedBox(height: DsSpace.xs),
        ],
        Text(hint, key: const ValueKey('smith-hint'), style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: DsCraftGridTemplate(
            key: ValueKey('smith-grid-${_tab.name}-$_step'),
            keyPrefix: 'smith',
            searchHint: _tab == SmithTab.forge && _step > 0
                ? s.t('ui.inventory.smith.search')
                : null,
            empty: s.t('ui.inventory.smith.empty'),
            items: items,
          ),
        ),
      ],
    );
  }
}
