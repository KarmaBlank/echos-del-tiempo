import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme/retro_text.dart';
import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/classes_catalog.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/sprite_catalog.dart';

/// Tiempos de la cinemática de ascensión (docs/specs/ascension.md § 5).
abstract final class AscensionCinematicTiming {
  static const freezeMs = 400;
  static const revealMs = 2200;
  static const flashEndMs = 2500;
  static const bannerOutMs = 4600;
  static const totalMs = 5200;

  /// Se puede saltar desde acá.
  static const skippableMs = 1000;
}

/// La cinemática de ascensión: la pantalla se detiene, la luz converge
/// en el personaje, destello, cambia el sprite al ascendido y el cartel
/// con el nombre. [at] fija un instante (tests y capturas); sin [at]
/// corre sola y llama a [onDone].
class AscensionCinematic extends StatefulWidget {
  const AscensionCinematic({
    super.key,
    required this.playerName,
    required this.classId,
    required this.ascensionId,
    this.sprites,
    this.onDone,
    this.at,
  });

  final String playerName;
  final String classId;
  final String ascensionId;
  final GameSprites? sprites;
  final VoidCallback? onDone;
  final int? at;

  @override
  State<AscensionCinematic> createState() => AscensionCinematicState();
}

class AscensionCinematicState extends State<AscensionCinematic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AscensionCinematicTiming.totalMs));
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.at == null) {
      _c.addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });
      _c.forward();
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone?.call();
  }

  /// Salta al final (clic, Esc o Enter después de 1 s). Devuelve si saltó.
  bool skip() {
    if (_ms < AscensionCinematicTiming.skippableMs) return false;
    _c.stop();
    _finish();
    return true;
  }

  double get _ms => widget.at?.toDouble() ??
      _c.value * AscensionCinematicTiming.totalMs;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = kAscensions[widget.ascensionId];
    if (a == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: skip,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ms = _ms;
          final revealed = ms >= AscensionCinematicTiming.revealMs;
          final base = widget.sprites?.hero(widget.classId);
          final asc = widget.sprites?.heroFor(widget.classId, a.id);
          final aura = widget.sprites?.aura(a.id);
          return CustomPaint(
            key: const ValueKey('asc-cinematic'),
            size: Size.infinite,
            painter: _CinematicPainter(
              ms: ms,
              color: Color(a.color),
              hero: revealed ? (asc ?? base) : base,
              aura: revealed ? aura : null,
              tint: revealed && asc == base,
            ),
            child: _banner(ms, a.name, Color(a.color), a.motto),
          );
        },
      ),
    );
  }

  Widget _banner(double ms, String name, Color col, String motto) {
    if (ms < AscensionCinematicTiming.flashEndMs) return const SizedBox.expand();
    final inT = ((ms - AscensionCinematicTiming.flashEndMs) / 300).clamp(0.0, 1.0);
    final outT = ((ms - AscensionCinematicTiming.bannerOutMs) / 600).clamp(0.0, 1.0);
    final o = (inT * (1 - outT)).clamp(0.0, 1.0);
    final cls = kClasses[widget.classId]?.name ?? widget.classId;
    return Opacity(
      opacity: o,
      child: Align(
        alignment: const Alignment(0, 0.62),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - inT)),
          child: Container(
            key: const ValueKey('asc-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: const Color(0xCC05060D),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(retroText('ASCENSIÓN'),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFFFD166), letterSpacing: 4)),
                const SizedBox(height: 10),
                Text(retroText(name.toUpperCase()),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      color: col,
                      shadows: const [
                        Shadow(color: Color(0xFF000000), offset: Offset(3, 3)),
                      ],
                    )),
                const SizedBox(height: 10),
                Text(retroText('${widget.playerName} · $cls'),
                    style: const TextStyle(fontSize: 10, color: Color(0xFFE8ECFF))),
                const SizedBox(height: 8),
                Text(retroText(motto),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 8, color: Color(0xFF9FB4FF))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CinematicPainter extends CustomPainter {
  _CinematicPainter({
    required this.ms,
    required this.color,
    required this.hero,
    required this.aura,
    required this.tint,
  });

  final double ms;
  final Color color;
  final ui.Image? hero;
  final ui.Image? aura;

  /// No hay sprite ascendido: el base, teñido con el color (fallback).
  final bool tint;

  static double _s(double x) {
    final t = x.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const t = AscensionCinematicTiming.totalMs;
    final fadeOut = _s((ms - (t - 600)) / 600);
    final dark = _s(ms / AscensionCinematicTiming.freezeMs) * (1 - fadeOut);
    canvas.drawRect(Offset.zero & size,
        Paint()..color = Color.fromRGBO(5, 6, 13, 0.88 * dark));

    final scale = (size.height / 90).floorToDouble().clamp(2.0, 10.0);
    final cx = size.width / 2;
    final feet = size.height * 0.5;
    final build = _s((ms - AscensionCinematicTiming.freezeMs) /
        (AscensionCinematicTiming.revealMs - AscensionCinematicTiming.freezeMs));
    final revealed = ms >= AscensionCinematicTiming.revealMs;
    final alive = 1 - fadeOut;

    // Columna de luz que crece.
    if (build > 0) {
      final w = 30 * scale * (0.2 + 0.8 * build);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, feet - 300), width: w, height: 1200),
          Paint()
            ..color = color.withValues(
                alpha: (revealed ? 0.18 : 0.08 + 0.22 * build) * alive));
    }

    // Partículas que convergen (antes) y anillo que se expande (después).
    final rnd = math.Random(7);
    final p = Paint();
    for (var i = 0; i < 48; i++) {
      final ang = rnd.nextDouble() * math.pi * 2;
      final r0 = (180 + rnd.nextDouble() * 260) * scale / 4;
      final speed = 0.5 + rnd.nextDouble();
      final q = ((build * speed) + i / 48) % 1;
      final r = revealed
          ? r0 * _s((ms - AscensionCinematicTiming.revealMs) / 900)
          : r0 * (1 - q);
      final x = cx + math.cos(ang) * r;
      final y = feet - 9 * scale + math.sin(ang) * r * 0.7;
      p.color = (i.isEven ? color : const Color(0xFFFFFFFF))
          .withValues(alpha: (revealed ? 0.8 * (1 - fadeOut) : q) * alive);
      final s = (i % 3 + 1) * scale / 2;
      canvas.drawRect(Rect.fromLTWH(x.roundToDouble(), y.roundToDouble(), s, s), p);
    }

    // Aura y héroe (sacudida que crece hasta el destello).
    final shake = revealed ? 0.0 : build * scale * 0.6;
    final dx = math.sin(ms / 23) * shake, dy = math.cos(ms / 31) * shake;
    canvas.save();
    canvas.translate(cx + dx, feet + dy);
    canvas.scale(scale);
    final glow = revealed ? 1.0 : build;
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -9), width: 30, height: 34),
        Paint()..color = color.withValues(alpha: 0.25 * glow * alive));
    final au = aura;
    if (au != null) {
      canvas.drawImage(
          au,
          const Offset(-12, -25),
          SpriteCatalog.pixelPaint()
            ..color = Color.fromRGBO(255, 255, 255,
                (0.65 + 0.25 * math.sin(ms / 220)) * alive));
    }
    final h = hero;
    if (h != null) {
      final paint = SpriteCatalog.pixelPaint()
        ..color = Color.fromRGBO(0, 0, 0, alive);
      if (!revealed && build > 0.6) {
        // Se carga de luz antes del destello.
        paint.colorFilter = ColorFilter.mode(
            color.withValues(alpha: (build - 0.6) * 1.6), BlendMode.srcATop);
      } else if (tint) {
        paint.colorFilter = ColorFilter.mode(
            color.withValues(alpha: 0.35), BlendMode.srcATop);
      }
      canvas.drawImage(h, Offset(-h.width / 2, -h.height.toDouble()), paint);
    }
    canvas.restore();

    // Barras de cine (encima de la luz).
    final bar = size.height * 0.11 * dark;
    final barPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, bar), barPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height - bar, size.width, bar), barPaint);

    // Destello blanco.
    if (ms >= AscensionCinematicTiming.revealMs &&
        ms < AscensionCinematicTiming.flashEndMs + 200) {
      final k = 1 -
          ((ms - AscensionCinematicTiming.revealMs) /
                  (AscensionCinematicTiming.flashEndMs +
                      200 -
                      AscensionCinematicTiming.revealMs))
              .clamp(0.0, 1.0);
      canvas.drawRect(Offset.zero & size,
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.9 * k));
    }
  }

  @override
  bool shouldRepaint(_CinematicPainter old) => old.ms != ms || old.hero != hero;
}
