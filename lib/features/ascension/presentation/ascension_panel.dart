import 'package:material_ui/material_ui.dart';

import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/data/trials_catalog.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/ascension_rules.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import '../domain/ascension_text.dart';
import 'ascension_views.dart';

/// Pestañas de la Estatua del Tiempo.
enum AscensionTab {
  trials(
      'PRUEBAS',
      'Mazmorras con trampas y un jefe. Cada Prueba superada da 2 puntos de '
          'ascensión a cada uno que la cumple.'),
  ascension(
      'ASCENSIÓN',
      'Tu subclase: elegí 1 de 2 con la Prueba I y gastá los puntos en su '
          'mini-árbol. Reiniciar y cambiar es gratis.');

  const AscensionTab(this.label, this.hint);
  final String label;
  final String hint;
}

/// Ayuda del panel (markup).
const kAscensionHelp = '<b>Estatua del Tiempo</b><br>'
    'PRUEBAS: niveles 30, 40 y 50, en orden. Púas: −vida cada segundo. '
    'Pulso del Tiempo (violeta): cuando brilla te devuelve al inicio del '
    'piso.<br>ASCENSIÓN: 6 puntos en total (2 por Prueba), 10 de costo en '
    'el árbol: elegí.';

/// La Estatua del Tiempo (docs/specs/ascension.md § 1-3).
class AscensionPanel extends StatefulWidget {
  const AscensionPanel({
    super.key,
    required this.view,
    required this.controller,
    this.sprites,
    this.initialTab,
  });

  final SessionView view;
  final SessionController controller;
  final GameSprites? sprites;
  final AscensionTab? initialTab;

  @override
  State<AscensionPanel> createState() => _AscensionPanelState();
}

class _AscensionPanelState extends State<AscensionPanel> {
  late var _tab = widget.initialTab ??
      (widget.view.me!.profile.ascension.trials.isEmpty
          ? AscensionTab.trials
          : AscensionTab.ascension);
  int? _sel;

  SessionController get c => widget.controller;
  SessionView get view => widget.view;

  @override
  Widget build(BuildContext context) {
    final p = view.me!.profile;
    final a = const AscensionRules().of(p);
    return PanelFrame(
      title: 'ESTATUA DEL TIEMPO',
      width: 1040,
      fill: true,
      help: kAscensionHelp,
      onClose: c.closePanel,
      titleTrailing: ProtoText(
          key: const ValueKey('asc-title-points'),
          protoEsc(trialsSummary(p.ascension))),
      header: PanelTabs(
        labels: [for (final t in AscensionTab.values) t.label],
        index: _tab.index,
        onChanged: (i) => setState(() => _tab = AscensionTab.values[i]),
      ),
      actions: [PanelButton('CERRAR [ESC]', onPressed: c.closePanel)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHint(_tab.hint),
          Expanded(
            child: switch (_tab) {
              AscensionTab.trials => _trials(p),
              AscensionTab.ascension => a == null
                  ? _choice(p)
                  : AscensionTreeView(
                      key: const ValueKey('asc-tree'),
                      def: a,
                      progress: p.ascension,
                      sprites: widget.sprites,
                      editBlocked: view.session.mode == SessionMode.battle
                          ? 'No en batalla'
                          : null,
                      onTake: (id) => setState(() => c.takeAscensionNode(id)),
                      onReset: () => setState(() => c.resetAscension()),
                      onChange: view.session.canShop
                          ? () => setState(() => c.resetAscension(full: true))
                          : null,
                    ),
            },
          ),
        ],
      ),
    );
  }

  Widget _choice(PlayerProfile p) {
    if (!p.ascension.trials.contains(1)) {
      return Center(
        child: ProtoText(protoColor(ProtoColors.dim,
            'Superá la Prueba del Tiempo I (nivel 30) para ascender.')),
      );
    }
    return AscensionChoiceView(
      key: const ValueKey('asc-choice'),
      classId: p.classId,
      sprites: widget.sprites,
      onChoose: (id) {
        if (c.chooseAscension(id)) c.closePanel();
      },
    );
  }

  Widget _trials(PlayerProfile p) {
    final rules = c.engine.trialRules;
    final s = view.session;
    final sel = trialDef(_sel) ??
        kTrials.firstWhere((t) => !p.ascension.trials.contains(t.number),
            orElse: () => kTrials.last);
    String state(TrialDef t) {
      if (p.ascension.trials.contains(t.number)) {
        return protoColor(ProtoColors.green, 'Superada');
      }
      final why = rules.cannotPropose(p, t.number);
      return why == null
          ? protoColor(ProtoColors.gold, 'Disponible')
          : protoColor(ProtoColors.dim, protoEsc(why));
    }

    final dev = FeatureFlags.instance.devTools;
    final boss = c.engine.catalog.zone(sel.bossZone)?.bossName ?? '?';
    final zone = c.engine.catalog.zone(sel.zone)?.name ?? '?';
    final voteOpen = s.vote != null;
    final why = rules.cannotPropose(p, sel.number) ??
        (s.mode != SessionMode.lobby
            ? 'Solo en el pueblo'
            : voteOpen
                ? 'Ya hay una votación'
                : null);
    return PanelSplit(
      listWidth: 380,
      list: [
        for (final t in kTrials)
          PanelListItem(
            key: ValueKey('trial-row-${t.number}'),
            selected: t.number == sel.number,
            onTap: () => setState(() => _sel = t.number),
            child: ProtoText('<b>Prueba ${t.roman} · ${protoEsc(t.name)}</b>'
                '<br><small>Nivel ${t.level} · ${state(t)}</small>'),
          ),
        if (dev) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in kTrials)
              PanelButton('DEV: PRUEBA ${t.roman}',
                  key: ValueKey('trial-dev-${t.number}'),
                  onPressed: () => setState(() => c.devGrantTrial(t.number))),
          ]),
        ],
      ],
      detail: PanelDetail(
        footer: [
          PanelButton('PROPONER PRUEBA',
              key: const ValueKey('trial-propose'),
              accent: ProtoColors.violet,
              reason: why, onPressed: () {
            if (c.proposeTrial(sel.number)) c.closePanel();
          }),
        ],
        children: [
          ProtoText(
              key: const ValueKey('trial-detail'),
              '<b style="color:#a29bfe">${protoEsc(sel.fullName)}</b><br>'
              '${state(sel)}<br><br>'
              'Nivel pedido: <b>${sel.level}</b>'
              '${sel.number > 1 ? ' · requiere la Prueba ${kTrials[sel.number - 2].roman}' : ''}<br>'
              'Mazmorra: ${protoEsc(zone)} · ${sel.floors} pisos · monstruos '
              'nivel ${sel.monsterLevel}<br>'
              'Jefe: <b>${protoEsc(boss)}</b><br><br>'
              '<b>Trampas</b> (por piso)<br>'
              '· ${sel.spikes} campos de púas: '
              '${protoColor(ProtoColors.crimson, '−${(sel.spikeDamage * 100).round()}% de vida')} '
              'por segundo encima (no matan)<br>'
              '· ${sel.pulses} Pulsos del Tiempo: cargan 2 s y '
              '${protoColor(ProtoColors.violet, 'te devuelven al inicio del piso')}'
              ' si estás encima cuando brillan<br><br>'
              '<b>Recompensa</b><br>'
              '${protoColor(ProtoColors.gold, '+2 puntos de ascensión')} la primera '
              'vez (cada jugador del grupo que la cumple gana los suyos)'
              '${sel.number == 1 ? '<br>y desbloquea la elección de ascensión' : ''}'),
        ],
      ),
    );
  }
}
