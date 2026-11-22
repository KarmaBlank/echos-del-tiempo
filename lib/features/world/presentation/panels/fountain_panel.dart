import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'fishing_widgets.dart' show fishRarityColor;

/// FUENTE RÚNICA (farming.md § 6–8, v0.23.0): ampliar el pueblo y elegir
/// LAGO o HUERTA para cada espacio, soltar peces en el lago, contratar al
/// ayudante de la huerta y, como antes, ir al tablero de encargos.
class FountainPanel extends StatelessWidget {
  const FountainPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = view.me?.profile;
    final t = c.town;
    final owner = c.isWorldOwner;
    final max = TownRules.maxExpansions;
    final free = TownRules.freeSlots(t);
    final next = TownRules.cost(t.expansions + 1);
    final why = p == null ? 'Sin personaje' : TownRules.cannotExpand(p, t);
    final cap = TownRules.lakeCapacity(t);
    final fish = [
      for (final f in kFish.values)
        if ((p?.life.count(f.id) ?? 0) > 0 && f.biome != kWaterJunkBiome) f
    ];
    final hireWhy = p == null ? 'Sin personaje' : TownRules.cannotHire(p, t);
    return PanelFrame(
      key: const ValueKey('panel-fountain'),
      title: 'FUENTE RÚNICA',
      width: 720,
      onClose: c.closePanel,
      actions: [
        PanelButton('TABLERO DE ENCARGOS',
            key: const ValueKey('fountain-board'),
            onPressed: () => c.openPanel(WorldPanel.missionBoard)),
        PanelButton('CERRAR',
            key: const ValueKey('fountain-close'), onPressed: c.closePanel),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DsSectionHeader('AMPLIAR EL PUEBLO',
                  trailing: DsBadge('${t.expansions}/$max',
                      key: const ValueKey('fountain-exp-count'))),
              Text(
                  'Cada ampliación suma una franja al este con dos espacios. '
                  'En cada uno elegís LAGO (más agua, más peces y más rareza) '
                  'o HUERTA (más parcelas).',
                  style: DsText.detail()),
              if (free > 0) ...[
                SizedBox(height: DsSpace.xs),
                DsListRow(
                  key: const ValueKey('fountain-slot'),
                  compact: true,
                  title: 'Espacio libre ($free)',
                  detail: owner
                      ? '¿Qué va en el espacio nuevo?'
                      : 'Lo elige el dueño del mundo',
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    DsButton('LAGO',
                        key: const ValueKey('fountain-zone-lago'),
                        size: DsButtonSize.compact,
                        onPressed: owner
                            ? () => c.assignZone(TownZoneKind.lago)
                            : null),
                    SizedBox(width: DsSpace.xs),
                    DsButton('HUERTA',
                        key: const ValueKey('fountain-zone-huerta'),
                        size: DsButtonSize.compact,
                        onPressed: owner
                            ? () => c.assignZone(TownZoneKind.huerta)
                            : null),
                  ]),
                ),
              ],
              if (t.expansions < max)
                DsListRow(
                  key: const ValueKey('fountain-expand'),
                  compact: true,
                  title: 'Ampliación ${t.expansions + 1}',
                  detail: TownRules.costText(next),
                  trailing: DsButton('AMPLIAR',
                      key: const ValueKey('fountain-expand-btn'),
                      size: DsButtonSize.compact,
                      tooltip: !owner
                          ? 'Solo el dueño del mundo amplía el pueblo'
                          : why,
                      onPressed: owner && why == null ? c.expandTown : null),
                ),
              Text(
                  'Zonas: ${t.zoneCount(TownZoneKind.lago)} de LAGO · '
                  '${t.zoneCount(TownZoneKind.huerta)} de HUERTA',
                  key: const ValueKey('fountain-zones'),
                  style: DsText.detail()),
              SizedBox(height: DsSpace.sm),
              DsSectionHeader('LAGO',
                  trailing: DsBadge('${t.stockTotal}/$cap',
                      key: const ValueKey('fountain-lake-count'))),
              Text(
                  'Soltá peces de tu bolsa: esa especie sale más seguido y, '
                  'con dos o más, cría al ganar misiones y sube la rareza.',
                  style: DsText.detail()),
              for (final e in t.stock.entries)
                if (kFish[e.key] case final f?)
                  DsListRow(
                    key: ValueKey('fountain-stock-${f.id}'),
                    compact: true,
                    title: '${f.name} ×${e.value}',
                    titleColor: fishRarityColor(f.rarity),
                    detail: e.value >= 2 ? 'Cría' : 'Sola',
                  ),
              for (final f in fish)
                DsListRow(
                  key: ValueKey('fountain-release-${f.id}'),
                  compact: true,
                  title: '${f.name} (tenés ${p?.life.count(f.id) ?? 0})',
                  titleColor: fishRarityColor(f.rarity),
                  trailing: DsButton('SOLTAR',
                      key: ValueKey('fountain-release-btn-${f.id}'),
                      size: DsButtonSize.compact,
                      onPressed: t.stockTotal < cap
                          ? () => c.stockFish(f.id)
                          : null),
                ),
              SizedBox(height: DsSpace.sm),
              DsSectionHeader('AYUDANTE DE LA HUERTA',
                  trailing: DsBadge(
                      '${t.helper}/${TownRules.t.i('helperMax')}',
                      key: const ValueKey('fountain-helper-level'))),
              DsListRow(
                key: const ValueKey('fountain-helper'),
                compact: true,
                title: t.helper == 0 ? 'Contratar' : 'Mejorar',
                detail: '${TownRules.helperCost(t.helper + 1)} de oro · '
                    'hasta ${TownRules.t.i('helperPlots') * (t.helper + 1)} '
                    'parcelas · cosecha al granero del comerciante',
                trailing: DsButton(t.helper == 0 ? 'CONTRATAR' : 'MEJORAR',
                    key: const ValueKey('fountain-helper-btn'),
                    size: DsButtonSize.compact,
                    tooltip: hireWhy,
                    onPressed: hireWhy == null ? c.hireHelper : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
