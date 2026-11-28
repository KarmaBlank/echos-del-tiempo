// Farm animals of the Granjero profession, ANIMALES branch
// (docs/specs/animals.md). Pure data: every entry names ids and Balance
// keys only; prices, days, XP and odds live in `kTuning['animals']`
// (Editor → Balance → Animales) and are read through the getters below.
// Sprites come from the manifest (`items.vida_<sprite>`), never from a
// file name. Internal ids keep the old profession id (`cultivo`) so saves
// load unchanged.

import '../models/elements.dart';
import '../models/town_build.dart' show BuildKind;
import 'tuning_catalog.dart';

/// Ranch tool or workshop machine: once bought it stays (animals.md § 2,
/// § 11). Machines ([machine]) are bought in the TALLER DE OFICIOS, the
/// tools in the GRANJA tab of the trader.
enum RanchTool {
  cubeta('cubeta', 'Cubeta'),
  tijeras('tijeras', 'Tijeras'),
  quesera('quesera', 'Quesera', machine: true),
  mayonesera('mayonesera', 'Mayonesera', machine: true);

  const RanchTool(this.id, this.sourceName, {this.machine = false});
  final String id;

  /// Spanish source name (i18n `data.materials.ranch_tool.<id>.name`).
  final String sourceName;

  /// A workshop machine (animals.md § 11), not a hand tool.
  final bool machine;

  /// Sprite id of the icon.
  String get sprite => id;

  int get price => _t.i('${id}Price');

  static RanchTool? fromId(Object? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }
}

TuningDef get _t => tuning(TuningId.animals);

/// A ranch building (coop or barn): a footprint with the house in the
/// top-left corner and a fenced yard (animals.md § 3).
class AnimalHomeDef {
  const AnimalHomeDef(this.id, this.kind,
      {required this.w,
      required this.h,
      required this.houseW,
      required this.houseH,
      required this.key});

  /// Construction id (`kConstructions`).
  final String id;
  final BuildKind kind;
  final int w, h, houseW, houseH;

  /// Balance prefix (`coopPrice`, `coopLevel`, `coopCap`).
  final String key;

  int get price => _t.i('${key}Price');
  int get level => _t.i('${key}Level');
  int get cap => _t.i('${key}Cap');

  /// Sprite of the house.
  String get sprite => id;
}

const kAnimalHomes = <BuildKind, AnimalHomeDef>{
  BuildKind.gallinero: AnimalHomeDef('gallinero', BuildKind.gallinero,
      w: 5, h: 4, houseW: 2, houseH: 2, key: 'coop'),
  BuildKind.establo: AnimalHomeDef('establo', BuildKind.establo,
      w: 7, h: 5, houseW: 3, houseH: 3, key: 'barn'),
};

AnimalHomeDef? animalHomeById(String id) =>
    kAnimalHomes.values.where((h) => h.id == id).firstOrNull;

/// What an animal leaves, what a machine makes, or a legendary product
/// (animals.md § 2, § 10, § 11).
class AnimalProductDef {
  const AnimalProductDef(this.id, this.name,
      {required this.key, this.legend = false, this.from});
  final String id;

  /// Spanish source name (i18n key `data.items.animal_product.<id>`).
  final String name;

  /// Balance prefix (`<key>Price`, `<key>Xp`).
  final String key;

  /// A legendary product (golden egg, …): never sold, Brann forges it
  /// (animals.md § 10). Its bag key always has the legendary quality.
  final bool legend;

  /// The product a machine makes this from (`null`: not processed).
  final String? from;

  int get price => legend ? 0 : _t.i('${key}Price');
  int get xp => legend ? 0 : _t.i('${key}Xp');

  String get sprite => id;
}

const kAnimalProducts = <String, AnimalProductDef>{
  'huevo': AnimalProductDef('huevo', 'Huevo', key: 'huevo'),
  'huevo_pato':
      AnimalProductDef('huevo_pato', 'Huevo de pato', key: 'huevoPato'),
  'leche': AnimalProductDef('leche', 'Leche', key: 'leche'),
  'leche_cabra':
      AnimalProductDef('leche_cabra', 'Leche de cabra', key: 'lecheCabra'),
  'lana': AnimalProductDef('lana', 'Lana', key: 'lana'),
  // Machines of the TALLER DE OFICIOS (§ 11): same quality, more price.
  'queso': AnimalProductDef('queso', 'Queso', key: 'queso', from: 'leche'),
  'queso_cabra': AnimalProductDef('queso_cabra', 'Queso de cabra',
      key: 'quesoCabra', from: 'leche_cabra'),
  'mayonesa':
      AnimalProductDef('mayonesa', 'Mayonesa', key: 'mayonesa', from: 'huevo'),
  'mayonesa_pato': AnimalProductDef('mayonesa_pato', 'Mayonesa de pato',
      key: 'mayonesaPato', from: 'huevo_pato'),
  // Legendary products at five hearts (§ 10).
  'huevo_dorado': AnimalProductDef('huevo_dorado', 'Huevo dorado',
      key: 'huevoDorado', legend: true),
  'huevo_marea': AnimalProductDef('huevo_marea', 'Huevo de la marea quieta',
      key: 'huevoMarea', legend: true),
  'cuerno_ancestral': AnimalProductDef('cuerno_ancestral', 'Cuerno ancestral',
      key: 'cuernoAncestral', legend: true),
  'cuerno_risco': AnimalProductDef('cuerno_risco', 'Cuerno del risco eterno',
      key: 'cuernoRisco', legend: true),
  'vellon_eco': AnimalProductDef('vellon_eco', 'Vellón del eco',
      key: 'vellonEco', legend: true),
};

/// Machine that makes [AnimalProductDef] with a `from` (§ 11).
RanchTool? machineFor(AnimalProductDef out) => switch (out.from) {
      'leche' || 'leche_cabra' => RanchTool.quesera,
      'huevo' || 'huevo_pato' => RanchTool.mayonesera,
      _ => null,
    };

/// The processed product a machine makes from [input] (`null`: none).
AnimalProductDef? processedOf(String input) =>
    kAnimalProducts.values.where((p) => p.from == input).firstOrNull;

/// A part an animal leaves through care, never by harm (animals.md § 9):
/// a material of the forge by parts (profession_gear_v2.md § 3).
enum AnimalPart {
  /// Shed by hens and ducks, found on the coop floor. Setting only.
  feather('pluma', 'Pluma'),

  /// Sheared from a sheep with high affection. Grip or setting.
  wool('lana_fina', 'Lana fina'),

  /// Shed by goats and cows, found in the barn. Head or setting.
  horn('cuerno', 'Cuerno mudado'),

  /// Brushed off cows and goats. Grip or setting.
  fur('pelaje', 'Pelaje mudado');

  const AnimalPart(this.id, this.sourceName);
  final String id;
  final String sourceName;
}

/// A farm animal species (animals.md § 2).
class AnimalDef {
  const AnimalDef(this.id, this.name, this.home,
      {required this.product,
      required this.key,
      required this.affinity,
      required this.parts,
      required this.legend,
      required this.weapon,
      required this.signature,
      this.tool});
  final String id;

  /// Spanish source name (i18n key `data.items.animal.<id>`).
  final String name;
  final BuildKind home;
  final String product;

  /// Tool needed to collect (`null`: the product drops on the floor).
  final RanchTool? tool;

  /// Balance prefix (`<key>Price`, `<key>Level`, `<key>Every`).
  final String key;

  /// Affinity its parts give in the setting slot (§ 9).
  final GameElement affinity;

  /// The parts it leaves (§ 9).
  final List<AnimalPart> parts;

  /// Its legendary product id (§ 10).
  final String legend;

  /// Weapon type Brann forges from the legendary product, and its
  /// signature affix (`(affix, min, max)`).
  final String weapon;
  final (String, int, int) signature;

  int get price => _t.i('${key}Price');
  int get level => _t.i('${key}Level');
  int get every => _t.i('${key}Every').clamp(1, 30);

  AnimalProductDef get productDef => kAnimalProducts[product]!;

  /// World sprite (`vida_animal_<id>`, `_b` second frame, `_z` asleep).
  String get sprite => 'animal_$id';
}

const kAnimals = <String, AnimalDef>{
  'gallina': AnimalDef('gallina', 'Gallina', BuildKind.gallinero,
      product: 'huevo',
      key: 'gallina',
      affinity: GameElement.fuego,
      parts: [AnimalPart.feather],
      legend: 'huevo_dorado',
      weapon: 'varita',
      signature: ('abrasador', 1, 1)),
  'pato': AnimalDef('pato', 'Pato', BuildKind.gallinero,
      product: 'huevo_pato',
      key: 'pato',
      affinity: GameElement.agua,
      parts: [AnimalPart.feather],
      legend: 'huevo_marea',
      weapon: 'arco',
      signature: ('impetuoso', 6, 10)),
  'vaca': AnimalDef('vaca', 'Vaca', BuildKind.establo,
      product: 'leche',
      key: 'vaca',
      tool: RanchTool.cubeta,
      affinity: GameElement.fisico,
      parts: [AnimalPart.horn, AnimalPart.fur],
      legend: 'cuerno_ancestral',
      weapon: 'hacha',
      signature: ('feroz', 20, 30)),
  'cabra': AnimalDef('cabra', 'Cabra', BuildKind.establo,
      product: 'leche_cabra',
      key: 'cabra',
      tool: RanchTool.cubeta,
      affinity: GameElement.electro,
      parts: [AnimalPart.horn, AnimalPart.fur],
      legend: 'cuerno_risco',
      weapon: 'lanza',
      signature: ('runico', 3, 5)),
  'oveja': AnimalDef('oveja', 'Oveja', BuildKind.establo,
      product: 'lana',
      key: 'oveja',
      tool: RanchTool.tijeras,
      affinity: GameElement.sagrado,
      parts: [AnimalPart.wool],
      legend: 'vellon_eco',
      weapon: 'báculo',
      signature: ('de_la_vida', 40, 60)),
};

/// The species whose legendary product is [productId] (`null`: none).
AnimalDef? animalOfLegend(String productId) =>
    kAnimals.values.where((a) => a.legend == productId).firstOrNull;

/// Smithing material id of an animal part: `ap_<species>_<part>_<q>`,
/// `q` = quality index 0 (normal) … 2 (épica).
String animalPartId(String species, AnimalPart part, int q) =>
    'ap_${species}_${part.id}_$q';

final _animalPart = RegExp(r'^ap_([a-z]+)_([a-z_]+)_([0-2])$');

/// (species, part, quality index) of an animal part id, or `null`.
(String, AnimalPart, int)? parseAnimalPart(String id) {
  final m = _animalPart.firstMatch(id);
  if (m == null || !kAnimals.containsKey(m.group(1))) return null;
  final part =
      AnimalPart.values.where((p) => p.id == m.group(2)).firstOrNull;
  if (part == null || !kAnimals[m.group(1)]!.parts.contains(part)) {
    return null;
  }
  return (m.group(1)!, part, int.parse(m.group(3)!));
}

/// Every animal part id (species × part × quality).
final kAnimalPartIds = <String>[
  for (final a in kAnimals.values)
    for (final p in a.parts)
      for (var q = 0; q < 3; q++) animalPartId(a.id, p, q),
];

/// Hay bale sprite / goods id.
const kHayId = 'heno';

/// Default Balance values (merged into `kTuningDefaults`). Rebalanced
/// for v0.50 (animals.md § 7): one hour caring for animals pays the same
/// XP and gold as one hour of crops (test `granjero_parity_test`).
const Map<String, num> kAnimalTuning = {
  // Buildings: gold, Granjero level and animal slots.
  'coopPrice': 600,
  'coopLevel': 3,
  'coopCap': 6,
  'barnPrice': 1500,
  'barnLevel': 6,
  'barnCap': 6,
  // Animals: gold, Granjero level and days per product.
  'gallinaPrice': 150,
  'gallinaLevel': 3,
  'gallinaEvery': 1,
  'patoPrice': 300,
  'patoLevel': 5,
  'patoEvery': 2,
  'vacaPrice': 800,
  'vacaLevel': 6,
  'vacaEvery': 1,
  'cabraPrice': 600,
  'cabraLevel': 8,
  'cabraEvery': 2,
  'ovejaPrice': 700,
  'ovejaLevel': 10,
  'ovejaEvery': 3,
  // Products: gold (normal quality) and Granjero XP.
  'huevoPrice': 13,
  'huevoXp': 10,
  'huevoPatoPrice': 26,
  'huevoPatoXp': 20,
  'lechePrice': 13,
  'lecheXp': 10,
  'lecheCabraPrice': 26,
  'lecheCabraXp': 20,
  'lanaPrice': 39,
  'lanaXp': 30,
  // Machines (§ 11): processed products (normal quality) and the XP of
  // running the machine once.
  'quesoPrice': 22,
  'quesoCabraPrice': 44,
  'mayonesaPrice': 22,
  'mayonesaPatoPrice': 44,
  'quesoXp': 0,
  'quesoCabraXp': 0,
  'mayonesaXp': 0,
  'mayonesaPatoXp': 0,
  'processXp': 2,
  'queseraPrice': 900,
  'mayoneseraPrice': 700,
  'machineLevel': 7,
  // Tools and hay.
  'cubetaPrice': 400,
  'tijerasPrice': 600,
  'hayPrice': 4,
  'hayPerCrop': 2,
  'siloMax': 99,
  'hayBagMax': 999,
  // Affection (points; 100 = one heart).
  'affMax': 500,
  'petGain': 30,
  'feedGain': 10,
  'unfedDecay': 20,
  'unpetDecay': 10,
  // Helpers (animals.md § 6).
  'helperPetGain': 15,
  'helperHeartCap': 2,
  'helperPerHome': 1,
  'helperLevel': 8,
  // Quality odds by hearts.
  'qRaroPerHeart': 0.1,
  'qEpicoPerHeart': 0.08,
  // Granjero XP for care; the daily cap per character (0 = no cap: the
  // world day already limits the care, § 7).
  'feedXp': 4,
  'petXp': 6,
  'xpDayCap': 0,
  // Parts (§ 9): chance per event (collect on the floor, brushing,
  // shearing) = partBase + partPerHeart × hearts; wool needs
  // woolHearts hearts. Quality = the product odds of the hearts.
  'partBase': 0.06,
  'partPerHeart': 0.04,
  'woolHearts': 3,
  // Legendary products (§ 10): chance per collect at full hearts.
  'legendChance': 0.03,
  // Brann's legendary animal forge: Granjero level, gold, Legendary
  // chance (else Epic) and how much each point of the tree adds.
  'animalForgeLevel': 12,
  'animalForgeGold': 1500,
  'animalForgeLegend': 0.3,
  'animalForgeLegendTree': 1,
  // Quality of a part as a forge material (profession_gear_v2.md § 2).
  'partQNormal': 0.6,
  'partQRaro': 0.8,
  'partQEpico': 1,
};

/// Default names (i18n `data.items.animal_name.<species>.<n>`), picked by
/// the animal number.
const kAnimalNames = <String, List<String>>{
  'gallina': ['Pinta', 'Clueca', 'Miga', 'Perla', 'Canela', 'Tiza'],
  'pato': ['Charco', 'Remo', 'Lenteja', 'Brisa', 'Junco', 'Pluma'],
  'vaca': ['Manchas', 'Lucera', 'Nube', 'Dulce', 'Tormenta', 'Paja'],
  'cabra': ['Roca', 'Saltona', 'Cardo', 'Niebla', 'Tomillo', 'Risco'],
  'oveja': ['Copo', 'Lanita', 'Algodón', 'Ovillo', 'Bruma', 'Merengue'],
};
