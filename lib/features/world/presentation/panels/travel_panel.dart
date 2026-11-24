import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../app/widgets/players_here_badge.dart';
import '../../domain/player_locations.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../../../endgame/presentation/eco_zone_hub.dart';
import '../world_strings.dart';

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
      title: context.t('ui.world.travel.title'),
      width: ecos ? 960 : 640,
      onClose: c.closePanel,
      header: PanelTabs(
        key: const ValueKey('travel-tabs'),
        labels: [
          context.t('ui.world.travel.tab_travel'),
          context.t('ui.world.travel.tab_echoes')
        ],
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
      actions: [
        PanelButton(context.t('ui.world.travel.close'),
            key: const ValueKey('travel-close'), onPressed: c.closePanel),
      ],
      child: ecos && profile != null
          ? SizedBox(
              height: 420,
              child: EcoZoneHub(
                  key: const ValueKey('travel-eco-hub'),
                  profile: profile,
                  here: c.nearEcoPortal,
                  zoneName: (z) =>
                      c.engine.catalog.zone(z)?.name ??
                      context.t('ui.world.travel.zone', {'n': z}),
                  goBlocked: c.ecoTravelBlocked,
                  onGo: (z, t) => c.travelToEcoPortal(z, tier: t)),
            )
          : _places(c),
    );
  }

  Widget _places(SessionController c) {
    final here = c.place;
    final why = c.cannotTravel;
    final at = playersByPlace(widget.view.session, widget.view.localId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.t('ui.world.travel.help'), style: DsText.detail()),
        SizedBox(height: DsSpace.sm),
        for (final b in kBiomes)
          DsListRow(
            key: ValueKey('travel-${b.id}'),
            compact: true,
            title: b.name,
            subtitleWidget: Text(b.blurb,
                softWrap: true,
                style: DsText.detail(b.open ? null : DsColors.textDisabled)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (at[b.id] case final names? when names.isNotEmpty) ...[
                PlayersHereBadge(
                    key: ValueKey('travel-players-${b.id}'),
                    names: names,
                    title: context.t('ui.world.players_here.title')),
                SizedBox(width: DsSpace.sm),
              ],
              b.id == here
                  ? DsBadge(context.t('ui.world.travel.here'),
                      key: ValueKey('travel-here-${b.id}'))
                  : DsButton(
                      !b.open
                          ? context.t('ui.world.travel.soon')
                          : c.travelLocked(b.id) == null
                              ? context.t('ui.world.travel.go')
                              : context.t('ui.world.travel.zone_caps',
                                  {'n': b.unlockZone}),
                      key: ValueKey('travel-go-${b.id}'),
                      size: DsButtonSize.compact,
                      kind: DsButtonKind.primary,
                      tooltip: b.open ? (c.travelLocked(b.id) ?? why) : null,
                      onPressed:
                          b.open && why == null && c.travelLocked(b.id) == null
                              ? () => c.travelPlace(b.id)
                              : null),
            ]),
          ),
      ],
    );
  }
}
