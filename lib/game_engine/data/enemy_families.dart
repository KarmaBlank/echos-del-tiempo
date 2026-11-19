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
  aberration('Aberración del Vacío', 'Aberraciones del Vacío', 'VA'),

  /// Autómatas del TUTORIAL (combat_tutorial.md § 3): débil al Fuego,
  /// resiste lo físico. No aparece en el bestiario.
  training('Autómata de práctica', 'Autómatas de práctica', 'AU');

  const EnemyFamily(this.label, this.plural, this.code);

  final String label;
  final String plural;

  /// Sigla de dos letras del ícono (la UI la dibuja sobre el color de la
  /// familia: las fuentes pixel no tienen símbolos).
  final String code;
}

/// Tipo de daño de un golpe, para las familias. Físico / mágico sale de
/// `SkillDef.kind`; los elementos, del estado que aplica la habilidad
/// (Quemadura = fuego, Congelación = hielo, Sagrado), de [kHolySkillIds]
/// y, desde v0.7, del elemento del golpe (`elementOf`, Agua y Electro
/// incluidos; también los golpes enemigos a jugadores con raza).
enum DamageTag {
  physical('físico'),
  magical('mágico'),
  fire('fuego'),
  ice('hielo'),
  holy('Sagrado'),
  water('agua'),
  electric('electro');

  const DamageTag(this.label);
  final String label;

  bool get isElement => this != physical && this != magical;
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

/// Reglas por familia (combo_balance.md § 3.1, bestiary.md § 1.2). Escala
/// fija: débil ×1.5, resistente ×0.5, inmune ×0 (daño 0, cartel
/// "INMUNE"). Los tipos amplios (físico / mágico) solo aparecen como
/// resistencia: las debilidades son elementos, así el tope por golpe
/// (§ 3.2) se rompe combinando elementos y no con cualquier golpe.
const Map<EnemyFamily, FamilyRule> kFamilyRules = {
  EnemyFamily.undead: FamilyRule(
    family: EnemyFamily.undead,
    damage: {DamageTag.holy: 1.5, DamageTag.fire: 1.5, DamageTag.ice: 0.5},
    immune: {StatusKind.poison},
    healHarm: 1.0,
    holyTick: 2.0,
  ),
  EnemyFamily.spectre: FamilyRule(
    family: EnemyFamily.spectre,
    damage: {DamageTag.physical: 0.5, DamageTag.holy: 1.5},
    immune: {StatusKind.poison},
    healHarm: 0.5,
    holyTick: 1.5,
  ),
  EnemyFamily.beast: FamilyRule(
    family: EnemyFamily.beast,
    damage: {DamageTag.fire: 1.5, DamageTag.ice: 0.5},
    stacks: {StatusKind.burn: 1},
    markMult: 1.5,
  ),
  EnemyFamily.arachnid: FamilyRule(
    family: EnemyFamily.arachnid,
    damage: {DamageTag.fire: 1.5, DamageTag.ice: 0.5},
    immune: {StatusKind.poison},
    stacks: {StatusKind.burn: 1},
  ),
  EnemyFamily.ooze: FamilyRule(
    family: EnemyFamily.ooze,
    damage: {DamageTag.fire: 1.5, DamageTag.electric: 1.5, DamageTag.water: 0.5},
  ),
  EnemyFamily.construct: FamilyRule(
    family: EnemyFamily.construct,
    damage: {DamageTag.magical: 0.5, DamageTag.electric: 1.5},
    immune: {StatusKind.poison},
    breakMult: 1.5,
  ),
  EnemyFamily.fireElemental: FamilyRule(
    family: EnemyFamily.fireElemental,
    damage: {
      DamageTag.ice: 1.5,
      DamageTag.water: 1.5,
      DamageTag.electric: 0.5,
      DamageTag.fire: 0,
    },
    immune: {StatusKind.burn},
    stacks: {StatusKind.freeze: 1},
  ),
  EnemyFamily.iceElemental: FamilyRule(
    family: EnemyFamily.iceElemental,
    damage: {DamageTag.fire: 1.5, DamageTag.water: 0.5, DamageTag.ice: 0},
    immune: {StatusKind.freeze},
    stacks: {StatusKind.burn: 1},
  ),
  EnemyFamily.temporal: FamilyRule(
    family: EnemyFamily.temporal,
    damage: {DamageTag.ice: 1.5, DamageTag.electric: 0.5},
    stacks: {StatusKind.freeze: 1, StatusKind.poison: -1},
    delayMult: 1.5,
  ),
  EnemyFamily.aberration: FamilyRule(
    family: EnemyFamily.aberration,
    damage: {DamageTag.holy: 1.5, DamageTag.magical: 0.5},
  ),
  EnemyFamily.training: FamilyRule(
    family: EnemyFamily.training,
    damage: {DamageTag.fire: 1.5, DamageTag.physical: 0.5},
  ),
};

/// Tope por golpe sin debilidad (combo_balance.md § 3.2), editable en el
/// admin de balance (`BalanceKind.hitCap`). Fracciones de la vida máxima.
///
/// Élite y jefe escalan con el grupo (combo_balance.md § 3.2, ajuste de
/// los pasos 3-4): lineal entre el valor solo ([eliteSolo], [bossSolo]) y
/// el de 4 jugadores ([elite], [boss]). Jefe: 25 / 22 / 18 / 15%.
class HitCapDef {
  const HitCapDef({
    this.common = 0.60,
    this.commonC = 0.35,
    this.eliteSolo = 0.45,
    this.elite = 0.35,
    this.bossSolo = 0.25,
    this.boss = 0.15,
    this.overLevel = 5,
  });

  String get id => 'tope';
  String get name => 'Tope por golpe';

  /// Común (no depende del grupo).
  final double common;

  /// Común en un nivel de zona C (combo_balance.md § 3.2, ajuste de los
  /// pasos 5-6).
  final double commonC;

  /// Élite y jefe: solo y a 4 jugadores.
  final double eliteSolo, elite, bossSolo, boss;

  /// Niveles del jugador sobre el enemigo desde los que no hay tope.
  final int overLevel;

  /// Fracción de vida máxima que puede sacar un golpe a [elite] / [boss]
  /// con [partySize] jugadores: `solo + (a4 − solo) × (jugadores − 1) / 3`.
  double fraction(
      {required bool elite,
      required bool boss,
      int partySize = 1,
      bool zoneC = false}) {
    if (!boss && !elite) return zoneC ? commonC : common;
    final t = ((partySize.clamp(1, 4)) - 1) / 3;
    final (solo, four) = boss ? (bossSolo, this.boss) : (eliteSolo, this.elite);
    return solo + (four - solo) * t;
  }
}
const kHitCaps = {'tope': HitCapDef()};

/// Reglas globales de combos y quiebre (combo_balance.md § 4 y § 5),
/// editables en el admin de balance (`BalanceKind.combo`). Los números
/// propios de cada Convergencia (daño por stack, topes, salpicadura) van
/// en `ReactionDef`.
class ComboRulesDef {
  const ComboRulesDef({
    this.weakMult = 1.25,
    this.resistMult = 0.5,
    this.ultBonus = 10,
    this.stackCap = 30,
    this.areaMult = 0.6,
    this.breakAttack = 4,
    this.breakPhysical = 6,
    this.breakMagical = 4,
    this.breakUltimate = 12,
    this.breakDual = 10,
    this.breakQuebrar = 1,
    this.breakWeak = 0.5,
    this.breakStatus = 6,
    this.breakReaction = 8,
    this.heavyBreak = 0.25,
    this.eliteBreak = 2.5,
    this.groupBreakBase = 0.6,
    this.groupBreakPer = 0.3,
    this.steadyGauge = 0.5,
  });

  String get id => 'combos';
  String get name => 'Combos y quiebre';

  // ---- Convergencias y área (§ 4) ----

  /// Convergencia contra un débil / resistente al elemento que detona.
  final double weakMult, resistMult;

  /// Carga de ULT para quien preparó y quien detonó, si son distintos.
  final double ultBonus;

  /// Tope de stacks de Quemadura y Veneno por enemigo.
  final int stackCap;

  /// Daño por blanco de las habilidades de área (sus estados, completos).
  final double areaMult;

  // ---- Quiebre (§ 5) ----

  /// Puntos de quiebre por acción (una vez por objetivo y acción).
  final double breakAttack, breakPhysical, breakMagical, breakUltimate,
      breakDual, breakQuebrar;

  /// +fracción de puntos si el golpe pega a una debilidad.
  final double breakWeak;

  /// Aplicar Aturdido o Congelación; reacción o Convergencia.
  final double breakStatus, breakReaction;

  /// +fracción de puntos de las armas pesadas (hacha, martillo).
  final double heavyBreak;

  /// Umbral del élite (× el del común de su tipo).
  final double eliteBreak;

  /// Umbral × `groupBreakBase + groupBreakPer × jugadores`.
  final double groupBreakBase, groupBreakPer;

  /// Fisurado que llega a su turno: la barra vuelve a esta fracción.
  final double steadyGauge;

  /// Multiplicador del umbral por tamaño del grupo.
  double groupBreak(int players) =>
      groupBreakBase + groupBreakPer * players.clamp(1, 4);
}

const kComboRules = {'combos': ComboRulesDef()};

/// Tipos de arma pesados (+25% de quiebre, combo_balance.md § 5).
const kHeavyWeaponTypes = {'hacha', 'martillo+escudo'};

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
  // Jefes del Abismo v0.8 (abyss_bosses.md § 2.2)
  'golemAbismo': EnemyFamily.construct,
  'hechiceraAbismo': EnemyFamily.temporal,
  'espectroAbismo': EnemyFamily.spectre,
  'devoradorAbismo': EnemyFamily.temporal,
  'ecoPrimordial': EnemyFamily.aberration,
  'ecoAbismo': EnemyFamily.temporal,
};
