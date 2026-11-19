import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart';
import '../models/status.dart';

// Habilidades de Agua y Electro v0.7 (docs/specs/elemental_reactions.md
// § 1 y § 5.1; tabla en docs/specs/combat.md § "Elementos"). Se suman a
// `kSkills`; las armas que las dan están en loot.md § 8.7. El estado que
// dejan (Mojado / Cargado) dura lo que dice el catálogo de estados
// elementales (`kElementStatuses`), no los stacks.

const _wet = StatusApplication(StatusKind.wet, 1);
const _charged = StatusApplication(StatusKind.charged, 1);

const _phys = SkillKind.physical;
const _mag = SkillKind.magical;
const _sup = SkillKind.support;

/// Las habilidades elementales nuevas, por id.
const Map<String, SkillDef> kElementalSkills = {
  // ---- Agua: dejan Mojado (lo detonan Electro y Hielo) y detonan
  // Cargado (Cortocircuito). ----
  'chorro': SkillDef(id: 'chorro', name: 'Chorro de Agua', mp: 3, kind: _mag, power: 1.5, status: _wet),
  'oleada': SkillDef(id: 'oleada', name: 'Oleada', mp: 8, kind: _mag, power: 1.0, allTargets: true, status: _wet),
  'geiser': SkillDef(id: 'geiser', name: 'Géiser', mp: 5, kind: _mag, power: 1.8, delay: 0.3, status: _wet),
  'torrente': SkillDef(id: 'torrente', name: 'Torrente', mp: 7, kind: _mag, power: 2.3, breaks: true),
  'bruma': SkillDef(id: 'bruma', name: 'Bruma Densa', mp: 6, kind: _mag, power: 0.5, allTargets: true, status: _wet, debuffs: [PartyBuff(BuffStat.speed, -0.10, 2)]),
  'escudoAgua': SkillDef(id: 'escudoAgua', name: 'Escudo de Agua', mp: 5, kind: _sup, allyShield: 0.20, shieldTurns: 2),
  'tajoMarea': SkillDef(id: 'tajoMarea', name: 'Tajo de Marea', mp: 4, kind: _phys, power: 1.6, status: _wet),
  'remolino': SkillDef(id: 'remolino', name: 'Remolino', mp: 6, kind: _phys, power: 0.9, allTargets: true, status: _wet),
  'lanzaMareas': SkillDef(id: 'lanzaMareas', name: 'Lanza de las Mareas', mp: 5, kind: _phys, power: 1.5, pierce: 0.5, status: _wet),
  'flechaAcuatica': SkillDef(id: 'flechaAcuatica', name: 'Flecha Acuática', mp: 3, kind: _phys, power: 1.3, status: _wet),
  // ---- Electro: dejan Cargado (lo detona Agua) y detonan Mojado
  // (Electrocución). ----
  'chispazo': SkillDef(id: 'chispazo', name: 'Chispazo', mp: 3, kind: _mag, power: 1.5, status: _charged),
  'cadenaRayos': SkillDef(id: 'cadenaRayos', name: 'Cadena de Rayos', mp: 7, kind: _mag, power: 1.3, bounces: 2, status: _charged),
  'tormentaElectrica': SkillDef(id: 'tormentaElectrica', name: 'Tormenta Eléctrica', mp: 10, kind: _mag, power: 1.1, allTargets: true, status: _charged),
  'descargaEstatica': SkillDef(id: 'descargaEstatica', name: 'Descarga Estática', mp: 5, kind: _mag, power: 1.2, status: _charged, extraStatuses: [StatusApplication(StatusKind.stun, 1, chance: 0.2)]),
  'campoEstatico': SkillDef(id: 'campoEstatico', name: 'Campo Estático', mp: 6, kind: _mag, power: 0.5, allTargets: true, status: _charged, debuffs: [PartyBuff(BuffStat.damageTaken, 0.10, 2)]),
  'corriente': SkillDef(id: 'corriente', name: 'Corriente', mp: 5, kind: _sup, advanceAllies: 0.35),
  'golpeTrueno': SkillDef(id: 'golpeTrueno', name: 'Golpe de Trueno', mp: 5, kind: _phys, power: 1.8, breakBonus: 0.3, status: _charged),
  'dagaElectrica': SkillDef(id: 'dagaElectrica', name: 'Puñalada Eléctrica', mp: 3, kind: _phys, power: 1.3, critBonus: 0.2, status: _charged),
  'flechaVoltaica': SkillDef(id: 'flechaVoltaica', name: 'Flecha Voltaica', mp: 4, kind: _phys, power: 1.5, status: _charged),
  'relampago': SkillDef(id: 'relampago', name: 'Relámpago', mp: 6, kind: _phys, power: 2.3, critBonus: 0.15),
};

/// Forma de entrega para la fusión (loot.md § 16.1), como `kSkillDelivery`.
const Map<String, SkillDelivery> kElementalSkillDelivery = {
  'chorro': SkillDelivery.any,
  'oleada': SkillDelivery.any,
  'geiser': SkillDelivery.any,
  'torrente': SkillDelivery.any,
  'bruma': SkillDelivery.any,
  'escudoAgua': SkillDelivery.any,
  'tajoMarea': SkillDelivery.melee,
  'remolino': SkillDelivery.melee,
  'lanzaMareas': SkillDelivery.melee,
  'flechaAcuatica': SkillDelivery.ranged,
  'chispazo': SkillDelivery.any,
  'cadenaRayos': SkillDelivery.any,
  'tormentaElectrica': SkillDelivery.any,
  'descargaEstatica': SkillDelivery.any,
  'campoEstatico': SkillDelivery.any,
  'corriente': SkillDelivery.any,
  'golpeTrueno': SkillDelivery.melee,
  'dagaElectrica': SkillDelivery.melee,
  'flechaVoltaica': SkillDelivery.ranged,
  'relampago': SkillDelivery.ranged,
};

/// Cada habilidad nueva se ve y suena como una existente (color, FX y
/// firma de sonido, como `kSkillLooks` de las variantes) hasta que tenga
/// arte propio.
const Map<String, String> kElementalSkillLooks = {
  'chorro': 'dardo',
  'oleada': 'ventisca',
  'geiser': 'erupcion',
  'torrente': 'rayoArcano',
  'bruma': 'niebla',
  'escudoAgua': 'fortaleza',
  'tajoMarea': 'corteGlacial',
  'remolino': 'giro',
  'lanzaMareas': 'perforar',
  'flechaAcuatica': 'saeta',
  'chispazo': 'chispa',
  'cadenaRayos': 'descarga',
  'tormentaElectrica': 'infierno',
  'descargaEstatica': 'descarga',
  'campoEstatico': 'temblor',
  'corriente': 'prisa',
  'golpeTrueno': 'aplastar',
  'dagaElectrica': 'tajoGemelo',
  'flechaVoltaica': 'rayoF',
  'relampago': 'rayoF',
};
