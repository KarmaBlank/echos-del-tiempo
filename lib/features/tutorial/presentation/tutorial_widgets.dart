import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_type.dart';
import '../../../game_engine/models/session_action.dart' show TutorialControl;
import '../../../game_engine/rules/tutorial_rules.dart';

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
class TutorialSealDetail extends StatefulWidget {
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
  State<TutorialSealDetail> createState() => _TutorialSealDetailState();
}

class _TutorialSealDetailState extends State<TutorialSealDetail> {
  bool _glossary = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final group = w.humans > 1;
    final hostOnly = group && !w.isHost ? 'Lo inicia el host' : null;
    final verb = w.done ? 'REPETIR' : 'EMPEZAR';
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
                              ? 'Completado. Podés repetirlo cuando quieras.'
                              : 'Obligatorio antes de la primera misión (uno '
                                  'por cuenta).',
                          style: _body(
                              w.done ? ProtoColors.green : ProtoColors.orange)),
                      if (w.lockText case final l?) ...[
                        const SizedBox(height: 4),
                        Text(l, style: _body(ProtoColors.red)),
                      ],
                      const SizedBox(height: 8),
                      Text(
                          'Una pelea de práctica contra un autómata de '
                          'entrenamiento: no da XP ni loot, no gasta pociones '
                          'y la vida y el MP vuelven a como estaban.',
                          style: _body(ProtoColors.ink)),
                      const SizedBox(height: 8),
                      for (final s in w.rules.stages)
                        Text('${s.number}. ${s.title}: ${s.teaches}',
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
              PanelButton('$verb EN GRUPO',
                  key: const ValueKey('tutorial-group'),
                  accent: ProtoColors.green,
                  reason: hostOnly,
                  onPressed: () => w.onStart(false))
            else ...[
              PanelButton('$verb SOLO',
                  key: const ValueKey('tutorial-solo'),
                  accent: ProtoColors.green,
                  onPressed: () => w.onStart(false)),
              if (w.companions > 0)
                PanelButton('$verb CON COMPAÑEROS',
                    key: const ValueKey('tutorial-party'),
                    accent: ProtoColors.green,
                    onPressed: () => w.onStart(true)),
            ],
            PanelButton(_glossary ? 'VOLVER' : 'GLOSARIO',
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
String tutorialArrowText(TutorialArrow? a) => switch (a) {
      TutorialArrow.timeline => '↑ barra de turnos',
      TutorialArrow.hp => '→ vida',
      TutorialArrow.mp => '↓ MP',
      TutorialArrow.pulse => '↓ Pulso',
      TutorialArrow.status => '→ estados del objetivo',
      TutorialArrow.breakBar => '→ barra de quiebre',
      TutorialArrow.ult => '→ ULT',
      null => '',
    };

/// El cartel del paso arriba, el de efecto abajo y el menú del
/// tutorial (Repetir etapa, Repetir, Glosario, Salir) en la batalla.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.banner,
    required this.card,
    required this.rules,
    required this.onCloseCard,
    required this.onControl,
    this.attemptText,
    this.canControl = true,
  });

  final TutorialBanner? banner;
  final TutorialCard? card;
  final TutorialRules rules;
  final VoidCallback onCloseCard;
  final void Function(TutorialControl op) onControl;

  /// "Intento 2: esta vez quebrás vos".
  final String? attemptText;

  /// En grupo, solo el host repite o sale.
  final bool canControl;

  /// Segundos que se ve el cartel de efecto (§ 4.1).
  static const cardSeconds = TutorialRules.cardSeconds;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  bool _menu = false;
  bool _glossary = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final b = w.banner;
    final card = w.card;
    return Stack(
      children: [
        if (b != null)
          Positioned(
            top: 46,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: RetroPanel(
                  key: const ValueKey('tutorial-banner'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  borderColor:
                      b.yourTurn ? ProtoColors.gold : ProtoColors.panelBorder,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (b.stage.isNotEmpty)
                        Text(retroText(b.stage), style: _body(ProtoColors.dim)),
                      Text(retroText(b.text),
                          style: _body(
                              b.yourTurn ? ProtoColors.gold : ProtoColors.sky)),
                      if (w.attemptText case final a?)
                        Text(retroText(a), style: _body(ProtoColors.violet)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (card != null && !_menu)
          Positioned(
            left: 0,
            right: 0,
            bottom: 150,
            child: Center(
              child: GestureDetector(
                onTap: w.onCloseCard,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: RetroPanel(
                    key: const ValueKey('tutorial-card'),
                    selected: true,
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final l in card.lines)
                          Text(retroText(l), style: _body(ProtoColors.ink)),
                        if (tutorialArrowText(card.arrow) case final a
                            when a.isNotEmpty)
                          Text(a, style: _body(ProtoColors.orange)),
                        Text('ESPACIO o clic para seguir',
                            textAlign: TextAlign.end,
                            style: _body(ProtoColors.dim, RetroType.label)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 8,
          top: 46,
          child: PanelButton('TUTORIAL ≡',
              key: const ValueKey('tutorial-menu'),
              onPressed: () => setState(() {
                    _menu = !_menu;
                    _glossary = false;
                  })),
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
                              child: GlossaryView(entries: w.rules.glossary()),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          alignment: WrapAlignment.center,
                          children: [
                            PanelButton('SEGUIR',
                                accent: ProtoColors.green,
                                onPressed: () => setState(() => _menu = false)),
                            PanelButton(
                                _glossary ? 'OCULTAR GLOSARIO' : 'GLOSARIO',
                                key: const ValueKey('tutorial-menu-glossary'),
                                onPressed: () =>
                                    setState(() => _glossary = !_glossary)),
                            for (final (op, label) in const [
                              (TutorialControl.repeatStage, 'REPETIR ETAPA'),
                              (TutorialControl.repeat, 'REPETIR'),
                              (TutorialControl.exit, 'SALIR'),
                            ])
                              PanelButton(label,
                                  key: ValueKey('tutorial-${op.name}'),
                                  reason: w.canControl
                                      ? null
                                      : 'Lo decide el host', onPressed: () {
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
  }
}
