import '../../../inventory/domain/item_names.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/models/custom_npc.dart';
import '../../../../game_engine/data/light_catalog.dart';
import '../../../../game_engine/rules/light_rules.dart';
import '../../../../game_engine/rules/mining_rules.dart';
import 'light_layer.dart';
import 'mine_layer.dart';
import '../../../../game_engine/rules/town_plan.dart';
import '../../../../game_engine/data/mine_catalog.dart' show MineTile;
import '../../../../app/theme/pixel_label.dart';
import '../../../../core/perf/perf_log.dart';
import '../../../../core/procedural/weapon_look.dart';
import '../../../../core/settings/graphics.dart';
import '../../../../game_engine/models/build_wants.dart';
import '../../../../game_engine/data/town_layout.dart';
import '../../../../game_engine/data/biomes_catalog.dart'
    show BiomeNpcDef, biomeLayout, kPueblo;
import '../../../../game_engine/rules/light_shaft_rules.dart';
import '../../../../game_engine/rules/waystone_rules.dart';
import 'ambient_life_layer.dart';
import 'region_light_layer.dart';
import '../../../../game_engine/rules/quest_track_rules.dart';
import '../../../../game_engine/models/game_map.dart';
import '../../../../game_engine/models/town_build.dart' show kTownStrip;
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/data/world_events_catalog.dart';
import '../../../../game_engine/rules/world_event_rules.dart';
import '../../../../game_engine/models/item.dart';
import '../../../../game_engine/models/loot.dart';
import '../../../../game_engine/models/loot_filter.dart';
import '../../../../game_engine/models/session_event.dart';
import '../../../../game_engine/data/exploration_catalog.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../game_engine/rules/dungeon_rules.dart';
import '../../../../game_engine/rules/eco_rules.dart';
import '../../../../game_engine/rules/trial_rules.dart';
import '../../../../game_engine/rules/sky_rules.dart';
import '../../../../game_engine/rules/weather_rules.dart';
import '../../../../game_engine/rules/zone_rules.dart';
import '../../../../netcode/contracts/net_traffic.dart';
import '../../../combat/presentation/game_sprites.dart';
import '../../../combat/presentation/sprite_catalog.dart';
import '../../../missions/domain/mission_text.dart';
import '../session_controller.dart';
import '../session_view.dart';
import 'actor_painter.dart';
import 'loot_painter.dart';
import 'map_labels.dart';
import 'map_themes.dart';
import 'ground_layer.dart';
import 'sky_layer.dart';
import 'town_edit_layer.dart';
import 'tile_cache.dart';
import 'vegetation_sway_layer.dart';
import 'tile_painter.dart';
import 'void_painter.dart';
import 'fishing_layer.dart';
import 'farm_layer.dart';
import 'life_level_layer.dart';
import '../../../../core/audio/sfx_catalog.dart';
import '../../../../game_engine/rules/life_tree_rules.dart';
import '../../../../game_engine/rules/biome_fisher_rules.dart';
import '../../../../game_engine/data/npc_camp_catalog.dart';
import '../../../../game_engine/rules/npc_camp_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../../../../app/design/design.dart' show DsColors;
import '../../../../game_engine/data/farming_catalog.dart'
    show kCrops, kFertilizers, CropQuality;
import '../../../inventory/presentation/item_widgets.dart' show RarityColors;
import '../panels/fishing_widgets.dart' show fishRarityColor;
import '../panels/town_edit_overlay.dart' show TownEditOverlay;
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

/// Logical sprite id of the dungeon exit portal (`items.vida_salida_mazmorra`
/// in sprite_manifest.yaml; free_movement.md § 2.4).
const kDungeonExitSprite = 'salida_mazmorra';

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
    // Procedural trees and bushes (procedural_vegetation.md § 4).
    tiles.vegetation = sprites.vegetation;
    sway.vegetation = sprites.vegetation;
    loot = LootPainter(
      nameOf: (d) => lootName(controller, d),
      weaponTypeOf: (id) => controller.engine.catalog.weapons[id]?.type,
    );
    _events = controller.events.listen(_onEvent);
    controller.onMineSwing = (x, y, bounced) {
      final p = controller.session?.players[controller.localId];
      mine.onSwing(x, y, t, fromX: p?.x, fromY: p?.y, bounced: bounced);
    };
    // Para la línea de rendimiento de ecos.log (FPS Y PING prendido).
    PerfLog.probes['mapa'] = _perfProbe;
  }

  String _perfProbe() =>
      '${tileLayer.direct ? 'tiles directo' : 'tiles en caché'}'
      ' (${tileLayer.cachedChunks} bloques, ${tileLayer.built} grabados)'
      ' · luz ${light.rebuilds} recálculos'
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

  /// Wind sway of the vegetation (biome_regions.md § 7.2.2).
  final sway = VegetationSwayLayer();
  final voidBg = VoidPainter();

  /// Pesca en el mapa (fishing.md § 4).
  final fishing = MapFishingLayer();

  /// Huerta del pueblo (farming.md § 2.3).
  final farm = MapFarmLayer();

  /// Ground marks of the seasons and the weather.
  final ground = MapGroundLayer();
  /// Mines: cracks, debris, bombs, carts (mining_smithing.md § 1.9).
  final mine = MineLayer();

  /// Noche, lluvia y rayos (day_night_weather.md § 4).
  final sky = MapSkyLayer();

  /// Mapa de luz (lighting.md § 4).
  final light = MapLightLayer();

  /// Cloud shadows, cave shade and light shafts (biome_regions.md § 7).
  final regionLight = RegionLightLayer();

  /// Ambient critters of a biome region (biome_regions.md § 6).
  final life = AmbientLifeLayer();

  /// Ajuste OSCURIDAD (1 = normal, 0.45 = suave, 0 = apagada).
  double darknessKeep = 1;

  /// Destellos (0–1, ajustes de accesibilidad) y «reducir movimiento».
  double flashFactor = 1;
  bool reduceMotion = false;

  /// Carteles de subida de nivel de oficio (farming.md § 2.6).
  final lifeLevels = MapLifeLevelLayer();
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

  /// Brillo mínimo para ver un enemigo en una mazmorra oscura.
  static const darkSeen = 0.12;

  /// Duración del estallido del haz al caer (ms).
  static const beamBurstMs = 1500.0;

  /// Duración del haz de un Legendario que fue al inventario (ms).
  static const inventoryBeamMs = 2600.0;

  /// Resolución virtual (`VW`, `VH`).
  static const vw = 480;
  static const vh = 288;
  static const ts = TilePainter.ts;

  /// Margen (px) para juntar faros fuera de cuadro: su luz y su efecto
  /// sobre las luciérnagas llegan hasta su radio (lighting.md § 3.4).
  static const _lampReach = 12 * ts;

  /// Reloj de animación en ms (`performance.now()` del prototipo).
  double t = 0;

  /// Escalado del mundo (ajuste ESCALADO; lo pone `WorldScreen`).
  ScaleMode scaleMode = ScaleMode.fit;

  /// Multiplicador de las partículas del mapa (ajuste PARTÍCULAS).
  double particleDensity = 1;

  /// Dónde se dibuja el mundo virtual dentro de [screen].
  Rect viewRect(Size screen) =>
      mapViewRect(screen, Size(vw.toDouble(), vh.toDouble()), scaleMode);

  /// Un rectángulo del mundo (px) en px de pantalla (con cámara y zoom).
  Rect worldToScreen(Rect w) {
    final r = viewRect(Size(size.x, size.y));
    final k = r.width / vw / zoom;
    Offset p(Offset o) => Offset(r.left + (o.dx - camX.roundToDouble()) * k,
        r.top + (o.dy - camY.roundToDouble()) * k);
    return Rect.fromPoints(p(w.topLeft), p(w.bottomRight));
  }

  /// Lo que ocupa el mapa en la pantalla.
  Rect get screenView => viewRect(Size(size.x, size.y));

  /// El tile del mundo bajo el punto [p] de la pantalla (para el tooltip
  /// de las parcelas; farming.md § 2.4).
  (int, int)? tileAtScreen(Offset p) {
    final r = viewRect(Size(size.x, size.y));
    if (!r.contains(p) || r.width <= 0) return null;
    final k = vw / r.width * zoom;
    final wx = (p.dx - r.left) * k + camX.roundToDouble();
    final wy = (p.dy - r.top) * k + camY.roundToDouble();
    return ((wx / ts).floor(), (wy / ts).floor());
  }

  /// Cámara (`cam`), esquina superior izquierda en px del mundo.
  double camX = 0, camY = 0;

  /// Zoom de la edición del pueblo (1 = normal; más = se ve más mapa).
  double editZoom = 1;
  static const editZooms = [1.0, 1.5, 2.0];

  /// El zoom en uso (solo en la edición del pueblo).
  double get zoom => controller.editingTown ? editZoom : 1;

  /// Rueda del mouse en la edición: [dir] > 0 aleja.
  void zoomBy(int dir) {
    final i = editZooms.indexOf(editZoom);
    final n = (i + dir).clamp(0, editZooms.length - 1);
    final cx = camX + vw * editZoom / 2, cy = camY + vh * editZoom / 2;
    editZoom = editZooms[n];
    camX = cx - vw * editZoom / 2;
    camY = cy - vh * editZoom / 2;
  }

  /// Arrastre con el mouse en la edición: [d] en px de pantalla.
  void panBy(Offset d) {
    final r = viewRect(Size(size.x, size.y));
    if (r.width <= 0) return;
    final k = vw / r.width * zoom;
    camX -= d.dx * k;
    camY -= d.dy * k;
  }

  /// Cámara libre de la edición (town_editor.md § 1.1): WASD / flechas,
  /// hasta las franjas fantasma de cada lado.
  void _updateEditCamera(SessionView view, double dt, double ix, double iy) {
    final e = controller.townEdit!;
    if (e.shift case (final dx, final dy)?) {
      camX += dx;
      camY += dy;
      e.shift = null;
    }
    final mw0 = view.map.width * ts, mh0 = view.map.height * ts;
    if (e.center) {
      // Elegir dónde contratar: el pueblo entero (si entra) y centrado.
      e.center = false;
      editZoom = editZooms.firstWhere((z) => mw0 <= vw * z && mh0 <= vh * z,
          orElse: () => editZooms.last);
      camX = (mw0 - vw * editZoom) / 2;
      camY = (mh0 - vh * editZoom) / 2;
      return;
    }
    camX += ix * 260 * zoom * dt;
    camY += iy * 260 * zoom * dt;
    const m = (kTownStrip + 1) * ts;
    final vwz = vw * zoom, vhz = vh * zoom;
    final mw = view.map.width * ts, mh = view.map.height * ts;
    double clamp(double v, double lo, double hi) =>
        hi < lo ? (lo + hi) / 2 : v.clamp(lo, hi);
    // La columna de la derecha (paleta, menú) tapa parte del mapa: se
    // descuenta para poder ver la franja este (town_editor.md § 1.2).
    final r = viewRect(Size(size.x, size.y));
    final pad = r.width > 0 && TownEditOverlay.sideOpen(controller)
        ? (TownEditOverlay.sideWidth(size.x) + 16) * vw / r.width * zoom
        : 0.0;
    camX = clamp(camX, -m, mw + m - (vwz - pad));
    camY = clamp(camY, -m, mh + m - vhz);
  }

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

  /// Compara los niveles de Pesca y Cultivo de cada jugador con los
  /// últimos vistos; una subida muestra el cartel y suena.
  void _watchLifeLevels() {
    final players = controller.session?.players;
    if (players == null) return;
    for (final p in players.values) {
      final pr = p.profile;
      final ups = lifeLevels.observe(
          p.id,
          pr.name,
          LifeTreeRules.level(pr, LifeSkillKind.pesca),
          LifeTreeRules.level(pr, LifeSkillKind.cultivo),
          t);
      if (ups.isNotEmpty) controller.fishSfx?.call(Sfx.levelUp);
    }
  }

  void _onEvent(SessionEvent e) {
    switch (e) {
      case MineDugEvent(:final playerId, :final tx, :final ty, :final code, :final label):
        final theme = controller.view?.map.theme ?? '';
        mine.onDug(tx, ty, code, label, playerId, theme, t);
        if (playerId == controller.localId) {
          controller.mineCracks.remove(controller.mineLevel?.idx(tx, ty));
        }
        if (MineTile.veins.contains(code)) {
          controller.fishSfx?.call(Sfx.flash);
        }
      case MineBombEvent(:final tx, :final ty, :final fuse):
        mine.onBomb(tx, ty, fuse, t);
      case MineBlastEvent(:final tx, :final ty, :final radius):
        mine.onBlast(tx, ty, radius, t);
        controller.fishSfx?.call(Sfx.hit);
      default:
    }
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
            '${def?.text ?? species} $sizeCm cm',
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
          '${count > 1 ? '$count × ' : ''}${def?.text ?? crop} (${q.label})',
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
    if (e case LightningEvent(:final tx, :final ty)) {
      sky.addBolt(tx, ty, t);
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
    _watchLifeLevels();
    _frameDt = dt;
    final (ix, iy) = _input();
    final editing = controller.editingTown;
    // Edición del pueblo: el personaje se queda quieto y WASD mueve la
    // cámara.
    controller.updateLocal(
        math.min(0.05, dt), editing ? 0 : ix, editing ? 0 : iy);
    if (!editing && _pickEdge.poll(_pickKey())) tryPickUp();
    final view = controller.view;
    if (view != null) {
      editing
          ? _updateEditCamera(view, math.min(0.05, dt), ix, iy)
          : _updateCamera(view, dt);
    }
    if (view != null && view.map.lobby) {
      final f = controller.mapFishing;
      fishing.update(view.map, math.min(0.05, dt),
          f != null && f.phase == FishPhase.waiting ? f.bobber : null);
    }
    final pm = _prefetchMap, pv = _prefetchView;
    if (pm != null && pv != null) tileLayer.prefetch(pm, pv);
  }

  /// El piso actual de la misión dentro del atlas (o `null`).
  /// Dónde dibujar el portal de salida de la mazmorra (free_movement.md
  /// § 2.4): la llegada del piso 1, solo en el Mundo con movimiento libre,
  /// fuera del TUTORIAL y de la Travesía. `null` = no hay.
  static (double, double)? dungeonExitAt(SessionView view,
      {required bool freeMovement, required bool run}) {
    final s = view.session;
    final m = s.mission;
    if (!freeMovement || run || m == null || m.floor != 0) return null;
    if (s.tutorial != null || s.run != null) return null;
    final sp = currentFloor(view)?.spawn ?? view.map.spawn;
    return (sp.x, sp.y);
  }

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

  /// Perf harness (tests): treat any mission map as a dark dungeon.
  @visibleForTesting
  static bool debugForceDark = false;

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
    // In battle the opaque battle scene covers the whole map: drawing
    // the world (tiles, lighting, actors) behind it only costs frames.
    if (view.session.mode == SessionMode.battle) return;

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
        backdrop: labelBackdrop, zoom: zoom);
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

  /// Etiqueta con [priority] (no se pisa con las otras con prioridad).
  /// Marca del habitante [n] para el jugador local (roles.md § 8.4).
  void _drawWorldEvents(Canvas c, GameSession s, String place, double t) {
    for (final a in s.town.events.at(place)) {
      final d = kWorldEvents.def(a.def);
      if (d == null || !WorldEventRules.hasActor(d.category)) continue;
      final at = WorldEventRules.spot(s.town, a);
      if (at == null) continue;
      final (x, y) = at;
      if (d.category == WorldEventCategory.echoPortal) {
        final closed = s.town.events.clearedBy(a.uid, controller.localId);
        final pulse = 0.5 + 0.5 * math.sin(t / 260);
        final color = (closed ? DsColors.textSecondary : DsColors.danger)
            .withValues(alpha: closed ? 0.35 : 0.55 + 0.4 * pulse);
        c.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 18, height: 24),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color);
        c.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 10, height: 16),
            Paint()..color = color.withValues(alpha: 0.25));
        _rankedText(c, d.title.text.toUpperCase(), x, y - 18,
            TownPalette.label, 6, 899);
        continue;
      }
      // Un NPC de datos vinculado protagoniza la visita (npc_editor.md
      // § 6.4): se dibuja él, no el actor del evento.
      if (kCustomNpcs.values.any((n) =>
          n.spawn == CustomNpcSpawn.event && n.place == d.id)) {
        continue;
      }
      final im = sprites.lifeIcon(d.sprite, 'herramienta');
      final bottom = y + 8;
      if (im != null) {
        final w = im.width.toDouble(), h = im.height.toDouble();
        c.drawImageRect(im, Rect.fromLTWH(0, 0, w, h),
            Rect.fromLTWH(x - w / 2, bottom - h, w, h),
            SpriteCatalog.pixelPaint());
      }
      _rankedText(c, d.title.text.toUpperCase(), x, bottom - 20,
          TownPalette.label, 6, 899);
      // Same mark and place as residents (world_events.md § 3.6).
      drawNpcMark(
          (txt, mx, my, col, size) =>
              _rankedText(c, txt, mx, my, col, size, 901),
          WorldEventRules.mark(s.town.events, a, d, controller.localId),
          x,
          bottom - 23,
          t);
    }
  }

  NpcMark _npcMark(BiomeNpcDef n) {
    final v = controller.view;
    final p = v?.me?.profile;
    if (v == null || p == null) return NpcMark.none;
    return QuestTrackRules.mark(p, controller.town, n);
  }

  /// Distancia (en tiles) hasta la que se ven los carteles de lugares
  /// del pueblo y los exteriores (town_loop.md § 2.1, v0.37.3).
  static const placeLabelRange = 4.5;

  /// Franja (en tiles) en la que el cartel aparece / se apaga suave.
  static const placeLabelFade = 1.0;

  /// Opacidad del cartel de lugar en ([x], [y]) según lo cerca que esté
  /// el jugador local: 1 adentro de [placeLabelRange], 0 pasando la franja.
  double _placeAlpha(double x, double y) {
    final dx = (x - controller.local.x) / ts,
        dy = (y - controller.local.y) / ts;
    final d = math.sqrt(dx * dx + dy * dy);
    return (1 - (d - placeLabelRange) / placeLabelFade).clamp(0.0, 1.0);
  }

  /// Cartel de un lugar: solo cerca del jugador, con fundido.
  void _placeText(Canvas c, String s, double x, double y, Color color,
      double size, int priority) {
    final a = _placeAlpha(x, y);
    if (a <= 0) return;
    _rankedText(
        c, s, x, y, color.withValues(alpha: color.a * a), size, priority);
  }

  /// Etiqueta del mundo con prioridad. Todas van un paso más chicas que
  /// el tamaño pedido (v0.37.3), con piso en 5.
  void _rankedText(Canvas c, String s, double x, double y, Color color,
      double size, int priority) {
    size = size > 5 ? size - 1 : size;
    if (!screenLabels) return actors.text(c, s, x, y, color, size);
    labels.add(MapTextLabel(c.getTransform(), s, x, y, color, size,
        priority: priority));
  }

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
    final z = zoom;
    if (z != 1) c.scale(1 / z);
    c.translate(-camX.roundToDouble(), -camY.roundToDouble());
    // Bomb blast: a small screen shake (mining_smithing.md § 1.9).
    final shake = mine.shake(t);
    if (shake != Offset.zero) c.translate(shake.dx, shake.dy);

    // Estado de las zonas para el jugador local (entradas del mundo).
    final zones = map.entrances.isEmpty
        ? const <int, ZoneStatus>{}
        : {for (final z in controller.zones) z.zone.index: z};
    bool open(int zone) => zones[zone]?.open ?? false;

    // Tiles visibles.
    final x0 = math.max(0, (camX / ts).floor());
    final y0 = math.max(0, (camY / ts).floor());
    final x1 = math.min(map.width - 1, x0 + (vw * z) ~/ ts + 1);
    final y1 = math.min(map.height - 1, y0 + (vh * z) ~/ ts + 1);
    // Pulso del Tiempo: con el reloj de la sala (el mismo que usa el host).
    final pulse = TrialRules.pulseCharge(s.time);
    // Capa estática por bloques + tiles animados encima (exploration.md §
    // "Rendimiento").
    final worldView = Rect.fromLTWH(
        camX.roundToDouble(), camY.roundToDouble(), vw * z, vh * z);
    tileLayer.draw(c, map, worldView,
        theme: map.theme,
        backdrop: abyss,
        t: t,
        gateOpen: s.gateOpen,
        density: particleDensity,
        pulse: pulse);
    // Wind in the vegetation (biome_regions.md § 7.2.2).
    if (map.lobby && !controller.editingTown) {
      sway.draw(c, map, x0, y0, x1, y1, t / 1000,
          motion: !reduceMotion, themeId: map.theme);
    }
    // Season and weather marks on the ground (weather_seasons.md § 6.3).
    if (map.lobby && s.town.sky.started && !controller.editingTown) {
      ground.draw(
          c,
          map,
          worldView,
          MapGroundLayer.markFor(
              lobby: true,
              place: map.place,
              season: WeatherRules.season(s.town.sky.day),
              weather: SkyRules.nowIn(s.town.sky, map.place)));
    }
    // Region waystones the local player activated (biome_regions.md § 4).
    if (map.lobby && !controller.editingTown) {
      if (biomeLayout(map.place) case final lay?) {
        final who = s.players[view.localId]?.profile.name;
        for (var i = 0; i < lay.waystones.length && who != null; i++) {
          final w = lay.waystones[i];
          if (w.x < x0 - 1 || w.x > x1 + 1 || w.y < y0 - 1 || w.y > y1 + 2) {
            continue;
          }
          if (!WaystoneRules.isActive(s.town, who, lay, i)) continue;
          tiles.waystoneGlow(c, w.x * ts, w.y * ts, t);
        }
      }
    }
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
      _placeText(c, 'TIENDA', merchant.x, merchant.y - 34,
          const Color(0xFFFFD166), 6, 0);
    }
    if (map.lobby && map.place != null) {
      // Exterior de bioma (overworld_biomes.md § 3): sus carteles.
      var rank = 0;
      // Labels stay inside the view (a pond at the edge was clipped).
      double inView(double x) => x.clamp(
          worldView.left + 36, math.max(worldView.left + 36, worldView.right - 36));
      for (final (txt, x, y)
          in biomeLayout(map.place)?.labels ?? const <(String, int, int)>[]) {
        _placeText(c, txt, inView((x + 0.5) * ts), y * ts - 4,
            TownPalette.label, 6, rank++);
      }
      final lay = biomeLayout(map.place);
      for (final (x, y)
          in lay == null ? const <(int, int)>[] : MiningRules.entrances(lay)) {
        // Above the mouth, and hidden while someone stands at it (it
        // covered the player's name).
        final mx = (x + 0.5) * ts, my = y * ts;
        final busy = s.players.values.any((p) =>
            (p.x - mx).abs() < 20 && p.y > my && p.y - my < 40);
        if (busy) continue;
        _placeText(c, controller.strings.t('ui.world.mine.label'), mx,
            my - 8, TownPalette.label, 6, rank++);
      }
    } else if (map.lobby) {
      // Lugares del pueblo (town_loop.md § 2.1): nombre sobre cada uno.
      final (ox, oy) = map.townOrigin;
      // Con prioridad: no se pisan (ui_style.md § "Etiquetas en el
      // mundo"); primero los lugares, después los carteles.
      var rank = 0;
      for (final l in map.townMarks ?? TownLayout.landmarks) {
        _placeText(c, l.name, l.center.x + ox * ts, (l.y + oy) * ts - 8,
            TownPalette.label, 6, rank++);
      }
      farm.drawZoneLabels(
          c,
          s.town,
          (txt, x, y, col, size) =>
              _placeText(c, txt, x, y, col, size, rank++));
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
      if (map.place case final place?) {
        fishing.drawHiddenSpot(
            c, map, place, math.max(1, s.town.sky.day), t / 1000);
      }
      // La huerta y los ayudantes son del pueblo, no de los exteriores.
      if (map.place == null) {
        farm.drawPlots(c, s.town, worldView, t);
        farm.drawSigns(c, s.town);
        farm.drawHelpers(
            c,
            s.town,
            s.time,
            t,
            (id) => sprites.lifeIcon(id, 'herramienta'),
            (txt, x, y, col, size) => _rankedText(c, txt, x, y, col, size, 900),
            hover: controller.hoverHelper,
            markOf: _npcMark,
            period: controller.helperPeriod);
        _drawLandmarkSprite(c, map, TownSpot.workshop, 'taller_oficios');
        _drawLandmarkSprite(c, map, TownSpot.armory, 'armeria');
        _drawLandmarkSprite(c, map, TownSpot.forge, 'forja');
      } else if (biomeLayout(map.place) case final lay?
          when !s.town.resident(lay.npc.id).invited) {
        // Habitante del bioma (overworld_biomes.md § 9); si ya se mudó al
        // pueblo, solo está allá (§ 10.1).
        // Campamento y paseo (§ 9.2): todo sale del reloj de la sala.
        _drawCamp(c, lay.npc, t);
        final at = NpcCampRules.state(lay.npc, s.time);
        final im = sprites.lifeIcon(lay.npc.sprite, 'herramienta');
        final cx = at.x, bottom = at.y + ts / 2;
        if (im != null) {
          final w = im.width.toDouble(), h = im.height.toDouble();
          // Sin aplastar el sprite: lo suyo se nota con las chispas;
          // un saltito al caminar.
          final dh = h;
          final hop = at.walking ? ((t / 120).floor().isEven ? 1.0 : 0.0) : 0.0;
          c.drawImageRect(
              im,
              Rect.fromLTWH(0, 0, w, h),
              Rect.fromLTWH(cx - w / 2, bottom - dh - hop, w, dh),
              SpriteCatalog.pixelPaint());
        }
        if (at.busy) _drawSparks(c, lay.npc, cx, bottom, t);
        _rankedText(c, lay.npc.name.toUpperCase(), cx, bottom - ts - 4,
            TownPalette.label, 6, 899);
        drawNpcMark(
            (txt, x, y, col, size) => _rankedText(c, txt, x, y, col, size, 901),
            _npcMark(lay.npc),
            cx,
            bottom - ts - 7,
            t);
      } else if (biomeLayout(map.place) case final lay?) {
        // Se está mudando (§ 10.1): baja por el camino del sur y se
        // desvanece en el borde. Sale del reloj de la sala: todos lo ven.
        final dep = ResidentRules.departure(
            lay.npc, s.town.resident(lay.npc.id), s.time);
        final im = sprites.lifeIcon(lay.npc.sprite, 'herramienta');
        if (dep != null && im != null) {
          final w = im.width.toDouble(), h = im.height.toDouble();
          final bottom = dep.y + ts / 2;
          final hop = (t / 120).floor().isEven ? 1.0 : 0.0;
          c.drawImageRect(
              im,
              Rect.fromLTWH(0, 0, w, h),
              Rect.fromLTWH(dep.x - w / 2, bottom - h - hop, w, h),
              SpriteCatalog.pixelPaint()
                ..color = DsColors.textPrimary.withValues(alpha: dep.alpha));
        }
      }
      // Pescador nativo del bioma (fishing.md § 12): camina por la orilla.
      if (biomeLayout(map.place) case final lay?) {
        if (kBiomeFishers[lay.id] case final f?) {
          final (fx, fy) = BiomeFisherRules.position(lay, s.time);
          final im = sprites.lifeIcon(f.sprite, 'herramienta');
          if (im != null) {
            final w = im.width.toDouble(), h = im.height.toDouble();
            c.drawImageRect(
                im,
                Rect.fromLTWH(0, 0, w, h),
                Rect.fromLTWH(fx - w / 2, fy + 8 - h, w, h),
                SpriteCatalog.pixelPaint());
          }
          _rankedText(
              c, f.name.toUpperCase(), fx, fy - 12, TownPalette.label, 6, 898);
        }
      }
      // World event actors (world_events.md § 3): visitors, wanderers,
      // caravans and echo rift portals, for their days.
      _drawWorldEvents(c, s, map.place ?? kPueblo, t);
      // NPC hechos con datos (npc_editor.md § 6): quietos, con su nombre.
      for (final n in controller.customNpcsHere) {
        final im = sprites.lifeIcon(n.def.sprite, 'herramienta');
        final bottom = n.y + ts / 2;
        if (im != null) {
          final w = im.width.toDouble(), h = im.height.toDouble();
          c.drawImageRect(im, Rect.fromLTWH(0, 0, w, h),
              Rect.fromLTWH(n.x - w / 2, bottom - h, w, h),
              SpriteCatalog.pixelPaint());
        }
        _rankedText(c, n.def.name.text.toUpperCase(), n.x, bottom - ts - 6,
            TownPalette.label, 6, 897);
      }
      // PNJ de la mina (mining_smithing.md § 1.2): quieto, con su nombre.
      if (controller.mineLevel?.npc case (final id, final nx, final ny)?) {
        final im = sprites.lifeIcon('npc_mina_$id', 'herramienta');
        final cx = (nx + 0.5) * ts, bottom = (ny + 1) * ts;
        if (im != null) {
          final w = im.width.toDouble(), h = im.height.toDouble();
          c.drawImageRect(im, Rect.fromLTWH(0, 0, w, h),
              Rect.fromLTWH(cx - w / 2, bottom - h, w, h),
              SpriteCatalog.pixelPaint());
        }
        _rankedText(
            c,
            controller.strings.t('ui.world.mine.npc.$id.name').toUpperCase(),
            cx,
            bottom - ts - 6,
            TownPalette.label,
            6,
            897);
      }
      // Objetivo del próximo E / clic (solo el jugador local).
      if (controller.farmTarget case final ft?) {
        farm.drawTarget(c, ft.tiles, ft.ok);
      }
    }

    // Entidades ordenadas por y (desempate: orden de llegada).
    final ents = <(double, int, void Function())>[];
    void add(double y, void Function() draw) =>
        ents.add((y, ents.length, draw));
    // Faros del pueblo (day_night_weather.md § 5): prendidos de noche.
    final outdoor = SkyRules.outdoor(map.theme, town: map.lobby);
    final night = outdoor && SkyRules.darkness(s.town.sky) > 0.25;
    final lights = <Offset>[];
    // Mazmorra oscura (lighting.md § 5): solo con misión en curso. Las
    // minas (mining_smithing.md § 1.2) son oscuras siempre.
    final darkMap = (!map.lobby &&
            s.mission != null &&
            (debugForceDark ||
                LightRules.isDark(map.theme,
                    floor: currentFloor(view)?.index ?? 0))) ||
        (map.lobby && MiningRules.isMine(map.place));
    final inMine = map.lobby && MiningRules.isMine(map.place);
    final movingLights = <LightSource>[];
    final placed = <(double, double)>[];
    sky.placedLights = placed;
    if (map.lobby && map.place == null) {
      final (ox, oy) = map.townOrigin;
      for (final (fx, fy) in s.town.lights) {
        final px = (fx + ox) * ts, py = (fy + oy) * ts;
        if (!worldView.inflate(_lampReach).contains(Offset(px, py))) continue;
        lights.add(Offset(px + 8, py + 2));
        placed.add((fx + ox + 0.5, fy + oy + 0.3));
        add(py + 15, () => tiles.faro(c, px, py, t, lit: night));
      }
    }

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
      final wisp = p.hp > 0 &&
          LightRules.wispActive(
              toggled: p.wisp,
              outdoor: outdoor,
              night: SkyRules.isNight(s.town.sky));
      if (p.hp > 0 && (darkMap || night || wisp)) {
        // In a mine the carried light is small (§ 1.6): torches matter.
        movingLights.add(LightSource(
            px / ts,
            py / ts,
            inMine && !wisp
                ? kLightDefs[LightId.minero]!
                : LightRules.carried(dark: darkMap, wisp: wisp)));
      }
      final line = s.mode != SessionMode.lobby
          ? null
          : mine
              ? controller.mapFishing?.line
              : p.fishLine;
      if (line == null && mine) fishing.barRect = null;
      if (wisp) {
        final w = _wispFollow(p.id, px, py);
        add(py + 0.5, () => _drawWisp(c, w));
      } else {
        _wisps.remove(p.id);
      }
      add(py, () {
        hero(px, py);
        // Cerca de la huerta sale la azada equipada (farming.md § 4).
        if (line == null && toolOut) {
          final face = mine ? controller.local.fx : p.dir;
          final tool = mine ? controller.activeTool : ActiveTool.hoe;
          if (tool == ActiveTool.mine) {
            // The pick is drawn by the mine layer (swing).
          } else if (tool == ActiveTool.rod) {
            fishing.drawIdleRod(c, px, py, face);
          } else {
            switch (mine ? controller.farmHand : FarmHand.hoe) {
              case FarmHand.hoe:
                farm.drawHoe(c, px, py, face);
              case FarmHand.can:
                farm.drawCan(c, px, py, face);
              case FarmHand.seed:
                final d = kCrops[p.profile.life.farm.activeSeed];
                farm.drawSeedBag(
                    c, px, py, face, FarmPalette.fruit[d?.rarity.index ?? 0]);
              case FarmHand.fert:
                // El abono, como bolsa del color de su rareza.
                final d = kFertilizers[controller.farmFert];
                farm.drawSeedBag(
                    c, px, py, face, FarmPalette.fruit[d?.rarity.index ?? 0]);
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
        // Solo el nombre, un paso más chico (v0.37.3).
        actors.text(c, p.name, px, py - 22,
            mine ? const Color(0xFFFFD166) : const Color(0xFFFFFFFF), 5);
        // Auto-fishing tag with this session's catches (fishing.md § 6).
        final auto = line != null &&
            (mine ? controller.autoFishing : line.auto);
        if (auto) {
          final tag = mine
              ? controller.strings.t('ui.world.ctl.autofish.tag',
                  {'n': controller.autoFishCaught})
              : controller.strings.t('ui.world.ctl.autofish.label');
          actors.text(c, tag, px, py - 29, const Color(0xFF7FD8FF), 4);
        }
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
      // Salida de la mazmorra (free_movement.md § 2.4): portal en la
      // llegada del piso 1, donde aparece SALIR DE LA MAZMORRA.
      if (dungeonExitAt(view,
              freeMovement: controller.engine.freeMovement,
              run: controller.isRun)
          case (final ex, final ey)) {
        if (sprites.lifeIcon(kDungeonExitSprite, '') case final im?) {
          add(ey - 1, () {
            final w = im.width.toDouble(), h = im.height.toDouble();
            c.drawImageRect(
                im,
                Rect.fromLTWH(0, 0, w, h),
                Rect.fromLTWH((ex - w / 2).roundToDouble(),
                    (ey + ts / 2 - h).roundToDouble(), w, h),
                SpriteCatalog.pixelPaint());
          });
        }
      }
      // Altar de la Ofrenda en la sala del jefe vencido
      // (persistent_dungeons.md § 4).
      if (DungeonRules.persistent(view.session, zone: mission.zone) &&
          DungeonRules.altarActive(mission)) {
        final b = DungeonRules.boss(mission)!;
        if (b.floor == mission.floor) {
          add(b.homeY, () {
            actors.relic(c, b.homeX, b.homeY, t);
            actors.text(
                c, 'OFRENDA', b.homeX, b.homeY - 22, ProtoColors.gold, 6);
          });
        }
      }
      for (final e in mission.enemies) {
        if (!e.alive || e.floor != mission.floor) continue;
        final d = _lerpPos('f${e.id}', e.x, e.y);
        // En la penumbra de una mazmorra oscura no se ven (salvo jefes).
        if (darkMap && !e.boss) {
          final lg = light.last;
          if (lg != null &&
              lg.lum((d.x / ts).floor(), (d.y / ts).floor()) <
                  darkSeen * darknessKeep) {
            continue;
          }
        }
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
    // Mines and the town cart station (mining_smithing.md § 1.7–1.9).
    void mineText(String txt, double x, double y, Color col, double size) =>
        actors.text(c, txt, x, y, col, size);
    if (controller.mineLevel case final lvl? when inMine) {
      final p = controller.session?.players[controller.localId];
      final ms = controller.mineClock.elapsedMilliseconds -
          controller.lastSwingMs;
      final period = controller.mineSwingPeriodMs;
      // The pick shows through a swing, and stays raised while held.
      final swinging = ms < period + 150 || controller.mineHolding;
      mine.drawMine(c, lvl, s.town.mine(map.place!), t,
          cracks: controller.mineCracks,
          playerAt: (id) => _lastDrawn[id],
          minerSprite: sprites.lifeIcon('npc_mina_miner', 'herramienta'),
          text: mineText,
          tr: controller.strings.t,
          swing: swinging && p != null && controller.lastSwingTile != null
              ? (controller.lastSwingTile!, ms, period, (p.x, p.y))
              : null,
          indicator: switch (controller.mineDigState) {
            (final tile, final dealt, final hits, final ok) => switch (
                  MineLayer.digProgress(
                      dealt: dealt,
                      hits: hits,
                      sinceHitMs: ms,
                      holding: controller.mineHolding)) {
                final k? => (tile, k, ok),
                null => null,
              },
            null => null,
          });
    } else if (map.lobby && map.place == null) {
      final (ox, oy) = map.townOrigin;
      for (final l in TownPlan.landmarksOf(s.town)) {
        if (l.spot != TownSpot.carts) continue;
        final rail = TownPlan.of(s.town).cartRail(l, s.town.lights);
        final top = (l.y + l.h + oy) * ts;
        mine.drawTown(
            c,
            s.town.mines,
            s.time,
            Rect.fromLTWH((l.x + ox) * ts, (l.y + oy) * ts, l.w * ts, l.h * ts),
            rail.isEmpty ? top : (rail.last.$2 + 1) * ts,
            t,
            text: mineText,
            label: controller.cartLabel);
      }
    }
    if (map.lobby) {
      fishing.drawPops(c, t, (id) => _lastDrawn[id],
          (s, x, y, col, size) => actors.text(c, s, x, y, col, size));
      farm.drawPops(c, t, (id) => _lastDrawn[id],
          (s, x, y, col, size) => actors.text(c, s, x, y, col, size));
    }
    lifeLevels.draw(c, t, controller.localId, (id) => _lastDrawn[id],
        (s, x, y, col, size) => actors.text(c, s, x, y, col, size));

    // Regions (biome_regions.md § 6–7): critters, cloud shadows and the
    // shade under cave roofs. Only the view; see RegionLightLayer.
    final region = map.lobby ? biomeLayout(map.place) : null;
    final secs = reduceMotion ? 0.0 : t / 1000;
    final dayDark = outdoor ? SkyRules.darkness(s.town.sky) : 1.0;
    if (!controller.editingTown) {
      if (region != null) {
        life.draw(c, worldView, secs, region.base.style.critter,
            density: particleDensity, night: dayDark > 0.5);
      }
      if (outdoor && WeatherRules.hasSky(map.place)) {
        final cover = LightShaftRules.cloudCover(
            SkyRules.nowIn(s.town.sky, s.place).name, dayDark);
        regionLight.drawClouds(c, worldView, secs, cover, map.width * ts,
            map.height * ts);
      }
      if (region != null) {
        regionLight
          ..drawCaveShade(c, region, outdoor ? 1 - 0.5 * dayDark : 0.6)
          // Water glow, specks, mist and drips (biome_regions.md § 7.2.1).
          ..drawCaveLife(c, region, secs, motion: !reduceMotion);
      }
      // Roof edge at the cave mouths (biome_regions.md § 7.2.1).
      if (region != null) regionLight.drawRoofEdges(c, region, map.tileAt);
    }

    // El cielo encima de todo el mapa (no en la edición del pueblo).
    if ((outdoor || darkMap) && !controller.editingTown) {
      // Luz por tile multiplicada sobre el mapa (lighting.md § 4).
      final dk = outdoor ? SkyRules.darkness(s.town.sky) : 1.0;
      final w = SkyRules.nowIn(s.town.sky, s.place);
      final overcast = !outdoor
          ? 0.0
          : switch (w) {
              Weather.tormenta => 1.0,
              Weather.lluvia => 0.5,
              Weather.fog => 0.35,
              Weather.snow => 0.25,
              Weather.despejado => 0.0,
            };
      final ambient = darkMap
          ? (inMine ? MapLightLayer.mineAmbient : MapLightLayer.dungeonAmbient)
          : MapLightLayer.outdoorAmbient(dk,
              overcast: overcast, bolt: sky.boltLight(t) * flashFactor);
      final lit = darkMap || dk > 0.05;
      if (lit && outdoor) {
        for (final (o, b) in sky.fireflies(worldView, t, particleDensity)) {
          movingLights.add(LightSource(
              o.dx / ts, o.dy / ts, kLightDefs[LightId.luciernaga]!,
              scale: b * dk));
        }
      }
      if (lit) {
        for (final l in floor) {
          if (!l.legendary || l.hidden) continue;
          movingLights.add(LightSource(
              l.ground.x / ts, l.ground.y / ts, kLightDefs[LightId.botin]!));
        }
      }
      final (ox, oy) = map.townOrigin;
      final townLights =
          map.lobby && map.place == null ? s.town.lights : const <(int, int)>[];
      final campLay = map.lobby ? biomeLayout(map.place) : null;
      final campNpc = campLay != null &&
              !s.town.resident(campLay.npc.id).invited
          ? campLay.npc
          : null;
      if (ambient.$1 < 0.995 || ambient.$3 < 0.995) {
        light.draw(c, map, worldView,
            ambient: ambient,
            fixed: (a, b, cx, cy) => lit
                ? [
                    ...LightRules.tileEmitters(map, a, b, cx, cy,
                        dark: darkMap && !inMine, biome: map.place != null),
                    ...LightRules.ambientEmitters(map, a, b, cx, cy),
                    for (final (fx, fy) in townLights)
                      LightSource(fx + ox + 0.5, fy + oy + 0.3,
                          kLightDefs[LightId.faro]!),
                    // Hoguera del campamento (lighting.md § 3).
                    if (campNpc != null)
                      if (NpcCampRules.light(campNpc, a, b, cx, cy)
                          case final l?)
                        l,
                    // Daylight through ceiling openings (§ 7).
                    for (final (sx, sy) in LightShaftRules.shafts(map))
                      if (sx >= a && sx < cx && sy >= b && sy < cy)
                        LightSource(
                            sx + 0.5, sy + 0.5, kLightDefs[LightId.shaft]!),
                  ]
                : const [],
            moving: lit ? movingLights : const [],
            t: t,
            keep: darknessKeep,
            motion: !reduceMotion);
      }
      // Niebla del minimapa (lighting.md § 5.4): lo que ve el jugador.
      final lg = light.last;
      final m = s.mission;
      if (darkMap && darknessKeep > 0 && m != null && lg != null) {
        controller.fogLoaded
          ..begin('${m.missionId}:${m.seed}', map.width, map.height)
          ..reveal(lg.x0, lg.y0, lg.w, lg.h, lg.lum, darkSeen * darknessKeep);
      } else {
        controller.fog.reset();
      }
      if (outdoor) {
        sky.draw(c, s.town.sky, worldView, t,
            lights: lights,
            density: particleDensity,
            flash: flashFactor,
            motion: !reduceMotion,
            tint: false,
            weather: SkyRules.nowIn(s.town.sky, s.place),
            precipitation: climateOf(s.place).showsPrecipitation);
      }
    }

    // Light shafts from openings above (biome_regions.md § 7): indoor
    // places flagged with openings; caves without them stay dark.
    if (!controller.editingTown && LightShaftRules.hasOpenings(map)) {
      final strength =
          darkMap ? 1.0 : (1 - dayDark * 0.7).clamp(0.3, 1.0).toDouble();
      // Biome regions: soft light pools, no beam (§ 7.2.1).
      if (map.lobby && biomeLayout(map.place) != null) {
        regionLight.drawPools(c, map, worldView, secs,
            strength: strength, motion: !reduceMotion);
      } else {
        regionLight.drawShafts(c, map, worldView, secs,
            strength: strength, motion: !reduceMotion);
      }
    }

    if (map.lobby && map.place == null) {
      TownEditLayer.draw(c, controller, map,
          (s, x, y, col, size) => actors.text(c, s, x, y, col, size),
          view: worldView);
    }

    // Carteles de las entradas de zona (mapa del mundo).
    for (final e in map.entrances) {
      final z = zones[e.zone];
      if (z == null) continue;
      final cx = e.center.x, cy = e.center.y;
      final col = z.open ? zoneColor(e.zone) : const Color(0xFF9AA0AC);
      if (!z.open) {
        _placeText(c, z.playable ? 'BLOQUEADA' : 'PRÓXIMAMENTE', cx, cy - 56,
            const Color(0xFFFF6B81), 6, 950);
      }
      _placeText(c, z.zone.name, cx, cy - 47, col, 7, 951);
      _placeText(c, z.zone.levelText, cx, cy - 38, col, 6, 952);
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
    if (outdoor && !controller.editingTown) {
      _drawSkyNotice(c, s.town.sky, SkyRules.nowIn(s.town.sky, s.place));
    }
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

  /// Cartel chico arriba (day_night_weather.md § 3.4): de noche, el
  /// pronóstico de mañana; de día con lluvia o tormenta, el clima.
  void _drawSkyNotice(Canvas c, SkyState sky, Weather w) {
    if (!sky.started) return;
    final txt = SkyRules.isNight(sky)
        ? 'Noche · ${SkyRules.forecast(sky)}'
        : w == Weather.despejado
            ? null
            : w == Weather.lluvia
                ? 'Llueve'
                : w.label;
    if (txt != _skyNoticeTxt) {
      _skyNoticeTxt = txt;
      _skyNoticeT0 = txt == null ? null : _now;
    }
    final t0 = _skyNoticeT0;
    if (txt == null || t0 == null) return;
    // Like a snackbar: 3 s, the last 0.5 s fading out.
    final q = (_now - t0) / skyNoticeMs;
    if (q >= 1) return;
    final a = (q < 5 / 6 ? 1.0 : (1 - q) * 6).clamp(0.0, 1.0);
    c.drawRect(const Rect.fromLTWH(vw / 2 - 110, 30, 220, 14),
        Paint()..color = SkyPalette.forecastBack.withValues(
            alpha: SkyPalette.forecastBack.a * a));
    actors.text(c, txt, vw / 2, 40,
        SkyPalette.forecast.withValues(alpha: a), 6);
  }

  /// How long the weather / forecast notice stays up (ms).
  static const skyNoticeMs = 3000.0;
  String? _skyNoticeTxt;
  double? _skyNoticeT0;
  double get _now => DateTime.now().millisecondsSinceEpoch.toDouble();

  /// Llama errante por jugador: posición suavizada y estela.
  final _wisps = <String, _Wisp>{};

  /// Mueve la Llama errante de [id] (lighting.md § 3.1.1): flota sobre la
  /// cabeza del personaje con un vaivén lento y lo sigue con retraso.
  _Wisp _wispFollow(String id, double px, double py) {
    final ph = (id.hashCode % 628) / 100.0;
    final sec = t / 1000;
    final tx =
        px + math.sin(sec * 0.45 + ph) * 8 + math.sin(sec * 1.1 + ph * 2) * 3;
    final ty = py - 24 + math.sin(sec * 1.6 + ph) * 2.5;
    final w = _wisps[id];
    if (w == null || (w.x - tx).abs() + (w.y - ty).abs() > 160) {
      return _wisps[id] = _Wisp(tx, ty, t);
    }
    final dt = ((t - w.at) / 1000).clamp(0.0, 0.1);
    final k = 1 - math.exp(-dt * 3.5);
    w
      ..x += (tx - w.x) * k
      ..y += (ty - w.y) * k
      ..at = t
      ..push();
    return w;
  }

  /// Dibuja la Llama errante [w] con dos ecos tenues detrás.
  void _drawWisp(Canvas c, _Wisp w) {
    final pulse = 1 + math.sin(t / 420) * 0.12;
    for (var k = 2; k >= 0; k--) {
      final (x, y) = w.echo(k * 8);
      final fade = 1.0 - k * 0.35;
      c.drawCircle(
          Offset(x, y),
          5.0 * fade * pulse,
          Paint()
            ..color = LightPalette.wispHalo.withValues(alpha: 0.35 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      if (k == 0) {
        c.drawCircle(Offset(x, y), 2.2, Paint()..color = LightPalette.wispCore);
      }
    }
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
        switch (controller.engine.catalog.zone(m.zone)) {
          final z? => zoneNameText(controller.strings, z),
          null => null,
        } ??
        switch (controller.engine.catalog.mission(m.missionId)) {
          final md? => missionNameText(controller.strings, md),
          null => null,
        } ??
        '';
    actors.text(c, floorLabelText(controller.strings, name, m.floor, m.floors),
        vw / 2, vh / 2, const Color(0xFFFFD166), 8);
  }

  /// Haces de Legendarios recién caídos al inventario en curso (tests).
  int get activeBeams => _beams.length;

  /// Lugares dibujados con sprite (v0.32.3: TALLER DE OFICIOS y
  /// ARMERÍA): `items.vida_<id>` del manifest, apoyado en su rectángulo.
  void _drawLandmarkSprite(Canvas c, GameMap map, TownSpot spot, String id) {
    final im = sprites.lifeIcon(id, 'herramienta');
    if (im == null) return;
    final l = (map.townMarks ?? TownLayout.landmarks)
        .where((l) => l.spot == spot)
        .firstOrNull;
    if (l == null) return;
    final (ox, oy) = map.townOrigin;
    final w = im.width.toDouble(), h = im.height.toDouble();
    final cx = (l.x + ox + l.w / 2) * ts, bottom = (l.y + oy + l.h) * ts;
    c.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, w, h),
        Rect.fromLTWH((cx - w / 2).roundToDouble(), bottom - h, w, h),
        SpriteCatalog.pixelPaint());
  }

  final Paint _campPaint = Paint();

  /// Campamento de un habitante de bioma (overworld_biomes.md § 9.2):
  /// hoguera con brasas que titilan y el objeto de su oficio.
  void _drawCamp(Canvas c, BiomeNpcDef npc, double t) {
    final camp = kNpcCamps[npc.id];
    final fire = NpcCampRules.fireTile(npc);
    final prop = NpcCampRules.propTile(npc);
    if (camp == null || fire == null || prop == null) return;
    void sprite(String id, (int, int) at) {
      final im = sprites.lifeIcon(id, 'herramienta');
      if (im == null) return;
      final w = im.width.toDouble(), h = im.height.toDouble();
      c.drawImageRect(
          im,
          Rect.fromLTWH(0, 0, w, h),
          Rect.fromLTWH((at.$1 + 0.5) * ts - w / 2, (at.$2 + 1) * ts - h, w, h),
          SpriteCatalog.pixelPaint());
    }

    sprite(NpcCampDef.fireSprite, fire);
    sprite(camp.propSprite, prop);
    // Llama: tres píxeles que suben y titilan (sin timers: sale de [t]).
    final fx = (fire.$1 + 0.5) * ts, fy = (fire.$2 + 1) * ts - 7;
    for (var i = 0; i < 3; i++) {
      final ph = ((t / 90 + i * 3.7) % 6) / 6;
      _campPaint.color = Color.lerp(const Color(0xFFFFE08A),
              const Color(0xFFFF6A2A), ph)!
          .withValues(alpha: 1 - ph);
      c.drawRect(
          Rect.fromLTWH(fx - 2 + i * 1.5, fy - ph * 6, 1, 1), _campPaint);
    }
  }

  /// Chispas de la actividad del habitante (§ 9.2), del color de su oficio.
  void _drawSparks(
      Canvas c, BiomeNpcDef npc, double x, double bottom, double t) {
    final key = kNpcCamps[npc.id]?.spark ?? 'calida';
    final base = LightPalette.tints[key] ?? LightPalette.fallback;
    for (var i = 0; i < 4; i++) {
      final ph = ((t / 160 + i * 1.9) % 4) / 4;
      _campPaint.color = base.withValues(alpha: 1 - ph);
      c.drawRect(
          Rect.fromLTWH(x - 5 + i * 3.0, bottom - 3 - ph * 8, 1, 1),
          _campPaint);
    }
  }
}

/// Estado de dibujo de una Llama errante: posición y estela corta.
class _Wisp {
  _Wisp(this.x, this.y, this.at);
  double x, y, at;
  final _trail = <(double, double)>[];

  void push() {
    _trail.add((x, y));
    if (_trail.length > 20) _trail.removeAt(0);
  }

  /// Posición de hace [back] cuadros.
  (double, double) echo(int back) {
    if (back == 0 || _trail.isEmpty) return (x, y);
    return _trail[math.max(0, _trail.length - 1 - back)];
  }
}
