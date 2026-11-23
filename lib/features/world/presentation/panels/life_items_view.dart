import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';

/// Pestaña PESCA Y CULTIVO de PERSONAJE (farming.md § 11, fishing.md
/// § 5.1): herramientas de oficio, pescados, basura del agua, semillas,
/// abonos y cosechas. Nunca ocupan casilleros del inventario. Solo en el
/// pueblo (en una misión se ve el aviso). Desde v0.24.2 una categoría
/// por vez (pestañas con la cantidad) y un buscador, en vez de secciones
/// apiladas; cada fila con su ícono.
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

class _Row {
  const _Row(this.search, this.widget);
  final String search;
  final Widget widget;
}

class _LifeItemsViewState extends State<LifeItemsView> {
  var _cat = LifeItemsCategory.herramientas;
  var _query = '';

  @override
  Widget build(BuildContext context) {
    if (!widget.inTown) {
      return Center(
        child: Text('Disponible en el pueblo.',
            key: const ValueKey('life-items-away'), style: DsText.detail()),
      );
    }
    final rows = {
      for (final c in LifeItemsCategory.values) c: _rows(c),
    };
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final r in rows[_cat]!)
        if (q.isEmpty || r.search.toLowerCase().contains(q)) r.widget
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
                      badge: '${rows[c]!.length}',
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
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: shown.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(DsSpace.sm),
                  child: Text(
                      q.isEmpty ? 'No hay nada acá.' : 'Sin resultados.',
                      key: const ValueKey('life-items-empty'),
                      style: DsText.detail()))
              : ListView(
                  key: ValueKey('life-list-${_cat.name}'), children: shown),
        ),
      ],
    );
  }

  /// A la derecha: un tag (tipo, rareza, calidad) y la acción.
  static Widget _trail(List<Widget> parts) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) SizedBox(width: DsSpace.xs),
          parts[i],
        ]
      ]);

  List<_Row> _rows(LifeItemsCategory cat) {
    final c = widget.controller;
    final life = widget.profile.life;
    final f = life.farm;
    switch (cat) {
      case LifeItemsCategory.herramientas:
        _Row tool(String id, String name, FishRarity r, String kind,
                bool equipped, VoidCallback onEquip) =>
            _Row(
                '$name $kind',
                DsListRow(
                  key: ValueKey('life-tool-$id'),
                  compact: true,
                  leading: LifeIcon(id, LifeIconKind.herramienta),
                  title: name,
                  titleColor: fishRarityColor(r),
                  detail: r.label,
                  trailing: _trail([
                    DsTag(kind.toUpperCase(), color: DsColors.textSecondary),
                    equipped
                        ? const DsTag('EQUIPADA', color: DsColors.reward)
                        : DsButton('EQUIPAR',
                            key: ValueKey('life-tool-eq-$id'),
                            size: DsButtonSize.compact,
                            onPressed: onEquip),
                  ]),
                ));
        return [
          for (final id in life.rods)
            if (kRods[id] case final r?)
              tool(id, r.name, r.rarity, 'Caña', life.rod == id,
                  () => c.equipRod(id)),
          for (final id in [...f.hoes, ...f.cans])
            if (kFarmTools[id] case final d?)
              tool(id, d.name, d.rarity, d.kind.label,
                  f.hoe == id || f.can == id, () => c.equipFarmTool(id)),
        ];
      case LifeItemsCategory.pescados:
        final lake = TownRules.lakeNear(c.town, c.local.x, c.local.y);
        final lakeFull =
            lake == null || lake.stockTotal >= TownRules.lakeCapacity(lake);
        return [
          for (final d in kFish.values)
            if (life.count(d.id) > 0 && d.biome != kWaterJunkBiome)
              _Row(
                  d.name,
                  DsListRow(
                    key: ValueKey('life-fish-${d.id}'),
                    compact: true,
                    leading: LifeIcon(d.id, LifeIconKind.pescado),
                    title: '${d.name} ×${life.count(d.id)}',
                    titleColor: fishRarityColor(d.rarity),
                    detail: '${d.price} de oro',
                    trailing: _trail([
                      DsTag(d.rarity.label.toUpperCase(),
                          color: fishRarityColor(d.rarity)),
                      DsButton('SOLTAR EN EL LAGO',
                          key: ValueKey('life-fish-stock-${d.id}'),
                          size: DsButtonSize.compact,
                          tooltip: lake == null
                              ? 'Acercate a un lago'
                              : (lakeFull ? 'El lago está lleno' : null),
                          onPressed: lakeFull
                              ? null
                              : () => c.stockFish(d.id, lake.id)),
                    ]),
                  )),
          for (final d in kFish.values)
            if (life.count(d.id) > 0 && d.biome == kWaterJunkBiome)
              _Row(
                  d.name,
                  DsListRow(
                    key: ValueKey('life-junk-${d.id}'),
                    compact: true,
                    leading: LifeIcon(d.id, LifeIconKind.basura),
                    title: '${d.name} ×${life.count(d.id)}',
                    detail: '${d.price} de oro',
                    trailing: const DsTag('BASURA DEL AGUA',
                        color: DsColors.textSecondary),
                  )),
        ];
      case LifeItemsCategory.semillas:
        return [
          for (final e in f.seeds.entries)
            if (kCrops[e.key] case final d?)
              _Row(
                  d.seedName,
                  DsListRow(
                    key: ValueKey('life-seed-${d.id}'),
                    compact: true,
                    leading: LifeIcon('semilla_${d.id}', LifeIconKind.semilla),
                    title: '${d.seedName} ×${e.value}',
                    titleColor: fishRarityColor(d.rarity),
                    detail: 'Crece en ${(d.growSec / 60).round()} min',
                    trailing: f.activeSeed == d.id
                        ? const DsTag('PARA PLANTAR', color: DsColors.reward)
                        : DsButton('ELEGIR',
                            key: ValueKey('life-seed-pick-${d.id}'),
                            size: DsButtonSize.compact,
                            onPressed: () => c.selectSeed(d.id)),
                  )),
          for (final e in f.ferts.entries)
            if (kFertilizers[e.key] case final d?)
              _Row(
                  d.name,
                  DsListRow(
                    key: ValueKey('life-fert-${d.id}'),
                    compact: true,
                    leading: LifeIcon(d.id, LifeIconKind.semilla),
                    title: '${d.name} ×${e.value}',
                    titleColor: fishRarityColor(d.rarity),
                    detail: 'Mejora la calidad de la cosecha',
                    trailing:
                        const DsTag('ABONO', color: DsColors.textSecondary),
                  )),
        ];
      case LifeItemsCategory.cosechas:
        return [
          for (final e in f.crops.entries)
            if (parseCropKey(e.key) case (final d, final q)?)
              _Row(
                  '${d.name} ${q.label}',
                  DsListRow(
                    key: ValueKey('life-crop-${d.id}-${q.index}'),
                    compact: true,
                    leading: LifeIcon('cosecha_${d.id}', LifeIconKind.cosecha),
                    title: '${d.name} ×${e.value}',
                    detail: '${d.price} de oro c/u',
                    trailing: DsTag(q.label.toUpperCase(),
                        color: cropQualityColor(q)),
                  )),
        ];
    }
  }
}
