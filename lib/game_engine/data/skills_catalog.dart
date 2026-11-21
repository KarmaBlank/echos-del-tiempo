import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart';
import '../models/status.dart';
import 'ascension_catalog.dart';
import 'elemental_skills_catalog.dart';
import 'skill_variants_catalog.dart';
import 'summoner_catalog.dart';

// `SK`, `ULTS` y `DUALS` del prototipo, 1:1. El color (`col`) y el
// elemento visual (`el`) son de la UI y no viven acá.

const _burn = StatusKind.burn;
const _poi = StatusKind.poison;
const _frz = StatusKind.freeze;
const _stun = StatusKind.stun;

const _phys = SkillKind.physical;
const _mag = SkillKind.magical;

/// Habilidad base Quebrar de las armas físicas y la de los lanzadores
/// (combo_balance.md § 5.1).
const kQuebrarId = 'quebrar';
const kQuebrarArcanoId = 'quebrarArcano';
const kBaseQuebrarIds = {kQuebrarId, kQuebrarArcanoId};

/// La Quebrar base del tipo de arma [weaponType]: la arcana para los
/// lanzadores (báculo, varita, tomo), la física para el resto.
String quebrarSkillFor(String? weaponType) =>
    const {'báculo', 'varita', 'tomo'}.contains(weaponType)
        ? kQuebrarArcanoId
        : kQuebrarId;

/// Habilidades de combo de cada clase (combo_balance.md § 5.2.1,
/// propuesta del paso 7): el motor las agrega al kit, antes de Quebrar,
/// con cualquier arma. Como Quebrar, no están en `WeaponDef.skillIds` ni
/// se trasladan. Cada clase prepara algo; Maga y Tirador además detonan
/// la Convergencia que prepara el otro.
const Map<String, List<String>> kClassComboSkill = {
  'guerrero': ['brasaEco'],
  'maga': ['ascuaEco', 'ignicionEco'],
  'tirador': ['puaEco', 'ponzonaEco'],
  'paladin': ['selloInstante'],
};

/// Habilidades que agrega el motor (Quebrar base y las de combo de
/// clase): no vienen de un arma ni se trasladan por fusión.
final Set<String> kEngineSkillIds = {
  ...kBaseQuebrarIds,
  for (final l in kClassComboSkill.values) ...l,
};

/// Habilidades que otorgan las armas (`SK`) y los kits de las ascensiones.
const Map<String, SkillDef> kSkills = {
  // Quebrar base (combo_balance.md § 5.1): toda arma la trae en su kit.
  // v0.9.1: no hace daño (power 0); solo cierra el quiebre. Es la ranura
  // base de Quebrar del arma (loot.md § 16.3): se puede reemplazar.
  // Paso 7 (§ 5.2): cuesta 2 de Pulso (sin MP) y pide objetivo Fisurado.
  kQuebrarId: SkillDef(id: kQuebrarId, name: 'Quebrar', kind: _phys, power: 0, breaks: true, pulse: 2, requires: [SkillReq.targetFissured()]),
  kQuebrarArcanoId: SkillDef(id: kQuebrarArcanoId, name: 'Quebrar arcano', kind: _mag, power: 0, breaks: true, pulse: 2, requires: [SkillReq.targetFissured()]),
  // Combo de clase (combo_balance.md § 5.2, propuesta del paso 7).
  // Guerrero y Maga preparan Quemadura, Tirador Veneno, Paladín Marca;
  // Maga detona el Veneno y Tirador la Quemadura.
  'brasaEco': SkillDef(id: 'brasaEco', name: 'Brasa Fugaz', mp: 2, kind: _phys, power: 0.7, status: StatusApplication(_burn, 3), instant: true),
  'ascuaEco': SkillDef(id: 'ascuaEco', name: 'Ascua Fugaz', mp: 2, kind: _mag, power: 0.6, status: StatusApplication(_burn, 2), instant: true),
  'puaEco': SkillDef(id: 'puaEco', name: 'Púa Fugaz', mp: 2, kind: _phys, power: 0.6, status: StatusApplication(_poi, 3), instant: true),
  'selloInstante': SkillDef(id: 'selloInstante', name: 'Sello del Instante', mp: 2, kind: SkillKind.support, debuffs: [PartyBuff(BuffStat.damageTaken, 0.20, 2)], instant: true),
  'ignicionEco': SkillDef(id: 'ignicionEco', name: 'Ignición Convergente', mp: 3, kind: _mag, power: 1.2, pulse: 2, requires: [SkillReq.targetStacks(_poi, 5)]),
  'ponzonaEco': SkillDef(id: 'ponzonaEco', name: 'Ponzoña Convergente', mp: 3, kind: _phys, power: 1.2, pulse: 2, requires: [SkillReq.targetStacks(_burn, 5)]),
  'giro': SkillDef(id: 'giro', name: 'Corte Giratorio', mp: 4, kind: _phys, power: 1.0, allTargets: true),
  'embestida': SkillDef(id: 'embestida', name: 'Embestida', mp: 4, kind: _phys, power: 1.2, delay: 0.45),
  'ignea': SkillDef(id: 'ignea', name: 'Golpe Ígneo', mp: 4, kind: _phys, power: 1.8, status: StatusApplication(_burn, 2)),
  'sismo': SkillDef(id: 'sismo', name: 'Golpe Sísmico', mp: 6, kind: _phys, power: 1.2, allTargets: true, delay: 0.3),
  'hendir': SkillDef(id: 'hendir', name: 'Hendidura Tóxica', mp: 5, kind: _phys, power: 2.0, status: StatusApplication(_poi, 2), breaks: true),
  'tajoT': SkillDef(id: 'tajoT', name: 'Tajo Temporal', mp: 7, kind: _phys, power: 2.4, delay: 0.6, status: StatusApplication(_frz, 1), breaks: true),
  'chispa': SkillDef(id: 'chispa', name: 'Chispa', mp: 3, kind: _mag, power: 1.6, status: StatusApplication(_burn, 1), instant: true),
  'cura': SkillDef(id: 'cura', name: 'Cura', mp: 5, kind: SkillKind.heal, power: 1.5, cleanse: 1),
  'bola': SkillDef(id: 'bola', name: 'Bola de Fuego', mp: 4, kind: _mag, power: 1.8, status: StatusApplication(_burn, 2)),
  'llamarada': SkillDef(id: 'llamarada', name: 'Llamarada', mp: 9, kind: _mag, power: 1.2, allTargets: true, status: StatusApplication(_burn, 1)),
  'lanzaH': SkillDef(id: 'lanzaH', name: 'Lanza de Hielo', mp: 4, kind: _mag, power: 1.6, status: StatusApplication(_frz, 2)),
  'ventisca': SkillDef(id: 'ventisca', name: 'Ventisca', mp: 9, kind: _mag, power: 1.1, allTargets: true, status: StatusApplication(_frz, 1)),
  'prisa': SkillDef(id: 'prisa', name: 'Prisa (aliados)', mp: 6, kind: SkillKind.haste),
  'detener': SkillDef(id: 'detener', name: 'Detener', mp: 6, kind: _mag, power: 0.7, delay: 1.0),
  'curaM': SkillDef(id: 'curaM', name: 'Cura Mayor', mp: 9, kind: SkillKind.heal, power: 2.4, cleanse: 5),
  'rafaga': SkillDef(id: 'rafaga', name: 'Ráfaga', mp: 4, kind: _phys, power: 0.9, allTargets: true),
  'venenosa': SkillDef(id: 'venenosa', name: 'Flecha Venenosa', mp: 3, kind: _phys, power: 0.7, status: StatusApplication(_poi, 3), instant: true),
  'certero': SkillDef(id: 'certero', name: 'Disparo Certero', mp: 3, kind: _phys, power: 1.6, critBonus: 0.4),
  'aturdir': SkillDef(id: 'aturdir', name: 'Disparo Aturdidor', mp: 4, kind: _phys, power: 0.8, delay: 0.7),
  'rayoF': SkillDef(id: 'rayoF', name: 'Flecha Rayo', mp: 4, kind: _phys, power: 1.9, breaks: true),
  'lluvia': SkillDef(id: 'lluvia', name: 'Lluvia de Flechas', mp: 6, kind: _phys, power: 1.1, allTargets: true),
  'sagrado': SkillDef(id: 'sagrado', name: 'Golpe Sagrado', mp: 3, kind: _phys, power: 1.5),
  'provocar': SkillDef(id: 'provocar', name: 'Provocar', mp: 3, kind: SkillKind.taunt, amount: 3),
  'escudoFe': SkillDef(id: 'escudoFe', name: 'Escudo de Fe', mp: 5, kind: SkillKind.guard),
  'bendicion': SkillDef(id: 'bendicion', name: 'Bendición', mp: 6, kind: SkillKind.heal, power: 1.0, cleanse: 5),
  'lanzaLuz': SkillDef(id: 'lanzaLuz', name: 'Lanza de Luz', mp: 4, kind: _mag, power: 1.7, delay: 0.3),
  'consagrar': SkillDef(id: 'consagrar', name: 'Consagrar', mp: 6, kind: _mag, power: 1.0, allTargets: true, status: StatusApplication(_burn, 1)),
  'juicio': SkillDef(id: 'juicio', name: 'Martillo del Juicio', mp: 7, kind: _phys, power: 2.3, delay: 0.8, breaks: true),
  'corteGlacial': SkillDef(id: 'corteGlacial', name: 'Corte Glacial', mp: 4, kind: _phys, power: 1.6, status: StatusApplication(_frz, 2)),
  'erupcion': SkillDef(id: 'erupcion', name: 'Erupción', mp: 7, kind: _phys, power: 1.1, allTargets: true, status: StatusApplication(_burn, 2)),
  'dardo': SkillDef(id: 'dardo', name: 'Dardo Tóxico', mp: 4, kind: _mag, power: 1.4, status: StatusApplication(_poi, 3), pulse: 1, instant: true),
  'niebla': SkillDef(id: 'niebla', name: 'Niebla Tóxica', mp: 8, kind: _mag, power: 0.8, allTargets: true, status: StatusApplication(_poi, 2)),
  'infierno': SkillDef(id: 'infierno', name: 'Infierno', mp: 12, kind: _mag, power: 1.4, allTargets: true, status: StatusApplication(_burn, 2)),
  'saeta': SkillDef(id: 'saeta', name: 'Saeta Glacial', mp: 4, kind: _phys, power: 1.5, status: StatusApplication(_frz, 2)),
  'metralla': SkillDef(id: 'metralla', name: 'Metralla Tóxica', mp: 6, kind: _phys, power: 0.9, allTargets: true, status: StatusApplication(_poi, 2)),
  // 'aura', 'fortaleza' y 'proteccion' (el viejo kit del Paladín) son
  // desde v0.5 el kit del Guardián: viven en `kAscensionSkills`.
  'estocada': SkillDef(id: 'estocada', name: 'Estocada Firme', mp: 2, kind: _phys, power: 1.8, critBonus: 0.15, breaks: true),
  'temblor': SkillDef(id: 'temblor', name: 'Temblor', mp: 6, kind: _phys, power: 0.9, allTargets: true, status: StatusApplication(_stun, 1, chance: 0.15)),
  'sanar': SkillDef(id: 'sanar', name: 'Sanación', mp: 4, kind: SkillKind.heal, power: 1.1, cleanse: 1),
  'golpeEscudo': SkillDef(id: 'golpeEscudo', name: 'Golpe de Escudo', mp: 3, kind: _phys, power: 1.3, status: StatusApplication(_stun, 1, chance: 0.3), breaks: true),
  'aplastar': SkillDef(id: 'aplastar', name: 'Aplastar', mp: 4, kind: _phys, power: 1.9, status: StatusApplication(_stun, 1, chance: 0.25), breaks: true),
  'tajoCarmesi': SkillDef(id: 'tajoCarmesi', name: 'Tajo Carmesí', mp: 5, kind: _phys, power: 1.9, critBonus: 0.2, status: StatusApplication(_burn, 2)),
  'vendaval': SkillDef(id: 'vendaval', name: 'Vendaval Helado', mp: 8, kind: _phys, power: 1.2, allTargets: true, status: StatusApplication(_frz, 2)),
  'tajoOcaso': SkillDef(id: 'tajoOcaso', name: 'Tajo del Ocaso', mp: 6, kind: _phys, power: 2.2, status: StatusApplication(_poi, 3)),
  'descarga': SkillDef(id: 'descarga', name: 'Descarga', mp: 6, kind: _mag, power: 2.1, breaks: true),
  'plaga': SkillDef(id: 'plaga', name: 'Plaga', mp: 10, kind: _mag, power: 1.0, allTargets: true, status: StatusApplication(_poi, 3)),
  'sombra': SkillDef(id: 'sombra', name: 'Flecha Sombría', mp: 4, kind: _phys, power: 1.4, critBonus: 0.25, status: StatusApplication(_poi, 2)),
  'ceroAbs': SkillDef(id: 'ceroAbs', name: 'Cero Absoluto', mp: 6, kind: _phys, power: 1.8, status: StatusApplication(_frz, 3)),
  'flechaSolar': SkillDef(id: 'flechaSolar', name: 'Flecha Solar', mp: 5, kind: _phys, power: 1.7, status: StatusApplication(_burn, 2)),
  'perfora': SkillDef(id: 'perfora', name: 'Tiro Perforante', mp: 6, kind: _phys, power: 2.6, critBonus: 0.35, breaks: true),
  // ---- loot v2: tipos nuevos (lanza, varita, ballesta, dagas) ----
  'perforar': SkillDef(id: 'perforar', name: 'Lanza Perforante', mp: 4, kind: _phys, power: 1.7, critBonus: 0.2),
  'barrido': SkillDef(id: 'barrido', name: 'Barrido de Lanza', mp: 5, kind: _phys, power: 1.0, allTargets: true, delay: 0.2),
  'empalar': SkillDef(id: 'empalar', name: 'Empalar', mp: 6, kind: _phys, power: 2.1, status: StatusApplication(_stun, 1, chance: 0.25), breaks: true),
  'misil': SkillDef(id: 'misil', name: 'Misil Arcano', mp: 2, kind: _mag, power: 1.4, critBonus: 0.15),
  'escarchaFugaz': SkillDef(id: 'escarchaFugaz', name: 'Escarcha Fugaz', mp: 4, kind: _mag, power: 1.2, delay: 0.2, status: StatusApplication(_frz, 1)),
  'rayoArcano': SkillDef(id: 'rayoArcano', name: 'Rayo Arcano', mp: 6, kind: _mag, power: 2.2, breaks: true),
  'virote': SkillDef(id: 'virote', name: 'Virote Pesado', mp: 5, kind: _phys, power: 2.2, delay: 0.4, breaks: true),
  'viroteIgneo': SkillDef(id: 'viroteIgneo', name: 'Virote Ígneo', mp: 5, kind: _phys, power: 1.8, status: StatusApplication(_burn, 2)),
  'tajoGemelo': SkillDef(id: 'tajoGemelo', name: 'Tajo Gemelo', mp: 3, kind: _phys, power: 1.3, critBonus: 0.3, breaks: true),
  'abanico': SkillDef(id: 'abanico', name: 'Abanico de Dagas', mp: 6, kind: _phys, power: 0.8, allTargets: true, status: StatusApplication(_poi, 2)),
  // ---- kit de las ascensiones (docs/specs/ascension.md § 4) ----
  ...kAscensionSkills,
  // ---- variantes v0.5 (docs/specs/combat.md § "Variantes de habilidades") ----
  ...kSkillVariants,
  // ---- Agua y Electro v0.7 (docs/specs/elemental_reactions.md) ----
  ...kElementalSkills,
  // ---- Invocador v0.8.1 (docs/specs/summoner.md) ----
  ...kSummonerSkills,
};

const _melee = SkillDelivery.melee;
const _ranged = SkillDelivery.ranged;
const _any = SkillDelivery.any;

/// Forma de entrega de cada habilidad de arma trasladable (loot.md
/// § 16.1). Explícita, sin adivinar por el nombre: `ranged` = físicas de
/// arco / ballesta / rifle (flechas, disparos, balas, virotes); `melee`
/// = las demás físicas; `any` = todo lo que no es un golpe con el arma.
/// Cubre todo [kSkills] menos el kit de ascensión (nunca se traslada;
/// test).
const Map<String, SkillDelivery> kSkillDelivery = {
  'giro': _melee, // Corte Giratorio
  'embestida': _melee, // Embestida
  'ignea': _melee, // Golpe Ígneo
  'sismo': _melee, // Golpe Sísmico
  'hendir': _melee, // Hendidura Tóxica
  'tajoT': _melee, // Tajo Temporal
  'chispa': _any, // Chispa
  'cura': _any, // Cura
  'bola': _any, // Bola de Fuego
  'llamarada': _any, // Llamarada
  'lanzaH': _any, // Lanza de Hielo
  'ventisca': _any, // Ventisca
  'prisa': _any, // Prisa (aliados)
  'detener': _any, // Detener
  'curaM': _any, // Cura Mayor
  'rafaga': _ranged, // Ráfaga
  'venenosa': _ranged, // Flecha Venenosa
  'certero': _ranged, // Disparo Certero
  'aturdir': _ranged, // Disparo Aturdidor
  'rayoF': _ranged, // Flecha Rayo
  'lluvia': _ranged, // Lluvia de Flechas
  'sagrado': _melee, // Golpe Sagrado
  'provocar': _any, // Provocar
  'escudoFe': _any, // Escudo de Fe
  'bendicion': _any, // Bendición
  'lanzaLuz': _any, // Lanza de Luz
  'consagrar': _any, // Consagrar
  'juicio': _melee, // Martillo del Juicio
  'corteGlacial': _melee, // Corte Glacial
  'erupcion': _melee, // Erupción
  'dardo': _any, // Dardo Tóxico
  'niebla': _any, // Niebla Tóxica
  'infierno': _any, // Infierno
  'saeta': _ranged, // Saeta Glacial
  'metralla': _ranged, // Metralla Tóxica
  'estocada': _melee, // Estocada Firme
  'temblor': _melee, // Temblor
  'sanar': _any, // Sanación
  'golpeEscudo': _melee, // Golpe de Escudo
  'aplastar': _melee, // Aplastar
  'tajoCarmesi': _melee, // Tajo Carmesí
  'vendaval': _melee, // Vendaval Helado
  'tajoOcaso': _melee, // Tajo del Ocaso
  'descarga': _any, // Descarga
  'plaga': _any, // Plaga
  'sombra': _ranged, // Flecha Sombría
  'ceroAbs': _ranged, // Cero Absoluto
  'flechaSolar': _ranged, // Flecha Solar
  'perfora': _ranged, // Tiro Perforante
  'perforar': _melee, // Lanza Perforante
  'barrido': _melee, // Barrido de Lanza
  'empalar': _melee, // Empalar
  'misil': _any, // Misil Arcano
  'escarchaFugaz': _any, // Escarcha Fugaz
  'rayoArcano': _any, // Rayo Arcano
  'virote': _ranged, // Virote Pesado
  'viroteIgneo': _ranged, // Virote Ígneo
  'tajoGemelo': _melee, // Tajo Gemelo
  'abanico': _melee, // Abanico de Dagas
  'curaFocal': _any, // Cura Focalizada
  'rocio': _any, // Rocío Sanador
  'brotes': _any, // Brotes de Vida
  'semilla': _any, // Semilla Vital
  'purificar': _any, // Purificación
  'resurreccion': _any, // Resurrección
  'fenix': _any, // Llama Fénix
  'graciaDesbordante': _any, // Gracia Desbordante
  'marea': _any, // Marea Vital
  'flechaSanadora': _ranged, // Flecha Sanadora
  'drenar': _any, // Drenar Vida
  'sifon': _melee, // Sifón Vital
  'escudoArcano': _any, // Escudo Arcano
  'barrera': _any, // Barrera
  'egidaEspinosa': _any, // Égida Espinosa
  'escudoVolatil': _any, // Escudo Volátil
  'bastionCreciente': _any, // Bastión Creciente
  'retoEscudado': _any, // Reto Escudado
  'murallaFe': _any, // Muralla de Fe
  'cupula': _any, // Cúpula Arcana
  'flechaPerforante': _ranged, // Flecha Perforante
  'balaTraspasante': _ranged, // Bala Traspasante
  'tiroRebote': _ranged, // Tiro de Rebote
  'dagaSaltarina': _melee, // Daga Saltarina
  'disparoCargado': _ranged, // Disparo Cargado
  'viroteAsedio': _ranged, // Virote de Asedio
  'rafagaTriple': _ranged, // Ráfaga Triple
  'cadencia': _ranged, // Cadencia Letal
  'flechaMarcadora': _ranged, // Flecha Marcadora
  'senalar': _any, // Señalar Presa
  'flechaIncendiaria': _ranged, // Flecha Incendiaria
  'flechaEscarcha': _ranged, // Flecha de Escarcha
  'balaCorrosiva': _ranged, // Bala Corrosiva
  'tiroQuebrantador': _ranged, // Tiro Quebrantador
  'rompearmaduras': _melee, // Rompearmaduras
  'rugidoIntimidante': _any, // Rugido Intimidante
  'golpeDebilitante': _melee, // Golpe Debilitante
  'lentitud': _any, // Lentitud
  'maldicion': _any, // Maldición
  'pesoTiempo': _any, // Peso del Tiempo
  'golpeConmocion': _melee, // Conmoción
  'silencio': _any, // Silencio
  'selloSagrado': _any, // Sello Sagrado
  'retroceso': _any, // Ola de Retroceso
  'inspirar': _any, // Inspirar
  'vientoPrisa': _any, // Viento de Prisa
  'impulso': _any, // Impulso Temporal
  'ojoAguila': _any, // Ojo de Águila
  // Agua y Electro v0.7.
  ...kElementalSkillDelivery,
  // Invocador v0.8.1.
  ...kSummonerSkillDelivery,
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
