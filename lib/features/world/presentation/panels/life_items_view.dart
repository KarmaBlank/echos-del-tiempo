import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import 'fishing_widgets.dart' show fishRarityColor;

/// Pestaña PESCA Y CULTIVO de PERSONAJE (farming.md § 11, fishing.md
/// § 5.1): herramientas de oficio, pescados, basura del agua, semillas,
/// abonos y cosechas. Nunca ocupan casilleros del inventario. Solo en el
/// pueblo (en una misión se ve el aviso).
class LifeItemsView extends StatelessWidget {
  const LifeItemsView(
      {super.key,
      required this.profile,
      required this.controller,
      required this.inTown});

  final PlayerProfile profile;
  final SessionController controller;
  final bool inTown;

  @override
  Widget build(BuildContext context) {
    if (!inTown) {
      return Center(
        child: Text('Disponible en el pueblo.',
            key: const ValueKey('life-items-away'), style: DsText.detail()),
      );
    }
    final c = controller;
    final life = profile.life;
    final f = life.farm;
    final lake = TownRules.lakeNear(c.town, c.local.x, c.local.y);
    final lakeFull =
        lake == null || lake.stockTotal >= TownRules.lakeCapacity(lake);
    final fish = [
      for (final d in kFish.values)
        if (life.count(d.id) > 0 && d.biome != kWaterJunkBiome) d
    ];
    final junk = [
      for (final d in kFish.values)
        if (life.count(d.id) > 0 && d.biome == kWaterJunkBiome) d
    ];
    final crops = [
      for (final e in f.crops.entries)
        if (parseCropKey(e.key) case final pc?) (pc.$1, pc.$2, e.value)
    ];
    Widget tool(String id, String name, FishRarity r, String kind,
            bool equipped, VoidCallback onEquip) =>
        DsListRow(
          key: ValueKey('life-tool-$id'),
          compact: true,
          title: name,
          titleColor: fishRarityColor(r),
          detail: kind,
          trailing: equipped
              ? const DsTag('EQUIPADA', color: DsColors.reward)
              : DsButton('EQUIPAR',
                  key: ValueKey('life-tool-eq-$id'),
                  size: DsButtonSize.compact,
                  onPressed: onEquip),
        );
    return ListView(
      key: const ValueKey('life-items'),
      children: [
        const DsSectionHeader('HERRAMIENTAS'),
        for (final id in life.rods)
          if (kRods[id] case final r?)
            tool(id, r.name, r.rarity, 'Caña', life.rod == id,
                () => c.equipRod(id)),
        for (final id in [...f.hoes, ...f.cans])
          if (kFarmTools[id] case final d?)
            tool(id, d.name, d.rarity, d.kind.label,
                f.hoe == id || f.can == id, () => c.equipFarmTool(id)),
        SizedBox(height: DsSpace.sm),
        DsSectionHeader('PESCADOS',
            trailing: DsBadge('${life.bagTotal}', neutral: true)),
        if (fish.isEmpty)
          Text('Sin pescados.', style: DsText.detail())
        else
          for (final d in fish)
            DsListRow(
              key: ValueKey('life-fish-${d.id}'),
              compact: true,
              title: '${d.name} ×${life.count(d.id)}',
              titleColor: fishRarityColor(d.rarity),
              detail: '${d.rarity.label} · ${d.price} de oro',
              trailing: DsButton('SOLTAR EN EL LAGO',
                  key: ValueKey('life-fish-stock-${d.id}'),
                  size: DsButtonSize.compact,
                  onPressed:
                      lakeFull ? null : () => c.stockFish(d.id, lake.id)),
            ),
        for (final d in junk)
          DsListRow(
            key: ValueKey('life-junk-${d.id}'),
            compact: true,
            title: '${d.name} ×${life.count(d.id)}',
            detail: 'Basura del agua · ${d.price} de oro',
          ),
        SizedBox(height: DsSpace.sm),
        DsSectionHeader('SEMILLAS',
            trailing: DsBadge('${f.seedTotal}', neutral: true)),
        if (f.seeds.isEmpty)
          Text('Sin semillas.', style: DsText.detail())
        else
          for (final e in f.seeds.entries)
            if (kCrops[e.key] case final d?)
              DsListRow(
                key: ValueKey('life-seed-${d.id}'),
                compact: true,
                title: '${d.seedName} ×${e.value}',
                titleColor: fishRarityColor(d.rarity),
                detail: 'Crece en ${(d.growSec / 60).round()} min',
                trailing: f.activeSeed == d.id
                    ? const DsTag('PARA PLANTAR', color: DsColors.reward)
                    : DsButton('ELEGIR',
                        key: ValueKey('life-seed-pick-${d.id}'),
                        size: DsButtonSize.compact,
                        onPressed: () => c.selectSeed(d.id)),
              ),
        for (final e in f.ferts.entries)
          if (kFertilizers[e.key] case final d?)
            DsListRow(
              key: ValueKey('life-fert-${d.id}'),
              compact: true,
              title: '${d.name} ×${e.value}',
              titleColor: fishRarityColor(d.rarity),
              detail: 'Mejora las chances: normal / rara / épica / legendaria',
            ),
        SizedBox(height: DsSpace.sm),
        DsSectionHeader('COSECHAS',
            trailing: DsBadge('${f.cropTotal}', neutral: true)),
        if (crops.isEmpty)
          Text('Sin cosechas.', style: DsText.detail())
        else
          for (final (d, q, n) in crops)
            DsListRow(
              key: ValueKey('life-crop-${d.id}-${q.index}'),
              compact: true,
              title: '${d.name} ×$n',
              titleColor: fishRarityColor(d.rarity),
              detail: 'Calidad ${q.label}',
            ),
      ],
    );
  }
}
