import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/farming_catalog.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Habitante de un bioma (overworld_biomes.md § 9): una frase, su
/// beneficio como habitante del pueblo y sus semillas en la grilla de
/// oficios (detalle a la derecha).
class BiomeNpcPanel extends StatelessWidget {
  const BiomeNpcPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final n = c.nearNpc ?? biomeLayout(c.place)?.npc;
    if (n == null) return const SizedBox.shrink();
    final p = view.me?.profile;
    final f = p?.life.farm;
    final gold = p?.credits ?? 0;
    final cells = [
      for (final e in n.seeds.entries)
        if (kCrops[e.key] case final s?)
          LifeItemCellData(
            id: 'npc-seed-${s.id}',
            icon: LifeIcon('semilla_${s.id}', LifeIconKind.semilla, size: 32),
            border: fishRarityColor(s.rarity),
            search: s.seedName,
            count: (f?.seedCount(s.id) ?? 0) > 0 ? f!.seedCount(s.id) : null,
            caption: '${e.value} oro',
            detail: LifeItemDetail(
              name: s.seedName,
              nameColor: fishRarityColor(s.rarity),
              tags: [
                ('SEMILLA', DsColors.textSecondary),
                (s.rarity.label.toUpperCase(), fishRarityColor(s.rarity)),
              ],
              lines: [
                'Crece en ${(s.growSec / 60).round()} min',
                'Tenés ${f?.seedCount(s.id) ?? 0}',
                'Precio: ${e.value} de oro c/u',
              ],
              description: s.lore.isEmpty ? null : s.lore,
              actions: [
                DsButton('COMPRAR 1 · ${e.value}',
                    key: ValueKey('npc-seed-buy-${s.id}'),
                    size: DsButtonSize.compact,
                    onPressed: gold >= e.value ? () => c.buySeed(s.id) : null),
              ],
            ),
          ),
    ];
    return PanelFrame(
      key: const ValueKey('panel-biome-npc'),
      title: '${n.name.toUpperCase()} · ${n.role.label.toUpperCase()}',
      width: 640,
      onClose: c.closePanel,
      actions: [
        PanelButton('CERRAR',
            key: const ValueKey('npc-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.npcLine(n), softWrap: true, style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Text('Beneficio en el pueblo: ${ResidentRules.benefitText(n, 0)}',
              key: const ValueKey('npc-benefit'),
              softWrap: true,
              style: DsText.detail(DsColors.textSecondary)),
          SizedBox(height: DsSpace.sm),
          LifeItemGrid(
            groups: [LifeItemGroup('SEMILLAS', cells)],
            empty: 'No vende nada todavía.',
          ),
        ],
      ),
    );
  }
}
