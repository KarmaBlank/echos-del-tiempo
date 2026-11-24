// Cooking recipes (docs/specs/farming.md § 17). Pure data: read by
// `CookingRules`; the UI only shows them.

import 'enemy_families.dart' show DamageTag;
import 'farming_catalog.dart';

export 'enemy_families.dart' show DamageTag;
export 'farming_catalog.dart' show CropQuality, cropKey, FishRarity;

/// What a meal buffs for the next missions.
enum MealStat {
  /// + max HP (fraction).
  hp,

  /// + ATK / MAG (fraction).
  atk,

  /// − damage taken from one element (fraction).
  res,
}

/// A cooking recipe: crops (by id, any quality chosen at cook time) and
/// optionally one fish species. Fish recipes last one more mission.
class MealDef {
  const MealDef(this.id, this.name, this.stat,
      {required this.crops,
      this.fish = const {},
      this.element,
      this.power = 1,
      this.lore = ''});

  final String id;
  final String name;
  final MealStat stat;

  /// Crop id → count (all of the quality picked at the pot).
  final Map<String, int> crops;

  /// Fish species → count (any size).
  final Map<String, int> fish;

  /// Resisted element when [stat] is [MealStat.res].
  final DamageTag? element;

  /// × on the buff (recipes with rarer crops hit harder).
  final double power;
  final String lore;

  bool get hasFish => fish.isNotEmpty;

  /// Rarity of the rarest crop (for the cell border).
  FishRarity get rarity {
    var r = FishRarity.comun;
    for (final id in crops.keys) {
      final c = kCrops[id];
      if (c != null && c.rarity.index > r.index) r = c.rarity;
    }
    return r;
  }
}

const kMeals = <String, MealDef>{
  'sopa_nabo': MealDef('sopa_nabo', 'Sopa de nabo', MealStat.hp,
      crops: {'nabo_claro': 3},
      lore: 'La receta más vieja del pueblo, y la que más reconforta.'),
  'pan_dorado': MealDef('pan_dorado', 'Pan dorado', MealStat.atk,
      crops: {'trigo_dorado': 3},
      lore: 'Corteza firme para un brazo firme.'),
  'guiso_calabaza': MealDef('guiso_calabaza', 'Guiso de calabaza', MealStat.res,
      crops: {'calabaza_sendero': 2, 'papa_piedra': 1},
      element: DamageTag.water,
      lore: 'Espeso: el agua resbala por encima.'),
  'tarta_frutilla': MealDef('tarta_frutilla', 'Tarta de frutilla', MealStat.res,
      crops: {'frutilla_rocio': 2, 'trigo_dorado': 1},
      element: DamageTag.fire,
      lore: 'El rocío de la fruta guarda el fresco de la mañana.'),
  'sopa_cebolla': MealDef('sopa_cebolla', 'Sopa de cebolla de cobre',
      MealStat.res,
      crops: {'cebolla_cobre': 2, 'nabo_claro': 1},
      element: DamageTag.electric,
      lore: 'El cobre de la cebolla se lleva las chispas.'),
  'caldo_invierno': MealDef('caldo_invierno', 'Caldo de invierno',
      MealStat.res,
      crops: {'col_invierno': 2, 'rabano_nieve': 1},
      element: DamageTag.ice,
      lore: 'Quien lo toma no siente la helada.'),
  'melon_glaseado': MealDef('melon_glaseado', 'Melón engranaje glaseado',
      MealStat.hp,
      crops: {'melon_engranaje': 1, 'trigo_dorado': 2},
      power: 2,
      lore: 'Cada gajo encastra en el siguiente.'),
  'ensalada_runica': MealDef('ensalada_runica', 'Ensalada rúnica', MealStat.atk,
      crops: {'flor_runica': 1, 'frutilla_rocio': 1},
      power: 2,
      lore: 'Las runas de los pétalos se sienten en la mano.'),
  'mojarra_nabo': MealDef('mojarra_nabo', 'Mojarra con nabo', MealStat.hp,
      crops: {'nabo_claro': 2},
      fish: {'mojarra_claro': 1},
      lore: 'Pesca y huerta en el mismo plato.'),
  'trucha_cebolla': MealDef('trucha_cebolla', 'Trucha a la cebolla',
      MealStat.atk,
      crops: {'cebolla_cobre': 1},
      fish: {'trucha_cobre': 1},
      power: 1.5,
      lore: 'Dos cobres que se entienden.'),
};

/// Key of a cooked meal in the bag: `<meal>@<quality index>`.
String mealKey(String meal, CropQuality q) => '$meal@${q.index}';

/// (meal, quality) of a bag key; `null` if invalid.
(MealDef, CropQuality)? parseMealKey(String key) {
  final i = key.lastIndexOf('@');
  if (i <= 0) return null;
  final m = kMeals[key.substring(0, i)];
  final q = int.tryParse(key.substring(i + 1));
  if (m == null || q == null || q < 0 || q >= CropQuality.values.length) {
    return null;
  }
  return (m, CropQuality.values[q]);
}
