import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/models/town_build.dart';
import '../session_controller.dart';
import '../session_view.dart';

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
      ('fountain-edit-btn', 'EDITAR PUEBLO',
          'Ampliá, poné y mové lagos y huertas, soltá peces.', editWhy,
          c.enterTownEdit),
      ('fountain-hire-farmer', 'CONTRATAR GRANJERO',
          'Elegí la huerta: siembra, riega y cosecha en su cofre.', farmWhy,
          () => c.enterHirePick(BuildKind.huerta)),
      ('fountain-hire-fisher', 'CONTRATAR PESCADOR',
          'Elegí el lago: pesca solo y deja lo que saca en su cofre.',
          fishWhy, () => c.enterHirePick(BuildKind.lago)),
      ('fountain-board', 'TABLERO DE ENCARGOS',
          'Encargos del pueblo para la próxima salida.', null,
          () => c.openPanel(WorldPanel.missionBoard)),
    ];
    return PanelFrame(
      key: const ValueKey('panel-fountain'),
      title: 'FUENTE RÚNICA',
      width: 560,
      onClose: c.closePanel,
      actions: [
        PanelButton('CERRAR',
            key: const ValueKey('fountain-close'), onPressed: c.closePanel),
      ],
      child: LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - DsSpace.sm) / 2;
        return Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.sm,
          children: [
            for (final (key, label, line, why, go) in actions)
              SizedBox(
                width: w,
                child: DsButton(label,
                    key: ValueKey(key),
                    kind: DsButtonKind.primary,
                    details: [why ?? line],
                    onPressed: why == null ? () => go() : null),
              ),
          ],
        );
      }),
    );
  }
}
