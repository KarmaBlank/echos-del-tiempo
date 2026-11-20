import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/rendering.dart';

import '../../../../app/design/design.dart';
import '../../../../core/fx/fx_catalog.dart';
import '../../../../game_engine/data/branch_ults_catalog.dart';
import '../sprite_catalog.dart';
import 'fx_bridge.dart';
import 'fx_player.dart';
import 'fx_style.dart';
import 'particles.dart';

/// Reloj de la vista previa de ULT (ms). Solo lo escucha el lienzo
/// (`CustomPainter(repaint:)`): ningún widget se reconstruye por frame.
class UltPreviewClock extends ChangeNotifier {
  double _ms = 0;
  double get ms => _ms;
  set ms(double v) {
    _ms = v;
    notifyListeners();
  }
}

/// Un número / efecto flotante sobre los objetivos (texto ya armado).
typedef UltPreviewLabel = ({String text, Color color});

/// La animación de datos de la ULT [id]: catálogo activo (la de la
/// ULT, o la de la que se parece si es de camino) o, sin catálogo /
/// solo código, una genérica de ecos (nunca `null`).
FxTimeline ultPreviewTimeline(String id) {
  final cat = FxCatalog.active;
  FxTimeline? ok(String? i) {
    final t = i == null ? null : cat?.timeline(i);
    return t == null || t.legacy ? null : t;
  }

  return ok(id) ?? ok(kBranchUltLooks[id]) ?? _generic;
}

final FxTimeline _generic = FxTimeline.parse('''
schema: 1
id: ult_preview_generic
category: ult
name: ULT
duration: 1800
phases: { build: 600, release: 800, recover: 400 }
targets: all
tracks:
  - type: dim
    keys:
      - { t: 0, v: 0 }
      - { t: 200, v: 0.7 }
      - { t: 1500, v: 0.6 }
      - { t: 1800, v: 0 }
  - type: shape
    fire:
      - { t: 0, shape: gather, anchor: caster, ms: 600, color: element }
  - type: echo
    who: caster
    count: 3
    lag: 70
    alpha: 0.45
    fade: 200
    keys:
      - { t: 500, at: caster }
      - { t: 800, at: target, dx: -16, ease: out }
      - { t: 1100, at: caster }
  - type: trail
    each_target: true
    stagger: 80
    fire:
      - { t: 700, from: caster, to: target, ms: 250, head: dot, echoes: 4, lag: 30 }
  - type: impact
    fire:
      - { t: 950 }
  - type: particles
    each_target: true
    stagger: 80
    fire:
      - { t: 950, preset: burst, anchor: target, count: 1.4, element: auto }
  - type: flash
    fire:
      - { t: 945, color: white, alpha: 0.4, ms: 120 }
  - type: shake
    fire:
      - { t: 950, amp: 3 }
''', fallbackId: 'ult_preview_generic');

/// Mini escena de la vista previa (ultimates_v2.md § 2.5): mundo de
/// 240 × 135 px, el personaje (con su arma) y dos aliados a la
/// izquierda, 1–3 enemigos a la derecha; reproduce el `FxTimeline` con el
/// mismo [FxPlayer] que la batalla y suma los números de ejemplo.
class UltPreviewSim {
  UltPreviewSim() : particles = ParticleSystem(math.Random(7));

  static const worldSize = Size(240, 135);
  static const ground = 104.0;
  static const caster = Offset(66, ground);
  static const allies = [
    Offset(66, ground),
    Offset(44, ground + 10),
    Offset(40, ground - 12),
  ];
  static const foes = [
    Offset(178, ground - 6),
    Offset(200, ground + 8),
    Offset(160, ground + 12),
  ];

  final ParticleSystem particles;
  final _done = <String>{};
  double _at = 0;
  FxTimeline? _t;

  /// Cantidad de veces que se pintó (tests: el lienzo sí se mueve).
  int paints = 0;

  /// Avanza hasta [a] ms (desde 0 si va hacia atrás o cambió la ULT).
  void seek(FxTimeline t, double a, FxStage st) {
    if (!identical(t, _t) || a < _at - 1) {
      _t = t;
      _at = 0;
      _done.clear();
      particles.clear();
    }
    // Tope de pasos por frame: un salto grande no congela la UI.
    var steps = 0;
    while (_at < a && steps++ < 12) {
      final step = math.min(16.0, a - _at);
      _at += step;
      FxPlayer.tick(t, _at, st, particles, _done, hitStop: (_) {});
      particles.update(step / 1000);
    }
    _at = math.max(_at, a);
  }
}

/// Momento del primer impacto de [t] (ms).
int ultPreviewImpact(FxTimeline t) =>
    t.impacts.isEmpty ? t.phases.build : t.impacts.first.t;

class UltPreviewPainter extends CustomPainter {
  UltPreviewPainter({
    required this.timeline,
    required this.clock,
    required this.sim,
    required this.foes,
    required this.count,
    required this.color,
    required this.element,
    required this.labels,
    this.weaponType,
    this.hero,
    this.allyImages = const [],
    this.enemyImages = const [],
  }) : super(repaint: clock);

  final FxTimeline timeline;
  final UltPreviewClock clock;
  final UltPreviewSim sim;

  /// Apunta a enemigos (si no, a aliados) y a cuántos (1–3).
  final bool foes;
  final int count;
  final Color color;
  final FxElement element;
  final List<UltPreviewLabel> labels;
  final String? weaponType;
  final ui.Image? hero;
  final List<ui.Image?> allyImages, enemyImages;

  static final _px = SpriteCatalog.pixelPaint();
  static final _fill = Paint()..isAntiAlias = false;

  // Textos ya medidos (no se rehacen por frame).
  final _texts = <TextPainter>[];

  List<Offset> get targets => foes
      ? UltPreviewSim.foes.take(count.clamp(1, 3)).toList()
      : count <= 1
          ? [UltPreviewSim.caster]
          : UltPreviewSim.allies;

  FxStage stage() => FxStage(
        caster: UltPreviewSim.caster,
        targets: targets,
        party: UltPreviewSim.allies,
        partner: UltPreviewSim.allies[1],
        casterImage: hero,
        partnerImage: allyImages.firstOrNull,
        color: color,
        element: element,
        visible: const Rect.fromLTWH(-200, -200, 640, 535),
      );

  @override
  void paint(Canvas canvas, Size size) {
    sim.paints++;
    final t = timeline;
    final time = clock.ms;
    final st = stage();
    sim.seek(t, time, st);
    const w = UltPreviewSim.worldSize;
    final fit = math.min(size.width / w.width, size.height / w.height);
    canvas.drawRect(Offset.zero & size, _fill..color = const Color(0xFF0C0B14));
    if (fit <= 0) return;
    final ox = (size.width - w.width * fit) / 2;
    final oy = (size.height - w.height * fit) / 2;
    canvas.save();
    canvas.translate(ox, oy);
    canvas.clipRect(Offset.zero & (w * fit));
    canvas.scale(fit);
    canvas.translate(sim.particles.shakeOffset().dx, 0);
    // Arena.
    canvas.drawRect(const Rect.fromLTWH(-200, -200, 640, 300),
        _fill..color = const Color(0xFF1B1830));
    canvas.drawRect(const Rect.fromLTWH(-200, UltPreviewSim.ground - 14, 640, 300),
        _fill..color = const Color(0xFF2B2440));
    canvas.drawRect(const Rect.fromLTWH(-200, UltPreviewSim.ground - 14, 640, 1),
        _fill..color = const Color(0xFF4A3F6B));
    final dim = FxPlayer.dim(t, time);
    if (dim > 0) {
      canvas.drawRect(const Rect.fromLTWH(-200, -200, 640, 535),
          _fill..color = Color.fromRGBO(4, 3, 10, dim * 0.85));
    }
    for (var i = UltPreviewSim.allies.length - 1; i >= 1; i--) {
      _actor(canvas, allyImages.isEmpty ? null : allyImages[(i - 1) % allyImages.length],
          UltPreviewSim.allies[i]);
    }
    _actor(canvas, hero, UltPreviewSim.caster, weapon: true);
    final foesAt = UltPreviewSim.foes.take(foes ? count.clamp(1, 3) : 2).toList();
    for (var i = 0; i < foesAt.length; i++) {
      _actor(canvas,
          enemyImages.isEmpty ? null : enemyImages[i % enemyImages.length],
          foesAt[i],
          flip: true);
    }
    FxPlayer.paint(canvas, t, time, st);
    FxPlayer.paintPrims(canvas, t, time, st);
    sim.particles.paint(canvas);
    _labels(canvas, st, time);
    canvas.restore();
  }

  void _actor(Canvas canvas, ui.Image? img, Offset feet,
      {bool flip = false, bool weapon = false}) {
    canvas.save();
    canvas.translate(feet.dx.roundToDouble(), feet.dy.roundToDouble());
    canvas.drawRect(const Rect.fromLTWH(-6, -1, 12, 2),
        _fill..color = const Color(0x66000000));
    if (flip) canvas.scale(-1, 1);
    if (img == null) {
      canvas.drawRect(const Rect.fromLTWH(-6, -16, 12, 16),
          _fill..color = flip ? const Color(0xFF8B5A6B) : const Color(0xFF8B93AF));
    } else {
      canvas.drawImage(img, Offset(-img.width / 2, -img.height.toDouble()), _px);
    }
    if (weapon) _weapon(canvas);
    canvas.restore();
  }

  /// El arma en la mano (silueta por tipo, en el color de la ULT).
  void _weapon(Canvas canvas) {
    final c = Color.lerp(color, fxWhite, 0.35)!;
    _fill.color = c;
    final ranged = kRangedWeaponTypes.contains(weaponType);
    switch (weaponType) {
      case 'báculo' || 'varita' || 'tomo':
        canvas.drawRect(const Rect.fromLTWH(7, -20, 1, 18), _fill);
        canvas.drawRect(const Rect.fromLTWH(6, -22, 3, 3), _fill..color = color);
      case 'arco' || 'ballesta':
        canvas.drawRect(const Rect.fromLTWH(8, -16, 1, 12), _fill);
        canvas.drawRect(const Rect.fromLTWH(7, -17, 1, 2), _fill);
        canvas.drawRect(const Rect.fromLTWH(7, -5, 1, 2), _fill);
      case 'rifle':
        canvas.drawRect(const Rect.fromLTWH(2, -9, 12, 2), _fill);
      case 'lanza':
        canvas.drawRect(const Rect.fromLTWH(1, -11, 16, 1), _fill);
        canvas.drawRect(const Rect.fromLTWH(17, -12, 2, 3), _fill..color = color);
      case 'hacha' || 'martillo':
        canvas.drawRect(const Rect.fromLTWH(7, -18, 1, 12), _fill);
        canvas.drawRect(const Rect.fromLTWH(8, -18, 4, 4), _fill..color = color);
      default:
        if (ranged) {
          canvas.drawRect(const Rect.fromLTWH(4, -9, 8, 2), _fill);
        } else {
          canvas.drawRect(const Rect.fromLTWH(7, -21, 1, 13), _fill);
          canvas.drawRect(const Rect.fromLTWH(5, -9, 5, 1), _fill);
        }
    }
  }

  /// Números de ejemplo: suben desde cada objetivo después del impacto.
  void _labels(Canvas canvas, FxStage st, double time) {
    if (labels.isEmpty) return;
    if (_texts.length != labels.length) {
      _texts
        ..clear()
        ..addAll([
          for (final l in labels)
            TextPainter(
                text: TextSpan(
                    text: l.text,
                    style: DsText.detail(l.color).copyWith(fontSize: 9, height: 1)),
                textDirection: TextDirection.ltr)
              ..layout(),
        ]);
    }
    final hit = ultPreviewImpact(timeline).toDouble();
    const life = 1100.0;
    final tg = st.targets;
    for (var i = 0; i < tg.length; i++) {
      final age = time - hit - i * 90;
      if (age < 0 || age > life) continue;
      final k = age / life;
      final alpha = k < 0.8 ? 1.0 : (1 - k) / 0.2;
      for (var j = 0; j < _texts.length; j++) {
        final tp = _texts[j];
        final o = tg[i].translate(-tp.width / 2,
            -30 - j * 10 - 10 * Curves2.out(k));
        if (alpha < 1) {
          canvas.saveLayer(
              Rect.fromLTWH(o.dx - 1, o.dy - 1, tp.width + 2, tp.height + 2),
              Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
        }
        // Sombra 1 px para leerse sobre los efectos.
        canvas.drawRect(Rect.fromLTWH(o.dx - 1, o.dy, tp.width + 2, tp.height),
            _fill..color = const Color(0x99000000));
        tp.paint(canvas, o);
        if (alpha < 1) canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(UltPreviewPainter old) =>
      !identical(old.timeline, timeline) ||
      old.labels != labels ||
      old.hero != hero ||
      old.count != count ||
      old.foes != foes;
}

/// Cues de sonido de la vista previa: `(id, ms)`, los mismos que la
/// batalla (pista `sound`, o preparación/descarga de la ULT) más los
/// impactos.
List<(String, int)> ultPreviewCues(FxTimeline t, String ultId,
    {required bool Function(String id) has,
    required String Function(String id, String part) ultCue,
    required String fallback,
    required String impact}) {
  final out = <(String, int)>[];
  if (t.track('sound') != null) {
    out.addAll([
      for (final c in soundCues(t, ultId, ultCue))
        if (has(c.$1)) c
    ]);
  } else if (has(ultCue(ultId, 'build'))) {
    out
      ..add((ultCue(ultId, 'build'), 0))
      ..add((ultCue(ultId, 'release'), t.phases.build));
  } else {
    out.add((fallback, 0));
  }
  for (final f in t.impacts) {
    out.add((impact, f.t));
  }
  return out;
}

/// Color de la ULT [id] en la vista previa (dorado si no tiene).
Color ultPreviewColor(String id) =>
    skillColor(id) == fxWhite ? const Color(0xFFFFE066) : skillColor(id);

/// `#rrggbb` → color (blanco si no se entiende).
Color ultPreviewHex(String h) => Color(
    0xFF000000 | (int.tryParse(h.replaceFirst('#', ''), radix: 16) ?? 0xFFFFFF));
