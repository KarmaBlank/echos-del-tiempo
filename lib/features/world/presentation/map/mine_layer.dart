import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/mine_catalog.dart';
import '../../../../game_engine/rules/autotile.dart';
import '../../../../game_engine/rules/mine_work_rules.dart';
import '../../../../game_engine/rules/mining_rules.dart';
import 'map_themes.dart';
import 'tile_target.dart';

typedef MineText = void Function(
    String s, double x, double y, Color col, double size);

class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.color,
      {this.size = 1.5, this.gravity = 160});
  double x, y, vx, vy, life;
  final double size, gravity;
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

  /// One local hit on ([tx], [ty]) from a player at ([fromX], [fromY])
  /// (feet, px): rock chips thrown back toward the player, a puff of
  /// dust and a couple of sparks; [bounced] (pick too weak / bedrock)
  /// throws only sparks. Also starts the tile's impact shake.
  void onSwing(int tx, int ty, double t,
      {double? fromX, double? fromY, bool bounced = false}) {
    final cx = (tx + 0.5) * ts, cy = (ty + 0.5) * ts;
    _hitTile = (tx, ty);
    _hitT0 = t;
    // Impact point: the face of the tile toward the player.
    final ax = fromX == null ? 0.0 : (fromX - cx).sign;
    final ay = fromY == null ? 0.0 : (fromY - 9 - cy).sign;
    final ix = cx + ax * 6, iy = cy + ay * 6;
    final sparks = bounced ? 7 : 3;
    for (var i = 0; i < sparks; i++) {
      final a = _rand.nextDouble() * math.pi * 2;
      final sp = 35 + _rand.nextDouble() * 25;
      _parts.add(_Particle(ix, iy, math.cos(a) * sp + ax * 20,
          math.sin(a) * sp + ay * 20, 0.16 + _rand.nextDouble() * 0.08,
          MinePalette.spark,
          size: 1));
    }
    if (bounced) return;
    for (var i = 0; i < 4; i++) {
      final sp = 25 + _rand.nextDouble() * 35;
      final spread = (_rand.nextDouble() - 0.5) * 40;
      _parts.add(_Particle(
          ix,
          iy,
          ax * sp + (ax == 0 ? spread : spread * 0.3),
          ay * sp - 35 + (ay == 0 ? 0 : spread * 0.3),
          0.35 + _rand.nextDouble() * 0.2,
          i.isEven ? MinePalette.rockLight : MinePalette.rockTop,
          size: i == 0 ? 2 : 1));
    }
    for (var i = 0; i < 3; i++) {
      _parts.add(_Particle(
          ix + (_rand.nextDouble() - 0.5) * 6,
          iy + (_rand.nextDouble() - 0.5) * 6,
          (_rand.nextDouble() - 0.5) * 10 + ax * 6,
          -8 - _rand.nextDouble() * 8,
          0.45 + _rand.nextDouble() * 0.2,
          MinePalette.dust.withValues(alpha: 0.7),
          size: 2 + _rand.nextDouble() * 1.5,
          gravity: 0));
    }
  }

  (int, int)? _hitTile;
  double _hitT0 = -1e9;

  /// Milliseconds the hit tile shakes; the dig indicator stays after the
  /// last hit when the player is no longer holding E / the click.
  static const hitShakeMs = 110.0, indicatorLingerMs = 600.0;

  /// The swing of the pick, ms after a hit: strike (the head lands at
  /// [strikeMs], with the chips), recoil, then wind-up back over the shoulder for the next hit.
  static const strikeMs = 45.0, recoilMs = 90.0;

  /// Pick angle relative to pointing at the target (rad; negative =
  /// raised back over the shoulder) [ms] after a hit, with [period] ms
  /// between hits. Past the period it stays raised.
  static double swingOffset(double ms, double period) {
    const raised = -2.1, recoil = -0.55;
    if (ms < 0) return raised;
    if (ms < strikeMs) {
      return raised * (1 - Curves.easeIn.transform(ms / strikeMs));
    }
    if (ms < strikeMs + recoilMs) {
      final k = (ms - strikeMs) / recoilMs;
      return recoil * Curves.easeOut.transform(k);
    }
    final rest = math.max(1.0, period - strikeMs - recoilMs);
    final k = ((ms - strikeMs - recoilMs) / rest).clamp(0.0, 1.0);
    return recoil + (raised - recoil) * Curves.easeInOut.transform(k);
  }

  /// Fill of the dig indicator for a tile with [dealt] of [hits], or
  /// `null` when it hides: the player let go more than
  /// [indicatorLingerMs] ago.
  static double? digProgress(
      {required int dealt,
      required int hits,
      required double sinceHitMs,
      required bool holding}) {
    if (!holding && sinceHitMs > indicatorLingerMs) return null;
    if (hits <= 0) return 0;
    return (dealt / hits).clamp(0.0, 1.0);
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

  /// Crack segments, in the order they appear as damage grows (tile
  /// local px).
  static const _crackSegs = [
    (8.0, 2.0, 6.0, 6.0),
    (6.0, 6.0, 9.0, 9.0),
    (6.0, 6.0, 2.0, 8.0),
    (9.0, 9.0, 13.0, 12.0),
    (9.0, 9.0, 8.0, 14.0),
    (6.0, 6.0, 11.0, 4.0),
    (2.0, 8.0, 2.0, 12.0),
    (13.0, 12.0, 14.0, 6.0),
  ];

  /// Crack segments drawn at [progress] (0..1) of a tile's hits.
  static int crackSegments(double progress) => progress <= 0
      ? 0
      : (1 + progress * (_crackSegs.length - 1))
          .floor()
          .clamp(1, _crackSegs.length);

  void _crack(Canvas c, double px, double py, double progress) {
    final n = crackSegments(progress);
    if (n == 0) return;
    final p = Paint()
      ..color = MinePalette.crack
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (final (x0, y0, x1, y1) in _crackSegs.take(n)) {
      path
        ..moveTo(px + x0, py + y0)
        ..lineTo(px + x1, py + y1);
    }
    c.drawPath(path, p);
    // Deep damage: loose chips darken the face.
    if (n >= 6) {
      _rect(c, MinePalette.rockDark, px + 3, py + 3, 2, 2);
      _rect(c, MinePalette.rockDark, px + 11, py + 9, 2, 1);
    }
  }

  /// The crack overlay of tile ([x], [y]) at [progress] (0..1), shaken
  /// for [hitShakeMs] after a hit on it.
  void drawCrack(Canvas c, int x, int y, double progress, double t) {
    var ox = 0.0, oy = 0.0;
    if (t - _hitT0 < hitShakeMs && _hitTile == (x, y)) {
      final k = 1 - (t - _hitT0) / hitShakeMs;
      ox = (math.sin(t / 9) * 1.5 * k).roundToDouble();
      oy = (math.cos(t / 13) * k).roundToDouble();
    }
    _crack(c, x * ts + ox, y * ts + oy, progress);
  }

  /// A short light flash over the face of the tile just hit.
  void drawImpactFlash(Canvas c, double t) {
    final k = 1 - (t - _hitT0) / hitShakeMs;
    if (k <= 0 || k > 1) return;
    if (_hitTile case (final hx, final hy)) {
      _rect(c, MinePalette.pickEdge.withValues(alpha: 0.35 * k), hx * ts + 1,
          hy * ts + 1, ts - 2, ts - 2);
    }
  }

  /// Steps and draws the loose particles (chips, dust, sparks) alone
  /// (previews).
  void drawEffects(Canvas c, double t) {
    _step(t);
    _drawParticles(c, (_) => null, (s, x, y, col, size) {}, t);
  }

  /// The mine level: station and cart, miners, cracks, bombs, particles,
  /// pops. [cracks]: tile index → hits dealt (local prediction).
  /// [swing]: the local player's swing (target tile, ms since the last
  /// hit, ms between hits, player feet). [indicator]: the tile being
  /// dug, its fill 0..1 and whether the pick can break it.
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
    ((int, int), double, double, (double, double))? swing,
    ((int, int), double, bool)? indicator,
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
    // The rails are floor tiles (drawTrack), under the actors.
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
    // Cracks (with the impact shake on the tile just hit).
    for (final e in cracks.entries) {
      final (x, y) = lvl.xy(e.key);
      final hits = MiningRules.hits(MiningRules.tileAt(lvl, st, x, y), lvl.level);
      if (hits > 0) drawCrack(c, x, y, e.value / hits, t);
    }
    drawImpactFlash(c, t);
    // Dig indicator (the same marker as the farm's).
    if (indicator case (final tile, final progress, final ok)) {
      drawTileTarget(c, [tile], ok, progress: progress);
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
    // Local swing, facing the target tile.
    if (swing
        case ((final tx, final ty), final ms, final period, (final ox, final oy))) {
      drawSwing(c, tx, ty, ox, oy, swingOffset(ms, period));
    }
    _drawParticles(c, playerAt, text, t);
  }

  // Cached hidden veins for the Pico B sparkle: recomputed only when the
  // player changes tile, the level state changes or the radius changes.
  (Object?, int, int, double)? _detectKey;
  List<(int, int)> _detectTiles = const [];

  /// Hidden veins near the player for the Pico B perk (cached).
  List<(int, int)> detectTiles(
      MineLevel lvl, MineLevelState st, double px, double py, double radius) {
    final key = (st, px.floor(), py.floor(), radius);
    if (key != _detectKey) {
      _detectKey = key;
      _detectTiles = MineWorkRules.hiddenVeins(lvl, st, px, py, radius);
    }
    return _detectTiles;
  }

  /// Whether the sparkle of tile ([x], [y]) shows at [t] ms: each tile
  /// blinks on its own phase, lit about a sixth of the time.
  static bool sparkleOn(int x, int y, double t) {
    final phase = ((x * 73856093) ^ (y * 19349663)) & 0x3ff;
    return ((t + phase * 3) % 1400) < 220;
  }

  /// Subtle 1–2 px sparkle on hidden veins ([tiles]; Pico B detect).
  void drawDetectSparkles(Canvas c, List<(int, int)> tiles, double t) {
    final p = Paint()..color = MinePalette.spark.withValues(alpha: 0.85);
    for (final (x, y) in tiles) {
      if (!sparkleOn(x, y, t)) continue;
      final h = ((x * 31) ^ (y * 17)) & 7;
      final sx = (x * ts + 4 + h).floorToDouble(),
          sy = (y * ts + 4 + ((h * 5) & 7)).floorToDouble();
      c.drawRect(Rect.fromLTWH(sx, sy, 1, 1), p);
      if (((t ~/ 110) + h).isEven) {
        c.drawRect(Rect.fromLTWH(sx - 1, sy, 1, 1), p);
        c.drawRect(Rect.fromLTWH(sx + 1, sy, 1, 1), p);
        c.drawRect(Rect.fromLTWH(sx, sy - 1, 1, 1), p);
        c.drawRect(Rect.fromLTWH(sx, sy + 1, 1, 1), p);
      }
    }
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
      q.vy += q.gravity * dt;
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

  /// The player's pick from the shoulder of a player at ([ox], [oy])
  /// (feet, px) toward tile ([tx], [ty]), turned [offset] rad back from
  /// pointing at it (over the shoulder on the side the player faces).
  void drawSwing(
      Canvas c, int tx, int ty, double ox, double oy, double offset) {
    final sx = ox, sy = oy - 9;
    final dx = (tx + 0.5) * ts - sx, dy = (ty + 0.5) * ts - sy;
    final side = dx < -0.5 ? -1.0 : 1.0;
    final a = math.atan2(dy, dx) + side * offset;
    c.save();
    c.translate(sx.roundToDouble(), sy.roundToDouble());
    c.rotate(a);
    // Handle along +x, head across its end; the spike on the striking
    // side (toward the tile at the impact).
    _rect(c, MinePalette.timberDark, 1, 0, 10, 1);
    _rect(c, MinePalette.timber, 1, -1, 10, 1);
    _rect(c, MinePalette.pickHeadDark, 10, -4, 3, 8);
    _rect(c, MinePalette.pickHead, 10, -4, 2, 8);
    final down = side > 0;
    _rect(c, MinePalette.pickHead, 9, down ? 4 : -6, 2, 2);
    _rect(c, MinePalette.pickEdge, 8, down ? 6 : -7, 1, 1);
    _rect(c, MinePalette.pickHeadDark, 9, down ? -5 : 4, 2, 1);
    c.restore();
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
  /// The cart track on the floor ([tiles], `MiningRules.track`): two
  /// rails on wooden sleepers, autotiled (straight, end, corner) from
  /// the neighbours on the track. Drawn with the floor, before actors.
  void drawTrack(Canvas c, List<(int, int)> tiles) {
    final set = tiles.toSet();
    for (final (x, y) in tiles) {
      final m = Autotile.mask4((dx, dy) => set.contains((x + dx, y + dy)));
      final px = x * ts, py = y * ts;
      final horiz = m & (Autotile.e | Autotile.w) != 0 || m == 0;
      final vert = m & (Autotile.n | Autotile.s) != 0;
      if (horiz) {
        final l = m & Autotile.w != 0 || m == 0 ? 0.0 : 3.0;
        final r = m & Autotile.e != 0 || m == 0 ? ts : ts - 3;
        for (var k = l + 1; k < r; k += 4) {
          _rect(c, MinePalette.timberDark, px + k, py + 4, 2, 9);
          _rect(c, MinePalette.timber, px + k, py + 4, 2, 1);
        }
        _rect(c, MinePalette.rail, px + l, py + 5, r - l, 1);
        _rect(c, MinePalette.rail, px + l, py + 11, r - l, 1);
        _rect(c, MinePalette.timberDark, px + l, py + 6, r - l, 1);
        _rect(c, MinePalette.timberDark, px + l, py + 12, r - l, 1);
      }
      if (vert) {
        final t = m & Autotile.n != 0 ? 0.0 : 3.0;
        final b = m & Autotile.s != 0 ? ts : ts - 3;
        for (var k = t + 1; k < b; k += 4) {
          _rect(c, MinePalette.timberDark, px + 3, py + k, 10, 2);
        }
        _rect(c, MinePalette.rail, px + 4, py + t, 1, b - t);
        _rect(c, MinePalette.rail, px + 11, py + t, 1, b - t);
      }
    }
  }

  void _rect(Canvas c, Color col, double x, double y, double w, double h) {
    _paint.color = col;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _paint);
  }

  void _circle(Canvas c, Color col, double x, double y, double r) {
    _paint.color = col;
    c.drawCircle(Offset(x, y), r, _paint);
  }
}
