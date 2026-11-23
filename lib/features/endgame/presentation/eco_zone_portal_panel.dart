import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/rules/eco_portal_rules.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import '../../inventory/domain/item_text.dart';
import '../domain/endgame_text.dart';
import 'eco_zone_hub.dart';

/// Portal de Ecos de una zona, en el exterior de su bioma
/// (docs/specs/ecos_zone.md § 4): arriba los tiers (cerrados en gris con
/// el motivo), abajo los Ecos de esta zona y del tier elegido con su ficha
/// y ABRIR (consume el Eco, como siempre).
class EcoZonePortalPanel extends StatefulWidget {
  const EcoZonePortalPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<EcoZonePortalPanel> createState() => _EcoZonePortalPanelState();
}

class _EcoZonePortalPanelState extends State<EcoZonePortalPanel> {
  int? _tier;
  String? _sel;

  SessionController get c => widget.controller;
  SessionView get view => widget.view;

  @override
  Widget build(BuildContext context) {
    final zone = c.ecoZone ?? 1;
    final p = view.actor!.profile;
    final rules = c.engine.progression;
    final name = c.engine.catalog.zone(zone)?.name ?? 'Zona $zone';
    final open = EcoPortalRules.unlockedTier(p, zone);
    var tier = _tier ?? c.ecoTier;
    if (tier == null) {
      // El tier abierto más alto con Ecos; si no, el más alto abierto.
      for (var t = open; t >= 1 && tier == null; t--) {
        if (p.ecos.any((e) => e.zone == zone && e.tier == t)) tier = t;
      }
    }
    tier = (tier ?? open).clamp(1, EcoPortalRules.maxTier);
    final ecos = [
      for (final e in p.ecos)
        if (e.zone == zone && e.tier == tier) e
    ];
    EcoItem? sel;
    for (final e in ecos) {
      if (e.uid == _sel) sel = e;
    }
    sel ??= ecos.isEmpty ? null : ecos.first;
    final s = view.session;
    final e = sel;
    final lock = EcoPortalRules.lockReason(p, zone, tier, zoneName: name);
    return PanelFrame(
      key: const ValueKey('panel-eco-zone'),
      title: 'PORTAL DE ECOS · ZONA $zone',
      width: 960,
      fill: true,
      onClose: c.closePanel,
      actions: [PanelButton('CERRAR [ESC]', onPressed: c.closePanel)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHint('$name: elegí un tier y un Eco tuyo de esta zona. ABRIR '
              'lo gasta y te lleva a una mazmorra nueva.'),
          EcoTierGrid(
            keyPrefix: 'eco-zone-tier',
            profile: p,
            zone: zone,
            zoneName: name,
            selected: tier,
            onSelect: (t) => setState(() {
              _tier = t;
              _sel = null;
            }),
          ),
          SizedBox(height: DsSpace.sm),
          Expanded(
            child: PanelSplit(
              listWidth: 400,
              list: [
                if (lock != null)
                  ProtoText(protoColor(ProtoColors.orange, protoEsc(lock)))
                else if (ecos.isEmpty)
                  ProtoText(
                      key: const ValueKey('eco-zone-empty'),
                      protoColor(
                          ProtoColors.dim,
                          'No tenés Ecos T$tier de esta zona. Los Ecos caen '
                          'como botín; este portal no abre nada sin uno.')),
                for (final x in ecos)
                  MenuRow(
                    wrap: true,
                    key: ValueKey('eco-zone-row-${x.uid}'),
                    selected: x.uid == e?.uid,
                    onTap: () => setState(() => _sel = x.uid),
                    label: ecoNameMarkup(rules, x),
                  ),
              ],
              detail: PanelDetail(
                footer: [
                  const KeyHints(confirm: 'Elegir', back: 'Cerrar'),
                  PanelButton('ABRIR',
                      key: const ValueKey('eco-zone-open'),
                      accent: ProtoColors.green,
                      reason: view.actingCompanion
                          ? 'Los Ecos los abre el líder'
                          : ecoZoneOpenBlocked(s, p, e, zone, tier,
                              near: c.nearEcoPortal == zone, zoneName: name),
                      onPressed: () {
                    if (e != null && c.proposeEco(e.uid)) c.closePanel();
                  }),
                ],
                children: [
                  if (e == null)
                    ProtoText(protoColor(ProtoColors.dim,
                        'Sin un Eco de este tier y zona el portal no abre.'))
                  else
                    ProtoText(
                        key: const ValueKey('eco-zone-detail'),
                        ecoTooltipMarkup(rules, e,
                            atlas: c.engine.atlasOf(s),
                            players: s.players.length)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
