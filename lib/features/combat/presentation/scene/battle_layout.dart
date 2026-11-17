import 'dart:math' as math;
import 'dart:ui';

import '../../../../game_engine/models/battle_state.dart';
import '../../domain/turn_order.dart' show isPassiveAdd;
import 'ult_cinematic.dart';

/// Dibuja el mundo detrás de la batalla (tiles, enemigos lejanos) en
/// coordenadas del mundo. [visible] es el rectángulo del mundo a la
/// vista; [t] el reloj de animación en ms.
typedef WorldPainter = void Function(Canvas canvas, Rect visible, double t);

/// Dónde ocurre la batalla en el mapa (lo que `startBattle` tomaba del
/// enemigo del campo). Lo arma quien hospeda la batalla (la sesión); sin
/// arena la escena usa un fondo liso.
class BattleArena {
  const BattleArena({
    required this.anchorX,
    required this.anchorY,
    required this.side,
    required this.worldWidth,
    required this.worldHeight,
    this.fieldFocusX,
    this.fieldFocusY,
    this.paintWorld,
  });

  /// `(bx, by)`: posición del enemigo del campo.
  final double anchorX, anchorY;

  /// `s`: 1 si el grupo queda a la derecha del enemigo, −1 a la izquierda.
  final int side;

  /// Tamaño del mapa en px (`map.w·TS`, `map.h·TS`).
  final double worldWidth, worldHeight;

  /// Centro de la cámara del campo al empezar (el jugador local): la
  /// cámara se desliza desde ahí hasta la batalla.
  final double? fieldFocusX, fieldFocusY;
  final WorldPainter? paintWorld;

  /// Regla de `startBattle` para el lado: el jugador que tocó está a la
  /// derecha → 1; se invierte si el grupo quedaría fuera del mapa.
  static int sideFor({
    required double enemyX,
    required double? triggerX,
    required double worldWidth,
  }) {
    var s = triggerX != null && triggerX > enemyX ? 1 : -1;
    if (enemyX + s * 86 < 12) s = 1;
    if (enemyX + s * 86 > worldWidth - 12) s = -1;
    return s;
  }
}

/// Cómo se mapea el lienzo virtual a la pantalla. Ver
/// docs/specs/battle_presentation.md § "Geometría".
class SceneGeometry {
  const SceneGeometry({
    required this.scale,
    required this.virtualWidth,
    required this.sceneHeight,
    this.size = const Size(480, 342),
  });

  /// Ancho y alto nominales del prototipo (`VW`, `VH`).
  static const baseWidth = 480;
  static const baseSceneHeight = 288;

  /// Alto de la franja de turnos (`#tl`, 54 px).
  static const stripHeight = 54;

  /// Píxeles de pantalla por píxel virtual.
  final double scale;
  final int virtualWidth;

  /// Alto de la escena (sin la franja), ≥ 288.
  final int sceneHeight;

  int get virtualHeight => stripHeight + sceneHeight;

  /// Tamaño en pantalla de toda la escena (franja + mundo).
  final Size size;

  /// Alto en pantalla de la franja de turnos.
  double get stripPx => (stripHeight * scale).roundToDouble();

  /// Área del mundo en px de pantalla (debajo de la franja).
  Rect get worldRect => Rect.fromLTWH(
      0, stripPx, size.width, math.max(1.0, size.height - stripPx));

  /// Unidad del HUD de la escena (1 con 1280×720, 2 con 1920×1080).
  int get hudUnit => scale < 2 ? 1 : 2;

  factory SceneGeometry.fit(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return const SceneGeometry(
          scale: 1, virtualWidth: baseWidth, sceneHeight: baseSceneHeight);
    }
    final s = math.min(size.width / baseWidth,
        size.height / (stripHeight + baseSceneHeight));
    return SceneGeometry(
      scale: s,
      virtualWidth: math.max(baseWidth, (size.width / s).floor()),
      sceneHeight: math.max(
          baseSceneHeight, (size.height / s).floor() - stripHeight),
      size: size,
    );
  }

  /// Punto de pantalla → punto del lienzo virtual.
  Offset toVirtual(Offset screen) => screen / scale;
}

/// Tamaño en px del mundo del sprite de un enemigo (sprite ×
/// `enemyScale` × 1.45 si es élite).
typedef EnemySize = Size Function(Combatant enemy);

/// Posiciones de batalla de cada actor (`startBattle`), sus cajas y el
/// encuadre de la cámara. Coordenadas del mundo; `(x, y)` = pies. Ver
/// docs/specs/battle_presentation.md § "Posiciones" y § "Cámara y
/// encuadre".
class BattleLayout {
  BattleLayout._(
      this.positions, this.boxes, this.side, this.centerX, this.centerY);

  final Map<String, Offset> positions;

  /// Caja de cada actor (px del mundo).
  final Map<String, Rect> boxes;
  final int side;

  /// `(B.cx, B.cy)`.
  final double centerX, centerY;

  static const _offsets = [
    Offset(0, 0),
    Offset(22, -26),
    Offset(22, 26),
    Offset(40, 0),
  ];

  /// Invocaciones (cristales): hacia el grupo desde el ancla.
  static const _addOffsets = [
    Offset(30, -22),
    Offset(30, 24),
    Offset(44, 0),
  ];

  /// Márgenes de la caja de la pelea (px del mundo).
  static const marginX = 16.0, marginTop = 6.0, marginBottom = 6.0;

  /// Lugar para las etiquetas de la fila de arriba (en unidades del HUD).
  static const labelRoom = 22;

  /// Zoom máximo del encuadre.
  static const maxZoom = 6;

  /// Sin arena: el enemigo en `(VW/2 − 34, 104)` de una vista de [vw].
  factory BattleLayout.compute(BattleState state, BattleArena? arena,
      {int vw = SceneGeometry.baseWidth, EnemySize? enemySize}) {
    final s = arena?.side ?? 1;
    final bx = arena?.anchorX ?? vw / 2 - 34.0;
    final by = arena?.anchorY ?? 104.0;
    final pos = <String, Offset>{};
    final boxes = <String, Rect>{};
    final n = state.party.length;
    for (var i = 0; i < n; i++) {
      final p =
          Offset(bx + s * (72 + (i % 2) * 14), by + (i - (n - 1) / 2) * 24);
      pos[state.party[i].id] = p;
      boxes[state.party[i].id] = Rect.fromLTWH(p.dx - 10, p.dy - 19, 20, 22);
    }
    final bossFirst = state.enemies.isNotEmpty && state.enemies.first.boss;
    var i = 0, k = 0;
    for (final e in state.enemies) {
      final Offset p;
      if (isPassiveAdd(e)) {
        // Cristales de la Sierpe: delante del jefe, entre él y el grupo.
        final o = _addOffsets[math.min(k++, _addOffsets.length - 1)];
        p = Offset(bx + s * o.dx, by + o.dy);
      } else {
        final o = _offsets[math.min(i, _offsets.length - 1)];
        p = Offset(bx - s * (o.dx + (i > 0 && bossFirst ? 18 : 0)), by + o.dy);
        i++;
      }
      pos[e.id] = p;
      final sz = enemySize?.call(e) ??
          (e.elite ? const Size(16 * 1.45, 14 * 1.45) : const Size(16, 14));
      boxes[e.id] =
          Rect.fromLTWH(p.dx - sz.width / 2, p.dy - sz.height, sz.width, sz.height + 4);
    }
    return BattleLayout._(pos, boxes, s, bx + s * 34, by);
  }

  Offset of(String id) => positions[id] ?? Offset(centerX, centerY);

  Rect boxOf(String id) =>
      boxes[id] ?? Rect.fromCenter(center: of(id), width: 16, height: 16);

  /// Unión de las cajas + márgenes (la "caja de la pelea").
  Rect get fightBox {
    if (boxes.isEmpty) {
      return Rect.fromCenter(
          center: Offset(centerX, centerY), width: 160, height: 80);
    }
    var r = boxes.values.first;
    for (final b in boxes.values) {
      r = r.expandToInclude(b);
    }
    return Rect.fromLTRB(r.left - marginX, r.top - marginTop,
        r.right + marginX, r.bottom + marginBottom);
  }

  /// Encuadre base: zoom entero que hace que la pelea llene el área del
  /// mundo de [g], centrado en la pelea y, si hay mapa, llevado hacia
  /// adentro del mapa mientras la pelea siga entera a la vista.
  CameraView frame(SceneGeometry g, BattleArena? arena) {
    final area = g.worldRect;
    final room = (labelRoom * g.hudUnit).toDouble();
    final fb = fightBox;
    final fit = math.min(
        area.width / fb.width, math.max(1.0, area.height - room) / fb.height);
    final zoom = fit.floor().clamp(1, maxZoom).toDouble();
    final vw = area.width / zoom, vh = area.height / zoom;
    final roomW = room / zoom;
    var cx = fb.center.dx;
    var cy = fb.center.dy - roomW / 2;
    // Rango en el que la pelea (y el lugar de las etiquetas) entra entera.
    final loX = fb.right - vw / 2, hiX = fb.left + vw / 2;
    final loY = fb.bottom - vh / 2, hiY = fb.top - roomW + vh / 2;
    if (arena != null) {
      final mw = arena.worldWidth, mh = arena.worldHeight;
      cx = mw <= vw ? mw / 2 : cx.clamp(vw / 2, mw - vw / 2);
      cy = mh <= vh ? mh / 2 : cy.clamp(vh / 2, mh - vh / 2);
    }
    if (loX <= hiX) cx = cx.clamp(loX, hiX);
    if (loY <= hiY) cy = cy.clamp(loY, hiY);
    return CameraView(Offset(cx, cy), zoom);
  }

  /// Cámara del campo al empezar (centrada en el jugador local), con el
  /// zoom de [base].
  static CameraView fieldView(BattleArena arena, CameraView base) =>
      CameraView(
          Offset(arena.fieldFocusX ?? arena.anchorX,
              arena.fieldFocusY ?? arena.anchorY),
          base.zoom);
}

/// Una vista de cámara aplicada a un área de pantalla: conversión
/// mundo ↔ pantalla.
class SceneViewport {
  SceneViewport(this.area, this.view);

  /// Área del mundo en px de pantalla.
  final Rect area;
  final CameraView view;

  double get zoom => view.zoom;

  /// Esquina superior izquierda de la vista en px del mundo, redondeada
  /// a píxeles enteros del mundo.
  Offset get topLeft => Offset(
      (view.center.dx - area.width / zoom / 2).roundToDouble(),
      (view.center.dy - area.height / zoom / 2).roundToDouble());

  /// Rectángulo del mundo a la vista.
  Rect get visible => topLeft & Size(area.width / zoom, area.height / zoom);

  Offset toScreen(Offset world) => area.topLeft + (world - topLeft) * zoom;

  Offset toWorld(Offset screen) => topLeft + (screen - area.topLeft) / zoom;

  Rect rectToScreen(Rect r) =>
      Rect.fromPoints(toScreen(r.topLeft), toScreen(r.bottomRight));
}
