import '../models/skill.dart';
import '../models/status.dart';

// `SK`, `ULTS` y `DUALS` del prototipo, 1:1. El color (`col`) y el
// elemento visual (`el`) son de la UI y no viven acá.

const _burn = StatusKind.burn;
const _poi = StatusKind.poison;
const _frz = StatusKind.freeze;
const _stun = StatusKind.stun;

const _phys = SkillKind.physical;
const _mag = SkillKind.magical;

/// Habilidades que otorgan las armas y los kits de clase (`SK`).
const Map<String, SkillDef> kSkills = {
  'giro': SkillDef(id: 'giro', name: 'Corte Giratorio', mp: 4, kind: _phys, power: 1.0, allTargets: true),
  'embestida': SkillDef(id: 'embestida', name: 'Embestida', mp: 4, kind: _phys, power: 1.2, delay: 0.45),
  'ignea': SkillDef(id: 'ignea', name: 'Golpe Ígneo', mp: 4, kind: _phys, power: 1.8, status: StatusApplication(_burn, 2)),
  'sismo': SkillDef(id: 'sismo', name: 'Golpe Sísmico', mp: 6, kind: _phys, power: 1.2, allTargets: true, delay: 0.3),
  'hendir': SkillDef(id: 'hendir', name: 'Hendidura Tóxica', mp: 5, kind: _phys, power: 2.0, status: StatusApplication(_poi, 2)),
  'tajoT': SkillDef(id: 'tajoT', name: 'Tajo Temporal', mp: 7, kind: _phys, power: 2.4, delay: 0.6, status: StatusApplication(_frz, 1)),
  'chispa': SkillDef(id: 'chispa', name: 'Chispa', mp: 3, kind: _mag, power: 1.6, status: StatusApplication(_burn, 1)),
  'cura': SkillDef(id: 'cura', name: 'Cura', mp: 5, kind: SkillKind.heal, power: 1.5, cleanse: 1),
  'bola': SkillDef(id: 'bola', name: 'Bola de Fuego', mp: 4, kind: _mag, power: 1.8, status: StatusApplication(_burn, 2)),
  'llamarada': SkillDef(id: 'llamarada', name: 'Llamarada', mp: 9, kind: _mag, power: 1.2, allTargets: true, status: StatusApplication(_burn, 1)),
  'lanzaH': SkillDef(id: 'lanzaH', name: 'Lanza de Hielo', mp: 4, kind: _mag, power: 1.6, status: StatusApplication(_frz, 2)),
  'ventisca': SkillDef(id: 'ventisca', name: 'Ventisca', mp: 9, kind: _mag, power: 1.1, allTargets: true, status: StatusApplication(_frz, 1)),
  'prisa': SkillDef(id: 'prisa', name: 'Prisa (aliados)', mp: 6, kind: SkillKind.haste),
  'detener': SkillDef(id: 'detener', name: 'Detener', mp: 6, kind: _mag, power: 0.7, delay: 1.0),
  'curaM': SkillDef(id: 'curaM', name: 'Cura Mayor', mp: 9, kind: SkillKind.heal, power: 2.4, cleanse: 5),
  'rafaga': SkillDef(id: 'rafaga', name: 'Ráfaga', mp: 4, kind: _phys, power: 0.9, allTargets: true),
  'venenosa': SkillDef(id: 'venenosa', name: 'Flecha Venenosa', mp: 3, kind: _phys, power: 0.7, status: StatusApplication(_poi, 3)),
  'certero': SkillDef(id: 'certero', name: 'Disparo Certero', mp: 3, kind: _phys, power: 1.6, critBonus: 0.4),
  'aturdir': SkillDef(id: 'aturdir', name: 'Disparo Aturdidor', mp: 4, kind: _phys, power: 0.8, delay: 0.7),
  'rayoF': SkillDef(id: 'rayoF', name: 'Flecha Rayo', mp: 4, kind: _phys, power: 1.9),
  'lluvia': SkillDef(id: 'lluvia', name: 'Lluvia de Flechas', mp: 6, kind: _phys, power: 1.1, allTargets: true),
  'sagrado': SkillDef(id: 'sagrado', name: 'Golpe Sagrado', mp: 3, kind: _phys, power: 1.5),
  'provocar': SkillDef(id: 'provocar', name: 'Provocar', mp: 3, kind: SkillKind.taunt, amount: 3),
  'escudoFe': SkillDef(id: 'escudoFe', name: 'Escudo de Fe', mp: 5, kind: SkillKind.guard),
  'bendicion': SkillDef(id: 'bendicion', name: 'Bendición', mp: 6, kind: SkillKind.heal, power: 1.0, cleanse: 5),
  'lanzaLuz': SkillDef(id: 'lanzaLuz', name: 'Lanza de Luz', mp: 4, kind: _mag, power: 1.7, delay: 0.3),
  'consagrar': SkillDef(id: 'consagrar', name: 'Consagrar', mp: 6, kind: _mag, power: 1.0, allTargets: true, status: StatusApplication(_burn, 1)),
  'juicio': SkillDef(id: 'juicio', name: 'Martillo del Juicio', mp: 7, kind: _phys, power: 2.3, delay: 0.8),
  'corteGlacial': SkillDef(id: 'corteGlacial', name: 'Corte Glacial', mp: 4, kind: _phys, power: 1.6, status: StatusApplication(_frz, 2)),
  'erupcion': SkillDef(id: 'erupcion', name: 'Erupción', mp: 7, kind: _phys, power: 1.1, allTargets: true, status: StatusApplication(_burn, 2)),
  'dardo': SkillDef(id: 'dardo', name: 'Dardo Tóxico', mp: 4, kind: _mag, power: 1.4, status: StatusApplication(_poi, 3)),
  'niebla': SkillDef(id: 'niebla', name: 'Niebla Tóxica', mp: 8, kind: _mag, power: 0.8, allTargets: true, status: StatusApplication(_poi, 2)),
  'infierno': SkillDef(id: 'infierno', name: 'Infierno', mp: 12, kind: _mag, power: 1.4, allTargets: true, status: StatusApplication(_burn, 2)),
  'saeta': SkillDef(id: 'saeta', name: 'Saeta Glacial', mp: 4, kind: _phys, power: 1.5, status: StatusApplication(_frz, 2)),
  'metralla': SkillDef(id: 'metralla', name: 'Metralla Tóxica', mp: 6, kind: _phys, power: 0.9, allTargets: true, status: StatusApplication(_poi, 2)),
  'aura': SkillDef(id: 'aura', name: 'Aura Restauradora', mp: 6, kind: SkillKind.regen, power: 0.6),
  'fortaleza': SkillDef(id: 'fortaleza', name: 'Fortaleza', mp: 3, kind: SkillKind.defenseUp, amount: 2),
  'proteccion': SkillDef(id: 'proteccion', name: 'Protección', mp: 5, kind: SkillKind.protect),
  'estocada': SkillDef(id: 'estocada', name: 'Estocada Firme', mp: 2, kind: _phys, power: 1.4, critBonus: 0.15),
  'temblor': SkillDef(id: 'temblor', name: 'Temblor', mp: 6, kind: _phys, power: 0.9, allTargets: true, status: StatusApplication(_stun, 1, chance: 0.15)),
  'sanar': SkillDef(id: 'sanar', name: 'Sanación', mp: 4, kind: SkillKind.heal, power: 1.1, cleanse: 1),
  'golpeEscudo': SkillDef(id: 'golpeEscudo', name: 'Golpe de Escudo', mp: 3, kind: _phys, power: 1.3, status: StatusApplication(_stun, 1, chance: 0.3)),
  'aplastar': SkillDef(id: 'aplastar', name: 'Aplastar', mp: 4, kind: _phys, power: 1.9, status: StatusApplication(_stun, 1, chance: 0.25)),
  'tajoCarmesi': SkillDef(id: 'tajoCarmesi', name: 'Tajo Carmesí', mp: 5, kind: _phys, power: 1.9, critBonus: 0.2, status: StatusApplication(_burn, 2)),
  'vendaval': SkillDef(id: 'vendaval', name: 'Vendaval Helado', mp: 8, kind: _phys, power: 1.2, allTargets: true, status: StatusApplication(_frz, 2)),
  'tajoOcaso': SkillDef(id: 'tajoOcaso', name: 'Tajo del Ocaso', mp: 6, kind: _phys, power: 2.2, status: StatusApplication(_poi, 3)),
  'descarga': SkillDef(id: 'descarga', name: 'Descarga', mp: 6, kind: _mag, power: 2.1),
  'plaga': SkillDef(id: 'plaga', name: 'Plaga', mp: 10, kind: _mag, power: 1.0, allTargets: true, status: StatusApplication(_poi, 3)),
  'sombra': SkillDef(id: 'sombra', name: 'Flecha Sombría', mp: 4, kind: _phys, power: 1.4, critBonus: 0.25, status: StatusApplication(_poi, 2)),
  'ceroAbs': SkillDef(id: 'ceroAbs', name: 'Cero Absoluto', mp: 6, kind: _phys, power: 1.8, status: StatusApplication(_frz, 3)),
  'flechaSolar': SkillDef(id: 'flechaSolar', name: 'Flecha Solar', mp: 5, kind: _phys, power: 1.7, status: StatusApplication(_burn, 2)),
  'perfora': SkillDef(id: 'perfora', name: 'Tiro Perforante', mp: 6, kind: _phys, power: 2.6, critBonus: 0.35),
  // ---- loot v2: tipos nuevos (lanza, varita, ballesta, dagas) ----
  'perforar': SkillDef(id: 'perforar', name: 'Lanza Perforante', mp: 4, kind: _phys, power: 1.7, critBonus: 0.2),
  'barrido': SkillDef(id: 'barrido', name: 'Barrido de Lanza', mp: 5, kind: _phys, power: 1.0, allTargets: true, delay: 0.2),
  'empalar': SkillDef(id: 'empalar', name: 'Empalar', mp: 6, kind: _phys, power: 2.1, status: StatusApplication(_stun, 1, chance: 0.25)),
  'misil': SkillDef(id: 'misil', name: 'Misil Arcano', mp: 2, kind: _mag, power: 1.4, critBonus: 0.15),
  'escarchaFugaz': SkillDef(id: 'escarchaFugaz', name: 'Escarcha Fugaz', mp: 4, kind: _mag, power: 1.2, delay: 0.2, status: StatusApplication(_frz, 1)),
  'rayoArcano': SkillDef(id: 'rayoArcano', name: 'Rayo Arcano', mp: 6, kind: _mag, power: 2.2),
  'virote': SkillDef(id: 'virote', name: 'Virote Pesado', mp: 5, kind: _phys, power: 2.2, delay: 0.4),
  'viroteIgneo': SkillDef(id: 'viroteIgneo', name: 'Virote Ígneo', mp: 5, kind: _phys, power: 1.8, status: StatusApplication(_burn, 2)),
  'tajoGemelo': SkillDef(id: 'tajoGemelo', name: 'Tajo Gemelo', mp: 3, kind: _phys, power: 1.3, critBonus: 0.3),
  'abanico': SkillDef(id: 'abanico', name: 'Abanico de Dagas', mp: 6, kind: _phys, power: 0.8, allTargets: true, status: StatusApplication(_poi, 2)),
};

/// ULT por tipo de arma (`ULTS`). No cuestan MP: requieren 100 de carga.
const Map<String, SkillDef> kUltimates = {
  'espada': SkillDef(id: 'ult_espada', name: 'Tajo Final', kind: _phys, power: 3.0, critBonus: 0.3),
  'hacha': SkillDef(id: 'ult_hacha', name: 'Cataclismo', kind: _phys, power: 2.0, allTargets: true, delay: 0.3),
  'báculo': SkillDef(id: 'ult_baculo', name: 'Meteoro', kind: _mag, power: 2.2, allTargets: true, status: StatusApplication(_burn, 2)),
  'tomo': SkillDef(id: 'ult_tomo', name: 'Paradoja', kind: _mag, power: 1.6, allTargets: true, delay: 1.0, status: StatusApplication(_frz, 2)),
  'arco': SkillDef(id: 'ult_arco', name: 'Tormenta de Flechas', kind: _phys, power: 1.8, allTargets: true, status: StatusApplication(_poi, 2)),
  'rifle': SkillDef(id: 'ult_rifle', name: 'Disparo Letal', kind: _phys, power: 3.6, critBonus: 0.4),
  'espada+escudo': SkillDef(id: 'ult_espada_escudo', name: 'Baluarte', kind: SkillKind.bulwark),
  'maza+escudo': SkillDef(id: 'ult_maza_escudo', name: 'Juicio Divino', kind: _mag, power: 1.6, allTargets: true, status: StatusApplication(_stun, 1)),
  'martillo+escudo': SkillDef(id: 'ult_martillo_escudo', name: 'Martillo Celestial', kind: _phys, power: 4.0, status: StatusApplication(_stun, 1)),
};

/// ULT de los tipos de arma nuevos de loot v2 (loot.md § 8.2). Viven
/// aparte de [kUltimates] hasta que la UI tenga su cinemática y su
/// sonido; el motor usa [kAllUltimates].
const Map<String, SkillDef> kNewUltimates = {
  'lanza': SkillDef(id: 'ult_lanza', name: 'Lluvia de Lanzas', kind: _phys, power: 1.7, allTargets: true, delay: 0.4),
  'varita': SkillDef(id: 'ult_varita', name: 'Tormenta Arcana', kind: _mag, power: 1.9, allTargets: true, critBonus: 0.2),
  'ballesta': SkillDef(id: 'ult_ballesta', name: 'Andanada', kind: _phys, power: 3.2, status: StatusApplication(_stun, 1)),
  'dagas': SkillDef(id: 'ult_dagas', name: 'Danza de Mil Cortes', kind: _phys, power: 2.8, critBonus: 0.5),
};

/// Todas las ULT por tipo de arma (las del prototipo + las nuevas).
const Map<String, SkillDef> kAllUltimates = {...kUltimates, ...kNewUltimates};

/// Ataques combinados (`DUALS`). La clave son los dos ids de clase
/// ordenados alfabéticamente y unidos con '+' (ver [dualKey]).
const Map<String, DualDef> kDuals = {
  'guerrero+maga': DualDef('Espada Llameante', StatusApplication(_burn, 2), 1.5),
  'guerrero+tirador': DualDef('Cruz Tormenta', StatusApplication(_poi, 2), 1.5),
  'maga+tirador': DualDef('Lluvia Estelar', StatusApplication(_frz, 2), 1.5),
  'guerrero+guerrero': DualDef('Doble Tajo X', StatusApplication(_frz, 1), 1.45),
  'maga+maga': DualDef('Supernova', StatusApplication(_burn, 2), 1.45),
  'guerrero+paladin': DualDef('Juicio Cruzado', StatusApplication(_frz, 1), 1.5),
  'maga+paladin': DualDef('Luz Purificadora', StatusApplication(_burn, 2), 1.5),
  'paladin+tirador': DualDef('Flecha Bendita', StatusApplication(_poi, 2), 1.5),
  'paladin+paladin': DualDef('Muralla Sagrada', StatusApplication(_frz, 2), 1.45),
  'tirador+tirador': DualDef('Fuego Cruzado', StatusApplication(_poi, 2), 1.45),
};

String dualKey(String classA, String classB) =>
    ([classA, classB]..sort()).join('+');
