import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../inventory/domain/item_text.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/panels/party_member_bar.dart';
import '../../world/presentation/session_view.dart';
import '../../combat/presentation/game_sprites.dart';
import '../domain/endgame_text.dart';
import 'abyss_view.dart';
import 'atlas_view.dart';
import 'eco_zone_hub.dart';
import '../../../core/i18n/i18n_providers.dart';

/// Pestañas del Portal del Eco.
enum EcoPortalTab {
  zonas,
  ecos,
  atlas,
  abismo;

  /// Keys of the tab label and its hint (`ui.endgame.tab.<name>.*`).
  String get labelKey => 'ui.endgame.tab.$name.label';
  String get hintKey => 'ui.endgame.tab.$name.hint';
}

/// Portal del Eco del pueblo (docs/specs/ecos_atlas.md § 1, § 4, § 5):
/// ECOS (lista + ficha, abrir y craftear) y ATLAS (el árbol de la cuenta).
class EcoPortalPanel extends ConsumerStatefulWidget {
  const EcoPortalPanel({
    super.key,
    required this.view,
    required this.controller,
    this.initialTab = EcoPortalTab.zonas,
    this.sprites,
  });

  final SessionView view;
  final SessionController controller;
  final EcoPortalTab initialTab;

  /// Para las tarjetas de los Jefes del Abismo (silueta / sprite).
  final GameSprites? sprites;

  @override
  ConsumerState<EcoPortalPanel> createState() => _EcoPortalPanelState();
}

class _EcoPortalPanelState extends ConsumerState<EcoPortalPanel> {
  late var _tab = widget.initialTab;
  String? _sel;

  SessionController get c => widget.controller;
  SessionView get view => widget.view;

  @override
  Widget build(BuildContext context) {
    // El miembro activo (solo_party.md § 6): sus Ecos y materiales. El
    // Abismo y abrir Ecos son del líder (propuestas de grupo).
    final p = view.actor!.profile;
    final atlas = view.atlas ?? c.atlas;
    final free = c.engine.atlasRules.free(atlas);
    // Q / E, Ctrl+Tab y 1-9 cambian de pestaña (menu_focus.dart).
    return PartyMemberKeys(
      view: view,
      controller: c,
      child: MenuTabKeys(
        count: EcoPortalTab.values.length,
        index: _tab.index,
        onChanged: (i) => setState(() => _tab = EcoPortalTab.values[i]),
        child: PanelFrame(
          title: ref.t('ui.endgame.portal.title'),
          width: 1040,
          fill: true,
          help: _tab == EcoPortalTab.abismo ? kAbyssHelp : kEcoPortalHelp,
          onClose: c.closePanel,
          titleTrailing: ProtoText(
              key: const ValueKey('portal-points'),
              ref.t('ui.endgame.portal.points', {'n': free})),
          header: PartyMemberBar.header(
              view,
              c,
              PanelTabs(
                labels: [
                  for (final t in EcoPortalTab.values) ref.t(t.labelKey)
                ],
                index: _tab.index,
                onChanged: (i) => setState(() => _tab = EcoPortalTab.values[i]),
              )),
          actions: [
            PanelButton(ref.t('ui.endgame.close'), onPressed: c.closePanel),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHint(ref.t(_tab.hintKey)),
              Expanded(
                child: switch (_tab) {
                  EcoPortalTab.zonas => EcoZoneHub(
                      key: const ValueKey('eco-hub'),
                      profile: p,
                      zoneName: (z) =>
                          c.engine.catalog.zone(z)?.name ??
                          ref.t('ui.endgame.zone_n', {'zone': z}),
                      goBlocked: c.ecoTravelBlocked,
                      onGo: (z, t) => c.travelToEcoPortal(z, tier: t)),
                  EcoPortalTab.ecos => _ecos(p),
                  EcoPortalTab.atlas => _atlas(atlas),
                  EcoPortalTab.abismo => AbyssView(
                      key: const ValueKey('abyss-view'),
                      view: view,
                      controller: c,
                      sprites: widget.sprites),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _atlas(AtlasProgress atlas) {
    final s = view.session;
    final remote = c.isClient;
    return AtlasView(
      key: const ValueKey('atlas-view'),
      progress: atlas,
      rules: c.engine.atlasRules,
      editBlocked:
          c.canEditAtlas ? null : ref.t('ui.endgame.only_in_town'),
      onTake: (id) => setState(() => c.takeAtlasNode(id)),
      onReset: () => setState(() => c.resetAtlas()),
      note: remote
          ? ref.t('ui.endgame.atlas.note_client')
          : s.players.length > 1
              ? ref.t('ui.endgame.atlas.note_host')
              : null,
    );
  }

  Widget _ecos(PlayerProfile p) {
    final rules = c.engine.progression;
    final s = view.session;
    final ecos = p.ecos;
    EcoItem? sel;
    for (final e in ecos) {
      if (e.uid == _sel) sel = e;
    }
    sel ??= ecos.isEmpty ? null : ecos.first;
    final atlasFx = c.engine.atlasOf(s);
    final dev = FeatureFlags.instance.devTools;
    final list = <Widget>[
      if (ecos.isEmpty)
        ProtoText(protoColor(
            ProtoColors.dim,
            ref.t('ui.endgame.ecos.none'))),
      for (final e in ecos)
        MenuRow(
          wrap: true,
          key: ValueKey('eco-row-${e.uid}'),
          selected: e.uid == sel?.uid,
          onTap: () => setState(() => _sel = e.uid),
          label: ecoNameMarkup(rules, e),
          value: protoColor(
              ProtoColors.dim, protoEsc(rules.ecos.zoneOf(e)?.name ?? '?')),
        ),
      if (dev) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in const [1, 8, 16])
            PanelButton('DEV: +ECO T$t',
                key: ValueKey('eco-dev-$t'),
                onPressed: () => setState(() => c.devGrantEco(t))),
        ]),
      ],
    ];
    final e = sel;
    if (e != null) {
      // Mejoras del Eco elegido, debajo de la lista (se ven sin bajar): una
      // fila por material con el costo y, si no se puede, el motivo.
      list.addAll([
        const SizedBox(height: 8),
        MenuHeader('${ref.t('ui.endgame.ecos.upgrade')} ${protoColor(ProtoColors.dim, ref.t('ui.endgame.ecos.have', {
              'shard': p.material(CraftMaterial.esquirla),
              'crystal': p.material(CraftMaterial.cristal),
              'prism': p.material(CraftMaterial.prisma),
              'anchor': p.material(CraftMaterial.ancla),
            }))}'),
        for (final op in EcoCraftOp.values)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  // Sin cortar: si no entra, pasa a 2 líneas.
                  child: ProtoText(ecoCraftRowMarkup(e, op)),
                ),
                const SizedBox(width: 8),
                PanelButton(ref.t('ui.endgame.ecos.use'),
                    key: ValueKey('eco-craft-${op.name}'),
                    reason: ecoCraftBlocked(s, view.actorId, p, e, op),
                    onPressed: () => setState(() => c.ecoCraft(e.uid, op))),
              ],
            ),
          ),
      ]);
    }
    return PanelSplit(
      listWidth: 440,
      list: list,
      detail: PanelDetail(
        footer: e == null
            ? const []
            : [
                KeyHints(
                    confirm: ref.t('ui.endgame.hint.choose'),
                    back: ref.t('ui.endgame.hint.close')),
                // Los Ecos se abren en el portal de su zona (ecos_zone.md
                // § 4): acá solo se viaja hasta él.
                PanelButton(ref.t('ui.endgame.go_to_portal'),
                    key: const ValueKey('eco-go'),
                    accent: ProtoColors.green,
                    reason: c.ecoTravelBlocked(e.zone),
                    onPressed: () => c.travelToEcoPortal(e.zone, tier: e.tier)),
              ],
        children: e == null
            ? [
                ProtoText(protoColor(ProtoColors.dim,
                    ref.t('ui.endgame.ecos.pick'))),
              ]
            : [
                ProtoText(
                    key: const ValueKey('eco-detail'),
                    ecoTooltipMarkup(rules, e,
                        atlas: atlasFx, players: s.players.length)),
              ],
      ),
    );
  }
}
