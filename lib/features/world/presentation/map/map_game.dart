import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/pixel_label.dart';
import '../../../../core/perf/perf_log.dart';
import '../../../../core/procedural/weapon_look.dart';
import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/models/build_wants.dart';
import '../../../../game_engine/data/town_layout.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/models/item.dart';
import '../../../../game_engine/models/loot.dart';
import '../../../../game_engine/models/loot_filter.dart';
import '../../../../game_engine/models/session_event.dart';
import '../../../../game_engine/data/exploration_catalog.dart';
import '../../../../game_engine/rules/eco_rules.dart';
import '../../../../game_engine/rules/trial_rules.dart';
import '../../../../game_engine/rules/zone_rules.dart';
import '../../../../netcode/contracts/net_traffic.dart';
import '../../../ascension/domain/ascension_text.dart';
import '../../../combat/presentation/game_sprites.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import '../../../missions/domain/mission_text.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'actor_painter.dart';
import 'loot_painter.dart';
import 'map_labels.dart';
import 'map_themes.dart';
import 'tile_cache.dart';
import 'tile_painter.dart';
import 'void_painter.dart';
import 'fishing_layer.dart';
import 'farm_layer.dart';
import '../../../../game_engine/data/farming_catalog.dart'
    show kCrops, CropQuality;
import '../../../inventory/presentation/item_widgets.dart' show RarityColors;
import '../panels/fishing_widgets.dart' show fishRarityColor;
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/rules/fishing_minigame.dart';

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
    // Para la línea de rendimiento de ecos.log (FPS Y PING prendido).
    PerfLog.probes['mapa'] = _perfProbe;
  }

  String _perfProbe() =>
      '${tileLayer.direct ? 'tiles directo' : 'tiles en caché'}'
      ' (${tileLayer.cachedChunks} bloques, ${tileLayer.built} grabados)'
      ' · etiquetas ${labelPen.cached} medidas'
      ' (${labelPen.misses} de ${labelPen.hits + labelPen.misses})'
      // Host: cuánto pesa el último `state` (netcode.md § "Perfiles solo
      // cuando cambian").
      '${switch (controller.net) {
        final NetTraffic n when n.clientCount > 0 =>
          ' · red: state ${(n.lastStateBytes / 1024).toStringAsFixed(1)} KB'
              ' a ${n.clientCount} clientes'
              ' (${n.skippedStates} salteados por conexión lenta)',
        _ => '',
      }}';

  final SessionController controller;
  final GameSprites sprites;
  final MoveInputReader _input;
  final ActorPainter actors;
  final tiles = TilePainter();
  late final tileLayer = TileLayerCache(tiles);
  final voidBg = VoidPainter();

  /// Pesca en el mapa (fishing.md § 4).
  final fishing = MapFishingLayer();

  /// Huerta del pueblo (farming.md § 2.3).
  final farm = MapFarmLayer();
  final _lastBobber = <String, (double, double)>{};

  /// Lo último dibujado: en [update] se graba de antemano un bloque de la
  /// capa estática que falte cerca (uno por cuadro).
  GameMap? _prefetchMap;
  Rect? _prefetchView;
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
  final _verdicts = <int, (String?, int, FilterVerdict, BuildWants?)>{};

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

  /// El tile del mundo bajo el punto [p] de la pantalla (para el tooltip
  /// de las parcelas; farming.md § 2.4).
  (int, int)? tileAtScreen(Offset p) {
    final r = viewRect(Size(size.x, size.y));
    if (!r.contains(p) || r.width <= 0) return null;
    final k = vw / r.width;
    final wx = (p.dx - r.left) * k + camX.roundToDouble();
    final wy = (p.dy - r.top) * k + camY.roundToDouble();
    return ((wx / ts).floor(), (wy / ts).floor());
  }

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
    final wants = controller.localWants;
    if (cached != null &&
        cached.$1 == p.lootFilter &&
        cached.$2 == p.level &&
        identical(cached.$4, wants)) {
      return cached.$3;
    }
    final v = controller.engine.lootVerdict(p, g.drop, wants: wants);
    _verdicts[g.id] = (p.lootFilter, p.level, v, wants);
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

  /// Cartel de misión opcional cumplida (worldgen.md § 11.8).
  static const questToastMs = 2800.0;
  double? _questT0;
  String _questText = '';

  /// DURACIÓN DE LOS AVISOS (accessibility.md § 9.5): multiplica
  /// [questToastMs]; infinito = hasta [dismissNotices] (lo pone
  /// `WorldScreen`).
  double noticeFactor = 1;

  /// Duración efectiva del cartel de misión opcional (ms).
  double get questToastShownMs => questToastMs * noticeFactor;

  /// Cierra el cartel de misión opcional (Retroceso con HASTA CERRAR).
  void dismissNotices() => _questT0 = null;

  /// FONDO DEL TEXTO EN EL MAPA (accessibility.md § 9.6; lo pone
  /// `WorldScreen`).
  MapLabelBackdrop labelBackdrop = MapLabelBackdrop.none;

  /// Se ve el cartel de misión opcional cumplida (tests).
  bool get showingQuestToast =>
      _questT0 != null && t - _questT0! < questToastShownMs;

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
    if (e case WaterLootEvent(:final playerId, :final label, :final rarity)) {
      final p = controller.session?.players[playerId];
      final from = _lastBobber[playerId] ??
          (p == null ? null : (p.x + p.dir * 24.0, p.y));
      final r = Rarity.values[rarity.clamp(0, Rarity.values.length - 1)];
      if (from != null) {
        fishing.addPop(
            playerId, from.$1, from.$2, label, RarityColors.of(r), t);
      }
    }
    if (e
        case FishCaughtEvent(
          :final playerId,
          :final species,
          :final sizeCm,
          :final auto
        ) when !auto) {
      final p = controller.session?.players[playerId];
      final from = _lastBobber[playerId] ??
          (p == null ? null : (p.x + p.dir * 24.0, p.y));
      final def = kFish[species];
      if (from != null) {
        fishing.addPop(
            playerId,
            from.$1,
            from.$2,
            '${def?.name ?? species} $sizeCm cm',
            fishRarityColor(def?.rarity ?? FishRarity.comun),
            t);
      }
    }
    if (e
        case CropHarvestedEvent(
          :final playerId,
          :final crop,
          :final quality,
          :final count,
          :final tx,
          :final ty,
          :final helper
        )) {
      final def = kCrops[crop];
      final q =
          CropQuality.values[quality.clamp(0, CropQuality.values.length - 1)];
      final rar = def?.rarity ?? FishRarity.comun;
      farm.addPop(
          helper ? '' : playerId,
          tx,
          ty,
          '${count > 1 ? '$count × ' : ''}${def?.name ?? crop} (${q.label})',
          fishRarityColor(FishRarity.values[q.index.clamp(0, 3)]),
          FarmPalette.fruit[rar.index.clamp(0, 3)],
          t);
    }
    if (e
        case FarmLootEvent(
          :final playerId,
          :final label,
          :final rarity,
          :final tx,
          :final ty
        )) {
      final r = Rarity.values[rarity.clamp(0, Rarity.values.length - 1)];
      farm.addPop(playerId, tx, ty, label, RarityColors.of(r),
          RarityColors.of(r), t + 250);
    }
    if (e case QuestDoneEvent(:final kind)) {
      _questT0 = t;
      _questText = questText(kind);
    }
    if (e case LootDropEvent(:final playerId, :final drop, :final groundId)
        when playerId == controller.localId &&
            groundId == null &&
            drop.item?.rarity == Rarity.legendario) {
      _beams.add(_Beam(t));
    }
  }

  @override
  void onRemove() {
    tileLayer.dispose();
    if (PerfLog.probes['mapa'] == _perfProbe) PerfLog.probes.remove('mapa');
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
    return controller.engine.lootVerdict(p, d, wants: controller.localWants);
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
    if (view != null && view.map.lobby) {
      final f = controller.mapFishing;
      fishing.update(view.map, math.min(0.05, dt),
          f != null && f.phase == FishPhase.waiting ? f.bobber : null);
    }
    final pm = _prefetchMap, pv = _prefetchView;
    if (pm != null && pv != null) tileLayer.prefetch(pm, pv);
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

  /// Arnés de rendimiento (tests): recibe los µs de cada [render].
  @visibleForTesting
  static void Function(int micros)? debugRenderTiming;

  @override
  void render(Canvas canvas) {
    final timing = debugRenderTiming;
    if (timing == null) return _render(canvas);
    final sw = Stopwatch()..start();
    _render(canvas);
    timing(sw.elapsedMicroseconds);
  }

  void _render(Canvas canvas) {
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
    // Nombres, carteles y loot: en px de pantalla, nítidos y finos (el
    // estilo de los nombres de la batalla; ui_style.md § "Etiquetas en
    // el mundo").
    canvas.save();
    canvas.clipRect(dst);
    paintMapLabels(canvas, labels, dst, vw.toDouble(), labelPen,
        backdrop: labelBackdrop);
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / vw, dst.height / vh);
    fishing.drawOverlay(canvas);
    canvas.restore();
  }

  /// `false`: las etiquetas se dibujan como antes de v0.5.1, en el lienzo
  /// virtual que después se agranda (solo para comparar en capturas).
  @visibleForTesting
  bool screenLabels = true;

  /// Etiquetas del último [drawWorld] (se dibujan en [render]).
  final labels = <MapLabel>[];
  final labelPen = PixelLabelPen();

  /// Todas las capas del mapa en el lienzo virtual (orden del spec).
  void drawWorld(Canvas c, SessionView view) {
    labels.clear();
    actors.labelSink = screenLabels ? labels : null;
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
    // Pulso del Tiempo: con el reloj de la sala (el mismo que usa el host).
    final pulse = TrialRules.pulseCharge(s.time);
    // Capa estática por bloques + tiles animados encima (exploration.md §
    // "Rendimiento").
    final worldView = Rect.fromLTWH(camX.roundToDouble(), camY.roundToDouble(),
        vw.toDouble(), vh.toDouble());
    tileLayer.draw(c, map, worldView,
        theme: map.theme,
        backdrop: abyss,
        t: t,
        gateOpen: s.gateOpen,
        density: particleDensity,
        pulse: pulse);
    _prefetchMap = map;
    _prefetchView = worldView;
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
      // Lugares del pueblo (town_loop.md § 2.1): nombre sobre cada uno.
      for (final l in TownLayout.landmarks) {
        actors.text(c, l.name, l.center.x, l.y * ts - 8, TownPalette.label, 6);
      }
      farm.drawZoneLabels(c, s.town,
          (txt, x, y, col, size) => actors.text(c, txt, x, y, col, size));
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
    if (map.lobby) {
      fishing.drawShadows(c);
      farm.drawPlots(c, s.town, worldView, t);
      farm.drawHelper(c, s.town, t);
      // Objetivo del próximo E / clic (solo el jugador local).
      if (controller.farmTarget case final ft?) {
        farm.drawTarget(c, ft.tiles, ft.ok);
      }
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
      // Herramienta de vida en la mano: no se ve el arma. Los demás
      // jugadores: caña con la línea afuera o cerca de la huerta (se deduce
      // de la posición; sin protocolo nuevo).
      final inTown = s.mode == SessionMode.lobby;
      final toolOut = inTown &&
          (mine
              ? controller.activeTool != null
              : p.fishLine != null || controller.nearSoilAt(px, py));
      void hero(double x, double y) => actors.hero(c,
          classId: p.profile.classId,
          weaponType: weapon?.type,
          look: p.profile.equippedItem == null
              ? null
              : WeaponLook.of(p.profile.equippedItem!),
          x: x,
          y: y,
          t: t,
          dir: mine ? controller.local.dir : p.dir,
          moving: mine ? controller.local.moving : p.moving,
          dead: p.hp <= 0,
          blink: grace && p.hp > 0,
          ascensionId: p.profile.ascension.id,
          showWeapon: !toolOut);
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
      final line = s.mode != SessionMode.lobby
          ? null
          : mine
              ? controller.mapFishing?.line
              : p.fishLine;
      if (line == null && mine) fishing.barRect = null;
      add(py, () {
        hero(px, py);
        // Cerca de la huerta sale la azada equipada (farming.md § 4).
        if (line == null && toolOut) {
          final face = mine ? controller.local.fx : p.dir;
          final tool = mine ? controller.activeTool : ActiveTool.hoe;
          if (tool == ActiveTool.rod) {
            fishing.drawIdleRod(c, px, py, face);
          } else {
            switch (mine ? controller.farmHand : FarmHand.hoe) {
              case FarmHand.hoe:
                farm.drawHoe(c, px, py, face);
              case FarmHand.can:
                farm.drawCan(c, px, py, face);
              case FarmHand.seed:
                final d = kCrops[p.profile.life.farm.activeSeed];
                farm.drawSeedBag(c, px, py, face,
                    FarmPalette.fruit[d?.rarity.index ?? 0]);
            }
          }
        }
        if (line != null) {
          final f = mine ? controller.mapFishing : null;
          final b = f?.bobber ?? (line.hasBobber ? (line.bx, line.by) : null);
          if (b != null) _lastBobber[p.id] = b;
          fishing.drawAngler(c,
              px: px,
              py: py,
              dir: mine ? controller.local.dir : p.dir,
              line: line,
              t: t,
              mine: f,
              text: (s, x, y, col, size) => actors.text(c, s, x, y, col, size));
        }
        actors.text(c, profileTitle(p.profile), px, py - 22,
            mine ? const Color(0xFFFFD166) : const Color(0xFFFFFFFF), 6);
      });
    }

    final mission = s.mission;
    final showField =
        s.mode == SessionMode.field || s.mode == SessionMode.levelUp;
    if (mission != null && showField) {
      for (final it in mission.items) {
        if (it.floor != mission.floor) continue;
        // El cofre de una sala secreta no se ve hasta abrirla.
        final hidden =
            it.secret != null && !mission.poiUsed.contains(it.secret);
        final visible =
            !hidden && (it.kind == MissionItemKind.seal || !it.done);
        final g = it.guard;
        final locked = g != null && (mission.enemy(g)?.alive ?? false);
        if (visible) add(it.y, () => actors.item(c, it, t, locked: locked));
      }
      // Reliquias de las misiones opcionales (worldgen.md § 11.8).
      for (final p in currentFloor(view)?.pois ?? const <MapPoi>[]) {
        if (p.kind != PoiKind.relic || mission.poiUsed.contains(p.id)) continue;
        final cx = p.center.x, cy = p.center.y;
        add(cy, () => actors.relic(c, cx, cy, t));
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
    if (map.lobby) {
      fishing.drawPops(c, t, (id) => _lastDrawn[id],
          (s, x, y, col, size) => actors.text(c, s, x, y, col, size));
      farm.drawPops(c, t, (id) => _lastDrawn[id],
          (s, x, y, col, size) => actors.text(c, s, x, y, col, size));
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
      // Nítidas en px de pantalla (como el resto de las etiquetas).
      if (!screenLabels) {
        loot.drawLabel(c, p);
        continue;
      }
      final col = labelColors(p.loot);
      labels.add(MapBoxLabel(c.getTransform(), p.rect, loot.labelText(p.loot),
          textColor: col.text,
          background: col.background,
          border: col.border,
          worldSize: labelPx(p.loot.style.size)));
    }
    c.restore();
    if (showingFallToast) {
      final q = (t - _myFallT0!) / fallToastMs;
      final a = q < 0.8 ? 1.0 : (1 - q) / 0.2;
      actors.text(c, fallToastText, vw / 2, 56,
          const Color(0xFFA29BFE).withValues(alpha: a.clamp(0.0, 1.0)), 8);
    }
    if (showingQuestToast) {
      final q =
          noticeFactor.isInfinite ? 0.2 : (t - _questT0!) / questToastShownMs;
      final a = (q < 0.85 ? 1.0 : (1 - q) / 0.15).clamp(0.0, 1.0);
      final y = 44.0 + (q < 0.1 ? (0.1 - q) * 80 : 0.0);
      c.drawRect(Rect.fromLTWH(vw / 2 - 110, y - 12, 220, 28),
          Paint()..color = Color.fromRGBO(10, 8, 24, 0.75 * a));
      actors.text(c, '¡Misión opcional cumplida!', vw / 2, y,
          const Color(0xFFFFD166).withValues(alpha: a), 8);
      actors.text(c, _questText, vw / 2, y + 11,
          const Color(0xFFFFFFFF).withValues(alpha: a), 6);
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
    final name = (m.missionId == EcoRules.missionId ||
                m.missionId == TrialRules.missionId
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
