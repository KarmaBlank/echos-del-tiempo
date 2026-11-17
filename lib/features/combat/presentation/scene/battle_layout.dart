import 'dart:math' as math;
import 'dart:ui';

import '../../../../game_engine/models/battle_state.dart';

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
    );
  }

  /// Punto de pantalla → punto del lienzo virtual.
  Offset toVirtual(Offset screen) => screen / scale;
}

/// Posiciones de batalla de cada actor (`startBattle`) y objetivo de la
/// cámara. Coordenadas del mundo; `(x, y)` = pies.
class BattleLayout {
  BattleLayout._(this.positions, this.side, this.centerX, this.centerY);

  final Map<String, Offset> positions;
  final int side;

  /// `(B.cx, B.cy)`.
  final double centerX, centerY;

  static const _offsets = [
    Offset(0, 0),
    Offset(22, -26),
    Offset(22, 26),
    Offset(40, 0),
  ];

  /// Sin arena: el enemigo en `(VW/2 − 34, 104)` de una vista de [vw].
  factory BattleLayout.compute(BattleState state, BattleArena? arena,
      {int vw = SceneGeometry.baseWidth}) {
    final s = arena?.side ?? 1;
    final bx = arena?.anchorX ?? vw / 2 - 34.0;
    final by = arena?.anchorY ?? 104.0;
    final pos = <String, Offset>{};
    final n = state.party.length;
    for (var i = 0; i < n; i++) {
      pos[state.party[i].id] =
          Offset(bx + s * (72 + (i % 2) * 14), by + (i - (n - 1) / 2) * 24);
    }
    final bossFirst = state.enemies.isNotEmpty && state.enemies.first.boss;
    for (var i = 0; i < state.enemies.length; i++) {
      final o = _offsets[math.min(i, _offsets.length - 1)];
      pos[state.enemies[i].id] =
          Offset(bx - s * (o.dx + (i > 0 && bossFirst ? 18 : 0)), by + o.dy);
    }
    return BattleLayout._(pos, s, bx + s * 34, by);
  }

  Offset of(String id) => positions[id] ?? Offset(centerX, centerY);

  /// Objetivo de la cámara (esquina superior izquierda) para una vista
  /// de [g]; [coverBottom] = px virtuales de escena tapados por paneles.
  Offset cameraTarget(SceneGeometry g, BattleArena? arena,
      {double coverBottom = 0}) {
    final vw = g.virtualWidth.toDouble();
    const vh = SceneGeometry.baseSceneHeight * 1.0;
    if (arena == null) return Offset.zero;
    final mw = arena.worldWidth, mh = arena.worldHeight;
    final visibleH = math.min(vh, g.sceneHeight - coverBottom).toDouble();
    final tx = mw < vw
        ? (mw - vw) / 2
        : (centerX - vw / 2).clamp(-40.0, mw - vw + 40);
    final ty = mh < vh
        ? (mh - vh) / 2
        : (centerY - vh / 2 + 40)
            .clamp(-70.0, math.max(-70.0, mh - visibleH + 30));
    return Offset(tx.toDouble(), ty.toDouble());
  }

  /// Cámara del campo centrada en el jugador local (`render` sin batalla).
  static Offset fieldCamera(SceneGeometry g, BattleArena arena) {
    final vw = g.virtualWidth.toDouble(), vh = g.sceneHeight.toDouble();
    final mw = arena.worldWidth, mh = arena.worldHeight;
    final fx = arena.fieldFocusX ?? arena.anchorX;
    final fy = arena.fieldFocusY ?? arena.anchorY;
    final tx = mw < vw ? (mw - vw) / 2 : (fx - vw / 2).clamp(0.0, mw - vw);
    final ty = mh < vh ? (mh - vh) / 2 : (fy - vh / 2).clamp(0.0, mh - vh);
    return Offset(tx.toDouble(), ty.toDouble());
  }
}
