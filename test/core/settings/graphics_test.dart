import 'dart:math' as math;
import 'dart:ui';

import 'package:echos_del_tiempo/core/settings/frame_limiter.dart';
import 'package:echos_del_tiempo/core/settings/graphics.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/particles.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cuántos cuadros dibuja [l] en [seconds] s de vsyncs a [hz].
int _drawnOver(FrameLimiter l, double hz, {double seconds = 2, int t0 = 0}) {
  final period = 1e6 / hz;
  final n = (seconds * hz).round();
  var drawn = 0;
  for (var i = 0; i < n; i++) {
    final t = t0 + (i * period).round();
    if (l.shouldDraw(Duration(microseconds: t))) drawn++;
  }
  return drawn;
}

void main() {
  group('ESCALADO (mapViewRect)', () {
    const v = Size(480, 288);

    test('1280×720: AJUSTAR ×2.5 (llena el alto); PIXEL PERFECT ×2', () {
      final fit = mapViewRect(const Size(1280, 720), v, ScaleMode.fit);
      expect(fit, const Rect.fromLTWH(40, 0, 1200, 720));
      final pp = mapViewRect(const Size(1280, 720), v, ScaleMode.pixelPerfect);
      expect(pp, const Rect.fromLTWH(160, 72, 960, 576));
    });

    test('área útil de la ventana por defecto (1264×681)', () {
      final fit = mapViewRect(const Size(1264, 681), v, ScaleMode.fit);
      expect(fit.height, 681);
      expect(fit.width, closeTo(1135, 1));
      final pp =
          mapViewRect(const Size(1264, 681), v, ScaleMode.pixelPerfect);
      expect(pp.size, const Size(960, 576));
      expect(pp.center.dx, 632);
      expect(pp.center.dy, closeTo(340.5, 0.5));
    });

    test('1920×1080 ×3 y 2560×1440 ×5 exacto', () {
      expect(mapViewRect(const Size(1920, 1080), v, ScaleMode.pixelPerfect),
          const Rect.fromLTWH(240, 108, 1440, 864));
      expect(mapViewRect(const Size(1920, 1080), v, ScaleMode.fit).height,
          1080);
      expect(mapViewRect(const Size(2400, 1440), v, ScaleMode.pixelPerfect),
          const Rect.fromLTWH(0, 0, 2400, 1440));
    });

    test('PIXEL PERFECT siempre entero (y mínimo ×1 en ventanas chicas)', () {
      for (final s in const [
        Size(800, 600),
        Size(1366, 768),
        Size(1600, 900),
        Size(3840, 2160),
        Size(300, 200),
      ]) {
        final r = mapViewRect(s, v, ScaleMode.pixelPerfect);
        final k = r.width / 480;
        expect(k, k.roundToDouble(), reason: '$s');
        expect(r.height / 288, k, reason: '$s');
        expect(k, greaterThanOrEqualTo(1));
        if (k > 1) {
          expect(r.width, lessThanOrEqualTo(s.width));
          expect(r.height, lessThanOrEqualTo(s.height));
          // El siguiente entero ya no entraría.
          expect((k + 1) * 480 > s.width || (k + 1) * 288 > s.height, isTrue);
        }
        final f = mapViewRect(s, v, ScaleMode.fit);
        expect(f.width >= r.width - 1 || k == 1, isTrue);
      }
    });
  });

  group('PARTÍCULAS', () {
    test('scaledCount: ×0.3 / ×0.6 / ×1, nunca hace desaparecer una ráfaga',
        () {
      expect(scaledCount(20, ParticleLevel.high.factor), 20);
      expect(scaledCount(20, ParticleLevel.medium.factor), 12);
      expect(scaledCount(20, ParticleLevel.low.factor), 6);
      expect(scaledCount(1, 0.3), 1);
      expect(scaledCount(0, 0.3), 0);
      expect(scaledCount(600, 0.3), 180);
    });

    test('las ráfagas del sistema de partículas siguen el nivel', () {
      int burst(ParticleLevel l) {
        final p = ParticleSystem(math.Random(1))..density = l.factor;
        p.burst(0, 0, FxElement.burn, 2.2);
        return p.particles.length;
      }

      final hi = burst(ParticleLevel.high);
      expect(hi, greaterThan(10));
      expect(burst(ParticleLevel.medium), closeTo(hi * 0.6, 1));
      expect(burst(ParticleLevel.low), closeTo(hi * 0.3, 1));
    });

    test('el tope también baja (600 × nivel)', () {
      final p = ParticleSystem(math.Random(2))..density = 0.3;
      for (var i = 0; i < 100; i++) {
        p.burst(0, 0, FxElement.burn, 3);
      }
      expect(p.particles.length, lessThanOrEqualTo(180));
    });

    test('la escena aplica el nivel de las opciones', () {
      final s = BattleSceneController(random: math.Random(3))
        ..options = const SceneOptions(particles: 0.6);
      s.advance(16);
      expect(s.particles.density, 0.6);
      s.dispose();
    });
  });

  group('ESCALADO en batalla', () {
    SceneFrame frame() {
      final state = BattleState(party: [], enemies: []);
      final g = SceneGeometry.fit(const Size(1280, 500));
      return SceneFrame(
        battle: state,
        geometry: g,
        layout: BattleLayout.compute(state, null),
      );
    }

    test('PIXEL PERFECT redondea el zoom de la cámara; AJUSTAR no', () {
      final s = BattleSceneController();
      final f = frame();
      s.camera = const CameraView(Offset(100, 100), 3.4);
      expect(s.viewFor(f).zoom, 3.4);
      s.options = const SceneOptions(pixelPerfect: true);
      expect(s.viewFor(f).zoom, 3);
      s.camera = const CameraView(Offset(100, 100), 3.6);
      expect(s.viewFor(f).zoom, 4);
      s.camera = const CameraView(Offset(100, 100), 0.7);
      expect(s.viewFor(f).zoom, 1);
      expect(s.viewFor(f).center, const Offset(100, 100));
      s.dispose();
    });
  });

  group('LÍMITE DE FPS (FrameLimiter)', () {
    test('sin límite: dibuja todos los vsyncs', () {
      expect(_drawnOver(FrameLimiter(), 144), 288);
    });

    test('60 Hz: tope 30 dibuja la mitad; tope 60 todos', () {
      expect(_drawnOver(FrameLimiter(fps: 30), 60), closeTo(60, 1));
      expect(_drawnOver(FrameLimiter(fps: 60), 60), 120);
    });

    test('60 en un monitor de 60.5 Hz no pierde cuadros (jitter)', () {
      expect(_drawnOver(FrameLimiter(fps: 60), 60.5), 121);
    });

    test('144 Hz: tope 60 da ~60; tope 30 da ~30', () {
      expect(_drawnOver(FrameLimiter(fps: 60), 144), closeTo(120, 3));
      expect(_drawnOver(FrameLimiter(fps: 30), 144), closeTo(60, 2));
    });

    test('120 Hz: tope 60 dibuja uno de cada dos', () {
      expect(_drawnOver(FrameLimiter(fps: 60), 120), closeTo(120, 2));
    });

    test('se re-sincroniza después de una pausa y al cambiar el tope', () {
      final l = FrameLimiter(fps: 30);
      _drawnOver(l, 60, seconds: 1);
      // Cinco segundos sin cuadros: el primero que llega se dibuja.
      expect(l.shouldDraw(const Duration(seconds: 6)), isTrue);
      expect(_drawnOver(l, 60, seconds: 1, t0: 6016667), closeTo(30, 1));
      l.fps = null;
      expect(_drawnOver(l, 60, seconds: 1, t0: 8000000), 60);
    });

    test('mide el intervalo del monitor', () {
      final l = FrameLimiter();
      _drawnOver(l, 144);
      expect(l.vsyncIntervalMs, closeTo(6.94, 0.05));
    });
  });
}
