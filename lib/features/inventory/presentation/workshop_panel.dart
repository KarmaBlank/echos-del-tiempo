import 'package:material_ui/material_ui.dart';
import '../domain/item_names.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/life_skills.dart' show kLifeMaterialIds;
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/life_craft_rules.dart';
import '../../world/presentation/panels/item_source_text.dart';
import '../../world/presentation/panels/life_icon.dart';
import '../../world/presentation/panels/life_item_grid.dart';
import '../../world/presentation/panels/party_member_bar.dart';
import '../../world/presentation/panels/tool_shop_grid.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import 'inventory_strings.dart';
import 'shop_sections.dart';

/// Oficio de cada receta del taller (filtro de chip).
const kWorkshopOficio = <String, String>{
  'fibra': 'cultivo',
  'cebo': 'pesca',
  'tabla': 'cultivo',
};

/// Ayuda `[?]` del taller.
String workshopHelp(BuildContext context) =>
    invStrings(context).t('ui.inventory.workshop.help');

/// TALLER DE OFICIOS del pueblo, la casa de los oficios (town_loop.md
/// § 2.1, v0.48.5): subpestañas CRAFTEO (materiales de oficio) y
/// HERRAMIENTAS (cañas, azadas, regaderas, picos; el agropecuario ya no
/// las vende). El host valida (`CraftOp.condense` con el prefijo de
/// oficio y las compras de herramienta de siempre).
class WorkshopPanel extends StatefulWidget {
  const WorkshopPanel(
      {super.key, required this.view, required this.controller, this.tab = 0});

  final SessionView view;
  final SessionController controller;

  /// Subpestaña inicial: 0 CRAFTEO, 1 HERRAMIENTAS.
  final int tab;

  @override
  State<WorkshopPanel> createState() => _WorkshopPanelState();
}

class _WorkshopPanelState extends State<WorkshopPanel> {
  late int _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    final view = widget.view, controller = widget.controller;
    final close = view.mustAllocate ? null : controller.closePanel;
    final shop = ShopContext(view, controller);
    final p = shop.profile;
    final s = invStrings(context);
    return PartyMemberKeys(
      view: view,
      controller: controller,
      child: PanelFrame(
        key: const ValueKey('panel-workshop'),
        title: s.t('ui.inventory.workshop.title'),
        width: 1000,
        fill: true,
        help: workshopHelp(context),
        onClose: close,
        titleTrailing: ProtoText(s.t('ui.inventory.workshop.credits',
            {'credits': '₵${p.credits}'})),
        header: PartyMemberBar.header(view, controller, const SizedBox.shrink()),
        actions: [
          PanelButton(s.t('ui.inventory.armory.character'),
              onPressed: () => controller.openPanel(WorldPanel.character)),
          PanelButton(s.t('ui.inventory.armory.close'), onPressed: close),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsTabBar(
              tabs: [
                DsTab(s.t('ui.inventory.workshop.tab.craft'),
                    key: const ValueKey('workshop-tab-craft')),
                DsTab(s.t('ui.inventory.workshop.tab.tools'),
                    key: const ValueKey('workshop-tab-tools')),
              ],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            SizedBox(height: DsSpace.xs),
            PanelHint(s.t(_tab == 0
                ? 'ui.inventory.workshop.hint'
                : 'ui.inventory.workshop.tools_hint')),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('${view.actorId}-$_tab'),
                child: _tab == 0
                    ? WorkshopGrid(shop: shop)
                    : ToolShopGrid(view: view, controller: controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One ingredient of a workshop recipe, for a given amount.
typedef WorkshopIngredient = ({
  String id,
  Widget icon,
  String name,
  int need,
  int have,
  List<String> sources,
  String? detail,
});

/// CRAFTEO: grilla de recetas (casillas de INVENTARIO) en una columna
/// angosta y el detalle llenando el resto (también la usa el Editor).
class WorkshopGrid extends StatefulWidget {
  const WorkshopGrid({super.key, required this.shop});

  final ShopContext shop;

  /// Grid column: 6 inventory cells (the three filter chips fit in a row).
  static const gridWidth = LifeItemGrid.cell * 6 + LifeItemGrid.gap * 5 + 8;

  @override
  State<WorkshopGrid> createState() => _WorkshopGridState();
}

class _WorkshopGridState extends State<WorkshopGrid> {
  int _filter = 0;
  String? _sel;
  int _qty = 1;

  static const _tags = [null, 'cultivo', 'pesca'];

  PlayerProfile get p => widget.shop.profile;

  Widget _icon(String id, double size) => LifeIcon(
      'mat_$id',
      switch (id) {
        'cebo' => LifeIconKind.pescado,
        'fibra' => LifeIconKind.cosecha,
        _ => LifeIconKind.herramienta,
      },
      size: size);

  List<WorkshopIngredient> _ingredients(
      BuildContext context, String id, int n) {
    final s = invStrings(context);
    final r = LifeCraftRules.recipe(id)!;
    int sum(List<(String, int)> l) => l.fold(0, (a, e) => a + e.$2);
    return [
      if (r.crops > 0)
        (
          id: 'any_crop',
          icon: const LifeIcon('cosecha', LifeIconKind.cosecha, size: 32),
          name: s.t('ui.inventory.workshop.ing.crops'),
          need: r.crops * n,
          have: sum(LifeCraftRules.spendableCrops(p)),
          sources: [s.t('ui.inventory.workshop.ing.crops_src')],
          detail: s.t('ui.inventory.workshop.ing.crops_desc'),
        ),
      if (r.fish > 0)
        (
          id: 'any_fish',
          icon: const LifeIcon('pescado', LifeIconKind.pescado, size: 32),
          name: s.t('ui.inventory.workshop.ing.fish'),
          need: r.fish * n,
          have: sum(LifeCraftRules.spendableFish(p)),
          sources: [s.t('ui.inventory.workshop.ing.fish_src')],
          detail: s.t('ui.inventory.workshop.ing.fish_desc'),
        ),
      if (r.fibras > 0)
        (
          id: 'fibra',
          icon: _icon('fibra', 32),
          name: kLifeMaterials['fibra']!.text,
          need: r.fibras * n,
          have: p.life.craft('fibra'),
          sources: itemSourceLines(context, 'fibra'),
          detail: kLifeMaterials['fibra']!.descriptionText,
        ),
      if (r.esquirlas > 0)
        (
          id: 'esquirla',
          icon: const PixelIcon(PixelIconKind.shard,
              size: 32, color: ProtoColors.sky),
          name: s.t('ui.inventory.workshop.ing.shard'),
          need: r.esquirlas * n,
          have: p.material(CraftMaterial.esquirla),
          sources: [s.t('ui.inventory.workshop.ing.shard_src')],
          detail: null,
        ),
      if (r.credits > 0)
        (
          id: 'gold',
          icon: const PixelIcon(PixelIconKind.coin,
              size: 32, color: ProtoColors.gold),
          name: s.t('ui.inventory.workshop.ing.gold'),
          need: r.credits * n,
          have: p.credits,
          sources: [s.t('ui.inventory.workshop.ing.gold_src')],
          detail: null,
        ),
    ];
  }

  Widget _card(BuildContext context, WorkshopIngredient i) => DsTooltipCard(
        title: i.name,
        detail: i.detail,
        children: [
          Text(
              invStrings(context).t('ui.town.source.have_need',
                  {'have': i.have, 'need': i.need}),
              style: DsText.body(
                  i.have >= i.need ? DsColors.success : DsColors.danger)),
          for (final l in i.sources) Text(l, style: DsText.body()),
        ],
      );

  LifeItemDetail _info(BuildContext context, String id) {
    final s = invStrings(context);
    final d = kLifeMaterials[id]!;
    return LifeItemDetail(
      name: d.text,
      nameColor: DsColors.textPrimary,
      itemId: id,
      tags: [
        (
          s.t('ui.inventory.workshop.tier', {'n': d.tier}),
          DsColors.textSecondary
        ),
        if (kWorkshopOficio[id] case final o?)
          (
            s.t(o == 'pesca'
                ? 'ui.inventory.workshop.filter.fishing'
                : 'ui.inventory.workshop.filter.farming'),
            DsColors.textSecondary
          ),
      ],
      lines: [
        s.t('ui.inventory.workshop.have',
            {'n': p.life.craft(id), 'max': LifeCraftRules.maxTimes(p, id)}),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tag = _tags[_filter];
    final ids = [
      for (final id in kLifeMaterialIds)
        if (tag == null || kWorkshopOficio[id] == tag) id
    ];
    final sel = ids.contains(_sel) ? _sel : ids.firstOrNull;
    final s = invStrings(context);
    final filters =
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
      for (var i = 0; i < _tags.length; i++)
        DsButton(
            s.t(switch (i) {
              0 => 'ui.inventory.workshop.filter.all',
              1 => 'ui.inventory.workshop.filter.farming',
              _ => 'ui.inventory.workshop.filter.fishing',
            }),
            key: ValueKey('workshop-filter-$i'),
            size: DsButtonSize.compact,
            selected: _filter == i,
            onPressed: () => setState(() => _filter = i)),
    ]);
    final grid = Wrap(
      spacing: LifeItemGrid.gap,
      runSpacing: LifeItemGrid.gap,
      children: [
        for (final id in ids)
          KeyedSubtree(
            key: ValueKey('workshop-cell-$id'),
            child: LifeItemCell(
              data: LifeItemCellData(
                id: 'workshop-item-$id',
                icon: _icon(id, LifeItemGrid.iconSize),
                border: DsColors.border,
                search: kLifeMaterials[id]!.text,
                count: p.life.craft(id),
                detail: _info(context, id),
              ),
              selected: id == sel,
              onTap: () => setState(() {
                _sel = id;
                _qty = 1;
              }),
            ),
          ),
      ],
    );
    return LayoutBuilder(builder: (context, box) {
      final left = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [filters, SizedBox(height: DsSpace.sm), grid],
      );
      final detail = sel == null
          ? null
          : KeyedSubtree(
              key: const ValueKey('workshop-detail'),
              child: _detail(context, sel));
      if (box.maxWidth >= 560 && box.hasBoundedHeight) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: WorkshopGrid.gridWidth,
              child: SingleChildScrollView(child: left)),
          SizedBox(width: DsSpace.sm),
          if (detail != null) Expanded(child: detail),
        ]);
      }
      return SingleChildScrollView(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              left,
              SizedBox(height: DsSpace.sm),
              if (detail != null) SizedBox(height: 460, child: detail),
            ]),
      );
    });
  }

  Widget _detail(BuildContext context, String id) {
    final s = invStrings(context);
    final d = kLifeMaterials[id]!;
    final max = LifeCraftRules.maxTimes(p, id);
    final inWorld = widget.shop.view.session.run == null;
    final n = _qty.clamp(1, LifeCraftRules.maxStack);
    final a = CraftAction(CraftOp.condense, '${LifeCraftRules.prefix}$id',
        index: n);
    final why = !inWorld
        ? s.t('ui.inventory.workshop.world_only')
        : max < n
            ? s.t('ui.inventory.workshop.not_enough')
            : widget.shop.guards.craft(p, a);
    final ings = _ingredients(context, id, n);
    final info = _info(context, id);
    Widget qtyButton(String label, String key, int? to) => DsButton(label,
        key: ValueKey('workshop-qty-$key'),
        size: DsButtonSize.compact,
        selected: key != 'minus' && key != 'plus' && to == n,
        onPressed:
            to == null || to < 1 ? null : () => setState(() => _qty = to));
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DsTooltip(
            card: lifeTooltipCard(context, info),
            child: Container(
              key: const ValueKey('workshop-result'),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: DsColors.surfaceSunken,
                  border: Border.all(color: DsColors.border, width: 2)),
              child: Center(child: _icon(id, 64)),
            ),
          ),
          SizedBox(width: DsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.text,
                    key: const ValueKey('workshop-detail-name'),
                    style: DsText.subtitle(DsColors.textTitle)),
                SizedBox(height: DsSpace.xs),
                Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
                  for (final (t, c) in info.tags) DsTag(t, color: c),
                ]),
                SizedBox(height: DsSpace.xs),
                for (final l in lifeDetailLines(context, info))
                  Text(l, style: DsText.body()),
              ],
            ),
          ),
        ]),
        SizedBox(height: DsSpace.xs),
        Text(d.descriptionText, style: DsText.detail()),
        SizedBox(height: DsSpace.sm),
        Text(s.t('ui.inventory.workshop.ingredients'),
            style: DsText.subtitle(DsColors.textSecondary)),
        SizedBox(height: DsSpace.xs),
        DsCostGrid(key: const ValueKey('workshop-cost'), [
          for (final i in ings)
            DsCostEntry(
                id: i.id,
                icon: i.icon,
                need: i.need,
                have: i.have,
                card: _card(context, i)),
        ]),
        SizedBox(height: DsSpace.sm),
        Text(s.t('ui.inventory.workshop.result', {'n': n, 'item': d.text}),
            key: const ValueKey('workshop-result-text'),
            style: DsText.body(DsColors.textPrimary)),
      ],
    );
    final actions = Wrap(
      spacing: DsSpace.xs,
      runSpacing: DsSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(s.t('ui.inventory.workshop.qty', {'n': n}),
            key: const ValueKey('workshop-qty'), style: DsText.body()),
        qtyButton('−', 'minus', n > 1 ? n - 1 : null),
        qtyButton('+', 'plus', n < LifeCraftRules.maxStack ? n + 1 : null),
        qtyButton('×1', '1', 1),
        qtyButton('×5', '5', 5),
        qtyButton(s.t('ui.inventory.workshop.max'), 'max', max),
        DsButton(s.t('ui.inventory.workshop.craft'),
            key: const ValueKey('workshop-craft'),
            kind: DsButtonKind.primary,
            tooltip: why,
            onPressed: why == null
                ? () {
                    widget.shop.controller.craft(a);
                    setState(() => _qty = 1);
                  }
                : null),
      ],
    );
    return DsDetailPane(body: body, actions: actions);
  }
}
