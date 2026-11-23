import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../app/widgets/pixel_icon.dart' show PixelIcon;
import '../../../../game_engine/rules/dungeon_rules.dart';
import '../../../inventory/presentation/craft_bench.dart'
    show materialColor, materialIcon;
import '../session_controller.dart';
import '../session_view.dart';

/// OFRENDA (persistent_dungeons.md § 4): el altar que queda en la sala del
/// jefe vencido. La grilla muestra los materiales que pide (estilo
/// INVENTARIO, detalle a la derecha); OFRENDAR los paga y revive al jefe.
class OfferingPanel extends StatelessWidget {
  const OfferingPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final m = view.session.mission;
    final me = view.session.players[view.localId];
    final zone = m?.zone ?? 1;
    final cost = DungeonRules.offeringCost(zone);
    final why = me == null
        ? 'No estás en la mazmorra'
        : DungeonRules.cannotOffer(me.profile, zone);
    return PanelFrame(
      key: const ValueKey('panel-offering'),
      title: 'OFRENDA',
      width: 640,
      onClose: controller.closePanel,
      actions: [
        PanelButton('OFRENDAR',
            key: const ValueKey('offering-pay'),
            reason: why,
            onPressed: why == null ? controller.offerBoss : null),
        PanelButton('CERRAR',
            key: const ValueKey('offering-close'),
            onPressed: controller.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('El eco del jefe vuelve a su sala a cambio de materiales.',
              key: const ValueKey('offering-notice'), style: DsText.detail()),
          const SizedBox(height: 6),
          SizedBox(
            height: 260,
            child: DsCraftGridTemplate(
              keyPrefix: 'offering',
              empty: 'No pide nada.',
              items: [
                for (final e in cost.entries)
                  () {
                    final have = me?.profile.material(e.key) ?? 0;
                    return DsCraftItem(
                      id: e.key.name,
                      icon: PixelIcon(materialIcon(e.key),
                          size: 32, color: materialColor(e.key)),
                      border: materialColor(e.key),
                      name: e.key.label,
                      count: have,
                      description: e.key.description,
                      lines: [
                        'Pide ${e.value} · tenés $have',
                        if (have < e.value) 'Te faltan ${e.value - have}',
                      ],
                    );
                  }(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
