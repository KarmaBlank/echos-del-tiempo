import 'dart:math' as math;

/// Percentiles de una lista de duraciones (µs), para el registro de
/// rendimiento y el arnés de pruebas (docs/specs/exploration.md §
/// "Rendimiento").
class FrameStats {
  FrameStats(Iterable<int> micros) : _sorted = List.of(micros)..sort();

  final List<int> _sorted;

  int get count => _sorted.length;

  /// Percentil [p] (0..100) en ms (`0` sin datos; vecino más cercano).
  double pct(double p) {
    if (_sorted.isEmpty) return 0;
    final i = ((p / 100) * (_sorted.length - 1)).round();
    return _sorted[math.min(_sorted.length - 1, math.max(0, i))] / 1000;
  }

  double get p50 => pct(50);
  double get p90 => pct(90);
  double get p99 => pct(99);
  double get max => _sorted.isEmpty ? 0 : _sorted.last / 1000;

  /// Promedio en ms.
  double get mean => _sorted.isEmpty
      ? 0
      : _sorted.fold<int>(0, (a, b) => a + b) / _sorted.length / 1000;

  static String _f(double ms) => ms.toStringAsFixed(2);

  /// `p50 1.20 · p90 2.31 · p99 4.00 · máx 5.12 ms`.
  String get summary =>
      'p50 ${_f(p50)} · p90 ${_f(p90)} · p99 ${_f(p99)} · máx ${_f(max)} ms';
}
