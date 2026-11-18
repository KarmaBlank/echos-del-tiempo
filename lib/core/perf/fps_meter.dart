import 'dart:collection';

/// Cuadros por segundo a partir de la hora de cada cuadro dibujado
/// (docs/specs/settings.md § 3.9). Puro: no sabe de Flutter.
///
/// Guarda los cuadros de la última [window] (hacia atrás desde el más
/// nuevo) y da `intervalos ÷ su suma`, contando solo los intervalos
/// menores que [maxGap]: si la app no redibujó por un rato (un menú
/// quieto), esa pausa no baja el número.
class FpsMeter {
  FpsMeter({
    this.window = const Duration(seconds: 1),
    this.maxGap = const Duration(milliseconds: 100),
  });

  final Duration window;
  final Duration maxGap;

  final _times = Queue<int>();

  /// Último valor calculado (se mantiene si la ventana queda sin
  /// intervalos válidos). `null` = nunca hubo dos cuadros seguidos.
  double? _fps;

  /// FPS suavizados en ~[window]; `null` sin datos.
  double? get fps => _fps;

  /// Suma un cuadro dibujado a la hora [micros] (µs, en orden; uno fuera
  /// de orden se ignora).
  void addFrame(int micros) {
    if (_times.isNotEmpty && micros < _times.last) return;
    _times.addLast(micros);
    final from = micros - window.inMicroseconds;
    while (_times.length > 1 && _times.first < from) {
      _times.removeFirst();
    }
    _recompute();
  }

  /// Varios cuadros de una vez (como llegan los `FrameTiming`).
  void addFrames(Iterable<int> micros) {
    for (final t in micros) {
      addFrame(t);
    }
  }

  void _recompute() {
    var n = 0;
    var sum = 0;
    int? prev;
    final gap = maxGap.inMicroseconds;
    for (final t in _times) {
      if (prev != null) {
        final d = t - prev;
        if (d > 0 && d < gap) {
          n++;
          sum += d;
        }
      }
      prev = t;
    }
    if (n > 0) _fps = n * 1e6 / sum;
  }

  /// Olvida todo.
  void reset() {
    _times.clear();
    _fps = null;
  }
}
