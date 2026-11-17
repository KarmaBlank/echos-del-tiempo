import 'passive_mechanic.dart';

/// Arma una lista de mecánicas para un nivel: [mechId] es el id de la
/// primera (las siguientes llevan `#2`, `#3`...), [name] el nombre con el
/// nivel ("Filo Resonante III") y [v] el valor del nivel.
typedef WeaponPassiveBuilder = List<PassiveMechanic> Function(
    String mechId, String name, double v);

/// Pasiva de arma (loot.md § 10): un efecto mecánico del sistema de
/// disparadores del árbol v2 con 5 niveles (I–V). Las de Épico salen del
/// pool de su tipo de arma ([types]); las de Legendario son únicas.
class WeaponPassiveDef {
  const WeaponPassiveDef({
    required this.id,
    required this.name,
    required this.values,
    required this.describe,
    required this.build,
    this.types = const {},
    this.unique = false,
  });

  final String id;
  final String name;

  /// Tipos de arma en cuyo pool está (vacío en las únicas).
  final Set<String> types;
  final bool unique;

  /// Valor principal por nivel (I..V).
  final List<double> values;

  /// Texto del efecto con el valor de un nivel.
  final String Function(double v) describe;
  final WeaponPassiveBuilder build;

  static const maxLevel = 5;

  double valueAt(int level) => values[level.clamp(1, maxLevel) - 1];

  String nameAt(int level) => '$name ${roman(level)}';

  String descriptionAt(int level) => describe(valueAt(level));

  /// Las mecánicas que entran al combate con la pasiva a [level].
  List<PassiveMechanic> mechanicsAt(int level) {
    final l = level.clamp(1, maxLevel);
    return build(mechanicId(id, l), nameAt(l), valueAt(l));
  }

  /// Id de la primera mecánica de la pasiva [id] a [level].
  static String mechanicId(String id, int level) => 'wp:$id:$level';

  static String roman(int n) =>
      const ['I', 'II', 'III', 'IV', 'V'][n.clamp(1, maxLevel) - 1];
}
