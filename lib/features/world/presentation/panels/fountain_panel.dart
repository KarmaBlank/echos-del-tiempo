import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';

/// FUENTE RÚNICA (town_editor.md § 1, farming.md § 8): entrar a EDITAR
/// PUEBLO (solo el dueño del mundo), contratar al ayudante de la huerta y,
/// como antes, ir al tablero de encargos.
class FountainPanel extends StatelessWidget {
  const FountainPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = view.me?.profile;
    final t = c.town;
    final editWhy = c.cannotEditTown;
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
        PanelButton('MAPA DE VIAJE',
            key: const ValueKey('fountain-travel'),
            onPressed: () => c.openPanel(WorldPanel.travel)),
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
              DsSectionHeader('AYUDANTE DE LA HUERTA',
                  trailing: DsBadge(
                      '${t.helper}/${TownRules.t.i('helperMax')}',
                      key: const ValueKey('fountain-helper-level'))),
              DsListRow(
                key: const ValueKey('fountain-helper'),
                compact: true,
                title: t.helper == 0 ? 'Contratar' : 'Mejorar',
                subtitleWidget: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          '${TownRules.helperCost(t.helper + 1)} de oro · '
                          'hasta ${TownRules.t.i('helperPlots') * (t.helper + 1)} '
                          'parcelas · cosecha al granero del comerciante',
                          softWrap: true,
                          style: DsText.detail()),
                      // El motivo del botón gris, a la vista.
                      if (hireWhy != null)
                        Text(hireWhy,
                            key: const ValueKey('fountain-helper-why'),
                            softWrap: true,
                            style: DsText.detail(DsColors.danger)),
                    ]),
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
