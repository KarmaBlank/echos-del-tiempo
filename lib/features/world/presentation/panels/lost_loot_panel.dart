import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../inventory/presentation/item_widgets.dart';
import '../session_controller.dart';
import '../session_view.dart';

/// Aviso fijo del panel (missions.md § "Loot perdido").
const kLostLootNotice = 'Se borra al empezar la próxima misión.';

/// Panel LOOT PERDIDO de la torrecita del pueblo: lo que quedó en el piso
/// al volver de la misión, compartido por toda la sala. Cada fila: TOMAR
/// (al inventario, lo valida el anfitrión). Ver missions.md.
class LostLootPanel extends StatelessWidget {
  const LostLootPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final pool = view.session.lostLoot;
    final rules = controller.engine.progression;
    return PanelFrame(
      key: const ValueKey('panel-lost-loot'),
      title: 'LOOT PERDIDO',
      width: 640,
      onClose: controller.closePanel,
      actions: [
        PanelButton('CERRAR',
            key: const ValueKey('lost-close'), onPressed: controller.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text('LO QUE QUEDÓ EN EL PISO', style: DsText.subtitle()),
            const SizedBox(width: 8),
            DsBadge('${pool.length}', key: const ValueKey('lost-count')),
          ]),
          const SizedBox(height: 4),
          Text(kLostLootNotice,
              key: const ValueKey('lost-notice'), style: DsText.detail()),
          const SizedBox(height: 6),
          if (pool.isEmpty)
            Text('No hay nada.',
                key: const ValueKey('lost-empty'), style: DsText.detail())
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final g in pool)
                    DsListRow(
                      key: ValueKey('lost-row-${g.id}'),
                      compact: true,
                      title: dropLabelText(rules, g.drop),
                      trailing: DsButton('TOMAR',
                          key: ValueKey('lost-take-${g.id}'),
                          size: DsButtonSize.compact,
                          onPressed: () => controller.takeLostLoot(g.id)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
