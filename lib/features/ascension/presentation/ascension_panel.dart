import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../game_engine/data/trials_catalog.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/ascension_rules.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/panels/party_member_bar.dart';
import '../../world/presentation/session_view.dart';
import '../domain/ascension_text.dart';
import 'ascension_views.dart';
import '../../../core/i18n/i18n_providers.dart';

/// Pestañas de la Estatua del Tiempo.
enum AscensionTab {
  trials,
  ascension;

  /// Keys of the tab label and its hint (`ui.ascension.tab.<name>.*`).
  String get labelKey => 'ui.ascension.tab.$name.label';
  String get hintKey => 'ui.ascension.tab.$name.hint';
}

/// Ayuda del panel (markup).
const kAscensionHelpKey = 'ui.ascension.help';

/// La Estatua del Tiempo (docs/specs/ascension.md § 1-3).
class AscensionPanel extends ConsumerStatefulWidget {
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
  ConsumerState<AscensionPanel> createState() => _AscensionPanelState();
}

class _AscensionPanelState extends ConsumerState<AscensionPanel> {
  late var _tab = widget.initialTab ??
      (widget.view.actor!.profile.ascension.trials.isEmpty
          ? AscensionTab.trials
          : AscensionTab.ascension);
  int? _sel;

  SessionController get c => widget.controller;
  SessionView get view => widget.view;

  @override
  Widget build(BuildContext context) {
    // El miembro activo (solo_party.md § 6): su ascensión. Las Pruebas
    // son propuestas de grupo: siempre las del líder.
    final p = view.actor!.profile;
    final a = const AscensionRules().of(p);
    // Q / E, Ctrl+Tab y 1-9 cambian de pestaña (menu_focus.dart).
    return PartyMemberKeys(
      view: view,
      controller: c,
      child: MenuTabKeys(
        count: AscensionTab.values.length,
        index: _tab.index,
        onChanged: (i) => setState(() => _tab = AscensionTab.values[i]),
        child: PanelFrame(
          title: ref.t('ui.ascension.title'),
          width: 1040,
          fill: true,
          help: ref.t(kAscensionHelpKey),
          onClose: c.closePanel,
          titleTrailing: ProtoText(
              key: const ValueKey('asc-title-points'),
              protoEsc(trialsSummary(p.ascension))),
          header: PartyMemberBar.header(
              view,
              c,
              PanelTabs(
                labels: [
                  for (final t in AscensionTab.values) ref.t(t.labelKey)
                ],
                index: _tab.index,
                onChanged: (i) => setState(() => _tab = AscensionTab.values[i]),
              )),
          actions: [PanelButton(ref.t('ui.ascension.close'), onPressed: c.closePanel)],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHint(ref.t(_tab.hintKey)),
              Expanded(
                child: switch (_tab) {
                  AscensionTab.trials => _trials(view.me!.profile),
                  AscensionTab.ascension => a == null
                      ? _choice(p)
                      : AscensionTreeView(
                          key: const ValueKey('asc-tree'),
                          def: a,
                          progress: p.ascension,
                          sprites: widget.sprites,
                          editBlocked: view.session.mode == SessionMode.battle
                              ? ref.t('ui.ascension.not_in_battle')
                              : null,
                          onTake: (id) =>
                              setState(() => c.takeAscensionNode(id)),
                          onReset: () => setState(() => c.resetAscension()),
                          onChange: view.session.canShop
                              ? () =>
                                  setState(() => c.resetAscension(full: true))
                              : null,
                        ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(PlayerProfile p) {
    if (!p.ascension.trials.contains(1)) {
      return Center(
        child: ProtoText(protoColor(ProtoColors.dim,
            ref.t('ui.ascension.need_first_trial'))),
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
        return protoColor(ProtoColors.green, ref.t('ui.ascension.trial.cleared'));
      }
      final why = rules.cannotPropose(p, t.number);
      return why == null
          ? protoColor(ProtoColors.gold, ref.t('ui.ascension.trial.available'))
          : protoColor(ProtoColors.dim, protoEsc(why));
    }

    final dev = FeatureFlags.instance.devTools;
    final boss = c.engine.catalog.zone(sel.bossZone)?.bossName ?? '?';
    final zone = c.engine.catalog.zone(sel.zone)?.name ?? '?';
    final voteOpen = s.vote != null;
    final why = rules.cannotPropose(p, sel.number) ??
        (s.mode != SessionMode.lobby
            ? ref.t('ui.ascension.only_in_town')
            : voteOpen
                ? ref.t('ui.ascension.vote_open')
                : null);
    return PanelSplit(
      listWidth: 380,
      list: [
        for (final t in kTrials)
          MenuRow(
            key: ValueKey('trial-row-${t.number}'),
            selected: t.number == sel.number,
            onTap: () => setState(() => _sel = t.number),
            label: ref.t('ui.ascension.trial.row',
                {'roman': t.roman, 'name': protoEsc(t.name)}),
            // Una palabra: el motivo largo va en el detalle.
            value: p.ascension.trials.contains(t.number)
                ? protoColor(ProtoColors.green, ref.t('ui.ascension.trial.cleared'))
                : protoColor(
                    rules.cannotPropose(p, t.number) == null
                        ? ProtoColors.gold
                        : ProtoColors.dim,
                    ref.t('ui.ascension.trial.level_short', {'level': t.level})),
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
          KeyHints(
              confirm: ref.t('ui.ascension.hint.choose'),
              back: ref.t('ui.ascension.hint.close')),
          PanelButton(ref.t('ui.ascension.propose'),
              key: const ValueKey('trial-propose'),
              accent: ProtoColors.violet,
              reason: why, onPressed: () {
            if (c.proposeTrial(sel.number)) c.closePanel();
          }),
        ],
        children: [
          // Ficha corta: una línea por dato, las trampas en el tip "?".
          ProtoText(
              key: const ValueKey('trial-detail'),
              ref.t('ui.ascension.trial.detail', {
                'name': protoEsc(sel.fullName),
                'state': state(sel),
                'level': sel.level,
                'hasRequires': sel.number > 1 ? 'yes' : 'no',
                'requires': sel.number > 1 ? kTrials[sel.number - 2].roman : '',
                'zone': protoEsc(zone),
                'floors': sel.floors,
                'monsterLevel': sel.monsterLevel,
                'boss': protoEsc(boss),
                'spikes': sel.spikes,
                'spikeDamage': protoColor(
                    ProtoColors.crimson,
                    ref.t('ui.ascension.trial.spike_damage',
                        {'pct': (sel.spikeDamage * 100).round()})),
                'pulses': sel.pulses,
                'pulseWord': protoColor(
                    ProtoColors.violet, ref.t('ui.ascension.trial.pulses')),
                'prize': protoColor(
                    ProtoColors.gold, ref.t('ui.ascension.trial.prize')),
                'first': sel.number == 1 ? 'yes' : 'no',
              })),
        ],
      ),
    );
  }
}
