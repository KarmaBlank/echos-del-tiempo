import 'dart:typed_data';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/models/fish_line.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/rules/fishing_minigame.dart';
import '../../../../game_engine/rules/map_fishing.dart';
import 'map_themes.dart';

class _Shadow {
  _Shadow(this.x, this.y, this.size);
  double x, y, vx = 0, vy = 0, turn = 0;
  final double size;
}

class _Pop {
  _Pop(this.playerId, this.x, this.y, this.label, this.color, this.t0);
  final String playerId;
  final double x, y;
  final String label;
  final Color color;
  final double t0;
}

/// Pesca dibujada en el mapa del pueblo (fishing.md § 4, v0.22.2): sombras
/// de peces en el agua real, caña y línea en la mano, boya en el tile del
/// lago, medidor de carga, "!" de la picada, barra de captura al lado del
/// personaje y el pez (o el hallazgo) que salta hacia el jugador. Arte
/// procedural; colores en [FishingPalette].
class MapFishingLayer {
  MapFishingLayer([math.Random? rand]) : _rand = rand ?? math.Random(7);
  final math.Random _rand;
  final _shadows = <_Shadow>[];
  final _pops = <_Pop>[];
  GameMap? _map;

  /// Duración del salto del pez hacia el jugador (ms).
  static const popMs = 900.0;

  /// La barra del último cuadro en px del mapa (tests); `null` = no se ve.
  Rect? barRect;

  /// Hay un salto de captura en curso (tests y capturas).
  bool get popping => _pops.isNotEmpty;

  int? _waterKey;

  /// Posiciones (x, y, tamaño) de las sombras (tests).
  List<(double, double, double)> get shadowLayout =>
      [for (final s in _shadows) (s.x, s.y, s.size)];

  void _sync(GameMap m) {
    if (identical(m, _map)) return;
    _map = m;
    if (!m.lobby) {
      _waterKey = null;
      _shadows.clear();
      return;
    }
    final water = <(int, int)>[
      for (var y = 0; y < m.height; y++)
        for (var x = 0; x < m.width; x++)
          if (FishingCast.isWater(m, x, y)) (x, y),
    ];
    // Cada snapshot trae otra instancia de GameMap aunque el lago no cambie:
    // las sombras solo se regeneran si cambia la geometría del agua.
    final key = Object.hash(m.width, m.height,
        Object.hashAll([for (final (x, y) in water) y * m.width + x]));
    if (key == _waterKey) return;
    _waterKey = key;
    _shadows.clear();
    if (water.isEmpty) return;
    // Disposición determinista por geometría del lago.
    final seed = math.Random(key & 0x7fffffff);
    for (var i = 0; i < 7; i++) {
      final (tx, ty) = water[seed.nextInt(water.length)];
      _shadows.add(_Shadow(
          (tx + 0.5) * 16, (ty + 0.5) * 16, 3.0 + seed.nextDouble() * 3));
    }
  }

  bool _wet(double x, double y) {
    final m = _map!;
    final (tx, ty) = FishingCast.tileOf(x, y);
    return FishingCast.isWater(m, tx, ty);
  }

  /// Mueve las sombras; con [lure] (la boya local en el agua) las que
  /// están cerca se le acercan.
  void update(GameMap map, double dt, (double, double)? lure) {
    _sync(map);
    for (final s in _shadows) {
      s.turn -= dt;
      if (s.turn <= 0) {
        final a = _rand.nextDouble() * math.pi * 2;
        s
          ..vx = math.cos(a) * 6
          ..vy = math.sin(a) * 4
          ..turn = 1.5 + _rand.nextDouble() * 2.5;
      }
      if (lure != null) {
        final dx = lure.$1 - s.x, dy = lure.$2 - s.y;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < 56 && d > 5) {
          s
            ..vx = dx / d * 7
            ..vy = dy / d * 7;
        }
      }
      final nx = s.x + s.vx * dt, ny = s.y + s.vy * dt;
      if (_wet(nx, ny)) {
        s
          ..x = nx
          ..y = ny;
      } else {
        s
          ..vx = -s.vx
          ..vy = -s.vy;
      }
    }
  }

  /// Sombras de peces (debajo de los actores).
  void drawShadows(Canvas c) {
    final p = Paint()..color = FishingPalette.shadow;
    for (final s in _shadows) {
      c.drawOval(
          Rect.fromCenter(
              center: Offset(s.x, s.y), width: s.size * 2, height: s.size),
          p);
    }
  }

  /// Agua brillante de un bioma (fishing.md § 11): destellos que laten
  /// sobre el tile del día. [t] en segundos.
  void drawHiddenSpot(Canvas c, GameMap m, String place, int day, double t) {
    final spot = FishingCast.hiddenSpot(m, place, day);
    if (spot == null) return;
    final cx = (spot.$1 + 0.5) * 16, cy = (spot.$2 + 0.5) * 16;
    final pulse = 0.5 + 0.5 * math.sin(t * 3);
    c.drawCircle(Offset(cx, cy), 6 + 3 * pulse,
        Paint()..color = FishingPalette.shimmerGlow);
    final p = Paint()..color = FishingPalette.shimmer;
    for (var i = 0; i < 3; i++) {
      final a = t * 1.7 + i * 2.1;
      final r = 2 + 4 * ((t * 0.8 + i / 3) % 1);
      c.drawRect(
          Rect.fromCenter(
              center: Offset(cx + math.cos(a) * r, cy + math.sin(a) * r),
              width: 1.5,
              height: 1.5),
          p);
    }
  }

  /// La caña en la mano sin lance (cerca del agua, antes de tirar).
  void drawIdleRod(Canvas c, double px, double py, num face) {
    final f = face < 0 ? -1.0 : 1.0;
    final hand = Offset(px + f * 4, py - 6);
    final tip = Offset(px + f * 11, py - 19);
    c.drawLine(hand, tip, Paint()
      ..color = FishingPalette.rod
      ..strokeWidth = 1.5);
    c.drawLine(tip, tip.translate(0, 6), Paint()..color = FishingPalette.line);
  }

  /// Caña, línea y boya de un jugador en (px, py) mirando [dir]. [mine]:
  /// la pesca local (medidor, barra y boya en vuelo).
  void drawAngler(
    Canvas c, {
    required double px,
    required double py,
    required int dir,
    required FishLine line,
    required double t,
    MapFishing? mine,
    void Function(String text, double x, double y, Color color, double size)?
        text,
  }) {
    final face = mine?.dir.$1 ?? dir;
    final hand = Offset(px + face * 4, py - 6);
    final tip = Offset(px + face * 11, py - 19);
    c.drawLine(
        hand,
        tip,
        Paint()
          ..color = FishingPalette.rod
          ..strokeWidth = 1.5);
    final g = mine?.game;
    final b = mine?.bobber ?? (line.hasBobber ? (line.bx, line.by) : null);
    if (b != null) {
      var dip = 0.0;
      if (g?.nibbling ?? false) dip = 1;
      if (line.stage == FishLineStage.bite) dip = 2 + math.sin(t / 30);
      if (line.stage == FishLineStage.reel) {
        dip = 1.5 + math.sin(t / 50) * 1.5;
      }
      final bo = Offset(
          b.$1 +
              (line.stage == FishLineStage.reel ? math.sin(t / 70) * 1.5 : 0),
          b.$2 + dip);
      c.drawLine(tip, bo, Paint()..color = FishingPalette.line);
      if (line.stage == FishLineStage.bite) {
        c.drawCircle(
            bo,
            5 + math.sin(t / 60),
            Paint()
              ..color = FishingPalette.foam
              ..style = PaintingStyle.stroke);
      }
      c.drawCircle(bo, 2, Paint()..color = FishingPalette.bobber);
      c.drawCircle(
          bo.translate(0, -1.5), 1, Paint()..color = FishingPalette.foam);
    } else {
      // Caña sin lance: la línea cuelga un poco.
      c.drawLine(
          tip, tip.translate(0, 6), Paint()..color = FishingPalette.line);
    }
    if (line.stage == FishLineStage.bite) {
      text?.call(
          '!', px, py - 30 + math.sin(t / 90) * 1.5, FishingPalette.bang, 10);
    }
    if (g != null && g.phase == FishPhase.charging) {
      final r = Rect.fromLTWH(px - 10, py - 34, 20, 3);
      c.drawRect(r, Paint()..color = FishingPalette.meterBack);
      c.drawRect(Rect.fromLTWH(r.left, r.top, r.width * g.power, r.height),
          Paint()..color = FishingPalette.meter);
    }
    if (mine != null) {
      if (g != null && g.phase == FishPhase.reel) {
        // La barra va por encima de nombres y carteles: se dibuja al final,
        // en drawOverlay, con la transformación del mundo guardada acá.
        barRect = Rect.fromLTWH(px + 12, py - 38, 6, 34);
        _overlay = (Float64List.fromList(c.getTransform()), barRect!, g);
      } else {
        barRect = null;
        _overlay = null;
      }
    }
  }

  (Float64List, Rect, FishingMinigame)? _overlay;

  /// Dibuja la barra del minijuego por encima de todo (etiquetas incluidas).
  /// [c] ya está en px del lienzo virtual (antes de la cámara).
  void drawOverlay(Canvas c) {
    final o = _overlay;
    _overlay = null;
    if (o == null) return;
    c.save();
    c.transform(o.$1);
    _bar(c, o.$2, o.$3);
    c.restore();
  }

  Rect _bar(Canvas c, Rect r, FishingMinigame g) {
    c.drawRect(r.inflate(1), Paint()..color = FishingPalette.barFrame);
    c.drawRect(r, Paint()..color = FishingPalette.barBack);
    double y(double v) => r.bottom - v * r.height;
    c.drawRect(
        Rect.fromLTRB(r.left, y(g.zonePos + g.zoneSize), r.right, y(g.zonePos)),
        Paint()
          ..color =
              g.fishInside ? FishingPalette.zoneIn : FishingPalette.zoneOut);
    c.drawRect(
        Rect.fromCenter(
            center: Offset(r.center.dx, y(g.fishPos)), width: 6, height: 2),
        Paint()..color = FishingPalette.bobber);
    // Progreso, una tira al lado.
    final pr = Rect.fromLTWH(r.right + 2, r.top, 2, r.height);
    c.drawRect(pr, Paint()..color = FishingPalette.barBack);
    c.drawRect(
        Rect.fromLTRB(
            pr.left, pr.bottom - g.progress * pr.height, pr.right, pr.bottom),
        Paint()..color = FishingPalette.meter);
    return r;
  }

  /// La captura salta del agua (x, y) hacia el jugador.
  void addPop(String playerId, double x, double y, String label, Color color,
          double t) =>
      _pops.add(_Pop(playerId, x, y, label, color, t));

  /// Dibuja los saltos en curso; [posOf] da dónde está cada jugador.
  void drawPops(
      Canvas c,
      double t,
      (double, double)? Function(String) posOf,
      void Function(String text, double x, double y, Color color, double size)
          text) {
    _pops.removeWhere((p) => t - p.t0 > popMs + 900);
    for (final p in _pops) {
      final to = posOf(p.playerId) ?? (p.x, p.y);
      final k = ((t - p.t0) / popMs).clamp(0.0, 1.0);
      final x = p.x + (to.$1 - p.x) * k;
      final y = p.y + (to.$2 - 10 - p.y) * k - math.sin(k * math.pi) * 22;
      if (k < 1) {
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 7, height: 4),
            Paint()..color = p.color);
        if (k < 0.2) {
          c.drawCircle(
              Offset(p.x, p.y),
              3 + k * 20,
              Paint()
                ..color = FishingPalette.foam
                ..style = PaintingStyle.stroke);
        }
      }
      text(p.label, to.$1, to.$2 - 34 - k * 4, p.color, 6);
    }
  }
}
