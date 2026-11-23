import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/rules/biome_fisher_rules.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Pescador nativo del bioma (fishing.md § 12): su frase y el pedido del
/// día en la grilla de oficios, con el detalle a la derecha y ENTREGAR.
class BiomeFisherPanel extends StatelessWidget {
  const BiomeFisherPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final f = kBiomeFishers[c.place];
    final p = view.me?.profile;
    if (f == null || p == null) return const SizedBox.shrink();
    final day = math.max(1, c.town.sky.day);
    final lv = FishingRules.level(p);
    final r = BiomeFisherRules.request(f.biome, day, lv);
    final why = BiomeFisherRules.cannot(p, c.townState, f.biome, day);
    final d = r == null ? null : kFish[r.species];
    final cells = <LifeItemCellData>[
      if (r != null && d != null)
        LifeItemCellData(
          id: 'fisher-req-${d.id}',
          icon: LifeIcon(d.id, LifeIconKind.pescado, size: 32),
          border: fishRarityColor(d.rarity),
          search: d.name,
          count: r.n,
          caption: '${r.cm} cm',
          detail: LifeItemDetail(
            name: 'Pedido de ${f.name}',
            nameColor: DsColors.textTitle,
            tags: [
              ('PEDIDO DEL DÍA', DsColors.reward),
              (d.rarity.label.toUpperCase(), fishRarityColor(d.rarity)),
            ],
            lines: [
              '${r.n} × ${d.name} (de ${r.cm} cm o más)',
              'Tenés ${p.life.count(d.id)} · tu récord: '
                  '${p.life.log[d.id] ?? 0} cm',
              'XP de Pesca: +${BiomeFisherRules.reward(r, lv).fishXp}',
              'XP de personaje: +${BiomeFisherRules.reward(r, lv).charXp}',
              'Oro: +${BiomeFisherRules.reward(r, lv).gold}',
            ],
            description: 'Solo se pesca en este lago. Pide algo nuevo cada '
                'día del mundo, según tu nivel de Pesca.',
            actions: [
              DsButton('ENTREGAR',
                  key: const ValueKey('fisher-deliver'),
                  size: DsButtonSize.compact,
                  tooltip: why,
                  onPressed: why == null ? c.fisherDeliver : null),
            ],
          ),
        ),
    ];
    return PanelFrame(
      key: const ValueKey('panel-biome-fisher'),
      title: '${f.name.toUpperCase()} · PESCADOR',
      width: 640,
      onClose: c.closePanel,
      actions: [
        PanelButton('CERRAR',
            key: const ValueKey('fisher-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(f.lines[day % f.lines.length],
              softWrap: true, style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Text(
              'No se muda al pueblo: vive en ${biomeLayout(f.biome)?.lakeName.toLowerCase() ?? 'su lago'}.',
              softWrap: true,
              style: DsText.detail(DsColors.textSecondary)),
          SizedBox(height: DsSpace.xs),
          LifeItemGrid(
            key: const ValueKey('fisher-grid'),
            groups: [LifeItemGroup(null, cells)],
            empty: 'Hoy no pide nada.',
          ),
        ],
      ),
    );
  }
}
