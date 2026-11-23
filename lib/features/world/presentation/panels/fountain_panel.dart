import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';

/// FUENTE RÚNICA (town_editor.md § 1, farming.md § 8): entrar a EDITAR
/// PUEBLO (solo el dueño del mundo), 
/// como antes, ir al tablero de encargos.
class FountainPanel extends StatelessWidget {
  const FountainPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = c.town;
    final editWhy = c.cannotEditTown;
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
              DsSectionHeader('EL PUEBLO',
                  trailing: DsBadge(
                      '${t.expansions}/${TownRules.maxExpansions}',
                      key: const ValueKey('fountain-exp-count'))),
              Text(
                  'Ampliá hacia cualquier lado, poné lagos y huertas donde '
                  'quieras, movelos y soltá peces en cada lago. Los demás '
                  'siguen jugando mientras editás.',
                  style: DsText.detail()),
              DsListRow(
                key: const ValueKey('fountain-edit'),
                compact: true,
                title: 'Edición del pueblo',
                // Segunda línea que se parte: nunca "…" (v0.24.2).
                subtitleWidget: Text(
                    '${t.lakes.length} lagos · ${t.farms.length} huertas '
                    '· ${t.stockTotal} peces soltados',
                    softWrap: true,
                    style: DsText.detail()),
                trailing: DsButton('EDITAR PUEBLO',
                    key: const ValueKey('fountain-edit-btn'),
                    size: DsButtonSize.compact,
                    kind: DsButtonKind.primary,
                    tooltip: editWhy,
                    onPressed: editWhy == null ? c.enterTownEdit : null),
              ),
              SizedBox(height: DsSpace.sm),
              Text(
                  'Los granjeros y pescadores se contratan en EDITAR PUEBLO: '
                  'tocá una huerta o un lago.',
                  key: const ValueKey('fountain-helper-note'),
                  style: DsText.detail()),
            ],
          ),
        ),
      ),
    );
  }
}
