import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/models/town_build.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';

/// FUENTE RÚNICA (town_editor.md § 1, farming.md § 8): panel chico con
/// acciones grandes, una línea cada una: EDITAR PUEBLO, CONTRATAR
/// GRANJERO / PESCADOR (elegir la huerta o el lago en el mapa) y el
/// TABLERO DE ENCARGOS. Bloqueada = gris con el motivo en su línea.
class FountainPanel extends StatelessWidget {
  const FountainPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final editWhy = c.cannotEditTown;
    final farmWhy = c.cannotPickHire(BuildKind.huerta);
    final fishWhy = c.cannotPickHire(BuildKind.lago);
    final actions = [
      ('fountain-edit-btn', context.t('ui.town.fountain.edit'),
          context.t('ui.town.fountain.edit_line'), editWhy,
          c.enterTownEdit),
      ('fountain-hire-farmer', context.t('ui.town.fountain.hire_farmer'),
          context.t('ui.town.fountain.hire_farmer_line'), farmWhy,
          () => c.enterHirePick(BuildKind.huerta)),
      ('fountain-hire-fisher', context.t('ui.town.fountain.hire_fisher'),
          context.t('ui.town.fountain.hire_fisher_line'),
          fishWhy, () => c.enterHirePick(BuildKind.lago)),
      ('fountain-board', context.t('ui.town.fountain.board'),
          context.t('ui.town.fountain.board_line'), null,
          () => c.openPanel(WorldPanel.missionBoard)),
      // Mapa de viaje (overworld_biomes.md § 1).
      ('fountain-travel', context.t('ui.town.fountain.travel'),
          context.t('ui.town.fountain.travel_line'), null,
          () => c.openPanel(WorldPanel.travel)),
      // Registro de encargos de los habitantes (overworld_biomes.md § 10.2).
      ('fountain-quests', context.t('ui.town.fountain.quests'),
          context.t('ui.town.fountain.quests_line'), null,
          () => c.openPanel(WorldPanel.questLog)),
    ];
    // Resumen de los beneficios permanentes (§ 10.3).
    final town = c.town;
    final living = ResidentRules.living(town);
    final summary = living.isEmpty
        ? context.t('ui.town.fountain.residents_none')
        : context.t('ui.town.fountain.residents', {
            'list': [
              for (final n in living)
                '${n.name}: ${ResidentRules.tier(town.resident(n.id)) < 0 ? context.t('ui.town.fountain.no_house') : ResidentRules.benefitText(n, ResidentRules.tier(town.resident(n.id)))}'
            ].join(' · ')
          });
    return PanelFrame(
      key: const ValueKey('panel-fountain'),
      title: context.t('ui.town.fountain.title'),
      width: 560,
      onClose: c.closePanel,
      actions: [
        PanelButton(context.t('ui.town.fountain.close'),
            key: const ValueKey('fountain-close'), onPressed: c.closePanel),
      ],
      child: LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - DsSpace.sm) / 2;
        return Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.sm,
          children: [
            SizedBox(
              width: box.maxWidth,
              child: Text(summary,
                  key: const ValueKey('fountain-residents'),
                  softWrap: true,
                  style: DsText.detail(DsColors.textSecondary)),
            ),
            for (final (key, label, line, why, go) in actions)
              SizedBox(
                width: w,
                child: DsButton(label,
                    key: ValueKey(key),
                    kind: DsButtonKind.primary,
                    details: [why ?? line],
                    // Bloqueada porque otro edita (town_editor.md § 1.3).
                    tooltip: why != null && why.startsWith('Está editando')
                        ? why
                        : null,
                    onPressed: why == null ? () => go() : null),
              ),
          ],
        );
      }),
    );
  }
}
