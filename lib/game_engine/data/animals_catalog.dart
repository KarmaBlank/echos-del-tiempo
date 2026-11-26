// Farm animals of the Cultivo profession (docs/specs/animals.md). Pure
// data: every entry names ids and Balance keys only; prices, days and XP
// live in `kTuning['animals']` (Editor → Balance → Animales) and are read
// through the getters below. Sprites come from the manifest
// (`items.vida_<sprite>`), never from a file name.

import '../models/town_build.dart' show BuildKind;
import 'tuning_catalog.dart';

/// Ranch tool: once bought it stays (animals.md § 2).
enum RanchTool {
  cubeta('cubeta', 'Cubeta'),
  tijeras('tijeras', 'Tijeras');

  const RanchTool(this.id, this.sourceName);
  final String id;

  /// Spanish source name (i18n `data.materials.ranch_tool.<id>.name`).
  final String sourceName;

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

/// What an animal leaves (animals.md § 2).
class AnimalProductDef {
  const AnimalProductDef(this.id, this.name, {required this.key});
  final String id;

  /// Spanish source name (i18n key `data.items.animal_product.<id>`).
  final String name;

  /// Balance prefix (`<key>Price`, `<key>Xp`).
  final String key;

  int get price => _t.i('${key}Price');
  int get xp => _t.i('${key}Xp');

  String get sprite => id;
}

const kAnimalProducts = <String, AnimalProductDef>{
  'huevo': AnimalProductDef('huevo', 'Huevo', key: 'huevo'),
  'huevo_pato': AnimalProductDef('huevo_pato', 'Huevo de pato', key: 'huevoPato'),
  'leche': AnimalProductDef('leche', 'Leche', key: 'leche'),
  'leche_cabra':
      AnimalProductDef('leche_cabra', 'Leche de cabra', key: 'lecheCabra'),
  'lana': AnimalProductDef('lana', 'Lana', key: 'lana'),
};

/// A farm animal species (animals.md § 2).
class AnimalDef {
  const AnimalDef(this.id, this.name, this.home,
      {required this.product, required this.key, this.tool});
  final String id;

  /// Spanish source name (i18n key `data.items.animal.<id>`).
  final String name;
  final BuildKind home;
  final String product;

  /// Tool needed to collect (`null`: the product drops on the floor).
  final RanchTool? tool;

  /// Balance prefix (`<key>Price`, `<key>Level`, `<key>Every`).
  final String key;

  int get price => _t.i('${key}Price');
  int get level => _t.i('${key}Level');
  int get every => _t.i('${key}Every').clamp(1, 30);

  AnimalProductDef get productDef => kAnimalProducts[product]!;

  /// World sprite (`vida_animal_<id>`, `_b` second frame, `_z` asleep).
  String get sprite => 'animal_$id';
}

const kAnimals = <String, AnimalDef>{
  'gallina': AnimalDef('gallina', 'Gallina', BuildKind.gallinero,
      product: 'huevo', key: 'gallina'),
  'pato': AnimalDef('pato', 'Pato', BuildKind.gallinero,
      product: 'huevo_pato', key: 'pato'),
  'vaca': AnimalDef('vaca', 'Vaca', BuildKind.establo,
      product: 'leche', key: 'vaca', tool: RanchTool.cubeta),
  'cabra': AnimalDef('cabra', 'Cabra', BuildKind.establo,
      product: 'leche_cabra', key: 'cabra', tool: RanchTool.cubeta),
  'oveja': AnimalDef('oveja', 'Oveja', BuildKind.establo,
      product: 'lana', key: 'oveja', tool: RanchTool.tijeras),
};

/// Hay bale sprite / goods id.
const kHayId = 'heno';

/// Default Balance values (merged into `kTuningDefaults`).
const Map<String, num> kAnimalTuning = {
  // Buildings: gold, Cultivo level and animal slots.
  'coopPrice': 600,
  'coopLevel': 3,
  'coopCap': 6,
  'barnPrice': 1500,
  'barnLevel': 6,
  'barnCap': 6,
  // Animals: gold, Cultivo level and days per product.
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
  // Products: gold (normal quality) and Cultivo XP.
  'huevoPrice': 20,
  'huevoXp': 6,
  'huevoPatoPrice': 50,
  'huevoPatoXp': 14,
  'lechePrice': 35,
  'lecheXp': 9,
  'lecheCabraPrice': 80,
  'lecheCabraXp': 20,
  'lanaPrice': 140,
  'lanaXp': 30,
  // Tools and hay.
  'cubetaPrice': 400,
  'tijerasPrice': 600,
  'hayPrice': 5,
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
  // Cultivo XP for care and the daily cap per character.
  'feedXp': 2,
  'petXp': 4,
  'xpDayCap': 300,
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
