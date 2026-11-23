import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../session_controller.dart';
import '../session_view.dart';

/// MAPA DE VIAJE (overworld_biomes.md § 1): el pueblo y los biomas. El
/// anfitrión elige y todo el grupo viaja junto; los biomas que faltan se
/// ven en gris ("Próximamente").
class TravelPanel extends StatelessWidget {
  const TravelPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final here = c.place;
    final why = c.cannotTravel;
    return PanelFrame(
      key: const ValueKey('panel-travel'),
      title: 'MAPA DE VIAJE',
      width: 640,
      onClose: c.closePanel,
      actions: [
        PanelButton('CERRAR',
            key: const ValueKey('travel-close'), onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              'Viaje rápido entre lugares desbloqueados. Viaja todo el grupo '
              'junto: decide el anfitrión.',
              style: DsText.detail()),
          SizedBox(height: DsSpace.sm),
          for (final b in kBiomes)
            DsListRow(
              key: ValueKey('travel-${b.id}'),
              compact: true,
              title: b.name,
              subtitleWidget: Text(b.blurb,
                  softWrap: true,
                  style: DsText.detail(b.open ? null : DsColors.textDisabled)),
              trailing: b.id == here
                  ? DsBadge('ACÁ', key: ValueKey('travel-here-${b.id}'))
                  : DsButton(
                      !b.open
                          ? 'PRÓXIMAMENTE'
                          : c.travelLocked(b.id) == null
                              ? 'VIAJAR'
                              : 'ZONA ${b.unlockZone}',
                      key: ValueKey('travel-go-${b.id}'),
                      size: DsButtonSize.compact,
                      kind: DsButtonKind.primary,
                      tooltip: b.open ? (c.travelLocked(b.id) ?? why) : null,
                      onPressed: b.open &&
                              why == null &&
                              c.travelLocked(b.id) == null
                          ? () => c.travelPlace(b.id)
                          : null),
            ),
        ],
      ),
    );
  }
}
