import 'battle_engine.dart' show RandomSource;

const _mask32 = 0xFFFFFFFF;

/// `Math.imul` de JS: producto de 32 bits con signo. Se parte en mitades
/// de 16 bits para que ningún producto intermedio pase de 2^53 (así da
/// lo mismo en la VM y en web). Devuelve el resultado como entero sin
/// signo de 32 bits (los bits son los mismos que en JS).
int imul32(int a, int b) {
  a &= _mask32;
  b &= _mask32;
  final ah = (a >> 16) & 0xFFFF;
  final al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF;
  final bl = b & 0xFFFF;
  final high = ((ah * bl + al * bh) & 0xFFFF) * 0x10000;
  return (al * bl + high) & _mask32;
}

/// `rng(seed)` del prototipo (mulberry32), bit a bit igual que en JS:
/// misma semilla → misma secuencia en [0, 1). Ver docs/specs/world.md.
///
/// Todo el estado se guarda como entero sin signo de 32 bits; `>>>` de JS
/// equivale a `>>` sobre ese valor, y `|0` a enmascarar con 32 bits.
RandomSource mulberry32(int seed) {
  var s = seed & _mask32;
  return () {
    s = (s + 0x6D2B79F5) & _mask32;
    var t = imul32(s ^ (s >> 15), 1 | s);
    t = ((t + imul32(t ^ (t >> 7), 61 | t)) & _mask32) ^ t;
    return ((t ^ (t >> 14)) & _mask32) / 4294967296;
  };
}
