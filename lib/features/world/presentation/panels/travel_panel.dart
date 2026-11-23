import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../../../endgame/presentation/eco_zone_hub.dart';

/// MAPA DE VIAJE (overworld_biomes.md § 1): el pueblo y los biomas; cada
/// uno viaja por su cuenta. Los biomas que faltan se ven en gris
/// ("Próximamente"). Pestaña ECOS (ecos_zone.md § 5): los portales de
/// Ecos de cada zona con IR.
class TravelPanel extends StatefulWidget {
  const TravelPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<TravelPanel> createState() => _TravelPanelState();
}

class _TravelPanelState extends State<TravelPanel> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final ecos = _tab == 1;
    final profile = widget.view.actor?.profile;
    return PanelFrame(
      key: const ValueKey('panel-travel'),
      title: 'MAPA DE VIAJE',
      width: ecos ? 960 : 640,
      onClose: c.closePanel,
      header: PanelTabs(
        key: const ValueKey('travel-tabs'),
        labels: const ['VIAJAR', 'ECOS'],
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
      actions: [
        PanelButton('CERRAR',
            key: const ValueKey('travel-close'), onPressed: c.closePanel),
      ],
      child: ecos && profile != null
          ? SizedBox(
              height: 420,
              child: EcoZoneHub(
                  key: const ValueKey('travel-eco-hub'),
                  profile: profile,
                  here: c.nearEcoPortal,
                  zoneName: (z) => c.engine.catalog.zone(z)?.name ?? 'Zona $z',
                  goBlocked: c.ecoTravelBlocked,
                  onGo: (z, t) => c.travelToEcoPortal(z, tier: t)),
            )
          : _places(c),
    );
  }

  Widget _places(SessionController c) {
    final here = c.place;
    final why = c.cannotTravel;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              'Viaje rápido entre lugares desbloqueados. Cada uno viaja por '
              'su cuenta.',
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
    );
  }
}
