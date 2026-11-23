import 'dart:typed_data';

/// Niebla de exploración de una mazmorra oscura (lighting.md § 5.4).
///
/// Es solo del cliente y del jugador local: no viaja por la red ni se
/// guarda. Recuerda qué tiles vio el jugador durante la misión en curso
/// (todos los pisos: el atlas los tiene en zonas distintas) y qué tiles
/// están a la vista en este cuadro.
class FogOfWar {
  Object? _key;
  int _w = 0, _h = 0;
  Uint8List _seen = Uint8List(0);

  /// Ventana iluminada del último cuadro.
  int _lx0 = 0, _ly0 = 0, _lw = 0, _lh = 0;
  Uint8List _lit = Uint8List(0);

  /// Hay niebla activa (mazmorra oscura en curso).
  bool get active => _key != null;

  /// Sube cada vez que se descubren tiles nuevos (para cachear el dibujo).
  int version = 0;

  /// Prepara la niebla para la misión [key] en un mapa de [w]×[h] tiles.
  /// Con otra clave (otra misión u otro mapa) se olvida lo explorado.
  void begin(Object key, int w, int h) {
    if (key == _key && w == _w && h == _h) return;
    _key = key;
    _w = w;
    _h = h;
    _seen = Uint8List(w * h);
    _lw = _lh = 0;
    version++;
  }

  /// Olvida todo (fuera de una mazmorra oscura).
  void reset() {
    if (_key == null) return;
    _key = null;
    _w = _h = 0;
    _seen = Uint8List(0);
    _lw = _lh = 0;
    version++;
  }

  /// Marca a la vista los tiles de la ventana [x0, y0, w, h] cuyo brillo
  /// ([lum]) llega a [threshold], y los suma a lo explorado.
  void reveal(int x0, int y0, int w, int h, double Function(int, int) lum,
      double threshold) {
    if (_lit.length < w * h) _lit = Uint8List(w * h);
    _lx0 = x0;
    _ly0 = y0;
    _lw = w;
    _lh = h;
    var grew = false;
    for (var y = 0; y < h; y++) {
      final ty = y0 + y;
      for (var x = 0; x < w; x++) {
        final tx = x0 + x;
        final on = lum(tx, ty) >= threshold;
        _lit[y * w + x] = on ? 1 : 0;
        if (on && tx >= 0 && ty >= 0 && tx < _w && ty < _h) {
          final i = ty * _w + tx;
          if (_seen[i] == 0) {
            _seen[i] = 1;
            grew = true;
          }
        }
      }
    }
    if (grew) version++;
  }

  /// El jugador ya vio el tile alguna vez en esta misión.
  bool explored(int tx, int ty) =>
      tx >= 0 && ty >= 0 && tx < _w && ty < _h && _seen[ty * _w + tx] != 0;

  /// El tile está a la vista (iluminado) en este cuadro.
  bool visible(int tx, int ty) {
    final x = tx - _lx0, y = ty - _ly0;
    return x >= 0 && y >= 0 && x < _lw && y < _lh && _lit[y * _lw + x] != 0;
  }
}
