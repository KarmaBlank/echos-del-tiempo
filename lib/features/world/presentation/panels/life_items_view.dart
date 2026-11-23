import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import 'life_tool_text.dart';
import '../session_controller.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Pestaña PESCA Y CULTIVO de PERSONAJE (farming.md § 11, fishing.md
/// § 5.1): herramientas de oficio, pescados, basura del agua, semillas,
/// abonos y cosechas. Nunca ocupan casilleros del inventario. Solo en el
/// pueblo (en una misión se ve el aviso). Desde v0.24.2 una categoría
/// por vez (pestañas con la cantidad) y un buscador, en vez de secciones
/// apiladas; cada fila con su ícono. Desde v0.24.4 una grilla de casillas con el
/// detalle de la elegida a la derecha ([LifeItemGrid]).
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

/// Categorías de la pestaña, en orden.
enum LifeItemsCategory {
  herramientas('HERRAMIENTAS'),
  pescados('PESCADOS'),
  semillas('SEMILLAS'),
  cosechas('COSECHAS');

  const LifeItemsCategory(this.label);
  final String label;
}

/// Calidad de cosecha → color de rareza.
Color cropQualityColor(CropQuality q) => fishRarityColor(switch (q) {
      CropQuality.normal => FishRarity.comun,
      CropQuality.raro => FishRarity.raro,
      CropQuality.epico => FishRarity.epico,
      CropQuality.legendario => FishRarity.legendario,
    });

class _LifeItemsViewState extends State<LifeItemsView> {
  var _cat = LifeItemsCategory.herramientas;
  var _query = '';

  /// Sub-filtro de HERRAMIENTAS: `null` todas, `pesca` o `cultivo`.
  String? _toolKind;

  @override
  Widget build(BuildContext context) {
    if (!widget.inTown) {
      return Center(
        child: Text('Disponible en el pueblo.',
            key: const ValueKey('life-items-away'), style: DsText.detail()),
      );
    }
    final cells = {
      for (final c in LifeItemsCategory.values) c: _cells(c),
    };
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final c in cells[_cat]!)
        if ((q.isEmpty || c.search.toLowerCase().contains(q)) &&
            (_cat != LifeItemsCategory.herramientas ||
                _toolKind == null ||
                c.id.startsWith('life-tool-cana') == (_toolKind == 'pesca')))
          c
    ];
    return Column(
      key: const ValueKey('life-items'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: DsTabBar(
              tabs: [
                for (final c in LifeItemsCategory.values)
                  DsTab(c.label,
                      badge: '${cells[c]!.length}',
                      key: ValueKey('life-cat-${c.name}')),
              ],
              index: _cat.index,
              onChanged: (i) =>
                  setState(() => _cat = LifeItemsCategory.values[i]),
            ),
          ),
          SizedBox(width: DsSpace.sm),
          DsSearchField(
              key: const ValueKey('life-search'),
              width: 180,
              onChanged: (v) => setState(() => _query = v)),
        ]),
        if (_cat == LifeItemsCategory.herramientas) ...[
          SizedBox(height: DsSpace.xs),
          Wrap(spacing: DsSpace.xs, children: [
            for (final k in const [null, 'pesca', 'cultivo'])
              DsButton((k ?? 'todas').toUpperCase(),
                  key: ValueKey('life-tool-filter-${k ?? 'todas'}'),
                  size: DsButtonSize.compact,
                  selected: _toolKind == k,
                  onPressed: () => setState(() => _toolKind = k)),
          ]),
        ],
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: LifeItemGrid(
            key: ValueKey('life-list-${_cat.name}'),
            groups: [LifeItemGroup(null, shown)],
            empty: q.isEmpty ? 'No hay nada acá.' : 'Sin resultados.',
            emptyKey: const ValueKey('life-items-empty'),
          ),
        ),
      ],
    );
  }

  static const _icon = LifeItemGrid.iconSize;

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
              caption: 'Nv $reqLevel',
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
                      ? const DsTag('EQUIPADA', color: DsColors.reward)
                      : DsButton('EQUIPAR',
                          key: ValueKey('life-tool-eq-$id'),
                          size: DsButtonSize.compact,
                          onPressed: onEquip),
                ],
              ),
            );
        return [
          for (final id in life.rods)
            if (kRods[id] case final r?)
              tool(id, r.name, r.rarity, 'Caña', r.reqLevel, life.rod == id,
                  () => c.equipRod(id), rodLines(r, fishLv),
                  rodCompare(r, kRods[life.rod] ?? kRods[kStarterRod]!, fishLv)),
          for (final id in [...f.hoes, ...f.cans])
            if (kFarmTools[id] case final d?)
              tool(id, d.name, d.rarity, d.kind.label, d.reqLevel,
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
                search: d.name,
                count: life.count(d.id),
                caption: '${d.price} oro',
                detail: LifeItemDetail(
                  name: d.name,
                  nameColor: fishRarityColor(d.rarity),
                  tags: [
                    ('PESCADO', DsColors.textSecondary),
                    (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
                  ],
                  lines: [
                    'Tenés ${life.count(d.id)}',
                    'Vale ${d.price} de oro c/u',
                  ],
                  actions: [
                    DsButton('SOLTAR EN EL LAGO',
                        key: ValueKey('life-fish-stock-${d.id}'),
                        size: DsButtonSize.compact,
                        tooltip: lake == null
                            ? 'Acercate a un lago'
                            : (lakeFull ? 'El lago está lleno' : null),
                        onPressed:
                            lakeFull ? null : () => c.stockFish(d.id, lake.id)),
                    // Con varios lagos: elegir en cuál.
                    if (c.town.lakes.length > 1)
                      for (final (i, l) in c.town.lakes.indexed)
                        if (l.id != lake?.id)
                          DsButton('LAGO ${i + 1}',
                              key: ValueKey('life-fish-stock-${d.id}-${l.id}'),
                              size: DsButtonSize.compact,
                              tooltip: l.stockTotal >= TownRules.lakeCapacity(l)
                                  ? 'El lago está lleno'
                                  : '${l.stockTotal}/${TownRules.lakeCapacity(l)} soltados',
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
                search: d.name,
                count: life.count(d.id),
                caption: '${d.price} oro',
                detail: LifeItemDetail(
                  name: d.name,
                  nameColor: DsColors.text,
                  tags: const [('BASURA DEL AGUA', DsColors.textSecondary)],
                  lines: [
                    'Tenés ${life.count(d.id)}',
                    'Vale ${d.price} de oro c/u',
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
                search: d.seedName,
                count: e.value,
                equipped: f.activeSeed == d.id,
                caption: '${(d.growSec / 60).round()} min',
                detail: LifeItemDetail(
                  name: d.seedName,
                  nameColor: fishRarityColor(d.rarity),
                  tags: [
                    ('SEMILLA', DsColors.textSecondary),
                    (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
                  ],
                  lines: [
                    'Tenés ${e.value}',
                    'Crece en ${(d.growSec / 60).round()} min',
                  ],
                  actions: [
                    f.activeSeed == d.id
                        ? const DsTag('PARA PLANTAR', color: DsColors.reward)
                        : DsButton('ELEGIR',
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
                search: d.name,
                count: e.value,
                detail: LifeItemDetail(
                  name: d.name,
                  nameColor: fishRarityColor(d.rarity),
                  tags: const [('ABONO', DsColors.textSecondary)],
                  lines: ['Tenés ${e.value}'],
                  description: 'Mejora la calidad de la cosecha. Se usa con F '
                      'sobre un cultivo.',
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
                search: '${d.name} ${q.label}',
                count: e.value,
                caption: '${d.price} oro',
                detail: LifeItemDetail(
                  name: d.name,
                  nameColor: cropQualityColor(q),
                  tags: [
                    ('COSECHA', DsColors.textSecondary),
                    (q.label.toUpperCase(), cropQualityColor(q)),
                  ],
                  lines: [
                    'Tenés ${e.value}',
                    'Calidad ${q.label}',
                    'Vale ${d.price} de oro c/u',
                  ],
                ),
              ),
        ];
    }
  }
}
