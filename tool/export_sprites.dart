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
import 'dart:math' as math;
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

  // ---- v0.3 (zonas 6–10, docs/specs/bosses.md § "v0.3"): arte propio. ----
  // Eco Sombrío: silueta sombría con ojos W y estela A.
  'ecoSombra': [
    '......XXXX......',
    '.....XXXXXX.....',
    '....XWXXWXXX....',
    '....XXXXXXXX....',
    '.....XXXXXX.....',
    '...AXXXXXXXXA...',
    '..AXXXXXXXXXXA..',
    '.AX.XXXXXXXX.XA.',
    '.A..XXXXXXXX..A.',
    '....XXXXXXXXX...',
    '.....XXXXXXXXA..',
    '......XXXXXXXAA.',
    '.......AXXXAAAA.',
    '.........AAA..A.',
  ],
  // Guardián del Reloj: constructo de bronce con esfera C y agujas O.
  'guardianReloj': [
    '.....XXXXXX.....',
    '....XDDDDDDX....',
    '....XDRDDRDX....',
    '....XXXXXXXX....',
    '..GXXCCCCCCXXG..',
    '.GGXCCCOCCCCXGG.',
    '..GXCCCOCCCCXG..',
    '..XXCCCOOOCCXX..',
    '..XXCCCCCCCCXX..',
    '..XXXCCCCCCXXX..',
    '..DD.XXXXXX.DD..',
    '..DD.XDDDDX.DD..',
    '.....XX..XX.....',
    '.....XX..XX.....',
    '....DDD..DDD....',
  ],
  // Salamandra: lagarto naranja con brasas E en el lomo.
  'salamandra': [
    '.XXXX.....E.E.E...',
    'XWOXXXX..EXEXEXE..',
    'XXXXXXXXXXXXXXXXX.',
    '.RXXXXXXXXXXXXXXXX',
    '..XXDXXXXXXXXDXXXD',
    '...DD.DD...DD.DD.D',
    '...D...D...D...D..',
  ],
  // Gólem de Magma: roca negra con grietas de lava L y núcleo Y.
  'golemMagma': [
    '....XXXXXXXX....',
    '...XXXXLXXXXX...',
    '...XXYYXXYYXX...',
    '...XXXXXXLXXX...',
    '.XXXXLXXXXXXXXX.',
    'XXXXXXLLXXXXLXXX',
    'XXX.XXXYYXXX.XXX',
    'XLX.XXLYYLXX.XLX',
    'XXX.XXXLLXXX.XXX',
    'XX..XXXXXXXX..XX',
    '....XXXLXXXX....',
    '....XXX..XXX....',
    '....XLX..XLX....',
    '...XXXX..XXXX...',
    '...LLLL..LLLL...',
  ],
  // Necrófago: carroñero encorvado, ojos R, garras W, baba G.
  'necrofago': [
    '...XXXX.........',
    '..XXXXXX........',
    '.XRXRXXXXX......',
    '.XXXXXXXXXXX....',
    'OWOWXXXXXXXXXX..',
    '.G..XXXXXXXXXXX.',
    '....DXXXXXXXXXXX',
    '...DD.XXXXXXXXX.',
    '..WD..XXXDXXDX..',
    '..W...XX.DD.DD..',
    '......XX..D..D..',
    '.....DD..DD..DD.',
    '.....WW..WW..WW.',
  ],
  // Alma Errante: llama azul pálida con cara.
  'almaErrante': [
    '......L.......',
    '.....LXL......',
    '....LXXXL..L..',
    '...LXXXXXL.X..',
    '..DXXXXXXXXX..',
    '..XXOXXOXXXXD.',
    '.DXXOXXOXXXXX.',
    '.XXXXXXXXXXXXD',
    '.XXXXOOXXXXXX.',
    '.DXXXXXXXXXXD.',
    '..XXXLLLLXXX..',
    '..DXXLLLLXXD..',
    '...DXXXXXXD...',
    '....D.XX.D....',
    '......D.......',
  ],
  // Vigilante del Vacío: ojo único E, placas P, lanza S.
  'vigilanteVacio': [
    'S...............',
    'S....XXXXX......',
    'S...XXXXXXX.....',
    'S...XPEEPXX.....',
    'S...XXEEXXX.....',
    'S....XXXXX......',
    'SS.PPXXXXXPP....',
    'SXXXXXXXXXXXP...',
    'S..XXPXXXPXXP...',
    'S..XXXXXXXXX....',
    'S..PXXXXXXXP....',
    'S...XXX.XXX.....',
    'S...XX...XX.....',
    'S...XX...XX.....',
    '...PPP...PPP....',
  ],
  // Ojo del Abismo: ojo flotante (iris E, pupila O) con tentáculos T.
  'ojoAbismo': [
    '....XXXXXX....',
    '..XXXXXXXXXX..',
    '.XXWWWWWWWWXX.',
    'XXWWWEEWWWWWXX',
    'XWWWEOOEWWWWWX',
    'XWWWEOOEWWWWWX',
    'XXWWWEEWWWWWXX',
    '.XXWWWWWWWWXX.',
    '..XXXXXXXXXX..',
    '..T.T.TT.T.T..',
    '.T..T.T..T..T.',
    'T...T..T..T..T',
    '...T..T....T..',
  ],
  // Heraldo de las Eras: capucha H, estandarte B, reloj de arena G/S.
  'heraldoEras': [
    '.........G......',
    '.........GBBBB..',
    '....HHH..GBBBBB.',
    '...HHHHH.GBGBBB.',
    '..HHOEOEHGBBBB..',
    '..HHOOOOHG......',
    '...HXXXXGG......',
    '..XXXXXXXG......',
    '.XXGXXXXXG......',
    '.XGSGXXXXG......',
    '.XXGXXXXXG......',
    '.XGSGXXXXG......',
    '..XXXXXXXG......',
    '..XXXXXXXXG.....',
    '.XXXXXXXXXX.....',
    '.XXXXXXXXXXX....',
    'XXXXXXXXXXXX....',
    '.DDD..DDD.......',
  ],
  // Fragmento del Tiempo: cristal de arena dorado con aristas.
  'fragmentoTiempo': [
    '.....L......',
    '....LXD.....',
    '...LXXXD....',
    '..LXXSXXD...',
    '.LXXSSSXXD..',
    'LXXXXSXXXXD.',
    '.LXXXXXXXD..',
    '..LXXSXXD...',
    '...LXSXD...L',
    '..L.LXD...LX',
    '.LX..D...LXD',
    'LXXD.....XD.',
    '.XD.......D.',
  ],
  // Jefa Hechicera del Eco: sombrero H con estrellas Y, bastón T con orbe
  // C, pelo A, ojos E (su eco usa la misma grilla con otra paleta).
  'hechicera': [
    '..........H.........',
    '.........HHH........',
    '........HHYHH.......',
    '.......HHHHHHH......',
    '......HHHYHHHHH.....',
    '....PPPPPPPPPPPPP...',
    '.CC.....SSSSAA......',
    'CWCC...SESSEAAA.....',
    'CCCC...SSSSSAAAA....',
    '.CC.....SSSAAAAA....',
    '..T...PXXXXXPAAA....',
    '..T..XXXXXXXXXAA....',
    '..TSSXXPXXXXXXXA....',
    '..T..XXXXPXXXXXX....',
    '..T..XXXXXPXXXXX....',
    '..T...XXXXXXXXXXX...',
    '..T...XXXXXXXXXXXX..',
    '..T..XXXXXXXXXXXXXX.',
    '..T..XXXXXXXXXXXXXXX',
    '..T.XXXXXXXXXXXXXXXX',
    '..T.PPPPPPPPPPPPPPPP',
  ],
  // Jefa Bestia de Magma: cuadrúpedo de roca, melena de fuego F/Y, lava L.
  'bestiaMagma': [
    '.......F.F..F...............',
    '.....FFYFFYFFF..F...........',
    '....FYFFFYFFYFFFF...........',
    '...FXXXXFFYFFFFFFF..........',
    '..XXXXXXXXFFYFFFFFF.........',
    '.XXYXXXXXXXXFFFFFFFXXXXX....',
    'XXXXXXXXXXXXXXXXXXXXXXXXXX..',
    'XLLLLXXXXXXXXXXLXXXXXXXXXXX.',
    '.YLYLDXXXXXXXLXXXXXXXLXXXXXX',
    '..LL..XXXXXXXXXXXXXXXXXXXXXF',
    '...L..XXXLXXXXXXXXXLXXXXXX.F',
    '......XXXXXXXXXXXXXXXXXXXX.F',
    '......XXXD.DXXXXXXXXD.DXXX..',
    '......XXX...XXX..XXX...XXX..',
    '......XXX...XXX..XXX...XXX..',
    '.....DXXX...XXX..DXXX..XXX..',
    '.....LLLL..LLLL..LLLL.LLLL..',
  ],
  // Jefe Espectro Coronado: corona C con gemas R, ojos E, manto D/M.
  'espectroCoronado': [
    '......C.C.C.C.........',
    '......CCCCCCC.........',
    '......CRCCCRC.........',
    '.....XXXXXXXXX........',
    '....XXXXXXXXXXX.......',
    '....XOEXXOEXXXX.......',
    '....XOOXXOOXXXXX......',
    '....XXXXXXXXXXXXD.....',
    '.....XXXOOXXXXXXDD....',
    '...DDXXXXXXXXXXDDDD...',
    '..DDDDXXXXXXXXDDDDDD..',
    '.XXDDDDDDDDDDDDDDDDDD.',
    'XX.DDDDMDDDDDDMDDDDDD.',
    'X..DDDDDDDDDDDDDDDDDDD',
    '...DDDDDDMDDDDDDDDDDDD',
    '...DDDDDDDDDDDMDDDDDDD',
    '...DDDDDDDDDDDDDDDDDD.',
    '....DDDDDDDDDDDDDDDD..',
    '....DMDD.DDDD.DDD.DD..',
    '....D.D..D.DD..D...D..',
    '.....D...D..D..D......',
  ],
  // Siervo Espectral (invocación): espectro chico con capucha D.
  'siervoEspectral': [
    '...DDDDD....',
    '..DDDDDDD...',
    '.DDXXXXDDD..',
    '.DXEXXEXDD..',
    '.DXXXXXXDD..',
    '.DDXXXXDDDD.',
    'XDDDDDDDDDD.',
    'XXDDDDDDDDDD',
    '..DDDDDDDDDD',
    '..DDDDDDDDD.',
    '..DD.DDD.DD.',
    '..D..D.D..D.',
    '.....D......',
  ],
  // Jefe Centinela del Vacío: coloso de obsidiana, ojo del vacío V/L/W,
  // placas P.
  'centinela': [
    '..........XXXXXX..........',
    '.........XXPPPPXX.........',
    '........XXXXXXXXXX........',
    '........XXLVVVLXXX........',
    '........XLVVWVVLXX........',
    '........XXLVVVLXXX........',
    '.........XXXXXXXX.........',
    '..PP...PPPXXXXXXPPP...PP..',
    '.PPPP.PPXXXXXXXXXXPP.PPPP.',
    'PPPPPPPXXXXLLXXXXXXPPPPPPP',
    '.PPPP.XXXXLVVLXXXXXX.PPPP.',
    '..PP..XXXXXLLXXXXXXX..PP..',
    '...P..XXXXXXXXXXXXXX..P...',
    '......XXPXXXXXXXXPXX......',
    '......XXXXXXXXXXXXXX......',
    '.......XXXXXXXXXXXX.......',
    '.......XXXX....XXXX.......',
    '.......XXXX....XXXX.......',
    '.......XXXX....XXXX.......',
    '......PPPPP....PPPPP......',
    '......DDDDD....DDDDD......',
  ],
  // Devorador de Eras, fase 2: cuernos H, ojos E, fauces con dientes W y
  // núcleo C/Y.
  'devoradorFase2': [
    'HH..................HH',
    '.HH................HH.',
    '..HH...XXXXXXXX...HH..',
    '...HHXXXXXXXXXXXXHH...',
    '....XXEXXEXXEXXEXX....',
    '...XXXXXXXXXXXXXXXX...',
    '..XXEXXXXXXXXXXXXEXX..',
    '..XXXXWDWDWDWDWDWXXX..',
    '.XXXXDDDDDDDDDDDDDXXX.',
    '.XXXDDDDDCCCCDDDDDDXX.',
    'XXXXDDDDCCYYCCDDDDDXXX',
    'XXXXDDDDCCYYCCDDDDDXXX',
    '.XXXDDDDDCCCCDDDDDDXX.',
    '.XXXXDDDDDDDDDDDDDXXX.',
    '..XXXXWDWDWDWDWDWXXX..',
    '..XXXXXXXXXXXXXXXXXX..',
    '...XXX.XXXXXXXX.XXX...',
    '..XX..XX.XXXX.XX..XX..',
    '.X...X...X..X...X...X.',
    'X...X....X..X....X...X',
  ],
  // v0.8 · Jefe secreto del Abismo, Eco Primordial (abyss_bosses.md): una
  // silueta del vacío X con un núcleo C y cinco orbes de elemento que la
  // rodean (F fuego, A agua, E electro, H hielo, V veneno), ojos W y
  // grietas de luz L.
  'ecoPrimordial': [
    '...........FF...........',
    '..........FFFF..........',
    '...AA......FF......EE...',
    '..AAAA.....XX.....EEEE..',
    '...AA....XXXXXX....EE...',
    '........XXXXXXXX........',
    '.......XXWXXXXWXX.......',
    '.......XXXXXXXXXX.......',
    '......XXXLXXXXLXXX......',
    '.....XXXXXXCCXXXXXX.....',
    '....XXXXXXCCCCXXXXXX....',
    '...XXXLXXCCYYCCXXLXXX...',
    '...XXXXXXCCYYCCXXXXXX...',
    '....XXXXXXCCCCXXXXXX....',
    '.....XXXXXXCCXXXXXX.....',
    '..HH..XXXLXXXXLXXX..VV..',
    '.HHHH..XXXXXXXXXX..VVVV.',
    '..HH...XXX.XX.XXX...VV..',
    '.......XX..XX..XX.......',
    '......XX...XX...XX......',
    '.....X....X..X....X.....',
    '....X....X....X....X....',
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
  // v0.3 (zonas 6–10).
  'ecoSombra': (spr: 'ecoSombra', col: '#3d2b5a'),
  'guardianReloj': (spr: 'guardianReloj', col: '#b08d57'),
  'hechicera': (spr: 'hechicera', col: '#6c3fa0'),
  'ecoHechicera': (spr: 'hechicera', col: '#7fd8e8'),
  'salamandra': (spr: 'salamandra', col: '#e67e22'),
  'golemMagma': (spr: 'golemMagma', col: '#3b3b3b'),
  'bestiaMagma': (spr: 'bestiaMagma', col: '#4a3b35'),
  'necrofago': (spr: 'necrofago', col: '#7d8f69'),
  'almaErrante': (spr: 'almaErrante', col: '#a8d8ff'),
  'espectroCoronado': (spr: 'espectroCoronado', col: '#8fa3c7'),
  'siervoEspectral': (spr: 'siervoEspectral', col: '#7d8db0'),
  'vigilanteVacio': (spr: 'vigilanteVacio', col: '#4b3a78'),
  'ojoAbismo': (spr: 'ojoAbismo', col: '#2d1b4e'),
  'centinela': (spr: 'centinela', col: '#2c2f3a'),
  'heraldoEras': (spr: 'heraldoEras', col: '#5a2a3a'),
  'fragmentoTiempo': (spr: 'fragmentoTiempo', col: '#d4a017'),
  // Devorador transformado (fase 2): no es un tipo de enemigo, es el
  // sprite que usa la escena con `Combatant.phase == 2`.
  'devoradorFase2': (spr: 'devoradorFase2', col: '#a3123a'),
  // v0.8 · Jefes del Abismo (abyss_bosses.md): la forma del jefe base con
  // una paleta del vacío; el secreto, arte propio.
  'golemAbismo': (spr: 'golem', col: '#4b3a78'),
  'hechiceraAbismo': (spr: 'hechicera', col: '#2a1a4a'),
  'ecoAbismo': (spr: 'hechicera', col: '#b8a6ff'),
  'espectroAbismo': (spr: 'espectroCoronado', col: '#5a4f8a'),
  'devoradorAbismo': (spr: 'ghost', col: '#6b2fb0'),
  'devoradorAbismoFase2': (spr: 'devoradorFase2', col: '#3a0f5a'),
  'ecoPrimordial': (spr: 'ecoPrimordial', col: '#1a1230'),
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
  // v0.3.
  'ecoSombra': {'A': '#7a5cc0'},
  'guardianReloj': {'D': '#5e4a2c', 'C': '#f5f0dc', 'G': '#e1b12c'},
  'hechicera': {'H': '#3a1f5c', 'Y': '#f6e58d', 'S': '#f2c29b', 'E': '#6ff7ff', 'C': '#7ff3ff',
      'T': '#8d6e4f', 'A': '#c0c0ff', 'P': '#b48cff'},
  'ecoHechicera': {'H': '#4aa3b8', 'Y': '#e8ffff', 'S': '#cdeff5', 'E': '#ffffff', 'C': '#ffffff',
      'T': '#6fb7c6', 'A': '#e8ffff', 'P': '#d4fbff', 'W': '#9ff3ff'},
  'salamandra': {'E': '#ffd166', 'D': '#8e3b12'},
  'golemMagma': {'L': '#ff7b29', 'Y': '#ffd166'},
  'bestiaMagma': {'F': '#ff7b29', 'Y': '#ffd166', 'L': '#ff5a1f', 'D': '#2a201c'},
  'necrofago': {'D': '#4a5640', 'G': '#a3e048'},
  'almaErrante': {'L': '#e8f6ff', 'D': '#4a7fbf'},
  'espectroCoronado': {'C': '#e1b12c', 'E': '#6ff7ff', 'D': '#2b2d42', 'M': '#4b4f6e'},
  'siervoEspectral': {'D': '#2b2d42', 'E': '#6ff7ff'},
  'vigilanteVacio': {'E': '#d6a2ff', 'S': '#c8d0d8', 'P': '#8a7bc4'},
  'ojoAbismo': {'E': '#ff3b6b', 'T': '#6c5ce7'},
  'centinela': {'P': '#5b5f73', 'V': '#9b59ff', 'L': '#c7a6ff', 'D': '#14161d'},
  'heraldoEras': {'H': '#2b1620', 'G': '#e1b12c', 'S': '#f6e58d', 'B': '#8e44ad', 'E': '#ffd166', 'D': '#2b1620'},
  'fragmentoTiempo': {'L': '#fff3b0', 'D': '#8a6a10', 'S': '#f6e58d'},
  'devoradorFase2': {'H': '#2d1b2e', 'E': '#ffd166', 'D': '#3d0a1f', 'C': '#ff7b29', 'Y': '#fff3b0'},
  // v0.8 · Jefes del Abismo: ojos fríos y luz violeta.
  'hechiceraAbismo': {'H': '#140a2a', 'Y': '#c39bff', 'S': '#8a7bc4', 'E': '#e8ffff', 'C': '#c39bff',
      'T': '#3a2a5a', 'A': '#9b7bff', 'P': '#6c3fa0'},
  'ecoAbismo': {'H': '#6c5ce7', 'Y': '#f2e8ff', 'S': '#d4c8ff', 'E': '#ffffff', 'C': '#ffffff',
      'T': '#8a7bc4', 'A': '#f2e8ff', 'P': '#d4c8ff', 'W': '#c39bff'},
  'espectroAbismo': {'C': '#c39bff', 'E': '#e8ffff', 'D': '#140a2a', 'M': '#2a1f4a'},
  'devoradorAbismoFase2': {'H': '#140a2a', 'E': '#e8ffff', 'D': '#1a0630', 'C': '#c39bff', 'Y': '#ffffff'},
  'ecoPrimordial': {'C': '#c39bff', 'Y': '#ffffff', 'L': '#e8ffff', 'F': '#ff7b29', 'A': '#48dbfb',
      'E': '#ffd166', 'H': '#bff4ff', 'V': '#7bed3f'},
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

// ================= ASCENSIONES (v0.5) =================
//
// Arte propio (no está en el prototipo). Cada ascensión es el héroe de su
// clase transformado: MISMA grilla de 12×16 (PNG 14×18) y mismo ancla que
// `heroRows`, así que el juego cambia el id del sprite 1:1 sin mover
// nada. Las armas siguen siendo overlays en código (WeaponOverlay). Las
// letras base (H/S/O/B/L/D) conservan su rol; las demás son propias de
// cada ascensión (ver docs/specs/sprites.md § "Ascensiones").

/// Grillas de las 8 ascensiones, id = `<clase>_<ascensión>`.
const Map<String, List<String>> ascensionRows = {
  // Berserker: pelo revuelto, ojos rojos E, pintura de guerra K, hombreras
  // M, correas cruzadas K, capa negra desgarrada C.
  'guerrero_berserker': [
    '..H.HH.HH...', '..HHHHHHHH..', '..HHSSSSHH..', '..HSESSESH..',
    '...SKSSKS...', '....SSSS....', '.CMMBRRBMM..', 'CSKBBBBBBKS.',
    'CSBKBBBBKBS.', 'CS.BKBBKB.S.', 'CC.KKRRKK...', 'C..LL..LL...',
    '.C.LL..LL...', 'C..LL..LL...', '..DDD..DDD..', '............',
  ],
  // Señor de la Guerra: yelmo dorado G con penacho P, hombreras Y, capa
  // carmesí C, cuerno de guerra W al cinto.
  'guerrero_senorGuerra': [
    '.....PPP....', '...PGGGGG...', '..GGSSSSGG..', '..GSOSSOSG..',
    '...SSSSSS...', '....SSSS....', '.CYYBBBBYY..', 'CSBBBGGBBBS.',
    'CSBBGBBGBBS.', 'CS.BBGGBB.S.', 'CC.GGYGGGWW.', 'CC.LL..LLW..',
    'C..LL..LL...', 'CC.LL..LL...', '..DDG..DDG..', '............',
  ],
  // Cronomante: capucha H con broche-reloj M, esfera de reloj W/K en el
  // pecho, cinto plateado con oro G, túnica larga hasta los pies.
  'maga_cronomante': [
    '....HHHH....', '...HHMMHH...', '..HHSSSSHH..', '..HSOSSOSH..',
    '..HSSSSSSH..', '...H.SS.H...', '..MBBBBBBM..', '.SBBMWMBBBS.',
    '.SBBWKKBBBS.', '.S.BMWMBB.S.', '...MMGGMM...', '...BBBBBB...',
    '..BBBBBBBB..', '..MBBMMBBM..', '..DDD..DDD..', '............',
  ],
  // Elementalista: pelo de fuego F/Y, túnica tricolor fuego Q / hielo I /
  // veneno V, cinto K con una gema de cada elemento.
  'maga_elementalista': [
    '..F.FY.F....', '...FFFFFF...', '..FFSSSSFF..', '..FSOSSOSF..',
    '...SSSSSS...', '....SSSS....', '..QQQIIVVV..', '.SQQQIIVVVS.',
    '.SQQQIIVVVS.', '.S.QQIIVV.S.', '...KQKIKVK..', '...QQIIVV...',
    '..QQQIIVVV..', '..QQQIIVVV..', '..DDD..DDD..', '............',
  ],
  // Francotirador: capucha y capa K, rifle largo G a la espalda, mira E
  // con destello W sobre el ojo, máscara y correa M.
  'tirador_francotirador': [
    '.G..KKKK....', '.G.KKKKKK...', '.GKKSSSSKK..', '.GKSOSSEWK..',
    '.G.MMMMMMK..', '.GK.MMMM....', '.KKBBBBBBM..', 'KSBMBBBBBBS.',
    'KSBBMBBBBBS.', 'KS.BBMBBB.S.', 'KK.MMMMMM...', 'K..LL..LL...',
    'KK.LL..LL...', 'K..LL..LL...', '..DDD..DDD..', '............',
  ],
  // Trampero: gorro de piel F/U con cola, manto de piel F/U con puntas
  // claras P, pelo ámbar H, correas cruzadas A, cepo T abierto colgando
  // atrás del cinto, polainas de piel U.
  'tirador_trampero': [
    '....FFFF....', '...FUFFUF...', '.UFHSSSSHF..', '.UFSOSSOSF..',
    '.P.SSSSSS...', '....SSSS....', '.PUFUFFUFUP.', '.SBABBBBABS.',
    '.SBBABBABBS.', '.S.BBAABB.S.', 'T.TAAAAAA...', 'TTTLL..LL...',
    '...LL..LL...', '...UU..UU...', '..DDD..DDD..', '............',
  ],
  // Templario: diadema Y con gema R, tabardo blanco W con sol Y/Z,
  // hombreras y cinto dorados G, capa crema C, grebas doradas.
  'paladin_templario': [
    '....HHHH....', '...HYRRYH...', '..HHSSSSHH..', '..HSOSSOSH..',
    '...SSSSSS...', '....SSSS....', '.CGWWWWWWG..', 'CSWWWYYWWWS.',
    'CSWWYZZYWWS.', 'CS.WWYYWW.S.', 'CC.GGGGGG...', 'CC.LL..LL...',
    'C..LL..LL...', 'CC.LL..LL...', '..DDD..DDD..', '............',
  ],
  // Guardián: yelmo cerrado M con cresta N y visor K de ojos E, hombreras
  // anchas P, tabardo azul N con emblema W, brazos y escarpes de placa.
  'paladin_guardian': [
    '....MNNM....', '...MMMMMM...', '..MPPPPPPM..', '..MKEKKEKM..',
    '...MMMMMM...', '....NNNN....', '.PPPBBBBPPP.', 'PPPNBBBBNPPP',
    '.MBBNNNNBBM.', '.M.BNWWNB.M.', '...MMMMMM...', '..MLL..LLM..',
    '...LL..LL...', '...LL..LL...', '.DDDD..DDDD.', '............',
  ],
};

/// Paletas de las ascensiones (mismo formato que [heroPalettes]).
const Map<String, Map<String, String>> ascensionPalettes = {
  'guerrero_berserker': {'H': '#5c1414', 'S': '#e3b08f', 'O': '#1b1b1b', 'E': '#ff2b2b',
      'K': '#1f1520', 'B': '#8b1a1a', 'R': '#ff4d3a', 'C': '#3a1c24', 'M': '#5a5560',
      'L': '#2b1e22', 'D': '#1b1214'},
  'guerrero_senorGuerra': {'P': '#e63946', 'G': '#d4af37', 'Y': '#ffe27a', 'S': '#f2c29b',
      'O': '#1b1b1b', 'B': '#a3162b', 'C': '#7d0f1f', 'W': '#f1e4c3', 'L': '#3b2f2f',
      'D': '#5a3d1e'},
  'maga_cronomante': {'H': '#0e5560', 'M': '#cfd8dc', 'S': '#f2c29b', 'O': '#1b1b1b',
      'B': '#17a2a0', 'W': '#f5fbff', 'K': '#1b2b34', 'G': '#e1b12c', 'D': '#2c3e50'},
  'maga_elementalista': {'F': '#e8432b', 'Y': '#ffd166', 'S': '#f2c29b', 'O': '#1b1b1b',
      'Q': '#f07a1a', 'I': '#3cc8ec', 'V': '#38b24a', 'K': '#2b2440', 'D': '#3b2a55'},
  'tirador_francotirador': {'G': '#5b646a', 'K': '#24382b', 'S': '#f2c29b', 'O': '#1b1b1b',
      'E': '#9ff3ff', 'W': '#ffffff', 'M': '#6b7a80', 'B': '#3b5e45', 'L': '#4a5358',
      'D': '#23282c'},
  'tirador_trampero': {'F': '#8a5a32', 'U': '#4f321b', 'P': '#d9c3a0', 'H': '#e1a03a', 'S': '#f2c29b',
      'O': '#1b1b1b', 'B': '#7a4a26', 'A': '#f0a830', 'T': '#a4adb3', 'L': '#5a3d22',
      'D': '#3b2615'},
  'paladin_templario': {'H': '#ffe9a0', 'Y': '#f1c40f', 'R': '#ff6b3d', 'S': '#f2c29b',
      'O': '#1b1b1b', 'C': '#efe6cf', 'G': '#d4af37', 'W': '#fbf9f2', 'Z': '#ff9f1a',
      'L': '#c8ccd2', 'D': '#b8860b'},
  'paladin_guardian': {'M': '#9aa5b1', 'N': '#2e5aac', 'P': '#dfe6e9', 'K': '#141a24',
      'E': '#6ff7ff', 'B': '#c8d0d8', 'W': '#ffffff', 'L': '#34495e', 'D': '#5d6d7e'},
};

/// Clase base de una ascensión (`guerrero_berserker` → `guerrero`).
String ascensionClass(String ascensionId) => ascensionId.split('_').first;

/// Nombre de la ascensión sin la clase (`guerrero_berserker` → `berserker`).
String ascensionName(String ascensionId) => ascensionId.split('_').last;

/// Sprite `idle` de una ascensión: [makeSprite] con su grilla y paleta.
RgbaImage ascensionSprite(String ascensionId) {
  final rows = ascensionRows[ascensionId]!;
  if (rows.length != heroRows.length || rows[0].length != heroRows[0].length) {
    throw ArgumentError('$ascensionId debe medir como el héroe (12×16)');
  }
  return makeSprite(rows, ascensionPalettes[ascensionId]!);
}

/// Tamaño del overlay de aura (PNG, sin contorno). Se dibuja DETRÁS del
/// héroe en `(-12, -25)` respecto de los pies: centrado en x y con la
/// última fila a la altura de los pies. Píxel del héroe `(px, py)` ↔
/// píxel del aura `(px + 5, py + 8)`.
const int auraWidth = 24, auraHeight = 26;

/// Lienzo de caracteres para dibujar auras con primitivas.
class _AuraCanvas {
  final List<List<String>> _cells =
      List.generate(auraHeight, (_) => List.filled(auraWidth, '.'));

  void dot(int x, int y, String c) {
    if (x >= 0 && x < auraWidth && y >= 0 && y < auraHeight) _cells[y][x] = c;
  }

  void line(int x0, int y0, int x1, int y1, String c) {
    final steps = [(x1 - x0).abs(), (y1 - y0).abs(), 1].reduce((a, b) => a > b ? a : b);
    for (var s = 0; s <= steps; s++) {
      dot(_jsRound(x0 + (x1 - x0) * s / steps), _jsRound(y0 + (y1 - y0) * s / steps), c);
    }
  }

  /// Punto a distancia [r] del centro `(cx, cy)` en el ángulo [deg]
  /// (0° = arriba, sentido horario).
  (int, int) polar(double cx, double cy, double r, double deg) {
    final a = deg * math.pi / 180;
    return (_jsRound(cx + r * math.sin(a)), _jsRound(cy - r * math.cos(a)));
  }

  List<String> rows() => [for (final r in _cells) r.join()];
}

/// Grillas de aura (24×26) por id `aura_<ascensión>`.
final Map<String, List<String>> auraRows = {
  // Llamas rojas que suben por los costados y sobre la cabeza + brasas.
  'aura_berserker': () {
    final c = _AuraCanvas();
    // (x, y de la base, alto)
    const tongues = [
      (2, 24, 6), (3, 20, 8), (4, 14, 5), (5, 8, 4), (8, 6, 4), (11, 5, 5),
      (14, 6, 3), (16, 7, 4), (18, 11, 5), (19, 17, 7), (20, 23, 8), (21, 25, 5),
    ];
    for (final (x, base, h) in tongues) {
      for (var k = 0; k < h; k++) {
        c.dot(x, base - k, k == h - 1 ? 'K' : (k < h ~/ 3 ? 'Y' : 'R'));
      }
    }
    for (final (x, y) in const [(1, 15), (6, 3), (13, 1), (17, 3), (22, 14), (0, 21), (23, 19)]) {
      c.dot(x, y, 'R');
    }
    return c.rows();
  }(),
  // Estandarte carmesí con emblema dorado a la espalda + destellos.
  'aura_senorGuerra': () {
    final c = _AuraCanvas();
    c.line(3, 1, 3, 25, 'G'); // asta
    c.dot(3, 0, 'Y'); // remate
    for (var y = 2; y <= 10; y++) {
      // paño con cola de golondrina hacia atrás (izquierda)
      final tail = y >= 8 ? (y - 7) : 0;
      for (var x = 4; x <= 10 - tail; x++) {
        c.dot(x, y, 'C');
      }
    }
    for (var x = 4; x <= 10; x++) {
      c.dot(x, 2, 'Y'); // ribete
    }
    // emblema: corona simple
    for (final (x, y) in const [(6, 5), (8, 5), (6, 6), (7, 6), (8, 6), (7, 4)]) {
      c.dot(x, y, 'Y');
    }
    for (final (x, y) in const [(20, 6), (22, 12), (19, 19), (1, 18)]) {
      c.dot(x, y, 'Y');
    }
    return c.rows();
  }(),
  // Reloj gigante detrás de la maga (12 marcas en anillo) y dos agujas
  // de reloj flotando sobre la cabeza.
  'aura_cronomante': () {
    final c = _AuraCanvas();
    const cx = 11.5, cy = 14.5;
    for (var h = 0; h < 12; h++) {
      final deg = h * 30.0;
      final big = h % 3 == 0;
      final (x0, y0) = c.polar(cx, cy, big ? 10.0 : 11.0, deg);
      final (x1, y1) = c.polar(cx, cy, 12.0, deg);
      c.line(x0, y0, x1, y1, big ? 'W' : 'T');
    }
    // aguja horaria (diagonal, arriba a la izquierda) con punta de flecha
    c.line(3, 8, 6, 5, 'M');
    for (final (x, y) in const [(6, 4), (7, 4), (7, 5)]) {
      c.dot(x, y, 'T');
    }
    // aguja minutera (horizontal, sobre la cabeza) con punta de flecha
    c.line(10, 4, 15, 4, 'M');
    c.dot(9, 4, 'T');
    for (final (x, y) in const [(15, 3), (16, 4), (15, 5)]) {
      c.dot(x, y, 'T');
    }
    return c.rows();
  }(),
  // Tres orbes elementales orbitando: fuego, hielo, veneno.
  'aura_elementalista': () {
    final c = _AuraCanvas();
    void orb(int x, int y, String rim, String core) {
      for (final (dx, dy) in const [(0, -1), (-1, 0), (1, 0), (0, 1), (0, 0)]) {
        c.dot(x + dx, y + dy, (dx, dy) == (0, 0) ? core : rim);
      }
      c.dot(x - 1, y - 1, 'W');
    }

    orb(3, 10, 'Q', 'Y');
    orb(9, 3, 'I', 'W');
    orb(21, 20, 'V', 'G');
    // estelas
    for (final (x, y, col) in const [
      (4, 13, 'Q'), (5, 15, 'Q'), (12, 3, 'I'), (14, 4, 'I'), (21, 17, 'V'), (21, 23, 'V'),
    ]) {
      c.dot(x, y, col);
    }
    return c.rows();
  }(),
  // Retícula de mira: cuatro esquineros y un destello frente a la mira.
  'aura_francotirador': () {
    final c = _AuraCanvas();
    const l = 1, r = 22, t = 5, b = 24, len = 3;
    for (final (x, y, sx, sy) in const [(l, t, 1, 1), (r, t, -1, 1), (l, b, 1, -1), (r, b, -1, -1)]) {
      c.line(x, y, x + sx * len, y, 'V');
      c.line(x, y, x, y + sy * len, 'V');
    }
    // cruz de la mira en el centro de los bordes
    c.line(11, 2, 11, 4, 'V');
    c.line(12, 2, 12, 4, 'V');
    // destello de 4 puntas a la altura del ojo (ojo en px (8,4) → aura (13,12))
    const gx = 20, gy = 11;
    c.dot(gx, gy, 'W');
    for (final (dx, dy) in const [(0, -1), (0, 1), (-1, 0), (1, 0)]) {
      c.dot(gx + dx, gy + dy, 'E');
    }
    c.dot(gx, gy - 2, 'E');
    c.dot(gx, gy + 2, 'E');
    return c.rows();
  }(),
  // Luciérnagas ámbar y abrojos (púas de cepo) en el suelo a los lados.
  'aura_trampero': () {
    final c = _AuraCanvas();
    for (final (x, y) in const [(2, 9), (21, 7), (4, 17), (19, 14), (7, 4), (16, 3), (22, 19)]) {
      c.dot(x, y, 'A');
    }
    for (final (x, y) in const [(2, 8), (21, 6), (16, 2)]) {
      c.dot(x, y, 'Y');
    }
    // dientes de cepo: zigzag en las dos filas de abajo
    for (var x = 0; x < auraWidth; x++) {
      if (x >= 6 && x <= 17) continue; // bajo el héroe no se ve
      c.dot(x, 25, 'T');
      if (x % 3 == 1) c.dot(x, 24, 'T');
      if (x % 6 == 1) c.dot(x, 23, 'A');
    }
    return c.rows();
  }(),
  // Halo solar detrás de la cabeza: anillo dorado y 8 rayos.
  'aura_templario': () {
    final c = _AuraCanvas();
    const cx = 11.5, cy = 10.5;
    for (var deg = 0; deg < 360; deg += 6) {
      final (x, y) = c.polar(cx, cy, 6.6, deg.toDouble());
      c.dot(x, y, 'Y');
    }
    for (var k = 0; k < 8; k++) {
      final deg = k * 45.0;
      final long = k.isEven;
      final (x0, y0) = c.polar(cx, cy, 8.0, deg);
      final (x1, y1) = c.polar(cx, cy, long ? 11.5 : 9.5, deg);
      c.line(x0, y0, x1, y1, long ? 'W' : 'Y');
    }
    return c.rows();
  }(),
  // Cúpula de escudo: arco doble azul/celeste que envuelve al guardián.
  'aura_guardian': () {
    final c = _AuraCanvas();
    const cx = 11.5, cy = 25.0;
    for (var deg = -90; deg <= 90; deg += 2) {
      final d = deg.toDouble();
      // elipse: radio x 11.5, radio y 24
      final a = d * math.pi / 180;
      final x = _jsRound(cx + 11.4 * math.sin(a)), y = _jsRound(cy - 24.0 * math.cos(a));
      c.dot(x, y, 'N');
      final xi = _jsRound(cx + 10.2 * math.sin(a)), yi = _jsRound(cy - 22.6 * math.cos(a));
      if (deg % 12 == 0) c.dot(xi, yi, 'W');
    }
    return c.rows();
  }(),
};

/// Paletas de aura. Colores planos, sin contorno.
const Map<String, Map<String, String>> auraPalettes = {
  'aura_berserker': {'R': '#ff3b2f', 'Y': '#ffb347', 'K': '#8b0f0f'},
  'aura_senorGuerra': {'G': '#d4af37', 'Y': '#ffe27a', 'C': '#c1121f'},
  'aura_cronomante': {'T': '#3fd6c9', 'M': '#cfd8dc', 'W': '#ffffff'},
  'aura_elementalista': {'Q': '#ff7b29', 'Y': '#ffd166', 'I': '#3cc8ec', 'V': '#38b24a',
      'G': '#b6f56b', 'W': '#ffffff'},
  'aura_francotirador': {'V': '#7bed9f', 'E': '#9ff3ff', 'W': '#ffffff'},
  'aura_trampero': {'A': '#f0a830', 'Y': '#fff3b0', 'T': '#a4adb3'},
  'aura_templario': {'Y': '#f6d365', 'W': '#fffbe6'},
  'aura_guardian': {'N': '#4aa3ff', 'W': '#d6ecff'},
};

/// Overlay de aura: píxeles planos de la paleta, sin contorno ni sombreado.
RgbaImage auraSprite(String auraId) {
  final rows = auraRows[auraId]!, pal = auraPalettes[auraId]!;
  final img = RgbaImage(auraWidth, auraHeight);
  for (var j = 0; j < auraHeight; j++) {
    for (var i = 0; i < auraWidth; i++) {
      final ch = rows[j][i];
      if (ch != '.') img._setOpaque(i, j, parseHex(pal[ch] ?? '#f0f'));
    }
  }
  return img;
}

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
      // v0.5: ascensiones y sus auras, en la carpeta de la clase base (ya
      // listada en pubspec.yaml).
      for (final a in ascensionRows.keys) ...{
        'characters/${ascensionClass(a)}/${ascensionName(a)}.png': ascensionSprite(a),
        'characters/${ascensionClass(a)}/aura_${ascensionName(a)}.png':
            auraSprite('aura_${ascensionName(a)}'),
      },
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
