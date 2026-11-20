import '../models/elements.dart';
import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart';
import '../models/status.dart';
import '../models/ult_def.dart';

// ULT v2 (docs/specs/ultimates_v2.md § 3): 50 ULT de jugador repartidas
// en armas, legendarios, árbol, hazañas, Ecos/Atlas/Maestría y jefes.
// Este catálogo es el RESPALDO del código: los datos viven en
// `assets/data/ults/<id>.ult.yaml` (mismo contenido; test de ida y
// vuelta en test/game_engine/ult_data_test.dart). La animación de cada
// una es `assets/fx/ult/<id>.fx.yaml`.

const _phys = SkillKind.physical;
const _mag = SkillKind.magical;
const _sup = SkillKind.support;
const _heal = SkillKind.heal;

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

const _fis = GameElement.fisico;
const _fue = GameElement.fuego;
const _hie = GameElement.hielo;
const _ven = GameElement.veneno;
const _sag = GameElement.sagrado;
const _agu = GameElement.agua;
const _ele = GameElement.electro;

const _wm = UltSource.weaponMod;
const _un = UltSource.unique;
const _tree = UltSource.tree;
const _feat = UltSource.feat;
const _eco = UltSource.eco;
const _boss = UltSource.boss;

/// Armas cuerpo a cuerpo / mágicas / con escudo (compatibilidad).
const kMeleeWeaponTypes = [
  'espada',
  'hacha',
  'lanza',
  'dagas',
  'espada+escudo',
  'maza+escudo',
  'martillo+escudo',
];
const kCasterWeaponTypes = ['báculo', 'tomo', 'varita'];
const kShieldWeaponTypes = ['espada+escudo', 'maza+escudo', 'martillo+escudo'];

/// Las 50, en el orden del spec.
const List<UltDef> kUltV2List = [
  // ================= 3.1 Armas Raras / Épicas (mod) =================
  UltDef(source: _wm, ref: '', element: _fis, weapons: ['espada'], skill: SkillDef(id: 'ult2_ecoFilo', name: 'Eco del Filo', kind: _phys, power: 1.52, hits: 3, breakBonus: 0.5)),
  UltDef(source: _wm, ref: '', element: _fis, weapons: ['hacha'], skill: SkillDef(id: 'ult2_taladoEras', name: 'Talado de Eras', kind: _phys, power: 2.03, allTargets: true, breakBonus: 0.6, delay: 0.2)),
  UltDef(source: _wm, ref: '', element: _fis, weapons: ['lanza'], skill: SkillDef(id: 'ult2_lanzaInmovil', name: 'Lanza Inmóvil', kind: _phys, power: 2.1, pierce: 0.5, delay: 0.6)),
  UltDef(source: _wm, ref: '', element: _fis, weapons: ['arco'], skill: SkillDef(id: 'ult2_flechaVuelve', name: 'Flecha que Vuelve', kind: _phys, power: 1.5, bounces: 2, ultCost: 80)),
  UltDef(source: _wm, ref: '', element: _fis, weapons: ['rifle'], skill: SkillDef(id: 'ult2_disparoAnterior', name: 'Disparo Anterior', kind: _phys, charge: 3.6, critBonus: 0.3, ultCost: 80)),
  UltDef(source: _wm, ref: '', element: _fis, weapons: ['ballesta'], skill: SkillDef(id: 'ult2_viroteDetenido', name: 'Virote Detenido', kind: _phys, power: 3.13, status: StatusApplication(_stun, 1), debuffs: [PartyBuff(_taken, 0.20, 2)])),
  UltDef(source: _wm, ref: '', element: _ven, weapons: ['dagas'], skill: SkillDef(id: 'ult2_milAyeres', name: 'Mil Ayeres', kind: _phys, power: 0.64, hits: 6, critBonus: 0.25, status: StatusApplication(_poi, 2))),
  UltDef(source: _wm, ref: '', element: _fue, weapons: ['báculo'], skill: SkillDef(id: 'ult2_brasaAntigua', name: 'Brasa Antigua', kind: _mag, power: 1.0, allTargets: true, status: StatusApplication(_burn, 2), catalyst: 0.2)),
  UltDef(source: _wm, ref: '', element: _hie, weapons: ['tomo'], skill: SkillDef(id: 'ult2_paginaRecuerda', name: 'Página que Recuerda', kind: _mag, power: 1.9, allTargets: true, status: StatusApplication(_wet, 1), extraStatuses: [StatusApplication(_frz, 1)])),
  UltDef(source: _wm, ref: '', element: _ele, weapons: ['varita'], skill: SkillDef(id: 'ult2_chispaRelojera', name: 'Chispa Relojera', kind: _mag, power: 1.72, allTargets: true, status: StatusApplication(_chg, 1), advanceAllies: 0.2)),
  UltDef(source: _wm, ref: '', element: _fis, weapons: ['espada+escudo'], skill: SkillDef(id: 'ult2_muroAyer', name: 'Muro de Ayer', kind: _sup, partyShield: 0.22, partyShieldTurns: 3, shieldReflect: 0.3)),
  UltDef(source: _wm, ref: '', element: _sag, weapons: ['maza+escudo'], skill: SkillDef(id: 'ult2_campanaPasado', name: 'Campana del Pasado', kind: _mag, power: 1.1, allTargets: true, status: StatusApplication(_holy, 1), partyBuffs: [PartyBuff(_guard, 0.20, 2)])),

  // ================= 3.2 Legendarios / únicos =================
  UltDef(source: _un, ref: 'yunqueEras', element: _fis, weapons: ['martillo+escudo'], skill: SkillDef(id: 'ult2_yunqueTiempo', name: 'Yunque del Tiempo', kind: _phys, power: 4.05, status: StatusApplication(_stun, 1), breakBonus: 1.0)),
  UltDef(source: _un, ref: 'espejoSinFondo', element: _fis, weapons: ['tomo', 'varita'], skill: SkillDef(id: 'ult2_relojPartido', name: 'Reloj Partido', kind: _mag, power: 1.51, allTargets: true, delay: 1.0, advanceAllies: 0.3)),
  UltDef(source: _un, ref: 'primaveraRota', element: _fis, weapons: ['arco', 'ballesta'], skill: SkillDef(id: 'ult2_ultimaCuerda', name: 'Última Cuerda', kind: _phys, power: 1.6, allTargets: true, trap: 0.6)),
  UltDef(source: _un, ref: 'fauceEras', element: _fis, weapons: ['espada', 'dagas'], skill: SkillDef(id: 'ult2_coronaRota', name: 'Hoja de la Corona Rota', kind: _phys, power: 4.21, execute: 0.25, lifeSteal: 0.25)),
  UltDef(source: _un, ref: 'pulsoAutomata', element: _ele, weapons: ['rifle'], skill: SkillDef(id: 'ult2_pulsoMagitec', name: 'Pulso Magitec', kind: _phys, power: 1.74, allTargets: true, status: StatusApplication(_chg, 1), pulseParty: 2)),
  UltDef(source: _un, ref: 'manecillaAbismo', element: _agu, weapons: ['báculo', 'varita'], skill: SkillDef(id: 'ult2_mareaAntigua', name: 'Marea Antigua', kind: _mag, power: 1.3, allTargets: true, status: StatusApplication(_wet, 2), partyBuffs: [PartyBuff(_crit, 0.15, 2)])),
  UltDef(source: _un, ref: 'coronaInvertida', element: _fis, weapons: ['espada+escudo', 'maza+escudo'], skill: SkillDef(id: 'ult2_baluarteAutomata', name: 'Baluarte Autómata', kind: _sup, protect: true, selfShield: 0.50, shieldTurns: 3, shieldBurst: 0.8)),
  UltDef(source: _un, ref: 'filoPrimordial', element: _fis, weapons: ['lanza', 'hacha'], skill: SkillDef(id: 'ult2_dobleHorizonte', name: 'Doble Horizonte', kind: _phys, power: 1.84, allTargets: true, delay: 0.5)),

  // ================= 3.3 Hitos del árbol (aprendidas) =================
  UltDef(source: _tree, ref: 'guerrero:20', element: _fis, classes: ['guerrero'], skill: SkillDef(id: 'ult2_sangreEco', name: 'Sangre de Eco', kind: _phys, power: 2.81, lifeSteal: 0.4, hpCost: 0.10, ultCost: 80)),
  UltDef(source: _tree, ref: 'guerrero:40', element: _fis, classes: ['guerrero'], skill: SkillDef(id: 'ult2_gritoRuinas', name: 'Grito de las Ruinas', kind: _sup, partyBuffs: [PartyBuff(_atk, 0.25, 3)], advanceAllies: 0.25, ultCost: 80)),
  UltDef(source: _tree, ref: 'maga:20', element: _fis, classes: ['maga'], skill: SkillDef(id: 'ult2_bucleBreve', name: 'Bucle Breve', kind: _mag, power: 0.9, allTargets: true, delay: 0.6, instant: true, ultCost: 60)),
  UltDef(source: _tree, ref: 'maga:40', element: _fis, classes: ['maga'], skill: SkillDef(id: 'ult2_prismaPasado', name: 'Prisma del Pasado', kind: _mag, power: 2.03, allTargets: true, detonate: 0.5)),
  UltDef(source: _tree, ref: 'paladin:20', element: _sag, classes: ['paladin'], skill: SkillDef(id: 'ult2_luzAyer', name: 'Luz de Ayer', kind: _heal, power: 1.4, revive: 0.25)),
  UltDef(source: _tree, ref: 'paladin:40', element: _sag, classes: ['paladin'], skill: SkillDef(id: 'ult2_sentenciaLejana', name: 'Sentencia Lejana', kind: _mag, power: 1.9, status: StatusApplication(_holy, 2), breakBonus: 0.5, ultCost: 80)),
  UltDef(source: _tree, ref: 'tirador:20', element: _fis, classes: ['tirador'], skill: SkillDef(id: 'ult2_ojoFuturo', name: 'Ojo del Futuro', kind: _phys, power: 3.8, critBonus: 0.5)),
  UltDef(source: _tree, ref: 'tirador:40', element: _fis, classes: ['tirador'], skill: SkillDef(id: 'ult2_lluviaEcos', name: 'Lluvia de Ecos', kind: _phys, power: 0.51, hits: 8, pierce: 0.3)),

  // ================= 3.4 Hazañas (aprendidas) =================
  UltDef(source: _feat, ref: 'ult_flawless', element: _fis, weapons: kMeleeWeaponTypes, skill: SkillDef(id: 'ult2_primerGolpe', name: 'Primer Golpe', kind: _phys, power: 2.5, openerBonus: 0.5, ultCost: 80)),
  UltDef(source: _feat, ref: 'ult_breaks', element: _fis, skill: SkillDef(id: 'ult2_cadenaEras', name: 'Cadena de Eras', kind: _phys, power: 2.03, allTargets: true, breakBonus: 0.8)),
  UltDef(source: _feat, ref: 'ult_cancels', element: _fis, skill: SkillDef(id: 'ult2_lluviaEsquirlas', name: 'Lluvia de Esquirlas', kind: _phys, power: 1.81, allTargets: true, ultDrain: 30)),
  UltDef(source: _feat, ref: 'ult_shields', element: _fis, weapons: kShieldWeaponTypes, skill: SkillDef(id: 'ult2_custodioInstante', name: 'Custodio del Instante', kind: _heal, power: 0.91, lowestAlly: true, allyShield: 0.50, protect: true, cleanse: 2, ultCost: 80)),
  UltDef(source: _feat, ref: 'ult_forge10', element: _fis, skill: SkillDef(id: 'ult2_forjadoAyer', name: 'Forjado en el Ayer', kind: _sup, selfBuff: PartyBuff(_dmg, 0.50, 3), selfTurn: 0.5, ultCost: 60)),
  UltDef(source: _feat, ref: 'ult_executes', element: _fis, skill: SkillDef(id: 'ult2_remateEco', name: 'Remate del Eco', kind: _phys, power: 3.57, execute: 0.35, ultCost: 80)),

  // ================= 3.5 Ecos / Atlas / Maestría (aprendidas) =================
  UltDef(source: _eco, ref: 'resonancia', element: _fue, classes: ['maga', 'tirador'], skill: SkillDef(id: 'ult2_atlasAbierto', name: 'Atlas Abierto', kind: _mag, power: 1.7, allTargets: true, status: StatusApplication(_burn, 1), extraStatuses: [StatusApplication(_frz, 1), StatusApplication(_poi, 1)])),
  UltDef(source: _eco, ref: 'fortuna', element: _fis, weapons: kCasterWeaponTypes, skill: SkillDef(id: 'ult2_eraSuspendida', name: 'Era Suspendida', kind: _mag, power: 3.16, delay: 1.4, ultDrain: 50)),
  UltDef(source: _eco, ref: 'ecojefe', element: _fis, classes: ['guerrero', 'paladin'], skill: SkillDef(id: 'ult2_anclaTemporal', name: 'Ancla Temporal', kind: _sup, partyShield: 0.15, partyShieldTurns: 2, partyBuffs: [PartyBuff(_guard, 0.20, 2)])),
  UltDef(source: _eco, ref: 'mastery:10', element: _fis, skill: SkillDef(id: 'ult2_golpeMaestro', name: 'Golpe Maestro', kind: _phys, power: 3.35, critBonus: 1.0)),
  UltDef(source: _eco, ref: 'mastery:20', element: _fis, skill: SkillDef(id: 'ult2_ecoDoble', name: 'Eco Doble', kind: _phys, power: 3.37, echoLast: 0.8, ultCost: 80)),
  UltDef(source: _eco, ref: 'eco:raro', element: _fis, skill: SkillDef(id: 'ult2_loQueSera', name: 'Lo Que Será', kind: _phys, delayedHit: 4.92)),

  // ================= 3.6 Botín de jefe (Fragmento de ULT) =================
  UltDef(source: _boss, ref: 'reyLimo', element: _ven, skill: SkillDef(id: 'ult2_diluvioMenor', name: 'Diluvio Menor', kind: _mag, power: 1.77, allTargets: true, status: StatusApplication(_poi, 3), ultCost: 80)),
  UltDef(source: _boss, ref: 'golemReloj', element: _hie, skill: SkillDef(id: 'ult2_engranajePrestado', name: 'Engranaje Prestado', kind: _mag, power: 1.3, allTargets: true, status: StatusApplication(_frz, 2), delay: 0.4)),
  UltDef(source: _boss, ref: 'matriarca', element: _ven, skill: SkillDef(id: 'ult2_telarTiempo', name: 'Telar del Tiempo', kind: _mag, power: 1.98, allTargets: true, status: StatusApplication(_poi, 2), debuffs: [PartyBuff(_spd, -0.20, 2)])),
  UltDef(source: _boss, ref: 'sierpe', element: _agu, skill: SkillDef(id: 'ult2_alientoPrestado', name: 'Aliento Prestado', kind: _mag, power: 1.95, allTargets: true, status: StatusApplication(_wet, 1), extraStatuses: [StatusApplication(_frz, 1)])),
  UltDef(source: _boss, ref: 'caballeroHueco', element: _fis, weapons: kMeleeWeaponTypes, skill: SkillDef(id: 'ult2_juicioAjeno', name: 'Juicio Ajeno', kind: _phys, power: 3.2, status: StatusApplication(_stun, 1), selfBuff: PartyBuff(_guard, 0.30, 2))),
  UltDef(source: _boss, ref: 'hechicera', element: _fis, weapons: kCasterWeaponTypes, skill: SkillDef(id: 'ult2_coroPrestado', name: 'Coro Prestado', kind: _mag, power: 1.76, allTargets: true, perAlly: 0.25)),
  UltDef(source: _boss, ref: 'bestiaMagma', element: _fue, skill: SkillDef(id: 'ult2_erupcionContenida', name: 'Erupción Contenida', kind: _mag, power: 1.2, allTargets: true, status: StatusApplication(_burn, 2), catalyst: 0.25)),
  UltDef(source: _boss, ref: 'espectroCoronado', element: _sag, skill: SkillDef(id: 'ult2_lamentoPrestado', name: 'Lamento Prestado', kind: _heal, power: 1.35, revive: 0.40)),
  UltDef(source: _boss, ref: 'centinela', element: _ele, skill: SkillDef(id: 'ult2_marcaVacio', name: 'Marca del Vacío', kind: _mag, power: 2.77, status: StatusApplication(_chg, 1), debuffs: [PartyBuff(_taken, 0.30, 3)], ultCost: 80)),
  UltDef(source: _boss, ref: 'devorador', element: _fue, skill: SkillDef(id: 'ult2_finPrestado', name: 'Fin Prestado', kind: _mag, power: 1.05, allTargets: true, status: StatusApplication(_burn, 2), stripBuffs: true)),
];

/// Las 50 por id.
final Map<String, UltDef> kUltV2 = {for (final u in kUltV2List) u.id: u};

/// Sus habilidades por id.
final Map<String, SkillDef> kUltV2Skills = {
  for (final u in kUltV2List) u.id: u.skill,
};

/// Jefe de Abismo → jefe base (fragmento que suelta).
const Map<String, String> kAbyssFragmentOf = {
  'golemAbismo': 'golemReloj',
  'hechiceraAbismo': 'hechicera',
  'espectroAbismo': 'espectroCoronado',
  'devoradorAbismo': 'devorador',
};

/// Probabilidad del fragmento después de la primera victoria (§ 2.3).
const kUltFragmentChance = 0.05;
const kUltFragmentChanceAbyss = 0.15;

/// ULT de las armas Raras / Épicas de tipo [type] (pool del mod).
List<String> ultV2ModsForType(String type) => [
      for (final u in kUltV2List)
        if (u.source == UltSource.weaponMod && u.weapons.contains(type)) u.id,
    ];

/// Cómo se consigue [u] (texto del repertorio).
String ultHowText(UltDef u, {String Function(String id)? name}) {
  final n = name ?? (String s) => s;
  final r = u.ref;
  return switch (u.source) {
    UltSource.weaponMod =>
      'Mod "ULT" en armas Raras (8%) o Épicas (20%) de tipo ${u.weapons.join(', ')}.',
    UltSource.unique => 'Viene con el legendario ${n(r)}.',
    UltSource.tree => () {
        final p = r.split(':');
        return 'Gastá ${p.last} puntos en el árbol de ${n(p.first)}.';
      }(),
    UltSource.feat => 'Hazaña: ${n(r)}.',
    UltSource.eco => r.startsWith('mastery:')
        ? 'Llegá a Maestría ${r.split(':').last}.'
        : r == 'eco:raro'
            ? 'Completá un Eco Raro o mejor.'
            : 'Completá un Eco con el nodo notable ${n(r)} del Atlas.',
    UltSource.boss =>
      'Fragmento de ULT de ${n(r)}: seguro en la primera victoria.',
  };
}
