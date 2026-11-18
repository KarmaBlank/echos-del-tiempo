import 'package:echos_del_tiempo/core/perf/fps_meter.dart';
import 'package:flutter_test/flutter_test.dart';

/// [n] cuadros cada [periodUs] µs desde [from].
List<int> frames(int from, int periodUs, int n) =>
    [for (var i = 0; i < n; i++) from + i * periodUs];

void main() {
  test('sin datos: null; un solo cuadro tampoco alcanza', () {
    final m = FpsMeter();
    expect(m.fps, isNull);
    m.addFrame(1000);
    expect(m.fps, isNull);
  });

  test('60 Hz, 30 Hz y 144 Hz parejos', () {
    final m = FpsMeter()..addFrames(frames(0, 16667, 120));
    expect(m.fps, closeTo(60, 0.1));
    final m30 = FpsMeter()..addFrames(frames(0, 33333, 60));
    expect(m30.fps, closeTo(30, 0.1));
    final m144 = FpsMeter()..addFrames(frames(0, 6944, 300));
    expect(m144.fps, closeTo(144, 0.1));
  });

  test('ventana de ~1 s: un bajón viejo deja de contar', () {
    final m = FpsMeter()
      ..addFrames(frames(0, 33333, 31)) // 1 s a 30
      ..addFrames(frames(1000000 + 16667, 16667, 30)); // ~0.5 s a 60
    // Todavía hay cuadros a 30 dentro de la ventana.
    expect(m.fps, inExclusiveRange(31, 59));
    m.addFrames(frames(1500000 + 16667, 16667, 70)); // > 1 s más a 60
    expect(m.fps, closeTo(60, 0.1));
  });

  test('una pausa sin cuadros (menú quieto) no baja el número', () {
    final m = FpsMeter()
      ..addFrames(frames(0, 16667, 30))
      ..addFrames(frames(3000000, 16667, 10)); // 3 s quieto, después 60
    expect(m.fps, closeTo(60, 0.1));
    // Solo pausas en la ventana: se queda con el último valor.
    m.addFrame(9000000);
    expect(m.fps, closeTo(60, 0.1));
  });

  test('fuera de orden se ignora; reset olvida', () {
    final m = FpsMeter()..addFrames(frames(0, 16667, 10));
    m.addFrame(5);
    expect(m.fps, closeTo(60, 0.1));
    m.reset();
    expect(m.fps, isNull);
  });
}
