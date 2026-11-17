import 'weapon.dart';

/// Estadísticas que la herrería puede mejorar en un arma (`UPSTATS` +
/// `def` para armas con escudo). La clave es la del prototipo/JSON.
enum UpgradeStat {
  pow('pow', 'Poder', WeaponUpgradeLevels.powPer),
  crit('crit', 'Crítico', WeaponUpgradeLevels.critPer),
  spd('spd', 'Velocidad', WeaponUpgradeLevels.spdPer),
  def('def', 'Defensa', WeaponUpgradeLevels.defPer);

  const UpgradeStat(this.key, this.label, this.perLevel);

  final String key;
  final String label;
  final double perLevel;

  static UpgradeStat? fromKey(String key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return null;
  }
}

/// Lectura/escritura por estadística sobre [WeaponUpgradeLevels].
extension WeaponUpgradeLevelsAccess on WeaponUpgradeLevels {
  int level(UpgradeStat s) => switch (s) {
        UpgradeStat.pow => pow,
        UpgradeStat.crit => crit,
        UpgradeStat.spd => spd,
        UpgradeStat.def => def,
      };

  WeaponUpgradeLevels withLevel(UpgradeStat s, int value) =>
      WeaponUpgradeLevels(
        pow: s == UpgradeStat.pow ? value : pow,
        crit: s == UpgradeStat.crit ? value : crit,
        spd: s == UpgradeStat.spd ? value : spd,
        def: s == UpgradeStat.def ? value : def,
      );

  /// Solo los niveles distintos de 0, con la clave del prototipo.
  Map<String, int> toJson() => {
        for (final s in UpgradeStat.values)
          if (level(s) > 0) s.key: level(s),
      };
}
