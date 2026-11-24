import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_type.dart';
import '../../combat/presentation/battle_hud.dart' show HudHighlight;
import '../../../game_engine/models/session_action.dart' show TutorialControl;
import '../../../game_engine/rules/tutorial_rules.dart';
import '../../../core/i18n/battle_log_text.dart';
import '../../../core/i18n/data_text.dart';
import '../../../core/i18n/i18n_providers.dart';

// TUTORIAL: Ecos de práctica (docs/specs/combat_tutorial.md): el detalle
// del sello, el cartel del paso, el cartel de efecto, el menú del
// tutorial y el glosario. Sin negritas: el énfasis va por color.

TextStyle _body(Color color, [double? size]) => TextStyle(
    fontFamily: RetroType.bodyFamily,
    fontFamilyFallback: RetroType.bodyFallback,
    letterSpacing: RetroType.letterSpacing,
    fontSize: size ?? RetroType.small,
    color: color);

TextStyle _title(Color color, [double size = RetroType.label]) =>
    TextStyle(fontFamily: RetroType.titleFamily, fontSize: size, color: color);

/// El glosario (§ 5): una entrada por concepto con su ícono.
class GlossaryView extends StatelessWidget {
  const GlossaryView({super.key, required this.entries});

  final List<GlossaryEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
        key: const ValueKey('tutorial-glossary'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    alignment: Alignment.center,
                    color: ProtoColors.barBg,
                    child: Text(g.icon, style: _title(ProtoColors.sky, 8)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '${retroText(g.title)}: ',
                          style: _body(ProtoColors.gold)),
                      TextSpan(
                          text: retroText(g.text),
                          style: _body(ProtoColors.ink)),
                    ])),
                  ),
                ],
              ),
            ),
        ],
      );
}

/// Detalle de TUTORIAL: Ecos de práctica en el sello (§ 1).
class TutorialSealDetail extends ConsumerStatefulWidget {
  const TutorialSealDetail({
    super.key,
    required this.rules,
    required this.done,
    required this.humans,
    required this.companions,
    required this.isHost,
    required this.onStart,
    this.lockText,
  });

  final TutorialRules rules;

  /// La cuenta local ya lo tiene vigente (el botón dice REPETIR).
  final bool done;

  /// Humanos en la sala y compañeros de la party.
  final int humans;
  final int companions;

  /// Este jugador es el host (en grupo, solo él lo inicia).
  final bool isHost;

  /// Empieza; `companions` = con los de la party.
  final void Function(bool companions) onStart;

  /// "Primero, todos tienen que hacer el TUTORIAL. Falta: …".
  final String? lockText;

  @override
  ConsumerState<TutorialSealDetail> createState() => _TutorialSealDetailState();
}

class _TutorialSealDetailState extends ConsumerState<TutorialSealDetail> {
  bool _glossary = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final group = w.humans > 1;
    final hostOnly =
        group && !w.isHost ? ref.t('ui.tutorial.host_starts') : null;
    final verb = w.done ? 'repeat' : 'start';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: _glossary
                ? GlossaryView(entries: w.rules.glossary())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(TutorialRules.name, style: _title(ProtoColors.gold)),
                      const SizedBox(height: 6),
                      Text(
                          w.done
                              ? ref.t('ui.tutorial.seal.done')
                              : ref.t('ui.tutorial.seal.required'),
                          style: _body(
                              w.done ? ProtoColors.green : ProtoColors.orange)),
                      if (w.lockText case final l?) ...[
                        const SizedBox(height: 4),
                        Text(l, style: _body(ProtoColors.red)),
                      ],
                      const SizedBox(height: 8),
                      Text(
                          ref.t('ui.tutorial.seal.about'),
                          style: _body(ProtoColors.ink)),
                      const SizedBox(height: 8),
                      for (final s in w.rules.stages)
                        Text('${s.number}. ${ref.strings.data('ui.tutorial.stage.${s.number}.title', s.title)}: ${ref.strings.data('ui.tutorial.stage.${s.number}.teaches', s.teaches)}',
                            style: _body(ProtoColors.dim)),
                      Text(
                          ref.t('ui.tutorial.seal.after'),
                          style: _body(ProtoColors.dim)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          runSpacing: 4,
          children: [
            if (group)
              PanelButton(ref.t('ui.tutorial.start_group', {'verb': verb}),
                  key: const ValueKey('tutorial-group'),
                  accent: ProtoColors.green,
                  reason: hostOnly,
                  onPressed: () => w.onStart(false))
            else ...[
              PanelButton(ref.t('ui.tutorial.start_solo', {'verb': verb}),
                  key: const ValueKey('tutorial-solo'),
                  accent: ProtoColors.green,
                  onPressed: () => w.onStart(false)),
              if (w.companions > 0)
                PanelButton(
                    ref.t('ui.tutorial.start_party', {'verb': verb}),
                    key: const ValueKey('tutorial-party'),
                    accent: ProtoColors.green,
                    onPressed: () => w.onStart(true)),
            ],
            PanelButton(
                ref.t(_glossary
                    ? 'ui.tutorial.back'
                    : 'ui.tutorial.glossary'),
                key: const ValueKey('tutorial-glossary-toggle'),
                onPressed: () => setState(() => _glossary = !_glossary)),
          ],
        ),
      ],
    );
  }
}

/// Lo que el cartel de efecto señala (§ 4.1), dicho en palabras: la
/// flecha apunta a la barra o al estado que cambió.
String tutorialArrowText(Strings t, TutorialArrow? a) =>
    a == null ? '' : t.t('ui.tutorial.arrow.${a.name}');

/// La pelea del TUTORIAL con su panel lateral fijo (§ 4.1): la arena se
/// achica y el panel ocupa una columna a la derecha, así nunca tapa
/// personajes, enemigos, números de daño ni el menú. El panel dice la
/// etapa, quién actúa, lo que pasó en la última acción y la votación
/// SIGUIENTE. El menú del tutorial (Repetir etapa, Repetir, Glosario,
/// Salir) se abre encima de todo.
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.battle,
    required this.banner,
    required this.card,
    required this.rules,
    required this.onNext,
    required this.onControl,
    this.last,
    this.waitingText,
    this.voted = false,
    this.hud = const {},
    this.canControl = true,
    this.options = const [],
    this.pickLines = const [],
    this.myPick,
    this.onPick,
    this.narration = const [],
  });

  /// Votación abierta del final (§ 4.4): (id, rótulo) de cada opción.
  final List<(String, String)> options;

  /// "Ana: QUIEBRA", "Beto: eligiendo…" y el motivo si no hay acuerdo.
  final List<String> pickLines;

  /// Lo que eligió este jugador.
  final String? myPick;
  final void Function(String choice)? onPick;

  /// ENTRENAR: lo que narra el panel (lo último abajo).
  final List<String> narration;

  /// La escena de batalla (va a la izquierda del panel).
  final Widget battle;

  final TutorialBanner? banner;

  /// El cartel abierto (espera la votación).
  final TutorialCard? card;

  /// El último cartel de efecto, ya cerrado.
  final TutorialCard? last;
  final TutorialRules rules;

  /// SIGUIENTE: el voto de este jugador.
  final VoidCallback onNext;
  final void Function(TutorialControl op) onControl;

  /// "Esperando: Beto".
  final String? waitingText;

  /// Este jugador ya votó.
  final bool voted;

  /// Qué resaltar en el HUD (`HudHighlight.mp` / `.pulse`).
  final Set<String> hud;

  /// En grupo, solo el host repite o sale.
  final bool canControl;

  /// Ancho de la columna del panel para un área de [width].
  static double panelWidth(double width) =>
      (width * 0.24).clamp(180.0, 320.0).roundToDouble();

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  bool _menu = false;
  bool _glossary = false;

  // Panel lateral con el sistema de diseño (design_system.md § 10.3):
  // `DsCard`, secciones con `DsSectionHeader`, jerarquía por color.
  Widget _section(String label, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [DsSectionHeader(label), ...children],
      );

  Widget _line(String text, Color color, {Key? key, bool detail = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: DsSpace.xs),
        child: Text(retroText(text),
            key: key,
            style: detail ? DsText.detail(color) : DsText.body(color)),
      );

  Widget _panel() {
    final w = widget;
    final b = w.banner;
    final card = w.card;
    final last = w.last;
    final head = b?.stage ?? '';
    return DsCard(
      key: const ValueKey('tutorial-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    head.isEmpty
                        ? ref.t('ui.tutorial.title')
                        : retroText(head),
                    style: DsText.subtitle(DsColors.textTitle)),
              ),
              // ≡ como ícono (la fuente pixel no tiene el glifo).
              DsButton.icon(const Icon(Icons.menu, size: 16),
                  key: const ValueKey('tutorial-menu'),
                  size: DsButtonSize.compact,
                  tooltip: ref.t('ui.tutorial.menu'),
                  onPressed: () => setState(() {
                        _menu = !_menu;
                        _glossary = false;
                      })),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (w.options.isNotEmpty)
                    _section(ref.t('ui.tutorial.section.vote'), [
                      if (b != null && b.text.isNotEmpty)
                        _line(b.text, DsColors.textTitle),
                      for (final (id, label) in w.options)
                        Padding(
                          padding: EdgeInsets.only(bottom: DsSpace.xs),
                          child: DsButton(label,
                              key: ValueKey('tutorial-pick-$id'),
                              selected: w.myPick == id,
                              onPressed: () => w.onPick?.call(id)),
                        ),
                      for (final l in w.pickLines)
                        _line(
                            l,
                            l.startsWith('Hay ') || l.startsWith('Falta ')
                                ? DsColors.warning
                                : DsColors.textPrimary),
                      _line(ref.t('ui.tutorial.all_must_vote'),
                          DsColors.textSecondary,
                          detail: true),
                    ])
                  else if (w.narration.isNotEmpty && card == null) ...[
                    if (b != null && b.text.isNotEmpty)
                      _section(ref.t('ui.tutorial.section.now'), [
                        _line(
                            b.text,
                            b.yourTurn
                                ? DsColors.textTitle
                                : DsColors.textSubtitle,
                            key: const ValueKey('tutorial-now')),
                      ]),
                    _section(ref.t('ui.tutorial.section.happening'), [
                      for (final (i, l) in w.narration.indexed)
                        _line(
                            l,
                            i == w.narration.length - 1
                                ? DsColors.textPrimary
                                : DsColors.textSecondary,
                            key: const ValueKey('tutorial-narration')),
                    ]),
                  ] else if (card != null)
                    _section(
                        card.heading ??
                            ref.t(card.effect
                                ? 'ui.tutorial.section.happened'
                                : 'ui.tutorial.section.stage'),
                        [
                          for (final l in [
                            ...card.lines,
                            if (!card.log.isEmpty)
                              battleLogText(card.log, strings: ref.strings),
                          ])
                            _line(l, DsColors.textPrimary,
                                key: const ValueKey('tutorial-card-line')),
                          if (tutorialArrowText(ref.strings, card.arrow) case final a
                              when a.isNotEmpty)
                            _line(a, DsColors.warning),
                        ])
                  else ...[
                    if (b != null && b.text.isNotEmpty)
                      _section(ref.t('ui.tutorial.section.now'), [
                        _line(
                            b.text,
                            b.yourTurn
                                ? DsColors.textTitle
                                : DsColors.textSubtitle,
                            key: const ValueKey('tutorial-now')),
                      ]),
                    if (last != null)
                      _section(ref.t('ui.tutorial.section.last_action'), [
                        for (final l in [
                          ...last.lines,
                          if (!last.log.isEmpty)
                            battleLogText(last.log, strings: ref.strings),
                        ])
                          _line(l, DsColors.textSecondary),
                      ]),
                  ],
                ],
              ),
            ),
          ),
          if (card != null) ...[
            SizedBox(height: DsSpace.sm),
            if (w.waitingText case final t?)
              _line(t, DsColors.warning,
                  key: const ValueKey('tutorial-waiting')),
            if (w.voted)
              _line(ref.t('ui.tutorial.voted_next'), DsColors.success,
                  key: const ValueKey('tutorial-voted'))
            else
              DsButton(ref.t('ui.tutorial.next'),
                  key: const ValueKey('tutorial-next'),
                  kind: DsButtonKind.primary,
                  onPressed: w.onNext),
            SizedBox(height: DsSpace.xs),
            Text(ref.t('ui.tutorial.next_hint'), style: DsText.detail()),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return LayoutBuilder(builder: (context, box) {
      final pw = TutorialOverlay.panelWidth(box.maxWidth);
      return Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            right: pw,
            child: HudHighlight(parts: w.hud, child: w.battle),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: pw,
            child: _panel(),
          ),
          if (_menu)
            Positioned.fill(
              child: ColoredBox(
                color: ProtoColors.scrim(0.6),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 620, maxHeight: 460),
                    child: RetroPanel(
                      key: const ValueKey('tutorial-menu-panel'),
                      selected: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(TutorialRules.name,
                              style: _title(ProtoColors.gold)),
                          const SizedBox(height: 8),
                          if (_glossary)
                            Flexible(
                              child: SingleChildScrollView(
                                child:
                                    GlossaryView(entries: w.rules.glossary()),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            children: [
                              PanelButton(ref.t('ui.tutorial.resume'),
                                  accent: ProtoColors.green,
                                  onPressed: () =>
                                      setState(() => _menu = false)),
                              PanelButton(
                                  ref.t(_glossary
                                      ? 'ui.tutorial.hide_glossary'
                                      : 'ui.tutorial.glossary'),
                                  key: const ValueKey('tutorial-menu-glossary'),
                                  onPressed: () =>
                                      setState(() => _glossary = !_glossary)),
                              for (final op in const [
                                TutorialControl.repeatStage,
                                TutorialControl.repeat,
                                TutorialControl.exit,
                              ])
                                PanelButton(ref.t('ui.tutorial.control.${op.name}'),
                                    key: ValueKey('tutorial-${op.name}'),
                                    reason: w.canControl
                                        ? null
                                        : ref.t('ui.tutorial.host_decides'),
                                    onPressed: () {
                                  setState(() => _menu = false);
                                  w.onControl(op);
                                }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// `HudHighlight` de las flechas de [hud] (MP y Pulso).
Set<String> tutorialHudParts(Set<TutorialArrow> hud) => {
      if (hud.contains(TutorialArrow.mp)) HudHighlight.mp,
      if (hud.contains(TutorialArrow.pulse)) HudHighlight.pulse,
    };
