import 'package:material_ui/material_ui.dart';
import '../../../inventory/domain/item_names.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../../game_engine/models/life_skills.dart' show kLifeMaterialIds;
import '../../../../game_engine/rules/life_craft_rules.dart';
import '../../../../game_engine/rules/life_time_rules.dart';
import '../../../../game_engine/rules/oficio_storage_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import 'life_tool_text.dart';
import '../session_controller.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';
import '../world_strings.dart';

/// OFICIOS → INVENTARIO de PERSONAJE (docs/specs/oficio_storage.md,
/// farming.md § 11, fishing.md § 5.1): una bolsa por oficio (PESCA,
/// CULTIVO, HERRERÍA) con su tope de casillas, filtros por tipo, un
/// buscador y la grilla con el detalle a la derecha ([LifeItemGrid]).
/// Nunca ocupan casilleros de EQUIPAMIENTO. Solo en el pueblo.
class LifeItemsView extends StatefulWidget {
  const LifeItemsView(
      {super.key,
      required this.profile,
      required this.controller,
      required this.inTown});

  final PlayerProfile profile;
  final SessionController controller;
  final bool inTown;

  @override
  State<LifeItemsView> createState() => _LifeItemsViewState();
}

/// Tipos de celda con que se arma cada bolsa.
enum LifeItemsCategory {
  herramientas,
  pescados,
  semillas,
  cosechas,
  bestiario,
  materiales
}

/// Filtros de cada bolsa: (id, clave del rótulo, prefijos de id de celda).
const _filters = <OficioBag, List<(String, String, List<String>)>>{
  OficioBag.pesca: [
    ('todo', 'ui.town.bag.filter.all', ['life-tool-cana', 'life-fish-', 'life-junk-']),
    ('canas', 'ui.town.bag.filter.rods', ['life-tool-cana']),
    ('pescados', 'ui.town.bag.filter.fish', ['life-fish-']),
    ('basura', 'ui.town.bag.filter.junk', ['life-junk-']),
    ('bestiario', 'ui.town.bag.filter.log', ['life-log-']),
  ],
  OficioBag.cultivo: [
    ('todo', 'ui.town.bag.filter.all', ['life-tool-a', 'life-tool-r', 'life-seed-', 'life-fert-', 'life-crop-']),
    ('herramientas', 'ui.town.bag.filter.tools', ['life-tool-a', 'life-tool-r']),
    ('semillas', 'ui.town.bag.filter.seeds', ['life-seed-']),
    ('abonos', 'ui.town.bag.filter.ferts', ['life-fert-']),
    ('cosechas', 'ui.town.bag.filter.crops', ['life-crop-']),
  ],
  OficioBag.herreria: [
    ('todo', 'ui.town.bag.filter.all', ['life-craft-']),
  ],
};

/// Calidad de cosecha → color de rareza.
Color cropQualityColor(CropQuality q) => fishRarityColor(switch (q) {
      CropQuality.normal => FishRarity.comun,
      CropQuality.raro => FishRarity.raro,
      CropQuality.epico => FishRarity.epico,
      CropQuality.legendario => FishRarity.legendario,
    });

class _LifeItemsViewState extends State<LifeItemsView> {
  var _bag = OficioBag.pesca;
  final _filter = <OficioBag, String>{};
  var _query = '';

  /// Bioma del BESTIARIO DE PESCA (fishing.md § 10).
  String _logBiome = 'zona1';

  /// Franja del BESTIARIO (`null` = todas; las sin descubrir no se
  /// filtran por hora: su horario es "???").
  DayTime? _logTime;

  String _biomeLabel(String id) => id == 'zona1'
      ? context.t('ui.town.bag.town')
      : kBiomes.where((b) => b.id == id).firstOrNull?.name ?? id.toUpperCase();

  static List<String> get _logBiomes => {
        for (final d in kFish.values)
          if (d.biome != kWaterJunkBiome) d.biome
      }.toList();

  @override
  Widget build(BuildContext context) {
    if (!widget.inTown) {
      return Center(
        child: Text(context.t('ui.town.bag.in_town_only'),
            key: const ValueKey('life-items-away'), style: DsText.detail()),
      );
    }
    final all = [
      for (final c in LifeItemsCategory.values) ..._cells(c),
    ];
    final filters = _filters[_bag]!;
    final fid = _filter[_bag] ?? 'todo';
    final f =
        filters.firstWhere((e) => e.$1 == fid, orElse: () => filters.first);
    final log = f.$1 == 'bestiario';
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final c in all)
        if (f.$3.any(c.id.startsWith) &&
            (q.isEmpty || c.search.toLowerCase().contains(q)) &&
            (!log ||
                (c.id.startsWith('life-log-$_logBiome-') &&
                    (_logTime == null || _logTimeOf(c.id) == _logTime))))
          c
    ];
    final p = widget.profile;
    return Column(
      key: const ValueKey('life-items'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: DsTabBar(
              tabs: [
                for (final b in OficioBag.values)
                  DsTab(b.label,
                      badge: '${OficioStorageRules.used(p, b)}/'
                          '${OficioStorageRules.cap}',
                      key: ValueKey('oficio-bag-${b.name}')),
              ],
              index: _bag.index,
              onChanged: (i) => setState(() => _bag = OficioBag.values[i]),
            ),
          ),
          SizedBox(width: DsSpace.sm),
          DsSearchField(
              key: const ValueKey('life-search'),
              width: 180,
              onChanged: (v) => setState(() => _query = v)),
        ]),
        if (filters.length > 1) ...[
          SizedBox(height: DsSpace.xs),
          Wrap(spacing: DsSpace.xs, children: [
            for (final e in filters)
              DsButton(context.t(e.$2),
                  key: ValueKey('oficio-filter-${e.$1}'),
                  size: DsButtonSize.compact,
                  selected: f.$1 == e.$1,
                  onPressed: () => setState(() => _filter[_bag] = e.$1)),
          ]),
        ],
        if (log) ...[
          SizedBox(height: DsSpace.xs),
          Wrap(spacing: DsSpace.xs, children: [
            for (final b in _logBiomes)
              DsButton('${_biomeLabel(b)} ${_logFound(b)}/${_logTotal(b)}',
                  key: ValueKey('life-log-biome-$b'),
                  size: DsButtonSize.compact,
                  selected: _logBiome == b,
                  onPressed: () => setState(() => _logBiome = b)),
          ]),
          SizedBox(height: DsSpace.xs),
          Wrap(spacing: DsSpace.xs, children: [
            for (final t in [null, ...DayTime.values])
              DsButton((t?.label ?? context.t('ui.town.bag.all_hours')).toUpperCase(),
                  key: ValueKey('life-log-time-${t?.name ?? 'todas'}'),
                  size: DsButtonSize.compact,
                  selected: _logTime == t,
                  onPressed: () => setState(() => _logTime = t)),
          ]),
        ],
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: LifeItemGrid(
            key: ValueKey('life-list-${_bag.name}-${f.$1}'),
            groups: [LifeItemGroup(null, shown)],
            empty: q.isEmpty ? context.t('ui.town.bag.empty') : context.t('ui.town.bag.no_results'),
            emptyKey: const ValueKey('life-items-empty'),
          ),
        ),
      ],
    );
  }

  static const _icon = LifeItemGrid.iconSize;

  DayTime? _logTimeOf(String cellId) {
    final id = cellId.split('-').last;
    if (!widget.profile.life.discovered(id)) return null;
    return LifeTimeRules.fishTime(id);
  }

  int _logTotal(String b) =>
      kFish.values.where((d) => d.biome == b).length;
  int _logFound(String b) => kFish.values
      .where((d) => d.biome == b && widget.profile.life.discovered(d.id))
      .length;

  List<LifeItemCellData> _cells(LifeItemsCategory cat) {
    final c = widget.controller;
    final life = widget.profile.life;
    final f = life.farm;
    switch (cat) {
      case LifeItemsCategory.herramientas:
        final fishLv = FishingRules.level(widget.profile);
        final farmLv = FarmingRules.level(widget.profile);
        LifeItemCellData tool(String id, String name, FishRarity r, String kind,
                int reqLevel, bool equipped, VoidCallback onEquip,
                List<String> lines, List<(String, bool)> cmp) =>
            LifeItemCellData(
              id: 'life-tool-$id',
              icon: LifeIcon(id, LifeIconKind.herramienta, size: _icon),
              border: fishRarityColor(r),
              search: '$name $kind',
              equipped: equipped,
              caption: context.t('ui.town.bag.req_level', {'n': reqLevel}),
              detail: LifeItemDetail(
                name: name,
                nameColor: fishRarityColor(r),
                tags: [
                  (kind.toUpperCase(), DsColors.textSecondary),
                  (r.label.toUpperCase(), fishRarityColor(r)),
                ],
                lines: lines,
                compare: cmp,
                hoverTip: true,
                actions: [
                  equipped
                      ? DsTag(context.t('ui.town.trader.equipped'), color: DsColors.reward)
                      : DsButton(context.t('ui.town.trader.equip'),
                          key: ValueKey('life-tool-eq-$id'),
                          size: DsButtonSize.compact,
                          onPressed: onEquip),
                ],
              ),
            );
        return [
          for (final id in life.rods)
            if (kRods[id] case final r?)
              tool(id, r.text, r.rarity, context.t('ui.town.bag.rod'), r.reqLevel, life.rod == id,
                  () => c.equipRod(id), rodLines(r, fishLv),
                  rodCompare(r, kRods[life.rod] ?? kRods[kStarterRod]!, fishLv)),
          for (final id in [...f.hoes, ...f.cans])
            if (kFarmTools[id] case final d?)
              tool(id, d.text, d.rarity, d.kind.label, d.reqLevel,
                  f.hoe == id || f.can == id, () => c.equipFarmTool(id),
                  farmToolLines(d, farmLv),
                  farmToolCompare(
                      d,
                      d.kind == FarmToolKind.azada
                          ? FarmingRules.hoeOf(widget.profile)
                          : FarmingRules.canOf(widget.profile),
                      farmLv)),
        ];
      case LifeItemsCategory.pescados:
        final lake = TownRules.lakeNear(c.town, c.local.x, c.local.y);
        final lakeFull =
            lake == null || lake.stockTotal >= TownRules.lakeCapacity(lake);
        return [
          for (final d in kFish.values)
            if (life.count(d.id) > 0 && d.biome != kWaterJunkBiome)
              LifeItemCellData(
                id: 'life-fish-${d.id}',
                icon: LifeIcon(d.id, LifeIconKind.pescado, size: _icon),
                border: fishRarityColor(d.rarity),
                search: '${d.text} ${d.name}',
                count: life.count(d.id),
                caption: context.t('ui.town.trader.price_short', {'n': d.price}),
                detail: LifeItemDetail(
                  name: d.text,
                  nameColor: fishRarityColor(d.rarity),
                  tags: [
                    (context.t('ui.town.trader.tag_fish'), DsColors.textSecondary),
                    (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
                  ],
                  lines: [
                    context.t('ui.town.trader.have', {'n': life.count(d.id)}),
                    context.t('ui.town.trader.worth_each', {'n': d.price}),
                  ],
                  actions: [
                    DsButton(context.t('ui.town.bag.release'),
                        key: ValueKey('life-fish-stock-${d.id}'),
                        size: DsButtonSize.compact,
                        tooltip: lake == null
                            ? context.t('ui.town.bag.go_to_lake')
                            : (lakeFull ? context.t('ui.town.edit.lake_full') : null),
                        onPressed:
                            lakeFull ? null : () => c.stockFish(d.id, lake.id)),
                    // Con varios lagos: elegir en cuál.
                    if (c.town.lakes.length > 1)
                      for (final (i, l) in c.town.lakes.indexed)
                        if (l.id != lake?.id)
                          DsButton(context.t('ui.town.bag.lake_n', {'n': i + 1}),
                              key: ValueKey('life-fish-stock-${d.id}-${l.id}'),
                              size: DsButtonSize.compact,
                              tooltip: l.stockTotal >= TownRules.lakeCapacity(l)
                                  ? context.t('ui.town.edit.lake_full')
                                  : context.t('ui.town.bag.released', {'n': l.stockTotal, 'max': TownRules.lakeCapacity(l)}),
                              onPressed: l.stockTotal >= TownRules.lakeCapacity(l)
                                  ? null
                                  : () => c.stockFish(d.id, l.id)),
                  ],
                ),
              ),
          for (final d in kFish.values)
            if (life.count(d.id) > 0 && d.biome == kWaterJunkBiome)
              LifeItemCellData(
                id: 'life-junk-${d.id}',
                icon: LifeIcon(d.id, LifeIconKind.basura, size: _icon),
                border: DsColors.textSecondary,
                search: '${d.text} ${d.name}',
                count: life.count(d.id),
                caption: context.t('ui.town.trader.price_short', {'n': d.price}),
                detail: LifeItemDetail(
                  name: d.text,
                  nameColor: DsColors.text,
                  tags: [(context.t('ui.town.trader.tag_junk'), DsColors.textSecondary)],
                  lines: [
                    context.t('ui.town.trader.have', {'n': life.count(d.id)}),
                    context.t('ui.town.trader.worth_each', {'n': d.price}),
                  ],
                ),
              ),
        ];
      case LifeItemsCategory.bestiario:
        return [
          for (final d in kFish.values)
            if (d.biome != kWaterJunkBiome)
              if (life.log[d.id] case final rec?)
                LifeItemCellData(
                  id: 'life-log-${d.biome}-${d.id}',
                  icon: LifeIcon(d.id, LifeIconKind.pescado, size: _icon),
                  border: fishRarityColor(d.rarity),
                  search: '${d.text} ${d.name}',
                  caption: context.t('ui.town.bag.cm', {'n': rec}),
                  detail: LifeItemDetail(
                    name: d.text,
                    nameColor: fishRarityColor(d.rarity),
                    tags: [
                      (_biomeLabel(d.biome), DsColors.textSecondary),
                      (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
                    ],
                    lines: [
                      context.t('ui.town.bag.record', {'n': rec}),
                      context.t('ui.town.bag.size', {'min': d.minCm, 'max': d.maxCm}),
                      context.t('ui.town.bag.bites', {'time': LifeTimeRules.fishTimeText(d.id)}),
                      context.t('ui.town.bag.worth', {'n': d.price}),
                    ],
                  ),
                )
              else
                LifeItemCellData(
                  id: 'life-log-${d.biome}-${d.id}',
                  icon: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                        DsColors.textSecondary, BlendMode.srcIn),
                    child: LifeIcon(d.id, LifeIconKind.pescado, size: _icon),
                  ),
                  border: DsColors.textSecondary,
                  search: '',
                  caption: '?',
                  detail: LifeItemDetail(
                    name: context.t('ui.town.bag.undiscovered'),
                    nameColor: DsColors.textSecondary,
                    tags: [(_biomeLabel(d.biome), DsColors.textSecondary)],
                    lines: [
                      context.t('ui.town.bag.size', {'min': d.minCm, 'max': d.maxCm}),
                      context.t('ui.town.bag.bites', {'time': '???'}),
                      context.t('ui.town.bag.catch_in', {'place': _biomeLabel(d.biome).toLowerCase()}),
                      context.t('ui.town.bag.first_catch'),
                    ],
                  ),
                ),
        ];
      case LifeItemsCategory.semillas:
        return [
          for (final e in f.seeds.entries)
            if (kCrops[e.key] case final d?)
              LifeItemCellData(
                id: 'life-seed-${d.id}',
                icon: LifeIcon('semilla_${d.id}', LifeIconKind.semilla,
                    size: _icon),
                border: fishRarityColor(d.rarity),
                search: '${d.seedText} ${d.seedName}',
                count: e.value,
                equipped: f.activeSeed == d.id,
                caption: context.t('ui.town.npc.minutes', {'n': (d.growSec / 60).round()}),
                detail: LifeItemDetail(
                  name: d.seedText,
                  nameColor: fishRarityColor(d.rarity),
                  tags: [
                    (context.t('ui.town.trader.tag_seed'), DsColors.textSecondary),
                    (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
                  ],
                  lines: [
                    context.t('ui.town.trader.have', {'n': e.value}),
                    context.t('ui.town.trader.grows_in', {'min': (d.growSec / 60).round()}),
                    context.t('ui.town.bag.origin', {'place': _biomeLabel(d.biome).toLowerCase()}),
                    LifeTimeRules.cropAffinity(d.id).label,
                    context.t('ui.town.bag.yields', {'n': d.price}),
                  ],
                  actions: [
                    f.activeSeed == d.id
                        ? DsTag(context.t('ui.town.bag.to_plant'), color: DsColors.reward)
                        : DsButton(context.t('ui.town.bag.pick'),
                            key: ValueKey('life-seed-pick-${d.id}'),
                            size: DsButtonSize.compact,
                            onPressed: () => c.selectSeed(d.id)),
                  ],
                ),
              ),
          for (final e in f.ferts.entries)
            if (kFertilizers[e.key] case final d?)
              LifeItemCellData(
                id: 'life-fert-${d.id}',
                icon: LifeIcon(d.id, LifeIconKind.semilla, size: _icon),
                border: fishRarityColor(d.rarity),
                search: '${d.text} ${d.name}',
                count: e.value,
                detail: LifeItemDetail(
                  name: d.text,
                  nameColor: fishRarityColor(d.rarity),
                  tags: [(context.t('ui.town.trader.tag_fert'), DsColors.textSecondary)],
                  lines: [context.t('ui.town.trader.have', {'n': e.value})],
                  description: context.t('ui.town.bag.fert_desc'),
                ),
              ),
        ];
      case LifeItemsCategory.materiales:
        return [
          for (final id in kLifeMaterialIds)
            if (life.craft(id) > 0)
              if (kLifeMaterials[id] case final d?)
                LifeItemCellData(
                  id: 'life-craft-$id',
                  icon: LifeIcon(
                      'mat_$id',
                      switch (id) {
                        'cebo' => LifeIconKind.pescado,
                        'fibra' => LifeIconKind.cosecha,
                        _ => LifeIconKind.herramienta,
                      },
                      size: _icon),
                  border: DsColors.border,
                  search: '${d.text} ${d.name}',
                  count: life.craft(id),
                  detail: LifeItemDetail(
                    name: d.text,
                    nameColor: DsColors.textTitle,
                    tags: [
                      (context.t('ui.town.bag.tag_material'), DsColors.textSecondary)
                    ],
                    lines: [context.t('ui.town.trader.have', {'n': life.craft(id)})],
                    description: d.description,
                  ),
                ),
        ];
      case LifeItemsCategory.cosechas:
        return [
          for (final e in f.crops.entries)
            if (parseCropKey(e.key) case (final d, final q)?)
              LifeItemCellData(
                id: 'life-crop-${d.id}-${q.index}',
                icon: LifeIcon('cosecha_${d.id}', LifeIconKind.cosecha,
                    size: _icon),
                border: cropQualityColor(q),
                search: '${d.text} ${d.name} ${q.label}',
                count: e.value,
                caption: context.t('ui.town.trader.price_short', {'n': d.price}),
                detail: LifeItemDetail(
                  name: d.text,
                  nameColor: cropQualityColor(q),
                  tags: [
                    (context.t('ui.town.trader.tag_crop'), DsColors.textSecondary),
                    (q.label.toUpperCase(), cropQualityColor(q)),
                  ],
                  lines: [
                    context.t('ui.town.trader.have', {'n': e.value}),
                    context.t('ui.town.bag.quality', {'q': q.label}),
                    context.t('ui.town.trader.worth_each', {'n': d.price}),
                  ],
                ),
              ),
        ];
    }
  }
}
