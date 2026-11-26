import 'package:flutter/widgets.dart';

import '../persistence/ecos_log.dart';

/// Decide en cada vsync si se dibuja el cuadro o se salta, para no pasar
/// de [fps] cuadros por segundo. Ver docs/specs/settings.md § 3.4.
///
/// Acumula la hora del próximo cuadro (`next += 1/fps`) y dibuja si el
/// vsync llega a menos de medio intervalo de ella. Si la app estuvo
/// quieta (sin cuadros) se re-sincroniza. Si el tope es ≥ 95% de la
/// frecuencia del monitor (medida), no limita.
class FrameLimiter {
  FrameLimiter({int? fps}) : _fps = fps;

  /// El de la app (lo usa [EcosBinding]; lo ajusta el controlador de
  /// ajustes).
  static final shared = FrameLimiter(fps: 60);

  int? _fps;

  /// Tope en cuadros por segundo; `null` = sin límite.
  int? get fps => _fps;
  set fps(int? v) {
    if (v == _fps) return;
    _fps = v;
    _next = null;
  }

  /// Hora (µs) del próximo cuadro a dibujar.
  int? _next;

  /// Último vsync visto (dibujado o no) y el intervalo medido (µs).
  int? _lastVsync;
  double _interval = 1e6 / 60;

  /// Intervalo de vsync medido (ms; tests y diagnóstico).
  double get vsyncIntervalMs => _interval / 1000;

  /// Cuadros dibujados / saltados (diagnóstico).
  int drawn = 0, skipped = 0;

  /// ¿Se dibuja el cuadro del vsync de hora [t]?
  bool shouldDraw(Duration t) {
    final now = t.inMicroseconds;
    final last = _lastVsync;
    _lastVsync = now;
    if (last != null) {
      final d = now - last;
      // Solo intervalos de cuadros seguidos (no las pausas de la app).
      if (d > 0 && d < 100000) _interval += (d - _interval) * 0.1;
    }
    final f = _fps;
    if (f == null || f <= 0) return _draw();
    final period = 1e6 / f;
    if (period <= _interval * 1.05) return _draw();
    final next = _next;
    if (next == null || now - next > period) {
      _next = (now + period).round();
      return _draw();
    }
    if (now >= next - _interval / 2) {
      _next = (next + period).round();
      return _draw();
    }
    skipped++;
    return false;
  }

  bool _draw() {
    drawn++;
    return true;
  }
}

/// El binding de la app: igual al de Flutter, pero salta los cuadros que
/// [FrameLimiter.shared] no deja dibujar (sin build, layout, paint ni
/// raster) y pide el siguiente vsync. Los `main_*.dart` lo inicializan
/// en lugar de `WidgetsFlutterBinding`.
class EcosBinding extends WidgetsFlutterBinding {
  EcosBinding._();

  static EcosBinding? _self;

  /// Inicializa el binding (una vez, antes que cualquier otro).
  static WidgetsBinding ensureInitialized() {
    if (_self == null) {
      _self = EcosBinding._();
      _logErrors();
    }
    return WidgetsBinding.instance;
  }

  /// Build / layout / paint exceptions go to `ecos.log` with their stack
  /// (in release they only showed the grey error box, with no trace).
  static void _logErrors() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      try {
        EcosLog.error(
            'FlutterError: ${d.exceptionAsString()}\n'
            '${d.context ?? ''}\n${d.stack ?? ''}');
      } catch (_) {}
      prev?.call(d);
    };
    // Errors outside a frame (timers such as the game tick, futures) used
    // to vanish in release; a failing tick froze the HUD with no trace.
    final prevAsync = _self!.platformDispatcher.onError;
    _self!.platformDispatcher.onError = (e, st) {
      try {
        EcosLog.error('Uncaught: $e\n$st');
      } catch (_) {}
      return prevAsync?.call(e, st) ?? false;
    };
  }

  bool _skipping = false;

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    if (rawTimeStamp != null &&
        !FrameLimiter.shared.shouldDraw(rawTimeStamp)) {
      _skipping = true;
      // El cuadro pendiente sigue "pedido" para el framework; se le pide
      // el próximo vsync directo al motor.
      platformDispatcher.scheduleFrame();
      return;
    }
    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    if (_skipping) {
      _skipping = false;
      return;
    }
    super.handleDrawFrame();
  }
}
