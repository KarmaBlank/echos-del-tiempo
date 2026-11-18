import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/models/item.dart';
import '../../../../game_engine/models/loot.dart';
import '../../../../game_engine/models/loot_filter.dart';
import '../../../../game_engine/models/session_event.dart';
import '../../../../game_engine/rules/eco_rules.dart';
import '../../../../game_engine/rules/zone_rules.dart';
import '../../../combat/presentation/game_sprites.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import '../../../missions/domain/mission_text.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'actor_painter.dart';
import 'loot_painter.dart';
import 'map_themes.dart';
import 'tile_painter.dart';
import 'void_painter.dart';

/// Lee la entrada de movimiento (-1..1 en cada eje). Por defecto, el
/// estado del teclado físico (WASD / flechas).
typedef MoveInputReader = (double, double) Function();

/// Lee si una tecla está apretada (Alt para ver todo el loot, E /
/// Espacio para levantar). Por defecto, el teclado físico.
typedef KeyReader = bool Function();

/// Haz de luz de un Legendario que fue directo al inventario (sin piso):
/// sale del jugador local un rato.
class _Beam {
  _Beam(this.t0);
  final double t0;
}

/// Caída al vacío de un jugador (exploration.md § "Caída al vacío").
class _Fall {
  _Fall(this.t0, this.x, this.y);
  final double t0;

  /// Dónde estaba al caer (px del mundo).
  final double x, y;
}

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
    KeyReader? showAllLoot,
    KeyReader? pickupKey,
  })  : _input = input ?? keyboardInput,
        _showAll = showAllLoot ?? altHeld,
        _pickKey = pickupKey ?? pickupHeld,
        actors = ActorPainter(sprites) {
    loot = LootPainter(
      nameOf: (d) => lootName(controller, d),
      weaponTypeOf: (id) => controller.engine.catalog.weapons[id]?.type,
    );
    _events = controller.events.listen(_onEvent);
  }

  final SessionController controller;
  final GameSprites sprites;
  final MoveInputReader _input;
  final ActorPainter actors;
  final tiles = TilePainter();
  final voidBg = VoidPainter();
  late final LootPainter loot;
  final KeyReader _showAll;
  final KeyReader _pickKey;
  final _pickEdge = KeyEdge();
  late final StreamSubscription<SessionEvent> _events;

  /// Cuándo se vio por primera vez cada objeto del piso (estallido del
  /// haz del Legendario al caer).
  final _seen = <int, double>{};
  final _beams = <_Beam>[];

  /// Veredicto del filtro por objeto del piso (se recalcula si cambia
  /// el filtro o el nivel del jugador).
  final _verdicts = <int, (String?, int, FilterVerdict)>{};

  /// Duración del estallido del haz al caer (ms).
  static const beamBurstMs = 1500.0;

  /// Duración del haz de un Legendario que fue al inventario (ms).
  static const inventoryBeamMs = 2600.0;

  /// Resolución virtual (`VW`, `VH`).
  static const vw = 480;
  static const vh = 288;
  static const ts = TilePainter.ts;

  /// Reloj de animación en ms (`performance.now()` del prototipo).
  double t = 0;

  /// Escalado del mundo (ajuste ESCALADO; lo pone `WorldScreen`).
  ScaleMode scaleMode = ScaleMode.fit;

  /// Multiplicador de las partículas del mapa (ajuste PARTÍCULAS).
  double particleDensity = 1;

  /// Dónde se dibuja el mundo virtual dentro de [screen].
  Rect viewRect(Size screen) =>
      mapViewRect(screen, Size(vw.toDouble(), vh.toDouble()), scaleMode);

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

  /// Alt (izquierdo o derecho): mostrar también el loot oculto.
  static bool altHeld() => HardwareKeyboard.instance.isAltPressed;

  /// E / Espacio (levantar; el controlador las usa antes para el
  /// mostrador, la armería y los sellos).
  static bool pickupHeld() {
    final k = HardwareKeyboard.instance.logicalKeysPressed;
    return k.contains(LogicalKeyboardKey.keyE) ||
        k.contains(LogicalKeyboardKey.space);
  }

  /// Nombre para mostrar de un drop (arma o pila).
  static String lootName(SessionController c, LootDrop d) =>
      lootDropName(c.engine.progression.items.displayName, d,
          ecoName: c.engine.progression.ecos.fullName);

  /// Veredicto del filtro del jugador local para [g].
  FilterVerdict verdictFor(GroundLoot g) {
    final me = controller.session?.players[controller.localId];
    if (me == null) return const FilterVerdict(true, FilterStyle.empty);
    final p = me.profile;
    final cached = _verdicts[g.id];
    if (cached != null && cached.$1 == p.lootFilter && cached.$2 == p.level) {
      return cached.$3;
    }
    final v = controller.engine.lootVerdict(p, g.drop);
    _verdicts[g.id] = (p.lootFilter, p.level, v);
    return v;
  }

  /// Duración del fundido al cambiar de piso (ms).
  static const fadeMs = 700.0;

  /// Cuándo empezó el último fundido de cambio de piso (`null` = nunca).
  double? _fadeT0;

  /// Hay un fundido de cambio de piso en curso (tests).
  bool get fading => _fadeT0 != null && t - _fadeT0! < fadeMs;

  /// Duración de la animación de caída (achicarse + aparecer) en ms.
  static const fallMs = 900.0;

  /// Cuánto dura el cartel `¡Caíste al vacío!` del jugador local (ms).
  static const fallToastMs = 2000.0;

  /// Texto del cartel de caída del jugador local.
  static const fallToastText = '¡Caíste al vacío!';

  /// Caídas en curso por jugador.
  final _falls = <String, _Fall>{};

  /// Última posición dibujada de cada jugador (de dónde cayó).
  final _lastDrawn = <String, (double, double)>{};

  /// Cuándo cayó el jugador local por última vez (cartel).
  double? _myFallT0;

  /// Progreso 0..1 de la caída de [playerId] (`null` si no está cayendo).
  double? fallProgress(String playerId) {
    final f = _falls[playerId];
    if (f == null) return null;
    final q = (t - f.t0) / fallMs;
    return q >= 1 ? null : q;
  }

  /// Se ve el cartel `¡Caíste al vacío!` (tests).
  bool get showingFallToast =>
      _myFallT0 != null && t - _myFallT0! < fallToastMs;

  /// Dónde empezó la caída de [playerId] (tests).
  (double, double)? fallOrigin(String playerId) => _falls[playerId] == null
      ? null
      : (_falls[playerId]!.x, _falls[playerId]!.y);

  /// Arranca la animación de caída de [playerId] (con
  /// `FellIntoVoidEvent`).
  void startFall(String playerId) {
    final from = _lastDrawn[playerId];
    final p = controller.session?.players[playerId];
    _falls[playerId] = _Fall(t, from?.$1 ?? p?.x ?? 0, from?.$2 ?? p?.y ?? 0);
    _disp.remove('p$playerId');
    if (playerId == controller.localId) _myFallT0 = t;
  }

  void _onEvent(SessionEvent e) {
    if (e is FloorChangedEvent) _fadeT0 = t;
    if (e case FellIntoVoidEvent(:final playerId)) startFall(playerId);
    if (e case LootDropEvent(:final playerId, :final drop, :final groundId)
        when playerId == controller.localId &&
            groundId == null &&
            drop.item?.rarity == Rarity.legendario) {
      _beams.add(_Beam(t));
    }
  }

  @override
  void onRemove() {
    unawaited(_events.cancel());
    super.onRemove();
  }

  /// E / Espacio sin otra interacción a mano: levanta lo más cercano.
  /// Devuelve el id pedido (o `null`).
  int? tryPickUp() {
    final view = controller.view;
    final s = controller.session;
    if (view == null ||
        s == null ||
        view.panel != null ||
        view.prompt != null ||
        controller.typing ||
        (s.mode != SessionMode.field && s.mode != SessionMode.lobby) ||
        s.players[controller.localId] == null) {
      return null;
    }
    final target =
        nearestPickable(_visible(s), controller.local.x, controller.local.y);
    if (target == null) return null;
    controller.pickUp(target.ground.id);
    return target.ground.id;
  }

  List<LootOnFloor> _visible(GameSession s) =>
      visibleLoot(s, controller.localId, (d) => _verdictOf(d, s),
          showAll: _showAll());

  FilterVerdict _verdictOf(LootDrop d, GameSession s) {
    for (final g in s.ground) {
      if (identical(g.drop, d)) return verdictFor(g);
    }
    final p = s.players[controller.localId]!.profile;
    return controller.engine.lootVerdict(p, d);
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
    if (_pickEdge.poll(_pickKey())) tryPickUp();
    final view = controller.view;
    if (view != null) _updateCamera(view, dt);
  }

  /// El piso actual de la misión dentro del atlas (o `null`).
  static MapFloor? currentFloor(SessionView view) {
    final m = view.session.mission;
    if (m == null || view.map.floors.isEmpty) return null;
    return view.map.floor(m.floor);
  }

  /// `render`, líneas 1021-1025. En una zona la cámara se limita al piso
  /// actual del atlas (exploration.md § "Mundo y pisos").
  void _updateCamera(SessionView view, double dt) {
    final map = view.map;
    final f = currentFloor(view)?.bounds;
    final bx = (f?.x ?? 0) * ts, by = (f?.y ?? 0) * ts;
    final mw = (f?.w ?? map.width) * ts, mh = (f?.h ?? map.height) * ts;
    var fx = controller.local.x, fy = controller.local.y;
    // Mientras el jugador local se achica, la cámara se queda donde cayó.
    final fall = _falls[controller.localId];
    final fq = fallProgress(controller.localId);
    if (fall != null && fq != null && fq < 0.5) {
      fx = fall.x;
      fy = fall.y;
    }
    final tx =
        mw < vw ? bx + (mw - vw) / 2 : (fx - vw / 2).clamp(bx, bx + mw - vw);
    final ty =
        mh < vh ? by + (mh - vh) / 2 : (fy - vh / 2).clamp(by, by + mh - vh);
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
    if (d == null ||
        math.sqrt(math.pow(d.x - x, 2) + math.pow(d.y - y, 2)) > 60) {
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
    final c =
        Canvas(recorder, Rect.fromLTWH(0, 0, vw.toDouble(), vh.toDouble()));
    drawWorld(c, view);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(vw, vh);
    picture.dispose();

    // Entero (PIXEL PERFECT) o fraccional (AJUSTAR), siempre con vecino
    // más cercano y centrado (docs/specs/settings.md § 3.1).
    final dst = viewRect(Size(size.x, size.y));
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
    // Vacío de las zonas de abismo: fondo con paralaje bajo los tiles.
    final abyss = kAbyssThemes.contains(map.theme);
    if (abyss) {
      voidBg.draw(c, map.theme, vw.toDouble(), vh.toDouble(),
          camX: camX, camY: camY, t: t, density: particleDensity);
    }
    c.save();
    c.translate(-camX.roundToDouble(), -camY.roundToDouble());

    // Estado de las zonas para el jugador local (entradas del mundo).
    final zones = map.entrances.isEmpty
        ? const <int, ZoneStatus>{}
        : {for (final z in controller.zones) z.zone.index: z};
    bool open(int zone) => zones[zone]?.open ?? false;

    // Tiles visibles.
    final x0 = math.max(0, (camX / ts).floor());
    final y0 = math.max(0, (camY / ts).floor());
    final x1 = math.min(map.width - 1, x0 + vw ~/ ts + 1);
    final y1 = math.min(map.height - 1, y0 + vh ~/ ts + 1);
    String? at(int x, int y) => map.contains(x, y) ? map.tileAt(x, y) : null;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        tiles.draw(c, map.tileAt(x, y), x * ts, y * ts, map.theme, x, y,
            t: t,
            gateOpen: s.gateOpen,
            lobby: map.lobby,
            at: at,
            voidBackdrop: abyss,
            density: particleDensity);
      }
    }
    // Arcos de las entradas de zona (sobresalen de su tile).
    for (final e in map.entrances) {
      if (e.tx < x0 - 2 || e.tx > x1 + 2 || e.ty < y0 || e.ty > y1 + 3) {
        continue;
      }
      tiles.entrance(c, e.tx, e.ty, e.zone,
          open: open(e.zone), t: t, density: particleDensity);
    }
    final merchant = map.merchant;
    if (merchant != null) {
      actors.text(
          c, 'TIENDA', merchant.x, merchant.y - 34, const Color(0xFFFFD166), 6);
    }
    if (map.lobby) {
      actors.text(c, 'MOSTRADOR DE MISIONES', 13 * ts, ts + 10,
          const Color(0xFF48DBFB), 7);
      actors.text(c, 'ARMERÍA', 21.5 * ts, ts + 10, const Color(0xFFFF9F43), 7);
      // Portal del Eco (docs/specs/ecos_atlas.md § 1).
      actors.text(c, 'PORTAL', 4.5 * ts, ts + 10,
          const Color(0xFF5AE6D2), 7);
    }

    // Loot en el piso (debajo de los actores; docs/specs/loot.md § 4).
    final onMap = s.mode == SessionMode.field ||
        s.mode == SessionMode.levelUp ||
        s.mode == SessionMode.lobby;
    final floor = onMap && s.players[view.localId] != null
        ? _visible(s)
        : const <LootOnFloor>[];
    _verdicts.removeWhere((id, _) => !s.ground.any((g) => g.id == id));
    for (final l in floor) {
      _seen.putIfAbsent(l.ground.id, () => t);
      loot.drawItem(c, l, t);
    }

    // Entidades ordenadas por y (desempate: orden de llegada).
    final ents = <(double, int, void Function())>[];
    void add(double y, void Function() draw) =>
        ents.add((y, ents.length, draw));

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
      final fall = _falls[p.id];
      final fq = fallProgress(p.id);
      if (fall != null && fq == null) _falls.remove(p.id);
      void hero(double x, double y) => actors.hero(c,
          classId: p.profile.classId,
          weaponType: weapon?.type,
          x: x,
          y: y,
          t: t,
          dir: mine ? controller.local.dir : p.dir,
          moving: mine ? controller.local.moving : p.moving,
          dead: p.hp <= 0,
          blink: grace && p.hp > 0);
      if (fall != null && fq != null) {
        if (fq < 0.5) {
          // Se achica y se desvanece donde cayó.
          add(fall.y, () => _drawFalling(c, fall, fq * 2, hero));
        } else {
          // Aparece en el punto de llegada.
          add(py, () => _drawArriving(c, px, py, (fq - 0.5) * 2, hero));
        }
        continue;
      }
      _lastDrawn[p.id] = (px, py);
      add(py, () {
        hero(px, py);
        actors.text(c, p.name, px, py - 22,
            mine ? const Color(0xFFFFD166) : const Color(0xFFFFFFFF), 6);
      });
    }

    final mission = s.mission;
    final showField =
        s.mode == SessionMode.field || s.mode == SessionMode.levelUp;
    if (mission != null && showField) {
      for (final it in mission.items) {
        if (it.floor != mission.floor) continue;
        final visible = it.kind == MissionItemKind.seal || !it.done;
        if (visible) add(it.y, () => actors.item(c, it, t));
      }
      for (final e in mission.enemies) {
        if (!e.alive || e.floor != mission.floor) continue;
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
            actors.text(c, '★ÉLITE', d.x, d.y - 34, const Color(0xFFFFD166), 6);
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

    // Carteles de las entradas de zona (mapa del mundo).
    for (final e in map.entrances) {
      final z = zones[e.zone];
      if (z == null) continue;
      final cx = e.center.x, cy = e.center.y;
      final col = z.open ? zoneColor(e.zone) : const Color(0xFF9AA0AC);
      if (!z.open) {
        actors.text(c, z.playable ? 'BLOQUEADA' : 'PRÓXIMAMENTE', cx, cy - 56,
            const Color(0xFFFF6B81), 6);
      }
      actors.text(c, z.zone.name, cx, cy - 47, col, 7);
      actors.text(c, z.zone.levelText, cx, cy - 38, col, 6);
    }

    // Haces de los Legendarios y etiquetas del loot, encima de todo.
    for (final l in floor) {
      if (!l.legendary || l.hidden) continue;
      final age = t - (_seen[l.ground.id] ?? t);
      loot.drawBeam(c, l.ground.x, l.ground.y, t,
          boost: (1 - age / beamBurstMs).clamp(0.0, 1.0),
          density: particleDensity);
    }
    _beams.removeWhere((b) => t - b.t0 > inventoryBeamMs);
    for (final b in _beams) {
      final q = (t - b.t0) / inventoryBeamMs;
      loot.drawBeam(c, controller.local.x, controller.local.y, t,
          boost: (1 - q * 2).clamp(0.0, 1.0), density: particleDensity);
    }
    for (final p in loot.placeLabels(floor,
        view: Rect.fromLTWH(camX, camY, vw.toDouble(), vh.toDouble()))) {
      loot.drawLabel(c, p);
    }
    c.restore();
    if (showingFallToast) {
      final q = (t - _myFallT0!) / fallToastMs;
      final a = q < 0.8 ? 1.0 : (1 - q) / 0.2;
      actors.text(c, fallToastText, vw / 2, 56,
          const Color(0xFFA29BFE).withValues(alpha: a.clamp(0.0, 1.0)), 8);
    }
    _drawFade(c, view);
  }

  /// Primera mitad de la caída: el héroe se achica (a 0.2) y se desvanece
  /// con un remolino de motas.
  void _drawFalling(
      Canvas c, _Fall f, double q, void Function(double, double) hero) {
    final s = 1 - 0.8 * q;
    final cx = f.x, cy = f.y - 8;
    c.saveLayer(null,
        Paint()..color = Color.fromRGBO(0, 0, 0, (1 - q).clamp(0.0, 1.0)));
    c.translate(cx, cy);
    c.scale(s, s);
    c.translate(-cx, -cy);
    hero(f.x, f.y);
    c.restore();
    final mote = Paint()
      ..isAntiAlias = false
      ..color = const Color(0xFFA29BFE).withValues(alpha: 1 - q);
    final n = scaledCount(6, particleDensity);
    for (var i = 0; i < n; i++) {
      final a = t / 120 + i * math.pi * 2 / n;
      final r = 12 * (1 - q) + 2;
      c.drawRect(
          Rect.fromLTWH((cx + math.cos(a) * r).roundToDouble(),
              (cy + 4 + math.sin(a) * r * 0.5).roundToDouble(), 1, 1),
          mote);
    }
  }

  /// Segunda mitad: anillo dorado que se cierra y el héroe que aparece.
  void _drawArriving(Canvas c, double x, double y, double q,
      void Function(double, double) hero) {
    final ring = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFD166).withValues(alpha: 1 - q * 0.6);
    final r = 14 - 10 * q;
    c.drawOval(
        Rect.fromCenter(
            center: Offset(x.roundToDouble(), y.roundToDouble() + 2),
            width: r * 2,
            height: r),
        ring);
    c.saveLayer(
        null, Paint()..color = Color.fromRGBO(0, 0, 0, q.clamp(0.0, 1.0)));
    hero(x, y);
    c.restore();
  }

  /// Fundido a negro al cambiar de piso con el cartel `<zona> · Piso N/F`.
  void _drawFade(Canvas c, SessionView view) {
    final t0 = _fadeT0;
    if (t0 == null) return;
    final q = (t - t0) / fadeMs;
    if (q >= 1) return;
    final a = q < 0.3 ? 1.0 : 1 - (q - 0.3) / 0.7;
    c.drawRect(Rect.fromLTWH(0, 0, vw.toDouble(), vh.toDouble()),
        Paint()..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0)));
    final m = view.session.mission;
    if (m == null) return;
    final name = (m.missionId == EcoRules.missionId
            ? controller.engine.missionOf(view.session, m.missionId)?.name
            : null) ??
        controller.engine.catalog.zone(m.zone)?.name ??
        controller.engine.catalog.mission(m.missionId)?.name ??
        '';
    actors.text(c, floorLabelText(name, m.floor, m.floors), vw / 2, vh / 2,
        const Color(0xFFFFD166), 8);
  }

  /// Haces de Legendarios recién caídos al inventario en curso (tests).
  int get activeBeams => _beams.length;
}
