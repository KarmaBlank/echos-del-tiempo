import '../../../inventory/domain/item_names.dart';
import '../../domain/town_names.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/helper_rules.dart';
import '../../../../game_engine/rules/life_craft_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'item_source_text.dart';
import 'life_icon.dart';
import 'life_item_grid.dart';
import '../world_strings.dart';

/// Pantalla de un ayudante (farming.md § 8, v0.25.5; tecla G al lado del
/// NPC). Granjero: SEMILLAS (plantilla TRASPASO: las tuyas a la
/// izquierda, las de la huerta a la derecha), TAREAS (plantar, regar, cosechar) y COFRE.
/// Pescador: MEJORAS y COFRE. MEJORAS (v0.27.0, farming.md § 8.5): grilla
/// de mejoras de este ayudante con su rango, costo y MEJORAR. Todo lo valida el anfitrión.
class HelperPanel extends StatefulWidget {
  const HelperPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<HelperPanel> createState() => _HelperPanelState();
}

class _HelperPanelState extends State<HelperPanel> {
  int _tab = 0;

  SessionController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final hp = c.helperPanel;
    final b = hp == null ? null : c.town.build(hp.$1);
    if (b == null || hp!.$2 >= b.helper) {
      return PanelFrame(
          key: const ValueKey('panel-helper'),
          title: context.t('ui.town.helper.title'),
          width: 480,
          onClose: c.closePanel,
          child: Text(context.t('ui.town.helper.gone'), style: DsText.detail()));
    }
    final farm = b.kind == BuildKind.huerta;
    final i = hp.$2;
    final tabs = farm
        ? const ['SEMILLAS', 'TAREAS', 'MEJORAS', 'COFRE']
        : const ['MEJORAS', 'COFRE'];
    final tab = _tab.clamp(0, tabs.length - 1);
    return PanelFrame(
      key: const ValueKey('panel-helper'),
      title: context.t(farm ? 'ui.town.helper.farmer_n' : 'ui.town.helper.fisher_n',
          {'n': i + 1}),
      width: 820,
      onClose: c.closePanel,
      actions: [
        PanelButton(context.t('ui.town.helper.close'),
            key: const ValueKey('helper-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bloqueado (farming.md § 8.6): "!" dorado y los motivos.
          if (HelperRules.blockers(b, i) case final why when why.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: DsSpace.xs),
              child: DsToast(why.join(' · '),
                  key: const ValueKey('helper-blocked'),
                  kind: DsToastKind.reward,
                  leading: Text('!', style: DsText.title(DsColors.reward))),
            ),
          Text(TownRules.helperLine(b), style: DsText.detail()),
          Builder(builder: (_) {
            final st = b.stat(i);
            final (xp, need) = HelperRules.progress(st);
            return Text(
                need > 0
                    ? context.t('ui.town.helper.level_xp', {'level': HelperRules.level(st), 'xp': xp, 'need': need})
                    : context.t('ui.town.helper.level_max', {'level': HelperRules.level(st)}),
                key: const ValueKey('helper-level'),
                style: DsText.body());
          }),
          SizedBox(height: DsSpace.xs),
          if (tabs.length > 1)
            DsTabBar(
              tabs: [
                for (final t in tabs)
                  DsTab(_tabLabel(t),
                      key: ValueKey('helper-tab-${t.toLowerCase()}')),
              ],
              index: tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
          SizedBox(height: DsSpace.sm),
          switch (tabs[tab]) {
            'SEMILLAS' => _seeds(b),
            'TAREAS' => _tasks(b, i),
            'MEJORAS' => _upgrades(b, i),
            _ => _chest(b),
          },
        ],
      ),
    );
  }

  String _tabLabel(String t) => context.t(switch (t) {
        'SEMILLAS' => 'ui.town.helper.tab.seeds',
        'TAREAS' => 'ui.town.helper.tab.tasks',
        'MEJORAS' => 'ui.town.helper.tab.upgrades',
        _ => 'ui.town.helper.tab.chest',
      });

  // ---------------- SEMILLAS ----------------

  List<DsTransferFilter> get _rarityFilters => [
    DsTransferFilter(context.t('ui.town.helper.all'), null),
    for (final r in FishRarity.values)
      DsTransferFilter(r.text.toUpperCase(), r.name),
  ];

  DsTransferItem _seedItem(TownBuild b, String id, int n, bool theirs) {
    final d = kCrops[id]!;
    final mine = widget.view.me?.profile.life.farm.seedCount(id) ?? 0;
    final there = b.seeds[id] ?? 0;
    return DsTransferItem(
      id: id,
      icon: LifeIcon('semilla_$id', LifeIconKind.semilla,
          size: LifeItemGrid.iconSize),
      name: d.seedName,
      border: fishRarityColor(d.rarity),
      count: n,
      tag: d.rarity.name,
      info: context.t('ui.town.helper.seed_info', {'rarity': d.rarity.text, 'mine': mine, 'there': there}),
    );
  }

  List<DsTransferItem> _sorted(
          Map<String, int> m, DsTransferItem? Function(String, int) f) =>
      [
        for (final e in (m.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))))
          if (e.value > 0)
            if (f(e.key, e.value) case final x?) x
      ];

  Widget _seeds(TownBuild b) {
    final mine =
        widget.view.me?.profile.life.farm.seeds ?? const <String, int>{};
    return DsTransferTemplate(
      key: const ValueKey('helper-seeds'),
      keyPrefix: 'helper',
      leftTitle: context.t('ui.town.helper.your_seeds'),
      rightTitle: context.t('ui.town.helper.farm_seeds'),
      left: _sorted(mine,
          (k, n) => kCrops[k] == null ? null : _seedItem(b, k, n, false)),
      right: _sorted(b.seeds,
          (k, n) => kCrops[k] == null ? null : _seedItem(b, k, n, true)),
      filters: _rarityFilters,
      searchHint: context.t('ui.town.helper.search_seed'),
      leftEmpty: context.t('ui.town.helper.no_seeds'),
      rightEmpty: context.t('ui.town.helper.farm_no_seeds'),
      onMove: (from, id, q) => from == DsTransferSide.left
          ? c.giveSeeds(b.id, id, q)
          : c.takeSeeds(b.id, id, q),
    );
  }

  // ---------------- TAREAS ----------------

  Widget _tasks(TownBuild b, int i) {
    final mask = b.taskMask(i);
    final next = TownRules.farmerNext(b, i);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
            context.t('ui.town.helper.tasks_text'),
            style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
          for (final t in HelperTask.values)
            DsButton('${t.index + 1}. ${t.text.toUpperCase()}',
                key: ValueKey('helper-task-${t.name}'),
                selected: mask & t.bit != 0,
                onPressed: () =>
                    c.setHelperTasks(b.id, i, mask ^ t.bit)),
        ]),
        SizedBox(height: DsSpace.sm),
        Text(
            context.t('ui.town.helper.next_cycle', {'task': next?.text.toLowerCase() ?? context.t('ui.town.helper.rests'), 's': c.helperRoundIn.ceil()}),
            key: const ValueKey('helper-next'),
            style: DsText.body()),
      ],
    );
  }

  // ---------------- MEJORAS ----------------

  Widget _upgrades(TownBuild b, int i) {
    final p = widget.view.me?.profile;
    final st = b.stat(i);
    final mat = HelperRules.matOf(b.kind);
    LifeItemCellData cell(HelperUpgrade u) {
      final r = st.rank(u);
      final max = r >= HelperRules.maxRank;
      final cost = max ? null : HelperRules.upgradeCost(b.kind, r + 1);
      final why = p == null
          ? context.t('ui.town.helper.no_character')
          : HelperRules.cannotUpgrade(p, b, i, u);
      final col = max ? DsColors.textTitle : DsColors.border;
      return LifeItemCellData(
        id: 'helper-up-${u.name}',
        icon: LifeIcon('mejora_${u.name}', LifeIconKind.herramienta,
            size: LifeItemGrid.iconSize),
        border: col,
        search: u.label,
        caption: '$r/${HelperRules.maxRank}',
        detail: LifeItemDetail(
          name: u.label,
          nameColor: DsColors.textTitle,
          tags: [
            (context.t('ui.town.helper.rank', {'n': r, 'max': HelperRules.maxRank}),
                DsColors.textSecondary)
          ],
          lines: [
            context.t('ui.town.helper.per_rank', {'effect': HelperRules.effectText(u)}),
            if (cost != null)
              context.t('ui.town.helper.costs', {'cost': HelperRules.costText(cost)}),
            if (cost != null) context.t('ui.town.helper.needs_level', {'n': cost.level}),
          ],
          cost: cost == null || cost.mats.isEmpty
              ? null
              : itemCostGrid(context, p, cost.mats,
                  key: ValueKey('helper-up-cost-${u.name}')),
          actions: [
            DsButton(max ? context.t('ui.town.helper.max') : context.t('ui.town.helper.upgrade'),
                key: ValueKey('helper-up-go-${u.name}'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                tooltip: why,
                onPressed: why == null
                    ? () => c.upgradeHelper(b.id, i, u)
                    : null),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
            context.t('ui.town.helper.upgrades_text', {'who': b.kind == BuildKind.huerta ? 'farmer' : 'fisher', 'mat': kLifeMaterials[mat]!.name.toLowerCase()}),
            style: DsText.detail()),
        DsGoldText(
            context.t('ui.town.helper.upgrades_have', {'n': p?.life.craft(mat) ?? 0, 'mat': kLifeMaterials[mat]!.name.toLowerCase(), 'planks': p?.life.craft('tabla') ?? 0, 'gold': p?.credits ?? 0}),
            key: const ValueKey('helper-up-have'),
            style: DsText.body()),
        SizedBox(height: DsSpace.xs),
        SizedBox(
          height: 300,
          child: LifeItemGrid(
            key: const ValueKey('helper-upgrades'),
            groups: [
              LifeItemGroup(context.t('ui.town.helper.tab.upgrades'), [
                for (final u in HelperRules.upgradesOf(b.kind)) cell(u)
              ]),
            ],
            empty: context.t('ui.town.helper.no_upgrades'),
          ),
        ),
      ],
    );
  }

  // ---------------- COFRE ----------------

  Widget _chest(TownBuild b) {
    final lake = b.kind == BuildKind.lago;
    final p = widget.view.me?.profile;
    DsTransferItem? cell(String k, int n) {
      if (lake) {
        final f = kFish[k];
        return DsTransferItem(
          id: k,
          icon: LifeIcon(k, LifeIconKind.pescado, size: LifeItemGrid.iconSize),
          name: f?.text ?? k,
          border: f == null ? DsColors.border : fishRarityColor(f.rarity),
          count: n,
          tag: f?.rarity.name,
          info: context.t('ui.town.helper.in_chest'),
        );
      }
      final pc = parseCropKey(k);
      return DsTransferItem(
        id: k,
        icon: LifeIcon('cosecha_${pc?.$1.id ?? k}', LifeIconKind.cosecha,
            size: LifeItemGrid.iconSize),
        name: pc == null ? k : '${pc.$1.text} (${pc.$2.label.toLowerCase()})',
        border: pc == null ? DsColors.border : fishRarityColor(pc.$1.rarity),
        count: n,
        tag: pc?.$1.rarity.name,
        info: context.t('ui.town.helper.in_chest'),
      );
    }

    // Lo tuyo del mismo tipo (solo para ver, el cofre se recoge entero).
    final mine = p == null
        ? const <String, int>{}
        : lake
            ? p.life.bag
            : p.life.farm.crops;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.t('ui.town.helper.chest_count', {'n': b.chestTotal, 'max': TownRules.t.i('chestMax')}),
            key: const ValueKey('helper-chest-count'),
            style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        DsTransferTemplate(
          key: const ValueKey('helper-chest'),
          keyPrefix: 'helper-chest',
          leftTitle: lake ? context.t('ui.town.helper.your_fish') : context.t('ui.town.helper.your_crops'),
          rightTitle: context.t('ui.town.helper.tab.chest'),
          left: _sorted(mine, cell),
          right: _sorted(b.chest, cell),
          filters: _rarityFilters,
          allowLeftToRight: false,
          allowRightToLeft: false,
          leftEmpty: lake ? context.t('ui.town.helper.no_fish') : context.t('ui.town.helper.collect_to_bag'),
          rightEmpty: context.t('ui.town.helper.chest_empty'),
          extraActions: [
            DsButton(context.t('ui.town.helper.collect_all'),
                key: const ValueKey('helper-collect'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                onPressed:
                    b.chest.isEmpty ? null : () => c.collectChest(b.id)),
          ],
          onMove: (a, b, n) {},
        ),
      ],
    );
  }
}
