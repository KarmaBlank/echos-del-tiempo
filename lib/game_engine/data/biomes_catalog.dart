// Mapa de viaje y exteriores de bioma (docs/specs/overworld_biomes.md).
// Datos puros: los lee `MapGenerator.biome` y `BiomeRules`; la UI solo
// los muestra.

import '../models/town_build.dart';
import 'town_layout.dart';

export '../rules/biome_regions.dart';

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
  const ForageDef(this.item, this.name, {this.cls = ForageClass.plant});

  /// What kind of spot it is (biome_regions.md § 5).
  final ForageClass cls;

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
  // Biome regions (biome_regions.md § 5): shared by every biome.
  ForageDef('', 'Mata de semillas', cls: ForageClass.seedBush),
  ForageDef('', 'Brotes de estación', cls: ForageClass.seasonal),
  ForageDef('flor_eco', 'Flor del eco', cls: ForageClass.echoBloom),
];

/// What a forage spot gives (biome_regions.md § 5).
enum ForageClass {
  /// The biome's wild product (and sometimes a seed).
  plant,

  /// Wild seed bush: always a seed, rare ones weigh more.
  seedBush,

  /// The product of the current season ([kSeasonalForage]).
  seasonal,

  /// Rare echo bloom, only in optional nooks; regrows slowly.
  echoBloom,
}

/// [kForageKinds] index of each shared kind.
const kForageSeedBush = 15;
const kForageSeasonal = 16;
const kForageEchoBloom = 17;

/// Seasonal forage product by season index (`Season.index`).
const kSeasonalForage = [
  'brote_primavera',
  'fresa_estival',
  'castana_otono',
  'baya_invierno',
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

/// Un motivo para salir de noche (overworld_biomes.md § 10.1.1): la
/// frase que dice ([id], en npcs.json) y adónde va: un lugar del pueblo
/// ([spot]) o la HUERTA más cercana a su casa ([build]); si no existe,
/// la fuente rúnica.
class NightOuting {
  const NightOuting(this.id, {this.spot, this.build});

  /// Id of its line in `NpcTalkDef.night` (npcs.json).
  final String id;
  final TownSpot? spot;
  final BuildKind? build;
}

/// Un habitante de bioma (§ 9): vende las semillas de su bioma y se
/// puede invitar al pueblo.
class BiomeNpcDef {
  const BiomeNpcDef(this.id, this.name, this.role,
      {required this.biome,
      required this.tile,
      required this.seeds,
      required this.benefit,
      this.nightOutings = const []});

  final String id;

  /// Salidas nocturnas (overworld_biomes.md § 10.1.1): algunas noches,
  /// con su chance (`resNightOut<Id>`), sale de su casa por uno de estos
  /// motivos y se queda cerca del lugar que le corresponde.
  final List<NightOuting> nightOutings;
  final String name;
  final NpcRole role;
  final String biome;

  /// Dónde está parado en su exterior.
  final (int, int) tile;

  /// Semilla del bioma → precio en oro.
  final Map<String, int> seeds;

  /// Beneficio como habitante del pueblo, con `{v}` = valor del nivel.
  final String benefit;

  /// Sprite (`items.vida_npc_<id>` del manifest).
  String get sprite => 'npc_$id';

  /// Retrato del cuadro de diálogo (`items.vida_npc_<id>_retrato`).
  String get portrait => 'npc_${id}_retrato';

  /// The same resident with its camp at [t] (the region generator places
  /// the camp; biome_regions.md § 4).
  BiomeNpcDef at((int, int) t) => BiomeNpcDef(id, name, role,
      biome: biome,
      tile: t,
      seeds: seeds,
      benefit: benefit,
      nightOutings: nightOutings);

  @override
  bool operator ==(Object other) => other is BiomeNpcDef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Lake variants of a biome region (biome_regions.md § 3).
enum LakeVariant {
  /// Open shore all around.
  open,

  /// Fishable from one side only; glowing plants close the rest.
  glowShore,

  /// Inside a cavern: rock walls, light falling from openings above.
  cave,
}

/// Ambient critters of a region (biome_regions.md § 6).
/// What plays (softly) while the local player is fishing
/// (biome_regions.md § 7.2.3).
enum FishingAmbience {
  /// Breeze gusts (open sky).
  breeze,

  /// Water drips (under a roof: caves, cave lakes, mines).
  drip,

  /// Nothing but the faint music.
  none,
}

enum CritterKind { butterfly, sparkMote, frostMote, ember, echoWisp }

/// How a biome region is generated (biome_regions.md § 2): lake variants
/// (weights), side-path flavour and ambient life. Pure data; the numbers
/// that tune sizes and counts live in `kTuning[TuningId.regions]`.
/// What a section of the wilds is (biome_exploration.md § 2).
enum WildKind { forest, cavern, giantLake, shrine, meadow }

/// Default section weights of the wilds (the giant lake has its own
/// chance, `giantLakeChance`).
const kDefaultWilds = {
  WildKind.forest: 0.5,
  WildKind.cavern: 0.22,
  WildKind.meadow: 0.2,
  WildKind.shrine: 0.08,
};

class BiomeRegionStyle {
  const BiomeRegionStyle(
      {required this.lakes,
      this.grove = 0.5,
      this.tunnel = 0.3,
      this.critter = CritterKind.butterfly,
      this.caveOpenings = true,
      this.fishingAmbience = FishingAmbience.breeze,
      this.lakeNames = const {},
      this.wilds = kDefaultWilds});

  /// Section kind -> weight in the wilds (biome_exploration.md § 2).
  final Map<WildKind, double> wilds;

  /// The quiet ambience while fishing here (§ 7.2.3).
  final FishingAmbience fishingAmbience;

  /// Cave lakes of this biome have openings above (light shafts); `false`
  /// keeps them dark (biome_regions.md § 7).
  final bool caveOpenings;

  /// Variant -> weight.
  final Map<LakeVariant, double> lakes;

  /// Chance that a side path crosses a small grove / a short cave.
  final double grove;
  final double tunnel;
  final CritterKind critter;

  /// Map label of the extra lakes by variant (the first lake uses the
  /// biome's own name).
  final Map<LakeVariant, String> lakeNames;
}

/// The fixed data of a biome exterior: theme, lake name and tables,
/// forage kinds, zones and resident. The geometry is generated per world
/// seed by `BiomeRegionGen` (biome_regions.md); `biomeLayout(id)` gives
/// the generated `BiomeLayout`.
class BiomeBase {
  const BiomeBase(this.id,
      {required this.theme,
      required this.lakeName,
      required this.forageKinds,
      required this.zones,
      required this.fish,
      required this.junk,
      required this.seeds,
      required this.npc,
      required this.style});

  final String id;
  final String theme;
  final String lakeName;

  /// The three base forage kinds ([kForageKinds] indices).
  final List<int> forageKinds;

  /// Dungeon zones whose entrances are in this exterior.
  final List<int> zones;

  /// Peces del lago (fishing.md § 2.1) y basura del agua (§ 8).
  final List<String> fish;
  final List<String> junk;

  /// Semillas exclusivas (farming.md § 2): id -> peso.
  final Map<String, double> seeds;
  final BiomeNpcDef npc;
  final BiomeRegionStyle style;
}

const _ilda = BiomeNpcDef('ilda', 'Ilda', NpcRole.herbolaria,
    biome: kBosque,
    tile: (12, 15),
    seeds: {'helecho_dulce': 40, 'arandano_sombra': 110},
    benefit: 'Pociones: curan +{v} % más.',
    nightOutings: [
      NightOuting('ilda_garden', build: BuildKind.huerta),
      NightOuting('ilda_dew', spot: TownSpot.fountain),
    ]);

const _velda = BiomeNpcDef('velda', 'Velda', NpcRole.archivista,
    biome: kRuinas,
    tile: (21, 16),
    seeds: {'lirio_mecanico': 60, 'calabaza_runica': 160},
    benefit: 'Mazmorras: se ven {v} salas más al entrar.',
    nightOutings: [
      NightOuting('velda_lamp', spot: TownSpot.board),
      NightOuting('velda_statue', spot: TownSpot.statue),
    ]);

const _kael = BiomeNpcDef('kael', 'Kael', NpcRole.instructor,
    biome: kCavernas,
    tile: (12, 15),
    seeds: {'nabo_escarcha': 80, 'flor_cristal': 220},
    benefit: 'Misiones: +{v} % de XP para todo el grupo.',
    nightOutings: [
      NightOuting('kael_watch', spot: TownSpot.portal),
      NightOuting('kael_drill', spot: TownSpot.lostLoot),
    ]);

const _brann = BiomeNpcDef('brann', 'Brann', NpcRole.forjador,
    biome: kGrieta,
    tile: (21, 16),
    seeds: {'chile_volcan': 110, 'flor_brasa': 300},
    benefit: 'Forja: mejoras {v} % más baratas.',
    nightOutings: [
      NightOuting('brann_embers', spot: TownSpot.forge),
      NightOuting('brann_stock', spot: TownSpot.armory),
    ]);

const _oren = BiomeNpcDef('oren', 'Oren', NpcRole.vidente,
    biome: kAbismo,
    tile: (12, 15),
    seeds: {'trigo_eco': 150, 'rosa_futuro': 420},
    benefit: 'Vida llena al volver al pueblo y +{v} % de vida máxima.',
    nightOutings: [
      NightOuting('oren_stars', spot: TownSpot.statue),
      NightOuting('oren_fountain', spot: TownSpot.fountain),
    ]);

const _cn = {
  LakeVariant.open: 'LAGO ABIERTO',
  LakeVariant.glowShore: 'ORILLA LUMINOSA',
  LakeVariant.cave: 'LAGO DE LA GRUTA',
};

/// The biome exteriors by id (no town). Geometry: `biomeLayout(id)`.
const kBiomeBases = <String, BiomeBase>{
  kBosque: BiomeBase(kBosque,
      theme: 'bosque_ext',
      lakeName: 'LAGO DEL BOSQUE',
      forageKinds: [0, 1, 2],
      zones: [1, 2],
      fish: kForestFish,
      junk: kForestJunk,
      seeds: kForestSeeds,
      npc: _ilda,
      style: BiomeRegionStyle(
          lakes: {
            LakeVariant.open: 0.5,
            LakeVariant.glowShore: 0.3,
            LakeVariant.cave: 0.2
          },
          grove: 0.7,
          tunnel: 0.2,
          critter: CritterKind.butterfly,
          lakeNames: _cn)),
  kRuinas: BiomeBase(kRuinas,
      theme: 'ruinas_ext',
      lakeName: 'ESTANQUE DE ENGRANAJES',
      forageKinds: [3, 4, 5],
      zones: [3, 5],
      fish: [
        'carpa_cobre', 'anguila_runa', 'pez_pinon', 'barbo_reloj',
        'esturion_eras',
      ],
      junk: ['engranaje_oxidado', 'placa_rota'],
      seeds: {'lirio_mecanico': 0.7, 'calabaza_runica': 0.25, 'olivo_eras': 0.05},
      npc: _velda,
      style: BiomeRegionStyle(
          lakes: {
            LakeVariant.open: 0.5,
            LakeVariant.glowShore: 0.2,
            LakeVariant.cave: 0.3
          },
          grove: 0.3,
          tunnel: 0.4,
          critter: CritterKind.sparkMote,
          lakeNames: _cn)),
  kCavernas: BiomeBase(kCavernas,
      theme: 'cavernas_ext',
      lakeName: 'LAGO HELADO',
      forageKinds: [6, 7, 8],
      zones: [4, 6],
      fish: [
        'pez_escarcha', 'lenguado_cristal', 'trucha_hielo', 'lucio_frio',
        'pez_invierno',
      ],
      junk: ['estalactita_rota', 'guante_helado'],
      seeds: {'nabo_escarcha': 0.7, 'flor_cristal': 0.25, 'lirio_eco': 0.05},
      npc: _kael,
      style: BiomeRegionStyle(
          lakes: {LakeVariant.cave: 0.6, LakeVariant.glowShore: 0.4},
          grove: 0.1,
          tunnel: 0.6,
          critter: CritterKind.frostMote,
          wilds: {
            WildKind.cavern: 0.45,
            WildKind.forest: 0.25,
            WildKind.meadow: 0.15,
            WildKind.shrine: 0.15,
          },
          fishingAmbience: FishingAmbience.drip,
          lakeNames: _cn)),
  kGrieta: BiomeBase(kGrieta,
      theme: 'grieta_ext',
      lakeName: 'LAGO DE BRASAS',
      forageKinds: [9, 10, 11],
      zones: [7, 8],
      fish: [
        'pez_ceniza', 'bagre_brasa', 'salamandra_lago', 'dorado_igneo',
        'pez_ultimo_fuego',
      ],
      junk: ['escoria', 'hueso_chamuscado'],
      seeds: {'chile_volcan': 0.7, 'flor_brasa': 0.25, 'fruta_forja': 0.05},
      npc: _brann,
      style: BiomeRegionStyle(
          lakes: {LakeVariant.open: 0.6, LakeVariant.cave: 0.4},
          grove: 0.2,
          tunnel: 0.5,
          critter: CritterKind.ember,
          caveOpenings: false,
          fishingAmbience: FishingAmbience.none,
          lakeNames: _cn)),
  kAbismo: BiomeBase(kAbismo,
      theme: 'abismo_ext',
      lakeName: 'MAR DE ECOS',
      forageKinds: [12, 13, 14],
      zones: [9, 10],
      fish: [
        'pez_eco', 'medusa_manana', 'raya_reloj', 'pez_paradoja',
        'leviatan_quieto',
      ],
      junk: ['arena_reloj', 'manecilla_perdida'],
      seeds: {'trigo_eco': 0.7, 'rosa_futuro': 0.25, 'arbol_paradoja': 0.05},
      npc: _oren,
      style: BiomeRegionStyle(
          lakes: {LakeVariant.glowShore: 0.6, LakeVariant.open: 0.4},
          grove: 0.3,
          tunnel: 0.3,
          critter: CritterKind.echoWisp,
          wilds: {
            WildKind.forest: 0.4,
            WildKind.cavern: 0.2,
            WildKind.meadow: 0.2,
            WildKind.shrine: 0.2,
          },
          fishingAmbience: FishingAmbience.none,
          lakeNames: _cn)),
};

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


