import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart';
import '../models/status.dart';
import 'elemental_skills_catalog.dart';

// Variantes de habilidades v0.5 (docs/specs/combat.md § "Variantes de
// habilidades"): familias de curación, escudos, disparos, debuffs,
// control y apoyo que JUEGAN distinto. Se suman a `kSkills`; las armas
// que las dan están en loot.md § 8.2.

const _burn = StatusKind.burn;
const _poi = StatusKind.poison;
const _frz = StatusKind.freeze;
const _stun = StatusKind.stun;

const _phys = SkillKind.physical;
const _mag = SkillKind.magical;
const _heal = SkillKind.heal;
const _sup = SkillKind.support;

const _mark = BuffStat.damageTaken;
const _atk = BuffStat.attack;
const _spd = BuffStat.speed;

/// Familia de una variante (para la spec, los tests y el tooltip).
enum SkillFamily { heal, shield, shot, debuff, control, buff }

/// Las variantes, por id.
const Map<String, SkillDef> kSkillVariants = {
  // ---- curación ----
  'curaFocal': SkillDef(id: 'curaFocal', name: 'Cura Focalizada', mp: 5, kind: _heal, power: 2.6, lowestAlly: true),
  'rocio': SkillDef(id: 'rocio', name: 'Rocío Sanador', mp: 4, kind: _heal, power: 0.7),
  'brotes': SkillDef(id: 'brotes', name: 'Brotes de Vida', mp: 5, kind: SkillKind.regen, power: 0.5),
  'semilla': SkillDef(id: 'semilla', name: 'Semilla Vital', mp: 3, kind: SkillKind.regen, power: 1.2, lowestAlly: true),
  'purificar': SkillDef(id: 'purificar', name: 'Purificación', mp: 4, kind: _heal, power: 1.2, cleanse: 5, lowestAlly: true),
  'resurreccion': SkillDef(id: 'resurreccion', name: 'Resurrección', mp: 9, kind: _heal, power: 1.4, revive: 0.35, lowestAlly: true),
  'fenix': SkillDef(id: 'fenix', name: 'Llama Fénix', mp: 14, kind: _heal, power: 1.0, revive: 0.7, cleanse: 5),
  'graciaDesbordante': SkillDef(id: 'graciaDesbordante', name: 'Gracia Desbordante', mp: 6, kind: _heal, power: 2.0, lowestAlly: true, overheal: 1.0),
  'marea': SkillDef(id: 'marea', name: 'Marea Vital', mp: 9, kind: _heal, power: 1.2, overheal: 0.6),
  'flechaSanadora': SkillDef(id: 'flechaSanadora', name: 'Flecha Sanadora', mp: 3, kind: _phys, power: 0.8, drainHeal: 1.0),
  'drenar': SkillDef(id: 'drenar', name: 'Drenar Vida', mp: 5, kind: _mag, power: 1.4, drainHeal: 0.6),
  'sifon': SkillDef(id: 'sifon', name: 'Sifón Vital', mp: 4, kind: _phys, power: 1.3, drainHeal: 0.5),
  // ---- escudos ----
  'escudoArcano': SkillDef(id: 'escudoArcano', name: 'Escudo Arcano', mp: 4, kind: _sup, allyShield: 0.30),
  'barrera': SkillDef(id: 'barrera', name: 'Barrera', mp: 7, kind: _sup, partyShield: 0.12, partyShieldTurns: 2),
  'egidaEspinosa': SkillDef(id: 'egidaEspinosa', name: 'Égida Espinosa', mp: 5, kind: _sup, allyShield: 0.22, shieldReflect: 0.6),
  'escudoVolatil': SkillDef(id: 'escudoVolatil', name: 'Escudo Volátil', mp: 5, kind: _sup, allyShield: 0.20, shieldBurst: 1.2),
  'bastionCreciente': SkillDef(id: 'bastionCreciente', name: 'Bastión Creciente', mp: 5, kind: _sup, selfShield: 0.12, shieldGrow: 1.3, shieldTurns: 3),
  'retoEscudado': SkillDef(id: 'retoEscudado', name: 'Reto Escudado', mp: 4, kind: SkillKind.taunt, amount: 2, selfShield: 0.20),
  'murallaFe': SkillDef(id: 'murallaFe', name: 'Muralla de Fe', mp: 9, kind: _sup, partyShield: 0.18, partyShieldTurns: 2, shieldReflect: 0.3),
  'cupula': SkillDef(id: 'cupula', name: 'Cúpula Arcana', mp: 8, kind: _sup, partyShield: 0.10, partyShieldTurns: 2, partyBuffs: [PartyBuff(BuffStat.guard, 0.10, 2)]),
  // ---- disparos ----
  'flechaPerforante': SkillDef(id: 'flechaPerforante', name: 'Flecha Perforante', mp: 4, kind: _phys, power: 1.4, pierce: 0.7),
  'balaTraspasante': SkillDef(id: 'balaTraspasante', name: 'Bala Traspasante', mp: 6, kind: _phys, power: 1.9, pierce: 0.8, critBonus: 0.15),
  'tiroRebote': SkillDef(id: 'tiroRebote', name: 'Tiro de Rebote', mp: 4, kind: _phys, power: 1.2, bounces: 2),
  'dagaSaltarina': SkillDef(id: 'dagaSaltarina', name: 'Daga Saltarina', mp: 5, kind: _phys, power: 1.0, bounces: 3, status: StatusApplication(_poi, 1)),
  'disparoCargado': SkillDef(id: 'disparoCargado', name: 'Disparo Cargado', mp: 5, kind: _phys, charge: 3.4, selfTurn: 0.7),
  'viroteAsedio': SkillDef(id: 'viroteAsedio', name: 'Virote de Asedio', mp: 7, kind: _phys, charge: 4.2, selfTurn: 0.7, status: StatusApplication(_stun, 1, chance: 0.5)),
  'rafagaTriple': SkillDef(id: 'rafagaTriple', name: 'Ráfaga Triple', mp: 4, kind: _phys, power: 0.6, hits: 3),
  'cadencia': SkillDef(id: 'cadencia', name: 'Cadencia Letal', mp: 6, kind: _phys, power: 0.45, hits: 5, critBonus: 0.1),
  'flechaMarcadora': SkillDef(id: 'flechaMarcadora', name: 'Flecha Marcadora', mp: 3, kind: _phys, power: 0.8, debuffs: [PartyBuff(_mark, 0.25, 2)]),
  'senalar': SkillDef(id: 'senalar', name: 'Señalar Presa', mp: 3, kind: _sup, debuffs: [PartyBuff(_mark, 0.35, 2)], selfTurn: 0.6),
  'flechaIncendiaria': SkillDef(id: 'flechaIncendiaria', name: 'Flecha Incendiaria', mp: 4, kind: _phys, power: 1.1, status: StatusApplication(_burn, 3)),
  'flechaEscarcha': SkillDef(id: 'flechaEscarcha', name: 'Flecha de Escarcha', mp: 4, kind: _phys, power: 1.0, status: StatusApplication(_frz, 2), debuffs: [PartyBuff(_spd, -0.15, 2)]),
  'balaCorrosiva': SkillDef(id: 'balaCorrosiva', name: 'Bala Corrosiva', mp: 5, kind: _phys, power: 1.2, status: StatusApplication(_poi, 2), debuffs: [PartyBuff(_mark, 0.15, 2)]),
  'tiroQuebrantador': SkillDef(id: 'tiroQuebrantador', name: 'Tiro Quebrantador', mp: 5, kind: _phys, power: 1.3, breakBonus: 1.0),
  // ---- debuffs ----
  'rompearmaduras': SkillDef(id: 'rompearmaduras', name: 'Rompearmaduras', mp: 5, kind: _phys, power: 1.3, breakBonus: 0.5, debuffs: [PartyBuff(_mark, 0.20, 3)]),
  'rugidoIntimidante': SkillDef(id: 'rugidoIntimidante', name: 'Rugido Intimidante', mp: 5, kind: _sup, allTargets: true, debuffs: [PartyBuff(_atk, -0.25, 2)]),
  'golpeDebilitante': SkillDef(id: 'golpeDebilitante', name: 'Golpe Debilitante', mp: 4, kind: _phys, power: 1.4, debuffs: [PartyBuff(_atk, -0.30, 2)]),
  'lentitud': SkillDef(id: 'lentitud', name: 'Lentitud', mp: 4, kind: _mag, power: 0.8, debuffs: [PartyBuff(_spd, -0.30, 2)]),
  'maldicion': SkillDef(id: 'maldicion', name: 'Maldición', mp: 9, kind: _mag, power: 0.6, allTargets: true, debuffs: [PartyBuff(_mark, 0.15, 2), PartyBuff(_atk, -0.15, 2)]),
  'pesoTiempo': SkillDef(id: 'pesoTiempo', name: 'Peso del Tiempo', mp: 8, kind: _mag, power: 1.0, allTargets: true, delay: 0.2, debuffs: [PartyBuff(_spd, -0.20, 2)]),
  // ---- control ----
  'golpeConmocion': SkillDef(id: 'golpeConmocion', name: 'Conmoción', mp: 5, kind: _phys, power: 1.1, status: StatusApplication(_stun, 1, chance: 0.5), breakBonus: 0.3),
  'silencio': SkillDef(id: 'silencio', name: 'Silencio', mp: 4, kind: _mag, power: 1.0, ultDrain: 50),
  'selloSagrado': SkillDef(id: 'selloSagrado', name: 'Sello Sagrado', mp: 5, kind: _mag, power: 0.9, ultDrain: 35, status: StatusApplication(_stun, 1, chance: 0.3)),
  'retroceso': SkillDef(id: 'retroceso', name: 'Ola de Retroceso', mp: 8, kind: _mag, power: 0.7, allTargets: true, delay: 0.35),
  // ---- buffs de grupo y línea de tiempo ----
  'inspirar': SkillDef(id: 'inspirar', name: 'Inspirar', mp: 5, kind: _sup, partyBuffs: [PartyBuff(_atk, 0.20, 2), PartyBuff(BuffStat.crit, 0.10, 2)]),
  'vientoPrisa': SkillDef(id: 'vientoPrisa', name: 'Viento de Prisa', mp: 6, kind: _sup, partyBuffs: [PartyBuff(_spd, 0.25, 2)]),
  'impulso': SkillDef(id: 'impulso', name: 'Impulso Temporal', mp: 5, kind: _sup, advanceAllies: 0.6),
  'ojoAguila': SkillDef(id: 'ojoAguila', name: 'Ojo de Águila', mp: 4, kind: _sup, partyBuffs: [PartyBuff(BuffStat.crit, 0.25, 2)]),
};

/// Familia de cada variante.
const Map<String, SkillFamily> kSkillVariantFamily = {
  'curaFocal': SkillFamily.heal,
  'rocio': SkillFamily.heal,
  'brotes': SkillFamily.heal,
  'semilla': SkillFamily.heal,
  'purificar': SkillFamily.heal,
  'resurreccion': SkillFamily.heal,
  'fenix': SkillFamily.heal,
  'graciaDesbordante': SkillFamily.heal,
  'marea': SkillFamily.heal,
  'flechaSanadora': SkillFamily.heal,
  'drenar': SkillFamily.heal,
  'sifon': SkillFamily.heal,
  'escudoArcano': SkillFamily.shield,
  'barrera': SkillFamily.shield,
  'egidaEspinosa': SkillFamily.shield,
  'escudoVolatil': SkillFamily.shield,
  'bastionCreciente': SkillFamily.shield,
  'retoEscudado': SkillFamily.shield,
  'murallaFe': SkillFamily.shield,
  'cupula': SkillFamily.shield,
  'flechaPerforante': SkillFamily.shot,
  'balaTraspasante': SkillFamily.shot,
  'tiroRebote': SkillFamily.shot,
  'dagaSaltarina': SkillFamily.shot,
  'disparoCargado': SkillFamily.shot,
  'viroteAsedio': SkillFamily.shot,
  'rafagaTriple': SkillFamily.shot,
  'cadencia': SkillFamily.shot,
  'flechaMarcadora': SkillFamily.shot,
  'senalar': SkillFamily.shot,
  'flechaIncendiaria': SkillFamily.shot,
  'flechaEscarcha': SkillFamily.shot,
  'balaCorrosiva': SkillFamily.shot,
  'tiroQuebrantador': SkillFamily.shot,
  'rompearmaduras': SkillFamily.debuff,
  'rugidoIntimidante': SkillFamily.debuff,
  'golpeDebilitante': SkillFamily.debuff,
  'lentitud': SkillFamily.debuff,
  'maldicion': SkillFamily.debuff,
  'pesoTiempo': SkillFamily.debuff,
  'golpeConmocion': SkillFamily.control,
  'silencio': SkillFamily.control,
  'selloSagrado': SkillFamily.control,
  'retroceso': SkillFamily.control,
  'inspirar': SkillFamily.buff,
  'vientoPrisa': SkillFamily.buff,
  'impulso': SkillFamily.buff,
  'ojoAguila': SkillFamily.buff,
};

/// Cada variante (y cada habilidad de Agua / Electro v0.7) se ve y suena
/// como una habilidad existente (color, FX y firma de sonido:
/// battle_presentation.md / audio.md). Sin arte nuevo.
const Map<String, String> kSkillLooks = {
  'curaFocal': 'curaM',
  'rocio': 'sanar',
  'brotes': 'aura',
  'semilla': 'aura',
  'purificar': 'bendicion',
  'resurreccion': 'curaM',
  'fenix': 'bendicion',
  'graciaDesbordante': 'cura',
  'marea': 'curaM',
  'flechaSanadora': 'venenosa',
  'drenar': 'dardo',
  'sifon': 'hendir',
  'escudoArcano': 'fortaleza',
  'barrera': 'fortaleza',
  'egidaEspinosa': 'escudoFe',
  'escudoVolatil': 'fortaleza',
  'bastionCreciente': 'escudoFe',
  'retoEscudado': 'provocar',
  'murallaFe': 'escudoFe',
  'cupula': 'fortaleza',
  'flechaPerforante': 'perfora',
  'balaTraspasante': 'perfora',
  'tiroRebote': 'certero',
  'dagaSaltarina': 'tajoGemelo',
  'disparoCargado': 'virote',
  'viroteAsedio': 'virote',
  'rafagaTriple': 'rafaga',
  'cadencia': 'metralla',
  'flechaMarcadora': 'certero',
  'senalar': 'apuntar',
  'flechaIncendiaria': 'flechaSolar',
  'flechaEscarcha': 'saeta',
  'balaCorrosiva': 'venenosa',
  'tiroQuebrantador': 'aturdir',
  'rompearmaduras': 'aplastar',
  'rugidoIntimidante': 'gritoGuerra',
  'golpeDebilitante': 'aplastar',
  'lentitud': 'detener',
  'maldicion': 'niebla',
  'pesoTiempo': 'detener',
  'golpeConmocion': 'aplastar',
  'silencio': 'misil',
  'selloSagrado': 'lanzaLuz',
  'retroceso': 'detener',
  'inspirar': 'gritoGuerra',
  'vientoPrisa': 'prisa',
  'impulso': 'aceleron',
  'ojoAguila': 'apuntar',
  // Agua y Electro v0.7: también se parecen a una existente.
  ...kElementalSkillLooks,
};
