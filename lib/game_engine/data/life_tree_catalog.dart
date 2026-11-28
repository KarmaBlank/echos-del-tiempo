// GENERATED-STYLE TABLE: life trees v2 (docs/specs/life_trees_v2.md).
// Shape lives here; every number lives in `kLifeTreeTuning`, spread into
// `kTuning[TuningId.lifeTree]` (Editor -> Balance -> Oficios: árboles).

/// Profession with its own tree.
enum LifeSkillKind {
  pesca('PESCA'),
  // The Granjero profession (crops + animals); the id stays `cultivo` so
  // saves and the wire keep working (animals.md § 12).
  cultivo('GRANJERO'),
  herreria('HERRERÍA');

  const LifeSkillKind(this.label);
  final String label;
}

/// Branch letters of every tree, left to right (life_trees_v2.md § 2).
const kLifeBranches = ['a', 'b', 'c', 'd', 'e'];

/// Extra branches of a tree after the five shared ones: the Granjero
/// tree adds ANIMALES (`f`, animals.md § 8).
const kLifeExtraBranches = <LifeSkillKind, List<String>>{
  LifeSkillKind.cultivo: ['f'],
};

/// Branch letters of [k], left to right.
List<String> lifeBranchesOf(LifeSkillKind k) =>
    [...kLifeBranches, ...?kLifeExtraBranches[k]];

/// The group a branch of [k] belongs to, for the canvas headings: the
/// Granjero tree splits into CULTIVOS (a–e) and ANIMALES (f).
String? lifeBranchGroup(LifeSkillKind k, String b) =>
    k != LifeSkillKind.cultivo ? null : (b == 'f' ? 'animals' : 'crops');

/// Tiers of a branch (1..[kLifeTiers]); the root is tier 0.
const kLifeTiers = 10;

/// One node of a profession tree.
class LifeTreeNode {
  const LifeTreeNode(this.id, this.name,
      {required this.x,
      required this.y,
      this.cost = 1,
      this.links = const [],
      this.effects = const {},
      this.grants = const {},
      this.branch,
      this.exclusive,
      this.major = false,
      this.root = false});

  final String id;

  /// es-AR name (source of the `data.life_trees.node.<id>.name` key).
  final String name;

  /// Column (-2..2 = branch a..e) and tier (0 = root .. 10 = capstone).
  final int x, y;
  int get tier => y;
  final int cost;

  /// Neighbours: takeable when any of them is taken (or is the root).
  final List<String> links;

  /// Continuous effect -> Balance key of its value.
  final Map<String, String> effects;

  /// One-time rewards -> Balance key of the amount (life_trees_v2.md § 4):
  /// `gold`, `mat:<CraftMaterial>`, `ore:<smith material>`,
  /// `craft:<life material>`, `bait:<id>`, `rod:<id>`,
  /// `meal:<meal>:<quality index>`, `weapon:<tier>`.
  final Map<String, String> grants;

  /// Branch letter (`null` on the root).
  final String? branch;

  /// Exclusive group: only one node of the group per tree (capstones).
  final String? exclusive;
  final bool major;
  final bool root;

  bool get capstone => y == kLifeTiers;
}

/// Effects the rules read (life_trees_v2.md § 5).
abstract final class LifeFx {
  // Fishing
  static const zone = 'zone';
  static const bite = 'bite';
  static const loot = 'loot';
  static const legend = 'legend';
  static const auto = 'auto';
  // Farming
  static const grow = 'grow';
  static const quality = 'quality';
  static const extra = 'extra';
  static const helper = 'helper';
  static const seed = 'seed';
  static const water = 'water';
  // Smithing
  static const forge = 'forge';
  // Every tree
  static const sell = 'sell';
  static const xp = 'xp';
  static const hp = 'hp';
  static const atk = 'atk';

  /// Extra missions every meal you eat lasts (summed over all trees).
  static const meal = 'meal';

  // Sub-path mechanics of tiers 4–7 (life_trees_v2.md § 2.1).
  // Pesca
  static const calm = 'calm'; // calm / auto fishing waits less
  static const twin = 'twin'; // chance of a double catch
  static const chest = 'chest'; // more sunken chests and echo weapons
  static const big = 'big'; // bigger fish (records)
  static const net = 'net'; // raft net: catches while sailing
  static const raft = 'raft'; // faster raft
  static const harpoon = 'harpoon'; // harpoon a big fish from the raft
  static const fishMeal = 'fishMeal'; // fish meals heal / buff more
  static const fishBuff = 'fishBuff'; // fish meals add ATK / MAG
  // Cultivo
  static const waterArea = 'waterArea'; // watering area (1 = 3×3)
  static const seedBack = 'seedBack'; // extra seeds on harvest
  static const mutate = 'mutate'; // mutated rare varieties
  static const compost = 'compost'; // more bags per compost
  static const compostArea = 'compostArea'; // composting area (1 = 3×3)
  static const livingRarity = 'livingRarity'; // living weapon quality
  static const livingAffix = 'livingAffix'; // living weapon extra affixes
  static const mealPower = 'mealPower'; // every meal buffs more
  // Granjero, ANIMALES branch (animals.md § 8)
  static const petCare = 'petCare'; // × affection per pet
  static const haySilo = 'haySilo'; // + bales in each hay store
  static const animalQuality = 'animalQuality'; // chance of +1 quality
  static const partDrop = 'partDrop'; // × part drop chance
  static const animalDouble = 'animalDouble'; // chance of a double product
  static const animalLegend = 'animalLegend'; // legendary products / forge
  // Herrería
  static const forgeAffix = 'forgeAffix'; // forged: extra affix / tier
  static const veinArea = 'veinArea'; // pickaxe area (1 = 3 veins)
  static const rareOre = 'rareOre'; // rarer ore
  static const smeltDouble = 'smeltDouble'; // double ingots sometimes
  static const salvage = 'salvage'; // salvaging returns more
  static const mineSpeed = 'mineSpeed'; // faster pickaxe
  static const detect = 'detect'; // reveal veins in a radius (tiles)
  static const orderPay = 'orderPay'; // better-paid orders
  static const orderChest = 'orderChest'; // orders bring chests

  /// Effects shown as raw numbers (not percentages).
  static const raw = {
    quality,
    auto,
    meal,
    waterArea,
    compostArea,
    veinArea,
    detect,
    haySilo,
  };
}

const _pesca = <LifeTreeNode>[
  LifeTreeNode('fish_r', 'Pescador',
      x: 0, y: 0, cost: 0, links: ['fish_a1', 'fish_b1', 'fish_c1', 'fish_d1', 'fish_e1'],
      effects: {LifeFx.xp: 'fish_r'}, root: true),
  LifeTreeNode('fish_a1', 'Muñeca firme',
      x: -2, y: 1, cost: 1, links: ['fish_r', 'fish_a2'],
      effects: {LifeFx.zone: 'fish_a1'}, branch: 'a'),
  LifeTreeNode('fish_a2', 'Ojo de boya',
      x: -2, y: 2, cost: 1, links: ['fish_a1', 'fish_a3'],
      effects: {LifeFx.bite: 'fish_a2'}, branch: 'a'),
  LifeTreeNode('fish_a3', 'Respiración lenta',
      x: -2, y: 3, cost: 1, links: ['fish_a2', 'fish_a4'],
      effects: {LifeFx.zone: 'fish_a3'}, branch: 'a'),
  LifeTreeNode('fish_a4', 'Hilo tenso',
      x: -2, y: 4, cost: 1, links: ['fish_a3', 'fish_a5'],
      effects: {LifeFx.bite: 'fish_a4'},
      grants: {'bait:lombriz': 'fish_a4_2'}, branch: 'a'),
  LifeTreeNode('fish_a5', 'Agua quieta',
      x: -2, y: 5, cost: 1, links: ['fish_a4', 'fish_a6'],
      effects: {LifeFx.zone: 'fish_a5'}, branch: 'a', major: true),
  LifeTreeNode('fish_a6', 'Paciencia vieja',
      x: -2, y: 6, cost: 1, links: ['fish_a5', 'fish_a7'],
      effects: {LifeFx.bite: 'fish_a6'}, branch: 'a'),
  LifeTreeNode('fish_a7', 'Pulso quieto',
      x: -2, y: 7, cost: 2, links: ['fish_a6', 'fish_a8'],
      effects: {LifeFx.zone: 'fish_a7', LifeFx.bite: 'fish_a7_2'}, branch: 'a'),
  LifeTreeNode('fish_a8', 'Escucha del lago',
      x: -2, y: 8, cost: 2, links: ['fish_a7', 'fish_a9'],
      effects: {LifeFx.zone: 'fish_a8'},
      grants: {'bait:larva_brillante': 'fish_a8_2'}, branch: 'a'),
  LifeTreeNode('fish_a9', 'Hora sin prisa',
      x: -2, y: 9, cost: 2, links: ['fish_a8', 'fish_a10'],
      effects: {LifeFx.bite: 'fish_a9'}, branch: 'a'),
  LifeTreeNode('fish_a10', 'Lago dormido',
      x: -2, y: 10, cost: 3, links: ['fish_a9'],
      effects: {LifeFx.zone: 'fish_a10', LifeFx.bite: 'fish_a10_2'},
      grants: {'rod:cana_eco': 'fish_a10_3'}, branch: 'a', major: true, exclusive: 'cap'),
  LifeTreeNode('fish_b1', 'Rastreador',
      x: -1, y: 1, cost: 1, links: ['fish_r', 'fish_b2'],
      effects: {LifeFx.loot: 'fish_b1'}, branch: 'b'),
  LifeTreeNode('fish_b2', 'Llamado del eco',
      x: -1, y: 2, cost: 1, links: ['fish_b1', 'fish_b3'],
      effects: {LifeFx.legend: 'fish_b2'}, branch: 'b'),
  LifeTreeNode('fish_b3', 'Ojo de ruinas',
      x: -1, y: 3, cost: 1, links: ['fish_b2', 'fish_b4'],
      effects: {LifeFx.loot: 'fish_b3'}, branch: 'b'),
  LifeTreeNode('fish_b4', 'Corriente vieja',
      x: -1, y: 4, cost: 1, links: ['fish_b3', 'fish_b5'],
      effects: {LifeFx.legend: 'fish_b4'}, branch: 'b'),
  LifeTreeNode('fish_b5', 'Mareas del tiempo',
      x: -1, y: 5, cost: 1, links: ['fish_b4', 'fish_b6'],
      effects: {LifeFx.legend: 'fish_b5'},
      grants: {'mat:esquirla': 'fish_b5_2'}, branch: 'b', major: true),
  LifeTreeNode('fish_b6', 'Fondo de era',
      x: -1, y: 6, cost: 1, links: ['fish_b5', 'fish_b7'],
      effects: {LifeFx.loot: 'fish_b6'}, branch: 'b'),
  LifeTreeNode('fish_b7', 'Lance del Mañana',
      x: -1, y: 7, cost: 2, links: ['fish_b6', 'fish_b8'],
      effects: {LifeFx.legend: 'fish_b7'}, branch: 'b'),
  LifeTreeNode('fish_b8', 'Restos hundidos',
      x: -1, y: 8, cost: 2, links: ['fish_b7', 'fish_b9'],
      effects: {LifeFx.loot: 'fish_b8'},
      grants: {'mat:cristal': 'fish_b8_2'}, branch: 'b'),
  LifeTreeNode('fish_b9', 'Voz del fondo',
      x: -1, y: 9, cost: 2, links: ['fish_b8', 'fish_b10'],
      effects: {LifeFx.legend: 'fish_b9'}, branch: 'b'),
  LifeTreeNode('fish_b10', 'Lo que el agua guarda',
      x: -1, y: 10, cost: 3, links: ['fish_b9'],
      effects: {LifeFx.legend: 'fish_b10', LifeFx.loot: 'fish_b10_2'},
      grants: {'mat:prisma': 'fish_b10_3'}, branch: 'b', major: true, exclusive: 'cap'),
  LifeTreeNode('fish_c1', 'Regateo',
      x: 0, y: 1, cost: 1, links: ['fish_r', 'fish_c2'],
      effects: {LifeFx.sell: 'fish_c1'}, branch: 'c'),
  LifeTreeNode('fish_c2', 'Red remendada',
      x: 0, y: 2, cost: 1, links: ['fish_c1', 'fish_c3'],
      effects: {LifeFx.auto: 'fish_c2'}, branch: 'c'),
  LifeTreeNode('fish_c3', 'Puesto del muelle',
      x: 0, y: 3, cost: 1, links: ['fish_c2', 'fish_c4'],
      effects: {LifeFx.sell: 'fish_c3'},
      grants: {'gold': 'fish_c3_2'}, branch: 'c'),
  LifeTreeNode('fish_c4', 'Cebo prensado',
      x: 0, y: 4, cost: 1, links: ['fish_c3', 'fish_c5'],
      grants: {'craft:cebo': 'fish_c4'}, branch: 'c'),
  LifeTreeNode('fish_c5', 'Pescadores del pueblo',
      x: 0, y: 5, cost: 1, links: ['fish_c4', 'fish_c6'],
      effects: {LifeFx.xp: 'fish_c5'}, branch: 'c', major: true),
  LifeTreeNode('fish_c6', 'Red de pescador',
      x: 0, y: 6, cost: 1, links: ['fish_c5', 'fish_c7'],
      effects: {LifeFx.auto: 'fish_c6'}, branch: 'c'),
  LifeTreeNode('fish_c7', 'Lonja',
      x: 0, y: 7, cost: 2, links: ['fish_c6', 'fish_c8'],
      effects: {LifeFx.sell: 'fish_c7'},
      grants: {'gold': 'fish_c7_2'}, branch: 'c'),
  LifeTreeNode('fish_c8', 'Oficio heredado',
      x: 0, y: 8, cost: 2, links: ['fish_c7', 'fish_c9'],
      effects: {LifeFx.xp: 'fish_c8'},
      grants: {'craft:cebo': 'fish_c8_2'}, branch: 'c'),
  LifeTreeNode('fish_c9', 'Gremio del agua',
      x: 0, y: 9, cost: 2, links: ['fish_c8', 'fish_c10'],
      effects: {LifeFx.sell: 'fish_c9'}, branch: 'c'),
  LifeTreeNode('fish_c10', 'Maestro del lago',
      x: 0, y: 10, cost: 3, links: ['fish_c9'],
      effects: {LifeFx.auto: 'fish_c10', LifeFx.sell: 'fish_c10_2'},
      grants: {'gold': 'fish_c10_3'}, branch: 'c', major: true, exclusive: 'cap'),
  LifeTreeNode('fish_d1', 'Brazos de remo',
      x: 1, y: 1, cost: 1, links: ['fish_r', 'fish_d2'],
      effects: {LifeFx.hp: 'fish_d1'}, branch: 'd'),
  LifeTreeNode('fish_d2', 'Arpón del eco',
      x: 1, y: 2, cost: 1, links: ['fish_d1', 'fish_d3'],
      effects: {LifeFx.atk: 'fish_d2'}, branch: 'd'),
  LifeTreeNode('fish_d3', 'Piel de sal',
      x: 1, y: 3, cost: 1, links: ['fish_d2', 'fish_d4'],
      effects: {LifeFx.hp: 'fish_d3'}, branch: 'd'),
  LifeTreeNode('fish_d4', 'Anzuelo de hueso',
      x: 1, y: 4, cost: 1, links: ['fish_d3', 'fish_d5'],
      effects: {LifeFx.atk: 'fish_d4'},
      grants: {'weapon:1': 'fish_d4_2'}, branch: 'd'),
  LifeTreeNode('fish_d5', 'Marea en las venas',
      x: 1, y: 5, cost: 1, links: ['fish_d4', 'fish_d6'],
      effects: {LifeFx.hp: 'fish_d5'}, branch: 'd', major: true),
  LifeTreeNode('fish_d6', 'Filo mojado',
      x: 1, y: 6, cost: 1, links: ['fish_d5', 'fish_d7'],
      effects: {LifeFx.atk: 'fish_d6'}, branch: 'd'),
  LifeTreeNode('fish_d7', 'Calma del lago',
      x: 1, y: 7, cost: 2, links: ['fish_d6', 'fish_d8'],
      effects: {LifeFx.hp: 'fish_d7', LifeFx.atk: 'fish_d7_2'}, branch: 'd'),
  LifeTreeNode('fish_d8', 'Cazador de orillas',
      x: 1, y: 8, cost: 2, links: ['fish_d7', 'fish_d9'],
      effects: {LifeFx.atk: 'fish_d8'},
      grants: {'weapon:2': 'fish_d8_2'}, branch: 'd'),
  LifeTreeNode('fish_d9', 'Ancla del cuerpo',
      x: 1, y: 9, cost: 2, links: ['fish_d8', 'fish_d10'],
      effects: {LifeFx.hp: 'fish_d9'}, branch: 'd'),
  LifeTreeNode('fish_d10', 'Arponero del Mañana',
      x: 1, y: 10, cost: 3, links: ['fish_d9'],
      effects: {LifeFx.hp: 'fish_d10', LifeFx.atk: 'fish_d10_2'},
      grants: {'weapon:3': 'fish_d10_3'}, branch: 'd', major: true, exclusive: 'cap'),
  LifeTreeNode('fish_e1', 'Fuego de orilla',
      x: 2, y: 1, cost: 1, links: ['fish_r', 'fish_e2'],
      grants: {'meal:mojarra_nabo:0': 'fish_e1'}, branch: 'e'),
  LifeTreeNode('fish_e2', 'Sal y humo',
      x: 2, y: 2, cost: 1, links: ['fish_e1', 'fish_e3'],
      effects: {LifeFx.xp: 'fish_e2'}, branch: 'e'),
  LifeTreeNode('fish_e3', 'Caldo de espinas',
      x: 2, y: 3, cost: 1, links: ['fish_e2', 'fish_e4'],
      grants: {'meal:trucha_cebolla:0': 'fish_e3'}, branch: 'e'),
  LifeTreeNode('fish_e4', 'Mesa larga',
      x: 2, y: 4, cost: 1, links: ['fish_e3', 'fish_e5'],
      effects: {LifeFx.meal: 'fish_e4'}, branch: 'e'),
  LifeTreeNode('fish_e5', 'Ahumadero',
      x: 2, y: 5, cost: 1, links: ['fish_e4', 'fish_e6'],
      effects: {LifeFx.sell: 'fish_e5'},
      grants: {'bait:cebo_escarcha': 'fish_e5_2'}, branch: 'e', major: true),
  LifeTreeNode('fish_e6', 'Receta de la abuela',
      x: 2, y: 6, cost: 1, links: ['fish_e5', 'fish_e7'],
      grants: {'meal:trucha_cebolla:2': 'fish_e6'}, branch: 'e'),
  LifeTreeNode('fish_e7', 'Banquete del muelle',
      x: 2, y: 7, cost: 2, links: ['fish_e6', 'fish_e8'],
      effects: {LifeFx.meal: 'fish_e7'}, branch: 'e'),
  LifeTreeNode('fish_e8', 'Cebo de tormenta',
      x: 2, y: 8, cost: 2, links: ['fish_e7', 'fish_e9'],
      grants: {'bait:cebo_tormenta': 'fish_e8'}, branch: 'e'),
  LifeTreeNode('fish_e9', 'Sabor del recuerdo',
      x: 2, y: 9, cost: 2, links: ['fish_e8', 'fish_e10'],
      effects: {LifeFx.xp: 'fish_e9'}, branch: 'e'),
  LifeTreeNode('fish_e10', 'Mesa del último día',
      x: 2, y: 10, cost: 3, links: ['fish_e9'],
      effects: {LifeFx.meal: 'fish_e10'},
      grants: {'meal:trucha_cebolla:3': 'fish_e10_2', 'bait:senuelo_eco': 'fish_e10_3'}, branch: 'e', major: true, exclusive: 'cap'),
];

const _cultivo = <LifeTreeNode>[
  LifeTreeNode('farm_r', 'Granjero',
      x: 0, y: 0, cost: 0, links: ['farm_a1', 'farm_b1', 'farm_c1', 'farm_d1', 'farm_e1', 'farm_f1'],
      effects: {LifeFx.xp: 'farm_r'}, root: true),
  LifeTreeNode('farm_a1', 'Surco parejo',
      x: -2, y: 1, cost: 1, links: ['farm_r', 'farm_a2'],
      effects: {LifeFx.grow: 'farm_a1'}, branch: 'a'),
  LifeTreeNode('farm_a2', 'Riego profundo',
      x: -2, y: 2, cost: 1, links: ['farm_a1', 'farm_a3'],
      effects: {LifeFx.water: 'farm_a2'}, branch: 'a'),
  LifeTreeNode('farm_a3', 'Tierra viva',
      x: -2, y: 3, cost: 1, links: ['farm_a2', 'farm_a4'],
      effects: {LifeFx.grow: 'farm_a3'}, branch: 'a'),
  LifeTreeNode('farm_a4', 'Abono viejo',
      x: -2, y: 4, cost: 1, links: ['farm_a3', 'farm_a5'],
      effects: {LifeFx.water: 'farm_a4'},
      grants: {'craft:fibra': 'farm_a4_2'}, branch: 'a'),
  LifeTreeNode('farm_a5', 'Raíz del tiempo',
      x: -2, y: 5, cost: 1, links: ['farm_a4', 'farm_a6'],
      effects: {LifeFx.grow: 'farm_a5'}, branch: 'a', major: true),
  LifeTreeNode('farm_a6', 'Lluvia guardada',
      x: -2, y: 6, cost: 1, links: ['farm_a5', 'farm_a7'],
      effects: {LifeFx.water: 'farm_a6'}, branch: 'a'),
  LifeTreeNode('farm_a7', 'Estación larga',
      x: -2, y: 7, cost: 2, links: ['farm_a6', 'farm_a8'],
      effects: {LifeFx.grow: 'farm_a7', LifeFx.water: 'farm_a7_2'}, branch: 'a'),
  LifeTreeNode('farm_a8', 'Surco del ayer',
      x: -2, y: 8, cost: 2, links: ['farm_a7', 'farm_a9'],
      effects: {LifeFx.grow: 'farm_a8'},
      grants: {'craft:fibra': 'farm_a8_2'}, branch: 'a'),
  LifeTreeNode('farm_a9', 'Savia lenta',
      x: -2, y: 9, cost: 2, links: ['farm_a8', 'farm_a10'],
      effects: {LifeFx.water: 'farm_a9'}, branch: 'a'),
  LifeTreeNode('farm_a10', 'Tierra que recuerda',
      x: -2, y: 10, cost: 3, links: ['farm_a9'],
      effects: {LifeFx.grow: 'farm_a10', LifeFx.quality: 'farm_a10_2'}, branch: 'a', major: true, exclusive: 'cap'),
  LifeTreeNode('farm_b1', 'Mano fina',
      x: -1, y: 1, cost: 1, links: ['farm_r', 'farm_b2'],
      effects: {LifeFx.quality: 'farm_b1'}, branch: 'b'),
  LifeTreeNode('farm_b2', 'Doble surco',
      x: -1, y: 2, cost: 1, links: ['farm_b1', 'farm_b3'],
      effects: {LifeFx.extra: 'farm_b2'}, branch: 'b'),
  LifeTreeNode('farm_b3', 'Ojo de semilla',
      x: -1, y: 3, cost: 1, links: ['farm_b2', 'farm_b4'],
      effects: {LifeFx.seed: 'farm_b3'}, branch: 'b'),
  LifeTreeNode('farm_b4', 'Cesta llena',
      x: -1, y: 4, cost: 1, links: ['farm_b3', 'farm_b5'],
      effects: {LifeFx.extra: 'farm_b4'},
      grants: {'gold': 'farm_b4_2'}, branch: 'b'),
  LifeTreeNode('farm_b5', 'Cosecha del eco',
      x: -1, y: 5, cost: 1, links: ['farm_b4', 'farm_b6'],
      effects: {LifeFx.quality: 'farm_b5'}, branch: 'b', major: true),
  LifeTreeNode('farm_b6', 'Hallazgo dorado',
      x: -1, y: 6, cost: 1, links: ['farm_b5', 'farm_b7'],
      effects: {LifeFx.seed: 'farm_b6'},
      grants: {'mat:esquirla': 'farm_b6_2'}, branch: 'b'),
  LifeTreeNode('farm_b7', 'Manos propias',
      x: -1, y: 7, cost: 2, links: ['farm_b6', 'farm_b8'],
      effects: {LifeFx.extra: 'farm_b7'}, branch: 'b'),
  LifeTreeNode('farm_b8', 'Grano antiguo',
      x: -1, y: 8, cost: 2, links: ['farm_b7', 'farm_b9'],
      effects: {LifeFx.quality: 'farm_b8', LifeFx.seed: 'farm_b8_2'}, branch: 'b'),
  LifeTreeNode('farm_b9', 'Granero lleno',
      x: -1, y: 9, cost: 2, links: ['farm_b8', 'farm_b10'],
      effects: {LifeFx.extra: 'farm_b9'}, branch: 'b'),
  LifeTreeNode('farm_b10', 'Cosecha de las eras',
      x: -1, y: 10, cost: 3, links: ['farm_b9'],
      effects: {LifeFx.quality: 'farm_b10', LifeFx.extra: 'farm_b10_2'},
      grants: {'mat:cristal': 'farm_b10_3'}, branch: 'b', major: true, exclusive: 'cap'),
  LifeTreeNode('farm_c1', 'Puesto propio',
      x: 0, y: 1, cost: 1, links: ['farm_r', 'farm_c2'],
      effects: {LifeFx.sell: 'farm_c1'}, branch: 'c'),
  LifeTreeNode('farm_c2', 'Mano derecha',
      x: 0, y: 2, cost: 1, links: ['farm_c1', 'farm_c3'],
      effects: {LifeFx.helper: 'farm_c2'}, branch: 'c'),
  LifeTreeNode('farm_c3', 'Tabla tratada',
      x: 0, y: 3, cost: 1, links: ['farm_c2', 'farm_c4'],
      grants: {'craft:tabla': 'farm_c3'}, branch: 'c'),
  LifeTreeNode('farm_c4', 'Mercado del pueblo',
      x: 0, y: 4, cost: 1, links: ['farm_c3', 'farm_c5'],
      effects: {LifeFx.sell: 'farm_c4'},
      grants: {'gold': 'farm_c4_2'}, branch: 'c'),
  LifeTreeNode('farm_c5', 'Ayudante fiel',
      x: 0, y: 5, cost: 1, links: ['farm_c4', 'farm_c6'],
      effects: {LifeFx.helper: 'farm_c5'}, branch: 'c', major: true),
  LifeTreeNode('farm_c6', 'Oficio compartido',
      x: 0, y: 6, cost: 1, links: ['farm_c5', 'farm_c7'],
      effects: {LifeFx.xp: 'farm_c6'}, branch: 'c'),
  LifeTreeNode('farm_c7', 'Cuadrilla',
      x: 0, y: 7, cost: 2, links: ['farm_c6', 'farm_c8'],
      effects: {LifeFx.helper: 'farm_c7'}, branch: 'c'),
  LifeTreeNode('farm_c8', 'Feria de cosecha',
      x: 0, y: 8, cost: 2, links: ['farm_c7', 'farm_c9'],
      effects: {LifeFx.sell: 'farm_c8'},
      grants: {'gold': 'farm_c8_2'}, branch: 'c'),
  LifeTreeNode('farm_c9', 'Libro de la granja',
      x: 0, y: 9, cost: 2, links: ['farm_c8', 'farm_c10'],
      effects: {LifeFx.xp: 'farm_c9'}, branch: 'c'),
  LifeTreeNode('farm_c10', 'Señor de la huerta',
      x: 0, y: 10, cost: 3, links: ['farm_c9'],
      effects: {LifeFx.helper: 'farm_c10', LifeFx.sell: 'farm_c10_2'},
      grants: {'craft:tabla': 'farm_c10_3'}, branch: 'c', major: true, exclusive: 'cap'),
  LifeTreeNode('farm_d1', 'Espalda de surco',
      x: 1, y: 1, cost: 1, links: ['farm_r', 'farm_d2'],
      effects: {LifeFx.hp: 'farm_d1'}, branch: 'd'),
  LifeTreeNode('farm_d2', 'Hoz templada',
      x: 1, y: 2, cost: 1, links: ['farm_d1', 'farm_d3'],
      effects: {LifeFx.atk: 'farm_d2'}, branch: 'd'),
  LifeTreeNode('farm_d3', 'Manos de tierra',
      x: 1, y: 3, cost: 1, links: ['farm_d2', 'farm_d4'],
      effects: {LifeFx.hp: 'farm_d3'}, branch: 'd'),
  LifeTreeNode('farm_d4', 'Horquilla de guerra',
      x: 1, y: 4, cost: 1, links: ['farm_d3', 'farm_d5'],
      effects: {LifeFx.atk: 'farm_d4'},
      grants: {'weapon:1': 'farm_d4_2'}, branch: 'd'),
  LifeTreeNode('farm_d5', 'Raíz firme',
      x: 1, y: 5, cost: 1, links: ['farm_d4', 'farm_d6'],
      effects: {LifeFx.hp: 'farm_d5'}, branch: 'd', major: true),
  LifeTreeNode('farm_d6', 'Filo de siega',
      x: 1, y: 6, cost: 1, links: ['farm_d5', 'farm_d7'],
      effects: {LifeFx.atk: 'farm_d6'}, branch: 'd'),
  LifeTreeNode('farm_d7', 'Cuerpo de estación',
      x: 1, y: 7, cost: 2, links: ['farm_d6', 'farm_d8'],
      effects: {LifeFx.hp: 'farm_d7', LifeFx.atk: 'farm_d7_2'}, branch: 'd'),
  LifeTreeNode('farm_d8', 'Guardián del campo',
      x: 1, y: 8, cost: 2, links: ['farm_d7', 'farm_d9'],
      effects: {LifeFx.atk: 'farm_d8'},
      grants: {'weapon:2': 'farm_d8_2'}, branch: 'd'),
  LifeTreeNode('farm_d9', 'Tronco viejo',
      x: 1, y: 9, cost: 2, links: ['farm_d8', 'farm_d10'],
      effects: {LifeFx.hp: 'farm_d9'}, branch: 'd'),
  LifeTreeNode('farm_d10', 'Segador del ocaso',
      x: 1, y: 10, cost: 3, links: ['farm_d9'],
      effects: {LifeFx.hp: 'farm_d10', LifeFx.atk: 'farm_d10_2'},
      grants: {'weapon:3': 'farm_d10_3'}, branch: 'd', major: true, exclusive: 'cap'),
  LifeTreeNode('farm_e1', 'Primer fuego',
      x: 2, y: 1, cost: 1, links: ['farm_r', 'farm_e2'],
      grants: {'meal:sopa_nabo:0': 'farm_e1'}, branch: 'e'),
  LifeTreeNode('farm_e2', 'Olla de hierro',
      x: 2, y: 2, cost: 1, links: ['farm_e1', 'farm_e3'],
      effects: {LifeFx.xp: 'farm_e2'}, branch: 'e'),
  LifeTreeNode('farm_e3', 'Pan del alba',
      x: 2, y: 3, cost: 1, links: ['farm_e2', 'farm_e4'],
      grants: {'meal:pan_dorado:0': 'farm_e3'}, branch: 'e'),
  LifeTreeNode('farm_e4', 'Cocina lenta',
      x: 2, y: 4, cost: 1, links: ['farm_e3', 'farm_e5'],
      effects: {LifeFx.meal: 'farm_e4'}, branch: 'e'),
  LifeTreeNode('farm_e5', 'Despensa',
      x: 2, y: 5, cost: 1, links: ['farm_e4', 'farm_e6'],
      grants: {'meal:guiso_calabaza:1': 'farm_e5'}, branch: 'e', major: true),
  LifeTreeNode('farm_e6', 'Especias del camino',
      x: 2, y: 6, cost: 1, links: ['farm_e5', 'farm_e7'],
      effects: {LifeFx.quality: 'farm_e6'}, branch: 'e'),
  LifeTreeNode('farm_e7', 'Mesa del pueblo',
      x: 2, y: 7, cost: 2, links: ['farm_e6', 'farm_e8'],
      effects: {LifeFx.meal: 'farm_e7'}, branch: 'e'),
  LifeTreeNode('farm_e8', 'Recetario antiguo',
      x: 2, y: 8, cost: 2, links: ['farm_e7', 'farm_e9'],
      grants: {'meal:ensalada_runica:2': 'farm_e8'}, branch: 'e'),
  LifeTreeNode('farm_e9', 'Sobremesa',
      x: 2, y: 9, cost: 2, links: ['farm_e8', 'farm_e10'],
      effects: {LifeFx.xp: 'farm_e9'}, branch: 'e'),
  LifeTreeNode('farm_e10', 'Banquete de la memoria',
      x: 2, y: 10, cost: 3, links: ['farm_e9'],
      effects: {LifeFx.meal: 'farm_e10'},
      grants: {'meal:caldo_invierno:3': 'farm_e10_2'}, branch: 'e', major: true, exclusive: 'cap'),
  // ANIMALES (animals.md § 8): care, hay, quality, parts and doubles,
  // the legendary products at the top.
  LifeTreeNode('farm_f1', 'Mano tibia',
      x: 3, y: 1, cost: 1, links: ['farm_r', 'farm_f2'],
      effects: {LifeFx.petCare: 'farm_f1'}, branch: 'f'),
  LifeTreeNode('farm_f2', 'Fardo ordenado',
      x: 3, y: 2, cost: 1, links: ['farm_f1', 'farm_f3'],
      effects: {LifeFx.haySilo: 'farm_f2'}, branch: 'f'),
  LifeTreeNode('farm_f3', 'Ojo de pastor',
      x: 3, y: 3, cost: 1, links: ['farm_f2', 'farm_f4'],
      effects: {LifeFx.animalQuality: 'farm_f3'}, branch: 'f'),
  LifeTreeNode('farm_f4', 'Pluma suelta',
      x: 3, y: 4, cost: 1, links: ['farm_f3', 'farm_f5'],
      effects: {LifeFx.partDrop: 'farm_f4'}, branch: 'f'),
  LifeTreeNode('farm_f5', 'Rebaño que recuerda',
      x: 3, y: 5, cost: 1, links: ['farm_f4', 'farm_f6'],
      effects: {LifeFx.partDrop: 'farm_f5'}, branch: 'f', major: true),
  LifeTreeNode('farm_f6', 'Cepillo de cerda',
      x: 3, y: 6, cost: 1, links: ['farm_f5', 'farm_f7'],
      effects: {LifeFx.partDrop: 'farm_f6'}, branch: 'f'),
  LifeTreeNode('farm_f7', 'Muda del eco',
      x: 3, y: 7, cost: 2, links: ['farm_f6', 'farm_f8'],
      effects: {LifeFx.partDrop: 'farm_f7'}, branch: 'f'),
  LifeTreeNode('farm_f8', 'Granero del ayer',
      x: 3, y: 8, cost: 2, links: ['farm_f7', 'farm_f9'],
      effects: {LifeFx.haySilo: 'farm_f8', LifeFx.petCare: 'farm_f8_2'},
      branch: 'f'),
  LifeTreeNode('farm_f9', 'Pastor del tiempo',
      x: 3, y: 9, cost: 2, links: ['farm_f8', 'farm_f10'],
      effects: {LifeFx.animalQuality: 'farm_f9'}, branch: 'f'),
  LifeTreeNode('farm_f10', 'Corral de las eras',
      x: 3, y: 10, cost: 3, links: ['farm_f9'],
      effects: {LifeFx.animalLegend: 'farm_f10', LifeFx.animalQuality: 'farm_f10_2'},
      branch: 'f', major: true, exclusive: 'cap'),
];

const _herreria = <LifeTreeNode>[
  LifeTreeNode('smith_r', 'Aprendiz de fragua',
      x: 0, y: 0, cost: 0, links: ['smith_a1', 'smith_b1', 'smith_c1', 'smith_d1', 'smith_e1'],
      effects: {LifeFx.xp: 'smith_r'}, root: true),
  LifeTreeNode('smith_a1', 'Martillo justo',
      x: -2, y: 1, cost: 1, links: ['smith_r', 'smith_a2'],
      effects: {LifeFx.forge: 'smith_a1'}, branch: 'a'),
  LifeTreeNode('smith_a2', 'Golpe medido',
      x: -2, y: 2, cost: 1, links: ['smith_a1', 'smith_a3'],
      effects: {LifeFx.forge: 'smith_a2'}, branch: 'a'),
  LifeTreeNode('smith_a3', 'Fuelle viejo',
      x: -2, y: 3, cost: 1, links: ['smith_a2', 'smith_a4'],
      effects: {LifeFx.forge: 'smith_a3'},
      grants: {'ore:ore_copper': 'smith_a3_2'}, branch: 'a'),
  LifeTreeNode('smith_a4', 'Yunque antiguo',
      x: -2, y: 4, cost: 1, links: ['smith_a3', 'smith_a5'],
      effects: {LifeFx.forge: 'smith_a4'}, branch: 'a'),
  LifeTreeNode('smith_a5', 'Carbón de roble',
      x: -2, y: 5, cost: 1, links: ['smith_a4', 'smith_a6'],
      effects: {LifeFx.forge: 'smith_a5'},
      grants: {'ore:ingot_copper': 'smith_a5_2'}, branch: 'a', major: true),
  LifeTreeNode('smith_a6', 'Temple paciente',
      x: -2, y: 6, cost: 1, links: ['smith_a5', 'smith_a7'],
      effects: {LifeFx.forge: 'smith_a6'}, branch: 'a'),
  LifeTreeNode('smith_a7', 'Brasa constante',
      x: -2, y: 7, cost: 2, links: ['smith_a6', 'smith_a8'],
      effects: {LifeFx.forge: 'smith_a7'}, branch: 'a'),
  LifeTreeNode('smith_a8', 'Marca del maestro',
      x: -2, y: 8, cost: 2, links: ['smith_a7', 'smith_a9'],
      effects: {LifeFx.forge: 'smith_a8'},
      grants: {'ore:ingot_bronze': 'smith_a8_2'}, branch: 'a'),
  LifeTreeNode('smith_a9', 'Ritmo del yunque',
      x: -2, y: 9, cost: 2, links: ['smith_a8', 'smith_a10'],
      effects: {LifeFx.forge: 'smith_a9'}, branch: 'a'),
  LifeTreeNode('smith_a10', 'Fragua sin tiempo',
      x: -2, y: 10, cost: 3, links: ['smith_a9'],
      effects: {LifeFx.forge: 'smith_a10', LifeFx.xp: 'smith_a10_2'}, branch: 'a', major: true, exclusive: 'cap'),
  LifeTreeNode('smith_b1', 'Ojo de veta',
      x: -1, y: 1, cost: 1, links: ['smith_r', 'smith_b2'],
      grants: {'ore:ore_copper': 'smith_b1'}, branch: 'b'),
  LifeTreeNode('smith_b2', 'Lingotera',
      x: -1, y: 2, cost: 1, links: ['smith_b1', 'smith_b3'],
      grants: {'ore:ingot_copper': 'smith_b2'}, branch: 'b'),
  LifeTreeNode('smith_b3', 'Ámbar escondido',
      x: -1, y: 3, cost: 1, links: ['smith_b2', 'smith_b4'],
      grants: {'ore:rare_amber': 'smith_b3'}, branch: 'b'),
  LifeTreeNode('smith_b4', 'Mena de bronce',
      x: -1, y: 4, cost: 1, links: ['smith_b3', 'smith_b5'],
      grants: {'ore:ore_bronze': 'smith_b4'}, branch: 'b'),
  LifeTreeNode('smith_b5', 'Esquirla del pozo',
      x: -1, y: 5, cost: 1, links: ['smith_b4', 'smith_b6'],
      grants: {'mat:esquirla': 'smith_b5'}, branch: 'b', major: true),
  LifeTreeNode('smith_b6', 'Escarcha en piedra',
      x: -1, y: 6, cost: 1, links: ['smith_b5', 'smith_b7'],
      grants: {'ore:ore_frost': 'smith_b6'}, branch: 'b'),
  LifeTreeNode('smith_b7', 'Engranaje perdido',
      x: -1, y: 7, cost: 2, links: ['smith_b6', 'smith_b8'],
      grants: {'ore:rare_cog': 'smith_b7'}, branch: 'b'),
  LifeTreeNode('smith_b8', 'Cristal del socavón',
      x: -1, y: 8, cost: 2, links: ['smith_b7', 'smith_b9'],
      grants: {'mat:cristal': 'smith_b8'}, branch: 'b'),
  LifeTreeNode('smith_b9', 'Brasa de la montaña',
      x: -1, y: 9, cost: 2, links: ['smith_b8', 'smith_b10'],
      grants: {'ore:ore_ember': 'smith_b9'}, branch: 'b'),
  LifeTreeNode('smith_b10', 'Corazón de la mina',
      x: -1, y: 10, cost: 3, links: ['smith_b9'],
      grants: {'ore:ingot_echo': 'smith_b10', 'mat:prisma': 'smith_b10_2'}, branch: 'b', major: true, exclusive: 'cap'),
  LifeTreeNode('smith_c1', 'Primera hoja',
      x: 0, y: 1, cost: 1, links: ['smith_r', 'smith_c2'],
      grants: {'weapon:1': 'smith_c1'}, branch: 'c'),
  LifeTreeNode('smith_c2', 'Filo del pasado',
      x: 0, y: 2, cost: 1, links: ['smith_c1', 'smith_c3'],
      effects: {LifeFx.atk: 'smith_c2'}, branch: 'c'),
  LifeTreeNode('smith_c3', 'Ojo de oficio',
      x: 0, y: 3, cost: 1, links: ['smith_c2', 'smith_c4'],
      effects: {LifeFx.xp: 'smith_c3'}, branch: 'c'),
  LifeTreeNode('smith_c4', 'Arma templada',
      x: 0, y: 4, cost: 1, links: ['smith_c3', 'smith_c5'],
      grants: {'weapon:2': 'smith_c4'}, branch: 'c'),
  LifeTreeNode('smith_c5', 'Afilado',
      x: 0, y: 5, cost: 1, links: ['smith_c4', 'smith_c6'],
      effects: {LifeFx.atk: 'smith_c5'}, branch: 'c', major: true),
  LifeTreeNode('smith_c6', 'Encargo del cuartel',
      x: 0, y: 6, cost: 1, links: ['smith_c5', 'smith_c7'],
      grants: {'gold': 'smith_c6'}, branch: 'c'),
  LifeTreeNode('smith_c7', 'Arma del eco',
      x: 0, y: 7, cost: 2, links: ['smith_c6', 'smith_c8'],
      grants: {'weapon:3': 'smith_c7'}, branch: 'c'),
  LifeTreeNode('smith_c8', 'Acero recordado',
      x: 0, y: 8, cost: 2, links: ['smith_c7', 'smith_c9'],
      effects: {LifeFx.atk: 'smith_c8'}, branch: 'c'),
  LifeTreeNode('smith_c9', 'Prisma de taller',
      x: 0, y: 9, cost: 2, links: ['smith_c8', 'smith_c10'],
      grants: {'mat:prisma': 'smith_c9'}, branch: 'c'),
  LifeTreeNode('smith_c10', 'Obra maestra',
      x: 0, y: 10, cost: 3, links: ['smith_c9'],
      effects: {LifeFx.atk: 'smith_c10'},
      grants: {'weapon:3': 'smith_c10_2', 'mat:prisma': 'smith_c10_3'}, branch: 'c', major: true, exclusive: 'cap'),
  LifeTreeNode('smith_d1', 'Temple',
      x: 1, y: 1, cost: 1, links: ['smith_r', 'smith_d2'],
      effects: {LifeFx.hp: 'smith_d1'}, branch: 'd'),
  LifeTreeNode('smith_d2', 'Coraza de chispa',
      x: 1, y: 2, cost: 1, links: ['smith_d1', 'smith_d3'],
      effects: {LifeFx.hp: 'smith_d2'}, branch: 'd'),
  LifeTreeNode('smith_d3', 'Mecanismo vivo',
      x: 1, y: 3, cost: 1, links: ['smith_d2', 'smith_d4'],
      effects: {LifeFx.hp: 'smith_d3', LifeFx.atk: 'smith_d3_2'}, branch: 'd'),
  LifeTreeNode('smith_d4', 'Brazo de fragua',
      x: 1, y: 4, cost: 1, links: ['smith_d3', 'smith_d5'],
      effects: {LifeFx.atk: 'smith_d4'}, branch: 'd'),
  LifeTreeNode('smith_d5', 'Resorte del tiempo',
      x: 1, y: 5, cost: 1, links: ['smith_d4', 'smith_d6'],
      effects: {LifeFx.hp: 'smith_d5'}, branch: 'd', major: true),
  LifeTreeNode('smith_d6', 'Engranaje del pecho',
      x: 1, y: 6, cost: 1, links: ['smith_d5', 'smith_d7'],
      effects: {LifeFx.hp: 'smith_d6'}, branch: 'd'),
  LifeTreeNode('smith_d7', 'Pulso de hierro',
      x: 1, y: 7, cost: 2, links: ['smith_d6', 'smith_d8'],
      effects: {LifeFx.atk: 'smith_d7'}, branch: 'd'),
  LifeTreeNode('smith_d8', 'Malla antigua',
      x: 1, y: 8, cost: 2, links: ['smith_d7', 'smith_d9'],
      effects: {LifeFx.hp: 'smith_d8'}, branch: 'd'),
  LifeTreeNode('smith_d9', 'Fuerza remachada',
      x: 1, y: 9, cost: 2, links: ['smith_d8', 'smith_d10'],
      effects: {LifeFx.atk: 'smith_d9'}, branch: 'd'),
  LifeTreeNode('smith_d10', 'Corazón de engranajes',
      x: 1, y: 10, cost: 3, links: ['smith_d9'],
      effects: {LifeFx.hp: 'smith_d10', LifeFx.atk: 'smith_d10_2'}, branch: 'd', major: true, exclusive: 'cap'),
  LifeTreeNode('smith_e1', 'Taller abierto',
      x: 2, y: 1, cost: 1, links: ['smith_r', 'smith_e2'],
      effects: {LifeFx.xp: 'smith_e1'}, branch: 'e'),
  LifeTreeNode('smith_e2', 'Clavos para el pueblo',
      x: 2, y: 2, cost: 1, links: ['smith_e1', 'smith_e3'],
      grants: {'craft:tabla': 'smith_e2'}, branch: 'e'),
  LifeTreeNode('smith_e3', 'Encargos menores',
      x: 2, y: 3, cost: 1, links: ['smith_e2', 'smith_e4'],
      grants: {'gold': 'smith_e3'}, branch: 'e'),
  LifeTreeNode('smith_e4', 'Aprendices',
      x: 2, y: 4, cost: 1, links: ['smith_e3', 'smith_e5'],
      effects: {LifeFx.xp: 'smith_e4'}, branch: 'e'),
  LifeTreeNode('smith_e5', 'Herramientas del pueblo',
      x: 2, y: 5, cost: 1, links: ['smith_e4', 'smith_e6'],
      grants: {'craft:fibra': 'smith_e5', 'craft:cebo': 'smith_e5_2'}, branch: 'e', major: true),
  LifeTreeNode('smith_e6', 'Fama de la fragua',
      x: 2, y: 6, cost: 1, links: ['smith_e5', 'smith_e7'],
      grants: {'gold': 'smith_e6'}, branch: 'e'),
  LifeTreeNode('smith_e7', 'Escuela de oficio',
      x: 2, y: 7, cost: 2, links: ['smith_e6', 'smith_e8'],
      effects: {LifeFx.xp: 'smith_e7'}, branch: 'e'),
  LifeTreeNode('smith_e8', 'Ancla de la fragua',
      x: 2, y: 8, cost: 2, links: ['smith_e7', 'smith_e9'],
      grants: {'mat:ancla': 'smith_e8'}, branch: 'e'),
  LifeTreeNode('smith_e9', 'Herrero del pueblo',
      x: 2, y: 9, cost: 2, links: ['smith_e8', 'smith_e10'],
      effects: {LifeFx.forge: 'smith_e9'},
      grants: {'gold': 'smith_e9_2'}, branch: 'e'),
  LifeTreeNode('smith_e10', 'Legado de la fragua',
      x: 2, y: 10, cost: 3, links: ['smith_e9'],
      effects: {LifeFx.xp: 'smith_e10'},
      grants: {'gold': 'smith_e10_2', 'mat:ancla': 'smith_e10_3'}, branch: 'e', major: true, exclusive: 'cap'),
];

/// Default numbers of every node effect and grant (Balance keys).
const kLifeTreeTuning = <String, num>{
  'fish_r': 0.05,
  'fish_a1': 0.04,
  'fish_a2': 0.05,
  'fish_a3': 0.04,
  'fish_a4': 0.05,
  'fish_a4_2': 10,
  'fish_a5': 0.05,
  'fish_a6': 0.06,
  'fish_a7': 0.06,
  'fish_a7_2': 0.05,
  'fish_a8': 0.06,
  'fish_a8_2': 8,
  'fish_a9': 0.08,
  'fish_a10': 0.12,
  'fish_a10_2': 0.12,
  'fish_a10_3': 1,
  'fish_b1': 0.08,
  'fish_b2': 0.05,
  'fish_b3': 0.1,
  'fish_b4': 0.06,
  'fish_b5': 0.08,
  'fish_b5_2': 3,
  'fish_b6': 0.12,
  'fish_b7': 0.1,
  'fish_b8': 0.15,
  'fish_b8_2': 2,
  'fish_b9': 0.12,
  'fish_b10': 0.2,
  'fish_b10_2': 0.25,
  'fish_b10_3': 2,
  'fish_c1': 0.05,
  'fish_c2': 1,
  'fish_c3': 0.05,
  'fish_c3_2': 150,
  'fish_c4': 6,
  'fish_c5': 0.08,
  'fish_c6': 1,
  'fish_c7': 0.08,
  'fish_c7_2': 400,
  'fish_c8': 0.1,
  'fish_c8_2': 12,
  'fish_c9': 0.1,
  'fish_c10': 2,
  'fish_c10_2': 0.15,
  'fish_c10_3': 1500,
  'fish_d1': 0.02,
  'fish_d2': 0.02,
  'fish_d3': 0.02,
  'fish_d4': 0.02,
  'fish_d4_2': 1,
  'fish_d5': 0.03,
  'fish_d6': 0.03,
  'fish_d7': 0.03,
  'fish_d7_2': 0.02,
  'fish_d8': 0.03,
  'fish_d8_2': 1,
  'fish_d9': 0.04,
  'fish_d10': 0.06,
  'fish_d10_2': 0.06,
  'fish_d10_3': 1,
  'fish_e1': 2,
  'fish_e2': 0.05,
  'fish_e3': 2,
  'fish_e4': 1,
  'fish_e5': 0.05,
  'fish_e5_2': 6,
  'fish_e6': 2,
  'fish_e7': 1,
  'fish_e8': 6,
  'fish_e9': 0.1,
  'fish_e10': 2,
  'fish_e10_2': 3,
  'fish_e10_3': 5,
  'farm_r': 0.05,
  'farm_a1': 0.05,
  'farm_a2': 0.15,
  'farm_a3': 0.06,
  'farm_a4': 0.15,
  'farm_a4_2': 6,
  'farm_a5': 0.08,
  'farm_a6': 0.2,
  'farm_a7': 0.08,
  'farm_a7_2': 0.1,
  'farm_a8': 0.1,
  'farm_a8_2': 12,
  'farm_a9': 0.25,
  'farm_a10': 0.15,
  'farm_a10_2': 0.2,
  'farm_b1': 0.05,
  'farm_b2': 0.05,
  'farm_b3': 0.1,
  'farm_b4': 0.05,
  'farm_b4_2': 150,
  'farm_b5': 0.1,
  'farm_b6': 0.15,
  'farm_b6_2': 3,
  'farm_b7': 0.08,
  'farm_b8': 0.1,
  'farm_b8_2': 0.1,
  'farm_b9': 0.08,
  'farm_b10': 0.25,
  'farm_b10_2': 0.12,
  'farm_b10_3': 3,
  'farm_c1': 0.05,
  'farm_c2': 0.15,
  'farm_c3': 6,
  'farm_c4': 0.05,
  'farm_c4_2': 250,
  'farm_c5': 0.15,
  'farm_c6': 0.08,
  'farm_c7': 0.2,
  'farm_c8': 0.08,
  'farm_c8_2': 600,
  'farm_c9': 0.1,
  'farm_c10': 0.3,
  'farm_c10_2': 0.15,
  'farm_c10_3': 20,
  'farm_d1': 0.02,
  'farm_d2': 0.02,
  'farm_d3': 0.02,
  'farm_d4': 0.02,
  'farm_d4_2': 1,
  'farm_d5': 0.03,
  'farm_d6': 0.03,
  'farm_d7': 0.03,
  'farm_d7_2': 0.02,
  'farm_d8': 0.03,
  'farm_d8_2': 1,
  'farm_d9': 0.04,
  'farm_d10': 0.06,
  'farm_d10_2': 0.06,
  'farm_d10_3': 1,
  'farm_e1': 3,
  'farm_e2': 0.05,
  'farm_e3': 3,
  'farm_e4': 1,
  'farm_e5': 2,
  'farm_e6': 0.05,
  'farm_e7': 1,
  'farm_e8': 2,
  'farm_e9': 0.1,
  'farm_e10': 2,
  'farm_e10_2': 3,
  'farm_f1': 0.15,
  'farm_f2': 20,
  'farm_f3': 0.05,
  'farm_f8': 30,
  'farm_f8_2': 0.15,
  'farm_f9': 0.08,
  'farm_f10': 0.02,
  'farm_f10_2': 0.1,
  'smith_r': 0.05,
  'smith_a1': 0.03,
  'smith_a2': 0.03,
  'smith_a3': 0.03,
  'smith_a3_2': 10,
  'smith_a4': 0.04,
  'smith_a5': 0.04,
  'smith_a5_2': 5,
  'smith_a6': 0.04,
  'smith_a7': 0.05,
  'smith_a8': 0.05,
  'smith_a8_2': 5,
  'smith_a9': 0.05,
  'smith_a10': 0.08,
  'smith_a10_2': 0.15,
  'smith_b1': 15,
  'smith_b2': 8,
  'smith_b3': 2,
  'smith_b4': 12,
  'smith_b5': 4,
  'smith_b6': 12,
  'smith_b7': 2,
  'smith_b8': 3,
  'smith_b9': 12,
  'smith_b10': 6,
  'smith_b10_2': 3,
  'smith_c1': 1,
  'smith_c2': 0.02,
  'smith_c3': 0.05,
  'smith_c4': 1,
  'smith_c5': 0.02,
  'smith_c6': 600,
  'smith_c7': 1,
  'smith_c8': 0.03,
  'smith_c9': 1,
  'smith_c10': 0.05,
  'smith_c10_2': 1,
  'smith_c10_3': 2,
  'smith_d1': 0.02,
  'smith_d2': 0.02,
  'smith_d3': 0.02,
  'smith_d3_2': 0.01,
  'smith_d4': 0.02,
  'smith_d5': 0.03,
  'smith_d6': 0.03,
  'smith_d7': 0.03,
  'smith_d8': 0.03,
  'smith_d9': 0.03,
  'smith_d10': 0.07,
  'smith_d10_2': 0.05,
  'smith_e1': 0.05,
  'smith_e2': 6,
  'smith_e3': 300,
  'smith_e4': 0.08,
  'smith_e5': 10,
  'smith_e5_2': 10,
  'smith_e6': 800,
  'smith_e7': 0.1,
  'smith_e8': 1,
  'smith_e9': 0.03,
  'smith_e9_2': 1200,
  'smith_e10': 0.2,
  'smith_e10_2': 3000,
  'smith_e10_3': 2,
  // Sub-path mechanics, tiers 4–7 (life_trees_v2.md § 2.1): main path
  // A = `<id>x`, second sub-path B = `<id>s`, companion = `<id>y`.
  'fish_a4x': 0.06,
  'fish_a5x': 0.06,
  'fish_a6x': 0.08,
  'fish_a7x': 0.1,
  'fish_a4s': 0.04,
  'fish_a5s': 0.04,
  'fish_a6s': 0.05,
  'fish_a7s': 0.07,
  'fish_b4x': 0.1,
  'fish_b5x': 0.1,
  'fish_b6x': 0.15,
  'fish_b7x': 0.2,
  'fish_b4s': 0.06,
  'fish_b5s': 0.06,
  'fish_b6s': 0.08,
  'fish_b7s': 0.1,
  'fish_c4x': 0.04,
  'fish_c5x': 0.04,
  'fish_c6x': 0.05,
  'fish_c7x': 0.07,
  'fish_c4s': 0.25,
  'fish_c5s': 0.25,
  'fish_c6s': 0.25,
  'fish_c7s': 0.25,
  'fish_d4x': 0.06,
  'fish_d5x': 0.06,
  'fish_d6x': 0.08,
  'fish_d7x': 0.1,
  'fish_d4s': 0.04,
  'fish_d5s': 0.04,
  'fish_d6s': 0.06,
  'fish_d7s': 0.06,
  'fish_e4x': 0.08,
  'fish_e5x': 0.08,
  'fish_e6x': 0.1,
  'fish_e7x': 0.14,
  'fish_e4s': 0.02,
  'fish_e5s': 0.02,
  'fish_e6s': 0.03,
  'fish_e7s': 0.03,
  'farm_a4x': 1,
  'farm_a5y': 0.1,
  'farm_a6y': 0.1,
  'farm_a7x': 1,
  'farm_a4s': 0.04,
  'farm_a5s': 0.04,
  'farm_a6s': 0.05,
  'farm_a7s': 0.07,
  'farm_b4x': 0.08,
  'farm_b5x': 0.08,
  'farm_b6x': 0.1,
  'farm_b7x': 0.14,
  'farm_b4s': 0.02,
  'farm_b5s': 0.02,
  'farm_b6s': 0.03,
  'farm_b7s': 0.03,
  'farm_c4x': 0.15,
  'farm_c5x': 0.15,
  'farm_c6x': 0.2,
  'farm_c7x': 0.25,
  'farm_c4s': 1,
  'farm_c5y': 0.03,
  'farm_c6y': 0.03,
  'farm_c7s': 1,
  'farm_c5r': 1,
  'farm_c6r': 1,
  'farm_c7r': 1,
  'farm_d4x': 0.05,
  'farm_d5x': 0.05,
  'farm_d6x': 0.07,
  'farm_d7x': 0.08,
  'farm_d4s': 0.15,
  'farm_d5s': 0.15,
  'farm_d6s': 0.2,
  'farm_d7s': 0.25,
  'farm_e4x': 0.05,
  'farm_e5x': 0.05,
  'farm_e6x': 0.07,
  'farm_e7x': 0.08,
  'farm_e4s': 1,
  'farm_e5s': 1,
  'farm_e6s': 1,
  'farm_e7s': 1,
  // ANIMALES sub-paths: parts (main) or double products (second).
  'farm_f4x': 0.15,
  'farm_f5x': 0.15,
  'farm_f6x': 0.2,
  'farm_f7x': 0.25,
  'farm_f4s': 0.04,
  'farm_f5s': 0.04,
  'farm_f6s': 0.05,
  'farm_f7s': 0.07,
  'smith_a4x': 0.03,
  'smith_a5x': 0.03,
  'smith_a6x': 0.04,
  'smith_a7x': 0.05,
  'smith_a4s': 0.06,
  'smith_a5s': 0.06,
  'smith_a6s': 0.08,
  'smith_a7s': 0.1,
  'smith_b4x': 1,
  'smith_b5y': 0.05,
  'smith_b6y': 0.05,
  'smith_b7x': 1,
  'smith_b4s': 0.05,
  'smith_b5s': 0.05,
  'smith_b6s': 0.07,
  'smith_b7s': 0.08,
  'smith_c4x': 0.06,
  'smith_c5x': 0.06,
  'smith_c6x': 0.08,
  'smith_c7x': 0.1,
  'smith_c4s': 0.1,
  'smith_c5s': 0.1,
  'smith_c6s': 0.15,
  'smith_c7s': 0.2,
  'smith_d4x': 0.06,
  'smith_d5x': 0.06,
  'smith_d6x': 0.08,
  'smith_d7x': 0.1,
  'smith_d4s': 4,
  'smith_d5s': 2,
  'smith_d6s': 2,
  'smith_d7s': 4,
  'smith_e4x': 0.08,
  'smith_e5x': 0.08,
  'smith_e6x': 0.1,
  'smith_e7x': 0.14,
  'smith_e4s': 0.05,
  'smith_e5s': 0.05,
  'smith_e6s': 0.07,
  'smith_e7s': 0.08,
};

/// Tier where every branch forks and tier where both sub-paths meet
/// again (life_trees_v2.md § 2).
const kLifeForkFrom = 4, kLifeForkTo = 7;

/// Version of the tree shape saved in `life.tv` (life_trees_v2.md § 6):
/// v2 gave every sub-path of tiers 4–7 its own mechanic, so saves below
/// it get the points of those tiers (and the ones above) back.
const kLifeTreeVersion = 2;

/// Sub-path mechanics (life_trees_v2.md § 2.1): `<prefix>_<branch>` →
/// (main sub-path "A", second sub-path "B"). Tiers 4–7 of the main path
/// carry A (Balance key `<id>x`), the second sub-path carries B (key
/// `<id>s`, its own id).
const kLifeForkFx = <String, (String, String)>{
  'fish_a': (LifeFx.calm, LifeFx.twin),
  'fish_b': (LifeFx.chest, LifeFx.big),
  'fish_c': (LifeFx.sell, LifeFx.net),
  'fish_d': (LifeFx.raft, LifeFx.harpoon),
  'fish_e': (LifeFx.fishMeal, LifeFx.fishBuff),
  'farm_a': (LifeFx.waterArea, LifeFx.grow),
  'farm_b': (LifeFx.seedBack, LifeFx.mutate),
  'farm_c': (LifeFx.compost, LifeFx.compostArea),
  'farm_d': (LifeFx.livingRarity, LifeFx.livingAffix),
  'farm_e': (LifeFx.mealPower, LifeFx.meal),
  'farm_f': (LifeFx.partDrop, LifeFx.animalDouble),
  'smith_a': (LifeFx.forge, LifeFx.forgeAffix),
  'smith_b': (LifeFx.veinArea, LifeFx.rareOre),
  'smith_c': (LifeFx.smeltDouble, LifeFx.salvage),
  'smith_d': (LifeFx.mineSpeed, LifeFx.detect),
  'smith_e': (LifeFx.orderPay, LifeFx.orderChest),
};

/// Area sub-paths: their mechanic sits on tiers 4 and 7 (1 = 3×3, 2 =
/// 5×5); tiers 5–6 carry this companion effect (key `<id>y`) instead.
/// Key: `<prefix>_<branch>` + `A` / `B`.
const kLifeForkCompanion = <String, String>{
  'farm_aA': LifeFx.water,
  'farm_cB': LifeFx.grow,
  'smith_bA': LifeFx.xp,
};

/// One-time grants the sub-path adds to main nodes that had none (the
/// Abono branch hands out compost recipes; amount key `<id>r`).
const kLifeForkGrants = <String, String>{
  'farm_c5': 'recipe:ember_compost',
  'farm_c6': 'recipe:honey_compost',
  'farm_c7': 'recipe:frost_compost',
};

/// The nodes of each profession: the main path of each branch plus its
/// second sub-path ([growLifeTree]).
final kLifeTrees = <LifeSkillKind, List<LifeTreeNode>>{
  LifeSkillKind.pesca: growLifeTree(_pesca),
  LifeSkillKind.cultivo: growLifeTree(_cultivo),
  LifeSkillKind.herreria: growLifeTree(_herreria),
};

/// Effects of tier [t] of branch [b] on the main sub-path ([main], "A")
/// or the second one ("B") (§ 2.1).
Map<String, String> lifeForkEffects(String pre, String b, int t, bool main) {
  final pair = kLifeForkFx['${pre}_$b'];
  final id = main ? '${pre}_$b$t' : '${pre}_$b${t}s';
  if (pair == null) return {LifeFx.xp: id};
  final fx = main ? pair.$1 : pair.$2;
  final comp = kLifeForkCompanion['${pre}_$b${main ? 'A' : 'B'}'];
  if (comp != null && t > kLifeForkFrom && t < kLifeForkTo) {
    return {comp: '${pre}_$b${t}y'};
  }
  return {fx: main ? '${id}x' : id};
}

/// Adds the second sub-path (`<branch><tier>s`, tiers [kLifeForkFrom]..
/// [kLifeForkTo]) to every branch of [base]: it leaves the tier-3 node,
/// runs beside the main path and rejoins it at tier 8, which becomes a
/// major node. Each fork node is a sibling choice of the main node of its
/// tier, same cost. Tiers 4–7 of both sub-paths get their own mechanic
/// ([kLifeForkFx]); the main nodes keep their name and one-time grants.
List<LifeTreeNode> growLifeTree(List<LifeTreeNode> base) {
  final byId = {for (final n in base) n.id: n};
  final pre = base.first.id.split('_').first;
  String main(String b, int t) => '${pre}_$b$t';
  String fork(String b, int t) => '${pre}_$b${t}s';

  final branches = [
    for (final b in [...kLifeBranches, 'f'])
      if (byId.containsKey(main(b, 1))) b
  ];
  final extra = <String, List<String>>{};
  final out = <LifeTreeNode>[];
  for (final b in branches) {
    extra[main(b, kLifeForkFrom - 1)] = [fork(b, kLifeForkFrom)];
    extra[main(b, kLifeForkTo + 1)] = [fork(b, kLifeForkTo)];
  }
  for (final n in base) {
    final add = extra[n.id];
    final b = n.branch;
    final rejoin = b != null && n.tier == kLifeForkTo + 1;
    final sub = b != null && n.tier >= kLifeForkFrom && n.tier <= kLifeForkTo;
    final g = kLifeForkGrants[n.id];
    if (add == null && !rejoin && !sub) {
      out.add(n);
      continue;
    }
    out.add(LifeTreeNode(n.id, n.name,
        x: n.x,
        y: n.y,
        cost: n.cost,
        links: [...n.links, ...?add],
        effects: sub ? lifeForkEffects(pre, b, n.tier, true) : n.effects,
        grants: g == null ? n.grants : {...n.grants, g: '${n.id}r'},
        branch: b,
        exclusive: n.exclusive,
        major: n.major || rejoin,
        root: n.root));
  }
  for (final b in branches) {
    for (var t = kLifeForkFrom; t <= kLifeForkTo; t++) {
      final id = fork(b, t);
      final twin = byId[main(b, t)]!;
      out.add(LifeTreeNode(id, kLifeForkNames[id] ?? id,
          x: twin.x,
          y: t,
          cost: twin.cost,
          links: [
            t == kLifeForkFrom ? main(b, t - 1) : fork(b, t - 1),
            t == kLifeForkTo ? main(b, t + 1) : fork(b, t + 1),
          ],
          effects: lifeForkEffects(pre, b, t, false),
          branch: b));
    }
  }
  return out;
}

/// Whether [n] is on the second sub-path of its branch.
bool isLifeFork(LifeTreeNode n) => n.id.endsWith('s') && n.branch != null;

/// Nodes refunded by the tree v2 migration (§ 6): tiers 4–7 changed
/// effects, and everything above them hangs from those tiers.
bool lifeNodeRefunded(LifeTreeNode n) =>
    n.branch != null && n.tier >= kLifeForkFrom;

final _byId = <LifeSkillKind, Map<String, LifeTreeNode>>{
  for (final e in kLifeTrees.entries) e.key: {for (final n in e.value) n.id: n},
};

LifeTreeNode? lifeTreeNode(LifeSkillKind k, String id) => _byId[k]![id];

/// Node ids of [k] (save migration drops everything else).
bool isLifeTreeNode(LifeSkillKind k, String id) => _byId[k]!.containsKey(id);

/// Second sub-path of every branch, tiers 4–7 (life_trees_v2.md § 2.1):
/// id → es-AR name. Shape and effects come from [growLifeTree].
const kLifeForkNames = <String, String>{
  'fish_a4s': 'Doble tirón',
  'fish_a5s': 'Anzuelo gemelo',
  'fish_a6s': 'Par de agallas',
  'fish_a7s': 'Lance doble',
  'fish_b4s': 'Fondo grande',
  'fish_b5s': 'Lomo ancho',
  'fish_b6s': 'Pez de récord',
  'fish_b7s': 'Gigante del lago',
  'fish_c4s': 'Red de balsa',
  'fish_c5s': 'Malla tendida',
  'fish_c6s': 'Red de arrastre',
  'fish_c7s': 'Red del navegante',
  'fish_d4s': 'Punta de arpón',
  'fish_d5s': 'Ojo de cazador',
  'fish_d6s': 'Arpón largo',
  'fish_d7s': 'Golpe del hondo',
  'fish_e4s': 'Sal de guerra',
  'fish_e5s': 'Fogón de batalla',
  'fish_e6s': 'Caldo del arponero',
  'fish_e7s': 'Banquete de marea',
  'farm_a4s': 'Lombriz amiga',
  'farm_a5s': 'Rocío temprano',
  'farm_a6s': 'Barro fértil',
  'farm_a7s': 'Acequia',
  'farm_b4s': 'Semilla rara',
  'farm_b5s': 'Brote extraño',
  'farm_b6s': 'Injerto del eco',
  'farm_b7s': 'Variedad perdida',
  'farm_c4s': 'Pala ancha',
  'farm_c5s': 'Montón de abono',
  'farm_c6s': 'Abonado parejo',
  'farm_c7s': 'Tierra cebada',
  'farm_d4s': 'Savia marcada',
  'farm_d5s': 'Corteza tallada',
  'farm_d6s': 'Nudo vivo',
  'farm_d7s': 'Raíz grabada',
  'farm_e4s': 'Horno de barro',
  'farm_e5s': 'Conserva',
  'farm_e6s': 'Caldo de huerta',
  'farm_e7s': 'Sobremesa larga',
  'farm_f4s': 'Nido doble',
  'farm_f5s': 'Ubre generosa',
  'farm_f6s': 'Doble esquila',
  'farm_f7s': 'Corral que rinde',
  'smith_a4s': 'Runa en caliente',
  'smith_a5s': 'Doble temple',
  'smith_a6s': 'Grabado fino',
  'smith_a7s': 'Marca del eco',
  'smith_b4s': 'Ojo de gema',
  'smith_b5s': 'Veta escondida',
  'smith_b6s': 'Mena rara',
  'smith_b7s': 'Corazón de piedra',
  'smith_c4s': 'Crisol viejo',
  'smith_c5s': 'Desarme limpio',
  'smith_c6s': 'Chatarra útil',
  'smith_c7s': 'Hierro que vuelve',
  'smith_d4s': 'Lámpara minera',
  'smith_d5s': 'Oído de roca',
  'smith_d6s': 'Brillo en la pared',
  'smith_d7s': 'Mapa de vetas',
  'smith_e4s': 'Cofre de regalo',
  'smith_e5s': 'Cliente fiel',
  'smith_e6s': 'Pedido con premio',
  'smith_e7s': 'Gremio agradecido',
};
