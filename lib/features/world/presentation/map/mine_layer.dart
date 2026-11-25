import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/mine_catalog.dart';
import '../../../../game_engine/rules/mine_work_rules.dart';
import '../../../../game_engine/rules/mining_rules.dart';
import 'map_themes.dart';

typedef MineText = void Function(
    String s, double x, double y, Color col, double size);

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.color,
      {this.size = 1.5});
  double x, y, vx, vy, life;
  final double size;
  final Color color;
  double age = 0;
}

class _Pop {
  _Pop(this.x, this.y, this.label, this.color, this.t0, this.to);
  final double x, y;
  final String label;
  final Color color;
  final double t0;

  /// Player that gets it (the pop flies to them).
  final String to;
}

/// Feel of the mines (docs/specs/mining_smithing.md § 1.9): crack stages,
/// sparks and debris, ore that flies to the player, lit bombs and the
/// blast shake; stations, carts and miners in the mine and the cart
/// station of the town. Pure drawing: everything comes from the session
/// state, the events and the local predictions of the controller.
class MineLayer {
  final _parts = <_Particle>[];
  final _pops = <_Pop>[];
  final _bombs = <(int, int, double)>[];
  double _shakeT0 = -1e9, _shakeAmp = 0;
  double _lastT = 0;
  final _rand = math.Random(7);

  static const ts = 16.0;

  /// Milliseconds a pop flies; a shake lasts.
  static const popMs = 650.0, shakeMs = 380.0;

  /// Debris and ore pop of a broken tile.
  void onDug(int tx, int ty, String code, String label, String playerId,
      String theme, double t) {
    final cx = (tx + 0.5) * ts, cy = (ty + 0.5) * ts;
    final vein = MineTile.veins.contains(code) || code == MineTile.crystal;
    final col = vein ? MinePalette.vein(theme) : MinePalette.rockLight;
    for (var i = 0; i < 10; i++) {
      final a = _rand.nextDouble() * math.pi * 2;
      final sp = 20 + _rand.nextDouble() * 50;
      _parts.add(_Particle(cx, cy, math.cos(a) * sp, math.sin(a) * sp - 30,
          0.45 + _rand.nextDouble() * 0.3,
          i.isEven ? MinePalette.rock : col,
          size: 1 + _rand.nextDouble() * 1.5));
    }
    if (label.isNotEmpty) {
      _pops.add(_Pop(cx, cy, label, col, t, playerId));
    }
  }

  /// Sparks of a swing on ([tx], [ty]).
  void onSwing(int tx, int ty, double t) {
    final cx = (tx + 0.5) * ts, cy = (ty + 0.5) * ts;
    for (var i = 0; i < 4; i++) {
      final a = _rand.nextDouble() * math.pi * 2;
      _parts.add(_Particle(cx, cy, math.cos(a) * 40, math.sin(a) * 40, 0.18,
          MinePalette.spark,
          size: 1));
    }
  }

  void onBomb(int tx, int ty, double fuse, double t) =>
      _bombs.add((tx, ty, t + fuse * 1000));

  void onBlast(int tx, int ty, int radius, double t) {
    _bombs.removeWhere((b) => b.$1 == tx && b.$2 == ty);
    _shakeT0 = t;
    _shakeAmp = 2.0 + radius;
    final cx = (tx + 0.5) * ts, cy = (ty + 0.5) * ts;
    for (var i = 0; i < 40; i++) {
      final a = _rand.nextDouble() * math.pi * 2;
      final sp = 30 + _rand.nextDouble() * 90;
      _parts.add(_Particle(cx, cy, math.cos(a) * sp, math.sin(a) * sp,
          0.5 + _rand.nextDouble() * 0.4,
          i % 3 == 0 ? MinePalette.spark : MinePalette.rockLight,
          size: 1 + _rand.nextDouble() * 2));
    }
  }

  /// Camera offset of the blast shake at [t] (ms).
  Offset shake(double t) {
    final k = (t - _shakeT0) / shakeMs;
    if (k < 0 || k >= 1) return Offset.zero;
    final a = _shakeAmp * (1 - k);
    return Offset(math.sin(t / 17) * a, math.cos(t / 23) * a);
  }

  /// Crack stages (1..3) of a tile with [dealt] of [hits].
  static int crackStage(int dealt, int hits) =>
      hits <= 0 || dealt <= 0 ? 0 : (1 + (dealt * 3 ~/ hits)).clamp(1, 3);

  void _crack(Canvas c, double px, double py, int stage) {
    final p = Paint()
      ..color = MinePalette.crack
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(px + 8, py + 2)
      ..lineTo(px + 6, py + 6)
      ..lineTo(px + 9, py + 9);
    if (stage >= 2) {
      path
        ..moveTo(px + 6, py + 6)
        ..lineTo(px + 2, py + 8)
        ..moveTo(px + 9, py + 9)
        ..lineTo(px + 13, py + 12);
    }
    if (stage >= 3) {
      path
        ..moveTo(px + 9, py + 9)
        ..lineTo(px + 8, py + 14)
        ..moveTo(px + 6, py + 6)
        ..lineTo(px + 11, py + 4);
    }
    c.drawPath(path, p);
  }

  /// The mine level: station and cart, miners, cracks, bombs, particles,
  /// pops. [cracks]: tile index → hits dealt (local prediction).
  /// [swing]: the local player's swing (target tile and progress 0..1).
  void drawMine(
    Canvas c,
    MineLevel lvl,
    MineLevelState st,
    double t, {
    required Map<int, int> cracks,
    required (double, double)? Function(String id) playerAt,
    required ui.Image? minerSprite,
    required MineText text,
    required String Function(String key, [Map<String, Object?> a]) tr,
    ((int, int), double, (double, double))? swing,
  }) {
    _step(t);
    // Station and its cart.
    final (sx, sy) = lvl.station;
    final px = sx * ts, py = sy * ts;
    if (st.station) {
      _rect(c, MinePalette.timber, px - 2, py - 10, 20, 3);
      _rect(c, MinePalette.timber, px - 2, py - 10, 3, 14);
      _rect(c, MinePalette.timber, px + 15, py - 10, 3, 14);
      if (st.cart.phase == CartPhase.mine) {
        _cart(c, px + 1, py + 2, st.cart.total / math.max(1, MiningRules.t.i('cartCap')),
            MinePalette.vein(MiningRules.themeOf(lvl.biome)));
      }
      text(
          st.cart.phase == CartPhase.mine
              ? tr('ui.world.mine.cart_fill', {
                  'n': st.cart.total,
                  'max': MiningRules.t.i('cartCap'),
                })
              : tr('ui.world.mine.cart_away'),
          px + 8,
          py - 14,
          MinePalette.label,
          6);
    }
    // Rails toward the edge of the station chamber.
    for (var k = -4; k <= 3; k++) {
      _rect(c, MinePalette.rail, px + k * ts, py + 13, ts, 1);
    }
    // Miners at work.
    for (final m in st.miners) {
      final mx = (m.x + 0.5) * ts, my = (m.y + 1) * ts;
      if (minerSprite != null) {
        final w = minerSprite.width.toDouble(),
            h = minerSprite.height.toDouble();
        c.drawImageRect(minerSprite, Rect.fromLTWH(0, 0, w, h),
            Rect.fromLTWH(mx - w / 2, my - h, w, h), Paint());
      } else {
        _rect(c, MinePalette.timber, mx - 3, my - 10, 6, 10);
      }
      // Pick going up and down.
      final a = math.sin(t / 120 + m.x) * 0.8;
      _pick(c, mx + 4, my - 8, a);
    }
    // Cracks.
    for (final e in cracks.entries) {
      final (x, y) = lvl.xy(e.key);
      final code = MiningRules.tileAt(lvl, st, x, y);
      final stage = crackStage(e.value, MiningRules.hits(code, lvl.level));
      if (stage > 0) _crack(c, x * ts, y * ts, stage);
    }
    // Lit bombs.
    for (final (bx, by, at) in _bombs) {
      final cx = (bx + 0.5) * ts, cy = (by + 0.5) * ts;
      _circle(c, MinePalette.bomb, cx, cy + 2, 5);
      final left = ((at - t) / 1000).clamp(0.0, 9.0);
      if (math.sin(t / 40) > 0) {
        _circle(c, MinePalette.spark, cx + 3, cy - 4, 1.6);
      }
      text(left.toStringAsFixed(1), cx, cy - 10, MinePalette.spark, 6);
    }
    _bombs.removeWhere((b) => b.$3 < t - 600);
    // Local swing.
    if (swing case ((final tx, final ty), final k, (final ox, final oy))) {
      final a = -1.2 + 2.0 * Curves.easeIn.transform(k.clamp(0.0, 1.0));
      final dx = (tx + 0.5) * ts - ox, dy = (ty + 0.5) * ts - oy;
      _pick(c, ox + dx * 0.45, oy - 4 + dy * 0.45, a);
    }
    _drawParticles(c, playerAt, text, t);
  }

  void _drawParticles(Canvas c, (double, double)? Function(String id) playerAt,
      MineText text, double t) {
    final p = Paint();
    for (final q in _parts) {
      p.color = q.color.withValues(alpha: (1 - q.age / q.life).clamp(0, 1));
      c.drawRect(Rect.fromLTWH(q.x, q.y, q.size, q.size), p);
    }
    for (final o in _pops) {
      final k = ((t - o.t0) / popMs).clamp(0.0, 1.0);
      final to = playerAt(o.to) ?? (o.x, o.y - 20);
      final e = Curves.easeInCubic.transform(k);
      // Out, up and into the player.
      final x = o.x + (to.$1 - o.x) * e;
      final y = o.y - 14 * math.sin(k * math.pi) + (to.$2 - 12 - o.y) * e;
      _circle(c, o.color, x, y, 2.5 * (1 - k * 0.5));
      if (k < 0.85) text(o.label, x, y - 8, o.color, 6);
    }
    _pops.removeWhere((o) => t - o.t0 > popMs);
  }

  void _step(double t) {
    final dt = ((t - _lastT) / 1000).clamp(0.0, 0.1);
    _lastT = t;
    for (final q in _parts) {
      q.age += dt;
      q.vy += 160 * dt;
      q.x += q.vx * dt;
      q.y += q.vy * dt;
    }
    _parts.removeWhere((q) => q.age >= q.life);
    if (_parts.length > 400) _parts.removeRange(0, _parts.length - 400);
  }

  /// The town cart station (§ 1.8): a short rail stub from the town
  /// exit edge ([railEnd], px; `TownPlan.cartRail`) up into the station,
  /// carts rolling in along it, parked on the station with their mine and
  /// biome, and rolling back out.
  void drawTown(Canvas c, MinesState mines, double now, Rect station,
      double railEnd, double t,
      {required MineText text,
      required String Function(String place) label}) {
    _step(t);
    final railX = station.center.dx;
    // Only the stub: the tiles south of the station that TownPlan
    // found bare, never over plots, builds or trees.
    for (var y = station.bottom; y < railEnd; y += 4) {
      _rect(c, MinePalette.rail, railX - 5, y, 1, 3);
      _rect(c, MinePalette.rail, railX + 4, y, 1, 3);
      _rect(c, MinePalette.timber, railX - 6, y, 12, 1);
    }
    final carts = MineWorkRules.townCarts(mines);
    final arrive = MiningRules.t.d('cartTravelSec');
    const anim = 4.0;
    // Carts come in from just past the edge so they roll into view.
    final from = railEnd + 12;
    final parkY = station.top + 3;
    var slot = 0;
    for (final (place, cart) in carts) {
      // Parked carts sit side by side on the station, westward.
      final slotX = station.right - 16.0 * (slot + 1) + 1;
      double? y;
      var onRail = true;
      switch (cart.phase) {
        case CartPhase.toTown:
          final left = cart.t + arrive - now;
          if (left > anim) continue;
          y = parkY + (from - parkY) * (left / anim).clamp(0.0, 1.0);
        case CartPhase.town:
          y = parkY;
          onRail = false;
        case CartPhase.back:
          final k = (now - cart.t) / anim;
          if (k >= 1) continue;
          y = parkY + (from - parkY) * k.clamp(0.0, 1.0);
        case CartPhase.mine:
          continue;
      }
      final m = MiningRules.parse(place);
      final col = MinePalette.vein(MiningRules.themeOf(m?.$1 ?? ''));
      _cart(c, onRail ? railX - 7 : slotX, y,
          cart.phase == CartPhase.back ? 0 : 1, col);
      if (cart.phase == CartPhase.town) {
        // Stacked above the station, one line per parked cart.
        text(label(place), station.center.dx, station.top - 4 - slot * 8.0,
            MinePalette.label, 6);
      }
      slot++;
    }
    _drawParticles(c, (_) => null, text, t);
  }

  void _cart(Canvas c, double x, double y, double fill, Color ore) {
    _rect(c, MinePalette.cartDark, x, y, 14, 9);
    _rect(c, MinePalette.cart, x + 1, y + 1, 12, 6);
    if (fill > 0) {
      final h = (5 * fill.clamp(0.0, 1.0)).roundToDouble();
      _rect(c, ore, x + 2, y + 1 + (5 - h), 10, h);
    }
    _circle(c, MinePalette.cartDark, x + 3, y + 10, 2);
    _circle(c, MinePalette.cartDark, x + 11, y + 10, 2);
  }

  void _pick(Canvas c, double x, double y, double a) {
    c.save();
    c.translate(x, y);
    c.rotate(a);
    _rect(c, MinePalette.timber, -1, -1, 2, 9);
    _rect(c, MinePalette.rockLight, -4, -2, 8, 2);
    c.restore();
  }

  final _paint = Paint();
  void _rect(Canvas c, Color col, double x, double y, double w, double h) {
    _paint.color = col;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _paint);
  }

  void _circle(Canvas c, Color col, double x, double y, double r) {
    _paint.color = col;
    c.drawCircle(Offset(x, y), r, _paint);
  }
}
