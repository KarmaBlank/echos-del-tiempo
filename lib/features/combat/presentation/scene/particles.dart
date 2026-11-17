import 'dart:math' as math;
import 'dart:ui';

import 'fx_style.dart';

/// Una partícula de `burst` (solo visual, local).
class Particle {
  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.gravity,
    required this.life,
    required this.color,
    required this.shape,
    required this.size,
  }) : maxLife = life;

  double x, y, vx, vy;
  final double gravity;
  double life;
  final double maxLife;
  final Color color;
  final ParticleShape shape;
  final double size;
}

/// Partículas, sacudida de pantalla y destello rojo de daño (`parts`,
/// `shake`, `hurtFlash`, `burst`, `drawParts` del prototipo). Números en
/// docs/specs/battle_presentation.md § "Partículas".
class ParticleSystem {
  ParticleSystem([math.Random? random]) : _rnd = random ?? math.Random();

  final math.Random _rnd;
  final particles = <Particle>[];

  /// Amplitud de la sacudida en px virtuales (`shake`).
  double shake = 0;

  /// Intensidad del destello rojo (`hurtFlash`).
  double hurtFlash = 0;

  static const maxParticles = 600;

  double random() => _rnd.nextDouble();

  /// `burst(x, y, el, mult)`.
  void burst(double x, double y, FxElement el, [double mult = 1]) =>
      burstWith(elementFx(el), x, y, mult);

  /// Como [burst] pero con una receta propia (escombros, chispas de las
  /// ULT).
  void burstWith(ElementFx d, double x, double y, [double mult = 1]) {
    final n = (d.count * mult).round();
    final wide = d.shape == ParticleShape.ray || d.shape == ParticleShape.plus;
    for (var i = 0; i < n; i++) {
      final a = random() * math.pi * 2;
      final sp = d.speed * (0.35 + random() * 0.85);
      particles.add(Particle(
        x: x + (random() - 0.5) * (wide ? 18 : 5),
        y: y + (random() - 0.5) * 6,
        vx: math.cos(a) * sp,
        vy: math.sin(a) * sp * (d.gravity < 0 ? 0.4 : 1) -
            (d.gravity < 0 ? 8 : 0),
        gravity: d.gravity,
        life: d.life * (0.6 + random() * 0.6),
        color: d.colors[(random() * d.colors.length).floor()],
        shape: d.shape,
        size: 1 + random() * 1.8,
      ));
    }
    if (particles.length > maxParticles) {
      particles.removeRange(0, particles.length - maxParticles);
    }
  }

  void addShake(double amount) => shake = math.max(shake, amount);

  /// Avanza [dt] segundos (como `drawParts`, con `dt` ≤ 0.05).
  void update(double dt) {
    dt = math.min(0.05, dt);
    shake = math.max(0, shake - dt * 22);
    hurtFlash = math.max(0, hurtFlash - dt * 0.9);
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        particles.removeAt(i);
        continue;
      }
      p.vy += p.gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.98;
    }
  }

  /// Desplazamiento de la sacudida para este frame (px enteros).
  Offset shakeOffset() {
    if (shake <= 0) return Offset.zero;
    return Offset(((random() - 0.5) * shake * 2).roundToDouble(),
        ((random() - 0.5) * shake * 2).roundToDouble());
  }

  void paint(Canvas c) {
    final fill = Paint()..isAntiAlias = false;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (final p in particles) {
      final a = math.min(1.0, p.life / p.maxLife * 1.4).clamp(0.0, 1.0);
      final color = p.color.withValues(alpha: a);
      fill.color = color;
      switch (p.shape) {
        case ParticleShape.shard:
          c.save();
          c.translate(p.x, p.y);
          c.rotate(math.atan2(p.vy, p.vx));
          c.drawRect(const Rect.fromLTWH(-3, -0.75, 6, 1.5), fill);
          c.restore();
        case ParticleShape.bubble:
          stroke.color = color;
          c.drawCircle(Offset(p.x, p.y), p.size + 0.5, stroke);
        case ParticleShape.ray:
          c.drawRect(Rect.fromLTWH(p.x - 0.5, p.y - 4, 1.5, 6 + p.size * 2), fill);
        case ParticleShape.plus:
          c.drawRect(Rect.fromLTWH(p.x - 2, p.y - 0.5, 5, 2), fill);
          c.drawRect(Rect.fromLTWH(p.x - 0.5, p.y - 2, 2, 5), fill);
        case ParticleShape.square:
          c.drawRect(
              Rect.fromLTWH(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size),
              fill);
      }
    }
  }

  void clear() {
    particles.clear();
    shake = 0;
    hurtFlash = 0;
  }
}
