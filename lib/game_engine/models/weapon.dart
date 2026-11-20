import 'attributes.dart';
import 'item.dart';

/// Fórmula de poder de un arma: `base + Σ coef[attr] * attr`.
/// Puerto de los objetos `atk`/`mag` del prototipo (`{b: 9, FUE: 0.5}`).
class PowerFormula {
  final double base;
  final Map<Attribute, double> coefficients;
  const PowerFormula({required this.base, this.coefficients = const {}});

  double evaluate(PlayerAttributes attrs) {
    var total = base;
    coefficients.forEach((attr, coef) => total += coef * attrs[attr]);
    return total;
  }

  /// Igual que [evaluate] con atributos efectivos (tope blando,
  /// progression_v2.md § 2.2).
  double evaluateEffective(double Function(Attribute) attr) {
    var total = base;
    coefficients.forEach((a, coef) => total += coef * attr(a));
    return total;
  }
}

/// Categoría de un tipo de arma (loot.md § 16.1): qué habilidades
/// trasladadas puede recibir. Los `caster` no golpean ni disparan: solo
/// reciben habilidades [SkillDelivery.any] (`models/skill.dart`).
enum WeaponCategory { melee, ranged, caster }

/// Una base de arma (loot.md § 1). Cualquier clase la equipa si cumple
/// el nivel y los requisitos de atributos; [classId] es solo la
/// "familia" (para la tienda, el sesgo de drops y la UI).
class WeaponDef {
  final String id;
  final String name;

  /// Familia de la base (la clase que más la aprovecha). No restringe.
  final String classId;
  final String type; // 'espada','hacha','lanza','báculo','tomo','varita','arco','rifle','ballesta','dagas','espada+escudo',...
  final int tier;

  /// Nivel de personaje requerido (y nivel mínimo de objeto para salir).
  final int level;
  final int price;
  final Map<Attribute, int> requirements;
  final PowerFormula atk;
  final PowerFormula? mag;
  final List<String> skillIds;
  final double weight; // resta velocidad
  final int shieldDefense; // armas con escudo: su implícito de DEF

  /// Implícito fijo de la base (además del DEF del escudo).
  final List<ItemMod> implicit;

  const WeaponDef({
    required this.id,
    required this.name,
    required this.classId,
    required this.type,
    required this.tier,
    this.level = 1,
    required this.price,
    required this.requirements,
    required this.atk,
    this.mag,
    this.skillIds = const [],
    this.weight = 0,
    this.shieldDefense = 0,
    this.implicit = const [],
  });

  String get family => classId;

  bool meetsRequirements(PlayerAttributes attrs) =>
      requirements.entries.every((e) => attrs[e.key] >= e.value);
}

/// Niveles de mejora por-estadística de un arma concreta en manos de un
/// jugador (reemplaza el viejo `p.up[weaponId]` numérico único).
class WeaponUpgradeLevels {
  final int pow, crit, spd, def;
  const WeaponUpgradeLevels({this.pow = 0, this.crit = 0, this.spd = 0, this.def = 0});

  int get total => pow + crit + spd + def;

  static const upMax = 5;
  static const powPer = 0.12;
  static const critPer = 0.02;
  static const spdPer = 0.3;
  static const defPer = 1.0;
}
