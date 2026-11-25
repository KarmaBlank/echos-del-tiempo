import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_markup.dart';
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
import 'eco_fusion_view.dart';
import 'eco_upgrade_view.dart';
import '../../../game_engine/data/biomes_catalog.dart' show biomeDef;
import '../../../game_engine/models/loot.dart' show StackKind;
import '../../../game_engine/rules/eco_portal_rules.dart';
import '../../inventory/presentation/item_widgets.dart'
    show PixelIcon, iconForStack;
import 'eco_zone_hub.dart';
import '../../../app/design/design.dart';
import '../../../game_engine/data/eco_catalog.dart' show ecoModRange;
import '../../../game_engine/rules/eco_rules.dart';
import '../../inventory/domain/item_names.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../domain/endgame_names.dart';
import '../../inventory/domain/eco_text.dart';

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

  /// Subpestaña FUSIONAR de ECOS (ecos_atlas.md § 4.2) y sus elegidos.
  bool _fuse = false;
  final _fuseSel = <String>[];

  /// Ecos de antes de fusionar: el que aparece nuevo es el resultado y
  /// queda elegido en MEJORAR.
  Set<String>? _fuseBefore;
  bool _justFused = false;

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
                          c.engine.catalog.zone(z)?.tr ??
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
    if (_fuseBefore case final before?) {
      for (final e in p.ecos) {
        if (before.contains(e.uid)) continue;
        _sel = e.uid;
        _fuseBefore = null;
        _justFused = true;
        _fuse = false;
        break;
      }
    }
    _fuseSel.removeWhere((u) => p.ecoByUid(u) == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          DsButton(ref.t('ui.endgame.ecos.sub.upgrade'),
              key: const ValueKey('eco-sub-upgrade'),
              size: DsButtonSize.compact,
              selected: !_fuse,
              onPressed: () => setState(() => _fuse = false)),
          DsButton(ref.t('ui.endgame.ecos.sub.fuse'),
              key: const ValueKey('eco-sub-fuse'),
              size: DsButtonSize.compact,
              selected: _fuse,
              onPressed: () => setState(() {
                    _fuse = true;
                    _justFused = false;
                  })),
        ]),
        SizedBox(height: DsSpace.sm),
        if (_justFused && !_fuse) ...[
          Text(ref.t('ui.endgame.fuse.after'),
              key: const ValueKey('eco-fuse-after'),
              style: DsText.detail(DsColors.success)),
          SizedBox(height: DsSpace.xs),
        ],
        Expanded(child: _fuse ? _fusion(p) : _upgrade(p)),
      ],
    );
  }

  void _toggleFuse(PlayerProfile p, String uid) {
    setState(() {
      if (_fuseSel.remove(uid)) return;
      final e = p.ecoByUid(uid);
      if (e == null) return;
      final first = _fuseSel.isEmpty ? null : p.ecoByUid(_fuseSel.first);
      if (first != null && first.tier != e.tier) _fuseSel.clear();
      if (_fuseSel.length < EcoRules.fuseCount) _fuseSel.add(uid);
    });
  }

  Widget _fusion(PlayerProfile p) {
    final rules = c.engine.progression;
    final n = EcoRules.fuseCount;
    final picked = [
      for (final u in _fuseSel)
        if (p.ecoByUid(u) case final e?) e
    ];
    final (ok, why) = ecoFuseState(view.session, view.actorId, p, _fuseSel);
    String zoneName(int z) =>
        c.engine.catalog.zone(z)?.tr ??
        ref.t('ui.endgame.zone_n', {'zone': z});
    final lines = <String>[];
    if (picked.isNotEmpty) {
      final pre = EcoRules.fusePreview(picked);
      lines
        ..add(ref.t('ui.endgame.fuse.tier', {'tier': pre.tier}))
        ..add(pre.zones.length == 1
            ? ref.t('ui.endgame.fuse.zone', {'zone': zoneName(pre.zones.single)})
            : ref.t('ui.endgame.fuse.zone_random',
                {'zones': pre.zones.map(zoneName).join(', ')}))
        ..add(ref.t('ui.endgame.fuse.rarity', {
          'rarity': pre.rarity.text,
          'mods': ecoModRange(pre.rarity).$1,
        }))
        ..add(EcoRules.fuseAnchors > 0
            ? ref.t('ui.endgame.fuse.cost', {
                'material': CraftMaterial.ancla.endgameTr,
                'n': EcoRules.fuseAnchors,
              })
            : ref.t('ui.endgame.fuse.cost_free'));
    }
    return EcoFusionView(
      key: const ValueKey('eco-fusion'),
      rules: rules,
      ecos: [...p.ecos]..sort((a, b) => a.tier.compareTo(b.tier)),
      selected: _fuseSel,
      onToggle: (u) => _toggleFuse(p, u),
      title: ref.t('ui.endgame.fuse.title'),
      hint: ref.t('ui.endgame.fuse.hint', {'n': n}),
      slots: [
        for (var i = 0; i < n; i++)
          (
            eco: i < picked.length ? picked[i] : null,
            label: i < picked.length
                ? '${ecoNameText(rules.ecos, picked[i])} · T${picked[i].tier}'
                : '${ref.t('ui.endgame.fuse.slot', {
                        'i': i + 1
                      })} · ${ref.t('ui.endgame.fuse.slot_empty')}',
          ),
      ],
      resultTitle: ref.t('ui.endgame.fuse.result'),
      resultLines: lines,
      fuseLabel: ref.t('ui.endgame.fuse.button'),
      clearLabel: ref.t('ui.endgame.fuse.clear'),
      fuseReason: why,
      empty: p.ecos.isEmpty ? ref.t('ui.endgame.ecos.none') : null,
      onClear: _fuseSel.isEmpty ? null : () => setState(_fuseSel.clear),
      onFuse: !ok
          ? null
          : () => setState(() {
                final uids = [..._fuseSel];
                _fuseBefore = {for (final e in p.ecos) e.uid};
                if (c.ecoFuse(uids)) {
                  _fuseSel.clear();
                } else {
                  _fuseBefore = null;
                }
              }),
    );
  }

  /// The material of an upgrade as an item cell with `have/need`.
  DsCostEntry _cost(PlayerProfile p, CraftMaterial m, int need) {
    final (icon, color) = iconForStack(StackKind.of(m));
    final have = p.material(m);
    return DsCostEntry(
      id: m.name,
      icon: PixelIcon(icon, accent: color, size: 32),
      need: need,
      have: have,
      card: DsTooltipCard(title: m.endgameTr, children: [
        Text(ref.t('ui.endgame.craft.have_need', {'have': have, 'need': need})),
      ]),
    );
  }

  Widget _upgrade(PlayerProfile p) {
    final rules = c.engine.progression;
    final s = view.session;
    final ecos = p.ecos;
    EcoItem? sel;
    for (final e in ecos) {
      if (e.uid == _sel) sel = e;
    }
    sel ??= ecos.isEmpty ? null : ecos.first;
    final e = sel;
    String zoneName(int z) =>
        c.engine.catalog.zone(z)?.tr ??
        ref.t('ui.endgame.zone_n', {'zone': z});
    final (ready, status) = e == null
        ? (false, '')
        : ecoStatusText(p, e,
            zoneName: zoneName(e.zone),
            biomeName: switch (EcoPortalRules.of(e.zone)) {
              final spot? => biomeDef(spot.biome)?.name ?? spot.biome,
              null => null,
            });
    return EcoUpgradeView(
      key: const ValueKey('eco-upgrade'),
      rules: rules,
      ecos: ecos,
      selected: e,
      onSelect: (u) => setState(() => _sel = u),
      empty: ref.t('ui.endgame.ecos.none'),
      info: e == null
          ? const SizedBox.shrink()
          : ProtoText(
              key: const ValueKey('eco-detail'),
              ecoTooltipMarkup(rules, e,
                  atlas: c.engine.atlasOf(s), players: s.players.length)),
      statusText: status,
      statusReady: ready,
      opensAt: ref.t('ui.endgame.ecos.opens_at'),
      goLabel: ref.t('ui.endgame.go_to_portal'),
      // Ecos open at their zone's portal (ecos_zone.md § 4): here you
      // only travel there.
      goReason: e == null ? null : c.ecoTravelBlocked(e.zone),
      onGo: () {
        if (e != null) c.travelToEcoPortal(e.zone, tier: e.tier);
      },
      upgradesTitle: ref.t('ui.endgame.ecos.upgrade_title'),
      applyLabel: ref.t('ui.endgame.ecos.apply'),
      ops: e == null
          ? const []
          : [
              for (final op in EcoCraftOp.values)
                EcoUpgradeOp(
                  id: op.name,
                  label: ref.t('ui.endgame.craft.op.${op.name}'),
                  effect: ref.t('ui.endgame.craft.effect.${op.name}'),
                  cost: switch (EcoRules.cost(e, op)) {
                    (final m, final n) => _cost(p, m, n),
                    null => null,
                  },
                  reason: ecoCraftBlocked(s, view.actorId, p, e, op),
                  onApply: () => setState(() => c.ecoCraft(e.uid, op)),
                ),
            ],
      footer: [
        if (FeatureFlags.instance.devTools)
          Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
            for (final t in const [1, 8, 16])
              PanelButton('DEV: +ECO T$t',
                  key: ValueKey('eco-dev-$t'),
                  onPressed: () => setState(() => c.devGrantEco(t))),
          ]),
      ],
    );
  }
}
