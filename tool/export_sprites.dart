// Exporta los sprites pixel art del prototipo `ecos-del-tiempo.html` a PNG.
//
// Uso (desde la raíz del proyecto, con el `dart` del SDK de Flutter):
//
//   dart run tool/export_sprites.dart
//
// Es un puerto 1:1 de `HERO`, `SPR`, `shade` y `makeSprite` del prototipo
// (ver docs/specs/sprites.md). Escribe un PNG por sprite, 1 píxel por
// píxel, con un codificador PNG propio (zlib de dart:io + CRC32): sin
// paquetes externos.
import 'dart:io';
import 'dart:typed_data';

// ================= DATOS (copiados del prototipo) =================

/// `HERO`: grilla del héroe, la misma para todas las clases.
const List<String> heroRows = [
  '....HHHH....', '...HHHHHH...', '..HHSSSSHH..', '..HSOSSOSH..',
  '...SSSSSS...', '....SSSS....', '..BBBBBBBB..', '.SBBBBBBBBS.',
  '.SBBBBBBBBS.', '.S.BBBBBB.S.', '...BBBBBB...', '...LL..LL...',
  '...LL..LL...', '...LL..LL...', '..DDD..DDD..', '............',
];

/// `SPR`: grillas base de enemigos (`X` = color del enemigo).
const Map<String, List<String>> enemyBaseRows = {
  'slime': [
    '................', '......XXXX......', '....XXXXXXXX....',
    '...XXXXXXXXXX...', '..XXXWWXXXWWXX..', '..XXXOWXXXOWXX..',
    '.XXXXXXXXXXXXXX.', '.XXXXXXXXXXXXXX.', 'XXXXXXXXXXXXXXXX',
    'XXXXXXXXXXXXXXXX', '.XXXXXXXXXXXXXX.', '..XXXXXXXXXXXX..',
  ],
  'bat': [
    'XX............XX', 'XXX..X....X..XXX', 'XXXX.XXXXXX.XXXX',
    'XXXXXXXXXXXXXXXX', '.XXXXXWXXWXXXXX.', '..XXXXOXXOXXXX..',
    '...XX.XXXX.XX...', '......XXXX......', '.......XX.......',
    '................',
  ],
  'golem': [
    '....XXXXXXXX....', '...XXXXXXXXXX...', '...XXRRXXRRXX...',
    '...XXXXXXXXXX...', '.XXXXXXXXXXXXXX.', 'XXXXXXXXXXXXXXXX',
    'XXX.XXXXXXXX.XXX', 'XXX.XXXXXXXX.XXX', 'XXX.XXXXXXXX.XXX',
    'XX..XXXXXXXX..XX', '....XXXXXXXX....', '....XXX..XXX....',
    '....XXX..XXX....', '...XXXX..XXXX...', '...XXXX..XXXX...',
  ],
  'ghost': [
    '.....XXXX.....', '...XXXXXXXX...', '..XXXXXXXXXX..',
    '.XXXOOXXOOXXX.', '.XXXOOXXOOXXX.', '.XXXXXXXXXXXX.',
    'XXXXXXOOXXXXXX', 'XXXXXXXXXXXXXX', 'XXXXXXXXXXXXXX',
    'XXXXXXXXXXXXXX', 'XXXXXXXXXXXXXX', '.XXXXXXXXXXXX.',
    '.XX.XXX.XXX.X.', '..X..X...X....',
  ],
};

/// `CLASSES[...].pal`: paletas de héroe por clase.
const Map<String, Map<String, String>> heroPalettes = {
  'guerrero': {'H': '#6b3a1e', 'S': '#f2c29b', 'O': '#1b1b1b', 'B': '#c0392b', 'L': '#3b2f2f', 'D': '#5a3d1e'},
  'maga': {'H': '#9b59b6', 'S': '#f2c29b', 'O': '#1b1b1b', 'B': '#2e5aac', 'L': '#24478a', 'D': '#3b2a55'},
  'paladin': {'H': '#d4af37', 'S': '#f2c29b', 'O': '#1b1b1b', 'B': '#bdc3c7', 'L': '#34495e', 'D': '#7f8c8d'},
  'tirador': {'H': '#f1c40f', 'S': '#f2c29b', 'O': '#1b1b1b', 'B': '#27ae60', 'L': '#34495e', 'D': '#2c3e50'},
};

/// Datos visuales de `EN`: sprite base (`spr`) y color (`col`).
/// La escala (`sc`) vive en el manifest, no en el PNG.
const Map<String, ({String spr, String col})> enemyLooks = {
  'slime': (spr: 'slime', col: '#4cd137'),
  'bat': (spr: 'bat', col: '#8e44ad'),
  'golem': (spr: 'golem', col: '#95a5a6'),
  'ghost': (spr: 'ghost', col: '#a29bfe'),
  'reyLimo': (spr: 'slime', col: '#e1b12c'),
  'golemReloj': (spr: 'golem', col: '#d4a017'),
  'devorador': (spr: 'ghost', col: '#e84393'),
};

/// Color del contorno que agrega `makeSprite`.
const String outlineColor = '#0d0d14';

/// Paleta de `enSpr`: `{X: col, W: '#ffffff', O: '#111', R: '#ff3b3b'}`.
Map<String, String> enemyPalette(String enemyId) => {
      'X': enemyLooks[enemyId]!.col,
      'W': '#ffffff',
      'O': '#111',
      'R': '#ff3b3b',
    };

// ================= LÓGICA DE PÍXELES =================

/// Imagen RGBA de 8 bits por canal, fila por fila.
class RgbaImage {
  RgbaImage(this.width, this.height) : pixels = Uint8List(width * height * 4);

  final int width;
  final int height;
  final Uint8List pixels;

  /// Color del píxel como `0xRRGGBBAA`.
  int rgbaAt(int x, int y) {
    final o = (y * width + x) * 4;
    return (pixels[o] << 24) | (pixels[o + 1] << 16) | (pixels[o + 2] << 8) | pixels[o + 3];
  }

  void _setOpaque(int x, int y, int rgb) {
    final o = (y * width + x) * 4;
    pixels[o] = (rgb >> 16) & 0xff;
    pixels[o + 1] = (rgb >> 8) & 0xff;
    pixels[o + 2] = rgb & 0xff;
    pixels[o + 3] = 0xff;
  }
}

/// `Math.round` de JS para valores positivos: `floor(x + 0.5)`.
int _jsRound(double x) => (x + 0.5).floor();

/// Parsea `#rgb` o `#rrggbb` (como CSS) a `0xRRGGBB`.
int parseHex(String hex) {
  var h = hex.substring(1);
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  return int.parse(h, radix: 16);
}

/// Formatea `0xRRGGBB` como `#rrggbb`.
String toHex(int rgb) => '#${rgb.toRadixString(16).padLeft(6, '0')}';

/// Puerto de `shade(hex, f)`: multiplica cada canal, redondea como JS y
/// recorta a [0, 255].
String shade(String hex, double f) {
  final n = parseHex(hex);
  int ch(int c) => _jsRound(c * f).clamp(0, 255);
  final r = ch(n >> 16), g = ch((n >> 8) & 255), b = ch(n & 255);
  return toHex((r << 16) | (g << 8) | b);
}

/// Puerto de `makeSprite(rows, pal)`: contorno `#0d0d14` de 1 px en los 4
/// vecinos ortogonales y sombreado de `X` (abajo ×0.78, dos filas de
/// arriba ×1.2).
RgbaImage makeSprite(List<String> rows, Map<String, String> pal) {
  final cols = rows[0].length;
  for (final r in rows) {
    if (r.length != cols) {
      throw ArgumentError('Todas las filas deben medir $cols: "$r"');
    }
  }
  final img = RgbaImage(cols + 2, rows.length + 2);
  bool filled(int i, int j) =>
      j >= 0 && j < rows.length && i >= 0 && i < cols && rows[j][i] != '.';

  final outline = parseHex(outlineColor);
  for (var j = -1; j <= rows.length; j++) {
    for (var i = -1; i <= cols; i++) {
      if (filled(i, j)) continue;
      if (filled(i - 1, j) || filled(i + 1, j) || filled(i, j - 1) || filled(i, j + 1)) {
        img._setOpaque(i + 1, j + 1, outline);
      }
    }
  }
  for (var j = 0; j < rows.length; j++) {
    for (var i = 0; i < cols; i++) {
      final ch = rows[j][i];
      if (ch == '.') continue;
      var col = pal[ch] ?? '#f0f';
      if (ch == 'X' && j > rows.length * 0.6) col = shade(col, 0.78);
      if (ch == 'X' && j < 2) col = shade(col, 1.2);
      img._setOpaque(i + 1, j + 1, parseHex(col));
    }
  }
  return img;
}

/// Puerto de `heroSpr(cls)`.
RgbaImage heroSprite(String classId) => makeSprite(heroRows, heroPalettes[classId]!);

/// Puerto de `enSpr(ty)`.
RgbaImage enemySprite(String enemyId) =>
    makeSprite(enemyBaseRows[enemyLooks[enemyId]!.spr]!, enemyPalette(enemyId));

// ================= PNG =================

final Uint32List _crcTable = () {
  final t = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();

/// CRC-32 (ISO-HDLC) tal como lo exige PNG.
int crc32(List<int> bytes) {
  var c = 0xffffffff;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}

/// Codifica la imagen como PNG RGBA 8 bits sin entrelazado (filtro 0).
Uint8List encodePng(RgbaImage img) {
  final out = BytesBuilder();
  out.add(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

  void chunk(String type, List<int> data) {
    final body = BytesBuilder()
      ..add(type.codeUnits)
      ..add(data);
    final bytes = body.toBytes();
    out
      ..add(_u32(data.length))
      ..add(bytes)
      ..add(_u32(crc32(bytes)));
  }

  final ihdr = BytesBuilder()
    ..add(_u32(img.width))
    ..add(_u32(img.height))
    ..add(const [8, 6, 0, 0, 0]); // 8 bits, RGBA, deflate, filtro 0, sin entrelazado
  chunk('IHDR', ihdr.toBytes());

  final stride = img.width * 4;
  final raw = Uint8List(img.height * (stride + 1));
  for (var y = 0; y < img.height; y++) {
    raw[y * (stride + 1)] = 0; // tipo de filtro: ninguno
    raw.setRange(y * (stride + 1) + 1, (y + 1) * (stride + 1), img.pixels, y * stride);
  }
  chunk('IDAT', zlib.encode(raw));
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _u32(int v) => [(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];

// ================= EXPORTACIÓN =================

/// Ruta relativa a `assets/sprites/` de cada sprite exportado.
Map<String, RgbaImage> buildAllSprites() => {
      for (final c in heroPalettes.keys) 'characters/$c/idle.png': heroSprite(c),
      for (final e in enemyLooks.keys) 'enemies/$e/idle.png': enemySprite(e),
    };

void main() {
  final root = Directory('assets/sprites');
  if (!root.existsSync()) {
    stderr.writeln('Correlo desde la raíz del proyecto (no existe ${root.path}).');
    exitCode = 1;
    return;
  }
  for (final entry in buildAllSprites().entries) {
    final file = File('${root.path}/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(encodePng(entry.value));
    stdout.writeln('${file.path} (${entry.value.width}x${entry.value.height})');
  }
}
