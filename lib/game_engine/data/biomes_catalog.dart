// Mapa de viaje y exteriores de bioma (docs/specs/overworld_biomes.md).
// Datos puros: los lee `MapGenerator.bosque` y `BiomeRules`; la UI solo
// los muestra.

import '../models/game_map.dart';

/// Un lugar del mapa de viaje: el pueblo o el exterior de un bioma.
class BiomeDef {
  const BiomeDef(this.id, this.name, this.blurb,
      {this.open = false, this.zones = const []});

  /// `pueblo`, `bosque`, … (el pueblo es el lugar `null` de la sala).
  final String id;
  final String name;

  /// Una línea para el mapa de viaje.
  final String blurb;

  /// Se puede viajar (los demás se ven en gris: "Próximamente").
  final bool open;

  /// Zonas (mazmorras) cuyas entradas están en este exterior.
  final List<int> zones;
}

/// El pueblo en el mapa de viaje.
const kPueblo = 'pueblo';

/// El exterior del Bosque (primer bioma, v0.26.0).
const kBosque = 'bosque';

/// Orden del mapa de viaje (de izquierda a derecha).
const kBiomes = <BiomeDef>[
  BiomeDef(kPueblo, 'PUEBLO',
      'El claro con la fuente rúnica: comerciante, huerta y tablero.',
      open: true),
  BiomeDef(kBosque, 'BOSQUE',
      'Lago propio, frutos silvestres y las entradas a la Pradera y al '
          'Bosque Hondo.',
      open: true, zones: [1, 2]),
  BiomeDef('ruinas', 'RUINAS', 'Próximamente.'),
  BiomeDef('cavernas', 'CAVERNAS', 'Próximamente.'),
  BiomeDef('grieta', 'GRIETA', 'Próximamente.'),
];

BiomeDef? biomeDef(String? id) {
  for (final b in kBiomes) {
    if (b.id == (id ?? kPueblo)) return b;
  }
  return null;
}

/// Tipo de recolectable (cada uno da su producto silvestre).
class ForageDef {
  const ForageDef(this.item, this.name);

  /// Id del producto (un `CropDef` silvestre: va a la bolsa de cosechas
  /// y se vende al comerciante).
  final String item;
  final String name;
}

const kForageKinds = <ForageDef>[
  ForageDef('moras_bosque', 'Moras'),
  ForageDef('hierba_rocio', 'Hierbas'),
  ForageDef('hongo_ambar', 'Hongos'),
];

/// Un punto de recolección del exterior: tile y tipo ([kForageKinds]).
typedef ForageSpot = ({int x, int y, int kind});

/// Bioma de los productos silvestres (no se plantan).
const kWildBiome = 'silvestre';

/// Peces del lago del Bosque (fishing.md § 2.1).
const kForestFish = [
  'mojarra_sombra',
  'bagre_raiz',
  'trucha_musgo',
  'lucio_runico',
  'salmon_eco',
];

/// Basura del agua del Bosque (fishing.md § 8).
const kForestJunk = ['hojarasca_mojada', 'rama_empapada'];

/// Semillas exclusivas del Bosque (farming.md § 2): salen de recolectar
/// y se plantan en la huerta del pueblo. Peso relativo de cada una.
const kForestSeeds = <String, double>{
  'helecho_dulce': 0.7,
  'arandano_sombra': 0.25,
  'seta_reloj': 0.05,
};

/// El exterior del Bosque (overworld_biomes.md § 3): 34 × 22, borde de
/// árboles, camino al sur (vuelta al pueblo), lago al este, matas para
/// recolectar y dos entradas de mazmorra al norte.
abstract final class BosqueLayout {
  static const width = 34;
  static const height = 22;
  static const theme = 'bosque_ext';

  /// Llegada desde el pueblo: el camino del sur.
  static const spawn = WorldPoint(17.0 * 16, 19.5 * 16);

  /// Entradas de mazmorra (zona, tile).
  static const entrances = [(1, 8, 3), (2, 25, 3)];

  /// Muelles del lago.
  static const docks = [(21, 14), (25, 17)];

  static const forage = <ForageSpot>[
    (x: 5, y: 8, kind: 0),
    (x: 11, y: 9, kind: 1),
    (x: 4, y: 14, kind: 2),
    (x: 9, y: 17, kind: 0),
    (x: 13, y: 13, kind: 1),
    (x: 29, y: 8, kind: 2),
    (x: 20, y: 8, kind: 0),
    (x: 6, y: 19, kind: 1),
  ];

  static const trees = [
    (3, 6), (12, 6), (27, 6), (30, 10), (5, 11), (10, 12), (14, 18),
    (29, 19), (19, 19), (3, 17), (22, 7), (7, 15),
  ];

  /// Carteles sobre el mapa (texto, tile).
  static const labels = [
    ('CAMINO AL PUEBLO', 17, 20),
    ('LAGO DEL BOSQUE', 25, 10),
  ];

  /// Lago: elipse con centro y radios en tiles.
  static bool lake(int x, int y) {
    final dx = (x - 25) / 4.6, dy = (y - 14) / 3.4;
    return dx * dx + dy * dy <= 1;
  }

  /// Las filas del mapa con las matas de [picked] ya recolectadas.
  static List<String> rows(Set<int> picked) {
    final g = [
      for (var y = 0; y < height; y++) List.filled(width, Tile.grass),
    ];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final border = y < 3 || x < 2 || x >= width - 2 || y == height - 1;
        if (border) g[y][x] = Tile.tree;
        if (lake(x, y)) g[y][x] = Tile.water;
      }
    }
    // Camino del sur hasta el cruce y el ramal a las dos entradas.
    for (var y = 4; y < height; y++) {
      g[y][16] = Tile.path;
      g[y][17] = Tile.path;
    }
    for (var x = 8; x <= 25; x++) {
      g[5][x] = Tile.path;
    }
    for (final (zone, x, y) in entrances) {
      g[y][x] = Tile.entrance(zone);
      g[y + 1][x] = Tile.path;
    }
    for (final (x, y) in docks) {
      g[y][x] = Tile.fishing;
    }
    for (final (x, y) in trees) {
      g[y][x] = Tile.tree;
    }
    for (var i = 0; i < forage.length; i++) {
      final f = forage[i];
      g[f.y][f.x] = picked.contains(i) ? Tile.forageUsed : Tile.forage;
    }
    return [for (final r in g) r.join()];
  }
}
