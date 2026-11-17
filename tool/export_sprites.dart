// Exporta los sprites pixel art del prototipo `ecos-del-tiempo.html` a PNG.
//
// Uso (desde la raíz del proyecto, con el `dart` del SDK de Flutter):
//
//   dart run tool/export_sprites.dart
//
// Es un puerto 1:1 de `HERO`, `SPR`, `shade` y `makeSprite` del prototipo
// (ver docs/specs/sprites.md), más los enemigos de v0.2 dibujados con el
// mismo pipeline. Escribe un PNG por sprite, 1 píxel por
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

/// `SPR`: grillas base de enemigos (`X` = color del enemigo). Las de v0.2
/// usan además letras propias (ver [enemyExtraPalettes]).
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

  // ---- v0.2 (Bosque Hondo / Picos Helados / Ruinas): arte propio, no
  // está en el prototipo. Mismo pipeline; colores extra en
  // `enemyExtraPalettes`.
  // Araña del Bosque Hondo: patas en arco, ojos R, colmillos G.
  'arana': [
    '..................',
    '.........XXXXXX...',
    '........XXXAXAXX..',
    '.......XXXXXAXXXX.',
    '..D....XXXXXAXXXX.',
    '.D.D...XXXXAXAXXX.',
    '.D..DXXXXXXXXXXXX.',
    'D...RXRXXXXXXXXXD.',
    '..DRXRXXXXXXXXX.D.',
    '.D..XXXXXX...DD.D.',
    '.D...XXXXDDD..D..D',
    'D...GDG.....D..D.D',
    'D..DG.......D..D.D',
  ],
  // Lobo de perfil mirando a la izquierda: orejas, cola, colmillos W, ojo E.
  'lobo': [
    '...X.X............',
    '...XXXX...........',
    '..XXEXXX.........X',
    'XXXXXXXXX.......XX',
    'OXXXXXXXXXXXXXXXX.',
    '.WLWLXXXXXXXXXXXX.',
    '...LLLXXXXXXXXXX..',
    '....LXXXXXXXXXXX..',
    '....XXDDX..XXDDX..',
    '....XX.DD..XX.DD..',
    '....XX.DD..XX.DD..',
    '...XX..DD.XX..DD..',
  ],
  // Murciélago de hielo: puntas L escarchadas, colmillos de carámbano W.
  'murcielagoHielo': [
    'L................L',
    'LL......DD......LL',
    'LXX....DDDD....XXL',
    '.XXX..DDDDDD..XXX.',
    '.XXXXXDEDDEDXXXXX.',
    '.XXXXXDDDDDDXXXXX.',
    '..XXXXXDDDDXXXXX..',
    '..XLXXXWDDWXXXLX..',
    '...L.LX.W..W.XL.L.',
    '.....L.......L....',
  ],
  // Elemental de escarcha: cuerpo de cristal macizo, núcleo W/A.
  'elementalEscarcha': [
    '..L....LL....L..',
    '.LL..XXXXXX..LL.',
    '.LXL.XWXXWX.LXL.',
    'LXXXLXXXXXXLXXXL',
    'LXXXXDXXXXDXXXXL',
    'XXXX.XXAAXX.XXXX',
    'XXXX.XAWWAX.XXXX',
    'DXXD.XAWWAX.DXXD',
    'DXXD.XXAAXX.DXXD',
    '.DD..XXXXXX..DD.',
    '.DD..DXXXXD..DD.',
    '....XXX..XXX....',
    '....XXX..XXX....',
    '...DXXD..DXXD...',
    '...DDDD..DDDD...',
  ],
  // Esqueleto guerrero: cuencas O con pupila R, espada oxidada S/T.
  'esqueleto': [
    '..S..XXXX......',
    '..S.XXXXXX.....',
    '..T.OOXOOX.....',
    '..S.ORXORX.....',
    '..S..XDXDX.....',
    '..T...XX.......',
    '..S.XXXXXXX....',
    '..SXXDXDXDXX...',
    '..SX.XDXDX.X...',
    '.HHHXXDXDX..X..',
    '..H...XXX...X..',
    '..H..XX.XX.....',
    '.....X...X.....',
    '.....D...D.....',
    '.....X...X.....',
    '....XX...XX....',
  ],
  // Caballero caído: escudo torre D/L, visor G, capa rota P.
  'caballeroCaido': [
    '......XXXX......',
    '.....XXXXXX.....',
    '.....GGGXXX.....',
    '.....XXXXXX.....',
    '..LLLLXXXXXXPP..',
    '.LDDDDLXXXXXPPP.',
    '.LDDDDLXXXXXXPP.',
    '.LDLLDLXXXXXXPPP',
    '.LDLLDLDXXDXXPP.',
    '.LDDDDLXXXXXXPPP',
    '.LDDDDLXXXDX.P.P',
    '.LDDDDLXX.XX.P..',
    '..LDDL.XX.XX....',
    '...LL..XX.XX....',
    '......XXX.XXX...',
  ],
  // Cristal de hielo (add): esquirla facetada con núcleo W.
  'cristalHielo': [
    '....L....',
    '...LXD...',
    '...LXD...',
    '..LXXDD..',
    '..LXXXD..',
    '..LXAXD..',
    '.LXAWADD.',
    '.LXAWADD.',
    '.LXXAXDD.',
    '.LXXXXDD.',
    '..LXXXD..',
    '.D.LXD.D.',
    'DDDDDDDDD',
  ],
  // Jefa Matriarca Araña: reloj de arena R, corona C, patas K.
  'matriarca': [
    '.............XXXRRRRRX......',
    '...........XXXXXXRRRXXXX....',
    '..........XXAXXXXXRXXXAXX...',
    '..........XXXXXXXRRRXXXXX...',
    '...A.....XXXXXXXRRRRRXXXXX..',
    '..K.K..C.CXCXXXXXXXXXXXXXX..',
    '..K..K.CCCCCXXXXXXXXXXXAXX..',
    '.K...K...XDDDXXXXXXXXXXXXX..',
    '.K....R.RXRXXXAXXXXXAXXXXKA.',
    '..AK...RXRXXXXXXXXXXXXXXX.K.',
    '..K.KKDXXXXXXXXXDXXXXXXX..K.',
    '..K...XXXXXXXXXXXXXXDDDD..K.',
    '.K....DXXDXXXXXXDDDDDDD...K.',
    '.K...AWXXWXXXXXX......K....K',
    '.K...KG.DGXXXXD.KK.....K...K',
    '.K...KG...DDD.....K....K...K',
    'K...K.G..K........K....K...K',
    'K...K....K.........K....K..K',
    'K...K....K.........K....K..K',
  ],
  // Jefa Sierpe de Escarcha: anillos enroscados, crin L, aliento L.
  'sierpe': [
    '............L...........',
    '...........L.L..L.......',
    '......XXXX.XXXXL....L...',
    '..XXXOEXXXXXXXXXXX.L....',
    'L.XXXXXXXXXXXXXXXXXX..L.',
    '.DWDWDXXXXXXBBXXXXXXXL..',
    'L.XXXXXXXX....BBBXXXX...',
    '................BBXXX.LL',
    '.L...............BXXX...',
    '................BXXXX...',
    '..........BBBBBBXXXX..L.',
    '.........XXXXXXBXXXX....',
    '.........DDDDDBBXXX.....',
    '......XBBBBBBBBBBBBBX..L',
    '.....XXXXXXXXXXXBXXXXX..',
    '.....DDDDDDDDDDDDDDDDD..',
    '...XBBBBBBBBBBBBBBBBBBX.',
    '..XXXXXXXXXXXXXXXXXXXXXX',
    'XXXXXXXXXXXXXXXXXXXXXXXX',
    'XDDDDDDDDDDDDDDDDDDDDDD.',
  ],
  // Jefe Caballero Hueco: yelmo vacío con ojos E, espada S y escudo Y.
  'caballeroHueco': [
    '..S..Y..XXXXX..Y......',
    '..SS.YYXXXXXXXYY......',
    '..SS..XYYYYYYYX.......',
    '..SS..XDDDDDDDX.......',
    '..SS..XDEDEDDDX.......',
    '..SS..XXDDDDDXX.......',
    '..SS.PPXXXXXXXPPPP....',
    '..SSPYYYXXXXXYYYPPP...',
    '..SSYXXXXXXXXXXXYPP...',
    '.YYYYYXXXXXXXXDDDDDD..',
    '..XDXPXXXXXXXXDYYYYD..',
    '..XDXPXXXXXXXXDYDDYD..',
    '...YPPXXXXXXXXDYDDYDP.',
    '..PPPPYYYYYYYYDYYYYDP.',
    '..PPPPXXXXPPXXDDYYDDP.',
    '..PPPPXXXXPPXXXDDDDPPP',
    '..PPPPXXXPPPPXXXDDPPPP',
    '..P.PPXXXPPPPXXX.PP.PP',
    '..P..PXXXPPPPXXX..P..P',
    '.....PXXX....XXX.P....',
    '.....DDDD....DDDD.....',
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
  // v0.2: cada uno con su propia forma base.
  'arana': (spr: 'arana', col: '#6a3d66'),
  'lobo': (spr: 'lobo', col: '#7f8fa6'),
  'murcielagoHielo': (spr: 'murcielagoHielo', col: '#9fe3f0'),
  'elementalEscarcha': (spr: 'elementalEscarcha', col: '#6cb4e4'),
  'esqueleto': (spr: 'esqueleto', col: '#e8e2cf'),
  'caballeroCaido': (spr: 'caballeroCaido', col: '#5d6673'),
  'cristalHielo': (spr: 'cristalHielo', col: '#86d8ff'),
  'matriarca': (spr: 'matriarca', col: '#4e2b55'),
  'sierpe': (spr: 'sierpe', col: '#4fb9d8'),
  'caballeroHueco': (spr: 'caballeroHueco', col: '#4a4f5a'),
};

/// Color del contorno que agrega `makeSprite`.
const String outlineColor = '#0d0d14';

/// Colores extra por enemigo (además de X/W/O/R), para el arte v0.2.
/// Solo `X` recibe brillo/sombra en `makeSprite`; estos se pintan planos.
const Map<String, Map<String, String>> enemyExtraPalettes = {
  'arana': {'D': '#5c4033', 'A': '#a8679a', 'G': '#7bed3f'},
  'lobo': {'D': '#4b5568', 'L': '#d2dae2', 'E': '#f9ca24'},
  'murcielagoHielo': {'D': '#3f8fb3', 'L': '#f4fdff', 'E': '#0b2e59'},
  'elementalEscarcha': {'D': '#2c6aa0', 'L': '#d4f1ff', 'A': '#9ff3ff'},
  'esqueleto': {'D': '#9c9583', 'S': '#a39c90', 'T': '#b5562a', 'H': '#5a3d22'},
  'caballeroCaido': {'D': '#2f3540', 'L': '#9aa5b1', 'P': '#6c3483', 'G': '#9effd8'},
  'cristalHielo': {'D': '#2e6fb5', 'L': '#f2fdff', 'A': '#c4f1ff'},
  'matriarca': {'D': '#2e1834', 'K': '#6e4a7c', 'A': '#9a5fa8', 'G': '#7bed3f', 'C': '#e0c068'},
  'sierpe': {'D': '#1f4f8a', 'B': '#b5ecf5', 'L': '#e8fbff', 'E': '#f6e58d'},
  'caballeroHueco': {'D': '#22252c', 'Y': '#b8963e', 'E': '#6ff7ff', 'P': '#4a3550', 'S': '#c8d0d8'},
};

/// Paleta de `enSpr`: `{X: col, W: '#ffffff', O: '#111', R: '#ff3b3b'}`,
/// más los colores extra de [enemyExtraPalettes] si el enemigo los tiene.
Map<String, String> enemyPalette(String enemyId) => {
      'X': enemyLooks[enemyId]!.col,
      'W': '#ffffff',
      'O': '#111',
      'R': '#ff3b3b',
      ...?enemyExtraPalettes[enemyId],
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
