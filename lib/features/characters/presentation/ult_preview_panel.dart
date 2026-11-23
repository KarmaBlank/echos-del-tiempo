import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../core/audio/sfx_catalog.dart';
import '../../../core/fx/fx_catalog.dart' show FxTimeline;
import '../../../core/audio/sfx_service.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/scene/fx_style.dart';
import '../../combat/presentation/scene/ult_preview_scene.dart';
import '../domain/ult_preview_samples.dart';

/// Vista previa animada de una ULT (docs/specs/ultimates_v2.md § 2.5):
/// mini escena en loop con la animación de datos, los ecos y números de
/// ejemplo del nivel mostrado. Liviana: un único [Ticker] que solo mueve
/// el reloj del lienzo (nada se reconstruye por frame); se pausa con
/// PAUSA, cuando la ventana pierde el foco y cuando la pestaña no está a
/// la vista (`TickerMode`). Sonido apagado hasta que se pide.
class UltPreviewPanel extends StatefulWidget {
  const UltPreviewPanel({
    super.key,
    required this.skill,
    required this.level,
    required this.classId,
    this.nextLevel = false,
    this.ascensionId,
    this.weaponType,
    this.stats,
    this.sprites,
    this.sfx,
  });

  /// La ULT ya nivelada a [level].
  final SkillDef skill;
  final int level;

  /// Los números son los del próximo nivel (hover de MEJORAR).
  final bool nextLevel;
  final String classId;
  final String? ascensionId;
  final String? weaponType;
  final DerivedStats? stats;
  final GameSprites? sprites;
  final SfxService? sfx;

  /// Arranca reproduciendo. En `flutter test` arranca en pausa (si no,
  /// `pumpAndSettle` no termina nunca); los tests de la vista previa lo
  /// prenden.
  static bool? autoplayOverride;
  static bool get autoplay =>
      autoplayOverride ??
      !(!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'));

  /// Pausa entre vueltas del loop (ms).
  static const loopGap = 700;

  @override
  State<UltPreviewPanel> createState() => _UltPreviewPanelState();
}

class _UltPreviewPanelState extends State<UltPreviewPanel>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_onTick);
  final _clock = UltPreviewClock();
  final _sim = UltPreviewSim();
  Duration _last = Duration.zero;
  late bool _playing = UltPreviewPanel.autoplay;
  bool _sound = false;
  bool _focused = true;

  late FxTimeline _t;
  late List<UltPreviewLabel> _labels;
  late UltPreviewReach _reach;
  late List<(String, int)> _cues;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _derive();
    _sync();
  }

  @override
  void didUpdateWidget(UltPreviewPanel old) {
    super.didUpdateWidget(old);
    if (old.skill.id != widget.skill.id) {
      _clock.ms = 0;
      _derive();
    } else if (old.skill != widget.skill ||
        old.stats != widget.stats ||
        old.nextLevel != widget.nextLevel) {
      _derive();
    }
  }

  void _derive() {
    final sk = widget.skill;
    _t = ultPreviewTimeline(sk.id);
    _reach = ultPreviewReach(sk);
    final s = widget.stats;
    _labels = [
      for (final x in ultPreviewSamples(sk,
          attack: s?.attack ?? 20,
          magic: s?.magic ?? 20,
          maxHp: s?.maxHp ?? 100,
          healBonus: s?.healBonus ?? 0))
        (text: x.text, color: _hex(x.hex)),
    ];
    final svc = widget.sfx;
    _cues = ultPreviewCues(_t, sk.id,
        has: (id) => svc?.catalog.containsKey(id) ?? false,
        ultCue: Sfx.ult,
        fallback: Sfx.ultimate,
        impact: Sfx.hit);
  }

  static Color _hex(String h) => ultPreviewHex(h);

  int get _loop => _t.duration + UltPreviewPanel.loopGap;

  void _onTick(Duration now) {
    final dt = _last == Duration.zero
        ? 16.0
        : ((now - _last).inMicroseconds / 1000).clamp(0.0, 50.0);
    _last = now;
    final prev = _clock.ms;
    var next = prev + dt;
    if (next >= _loop) next -= _loop;
    if (_sound) {
      for (final (id, ms) in _cues) {
        final hit = next >= prev ? (ms > prev && ms <= next) : (ms > prev || ms <= next);
        if (hit || (prev == 0 && ms == 0)) widget.sfx?.play(id);
      }
    }
    _clock.ms = next;
  }

  /// Corre solo si se pidió y la ventana tiene el foco.
  void _sync() {
    final run = _playing && _focused;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _focused = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final sp = w.sprites;
    final color = ultPreviewColor(w.skill.id);
    return Column(
      key: const ValueKey('ult-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: RepaintBoundary(
            child: ClipRect(
              child: CustomPaint(
                key: const ValueKey('ult-preview-canvas'),
                painter: UltPreviewPainter(
                  timeline: _t,
                  clock: _clock,
                  sim: _sim,
                  foes: _reach.foes,
                  count: _reach.count,
                  color: color,
                  element: skillElement(w.skill),
                  labels: _labels,
                  weaponType: w.weaponType,
                  hero: sp?.heroFor(w.classId, w.ascensionId),
                  allyImages: [
                    for (final c in const ['maga', 'paladin']) sp?.hero(c),
                  ],
                  enemyImages: [
                    for (final e in const ['slime', 'bat', 'golem']) sp?.enemy(e),
                  ],
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        SizedBox(height: DsSpace.xs),
        Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
          DsButton(_playing ? 'PAUSA' : 'REPRODUCIR',
              key: const ValueKey('ult-preview-play'),
              size: DsButtonSize.compact,
              onPressed: () => setState(() {
                    _playing = !_playing;
                    _sync();
                  })),
          DsButton(_sound ? 'SONIDO: SÍ' : 'SONIDO: NO',
              key: const ValueKey('ult-preview-sound'),
              size: DsButtonSize.compact,
              onPressed: w.sfx == null
                  ? null
                  : () => setState(() => _sound = !_sound)),
        ]),
      ],
    );
  }
}
