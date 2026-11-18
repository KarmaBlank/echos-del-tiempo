import 'package:material_ui/material_ui.dart';

import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
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
import '../../world/presentation/session_view.dart';
import '../domain/endgame_text.dart';
import 'atlas_view.dart';

/// Pestañas del Portal del Eco.
enum EcoPortalTab {
  ecos('ECOS', 'Elegí un Eco: ABRIR lo propone al grupo; los materiales lo mejoran.'),
  atlas('ATLAS',
      'Árbol de la cuenta: ganás puntos al completar algo por primera vez.');

  const EcoPortalTab(this.label, this.hint);
  final String label;
  final String hint;
}

/// Portal del Eco del pueblo (docs/specs/ecos_atlas.md § 1, § 4, § 5):
/// ECOS (lista + ficha, abrir y craftear) y ATLAS (el árbol de la cuenta).
class EcoPortalPanel extends StatefulWidget {
  const EcoPortalPanel({
    super.key,
    required this.view,
    required this.controller,
    this.initialTab = EcoPortalTab.ecos,
  });

  final SessionView view;
  final SessionController controller;
  final EcoPortalTab initialTab;

  @override
  State<EcoPortalPanel> createState() => _EcoPortalPanelState();
}

class _EcoPortalPanelState extends State<EcoPortalPanel> {
  late var _tab = widget.initialTab;
  String? _sel;

  SessionController get c => widget.controller;
  SessionView get view => widget.view;

  @override
  Widget build(BuildContext context) {
    final me = view.me!;
    final p = me.profile;
    final atlas = view.atlas ?? c.atlas;
    final free = c.engine.atlasRules.free(atlas);
    return PanelFrame(
      title: 'PORTAL DEL ECO',
      width: 1040,
      fill: true,
      help: kEcoPortalHelp,
      onClose: c.closePanel,
      titleTrailing: ProtoText(
          key: const ValueKey('portal-points'),
          'Atlas: <b>$free</b> punto${free == 1 ? '' : 's'} libre'
          '${free == 1 ? '' : 's'}'),
      header: PanelTabs(
        labels: [for (final t in EcoPortalTab.values) t.label],
        index: _tab.index,
        onChanged: (i) => setState(() => _tab = EcoPortalTab.values[i]),
      ),
      actions: [
        PanelButton('CERRAR [ESC]', onPressed: c.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!p.ecosUnlocked)
            PanelHint(protoColor(
                ProtoColors.orange,
                'Portal apagado: vencé al Devorador de Eras (Corazón del '
                'Tiempo) para activarlo. Los Ecos que caigan se guardan.')),
          PanelHint(_tab.hint),
          Expanded(
            child: switch (_tab) {
              EcoPortalTab.ecos => _ecos(p),
              EcoPortalTab.atlas => _atlas(atlas),
            },
          ),
        ],
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
      editBlocked: c.canEditAtlas ? null : 'Solo en el pueblo',
      onTake: (id) => setState(() => c.takeAtlasNode(id)),
      onReset: () => setState(() => c.resetAtlas()),
      note: remote
          ? 'En grupo vale el Atlas del anfitrión; tus puntos se guardan en '
              'tu cuenta.'
          : s.players.length > 1
              ? 'Tu Atlas vale para todo el grupo.'
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
            'No tenés Ecos. Caen de enemigos de nivel 45 o más (zonas 9 y '
            '10) y al completar otros Ecos.')),
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
        MenuHeader('MEJORAR ${protoColor(ProtoColors.dim, '· tienes '
            'Esquirla ${p.material(CraftMaterial.esquirla)}'
            ' · Cristal ${p.material(CraftMaterial.cristal)}'
            ' · Prisma ${p.material(CraftMaterial.prisma)}'
            ' · Ancla ${p.material(CraftMaterial.ancla)}')}'),
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
                PanelButton('USAR',
                    key: ValueKey('eco-craft-${op.name}'),
                    reason: ecoCraftBlocked(s, view.localId, p, e, op),
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
                const KeyHints(confirm: 'Elegir', back: 'Cerrar'),
                PanelButton('ABRIR ECO',
                    key: const ValueKey('eco-open'),
                    accent: ProtoColors.green,
                    reason: ecoOpenBlocked(s, p, e), onPressed: () {
                  if (c.proposeEco(e.uid)) c.closePanel();
                }),
              ],
        children: e == null
            ? [
                ProtoText(protoColor(ProtoColors.dim,
                    'Elegí un Eco de la lista para ver su ficha.')),
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
