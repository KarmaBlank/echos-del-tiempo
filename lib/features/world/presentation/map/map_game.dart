import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/models/game_session.dart';
import '../../../combat/presentation/game_sprites.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'actor_painter.dart';
import 'map_themes.dart';
import 'tile_painter.dart';

/// Lee la entrada de movimiento (-1..1 en cada eje). Por defecto, el
/// estado del teclado físico (WASD / flechas).
typedef MoveInputReader = (double, double) Function();

/// Posición suavizada (`disp[key]` de `lerpPos`).
class _Disp {
  _Disp(this.x, this.y);
  double x, y;
}

/// El mapa del prototipo (`render`, líneas 1019-1091) como juego Flame:
/// dibuja la sesión del [controller] a resolución virtual 480×288 y la
/// escala con vecino más cercano. Mueve al jugador local en cada frame
/// (`updateMe`). Ver docs/specs/exploration.md.
class MapGame extends Game {
  MapGame({
    required this.controller,
    required this.sprites,
    MoveInputReader? input,
  })  : _input = input ?? keyboardInput,
        actors = ActorPainter(sprites);

  final SessionController controller;
  final GameSprites sprites;
  final MoveInputReader _input;
  final ActorPainter actors;
  final tiles = TilePainter();

  /// Resolución virtual (`VW`, `VH`).
  static const vw = 480;
  static const vh = 288;
  static const ts = TilePainter.ts;

  /// Reloj de animación en ms (`performance.now()` del prototipo).
  double t = 0;

  /// Cámara (`cam`), esquina superior izquierda en px del mundo.
  double camX = 0, camY = 0;

  final _disp = <String, _Disp>{};
  double _frameDt = 1 / 60;

  /// WASD / flechas del teclado físico.
  static (double, double) keyboardInput() {
    final k = HardwareKeyboard.instance.logicalKeysPressed;
    var vx = 0.0, vy = 0.0;
    if (k.contains(LogicalKeyboardKey.keyA) ||
        k.contains(LogicalKeyboardKey.arrowLeft)) {
      vx--;
    }
    if (k.contains(LogicalKeyboardKey.keyD) ||
        k.contains(LogicalKeyboardKey.arrowRight)) {
      vx++;
    }
    if (k.contains(LogicalKeyboardKey.keyW) ||
        k.contains(LogicalKeyboardKey.arrowUp)) {
      vy--;
    }
    if (k.contains(LogicalKeyboardKey.keyS) ||
        k.contains(LogicalKeyboardKey.arrowDown)) {
      vy++;
    }
    return (vx, vy);
  }

  @override
  Color backgroundColor() => kMapBackground;

  /// Factor de suavizado por frame de 60 Hz llevado a [dt] segundos.
  static double smoothing(double perFrame, double dt) =>
      1 - math.pow(1 - perFrame, dt * 60).toDouble();

  @override
  void update(double dt) {
    t += dt * 1000;
    _frameDt = dt;
    final (ix, iy) = _input();
    controller.updateLocal(math.min(0.05, dt), ix, iy);
    final view = controller.view;
    if (view != null) _updateCamera(view, dt);
  }

  /// `render`, líneas 1021-1025.
  void _updateCamera(SessionView view, double dt) {
    final map = view.map;
    final mw = map.width * ts, mh = map.height * ts;
    final fx = controller.local.x, fy = controller.local.y;
    final tx = mw < vw ? (mw - vw) / 2 : (fx - vw / 2).clamp(0.0, mw - vw);
    final ty = mh < vh ? (mh - vh) / 2 : (fy - vh / 2).clamp(0.0, mh - vh);
    final k = smoothing(0.25, dt);
    camX += (tx - camX) * k;
    camY += (ty - camY) * k;
    if ((camX - tx).abs() > 200 || (camY - ty).abs() > 200) {
      camX = tx;
      camY = ty;
    }
  }

  /// `lerpPos`: suaviza la posición de otros actores.
  _Disp _lerpPos(String key, double x, double y) {
    final d = _disp[key];
    if (d == null || math.sqrt(math.pow(d.x - x, 2) + math.pow(d.y - y, 2)) > 60) {
      return _disp[key] = _Disp(x, y);
    }
    final k = smoothing(0.35, _frameDt);
    d
      ..x += (x - d.x) * k
      ..y += (y - d.y) * k;
    return d;
  }

  @override
  void render(Canvas canvas) {
    final view = controller.view;
    final full = Offset.zero & Size(size.x, size.y);
    canvas.drawRect(full, Paint()..color = kMapBackground);
    if (view == null) return;

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder,
        Rect.fromLTWH(0, 0, vw.toDouble(), vh.toDouble()));
    drawWorld(c, view);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(vw, vh);
    picture.dispose();

    // Escalado entero o no, siempre con vecino más cercano y centrado.
    final s = math.min(size.x / vw, size.y / vh);
    final w = vw * s, h = vh * s;
    final dst = Rect.fromLTWH(((size.x - w) / 2).roundToDouble(),
        ((size.y - h) / 2).roundToDouble(), w.roundToDouble(), h.roundToDouble());
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, vw.toDouble(), vh.toDouble()),
        dst,
        SpriteCatalog.pixelPaint());
    image.dispose();
  }

  /// Todas las capas del mapa en el lienzo virtual (orden del spec).
  void drawWorld(Canvas c, SessionView view) {
    final s = view.session;
    final map = view.map;
    c.drawRect(Rect.fromLTWH(0, 0, vw.toDouble(), vh.toDouble()),
        Paint()..color = kMapBackground);
    c.save();
    c.translate(-camX.roundToDouble(), -camY.roundToDouble());

    // Tiles visibles.
    final x0 = math.max(0, (camX / ts).floor());
    final y0 = math.max(0, (camY / ts).floor());
    final x1 = math.min(map.width - 1, x0 + vw ~/ ts + 1);
    final y1 = math.min(map.height - 1, y0 + vh ~/ ts + 1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        tiles.draw(c, map.tileAt(x, y), x * ts, y * ts, map.theme, x, y,
            t: t, gateOpen: s.gateOpen, lobby: map.lobby);
      }
    }
    final merchant = map.merchant;
    if (merchant != null) {
      actors.text(c, 'TIENDA', merchant.x, merchant.y - 34,
          const Color(0xFFFFD166), 6);
    }
    if (map.lobby) {
      actors.text(c, 'MOSTRADOR DE MISIONES', 13 * ts, ts + 10,
          const Color(0xFF48DBFB), 7);
      actors.text(c, 'ARMERÍA', 21.5 * ts, ts + 10, const Color(0xFFFF9F43), 7);
    }

    // Entidades ordenadas por y (desempate: orden de llegada).
    final ents = <(double, int, void Function())>[];
    void add(double y, void Function() draw) => ents.add((y, ents.length, draw));

    final grace = s.mode == SessionMode.field &&
        s.graceLeft > 0 &&
        (t / 110).floor() % 2 == 1;
    for (final p in s.playerList) {
      final mine = p.id == view.localId;
      final double px, py;
      if (mine) {
        px = controller.local.x;
        py = controller.local.y;
      } else {
        final d = _lerpPos('p${p.id}', p.x, p.y);
        px = d.x;
        py = d.y;
      }
      final weapon = controller.engine.catalog.weapons[p.profile.equipped];
      add(py, () {
        actors.hero(c,
            classId: p.profile.classId,
            weaponType: weapon?.type,
            x: px,
            y: py,
            t: t,
            dir: mine ? controller.local.dir : p.dir,
            moving: mine ? controller.local.moving : p.moving,
            dead: p.hp <= 0,
            blink: grace && p.hp > 0);
        actors.text(c, p.name, px, py - 22,
            mine ? const Color(0xFFFFD166) : const Color(0xFFFFFFFF), 6);
      });
    }

    final mission = s.mission;
    final showField =
        s.mode == SessionMode.field || s.mode == SessionMode.levelUp;
    if (mission != null && showField) {
      for (final it in mission.items) {
        final visible = it.kind == MissionItemKind.seal || !it.done;
        if (visible) add(it.y, () => actors.item(c, it, t));
      }
      for (final e in mission.enemies) {
        if (!e.alive) continue;
        final d = _lerpPos('f${e.id}', e.x, e.y);
        add(d.y, () {
          actors.enemy(c,
              type: e.group.first,
              x: d.x,
              y: d.y,
              dir: e.dir,
              t: t,
              elite: e.elite);
          if (e.elite) {
            actors.text(
                c, '★ÉLITE', d.x, d.y - 34, const Color(0xFFFFD166), 6);
          }
          if (e.aggro) {
            actors.text(c, '!', d.x, d.y - 22 + math.sin(t / 90) * 1.5,
                const Color(0xFFFF4757), 9);
          }
          if (e.boss) {
            actors.text(c, 'JEFE', d.x, d.y - 48, const Color(0xFFFF4757), 7);
          }
        });
      }
    }
    ents.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    for (final e in ents) {
      e.$3();
    }
    c.restore();
  }
}
