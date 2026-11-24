// Mapa de viaje y exteriores de bioma (docs/specs/overworld_biomes.md).
// Datos puros: los lee `MapGenerator.biome` y `BiomeRules`; la UI solo
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

  /// Existe (los que no, se ven en gris: "Próximamente").
  final bool open;

  /// Zonas (mazmorras) cuyas entradas están en este exterior.
  final List<int> zones;

  /// Zona que el dueño del mundo tiene que tener desbloqueada para viajar
  /// (§ 1.1; 0 = siempre).
  int get unlockZone => zones.isEmpty ? 0 : zones.first;
}

/// El pueblo en el mapa de viaje.
const kPueblo = 'pueblo';

const kBosque = 'bosque';
const kRuinas = 'ruinas';
const kCavernas = 'cavernas';
const kGrieta = 'grieta';
const kAbismo = 'abismo';

/// Orden del mapa de viaje.
const kBiomes = <BiomeDef>[
  BiomeDef(kPueblo, 'PUEBLO',
      'El claro con la fuente rúnica: comerciante, huerta y tablero.',
      open: true),
  BiomeDef(kBosque, 'BOSQUE',
      'Lago propio, frutos silvestres y las entradas a la Pradera y al '
          'Bosque Hondo.',
      open: true, zones: [1, 2]),
  BiomeDef(kRuinas, 'RUINAS',
      'Restos del pasado magitec: estanque de engranajes y las entradas a '
          'las Ruinas Cronales y la Fortaleza Caída.',
      open: true, zones: [3, 5]),
  BiomeDef(kCavernas, 'CAVERNAS',
      'Bajo tierra y sin cielo: lago helado y las entradas a las Cavernas '
          'Heladas y al Laberinto Temporal.',
      open: true, zones: [4, 6]),
  BiomeDef(kGrieta, 'GRIETA',
      'Tierra partida y caliente: lago de brasas y las entradas a la '
          'Grieta Ígnea y al Cementerio de Eras.',
      open: true, zones: [7, 8]),
  BiomeDef(kAbismo, 'ABISMO',
      'Donde llegan los ecos del futuro: mar de ecos y las entradas al '
          'Abismo y al Corazón del Tiempo.',
      open: true, zones: [9, 10]),
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

/// Todos los tipos de recolectable; cada bioma usa tres
/// (`BiomeLayout.forage[].kind` es el índice acá).
const kForageKinds = <ForageDef>[
  ForageDef('moras_bosque', 'Moras'),
  ForageDef('hierba_rocio', 'Hierbas'),
  ForageDef('hongo_ambar', 'Hongos'),
  ForageDef('musgo_cobre', 'Musgo de cobre'),
  ForageDef('liquen_runa', 'Liquen rúnico'),
  ForageDef('baya_engranaje', 'Bayas de engranaje'),
  ForageDef('cristal_escarcha', 'Cristales de escarcha'),
  ForageDef('liquen_azul', 'Liquen azul'),
  ForageDef('hongo_frio', 'Hongos fríos'),
  ForageDef('pimiento_brasa', 'Pimientos de brasa'),
  ForageDef('flor_ceniza', 'Flores de ceniza'),
  ForageDef('raiz_ignea', 'Raíces ígneas'),
  ForageDef('polvo_eco', 'Polvo de eco'),
  ForageDef('flor_manana', 'Flores del mañana'),
  ForageDef('fruto_paradoja', 'Frutos paradoja'),
];

/// Un punto de recolección del exterior: tile y tipo ([kForageKinds]).
typedef ForageSpot = ({int x, int y, int kind});

/// Bioma de los productos silvestres (no se plantan).
const kWildBiome = 'silvestre';

/// Rol de un habitante de bioma (§ 9): define su beneficio al vivir en
/// el pueblo.
enum NpcRole {
  herbolaria('Herbolaria'),
  archivista('Archivista'),
  instructor('Instructor'),
  forjador('Forjador'),
  vidente('Vidente');

  const NpcRole(this.label);
  final String label;
}

/// Un habitante de bioma (§ 9): vende las semillas de su bioma y se
/// puede invitar al pueblo.
class BiomeNpcDef {
  const BiomeNpcDef(this.id, this.name, this.role,
      {required this.biome,
      required this.tile,
      required this.lines,
      required this.seeds,
      required this.benefit,
      this.nightOwl = false});

  final String id;

  /// Trasnochador (overworld_biomes.md § 10.1): algunas noches sale a
  /// pasear en vez de quedarse en su casa (`resNightOwlChance`).
  final bool nightOwl;
  final String name;
  final NpcRole role;
  final String biome;

  /// Dónde está parado en su exterior.
  final (int, int) tile;

  /// Frases (una por visita, en orden circular).
  final List<String> lines;

  /// Semilla del bioma → precio en oro.
  final Map<String, int> seeds;

  /// Beneficio como habitante del pueblo, con `{v}` = valor del nivel.
  final String benefit;

  /// Sprite (`items.vida_npc_<id>` del manifest).
  String get sprite => 'npc_$id';

  /// Retrato del cuadro de diálogo (`items.vida_npc_<id>_retrato`).
  String get portrait => 'npc_${id}_retrato';
}

/// Un exterior de bioma: 34 × 22, borde sólido, camino al sur (vuelta al
/// pueblo), un lago con muelles, matas, obstáculos, dos entradas de
/// mazmorra al norte y un habitante.
class BiomeLayout {
  const BiomeLayout(this.id,
      {required this.theme,
      required this.lake,
      required this.lakeName,
      required this.docks,
      required this.forage,
      required this.obstacles,
      required this.entrances,
      required this.fish,
      required this.junk,
      required this.seeds,
      required this.npc});

  static const width = 34;
  static const height = 22;

  final String id;
  final String theme;

  /// Lago: elipse (centro x, centro y, radio x, radio y) en tiles.
  final (double, double, double, double) lake;
  final String lakeName;
  final List<(int, int)> docks;
  final List<ForageSpot> forage;
  final List<(int, int)> obstacles;

  /// Entradas de mazmorra (zona, tile).
  final List<(int, int, int)> entrances;

  /// Peces del lago (fishing.md § 2.1) y basura del agua (§ 8).
  final List<String> fish;
  final List<String> junk;

  /// Semillas exclusivas (farming.md § 2): id → peso.
  final Map<String, double> seeds;
  final BiomeNpcDef npc;

  /// Llegada desde el pueblo: el camino del sur.
  WorldPoint get spawn => const WorldPoint(17.0 * 16, 19.5 * 16);

  /// Portales de Ecos (ecos_zone.md § 2): uno por zona de este exterior,
  /// a la derecha de su entrada. (zona, x del tile del medio, y); el
  /// portal ocupa 3 tiles (`x − 1 .. x + 1`), como el del pueblo, y el del
  /// medio cumple `x % 3 == 1` para que el anillo se dibuje ahí.
  List<(int, int, int)> get ecoPortals => [
        for (final (zone, x, y) in entrances)
          (zone, _ringX(x + 3), y),
      ];

  static int _ringX(int x) {
    while (x % 3 != 1) {
      x++;
    }
    return x;
  }

  /// Carteles sobre el mapa (texto, tile).
  List<(String, int, int)> get labels => [
        ('CAMINO AL PUEBLO', 17, 20),
        (lakeName, lake.$1.round(), (lake.$2 - lake.$4 - 1).round()),
        for (final (zone, x, y) in ecoPortals)
          ('ECOS · ZONA $zone', x, y - 1),
      ];

  bool isLake(int x, int y) {
    final dx = (x - lake.$1) / lake.$3, dy = (y - lake.$2) / lake.$4;
    return dx * dx + dy * dy <= 1;
  }

  /// Las filas del mapa con las matas de [picked] ya recolectadas.
  List<String> rows(Set<int> picked) {
    final g = [
      for (var y = 0; y < height; y++) List.filled(width, Tile.grass),
    ];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final border = y < 3 || x < 2 || x >= width - 2 || y == height - 1;
        if (border) g[y][x] = Tile.tree;
        if (isLake(x, y)) g[y][x] = Tile.water;
      }
    }
    for (var y = 4; y < height; y++) {
      g[y][16] = Tile.path;
      g[y][17] = Tile.path;
    }
    final xs = [for (final e in entrances) e.$2]..sort();
    for (var x = xs.first; x <= xs.last; x++) {
      g[5][x] = Tile.path;
    }
    for (final (zone, x, y) in entrances) {
      g[y][x] = Tile.entrance(zone);
      g[y + 1][x] = Tile.path;
    }
    for (final (_, x, y) in ecoPortals) {
      for (var dx = -1; dx <= 1; dx++) {
        g[y][x + dx] = Tile.portal;
        g[y + 1][x + dx] = Tile.path;
      }
    }
    for (final (x, y) in docks) {
      g[y][x] = Tile.fishing;
    }
    for (final (x, y) in obstacles) {
      g[y][x] = Tile.tree;
    }
    for (var i = 0; i < forage.length; i++) {
      final f = forage[i];
      g[f.y][f.x] = picked.contains(i) ? Tile.forageUsed : Tile.forage;
    }
    return [for (final r in g) r.join()];
  }
}

const _ilda = BiomeNpcDef('ilda', 'Ilda', NpcRole.herbolaria,
    biome: kBosque,
    tile: (12, 15),
    lines: [
      'Las moras de acá saben distinto cada mañana. Como si el bosque se '
          'acordara de algo.',
      'Hay ecos que bajan por el río. Yo no los pesco: los dejo pasar.',
      'Si un día tu pueblo necesita quien cure, avisame.',
    ],
    seeds: {'helecho_dulce': 40, 'arandano_sombra': 110},
    benefit: 'Pociones: curan +{v} % más.');

const _velda = BiomeNpcDef('velda', 'Velda', NpcRole.archivista,
    biome: kRuinas,
    tile: (21, 16),
    lines: [
      'Estas placas son mapas. Del pasado, cuando todo era más avanzado.',
      'Los autómatas no están rotos: esperan una orden que nadie recuerda.',
      'Algo hizo que el mundo se volviera medieval. Lo estoy anotando.',
    ],
    seeds: {'lirio_mecanico': 60, 'calabaza_runica': 160},
    benefit: 'Mazmorras: se ven {v} salas más al entrar.');

const _kael = BiomeNpcDef('kael', 'Kael', NpcRole.instructor,
    biome: kCavernas,
    tile: (12, 15),
    lines: [
      'Acá abajo no hay día ni noche. Solo el frío y el eco de tus pasos.',
      'El eco que oís a veces llega antes que tu voz. Es del futuro.',
      'Entrená conmigo y vas a aprender más rápido allá afuera.',
    ],
    seeds: {'nabo_escarcha': 80, 'flor_cristal': 220},
    benefit: 'Misiones: +{v} % de XP para todo el grupo.');

const _brann = BiomeNpcDef('brann', 'Brann', NpcRole.forjador,
    biome: kGrieta,
    tile: (21, 16),
    lines: [
      'Este calor viene de abajo, de un mecanismo viejo que sigue andando.',
      'Forjo con lo que deja el pasado. Nada se pierde del todo.',
      'Llevame a tu pueblo y tus mejoras van a salir más baratas.',
    ],
    seeds: {'chile_volcan': 110, 'flor_brasa': 300},
    benefit: 'Forja: mejoras {v} % más baratas.');

const _oren = BiomeNpcDef('oren', 'Oren', NpcRole.vidente,
    biome: kAbismo,
    tile: (12, 15),
    lines: [
      'El futuro no se cambia. Se cumple. Yo solo miro cómo llega.',
      'Ya te vi volver de esa mazmorra. Todavía no fuiste.',
      'Lo que tiene que pasar, pasa. Mejor llegar sanos.',
    ],
    seeds: {'trigo_eco': 150, 'rosa_futuro': 420},
    benefit: 'Vida llena al volver al pueblo y +{v} % de vida máxima.',
    nightOwl: true);

/// Los exteriores por id (el pueblo no está).
const kBiomeLayouts = <String, BiomeLayout>{
  kBosque: BiomeLayout(kBosque,
      theme: 'bosque_ext',
      lake: (25, 14, 4.6, 3.4),
      lakeName: 'LAGO DEL BOSQUE',
      docks: [(21, 14), (25, 17)],
      forage: [
        (x: 5, y: 8, kind: 0),
        (x: 11, y: 9, kind: 1),
        (x: 4, y: 14, kind: 2),
        (x: 9, y: 17, kind: 0),
        (x: 13, y: 13, kind: 1),
        (x: 29, y: 8, kind: 2),
        (x: 20, y: 8, kind: 0),
        (x: 6, y: 19, kind: 1),
      ],
      obstacles: [
        (3, 6), (12, 6), (27, 6), (30, 10), (5, 11), (10, 12), (14, 18),
        (29, 19), (19, 19), (3, 17), (22, 7), (7, 15),
      ],
      entrances: [(1, 8, 3), (2, 25, 3)],
      fish: kForestFish,
      junk: kForestJunk,
      seeds: kForestSeeds,
      npc: _ilda),
  kRuinas: BiomeLayout(kRuinas,
      theme: 'ruinas_ext',
      lake: (8, 13, 4.2, 3.2),
      lakeName: 'ESTANQUE DE ENGRANAJES',
      docks: [(12, 13), (8, 16)],
      forage: [
        (x: 22, y: 8, kind: 3), (x: 28, y: 9, kind: 4), (x: 29, y: 14, kind: 5),
        (x: 24, y: 17, kind: 3), (x: 20, y: 12, kind: 4), (x: 4, y: 8, kind: 5),
        (x: 13, y: 8, kind: 3), (x: 27, y: 19, kind: 4), (x: 5, y: 19, kind: 5),
      ],
      obstacles: [
        (3, 6), (14, 6), (21, 6), (30, 6), (25, 11), (30, 17), (19, 18),
        (13, 18), (3, 17), (23, 14),
      ],
      entrances: [(3, 9, 3), (5, 25, 3)],
      fish: [
        'carpa_cobre', 'anguila_runa', 'pez_pinon', 'barbo_reloj',
        'esturion_eras',
      ],
      junk: ['engranaje_oxidado', 'placa_rota'],
      seeds: {'lirio_mecanico': 0.7, 'calabaza_runica': 0.25, 'olivo_eras': 0.05},
      npc: _velda),
  kCavernas: BiomeLayout(kCavernas,
      theme: 'cavernas_ext',
      lake: (25, 13, 4.4, 3.6),
      lakeName: 'LAGO HELADO',
      docks: [(21, 13), (25, 17)],
      forage: [
        (x: 5, y: 8, kind: 6), (x: 11, y: 9, kind: 7), (x: 4, y: 14, kind: 8),
        (x: 9, y: 18, kind: 6), (x: 13, y: 12, kind: 7), (x: 29, y: 18, kind: 8),
        (x: 20, y: 8, kind: 6), (x: 6, y: 19, kind: 7), (x: 30, y: 8, kind: 8),
      ],
      obstacles: [
        (3, 6), (12, 6), (27, 6), (5, 11), (10, 12), (14, 18), (19, 19),
        (3, 17), (22, 7), (31, 12),
      ],
      entrances: [(4, 8, 3), (6, 25, 3)],
      fish: [
        'pez_escarcha', 'lenguado_cristal', 'trucha_hielo', 'lucio_frio',
        'pez_invierno',
      ],
      junk: ['estalactita_rota', 'guante_helado'],
      seeds: {'nabo_escarcha': 0.7, 'flor_cristal': 0.25, 'lirio_eco': 0.05},
      npc: _kael),
  kGrieta: BiomeLayout(kGrieta,
      theme: 'grieta_ext',
      lake: (8, 13, 4.4, 3.4),
      lakeName: 'LAGO DE BRASAS',
      docks: [(12, 13), (8, 17)],
      forage: [
        (x: 22, y: 8, kind: 9), (x: 28, y: 9, kind: 10), (x: 29, y: 14, kind: 11),
        (x: 24, y: 17, kind: 9), (x: 20, y: 12, kind: 10), (x: 4, y: 8, kind: 11),
        (x: 13, y: 8, kind: 9), (x: 27, y: 19, kind: 10), (x: 5, y: 19, kind: 11),
      ],
      obstacles: [
        (3, 6), (14, 6), (21, 6), (30, 6), (25, 11), (30, 17), (19, 18),
        (13, 18), (3, 17), (23, 14),
      ],
      entrances: [(7, 9, 3), (8, 25, 3)],
      fish: [
        'pez_ceniza', 'bagre_brasa', 'salamandra_lago', 'dorado_igneo',
        'pez_ultimo_fuego',
      ],
      junk: ['escoria', 'hueso_chamuscado'],
      seeds: {'chile_volcan': 0.7, 'flor_brasa': 0.25, 'fruta_forja': 0.05},
      npc: _brann),
  kAbismo: BiomeLayout(kAbismo,
      theme: 'abismo_ext',
      lake: (25, 13, 5.0, 3.8),
      lakeName: 'MAR DE ECOS',
      docks: [(20, 13), (25, 17)],
      forage: [
        (x: 5, y: 8, kind: 12), (x: 11, y: 9, kind: 13), (x: 4, y: 14, kind: 14),
        (x: 9, y: 18, kind: 12), (x: 13, y: 12, kind: 13), (x: 29, y: 18, kind: 14),
        (x: 20, y: 8, kind: 12), (x: 6, y: 19, kind: 13), (x: 30, y: 8, kind: 14),
      ],
      obstacles: [
        (3, 6), (12, 6), (27, 6), (5, 11), (10, 12), (14, 18), (19, 19),
        (3, 17), (22, 7), (31, 12),
      ],
      entrances: [(9, 8, 3), (10, 25, 3)],
      fish: [
        'pez_eco', 'medusa_manana', 'raya_reloj', 'pez_paradoja',
        'leviatan_quieto',
      ],
      junk: ['arena_reloj', 'manecilla_perdida'],
      seeds: {'trigo_eco': 0.7, 'rosa_futuro': 0.25, 'arbol_paradoja': 0.05},
      npc: _oren),
};

/// El exterior de [id] (`null` = pueblo o desconocido).
BiomeLayout? biomeLayout(String? id) => kBiomeLayouts[id];

/// Los habitantes de todos los biomas.
List<BiomeNpcDef> get kBiomeNpcs =>
    [for (final l in kBiomeLayouts.values) l.npc];

BiomeNpcDef? biomeNpc(String id) {
  for (final n in kBiomeNpcs) {
    if (n.id == id) return n;
  }
  return null;
}

/// El exterior del Bosque (v0.26.0).
BiomeLayout get bosqueLayout => kBiomeLayouts[kBosque]!;

/// Peces, basura y semillas del Bosque (v0.26.0).
const kForestFish = [
  'mojarra_sombra', 'bagre_raiz', 'trucha_musgo', 'lucio_runico', 'salmon_eco',
];
const kForestJunk = ['hojarasca_mojada', 'rama_empapada'];
const kForestSeeds = <String, double>{
  'helecho_dulce': 0.7,
  'arandano_sombra': 0.25,
  'seta_reloj': 0.05,
};

/// Nombre del habitante [id] (o el id si no existe).
String biomeNpcName(String id) => biomeNpc(id)?.name ?? id;
