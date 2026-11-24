import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../../core/i18n/i18n_providers.dart';
import '../domain/endgame_names.dart';

/// Portal de Ecos de una zona, en el exterior de su bioma
/// (docs/specs/ecos_zone.md § 4): arriba los tiers (cerrados en gris con
/// el motivo), abajo los Ecos de esta zona y del tier elegido con su ficha
/// y ABRIR (consume el Eco, como siempre).
class EcoZonePortalPanel extends ConsumerStatefulWidget {
  const EcoZonePortalPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  ConsumerState<EcoZonePortalPanel> createState() => _EcoZonePortalPanelState();
}

class _EcoZonePortalPanelState extends ConsumerState<EcoZonePortalPanel> {
  int? _tier;
  String? _sel;

  SessionController get c => widget.controller;
  SessionView get view => widget.view;

  @override
  Widget build(BuildContext context) {
    final zone = c.ecoZone ?? 1;
    final p = view.actor!.profile;
    final rules = c.engine.progression;
    final name = c.engine.catalog.zone(zone)?.tr ??
        ref.t('ui.endgame.zone_n', {'zone': zone});
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
    final lock = ecoLockText(p, zone, tier, zoneName: name);
    return PanelFrame(
      key: const ValueKey('panel-eco-zone'),
      title: ref.t('ui.endgame.zone_portal.title', {'zone': zone}),
      width: 960,
      fill: true,
      onClose: c.closePanel,
      actions: [
        PanelButton(ref.t('ui.endgame.close'), onPressed: c.closePanel)
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHint(ref.t('ui.endgame.zone_portal.hint', {'name': name})),
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
                          ref.t('ui.endgame.zone_portal.empty',
                              {'tier': tier}))),
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
                  KeyHints(
                      confirm: ref.t('ui.endgame.hint.choose'),
                      back: ref.t('ui.endgame.hint.close')),
                  PanelButton(ref.t('ui.endgame.open'),
                      key: const ValueKey('eco-zone-open'),
                      accent: ProtoColors.green,
                      reason: view.actingCompanion
                          ? ref.t('ui.endgame.zone_portal.leader_opens')
                          : ecoZoneOpenBlocked(s, p, e, zone, tier,
                              near: c.nearEcoPortal == zone, zoneName: name),
                      onPressed: () {
                    if (e != null && c.proposeEco(e.uid)) c.closePanel();
                  }),
                ],
                children: [
                  if (e == null)
                    ProtoText(protoColor(ProtoColors.dim,
                        ref.t('ui.endgame.zone_portal.no_eco')))
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
