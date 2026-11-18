import '../models/attributes.dart';
import '../models/elements.dart';
import '../models/item.dart';
import '../models/passive_mechanic.dart';
import '../models/skill.dart';
import '../models/status.dart';
import '../models/weapon.dart';

// Invocador de la Maga v0.8.1 (docs/specs/summoner.md): invocaciones
// (aliados de la IA en la línea de tiempo), sus habilidades, los tomos
// que las dan, la ULT del Libro de los Cuatro y las mecánicas del
// cluster "Invocador" del árbol. Datos puros: las reglas están en
// rules/summon_rules.dart y el motor en rules/battle_engine_summons.dart.

/// Las 6 invocaciones.
enum SummonKind { fuego, agua, electro, hielo, golem, espiritu }

/// Qué hace en su turno (IA por tipo, § 3 del spec).
enum SummonRole {
  /// Pega a un enemigo (prefiere el que reacciona con su elemento).
  elemental,

  /// Provoca (atrae golpes), escuda al aliado más herido y pega flojo.
  golem,

  /// Cura al aliado más herido o marca a un enemigo.
  espiritu,
}

class SummonDef {
  const SummonDef({
    required this.kind,
    required this.name,
    required this.role,
    required this.element,
    required this.hp,
    required this.atk,
    required this.speed,
    this.status,
  });
  final SummonKind kind;
  final String name;
  final SummonRole role;
  final GameElement element;

  /// Multiplicadores sobre la base (§ 2 del spec).
  final double hp, atk, speed;

  /// Estado que deja cada golpe.
  final StatusApplication? status;
}

const Map<SummonKind, SummonDef> kSummons = {
  SummonKind.fuego: SummonDef(kind: SummonKind.fuego, name: 'Elemental de Fuego', role: SummonRole.elemental, element: GameElement.fuego, hp: 0.8, atk: 0.9, speed: 1.0, status: StatusApplication(StatusKind.burn, 2)),
  SummonKind.agua: SummonDef(kind: SummonKind.agua, name: 'Elemental de Agua', role: SummonRole.elemental, element: GameElement.agua, hp: 0.9, atk: 0.7, speed: 1.0, status: StatusApplication(StatusKind.wet, 1)),
  SummonKind.electro: SummonDef(kind: SummonKind.electro, name: 'Elemental de Electro', role: SummonRole.elemental, element: GameElement.electro, hp: 0.7, atk: 0.8, speed: 1.2, status: StatusApplication(StatusKind.charged, 1)),
  SummonKind.hielo: SummonDef(kind: SummonKind.hielo, name: 'Elemental de Hielo', role: SummonRole.elemental, element: GameElement.hielo, hp: 0.9, atk: 0.7, speed: 0.9, status: StatusApplication(StatusKind.freeze, 1)),
  SummonKind.golem: SummonDef(kind: SummonKind.golem, name: 'Gólem', role: SummonRole.golem, element: GameElement.fisico, hp: 2.2, atk: 0.5, speed: 0.8),
  SummonKind.espiritu: SummonDef(kind: SummonKind.espiritu, name: 'Espíritu', role: SummonRole.espiritu, element: GameElement.sagrado, hp: 0.8, atk: 0.4, speed: 1.1),
};

// ---------------- números (summoner.md § 2) ----------------

/// Máximo de invocaciones activas por invocador (Legión: 6).
const kSummonMax = 4;
const kSummonMaxLegion = 6;

/// Turnos propios que dura una invocación.
const kSummonTurns = 4;

/// Bono de stats de las invocaciones por rareza del tomo.
const Map<Rarity, double> kSummonRarityBonus = {
  Rarity.comun: 0,
  Rarity.magico: 0.05,
  Rarity.raro: 0.10,
  Rarity.epico: 0.15,
  Rarity.legendario: 0.25,
};

/// Bono por nivel de forja "Poder" del arma.
const kSummonForgePerPow = 0.04;

/// Gólem: escudo (MAG × esto) al aliado más herido; probabilidad de
/// atraer un golpe enemigo de un solo objetivo.
const kGolemShield = 0.8;
const kGolemTaunt = 0.5;

/// Sin Gólem: cada invocación atrae un golpe con esta probabilidad (tope
/// 40%).
const kSummonDrawChance = 0.12;

/// Espíritu: cura MAG × esto si alguien está debajo del 80%; si no,
/// Marca (+12% daño recibido, 2 turnos).
const kSpiritHeal = 0.9;
const kSpiritMark = 0.12;

/// Sacrificio: MAG × esto con el elemento de la invocación a todos.
const kSacrificePower = 1.6;

/// Portal de los Cuatro: golpe inmediato × 1.5 y, al terminar, cada
/// elemental detona MAG × 0.8 de su elemento a todos.
const kPortalStrike = 1.5;
const kPortalBurst = 0.8;

/// Pacto: −5% de vida máx. por invocación al empezar tu turno.
const kPactCost = 0.05;

/// Legión: cada invocación −30% de stats.
const kLegionPenalty = 0.30;

// ---------------- habilidades ----------------

const _sup = SkillKind.support;

/// Habilidades del Invocador, por id (se suman a `kSkills`).
const Map<String, SkillDef> kSummonerSkills = {
  'invFuego': SkillDef(id: 'invFuego', name: 'Invocar Elemental de Fuego', mp: 6, kind: _sup),
  'invAgua': SkillDef(id: 'invAgua', name: 'Invocar Elemental de Agua', mp: 6, kind: _sup),
  'invElectro': SkillDef(id: 'invElectro', name: 'Invocar Elemental de Electro', mp: 6, kind: _sup),
  'invHielo': SkillDef(id: 'invHielo', name: 'Invocar Elemental de Hielo', mp: 6, kind: _sup),
  'invGolem': SkillDef(id: 'invGolem', name: 'Invocar Gólem', mp: 8, kind: _sup),
  'invEspiritu': SkillDef(id: 'invEspiritu', name: 'Invocar Espíritu', mp: 7, kind: _sup),
  'sacrificio': SkillDef(id: 'sacrificio', name: 'Sacrificio', mp: 4, kind: _sup),
  'enjambre': SkillDef(id: 'enjambre', name: 'Llamado del Enjambre', mp: 14, kind: _sup),
  'comandar': SkillDef(id: 'comandar', name: 'Comandar', mp: 5, kind: _sup),
};

/// La invocación de cada habilidad de invocar.
const Map<String, SummonKind> kSummonSkillKind = {
  'invFuego': SummonKind.fuego,
  'invAgua': SummonKind.agua,
  'invElectro': SummonKind.electro,
  'invHielo': SummonKind.hielo,
  'invGolem': SummonKind.golem,
  'invEspiritu': SummonKind.espiritu,
};

/// Los 4 elementales (Enjambre y Portal).
const kElementalSummons = [
  SummonKind.fuego,
  SummonKind.agua,
  SummonKind.electro,
  SummonKind.hielo,
];

/// ULT del Libro de los Cuatro.
const kPortalUltimate = SkillDef(id: 'ult_portal', name: 'Portal de los Cuatro', kind: _sup);

/// Las 3 ULT del Invocador: ULT de arma de los tomos (summoner.md § 7).
/// Ids estables: también las puede dar un mod "ULT: X" de arma.
const kAvatarUltimate = SkillDef(id: 'ult_avatar', name: 'Avatar del Pacto', kind: _sup);
const kMareaUltimate = SkillDef(id: 'ult_marea', name: 'Marea de Espíritus', kind: _sup);
const Map<String, SkillDef> kSummonerUltimates = {
  'ult_portal': kPortalUltimate,
  'ult_avatar': kAvatarUltimate,
  'ult_marea': kMareaUltimate,
};

/// Avatar del Pacto: dura 3 turnos; +15% de daño por invocación
/// absorbida y sus estados en cada golpe.
const kAvatarTurns = 3;
const kAvatarPower = 0.15;

/// Marea de Espíritus: escudo al grupo (15% de tu vida máx.) y las
/// invocaciones provocan 2 golpes.
const kMareaShield = 0.15;
const kMareaTaunt = 2;

/// ULT propia de cada tomo (reemplaza a la del tipo `tomo`).
const Map<String, String> kWeaponUltOf = {
  'libro_cuatro': 'ult_portal',
  'codice_enjambre': 'ult_marea',
  'tomo_pacto': 'ult_avatar',
};

/// Solo armas de lanzador (báculo, varita, tomo) las reciben por fusión.
const Map<String, SkillDelivery> kSummonerSkillDelivery = {
  'invFuego': SkillDelivery.caster,
  'invAgua': SkillDelivery.caster,
  'invElectro': SkillDelivery.caster,
  'invHielo': SkillDelivery.caster,
  'invGolem': SkillDelivery.caster,
  'invEspiritu': SkillDelivery.caster,
  'sacrificio': SkillDelivery.caster,
  'enjambre': SkillDelivery.caster,
  'comandar': SkillDelivery.caster,
};

/// Elemento de cada habilidad (para `kSkillElement`).
const Map<String, GameElement> kSummonerSkillElement = {
  'invFuego': GameElement.fuego,
  'invAgua': GameElement.agua,
  'invElectro': GameElement.electro,
  'invHielo': GameElement.hielo,
  'invGolem': GameElement.fisico,
  'invEspiritu': GameElement.sagrado,
  'sacrificio': GameElement.fisico,
  'enjambre': GameElement.fisico,
  'comandar': GameElement.fisico,
  'ult_portal': GameElement.fisico,
  'ult_avatar': GameElement.fisico,
  'ult_marea': GameElement.fisico,
};

/// Se ven y suenan como una existente (como `kSkillLooks`).
const Map<String, String> kSummonerSkillLooks = {
  'invFuego': 'llamarada',
  'invAgua': 'niebla',
  'invElectro': 'descarga',
  'invHielo': 'ventisca',
  'invGolem': 'fortaleza',
  'invEspiritu': 'bendicion',
  'sacrificio': 'infierno',
  'enjambre': 'chispa',
  'comandar': 'prisa',
};

// ---------------- tomos (loot.md § 8) ----------------

const _esp = Attribute.esp;
const _fue = Attribute.fue;

const Map<String, WeaponDef> kSummonerWeapons = {
  'tomo_invocador': WeaponDef(id: 'tomo_invocador', name: 'Tomo del Invocador', classId: 'maga', type: 'tomo', tier: 2, level: 6, price: 1100, weight: 0.4,
      requirements: {_esp: 18}, atk: PowerFormula(base: 4, coefficients: {_fue: 0.3}), mag: PowerFormula(base: 12, coefficients: {_esp: 0.8}),
      skillIds: ['invFuego', 'invGolem', 'sacrificio'], implicit: [ItemMod(ModStat.summonDamage, 6)]),
  'grimorio_mareas_vivas': WeaponDef(id: 'grimorio_mareas_vivas', name: 'Grimorio de las Mareas Vivas', classId: 'maga', type: 'tomo', tier: 3, level: 18, price: 3000, weight: 0.4,
      requirements: {_esp: 27}, atk: PowerFormula(base: 5, coefficients: {_fue: 0.3}), mag: PowerFormula(base: 22, coefficients: {_esp: 0.9}),
      skillIds: ['invAgua', 'invHielo', 'comandar'], implicit: [ItemMod(ModStat.summonDamage, 10)]),
  'codice_enjambre': WeaponDef(id: 'codice_enjambre', name: 'Códice del Enjambre', classId: 'maga', type: 'tomo', tier: 3, level: 30, price: 6600, weight: 0.4,
      requirements: {_esp: 40}, atk: PowerFormula(base: 6, coefficients: {_fue: 0.3}), mag: PowerFormula(base: 36, coefficients: {_esp: 1.04}),
      skillIds: ['invElectro', 'enjambre', 'sacrificio'], implicit: [ItemMod(ModStat.summonTurns, 1)]),
  'libro_cuatro': WeaponDef(id: 'libro_cuatro', name: 'Libro de los Cuatro', classId: 'maga', type: 'tomo', tier: 3, level: 44, price: 12000, weight: 0.5,
      requirements: {_esp: 54}, atk: PowerFormula(base: 7, coefficients: {_fue: 0.3}), mag: PowerFormula(base: 46, coefficients: {_esp: 1.15}),
      skillIds: ['invEspiritu', 'enjambre', 'comandar'], implicit: [ItemMod(ModStat.summonDamage, 15)]),
  'tomo_pacto': WeaponDef(id: 'tomo_pacto', name: 'Tomo del Pacto', classId: 'maga', type: 'tomo', tier: 3, level: 36, price: 8800, weight: 0.4,
      requirements: {_esp: 46}, atk: PowerFormula(base: 6, coefficients: {_fue: 0.3}), mag: PowerFormula(base: 40, coefficients: {_esp: 1.08}),
      skillIds: ['invFuego', 'invHielo', 'sacrificio'], implicit: [ItemMod(ModStat.summonTurns, 1)]),
};

// ---------------- árbol: cluster Invocador (summoner.md § 5) ----------------

/// Qué modifica cada mecánica del cluster (las lee el motor de
/// invocaciones; el resto del motor las ignora).
enum SummonMod {
  /// +fracción de vida y daño de tus invocaciones.
  stats,

  /// +fracción de daño solo de los 4 elementales.
  elementalDamage,

  /// +fracción del escudo del Gólem.
  golemShield,

  /// Heredan esta fracción de tu crítico.
  critInherit,

  /// Al morir explotan: MAG × valor de su elemento a todos.
  deathBurst,

  /// Sacrificio deja el estado de la invocación en todos.
  sacrificeStatus,

  /// +ULT al invocar.
  invokeUlt,

  /// +turnos de duración.
  turns,

  /// +fracción de daño propio por invocación activa.
  danceDamage,

  /// +fracción de daño por enemigo que matan (tope 5 muertes).
  killGrowth,

  /// Legión: máx. 6, −30% de stats.
  legion,

  /// Pacto: duran para siempre; −5% de vida por invocación por turno.
  pact,
}

const _sm = ProcEffectKind.summon;
const _al = ProcTrigger.always;

PassiveMechanic _m(String id, String name, double v, String text) =>
    PassiveMechanic(
        id: id,
        name: name,
        trigger: _al,
        effects: [ProcEffect(_sm, value: v)],
        description: text);

/// Mecánicas del cluster (chicos con el id de su nodo, notables y las
/// 2 keystones), en el orden de [kSummonerTreeNodes].
final List<PassiveMechanic> kSummonerTreeMechanics = [
  _m('invocador_s1', 'Vínculo', 0.06, 'Tus invocaciones tienen +6% de vida y daño.'),
  _m('invocador_s2', 'Chispa Elemental', 0.08, 'Tus elementales (Fuego, Agua, Electro, Hielo) hacen +8% de daño.'),
  _m('invocador_s4', 'Piedra Viva', 0.15, 'El escudo de tu Gólem es 15% más grande.'),
  _m('invocador_s6', 'Conjuro Amplio', 0.06, 'Tus invocaciones tienen +6% de vida y daño.'),
  _m('herenciaArcana', 'Herencia Arcana', 0.30, 'Tus invocaciones heredan el 30% de tu probabilidad de crítico.'),
  _m('ofrendaVolatil', 'Ofrenda Volátil', 0.8, 'Al morir (o sacrificarse), una invocación explota con su elemento: MAG × 0.8 a todos los enemigos (puede detonar reacciones).'),
  _m('sacrificioRitual', 'Sacrificio Ritual', 1, 'Sacrificio deja además el estado de la invocación en todos los enemigos.'),
  _m('llamadoResonante', 'Llamado Resonante', 10, 'Invocar te da +10 de carga de ULT.'),
  _m('festinArcano', 'Festín Arcano', 0.10, 'Tus invocaciones ganan +10% de daño por cada enemigo que matan (hasta +50%).'),
  _m('pactoDuradero', 'Pacto Duradero', 2, 'Tus invocaciones duran 2 turnos más.'),
  _m('coroEcos', 'Coro de Ecos', 0.05, 'Por cada invocación activa hacés +5% de daño.'),
  _m('legion', 'Legión', 0.30, 'Hasta 6 invocaciones a la vez, pero cada una tiene −30% de vida y daño.'),
  _m('pacto', 'Pacto Eterno', 0.05, 'Tus invocaciones duran hasta que caen, pero al empezar tu turno perdés 5% de tu vida máx. por cada una (nunca te deja en menos de 1).'),
];

/// Modificador de cada mecánica del cluster.
const Map<String, SummonMod> kSummonerModOf = {
  'invocador_s1': SummonMod.stats,
  'invocador_s2': SummonMod.elementalDamage,
  'invocador_s4': SummonMod.golemShield,
  'invocador_s6': SummonMod.stats,
  'herenciaArcana': SummonMod.critInherit,
  'ofrendaVolatil': SummonMod.deathBurst,
  'sacrificioRitual': SummonMod.sacrificeStatus,
  'llamadoResonante': SummonMod.invokeUlt,
  'festinArcano': SummonMod.killGrowth,
  'pactoDuradero': SummonMod.turns,
  'coroEcos': SummonMod.danceDamage,
  'legion': SummonMod.legion,
  'pacto': SummonMod.pact,
};

/// Valor de cada mecánica del cluster.
final Map<String, double> kSummonerModValue = {
  for (final m in kSummonerTreeMechanics) m.id: m.effects.first.value,
};

/// Nodos del cluster (geometría en unidades de árbol, en el hueco entre
/// Alquimia y el puente Galvánica): id, x, y, tipo (`s`/`n`/`k`) y
/// mecánica. Entrada desde `galvanica_a1`.
const List<(String, double, double, String, String)> kSummonerTreeNodes = [
  ('invocador_s1', 17.4, 7.6, 's', 'invocador_s1'),
  ('invocador_n1', 18.3, 8.2, 'n', 'herenciaArcana'),
  ('invocador_s2', 19.3, 7.6, 's', 'invocador_s2'),
  ('invocador_na', 20.3, 7.9, 'n', 'ofrendaVolatil'),
  ('invocador_nr', 18.0, 9.2, 'n', 'sacrificioRitual'),
  ('invocador_nb', 18.0, 10.2, 'n', 'llamadoResonante'),
  ('invocador_s4', 20.6, 8.9, 's', 'invocador_s4'),
  ('invocador_nk', 18.8, 10.9, 'n', 'festinArcano'),
  ('invocador_nc', 19.9, 10.2, 'n', 'pactoDuradero'),
  ('invocador_s6', 20.6, 11.0, 's', 'invocador_s6'),
  ('invocador_nd', 20.2, 12.0, 'n', 'coroEcos'),
  ('invocador_kl', 19.5, 12.8, 'k', 'legion'),
  ('invocador_kp', 21.0, 12.3, 'k', 'pacto'),
];

const List<(String, String)> kSummonerTreeLinks = [
  ('galvanica_a1', 'invocador_s1'),
  ('invocador_s1', 'invocador_n1'),
  ('invocador_n1', 'invocador_s2'),
  ('invocador_s2', 'invocador_na'),
  ('invocador_n1', 'invocador_nr'),
  ('invocador_nr', 'invocador_nb'),
  ('invocador_na', 'invocador_s4'),
  ('invocador_s4', 'invocador_nc'),
  ('invocador_nb', 'invocador_nk'),
  ('invocador_nk', 'invocador_nc'),
  ('invocador_nc', 'invocador_s6'),
  ('invocador_s6', 'invocador_nd'),
  ('invocador_nd', 'invocador_kl'),
  ('invocador_nd', 'invocador_kp'),
];

/// Stats de afijo que tocan a las invocaciones.
const kSummonModStats = {ModStat.summonDamage, ModStat.summonTurns};

/// La ULT de la base [w]: la propia del tomo (Invocador) o la de su tipo.
SkillDef? weaponBaseUlt(WeaponDef w, Map<String, SkillDef> ultimates) =>
    kSummonerUltimates[kWeaponUltOf[w.id]] ?? ultimates[w.type];
