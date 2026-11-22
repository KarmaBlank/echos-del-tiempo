import '../models/item.dart';
import 'tuning_catalog.dart';

/// Mejoras directas de la Travesía (docs/specs/roguelike.md § 4): salen en
/// la fila Extra, se apilan y duran toda la run. Los valores viven en el
/// grupo de ajustes «Travesía» (Editor → Balance).
enum RunBoon {
  hechizos('boonSpell'),
  ataque('boonAttack'),
  curas('boonHeal'),
  critico('boonCrit'),
  ult('boonUlt'),
  elites('boonElite'),
  pulso('boonPulse'),
  defensa('boonDefense'),
  robo('boonSteal');

  const RunBoon(this.tuningKey);
  final String tuningKey;

  /// Valor vigente de una copia.
  int get value => tuning(TuningId.travesia).i(tuningKey);

  /// Texto para el jugador.
  String get text => switch (this) {
        hechizos => 'Tus hechizos hacen +$value % de daño',
        ataque => 'Tu ataque básico y tus golpes físicos +$value %',
        curas => 'Tus curas rinden +$value %',
        critico => '+$value % de crítico',
        ult => 'La ULT carga +$value % más rápido',
        elites => '+$value % de daño contra élites y jefes',
        pulso => 'Empezás cada pelea con +$value Pulso',
        defensa => '+$value DEF',
        robo => '+$value % de robo de vida',
      };

  static RunBoon? byName(String? n) {
    for (final b in values) {
      if (b.name == n) return b;
    }
    return null;
  }

  /// Modificadores de arma que aporta en una pelea (las de élite solo en
  /// élites y jefes; el Pulso no es un modificador).
  List<ItemMod> mods({required bool eliteFight}) => switch (this) {
        hechizos => [ItemMod(ModStat.magPct, value)],
        ataque => [ItemMod(ModStat.atkPct, value)],
        curas => [ItemMod(ModStat.healPower, value)],
        critico => [ItemMod(ModStat.critChance, value)],
        ult => [ItemMod(ModStat.ultCharge, value)],
        elites => eliteFight
            ? [ItemMod(ModStat.atkPct, value), ItemMod(ModStat.magPct, value)]
            : const [],
        pulso => const [],
        defensa => [ItemMod(ModStat.defense, value)],
        robo => [ItemMod(ModStat.lifeSteal, value)],
      };
}
