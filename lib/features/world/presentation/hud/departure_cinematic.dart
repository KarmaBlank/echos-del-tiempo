import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../game_engine/data/tuning_catalog.dart';
import '../../../../game_engine/models/game_session.dart';
import '../map/map_themes.dart';
import '../world_strings.dart';

/// Cinemática corta de partida (town_loop.md § 2, v0.21.0): cuando la
/// misión arranca (preparación → campo) la party sale por el camino de
/// tierra del pueblo. Dura `exploration.departureSec` (≤ 4 s, Editor →
/// Balance) y se salta con cualquier tecla o clic (que siguen de largo:
/// no se come la entrada). REDUCIR MOVIMIENTO la saltea. Es local: cada
/// jugador ve la suya.
class DepartureCinematic extends StatefulWidget {
  const DepartureCinematic(
      {super.key,
      required this.mode,
      this.destination,
      this.reduceMotion = false,
      this.enabled = true});

  final SessionMode mode;

  /// Nombre de la zona o misión de destino.
  final String? destination;
  final bool reduceMotion;

  /// `false` en la Travesía (no hay pueblo).
  final bool enabled;

  /// Segundos de la cinemática (tunable, con tope de 4).
  static double get seconds =>
      kTuning[TuningId.exploration]!.d('departureSec').clamp(0.0, 4.0);

  @override
  State<DepartureCinematic> createState() => DepartureCinematicState();
}

class DepartureCinematicState extends State<DepartureCinematic>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this)..value = 1;

  /// Se está mostrando.
  bool get playing => _anim.isAnimating;

  @override
  void didUpdateWidget(DepartureCinematic oldWidget) {
    super.didUpdateWidget(oldWidget);
    final secs = DepartureCinematic.seconds;
    if (widget.enabled &&
        !widget.reduceMotion &&
        secs > 0 &&
        oldWidget.mode == SessionMode.prep &&
        widget.mode == SessionMode.field) {
      _anim.duration = Duration(milliseconds: (secs * 1000).round());
      _anim.forward(from: 0);
      HardwareKeyboard.instance.addHandler(_onKey);
    }
    if (widget.mode != SessionMode.field) skip();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent) skip();
    return false;
  }

  /// Corta la cinemática.
  void skip() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (_anim.value < 1) _anim.value = 1;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        if (_anim.value >= 1) {
          HardwareKeyboard.instance.removeHandler(_onKey);
          return const SizedBox.shrink();
        }
        final p = _anim.value;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => skip(),
          child: IgnorePointer(
            child: Stack(
              key: const ValueKey('departure-cinematic'),
              children: [
                Positioned.fill(child: CustomPaint(painter: _RoadPainter(p))),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: Column(
                    children: [
                      Text(
                          retroText(widget.destination == null
                              ? context.t('ui.world.departure.leaving')
                              : context.t('ui.world.departure.heading',
                                  {'place': widget.destination})),
                          style: DsText.title()),
                      const SizedBox(height: 6),
                      Text(context.t('ui.world.departure.skip'),
                          style: DsText.body()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Camino de tierra entre árboles que se aleja; la party (cuatro
/// cuadraditos) camina hacia arriba. Fundido al principio y al final.
class _RoadPainter extends CustomPainter {
  _RoadPainter(this.p);
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    final th = mapTheme('pueblo');
    final a = (p < 0.15 ? p / 0.15 : (p > 0.85 ? (1 - p) / 0.15 : 1.0))
        .clamp(0.0, 1.0);
    final paint = Paint()..isAntiAlias = false;
    void rect(Color c, Rect r) {
      paint.color = c.withValues(alpha: c.a * a);
      canvas.drawRect(r, paint);
    }

    final w = size.width, h = size.height;
    rect(th.grass, Offset.zero & size);
    final px = (w / 120).clamp(3.0, 10.0);
    // Camino: trapecio de bloques (ancho abajo, angosto arriba).
    for (var y = 0.0; y < h; y += px) {
      final k = y / h;
      final half = w * (0.04 + 0.16 * k);
      rect(th.path, Rect.fromLTWH(w / 2 - half, y, half * 2, px));
      // Matas que pasan (sube la velocidad con el avance).
      final off = ((y / px + p * 60).floor() % 7);
      if (off == 0) {
        rect(th.tree, Rect.fromLTWH(w / 2 - half - px * 6, y, px * 4, px * 3));
        rect(th.tree2, Rect.fromLTWH(w / 2 + half + px * 2, y, px * 4, px * 3));
      }
    }
    // La party: camina hacia el horizonte.
    final py = h * (0.85 - 0.55 * p);
    for (var i = 0; i < 4; i++) {
      final bob = ((p * 40 + i).floor().isEven ? 0 : 1) * px * 0.5;
      rect(
          i.isEven ? th.trunk : th.rock2,
          Rect.fromLTWH(
              w / 2 - px * 5 + i * px * 2.5, py + bob, px * 2, px * 3));
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.p != p;
}
