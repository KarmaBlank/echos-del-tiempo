import '../models/status.dart';

// Familias de enemigos v0.6 (docs/specs/bestiary.md § 1): cada enemigo y
// jefe pertenece a una familia con debilidades, resistencias e
// inmunidades que habilitan builds ("las curas dañan a los no muertos").
// Las reglas son datos: `BattleEngine` las lee sin saber de familias
// concretas (rules/family_rules.dart).

/// Familia de un enemigo.
enum EnemyFamily {
  undead('No muerto', 'No muertos', 'NM'),
  spectre('Espectro', 'Espectros', 'ES'),
  beast('Bestia', 'Bestias', 'BE'),
  arachnid('Arácnido', 'Arácnidos', 'AR'),
  ooze('Cieno', 'Cienos', 'CI'),
  construct('Constructo', 'Constructos', 'CO'),
  fireElemental('Elemental ígneo', 'Elementales ígneos', 'IG'),
  iceElemental('Elemental de escarcha', 'Elementales de escarcha', 'HE'),
  temporal('Temporal', 'Temporales', 'TE'),
  aberration('Aberración del Vacío', 'Aberraciones del Vacío', 'VA');

  const EnemyFamily(this.label, this.plural, this.code);

  final String label;
  final String plural;

  /// Sigla de dos letras del ícono (la UI la dibuja sobre el color de la
  /// familia: las fuentes pixel no tienen símbolos).
  final String code;
}

/// Tipo de daño de un golpe del grupo, para las familias. Físico / mágico
/// sale de `SkillDef.kind`; los elementos, del estado que aplica la
/// habilidad (Quemadura = fuego, Congelación = hielo, Sagrado) o de
/// [kHolySkillIds].
enum DamageTag {
  physical('físico'),
  magical('mágico'),
  fire('fuego'),
  ice('hielo'),
  holy('Sagrado');

  const DamageTag(this.label);
  final String label;

  bool get isElement =>
      this == fire || this == ice || this == holy;
}

/// Reglas de una familia. Todos los factores son multiplicadores (1 =
/// sin efecto). Ver docs/specs/bestiary.md § 1.2.
class FamilyRule {
  const FamilyRule({
    required this.family,
    this.damage = const {},
    this.immune = const {},
    this.stacks = const {},
    this.healHarm = 0,
    this.holyTick = 1,
    this.breakMult = 1,
    this.delayMult = 1,
    this.markMult = 1,
  });

  final EnemyFamily family;

  /// Daño recibido por tipo (> 1 débil, < 1 resiste).
  final Map<DamageTag, double> damage;

  /// Estados que nunca le entran.
  final Set<StatusKind> immune;

  /// Stacks de más (o de menos, mín. 1) cuando el grupo le aplica el
  /// estado.
  final Map<StatusKind, int> stacks;

  /// Las curas de habilidad del grupo lo dañan: fracción de la cura.
  final double healHarm;

  /// Daño del estado Sagrado al empezar su turno.
  final double holyTick;

  /// Llenado de la barra de quiebre.
  final double breakMult;

  /// Retrasos de las habilidades (Tajo Temporal, Detener...).
  final double delayMult;

  /// Bonus de la Marca (`damageTaken`) que recibe.
  final double markMult;
}

/// Ids de habilidades con daño Sagrado aunque no apliquen el estado
/// (paladín, templario, ULT de maza / martillo con escudo).
const Set<String> kHolySkillIds = {
  'sagrado',
  'lanzaLuz',
  'consagrar',
  'juicio',
  'castigo',
  'luzCegadora',
  'selloSagrado',
  'ult_maza_escudo',
  'ult_martillo_escudo',
};

/// `DamageEvent.sourceId` del daño de una cura a un no muerto.
const kHealHarmSourceId = 'curaSagrada';

/// Reglas por familia.
const Map<EnemyFamily, FamilyRule> kFamilyRules = {
  EnemyFamily.undead: FamilyRule(
    family: EnemyFamily.undead,
    damage: {DamageTag.holy: 1.5, DamageTag.fire: 1.25},
    immune: {StatusKind.poison},
    healHarm: 1.0,
    holyTick: 2.0,
  ),
  EnemyFamily.spectre: FamilyRule(
    family: EnemyFamily.spectre,
    damage: {
      DamageTag.physical: 0.7,
      DamageTag.magical: 1.25,
      DamageTag.holy: 1.25,
    },
    immune: {StatusKind.poison},
    healHarm: 0.5,
    holyTick: 1.5,
  ),
  EnemyFamily.beast: FamilyRule(
    family: EnemyFamily.beast,
    damage: {DamageTag.fire: 1.25},
    stacks: {StatusKind.burn: 1},
    markMult: 1.5,
  ),
  EnemyFamily.arachnid: FamilyRule(
    family: EnemyFamily.arachnid,
    damage: {DamageTag.fire: 1.5},
    immune: {StatusKind.poison},
    stacks: {StatusKind.burn: 1},
  ),
  EnemyFamily.ooze: FamilyRule(
    family: EnemyFamily.ooze,
    damage: {DamageTag.fire: 1.25},
  ),
  EnemyFamily.construct: FamilyRule(
    family: EnemyFamily.construct,
    damage: {DamageTag.magical: 0.8},
    immune: {StatusKind.poison},
    breakMult: 1.5,
  ),
  EnemyFamily.fireElemental: FamilyRule(
    family: EnemyFamily.fireElemental,
    damage: {DamageTag.ice: 1.5, DamageTag.fire: 0.5},
    immune: {StatusKind.burn},
    stacks: {StatusKind.freeze: 1},
  ),
  EnemyFamily.iceElemental: FamilyRule(
    family: EnemyFamily.iceElemental,
    damage: {DamageTag.fire: 1.5, DamageTag.ice: 0.5},
    immune: {StatusKind.freeze},
    stacks: {StatusKind.burn: 1},
  ),
  EnemyFamily.temporal: FamilyRule(
    family: EnemyFamily.temporal,
    damage: {DamageTag.ice: 1.25},
    stacks: {StatusKind.freeze: 1, StatusKind.poison: -1},
    delayMult: 1.5,
  ),
  EnemyFamily.aberration: FamilyRule(
    family: EnemyFamily.aberration,
    damage: {
      DamageTag.physical: 1.2,
      DamageTag.holy: 1.5,
      DamageTag.magical: 0.75,
    },
  ),
};

/// Familia de cada enemigo del catálogo (incluye jefes e invocaciones).
const Map<String, EnemyFamily> kEnemyFamily = {
  // Zona 1 · Pradera Esmeralda
  'slime': EnemyFamily.ooze,
  'bat': EnemyFamily.beast,
  'reyLimo': EnemyFamily.ooze,
  // Zona 2 · Bosque Hondo
  'arana': EnemyFamily.arachnid,
  'lobo': EnemyFamily.beast,
  'matriarca': EnemyFamily.arachnid,
  // Zona 3 · Ruinas Cronales
  'golem': EnemyFamily.construct,
  'ghost': EnemyFamily.spectre,
  'golemReloj': EnemyFamily.construct,
  // Zona 4 · Cavernas Heladas
  'murcielagoHielo': EnemyFamily.beast,
  'elementalEscarcha': EnemyFamily.iceElemental,
  'sierpe': EnemyFamily.iceElemental,
  'cristalHielo': EnemyFamily.iceElemental,
  // Zona 5 · Fortaleza Caída
  'esqueleto': EnemyFamily.undead,
  'caballeroCaido': EnemyFamily.undead,
  'caballeroHueco': EnemyFamily.undead,
  // Zona 6 · Laberinto Temporal
  'ecoSombra': EnemyFamily.temporal,
  'guardianReloj': EnemyFamily.construct,
  'hechicera': EnemyFamily.temporal,
  'ecoHechicera': EnemyFamily.temporal,
  // Zona 7 · Grieta Ígnea
  'salamandra': EnemyFamily.fireElemental,
  'golemMagma': EnemyFamily.fireElemental,
  'bestiaMagma': EnemyFamily.fireElemental,
  // Zona 8 · Cementerio de Eras
  'necrofago': EnemyFamily.undead,
  'almaErrante': EnemyFamily.spectre,
  'espectroCoronado': EnemyFamily.spectre,
  'siervoEspectral': EnemyFamily.spectre,
  // Zona 9 · Abismo del Tiempo
  'vigilanteVacio': EnemyFamily.aberration,
  'ojoAbismo': EnemyFamily.aberration,
  'centinela': EnemyFamily.aberration,
  // Zona 10 · Corazón del Tiempo
  'heraldoEras': EnemyFamily.temporal,
  'fragmentoTiempo': EnemyFamily.temporal,
  'devorador': EnemyFamily.temporal,
};
