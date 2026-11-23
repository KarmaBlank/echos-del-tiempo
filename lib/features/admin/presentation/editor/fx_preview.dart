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
import 'fx_editor_selection.dart';

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
    this.selectedTrack,
    this.selectedKey,
    this.onion = false,
    super.repaint,
  });

  final FxTimeline timeline;
  final double time;
  final FxPreviewSim sim;
  final int enemies;
  final bool camera;
  final ui.Image? hero, partner;
  final List<ui.Image?> enemyImages;

  /// Element being edited: framed with the selection box (§ 7.7).
  final int? selectedTrack;
  final ({int track, bool fire, int index})? selectedKey;

  /// Draw the previous and next key of [selectedTrack], faint.
  final bool onion;

  /// World → canvas scale of the last paint (drag on the move handle).
  static double lastScale = 1;

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
    var scale = fit;
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
      scale *= z;
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
    final sel = selectedTrack;
    if (onion && sel != null && sel < t.tracks.length) {
      final (prev, next) = fxNeighborKeys(t, sel, time);
      for (final at in [prev, next]) {
        if (at == null) continue;
        canvas.saveLayer(
            null, Paint()..color = DsColors.background.withValues(alpha: 0.35));
        FxPlayer.paint(canvas, t, at.toDouble(), st);
        canvas.restore();
      }
    }
    FxPlayer.paint(canvas, t, time, st);
    FxPlayer.paintPrims(canvas, t, time, st);
    sim.particles.paint(canvas);
    if (sel != null && sel < t.tracks.length) {
      final key = selectedKey;
      final tr = t.tracks[sel];
      final k = key != null && key.track == sel && key.fire &&
              key.index < tr.fires.length
          ? tr.fires[key.index]
          : null;
      paintSelection(canvas,
          fxSelectionBox(t, sel, time, st, Offset.zero & w, key: k), scale);
    }
    lastScale = scale;
    canvas.restore();
    // Barras de cine y tarjeta del nombre (pistas `letterbox` y
    // `title_card`; las mismas reglas que la batalla).
    final area = Rect.fromLTWH((size.width - w.width * fit) / 2,
        (size.height - w.height * fit) / 2, w.width * fit, w.height * fit);
    final lb = letterboxAt(t, time);
    if (lb > 0) {
      final bh = (area.height * lb).roundToDouble();
      final black = Paint()..color = DsColors.background;
      canvas.drawRect(Rect.fromLTWH(area.left, area.top, area.width, bh), black);
      canvas.drawRect(
          Rect.fromLTWH(area.left, area.bottom - bh, area.width, bh), black);
    }
    final card = titleCardWindow(t);
    if (card != null && time >= card.$1 && time <= card.$2) {
      final k = ((time - card.$1) / 180).clamp(0.0, 1.0) *
          (1 - ((time - (card.$2 - 140)) / 200).clamp(0.0, 1.0));
      final by = area.top + area.height * 0.2;
      canvas.drawRect(Rect.fromLTWH(area.left, by, area.width * 0.6 * k, 34),
          Paint()..color = st.color.withValues(alpha: 0.75 * k));
      final tp = TextPainter(
          text: TextSpan(
              text: t.name.toUpperCase(),
              style: DsText.subtitle()),
          textDirection: TextDirection.ltr)
        ..layout();
      if (k > 0.5) tp.paint(canvas, Offset(area.left + 12, by + 8));
    }
  }

  @override
  bool shouldRepaint(FxPreviewPainter old) => true;

  /// Green box around the edited element, a cross handle when it can be
  /// moved and corner squares when it can be scaled. Line widths are in
  /// screen px ([scale] = world → screen).
  static void paintSelection(Canvas canvas, FxSelectionBox b, double scale) {
    final px = 1 / scale;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * px
      ..color = DsColors.editSelection
      ..isAntiAlias = false;
    final fill = Paint()
      ..color = DsColors.editSelection
      ..isAntiAlias = false;
    canvas.drawRect(b.rect, stroke);
    if (b.canScale) {
      final h = 6 * px;
      for (final c in [
        b.rect.topLeft,
        b.rect.topRight,
        b.rect.bottomLeft,
        b.rect.bottomRight,
      ]) {
        canvas.drawRect(Rect.fromCenter(center: c, width: h, height: h), fill);
      }
    }
    if (b.canMove) {
      final c = b.rect.center;
      final l = 6 * px;
      canvas.drawRect(
          Rect.fromCenter(center: c, width: 2 * l, height: 2 * px), fill);
      canvas.drawRect(
          Rect.fromCenter(center: c, width: 2 * px, height: 2 * l), fill);
    }
  }
}

/// Regla de la línea de tiempo (game_editor.md § 3.2 y § 7.7): una fila
/// por elemento y propiedad ("Sprite · Escala"), keys como rombos,
/// disparos como marcas, el key elegido en verde y el cabezal con su
/// tiempo.
class FxTimelinePainter extends CustomPainter {
  FxTimelinePainter({
    required this.timeline,
    required this.time,
    required this.rows,
    this.selectedTrack,
    this.selectedField,
    this.selectedKey,
  });

  final FxTimeline timeline;
  final double time;

  /// One row per element and property ([fxRowsOf]).
  final List<FxRow> rows;
  final int? selectedTrack;
  final String? selectedField;
  final ({int track, bool fire, int index})? selectedKey;

  static const rowH = 16.0;
  static const labelW = 150.0;
  static const rulerH = 18.0;

  /// Rombos/marcas en pantalla, para el clic.
  static double xOf(double ms, double duration, double width) =>
      labelW + (width - labelW - 8) * (ms / math.max(1, duration));

  @override
  void paint(Canvas canvas, Size size) {
    final d = timeline.duration.toDouble();
    final fill = Paint()..isAntiAlias = false;
    canvas.drawRect(Offset.zero & size, fill..color = DsColors.surfaceSunken);
    final tp = TextPainter(
        textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…');
    void label(String s, Offset o, Color c, [double maxW = double.infinity]) {
      tp.text =
          TextSpan(text: s, style: DsText.detail(c).copyWith(fontSize: 9));
      tp.layout(maxWidth: maxW);
      tp.paint(canvas, o);
    }

    // Regla.
    for (var ms = 0; ms <= d; ms += 100) {
      final x = xOf(ms.toDouble(), d, size.width);
      final major = ms % 500 == 0;
      canvas.drawRect(Rect.fromLTWH(x, major ? 2 : 10, 1, major ? 14 : 6),
          fill..color = DsColors.borderControl);
      if (major) label(fxSeconds(ms), Offset(x + 2, 1), DsColors.textSecondary);
    }
    // Fases.
    final ph = timeline.phases;
    for (final (from, len, col) in [
      (0, ph.build, DsColors.mp),
      (ph.build, ph.release, DsColors.warning),
      (ph.build + ph.release, ph.recover, DsColors.success),
    ]) {
      final x0 = xOf(from.toDouble(), d, size.width);
      final x1 = xOf((from + len).toDouble(), d, size.width);
      canvas.drawRect(Rect.fromLTRB(x0, rulerH, x1, size.height),
          fill..color = col.withValues(alpha: 0.08));
    }
    final selKey = selectedKey;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final tr = timeline.tracks[row.track];
      final y = rulerH + i * rowH;
      final rowSel = row.track == selectedTrack &&
          (selectedField == null || row.field == selectedField);
      if (rowSel) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, rowH),
            fill..color = DsColors.editSelection.withValues(alpha: 0.14));
      }
      // Separador entre elementos.
      if (i > 0 && rows[i - 1].track != row.track) {
        canvas.drawRect(
            Rect.fromLTWH(0, y, size.width, 1), fill..color = DsColors.border);
      }
      label(
          fxRowLabel(timeline, row),
          Offset(4, y + 2),
          rowSel
              ? DsColors.editSelection
              : tr.known
                  ? DsColors.textPrimary
                  : DsColors.textSecondary,
          labelW - 8);
      final cy = y + rowH / 2;
      for (final (fire, list) in [(false, tr.keys), (true, tr.fires)]) {
        for (var k = 0; k < list.length; k++) {
          if (!fxRowShows(row, list[k], fire: fire)) continue;
          final x = xOf(list[k].t.toDouble(), d, size.width);
          final sel = selKey == (track: row.track, fire: fire, index: k);
          if (sel) {
            // Recuadro verde alrededor del key elegido.
            canvas.drawRect(Rect.fromLTWH(x - 7, y + 1, 14, rowH - 2),
                fill..color = DsColors.editSelection.withValues(alpha: 0.35));
          }
          final col = sel
              ? DsColors.editSelection
              : fire
                  ? (tr.type == 'impact' && !list[k].b('pre')
                      ? DsColors.danger
                      : DsColors.textSubtitle)
                  : DsColors.mp;
          if (fire) {
            canvas.drawRect(Rect.fromLTWH(x - 1, y + 2, sel ? 3 : 2, rowH - 4),
                fill..color = col);
          } else {
            final r = sel ? 6.0 : 5.0;
            final p = Path()
              ..moveTo(x, cy - r)
              ..lineTo(x + r, cy)
              ..lineTo(x, cy + r)
              ..lineTo(x - r, cy)
              ..close();
            canvas.drawPath(p, fill..color = col);
          }
        }
      }
    }
    // Impactos sobre la regla y cabezal con su tiempo.
    for (final f in timeline.impacts) {
      final x = xOf(f.t.toDouble(), d, size.width);
      canvas.drawRect(
          Rect.fromLTWH(x - 1, 0, 3, rulerH), fill..color = DsColors.danger);
    }
    final hx = xOf(time.clamp(0, d).toDouble(), d, size.width);
    canvas.drawRect(Rect.fromLTWH(hx - 1, 0, 2, size.height),
        fill..color = DsColors.focus);
    tp.text = TextSpan(
        text: fxSeconds(time),
        style: DsText.detail(DsColors.background).copyWith(fontSize: 9));
    tp.layout();
    final tx = (hx + 2)
        .clamp(labelW, math.max(labelW, size.width - tp.width - 4))
        .toDouble();
    canvas.drawRect(Rect.fromLTWH(tx - 2, 0, tp.width + 4, 11),
        fill..color = DsColors.focus);
    tp.paint(canvas, Offset(tx, 0));
  }

  @override
  bool shouldRepaint(FxTimelinePainter old) => true;
}
