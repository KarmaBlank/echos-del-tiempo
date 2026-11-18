import '../models/elements.dart';
import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart';
import '../models/status.dart';
import '../models/item.dart';
import 'summoner_catalog.dart' show kSummonerUltimates, kWeaponUltOf;
import 'uniques_catalog.dart';

// ULT de camino (docs/specs/branch_ults.md): 3 por cada camino del árbol
// v6 (menos el Invocador, que trae las suyas en summoner_catalog.dart),
// con el tema del camino. Decisión del dueño: NO van en el árbol; salen
// en armas, como mod especial "ULT: <nombre>" (Raro 8%, Épico 20%,
// Legendarios con ULT propia fija) y reemplazan la ULT del tipo de arma.
// Solo usan campos que el motor ya entiende (sin efectos nuevos).

const _phys = SkillKind.physical;
const _mag = SkillKind.magical;
const _sup = SkillKind.support;
const _heal = SkillKind.heal;
const _regen = SkillKind.regen;
const _taunt = SkillKind.taunt;

const _burn = StatusKind.burn;
const _poi = StatusKind.poison;
const _frz = StatusKind.freeze;
const _stun = StatusKind.stun;
const _holy = StatusKind.holy;
const _wet = StatusKind.wet;
const _chg = StatusKind.charged;

const _atk = BuffStat.attack;
const _spd = BuffStat.speed;
const _crit = BuffStat.crit;
const _dmg = BuffStat.damage;
const _taken = BuffStat.damageTaken;
const _guard = BuffStat.guard;
const _ls = BuffStat.lifeSteal;

/// Una ULT de camino: camino, habilidad y la ULT existente a la que se
/// parece (guion de cinemática, FX y sonido; sin arte nuevo).
typedef BranchUlt = (String path, SkillDef skill, String look);

const _espada = 'ult_espada';
const _hacha = 'ult_hacha';
const _baculo = 'ult_baculo';
const _tomo = 'ult_tomo';
const _arco = 'ult_arco';
const _rifle = 'ult_rifle';
const _bulwark = 'ult_espada_escudo';
const _maza = 'ult_maza_escudo';
const _martillo = 'ult_martillo_escudo';
const _lanza = 'ult_lanza';
const _varita = 'ult_varita';
const _ballesta = 'ult_ballesta';
const _dagas = 'ult_dagas';
const _berserker = 'ult_berserker';
const _senor = 'ult_senorGuerra';
const _crono = 'ult_cronomante';
const _elem = 'ult_elementalista';
const _franco = 'ult_francotirador';
const _trampero = 'ult_trampero';
const _templario = 'ult_templario';
const _guardian = 'ult_guardian';

const List<BranchUlt> kBranchUltList = [
  // ================= Guerrero (v4) =================
  ('muralla', SkillDef(id: 'ult_muroViviente', name: 'Muro Viviente', kind: _taunt, amount: 2, selfShield: 0.35, shieldTurns: 3, shieldReflect: 0.5), _bulwark),
  ('muralla', SkillDef(id: 'ult_contragolpe', name: 'Contragolpe Total', kind: _phys, power: 2.4, status: StatusApplication(_stun, 1), selfBuff: PartyBuff(_guard, 0.30, 2)), _martillo),
  ('muralla', SkillDef(id: 'ult_espinasAcero', name: 'Espinas de Acero', kind: _sup, partyShield: 0.15, partyShieldTurns: 2, shieldReflect: 0.6), _guardian),
  ('sangre', SkillDef(id: 'ult_banqueteSangre', name: 'Banquete de Sangre', kind: _phys, power: 3.2, lifeSteal: 0.8, hpCost: 0.10), _berserker),
  ('sangre', SkillDef(id: 'ult_hemorragia', name: 'Hemorragia', kind: _phys, power: 1.6, allTargets: true, lifeSteal: 0.3, debuffs: [PartyBuff(_atk, -0.15, 2)]), _hacha),
  ('sangre', SkillDef(id: 'ult_pactoCarmesi', name: 'Pacto Carmesí', kind: _phys, power: 4.2, hpCost: 0.25, critBonus: 0.3), _espada),
  ('quiebre', SkillDef(id: 'ult_terremoto', name: 'Terremoto', kind: _phys, power: 1.8, allTargets: true, delay: 0.3, breakBonus: 0.6), _hacha),
  ('quiebre', SkillDef(id: 'ult_quebrantahuesos', name: 'Quebrantahuesos', kind: _phys, power: 3.4, breakBonus: 1.0, status: StatusApplication(_stun, 1)), _martillo),
  ('quiebre', SkillDef(id: 'ult_martilleo', name: 'Martilleo', kind: _phys, power: 0.9, hits: 4, breakBonus: 0.4), _lanza),
  ('gritos', SkillDef(id: 'ult_gritoTotal', name: 'Grito de Guerra Total', kind: _sup, partyBuffs: [PartyBuff(_atk, 0.30, 3)], advanceAllies: 0.20), _senor),
  ('gritos', SkillDef(id: 'ult_rugido', name: 'Rugido Atronador', kind: _phys, power: 1.2, allTargets: true, status: StatusApplication(_stun, 1, chance: 0.4), debuffs: [PartyBuff(_atk, -0.20, 2)]), _hacha),
  ('gritos', SkillDef(id: 'ult_himnoBatalla', name: 'Himno de Batalla', kind: _sup, partyBuffs: [PartyBuff(_crit, 0.20, 3), PartyBuff(_spd, 0.20, 3)]), _senor),
  ('filo', SkillDef(id: 'ult_milFilos', name: 'Mil Filos', kind: _phys, power: 0.8, hits: 5, critBonus: 0.3), _dagas),
  ('filo', SkillDef(id: 'ult_cortePerfecto', name: 'Corte Perfecto', kind: _phys, power: 3.5, critBonus: 0.8), _espada),
  ('filo', SkillDef(id: 'ult_desarmeTotal', name: 'Desarme Total', kind: _phys, power: 2.2, critBonus: 0.3, debuffs: [PartyBuff(_atk, -0.30, 3)]), _espada),
  // ================= Maga (v4) =================
  ('arcano', SkillDef(id: 'ult_novaArcana', name: 'Nova Arcana', kind: _mag, power: 2.0, allTargets: true, critBonus: 0.2), _varita),
  ('arcano', SkillDef(id: 'ult_sobrecargaMana', name: 'Sobrecarga de Maná', kind: _mag, power: 4.0, hpCost: 0.10), _varita),
  ('arcano', SkillDef(id: 'ult_silencioArcano', name: 'Silencio Arcano', kind: _mag, power: 1.4, allTargets: true, ultDrain: 30), _tomo),
  ('brasa', SkillDef(id: 'ult_infierno', name: 'Infierno', kind: _mag, power: 1.8, allTargets: true, status: StatusApplication(_burn, 3)), _baculo),
  ('brasa', SkillDef(id: 'ult_supernova', name: 'Supernova', kind: _mag, power: 3.0, detonate: 0.15, status: StatusApplication(_burn, 2)), _baculo),
  ('brasa', SkillDef(id: 'ult_lluviaCeniza', name: 'Lluvia de Ceniza', kind: _mag, power: 1.2, allTargets: true, status: StatusApplication(_burn, 2), debuffs: [PartyBuff(_atk, -0.15, 2)]), _baculo),
  ('cronos', SkillDef(id: 'ult_paradojaTemporal', name: 'Paradoja Temporal', kind: _mag, power: 1.2, allTargets: true, delay: 1.0), _crono),
  ('cronos', SkillDef(id: 'ult_bucle', name: 'Bucle', kind: _sup, advanceAllies: 0.60, selfTurn: 0.5), _crono),
  ('cronos', SkillDef(id: 'ult_eraDetenida', name: 'Era Detenida', kind: _mag, power: 3.0, delay: 1.5), _tomo),
  ('escarcha', SkillDef(id: 'ult_ceroAbsoluto', name: 'Cero Absoluto', kind: _mag, power: 1.6, allTargets: true, status: StatusApplication(_frz, 3)), _tomo),
  ('escarcha', SkillDef(id: 'ult_ataudHielo', name: 'Ataúd de Hielo', kind: _mag, power: 3.2, delay: 0.5, status: StatusApplication(_frz, 4)), _tomo),
  ('escarcha', SkillDef(id: 'ult_ventiscaPerpetua', name: 'Ventisca Perpetua', kind: _mag, power: 1.3, allTargets: true, status: StatusApplication(_frz, 2), debuffs: [PartyBuff(_spd, -0.20, 2)]), _tomo),
  ('prisma', SkillDef(id: 'ult_arcoiris', name: 'Arcoíris', kind: _mag, power: 1.5, allTargets: true, catalyst: 0.25, status: StatusApplication(_burn, 1), extraStatuses: [StatusApplication(_frz, 1), StatusApplication(_poi, 1)]), _elem),
  ('prisma', SkillDef(id: 'ult_prismaRoto', name: 'Prisma Roto', kind: _mag, power: 2.8, catalyst: 0.5), _elem),
  ('prisma', SkillDef(id: 'ult_descomposicion', name: 'Descomposición Total', kind: _mag, power: 1.4, allTargets: true, detonate: 0.20), _elem),
  // ================= Tirador (v4) =================
  ('viento', SkillDef(id: 'ult_vendaval', name: 'Vendaval', kind: _phys, power: 1.6, allTargets: true, delay: 0.4), _arco),
  ('viento', SkillDef(id: 'ult_ciclon', name: 'Ciclón', kind: _phys, power: 1.4, bounces: 4), _lanza),
  ('viento', SkillDef(id: 'ult_vientoCola', name: 'Viento de Cola', kind: _sup, partyBuffs: [PartyBuff(_spd, 0.30, 3)], advanceAllies: 0.30), _senor),
  ('lluvia', SkillDef(id: 'ult_diluvioFlechas', name: 'Diluvio de Flechas', kind: _phys, power: 1.9, allTargets: true, critBonus: 0.1), _arco),
  ('lluvia', SkillDef(id: 'ult_lluviaAcida', name: 'Lluvia Ácida', kind: _phys, power: 1.4, allTargets: true, status: StatusApplication(_poi, 3)), _arco),
  ('lluvia', SkillDef(id: 'ult_granizada', name: 'Granizada', kind: _phys, power: 1.4, allTargets: true, delay: 0.3, status: StatusApplication(_frz, 1)), _arco),
  ('precision', SkillDef(id: 'ult_tiroImposible', name: 'Tiro Imposible', kind: _phys, power: 4.6, critBonus: 1.0), _franco),
  ('precision', SkillDef(id: 'ult_ojoHalcon', name: 'Ojo de Halcón', kind: _sup, selfBuff: PartyBuff(_crit, 0.50, 2), selfTurn: 0.4), _rifle),
  ('precision', SkillDef(id: 'ult_disparoMarcador', name: 'Disparo Marcador', kind: _phys, power: 2.6, debuffs: [PartyBuff(_taken, 0.25, 3)]), _rifle),
  ('acecho', SkillDef(id: 'ult_emboscada', name: 'Emboscada', kind: _phys, power: 3.0, critBonus: 0.3, execute: 0.25), _franco),
  ('acecho', SkillDef(id: 'ult_redTrampas', name: 'Red de Trampas', kind: _phys, power: 1.0, allTargets: true, trap: 0.7), _trampero),
  ('acecho', SkillDef(id: 'ult_presaMarcada', name: 'Presa Marcada', kind: _phys, power: 2.2, trap: 1.0, debuffs: [PartyBuff(_taken, 0.30, 3)]), _ballesta),
  ('toxina', SkillDef(id: 'ult_plaga', name: 'Plaga', kind: _phys, power: 1.4, allTargets: true, status: StatusApplication(_poi, 4)), _arco),
  ('toxina', SkillDef(id: 'ult_venenoLetal', name: 'Veneno Letal', kind: _phys, power: 2.6, status: StatusApplication(_poi, 6)), _ballesta),
  ('toxina', SkillDef(id: 'ult_nieblaToxica', name: 'Niebla Tóxica', kind: _phys, power: 0.8, allTargets: true, status: StatusApplication(_poi, 2), debuffs: [PartyBuff(_atk, -0.20, 2)]), _arco),
  // ================= Paladín (v4) =================
  ('luz', SkillDef(id: 'ult_amanecer', name: 'Amanecer', kind: _mag, power: 1.6, allTargets: true, status: StatusApplication(_holy, 3)), _templario),
  ('luz', SkillDef(id: 'ult_rayoSolar', name: 'Rayo Solar', kind: _mag, power: 3.4, drainHeal: 0.4, status: StatusApplication(_holy, 3)), _maza),
  ('luz', SkillDef(id: 'ult_luzSanadora', name: 'Luz Sanadora', kind: _heal, power: 1.6, cleanse: 5), _guardian),
  ('juicio', SkillDef(id: 'ult_sentenciaDivina', name: 'Sentencia Divina', kind: _mag, power: 3.8, status: StatusApplication(_stun, 1)), _martillo),
  ('juicio', SkillDef(id: 'ult_veredicto', name: 'Veredicto', kind: _mag, power: 1.6, allTargets: true, status: StatusApplication(_stun, 1), debuffs: [PartyBuff(_taken, 0.20, 2)]), _maza),
  ('juicio', SkillDef(id: 'ult_martilloJusticia', name: 'Martillo de Justicia', kind: _phys, power: 4.2, breakBonus: 0.5, status: StatusApplication(_holy, 2)), _martillo),
  ('fe', SkillDef(id: 'ult_milagro', name: 'Milagro', kind: _heal, power: 1.5, revive: 0.5), _guardian),
  ('fe', SkillDef(id: 'ult_graciaEterna', name: 'Gracia Eterna', kind: _regen, power: 2.0), _guardian),
  ('fe', SkillDef(id: 'ult_olaFe', name: 'Ola de Fe', kind: _heal, power: 2.2, overheal: 0.8), _guardian),
  ('vigilia', SkillDef(id: 'ult_vigiliaEterna', name: 'Vigilia Eterna', kind: _sup, partyBuffs: [PartyBuff(_guard, 0.35, 3)]), _guardian),
  ('vigilia', SkillDef(id: 'ult_juramento', name: 'Juramento', kind: _taunt, amount: 2, selfShield: 0.50, shieldTurns: 3), _bulwark),
  ('vigilia', SkillDef(id: 'ult_penitencia', name: 'Penitencia Sagrada', kind: _mag, power: 1.4, allTargets: true, status: StatusApplication(_holy, 2), selfBuff: PartyBuff(_guard, 0.30, 2)), _templario),
  ('bastion', SkillDef(id: 'ult_bastionAbsoluto', name: 'Bastión Absoluto', kind: _sup, partyShield: 0.25, partyShieldTurns: 3, shieldGrow: 0.5), _guardian),
  ('bastion', SkillDef(id: 'ult_egidaReflejante', name: 'Égida Reflejante', kind: _sup, partyShield: 0.18, partyShieldTurns: 2, shieldReflect: 0.6), _guardian),
  ('bastion', SkillDef(id: 'ult_escudoExplosivo', name: 'Escudo Explosivo', kind: _sup, partyShield: 0.15, partyShieldTurns: 2, shieldBurst: 1.5), _bulwark),
  // ================= Puentes v3 =================
  ('hojaArcana', SkillDef(id: 'ult_hojaRunica', name: 'Hoja Rúnica', kind: _phys, power: 3.0, critBonus: 0.2, status: StatusApplication(_wet, 1)), _espada),
  ('hojaArcana', SkillDef(id: 'ult_aceroArcano', name: 'Acero Arcano', kind: _mag, power: 1.7, allTargets: true, breakBonus: 0.3), _varita),
  ('hojaArcana', SkillDef(id: 'ult_egidaRunica', name: 'Égida Rúnica Mayor', kind: _sup, selfShield: 0.30, shieldTurns: 3, partyBuffs: [PartyBuff(_dmg, 0.15, 2)]), _guardian),
  ('runas', SkillDef(id: 'ult_runaExplosiva', name: 'Runa Explosiva', kind: _mag, power: 3.2, critBonus: 0.4), _varita),
  ('runas', SkillDef(id: 'ult_circuloRunico', name: 'Círculo Rúnico', kind: _mag, power: 1.3, allTargets: true, trap: 0.5), _trampero),
  ('runas', SkillDef(id: 'ult_disparoRunico', name: 'Disparo Rúnico', kind: _phys, power: 2.4, pierce: 0.8, status: StatusApplication(_chg, 1)), _rifle),
  ('centinela', SkillDef(id: 'ult_faro', name: 'Faro', kind: _mag, power: 1.3, allTargets: true, status: StatusApplication(_holy, 2), debuffs: [PartyBuff(_taken, 0.15, 2)]), _templario),
  ('centinela', SkillDef(id: 'ult_guardiaCentinela', name: 'Guardia del Centinela', kind: _sup, partyShield: 0.15, partyShieldTurns: 3, partyBuffs: [PartyBuff(_crit, 0.15, 3)]), _guardian),
  ('centinela', SkillDef(id: 'ult_flechaLuz', name: 'Flecha de Luz', kind: _phys, power: 3.4, pierce: 0.5, status: StatusApplication(_holy, 3)), _ballesta),
  ('coloso', SkillDef(id: 'ult_pisoton', name: 'Pisotón del Coloso', kind: _phys, power: 1.8, allTargets: true, status: StatusApplication(_stun, 1, chance: 0.5)), _hacha),
  ('coloso', SkillDef(id: 'ult_colosoInamovible', name: 'Coloso Inamovible', kind: _taunt, amount: 3, selfShield: 0.60, shieldTurns: 3), _bulwark),
  ('coloso', SkillDef(id: 'ult_punoTitan', name: 'Puño de Titán', kind: _phys, power: 4.4, breakBonus: 0.8, delay: 0.4), _martillo),
  // ================= Grupos v4 =================
  ('estandarte', SkillDef(id: 'ult_estandarteGuerra', name: 'Estandarte de Guerra', kind: _sup, partyBuffs: [PartyBuff(_dmg, 0.25, 3)]), _senor),
  ('estandarte', SkillDef(id: 'ult_cargaEstandarte', name: 'Carga del Estandarte', kind: _phys, power: 1.6, allTargets: true, advanceAllies: 0.30), _lanza),
  ('estandarte', SkillDef(id: 'ult_banderaInmortal', name: 'Bandera Inmortal', kind: _sup, partyBuffs: [PartyBuff(_atk, 0.20, 3), PartyBuff(_guard, 0.15, 3)]), _senor),
  ('sintonia', SkillDef(id: 'ult_armonia', name: 'Armonía', kind: _sup, advanceAllies: 0.50, partyBuffs: [PartyBuff(_spd, 0.15, 2)]), _crono),
  ('sintonia', SkillDef(id: 'ult_resonancia', name: 'Resonancia', kind: _mag, power: 1.5, allTargets: true, breakBonus: 0.4), _varita),
  ('sintonia', SkillDef(id: 'ult_acordeFinal', name: 'Acorde Final', kind: _mag, power: 2.8, ultDrain: 50), _varita),
  ('vinculo', SkillDef(id: 'ult_lazoVital', name: 'Lazo Vital', kind: _heal, power: 1.8, cleanse: 3), _guardian),
  ('vinculo', SkillDef(id: 'ult_corazonesUnidos', name: 'Corazones Unidos', kind: _sup, partyShield: 0.20, partyShieldTurns: 2, partyBuffs: [PartyBuff(_ls, 0.15, 3)]), _guardian),
  ('vinculo', SkillDef(id: 'ult_sacrificioCompartido', name: 'Sacrificio Compartido', kind: _heal, power: 2.5, hpCost: 0.20, revive: 0.4), _guardian),
  ('refugio', SkillDef(id: 'ult_refugioSeguro', name: 'Refugio Seguro', kind: _sup, partyBuffs: [PartyBuff(_guard, 0.40, 2)]), _guardian),
  ('refugio', SkillDef(id: 'ult_cupulaMayor', name: 'Cúpula Mayor', kind: _sup, partyShield: 0.22, partyShieldTurns: 3), _guardian),
  ('refugio', SkillDef(id: 'ult_retiradaTactica', name: 'Retirada Táctica', kind: _sup, partyShield: 0.12, partyShieldTurns: 2, advanceAllies: 0.40), _crono),
  // ================= Clusters exteriores v6 =================
  ('verdugo', SkillDef(id: 'ult_guillotina', name: 'Guillotina', kind: _phys, power: 3.2, execute: 0.30), _espada),
  ('verdugo', SkillDef(id: 'ult_cosechaAlmas', name: 'Cosecha de Almas', kind: _phys, power: 1.7, allTargets: true, execute: 0.15, selfTurn: 0.5), _hacha),
  ('verdugo', SkillDef(id: 'ult_juicioPublico', name: 'Juicio Público', kind: _phys, power: 2.5, partyBuffs: [PartyBuff(_dmg, 0.15, 2)]), _senor),
  ('tempestad', SkillDef(id: 'ult_martilloTormenta', name: 'Martillo de Tormenta', kind: _phys, power: 3.2, breakBonus: 0.5, status: StatusApplication(_chg, 1)), _martillo),
  ('tempestad', SkillDef(id: 'ult_galerna', name: 'Galerna', kind: _phys, power: 1.6, allTargets: true, delay: 0.3, status: StatusApplication(_wet, 1)), _hacha),
  ('tempestad', SkillDef(id: 'ult_ojoTormenta', name: 'Ojo de la Tormenta', kind: _phys, power: 2.0, status: StatusApplication(_wet, 1), extraStatuses: [StatusApplication(_chg, 1), StatusApplication(_stun, 1, chance: 0.5)]), _lanza),
  ('vanguardia', SkillDef(id: 'ult_avanzada', name: 'Avanzada', kind: _sup, advanceAllies: 0.50, partyShield: 0.10, partyShieldTurns: 2), _senor),
  ('vanguardia', SkillDef(id: 'ult_toqueCarga', name: 'Toque de Carga', kind: _phys, power: 1.5, allTargets: true, partyBuffs: [PartyBuff(_spd, 0.20, 2)]), _lanza),
  ('vanguardia', SkillDef(id: 'ult_escoltaReal', name: 'Escolta Real', kind: _sup, protect: true, allyShield: 0.35, shieldTurns: 3), _guardian),
  ('marea', SkillDef(id: 'ult_tsunami', name: 'Tsunami', kind: _mag, power: 1.6, allTargets: true, delay: 0.5, status: StatusApplication(_wet, 1)), _tomo),
  ('marea', SkillDef(id: 'ult_remolinoAbisal', name: 'Remolino Abisal', kind: _mag, power: 3.0, status: StatusApplication(_wet, 1), debuffs: [PartyBuff(_spd, -0.30, 2)]), _tomo),
  ('marea', SkillDef(id: 'ult_mareaAlta', name: 'Marea Alta', kind: _mag, power: 1.2, allTargets: true, detonate: 0.15, status: StatusApplication(_wet, 1)), _varita),
  ('voltio', SkillDef(id: 'ult_tormentaRayos', name: 'Tormenta de Rayos', kind: _mag, power: 1.5, allTargets: true, critBonus: 0.15, status: StatusApplication(_chg, 1)), _varita),
  ('voltio', SkillDef(id: 'ult_rayoCadena', name: 'Rayo en Cadena', kind: _mag, power: 2.0, bounces: 4, status: StatusApplication(_chg, 1)), _varita),
  ('voltio', SkillDef(id: 'ult_descargaSuprema', name: 'Descarga Suprema', kind: _mag, power: 3.6, status: StatusApplication(_chg, 1), extraStatuses: [StatusApplication(_stun, 1, chance: 0.4)]), _varita),
  ('alquimia', SkillDef(id: 'ult_granTransmutacion', name: 'Gran Transmutación', kind: _mag, power: 1.4, allTargets: true, catalyst: 0.4), _elem),
  ('alquimia', SkillDef(id: 'ult_piedraFilosofal', name: 'Piedra Filosofal', kind: _mag, power: 2.6, detonate: 0.25), _elem),
  ('alquimia', SkillDef(id: 'ult_elixirVolatil', name: 'Elixir Volátil', kind: _mag, power: 1.2, allTargets: true, status: StatusApplication(_poi, 2), extraStatuses: [StatusApplication(_burn, 1)]), _baculo),
  ('monzon', SkillDef(id: 'ult_monzon', name: 'Monzón', kind: _phys, power: 1.6, allTargets: true, advanceAllies: 0.20, status: StatusApplication(_wet, 1)), _arco),
  ('monzon', SkillDef(id: 'ult_aguacero', name: 'Aguacero', kind: _phys, power: 1.2, allTargets: true, status: StatusApplication(_wet, 1), extraStatuses: [StatusApplication(_frz, 1)]), _arco),
  ('monzon', SkillDef(id: 'ult_trombaMarina', name: 'Tromba Marina', kind: _phys, power: 1.8, allTargets: true, delay: 0.3, status: StatusApplication(_wet, 1)), _ballesta),
  ('centella', SkillDef(id: 'ult_disparoRelampago', name: 'Disparo Relámpago', kind: _phys, power: 4.0, critBonus: 0.5, status: StatusApplication(_chg, 1)), _rifle),
  ('centella', SkillDef(id: 'ult_cadenaVoltaica', name: 'Cadena Voltaica', kind: _phys, power: 1.6, bounces: 4, status: StatusApplication(_chg, 1)), _arco),
  ('centella', SkillDef(id: 'ult_tensionMaxima', name: 'Tensión Máxima', kind: _phys, charge: 5.0, selfTurn: 0.7, status: StatusApplication(_chg, 1)), _ballesta),
  ('monteria', SkillDef(id: 'ult_granCaceria', name: 'Gran Cacería', kind: _phys, power: 1.0, allTargets: true, trap: 1.0), _trampero),
  ('monteria', SkillDef(id: 'ult_cepoMayor', name: 'Cepo Mayor', kind: _phys, power: 2.4, trap: 0.8, status: StatusApplication(_stun, 1)), _ballesta),
  ('monteria', SkillDef(id: 'ult_trofeoCaza', name: 'Trofeo de Caza', kind: _phys, power: 3.2, execute: 0.20, drainHeal: 0.3), _franco),
  ('exorcismo', SkillDef(id: 'ult_purificacion', name: 'Purificación', kind: _mag, power: 2.0, allTargets: true, status: StatusApplication(_holy, 4)), _templario),
  ('exorcismo', SkillDef(id: 'ult_exorcismo', name: 'Exorcismo', kind: _mag, power: 3.8, status: StatusApplication(_holy, 4)), _maza),
  ('exorcismo', SkillDef(id: 'ult_destierro', name: 'Destierro', kind: _mag, power: 1.5, allTargets: true, delay: 0.6, status: StatusApplication(_holy, 2)), _templario),
  ('manantial', SkillDef(id: 'ult_fuenteEterna', name: 'Fuente Eterna', kind: _regen, power: 2.2), _guardian),
  ('manantial', SkillDef(id: 'ult_bautismo', name: 'Bautismo', kind: _heal, power: 1.4, revive: 0.6), _guardian),
  ('manantial', SkillDef(id: 'ult_desbordeSagrado', name: 'Desborde Sagrado', kind: _heal, power: 2.0, overheal: 1.0), _guardian),
  ('pararrayos', SkillDef(id: 'ult_pararrayosViviente', name: 'Pararrayos Viviente', kind: _taunt, amount: 2, selfShield: 0.35, shieldTurns: 3, shieldReflect: 0.6), _bulwark),
  ('pararrayos', SkillDef(id: 'ult_jaulaFaraday', name: 'Jaula de Faraday', kind: _sup, partyShield: 0.18, partyShieldTurns: 2, shieldBurst: 1.2), _guardian),
  ('pararrayos', SkillDef(id: 'ult_retornoTierra', name: 'Retorno a Tierra', kind: _mag, power: 1.4, allTargets: true, status: StatusApplication(_chg, 1), debuffs: [PartyBuff(_atk, -0.20, 2)]), _maza),
  // ================= Puentes elementales v6 =================
  ('forja', SkillDef(id: 'ult_forjaDivina', name: 'Forja Divina', kind: _phys, power: 3.0, breakBonus: 0.7, status: StatusApplication(_burn, 3)), _hacha),
  ('forja', SkillDef(id: 'ult_aceroFundido', name: 'Acero Fundido', kind: _phys, power: 1.6, allTargets: true, status: StatusApplication(_burn, 2)), _baculo),
  ('forja', SkillDef(id: 'ult_yunque', name: 'Yunque', kind: _phys, power: 3.6, breakBonus: 1.2, delay: 0.3), _martillo),
  ('galvanica', SkillDef(id: 'ult_electrolisis', name: 'Electrólisis', kind: _mag, power: 1.4, allTargets: true, status: StatusApplication(_wet, 1), extraStatuses: [StatusApplication(_chg, 1)]), _elem),
  ('galvanica', SkillDef(id: 'ult_circuitoCerrado', name: 'Circuito Cerrado', kind: _mag, power: 2.4, bounces: 3, status: StatusApplication(_wet, 1)), _varita),
  ('galvanica', SkillDef(id: 'ult_arcoPlasma', name: 'Arco de Plasma', kind: _mag, power: 3.4, catalyst: 0.3, status: StatusApplication(_chg, 1)), _varita),
  ('eclipse', SkillDef(id: 'ult_eclipseTotal', name: 'Eclipse Total', kind: _phys, power: 1.5, allTargets: true, status: StatusApplication(_poi, 2), extraStatuses: [StatusApplication(_holy, 2)]), _arco),
  ('eclipse', SkillDef(id: 'ult_sombraSagrada', name: 'Sombra Sagrada', kind: _phys, power: 2.8, critBonus: 0.2, status: StatusApplication(_poi, 3), extraStatuses: [StatusApplication(_holy, 2)]), _dagas),
  ('eclipse', SkillDef(id: 'ult_crepusculo', name: 'Crepúsculo', kind: _mag, power: 1.3, allTargets: true, drainHeal: 0.4, status: StatusApplication(_poi, 3)), _templario),
  ('glaciar', SkillDef(id: 'ult_avalancha', name: 'Avalancha', kind: _phys, power: 1.7, allTargets: true, status: StatusApplication(_frz, 2)), _hacha),
  ('glaciar', SkillDef(id: 'ult_escudoGlaciar', name: 'Escudo Glaciar', kind: _sup, partyShield: 0.18, partyShieldTurns: 3, partyBuffs: [PartyBuff(_guard, 0.10, 3)]), _guardian),
  ('glaciar', SkillDef(id: 'ult_tempano', name: 'Témpano', kind: _phys, power: 3.6, delay: 0.4, status: StatusApplication(_frz, 3)), _martillo),
  // ================= Grupos exteriores v6 =================
  ('tactica', SkillDef(id: 'ult_planMaestro', name: 'Plan Maestro', kind: _sup, partyBuffs: [PartyBuff(_dmg, 0.20, 2)], advanceAllies: 0.30), _senor),
  ('tactica', SkillDef(id: 'ult_fuegoCruzado', name: 'Fuego Cruzado', kind: _phys, power: 1.6, allTargets: true, debuffs: [PartyBuff(_taken, 0.20, 3)]), _arco),
  ('tactica', SkillDef(id: 'ult_golpeCoordinado', name: 'Golpe Coordinado', kind: _phys, power: 3.0, breakBonus: 0.5, debuffs: [PartyBuff(_taken, 0.15, 2)]), _lanza),
  ('coro', SkillDef(id: 'ult_granHimno', name: 'Gran Himno', kind: _sup, partyBuffs: [PartyBuff(_spd, 0.20, 3), PartyBuff(_crit, 0.15, 3)]), _senor),
  ('coro', SkillDef(id: 'ult_canonEterno', name: 'Canon Eterno', kind: _sup, partyBuffs: [PartyBuff(_dmg, 0.15, 4)]), _crono),
  ('coro', SkillDef(id: 'ult_crescendo', name: 'Crescendo', kind: _mag, power: 1.4, allTargets: true, advanceAllies: 0.40), _varita),
  ('santuario', SkillDef(id: 'ult_santuario', name: 'Santuario', kind: _heal, power: 1.6, cleanse: 5), _guardian),
  ('santuario', SkillDef(id: 'ult_altarSagrado', name: 'Altar Sagrado', kind: _mag, power: 1.4, allTargets: true, drainHeal: 0.5, status: StatusApplication(_holy, 3)), _templario),
  ('santuario', SkillDef(id: 'ult_ultimoRezo', name: 'Último Rezo', kind: _heal, power: 1.2, revive: 0.5, cleanse: 3), _guardian),
  ('fortaleza', SkillDef(id: 'ult_murallaEterna', name: 'Muralla Eterna', kind: _sup, partyShield: 0.30, partyShieldTurns: 3), _guardian),
  ('fortaleza', SkillDef(id: 'ult_torreHomenaje', name: 'Torre del Homenaje', kind: _taunt, amount: 2, selfShield: 0.30, shieldTurns: 3, shieldGrow: 0.5), _bulwark),
  ('fortaleza', SkillDef(id: 'ult_ciudadela', name: 'Ciudadela', kind: _sup, partyShield: 0.10, partyShieldTurns: 3, partyBuffs: [PartyBuff(_guard, 0.25, 3)]), _guardian),
];

/// Tipos de arma en los que puede salir el mod "ULT: <nombre>" de cada
/// camino (todas las ULT del camino comparten la lista).
const Map<String, List<String>> kBranchUltPathTypes = {
  // Guerrero
  'muralla': ['espada', 'hacha', 'lanza'],
  'sangre': ['espada', 'hacha', 'dagas'],
  'quiebre': ['hacha', 'lanza', 'martillo+escudo'],
  'gritos': ['espada', 'hacha', 'lanza'],
  'filo': ['espada', 'dagas', 'lanza'],
  'verdugo': ['espada', 'hacha', 'dagas'],
  'tempestad': ['hacha', 'lanza', 'espada'],
  'vanguardia': ['espada', 'lanza', 'espada+escudo'],
  // Maga
  'arcano': ['varita', 'tomo', 'báculo'],
  'brasa': ['báculo', 'varita'],
  'cronos': ['tomo', 'varita'],
  'escarcha': ['báculo', 'tomo'],
  'prisma': ['báculo', 'varita', 'tomo'],
  'marea': ['báculo', 'tomo', 'lanza'],
  'voltio': ['varita', 'báculo', 'tomo'],
  'alquimia': ['tomo', 'báculo', 'varita'],
  // Tirador
  'viento': ['arco', 'dagas', 'lanza'],
  'lluvia': ['arco', 'ballesta'],
  'precision': ['rifle', 'arco', 'ballesta'],
  'acecho': ['arco', 'ballesta', 'dagas'],
  'toxina': ['arco', 'ballesta', 'dagas'],
  'monzon': ['arco', 'ballesta', 'rifle'],
  'centella': ['rifle', 'arco', 'ballesta'],
  'monteria': ['arco', 'ballesta'],
  // Paladín
  'luz': ['maza+escudo', 'espada+escudo', 'báculo'],
  'juicio': ['martillo+escudo', 'maza+escudo'],
  'fe': ['maza+escudo', 'báculo', 'espada+escudo'],
  'vigilia': ['espada+escudo', 'maza+escudo', 'martillo+escudo'],
  'bastion': ['espada+escudo', 'martillo+escudo', 'maza+escudo'],
  'exorcismo': ['maza+escudo', 'martillo+escudo', 'espada+escudo'],
  'manantial': ['maza+escudo', 'espada+escudo', 'báculo'],
  'pararrayos': ['espada+escudo', 'martillo+escudo', 'maza+escudo'],
  // Puentes
  'hojaArcana': ['espada', 'varita', 'báculo'],
  'runas': ['varita', 'tomo', 'rifle'],
  'centinela': ['ballesta', 'arco', 'maza+escudo'],
  'coloso': ['martillo+escudo', 'hacha', 'espada+escudo'],
  'forja': ['hacha', 'espada', 'báculo'],
  'galvanica': ['varita', 'rifle', 'tomo'],
  'eclipse': ['arco', 'dagas', 'maza+escudo'],
  'glaciar': ['martillo+escudo', 'hacha', 'espada+escudo'],
  // Grupos
  'estandarte': ['espada', 'lanza', 'maza+escudo'],
  'sintonia': ['varita', 'tomo', 'rifle'],
  'vinculo': ['báculo', 'maza+escudo', 'arco'],
  'refugio': ['espada+escudo', 'martillo+escudo', 'tomo'],
  'tactica': ['rifle', 'lanza', 'varita'],
  'coro': ['varita', 'tomo', 'lanza'],
  'santuario': ['maza+escudo', 'báculo', 'tomo'],
  'fortaleza': ['espada+escudo', 'martillo+escudo', 'maza+escudo'],
};

/// Las ULT de camino por id.
final Map<String, SkillDef> kBranchUltSkills = {
  for (final (_, s, _) in kBranchUltList) s.id: s,
};

/// Camino → sus 3 ULT (ids).
final Map<String, List<String>> kBranchUlts = () {
  final out = <String, List<String>>{};
  for (final (p, s, _) in kBranchUltList) {
    (out[p] ??= []).add(s.id);
  }
  return out;
}();

/// ULT → camino.
final Map<String, String> kBranchUltPath = {
  for (final (p, s, _) in kBranchUltList) s.id: p,
};

/// ULT → la ULT existente a la que se parece (guion, FX y sonido).
final Map<String, String> kBranchUltLooks = {
  for (final (_, s, l) in kBranchUltList) s.id: l,
};

/// ULT → tipos de arma compatibles.
final Map<String, List<String>> kBranchUltWeaponTypes = {
  for (final (p, s, _) in kBranchUltList) s.id: kBranchUltPathTypes[p]!,
};

/// Elemento de cada ULT de camino (para `kSkillElement`): el del estado
/// que aplica; Sagrado las curas; Físico el resto.
final Map<String, GameElement> kBranchUltElement = {
  for (final (_, s, _) in kBranchUltList) s.id: _elementOf(s),
};

GameElement _elementOf(SkillDef s) {
  if (s.kind == _heal || s.kind == _regen) return GameElement.sagrado;
  return switch (s.status?.kind) {
    _burn => GameElement.fuego,
    _frz => GameElement.hielo,
    _poi => GameElement.veneno,
    _holy => GameElement.sagrado,
    _wet => GameElement.agua,
    _chg => GameElement.electro,
    _ => GameElement.fisico,
  };
}

/// ULT de camino que pueden salir en un arma de tipo [type].
List<String> branchUltsForType(String type) => [
      for (final e in kBranchUltWeaponTypes.entries)
        if (e.value.contains(type)) e.key,
    ];

/// Probabilidad de que un arma Rara / Épica salga con "ULT: <nombre>"
/// (los Legendarios con ULT la traen fija: `UniqueDef.ultId`).
const kBranchUltChanceRare = 0.08;
const kBranchUltChanceEpic = 0.20;

/// Todas las ULT que puede traer un arma concreta (mod, legendario o
/// base): las de camino y las 3 del Invocador.
final Map<String, SkillDef> kWeaponUltSkills = {
  ...kBranchUltSkills,
  ...kSummonerUltimates,
};

/// La ULT propia de un arma concreta, o `null` (usa la del tipo): el mod
/// "ULT: <nombre>" de la instancia, la fija de su legendario o la de su
/// base (tomos del Invocador, `kWeaponUltOf`). [baseId] es la base
/// equipada; la instancia solo cuenta si es de esa base.
SkillDef? ownWeaponUlt(String? baseId, ItemInstance? item) {
  final it = item != null && item.baseId == baseId ? item : null;
  final id = it?.ultId ??
      (it?.uniqueId == null ? null : kUniques[it!.uniqueId]?.ultId) ??
      kWeaponUltOf[baseId];
  return kWeaponUltSkills[id];
}

/// La ULT de la instancia [item] por sí misma (mod o legendario), para
/// tooltips; `null` = la del tipo.
SkillDef? itemUlt(ItemInstance item) => ownWeaponUlt(item.baseId, item);
