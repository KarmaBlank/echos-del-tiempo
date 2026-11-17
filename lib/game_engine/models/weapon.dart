import 'attributes.dart';

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
}

class WeaponDef {
  final String id;
  final String name;
  final String classId;
  final String type; // 'espada','hacha','báculo','tomo','arco','rifle','espada+escudo',...
  final int tier;
  final int price;
  final Map<Attribute, int> requirements;
  final PowerFormula atk;
  final PowerFormula? mag;
  final List<String> skillIds;
  final double weight; // resta velocidad
  final int shieldDefense; // solo armas de paladín con escudo

  const WeaponDef({
    required this.id,
    required this.name,
    required this.classId,
    required this.type,
    required this.tier,
    required this.price,
    required this.requirements,
    required this.atk,
    this.mag,
    this.skillIds = const [],
    this.weight = 0,
    this.shieldDefense = 0,
  });

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
