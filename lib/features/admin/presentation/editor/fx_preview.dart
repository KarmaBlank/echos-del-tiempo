import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../../../../app/design/design.dart';
import '../../../../core/fx/fx_catalog.dart';
import '../../../combat/presentation/scene/fx_bridge.dart';
import '../../../combat/presentation/scene/fx_player.dart';
import '../../../combat/presentation/scene/fx_style.dart';
import '../../../combat/presentation/scene/particles.dart';
import '../../../combat/presentation/scene/ult_cinematic.dart';
import '../../../combat/presentation/scene/ult_fx.dart' show UltDirector;
import '../../../combat/presentation/sprite_catalog.dart';

/// Mini escena de batalla del Editor (game_editor.md § 3.2): mundo de
/// 240 × 135 px con el lanzador (y su compañero) a la izquierda y 1–4
/// enemigos de prueba a la derecha. Reproduce un `FxTimeline` con el
/// mismo `FxPlayer` que la batalla.
class FxPreviewSim {
  FxPreviewSim([math.Random? random])
      : particles = ParticleSystem(random ?? math.Random(7));

  static const worldSize = Size(240, 135);
  static const ground = 104.0;

  final ParticleSystem particles;
  final done = <String>{};
  double _at = 0;
  FxTimeline? _t;

  /// Hit-stop pendiente (ms del reloj de la animación congelados).
  double hitStop = 0;

  static const caster = Offset(62, ground);
  static const partner = Offset(40, ground + 8);
  static const _enemies = [
    Offset(176, ground - 10),
    Offset(196, ground + 4),
    Offset(156, ground + 10),
    Offset(214, ground - 14),
  ];

  static List<Offset> enemiesOf(int n) => _enemies.take(n.clamp(1, 4)).toList();

  /// Objetivos según el `targets` de la animación.
  static List<Offset> targetsOf(FxTimeline t, int n) => switch (t.targets) {
        'allies' || 'self' => [caster, partner],
        'single' || 'line' => enemiesOf(1),
        _ => enemiesOf(n),
      };

  /// Avanza la simulación hasta [a] ms (desde el inicio si va hacia
  /// atrás o cambió la animación), en pasos de 16 ms.
  void seek(FxTimeline t, double a, FxStage st) {
    if (!identical(t, _t) || a < _at - 1) {
      _t = t;
      _at = 0;
      done.clear();
      particles.clear();
      hitStop = 0;
    }
    while (_at < a) {
      final step = math.min(16.0, a - _at);
      _at += step;
      FxPlayer.tick(t, _at, st, particles, done, hitStop: (_) {});
      particles.update(step / 1000);
    }
  }
}

/// Escenario del preview para [t].
FxStage previewStage(FxTimeline t, int enemies,
    {ui.Image? casterImage, ui.Image? partnerImage}) {
  final code = t.category == 'duo' ? null : codeUltScriptFor(t.id);
  final el = code == null
      ? FxElement.arcane
      : UltDirector.element(code.style);
  final color = t.category == 'duo'
      ? const Color(0xFFB48CFF)
      : skillColor(t.id) == fxWhite
          ? const Color(0xFFFFE066)
          : skillColor(t.id);
  return FxStage(
    caster: FxPreviewSim.caster,
    targets: FxPreviewSim.targetsOf(t, enemies),
    party: const [FxPreviewSim.caster, FxPreviewSim.partner],
    partner: t.category == 'duo' ? FxPreviewSim.partner : null,
    casterImage: casterImage,
    partnerImage: partnerImage,
    color: color,
    element: el,
    visible: const Rect.fromLTWH(-200, -200, 640, 535),
  );
}

/// Clase de prueba que lanza [t] (por sus etiquetas).
String previewClassOf(FxTimeline t) {
  for (final (tag, cls) in const [
    ('guerrero', 'guerrero'),
    ('maga', 'maga'),
    ('paladín', 'paladin'),
    ('tirador', 'tirador'),
  ]) {
    if (t.tags.contains(tag)) return cls;
  }
  return 'guerrero';
}

class FxPreviewPainter extends CustomPainter {
  FxPreviewPainter({
    required this.timeline,
    required this.time,
    required this.sim,
    required this.enemies,
    this.camera = true,
    this.hero,
    this.partner,
    this.enemyImages = const [],
    super.repaint,
  });

  final FxTimeline timeline;
  final double time;
  final FxPreviewSim sim;
  final int enemies;
  final bool camera;
  final ui.Image? hero, partner;
  final List<ui.Image?> enemyImages;

  @override
  void paint(Canvas canvas, Size size) {
    final t = timeline;
    final st = previewStage(t, enemies, casterImage: hero, partnerImage: partner);
    sim.seek(t, time, st);
    const w = FxPreviewSim.worldSize;
    final fit = math.min(size.width / w.width, size.height / w.height);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0C0B14));
    canvas.save();
    canvas.translate((size.width - w.width * fit) / 2,
        (size.height - w.height * fit) / 2);
    canvas.clipRect(Offset.zero & (w * fit));
    canvas.scale(fit);
    // Cámara de la cinemática (la misma función que la batalla).
    if (camera && const {'ult', 'duo', 'enemy_ult'}.contains(t.category)) {
      final script = scriptFromTimeline(t, UltStyle.duo);
      final view = ultCameraAt(script, time,
          base: CameraView(w.center(Offset.zero), 1),
          caster: st.caster,
          targets: st.targets,
          party: st.party);
      final z = (view.zoom / 1).clamp(1.0, 2.0);
      canvas.translate(w.width / 2, w.height / 2);
      canvas.scale(z);
      canvas.translate(-view.center.dx, -view.center.dy);
    }
    canvas.translate(sim.particles.shakeOffset().dx, 0);
    // Arena.
    canvas.drawRect(Rect.fromLTWH(-200, -200, w.width + 400, FxPreviewSim.ground + 200),
        Paint()..color = const Color(0xFF1B1830));
    canvas.drawRect(
        Rect.fromLTWH(-200, FxPreviewSim.ground - 14, w.width + 400, 300),
        Paint()..color = const Color(0xFF2B2440));
    canvas.drawRect(Rect.fromLTWH(-200, FxPreviewSim.ground - 14, w.width + 400, 1),
        Paint()..color = const Color(0xFF4A3F6B));
    // Oscurecido de la cinemática.
    final dim = FxPlayer.dim(t, time);
    if (dim > 0) {
      canvas.drawRect(Rect.fromLTWH(-200, -200, w.width + 400, w.height + 400),
          Paint()..color = Color.fromRGBO(4, 3, 10, dim * 0.85));
    }
    void actor(ui.Image? img, Offset feet, {bool flip = false}) {
      canvas.save();
      canvas.translate(feet.dx.roundToDouble(), feet.dy.roundToDouble());
      canvas.drawOval(const Rect.fromLTWH(-6, -1, 12, 3),
          Paint()..color = const Color(0x66000000));
      if (flip) canvas.scale(-1, 1);
      if (img == null) {
        canvas.drawRect(const Rect.fromLTWH(-6, -16, 12, 16),
            Paint()..color = const Color(0xFF8B93AF));
      } else {
        canvas.drawImage(img, Offset(-img.width / 2, -img.height.toDouble()),
            SpriteCatalog.pixelPaint());
      }
      canvas.restore();
    }

    actor(partner, FxPreviewSim.partner);
    actor(hero, FxPreviewSim.caster);
    final foes = FxPreviewSim.enemiesOf(enemies);
    for (var i = 0; i < foes.length; i++) {
      actor(enemyImages.isEmpty ? null : enemyImages[i % enemyImages.length],
          foes[i],
          flip: true);
    }
    FxPlayer.paint(canvas, t, time, st);
    sim.particles.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FxPreviewPainter old) => true;
}

/// Regla de la línea de tiempo: pistas con keyframes (rombos) y disparos
/// (marcas), impactos y el cabezal (game_editor.md § 3.2).
class FxTimelinePainter extends CustomPainter {
  FxTimelinePainter({
    required this.timeline,
    required this.time,
    this.selectedTrack,
    this.selectedKey,
  });

  final FxTimeline timeline;
  final double time;
  final int? selectedTrack;
  final ({int track, bool fire, int index})? selectedKey;

  static const rowH = 16.0;
  static const labelW = 96.0;
  static const rulerH = 18.0;

  /// Rombos/marcas en pantalla, para el clic.
  static double xOf(double ms, double duration, double width) =>
      labelW + (width - labelW - 8) * (ms / math.max(1, duration));

  @override
  void paint(Canvas canvas, Size size) {
    final d = timeline.duration.toDouble();
    final fill = Paint()..isAntiAlias = false;
    canvas.drawRect(Offset.zero & size, fill..color = const Color(0xFF12111C));
    // Regla.
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String s, Offset o, Color c) {
      tp.text = TextSpan(
          text: s, style: DsText.detail(c).copyWith(fontSize: 9));
      tp.layout();
      tp.paint(canvas, o);
    }

    for (var ms = 0; ms <= d; ms += 100) {
      final x = xOf(ms.toDouble(), d, size.width);
      final major = ms % 500 == 0;
      canvas.drawRect(Rect.fromLTWH(x, major ? 2 : 10, 1, major ? 14 : 6),
          fill..color = const Color(0xFF4A4766));
      if (major) label('$ms', Offset(x + 2, 1), const Color(0xFF8D89B3));
    }
    // Fases.
    final ph = timeline.phases;
    for (final (from, len, col) in [
      (0, ph.build, const Color(0x2233AAFF)),
      (ph.build, ph.release, const Color(0x22FF7B29)),
      (ph.build + ph.release, ph.recover, const Color(0x2299FF99)),
    ]) {
      final x0 = xOf(from.toDouble(), d, size.width);
      final x1 = xOf((from + len).toDouble(), d, size.width);
      canvas.drawRect(Rect.fromLTRB(x0, rulerH, x1, size.height),
          fill..color = col);
    }
    for (var i = 0; i < timeline.tracks.length; i++) {
      final tr = timeline.tracks[i];
      final y = rulerH + i * rowH;
      if (i == selectedTrack) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, rowH),
            fill..color = const Color(0x337C5CFF));
      }
      label(tr.type.toUpperCase(), Offset(4, y + 2),
          tr.known ? const Color(0xFFCFCBEA) : const Color(0xFF8D89B3));
      final cy = y + rowH / 2;
      for (var k = 0; k < tr.keys.length; k++) {
        final x = xOf(tr.keys[k].t.toDouble(), d, size.width);
        final sel = selectedKey == (track: i, fire: false, index: k);
        final p = Path()
          ..moveTo(x, cy - 5)
          ..lineTo(x + 5, cy)
          ..lineTo(x, cy + 5)
          ..lineTo(x - 5, cy)
          ..close();
        canvas.drawPath(
            p, fill..color = sel ? const Color(0xFFFFE066) : const Color(0xFF9FF6FF));
      }
      for (var k = 0; k < tr.fires.length; k++) {
        final x = xOf(tr.fires[k].t.toDouble(), d, size.width);
        final sel = selectedKey == (track: i, fire: true, index: k);
        final imp = tr.type == 'impact' && !tr.fires[k].b('pre');
        canvas.drawRect(Rect.fromLTWH(x - 1, y + 2, imp ? 3 : 2, rowH - 4),
            fill
              ..color = sel
                  ? const Color(0xFFFFE066)
                  : imp
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFFB48CFF));
      }
    }
    // Impactos sobre la regla y cabezal.
    for (final f in timeline.impacts) {
      final x = xOf(f.t.toDouble(), d, size.width);
      canvas.drawRect(Rect.fromLTWH(x - 1, 0, 3, rulerH),
          fill..color = const Color(0xFFFF6B6B));
    }
    final hx = xOf(time.clamp(0, d), d, size.width);
    canvas.drawRect(Rect.fromLTWH(hx, 0, 1, size.height),
        fill..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(FxTimelinePainter old) => true;
}
