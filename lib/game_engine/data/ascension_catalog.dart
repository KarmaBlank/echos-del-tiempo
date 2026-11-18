import '../models/ascension.dart';
import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart';
import '../models/status.dart';
import 'ascension_mechanics.dart';

// Las 8 ascensiones (docs/specs/ascension.md § 2-4): mini-árbol de 8
// nodos, 2 habilidades de kit (el Guardián 3) y una ULT propia.

const _burn = StatusKind.burn;
const _poi = StatusKind.poison;
const _frz = StatusKind.freeze;
const _stun = StatusKind.stun;
const _holy = StatusKind.holy;

/// Habilidades del kit de las ascensiones (se suman a `kSkills`).
const Map<String, SkillDef> kAscensionSkills = {
  // Berserker
  'sangria': SkillDef(id: 'sangria', name: 'Sangría', mp: 3, kind: SkillKind.physical, power: 2.4, hpCost: 0.10),
  'torbellino': SkillDef(id: 'torbellino', name: 'Torbellino Rojo', mp: 6, kind: SkillKind.physical, power: 1.2, allTargets: true, lifeSteal: 0.30),
  // Señor de la Guerra
  'gritoGuerra': SkillDef(id: 'gritoGuerra', name: 'Grito de Guerra', mp: 5, kind: SkillKind.support, partyBuffs: [PartyBuff(BuffStat.attack, 0.25, 3)]),
  'estandarte': SkillDef(id: 'estandarte', name: 'Estandarte', mp: 6, kind: SkillKind.support, partyBuffs: [PartyBuff(BuffStat.guard, 0.25, 2)]),
  // Cronomante
  'aceleron': SkillDef(id: 'aceleron', name: 'Acelerón', mp: 6, kind: SkillKind.support, advanceAllies: 0.40),
  'grietaTemporal': SkillDef(id: 'grietaTemporal', name: 'Grieta Temporal', mp: 5, kind: SkillKind.magical, power: 1.5, delay: 0.8),
  // Elementalista
  'prismaElemental': SkillDef(id: 'prismaElemental', name: 'Prisma Elemental', mp: 4, kind: SkillKind.magical, power: 1.4, status: StatusApplication(_burn, 1), extraStatuses: [StatusApplication(_frz, 1), StatusApplication(_poi, 1)]),
  'detonar': SkillDef(id: 'detonar', name: 'Detonar', mp: 6, kind: SkillKind.magical, power: 1.2, detonate: 0.30),
  // Francotirador
  'tiroCabeza': SkillDef(id: 'tiroCabeza', name: 'Tiro a la Cabeza', mp: 6, kind: SkillKind.physical, power: 2.4, critBonus: 0.35, execute: 0.25),
  'apuntar': SkillDef(id: 'apuntar', name: 'Apuntar', mp: 3, kind: SkillKind.support, selfBuff: PartyBuff(BuffStat.crit, 1.0, 1), selfTurn: 0.5),
  // Trampero
  'trampaPuas': SkillDef(id: 'trampaPuas', name: 'Trampa de Púas', mp: 4, kind: SkillKind.support, allTargets: true, trap: 1.0),
  'redCaza': SkillDef(id: 'redCaza', name: 'Red de Caza', mp: 4, kind: SkillKind.physical, power: 1.1, delay: 0.5, status: StatusApplication(_poi, 2)),
  // Templario
  'castigo': SkillDef(id: 'castigo', name: 'Castigo Sagrado', mp: 4, kind: SkillKind.magical, power: 1.6, status: StatusApplication(_stun, 1, chance: 0.35), extraStatuses: [StatusApplication(_holy, 1)]),
  'luzCegadora': SkillDef(id: 'luzCegadora', name: 'Luz Cegadora', mp: 7, kind: SkillKind.magical, power: 0.9, allTargets: true, status: StatusApplication(_stun, 1, chance: 0.25)),
  // Guardián: el kit clásico del Paladín (hasta v0.4 era de la clase),
  // mejorado. Fortaleza absorbe a la vieja Égida Grupal.
  'proteccion': SkillDef(id: 'proteccion', name: 'Protección', mp: 5, kind: SkillKind.protect, selfBuff: PartyBuff(BuffStat.guard, 0.20, 1)),
  'fortaleza': SkillDef(id: 'fortaleza', name: 'Fortaleza', mp: 6, kind: SkillKind.defenseUp, amount: 2, partyShield: 0.15, partyShieldTurns: 3, partyBuffs: [PartyBuff(BuffStat.guard, 0.10, 2)]),
  'aura': SkillDef(id: 'aura', name: 'Aura Restauradora', mp: 6, kind: SkillKind.regen, power: 1.0),
};

/// ULT de cada ascensión, por id de ascensión (reemplaza la del arma).
const Map<String, SkillDef> kAscensionUltimates = {
  'berserker': SkillDef(id: 'ult_berserker', name: 'Frenesí Carmesí', kind: SkillKind.physical, power: 3.6, critBonus: 0.3, lifeSteal: 0.5),
  'senorGuerra': SkillDef(id: 'ult_senorGuerra', name: 'Llamado a las Armas', kind: SkillKind.physical, power: 1.6, allTargets: true, partyBuffs: [PartyBuff(BuffStat.attack, 0.30, 3)], advanceAllies: 0.30),
  'cronomante': SkillDef(id: 'ult_cronomante', name: 'Detener el Tiempo', kind: SkillKind.magical, power: 1.4, allTargets: true, delay: 1.2, advanceAllies: 0.50),
  'elementalista': SkillDef(id: 'ult_elementalista', name: 'Trinidad', kind: SkillKind.magical, power: 1.7, allTargets: true, status: StatusApplication(_burn, 2), extraStatuses: [StatusApplication(_frz, 2), StatusApplication(_poi, 2)]),
  'francotirador': SkillDef(id: 'ult_francotirador', name: 'Bala del Juicio', kind: SkillKind.physical, power: 4.5, critBonus: 1.0, execute: 0.30),
  'trampero': SkillDef(id: 'ult_trampero', name: 'Campo Minado', kind: SkillKind.physical, power: 1.5, allTargets: true, trap: 0.8),
  'templario': SkillDef(id: 'ult_templario', name: 'Juicio Final', kind: SkillKind.magical, power: 2.0, allTargets: true, status: StatusApplication(_stun, 1), extraStatuses: [StatusApplication(_holy, 1)]),
  'guardian': SkillDef(id: 'ult_guardian', name: 'Fortaleza Inquebrantable', kind: SkillKind.support, partyShield: 0.25, partyShieldTurns: 3, partyBuffs: [PartyBuff(BuffStat.guard, 0.25, 3)], protect: true),
};

/// Las ULT de ascensión por `SkillDef.id` (`ult_berserker`...).
final Map<String, SkillDef> kAscensionUltimatesById = {
  for (final u in kAscensionUltimates.values) u.id: u,
};

/// Los 8 nodos con la forma de § 3 (raíz, dos ramas de 3 y la final).
List<AscensionNode> _tree(String a) {
  AscensionNode n(String key, int cost, int x, int y, List<String> links,
      {bool major = false, Map<String, num> stats = const {}}) {
    final id = '${a}_$key';
    final m = kAscensionMechanics[id];
    return AscensionNode(
      id: id,
      name: m?.name ?? _statNames[id] ?? id,
      cost: cost,
      x: x,
      y: y,
      links: [for (final l in links) '${a}_$l'],
      text: m?.description ?? _statTexts[id] ?? '',
      mechanicId: m?.id,
      stats: stats,
      major: major,
    );
  }

  final sobrecarga = a == 'elementalista'
      ? const {'burn': 1, 'frz': 1, 'poi': 1}
      : const <String, num>{};
  return [
    n('r', 0, 0, 0, ['a1', 'b1']),
    n('a1', 1, -1, 1, ['r', 'a2']),
    n('a2', 1, -1, 2, ['a1', 'a3'], stats: sobrecarga),
    n('a3', 2, -1, 3, ['a2', 'k'], major: true),
    n('b1', 1, 1, 1, ['r', 'b2']),
    n('b2', 1, 1, 2, ['b1', 'b3']),
    n('b3', 2, 1, 3, ['b2', 'k'], major: true),
    n('k', 2, 0, 4, ['a3', 'b3'], major: true),
  ];
}

/// Nodos de stats (sin mecánica).
const _statNames = {'elementalista_a2': 'Sobrecarga'};
const _statTexts = {
  'elementalista_a2':
      '+1 stack a toda Quemadura, Congelación y Veneno que aplicás.',
};

/// Las 8 ascensiones por id (contrato fijo con el arte).
final Map<String, AscensionDef> kAscensions = {
  for (final a in [
    AscensionDef(id: 'berserker', classId: 'guerrero', name: 'Berserker', theme: 'vida baja = más daño, robo de vida', motto: 'Cuanto más sangra, más pega.', color: 0xFFFF4757, skillIds: const ['sangria', 'torbellino'], ultId: 'ult_berserker', nodes: _tree('berserker')),
    AscensionDef(id: 'senorGuerra', classId: 'guerrero', name: 'Señor de la Guerra', theme: 'gritos que buffean al grupo', motto: 'Su voz es el estandarte del grupo.', color: 0xFFFFB142, skillIds: const ['gritoGuerra', 'estandarte'], ultId: 'ult_senorGuerra', nodes: _tree('senorGuerra')),
    AscensionDef(id: 'cronomante', classId: 'maga', name: 'Cronomante', theme: 'adelanta aliados, retrasa enemigos', motto: 'El tiempo obedece a su mano.', color: 0xFFA29BFE, skillIds: const ['aceleron', 'grietaTemporal'], ultId: 'ult_cronomante', nodes: _tree('cronomante')),
    AscensionDef(id: 'elementalista', classId: 'maga', name: 'Elementalista', theme: 'combos de Quemadura, Congelación y Veneno', motto: 'Fuego, hielo y veneno en una sola mano.', color: 0xFFFF9F43, skillIds: const ['prismaElemental', 'detonar'], ultId: 'ult_elementalista', nodes: _tree('elementalista')),
    AscensionDef(id: 'francotirador', classId: 'tirador', name: 'Francotirador', theme: 'críticos enormes a un objetivo', motto: 'Un disparo. Una baja.', color: 0xFFFF6B81, skillIds: const ['tiroCabeza', 'apuntar'], ultId: 'ult_francotirador', nodes: _tree('francotirador')),
    AscensionDef(id: 'trampero', classId: 'tirador', name: 'Trampero', theme: 'trampas y daño en área', motto: 'El campo de batalla ya es suyo.', color: 0xFF7BED9F, skillIds: const ['trampaPuas', 'redCaza'], ultId: 'ult_trampero', nodes: _tree('trampero')),
    AscensionDef(id: 'templario', classId: 'paladin', name: 'Templario', theme: 'daño sagrado y aturdir', motto: 'La luz juzga y no perdona.', color: 0xFFFFEAA7, skillIds: const ['castigo', 'luzCegadora'], ultId: 'ult_templario', nodes: _tree('templario')),
    AscensionDef(id: 'guardian', classId: 'paladin', name: 'Guardián', theme: 'escudos y protección del grupo', motto: 'Nadie cae mientras él esté en pie.', color: 0xFF74B9FF, skillIds: const ['proteccion', 'fortaleza', 'aura'], ultId: 'ult_guardian', nodes: _tree('guardian')),
  ])
    a.id: a,
};

/// Las 2 ascensiones de una clase, en orden (A, B).
List<AscensionDef> ascensionsOf(String classId) =>
    [for (final a in kAscensions.values) if (a.classId == classId) a];
