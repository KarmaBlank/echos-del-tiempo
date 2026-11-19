import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/retro_panel.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_type.dart';
import '../../combat/presentation/battle_hud.dart' show HudHighlight;
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
                      Text(
                          'Después: repetir el tutorial o ENTRENAR '
                          '(libre, con un kit para probar todo).',
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

/// La pelea del TUTORIAL con su panel lateral fijo (§ 4.1): la arena se
/// achica y el panel ocupa una columna a la derecha, así nunca tapa
/// personajes, enemigos, números de daño ni el menú. El panel dice la
/// etapa, quién actúa, lo que pasó en la última acción y la votación
/// SIGUIENTE. El menú del tutorial (Repetir etapa, Repetir, Glosario,
/// Salir) se abre encima de todo.
class TutorialOverlay extends StatefulWidget {
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
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  bool _menu = false;
  bool _glossary = false;

  Widget _section(String label, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: _body(ProtoColors.dim, RetroType.label)),
            const SizedBox(height: 2),
            ...children,
          ],
        ),
      );

  Widget _panel() {
    final w = widget;
    final b = w.banner;
    final card = w.card;
    final last = w.last;
    final head = b?.stage ?? '';
    return RetroPanel(
      key: const ValueKey('tutorial-panel'),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(head.isEmpty ? 'TUTORIAL' : retroText(head),
                    style: _body(ProtoColors.gold)),
              ),
              PanelButton('≡',
                  key: const ValueKey('tutorial-menu'),
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
                    _section('VOTACIÓN', [
                      if (b != null && b.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(retroText(b.text),
                              style: _body(ProtoColors.gold)),
                        ),
                      for (final (id, label) in w.options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: PanelButton(label,
                              key: ValueKey('tutorial-pick-$id'),
                              selected: w.myPick == id,
                              accent: w.myPick == id
                                  ? ProtoColors.green
                                  : null,
                              onPressed: () => w.onPick?.call(id)),
                        ),
                      for (final l in w.pickLines)
                        Text(retroText(l),
                            style: _body(l.startsWith('Hay ') ||
                                    l.startsWith('Falta ')
                                ? ProtoColors.orange
                                : ProtoColors.ink)),
                      Text('Hace falta que voten todos.',
                          style: _body(ProtoColors.dim, RetroType.label)),
                    ])
                  else if (w.narration.isNotEmpty && card == null) ...[
                    if (b != null && b.text.isNotEmpty)
                      _section('AHORA', [
                        Text(retroText(b.text),
                            key: const ValueKey('tutorial-now'),
                            style: _body(b.yourTurn
                                ? ProtoColors.gold
                                : ProtoColors.sky)),
                      ]),
                    _section('LO QUE PASA', [
                      for (final (i, l) in w.narration.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(retroText(l),
                              key: const ValueKey('tutorial-narration'),
                              style: _body(i == w.narration.length - 1
                                  ? ProtoColors.ink
                                  : ProtoColors.dim)),
                        ),
                    ]),
                  ] else if (card != null)
                    _section(
                        card.heading ??
                            (card.effect ? 'LO QUE PASÓ' : 'EN ESTA ETAPA'),
                        [
                      for (final l in card.lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(retroText(l),
                              key: const ValueKey('tutorial-card-line'),
                              style: _body(ProtoColors.ink)),
                        ),
                      if (tutorialArrowText(card.arrow) case final a
                          when a.isNotEmpty)
                        Text(a, style: _body(ProtoColors.orange)),
                    ])
                  else ...[
                    if (b != null && b.text.isNotEmpty)
                      _section('AHORA', [
                        Text(retroText(b.text),
                            key: const ValueKey('tutorial-now'),
                            style: _body(b.yourTurn
                                ? ProtoColors.gold
                                : ProtoColors.sky)),
                      ]),
                    if (last != null)
                      _section('ÚLTIMA ACCIÓN', [
                        for (final l in last.lines)
                          Text(retroText(l), style: _body(ProtoColors.dim)),
                      ]),
                  ],
                ],
              ),
            ),
          ),
          if (card != null) ...[
            const SizedBox(height: 6),
            if (w.waitingText case final t?)
              Text(retroText(t),
                  key: const ValueKey('tutorial-waiting'),
                  style: _body(ProtoColors.orange)),
            const SizedBox(height: 4),
            if (w.voted)
              Text('Ya votaste SIGUIENTE.',
                  key: const ValueKey('tutorial-voted'),
                  style: _body(ProtoColors.green))
            else
              PanelButton('SIGUIENTE',
                  key: const ValueKey('tutorial-next'),
                  accent: ProtoColors.green,
                  onPressed: w.onNext),
            Text('ESPACIO o Enter: leí y entendí',
                style: _body(ProtoColors.dim, RetroType.label)),
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
                              PanelButton('SEGUIR',
                                  accent: ProtoColors.green,
                                  onPressed: () =>
                                      setState(() => _menu = false)),
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
    });
  }
}

/// `HudHighlight` de las flechas de [hud] (MP y Pulso).
Set<String> tutorialHudParts(Set<TutorialArrow> hud) => {
      if (hud.contains(TutorialArrow.mp)) HudHighlight.mp,
      if (hud.contains(TutorialArrow.pulse)) HudHighlight.pulse,
    };
