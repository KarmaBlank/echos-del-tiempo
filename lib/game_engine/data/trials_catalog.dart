/// Una Prueba del Tiempo (docs/specs/ascension.md § 1).
class TrialDef {
  const TrialDef({
    required this.number,
    required this.name,
    required this.level,
    required this.zone,
    required this.bossZone,
    required this.monsterLevel,
    required this.floors,
    required this.spikes,
    required this.pulses,
    required this.spikeDamage,
  });

  /// 1..3.
  final int number;
  final String name;

  /// Nivel pedido para proponerla y ganar sus puntos.
  final int level;

  /// Zona cuyo generador, tema, grupos y música usa la mazmorra.
  final int zone;

  /// Zona cuyo jefe la custodia.
  final int bossZone;
  final int monsterLevel;
  final int floors;

  /// Parches de púas (2 × 2) y pulsos (3 × 3) por piso.
  final int spikes;
  final int pulses;

  /// Fracción de la vida máx. que quitan las púas por segundo.
  final double spikeDamage;

  String get roman => const ['I', 'II', 'III'][number - 1];
  String get fullName => 'Prueba del Tiempo $roman · $name';
}

const List<TrialDef> kTrials = [
  TrialDef(number: 1, name: 'El Umbral', level: 30, zone: 6, bossZone: 3, monsterLevel: 32, floors: 2, spikes: 6, pulses: 4, spikeDamage: 0.08),
  TrialDef(number: 2, name: 'La Encrucijada', level: 40, zone: 5, bossZone: 5, monsterLevel: 42, floors: 2, spikes: 8, pulses: 6, spikeDamage: 0.10),
  TrialDef(number: 3, name: 'El Juicio', level: 50, zone: 10, bossZone: 6, monsterLevel: 52, floors: 3, spikes: 10, pulses: 8, spikeDamage: 0.12),
];

TrialDef? trialDef(int? n) =>
    n == null || n < 1 || n > kTrials.length ? null : kTrials[n - 1];
