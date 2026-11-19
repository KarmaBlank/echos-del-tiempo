import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';

import '../persistence/ecos_log.dart';
import 'frame_stats.dart';

/// Registro de rendimiento para el juego real (docs/specs/exploration.md
/// § "Rendimiento"): mientras el indicador FPS Y PING está prendido,
/// junta los `FrameTiming` de cada cuadro y cada [every] escribe en
/// `ecos.log` una línea con los cuadros por segundo y los percentiles de
/// build (hilo de la UI) y raster (GPU), más lo que agreguen las
/// [probes] (p. ej. la caché de tiles del mapa). Sin temporizadores: se
/// escribe al llegar los cuadros.
class PerfLog {
  PerfLog({this.every = const Duration(seconds: 10), this.sink});

  final Duration every;

  /// Dónde escribe (por defecto `EcosLog.info`; los tests lo cambian).
  final void Function(String line)? sink;

  /// Datos extra por nombre (los registra quien los tiene).
  static final probes = <String, String Function()>{};

  final _build = <int>[], _raster = <int>[], _total = <int>[];
  int? _from;
  bool _on = false;

  /// Líneas escritas (tests).
  int lines = 0;

  void start() {
    if (_on) return;
    _on = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_on) return;
    _on = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _clear();
  }

  void _clear() {
    _build.clear();
    _raster.clear();
    _total.clear();
    _from = null;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      add(t.buildDuration, t.rasterDuration, t.totalSpan,
          t.timestampInMicroseconds(FramePhase.vsyncStart));
    }
  }

  /// Suma un cuadro (con la hora de su vsync en µs).
  void add(Duration build, Duration raster, Duration total, int vsyncUs) {
    final from = _from ??= vsyncUs;
    _build.add(build.inMicroseconds);
    _raster.add(raster.inMicroseconds);
    _total.add(total.inMicroseconds);
    final span = vsyncUs - from;
    if (span >= every.inMicroseconds) {
      _flush(span);
      _clear();
    }
  }

  void _flush(int spanUs) {
    final n = _build.length;
    final fps = spanUs <= 0 ? 0 : n * 1e6 / spanUs;
    final extra = [
      for (final e in probes.entries) '${e.key}: ${e.value()}',
    ];
    final line = 'Rendimiento: $n cuadros (${fps.toStringAsFixed(1)} fps)'
        ' · build ${FrameStats(_build).summary}'
        ' · raster ${FrameStats(_raster).summary}'
        ' · total ${FrameStats(_total).summary}'
        '${extra.isEmpty ? '' : ' · ${extra.join(' · ')}'}';
    lines++;
    (sink ?? EcosLog.info)(line);
  }
}
