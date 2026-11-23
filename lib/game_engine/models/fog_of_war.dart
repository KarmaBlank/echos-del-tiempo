import 'dart:convert';
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

  /// Lo explorado de cada mazmorra ya visitada (persistent_dungeons.md
  /// § 2): `"<clave>"` → bits empaquetados en base64 (1 bit por tile).
  /// Las mazmorras de zona tienen semilla fija por mundo, así que volver
  /// a entrar recupera la niebla. Se guarda a disco aparte (`FogStore`).
  final Map<String, String> archive = {};

  static const maxArchive = 48;

  /// Cambió [archive] desde el último guardado.
  bool dirty = false;

  void _stash() {
    final k = _key;
    if (k == null || !_seen.contains(1)) return;
    final enc = pack(_seen, _w, _h);
    if (archive['$k'] != enc) {
      archive
        ..remove('$k')
        ..['$k'] = enc;
      // Tope: las [maxArchive] más recientes (los Ecos no se repiten).
      while (archive.length > maxArchive) {
        archive.remove(archive.keys.first);
      }
      dirty = true;
    }
  }

  /// `w,h,` + base64 de los bits de [seen].
  static String pack(Uint8List seen, int w, int h) {
    final out = Uint8List((seen.length + 7) >> 3);
    for (var i = 0; i < seen.length; i++) {
      if (seen[i] != 0) out[i >> 3] |= 1 << (i & 7);
    }
    return '$w,$h,${base64Encode(out)}';
  }

  /// Lo inverso de [pack]; `null` si no es de un mapa de [w]×[h].
  static Uint8List? unpack(String? raw, int w, int h) {
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 3 || parts[0] != '$w' || parts[1] != '$h') return null;
    try {
      final bits = base64Decode(parts[2]);
      final out = Uint8List(w * h);
      for (var i = 0; i < out.length; i++) {
        if ((i >> 3) < bits.length && bits[i >> 3] & (1 << (i & 7)) != 0) {
          out[i] = 1;
        }
      }
      return out;
    } on FormatException {
      return null;
    }
  }

  /// Prepara la niebla para la misión [key] en un mapa de [w]×[h] tiles.
  /// Con otra clave se guarda lo explorado en [archive] y se recupera lo
  /// de [key] si ya estuvo ahí.
  void begin(Object key, int w, int h) {
    if (key == _key && w == _w && h == _h) return;
    _stash();
    _key = key;
    _w = w;
    _h = h;
    _seen = unpack(archive['$key'], w, h) ?? Uint8List(w * h);
    _lw = _lh = 0;
    version++;
  }

  /// Olvida todo (fuera de una mazmorra oscura).
  void reset() {
    if (_key == null) return;
    _stash();
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
