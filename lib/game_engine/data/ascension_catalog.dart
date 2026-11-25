import '../models/ascension.dart';
import '../models/passive_mechanic.dart' show BuffStat;
import '../models/skill.dart';
import '../models/status.dart';
import 'ascension_mechanics.dart';

// Las 8 ascensiones (docs/specs/ascension.md § 2-4): mini-árbol de 8
// nodos, 2 habilidades de kit (el Guardián 3) y una ULT propia.

const _poi = StatusKind.poison;
const _stun = StatusKind.stun;
const _holy = StatusKind.holy;
const _wet = StatusKind.wet;
const _chg = StatusKind.charged;

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
  // Elementalista (v0.7, ascension.md § 4.1): Prisma prepara, Detonar
  // detona (catalizador).
  'prismaElemental': SkillDef(id: 'prismaElemental', name: 'Prisma Elemental', mp: 4, kind: SkillKind.magical, power: 1.3, status: StatusApplication(_wet, 1), extraStatuses: [StatusApplication(_chg, 1)]),
  'detonar': SkillDef(id: 'detonar', name: 'Detonar', mp: 5, kind: SkillKind.magical, power: 1.5, catalyst: 0.30, pulse: 2),
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
  'elementalista': SkillDef(id: 'ult_elementalista', name: 'Trinidad', kind: SkillKind.magical, power: 1.5, allTargets: true, catalyst: 0.30, status: StatusApplication(_wet, 1), extraStatuses: [StatusApplication(_chg, 1), StatusApplication(_poi, 2)]),
  'francotirador': SkillDef(id: 'ult_francotirador', name: 'Bala del Juicio', kind: SkillKind.physical, power: 4.5, critBonus: 1.0, execute: 0.30),
  'trampero': SkillDef(id: 'ult_trampero', name: 'Campo Minado', kind: SkillKind.physical, power: 1.5, allTargets: true, trap: 0.8),
  'templario': SkillDef(id: 'ult_templario', name: 'Juicio Final', kind: SkillKind.magical, power: 2.0, allTargets: true, status: StatusApplication(_stun, 1), extraStatuses: [StatusApplication(_holy, 1)]),
  'guardian': SkillDef(id: 'ult_guardian', name: 'Fortaleza Inquebrantable', kind: SkillKind.support, partyShield: 0.25, partyShieldTurns: 3, partyBuffs: [PartyBuff(BuffStat.guard, 0.25, 3)], protect: true),
};

/// Las ULT de ascensión por `SkillDef.id` (`ult_berserker`...).
final Map<String, SkillDef> kAscensionUltimatesById = {
  for (final u in kAscensionUltimates.values) u.id: u,
};

//// A branch of an ascension tree (ascension.md § 3.2): its name, the stat
/// of its minor nodes, the second stat of its major node and the ids
/// (without the `<asc>_` prefix) of its notables (tiers 3, 6) and
/// capstone (tier 10). The Trades branch has no [notables].
class AscensionBranch {
  const AscensionBranch(this.name, this.stat, this.second, this.notables);

  final String name;
  final String stat;
  final String second;
  final List<String> notables;
}

/// The 3 own branches of each ascension (§ 3.2 / 3.3).
const Map<String, List<AscensionBranch>> kAscensionBranches = {
  'berserker': [
    AscensionBranch('Furia', 'atk', 'crit', ['a1', 'a2', 'a3']),
    AscensionBranch('Sangre', 'hp', 'def', ['b1', 'b2', 'b3']),
    AscensionBranch('Rugido', 'ult', 'spd', ['c1', 'c2', 'k']),
  ],
  'senorGuerra': [
    AscensionBranch('Mando', 'ult', 'atk', ['a1', 'a2', 'a3']),
    AscensionBranch('Bandera', 'def', 'hp', ['b1', 'b2', 'b3']),
    AscensionBranch('Tambor', 'atk', 'spd', ['c1', 'c2', 'k']),
  ],
  'cronomante': [
    AscensionBranch('Retraso', 'mag', 'spd', ['a1', 'a2', 'a3']),
    AscensionBranch('Sincronía', 'spd', 'hp', ['b1', 'b2', 'b3']),
    AscensionBranch('Reloj', 'ult', 'mag', ['c1', 'c2', 'k']),
  ],
  'elementalista': [
    AscensionBranch('Reacción', 'mag', 'ult', ['a1', 'a2', 'a3']),
    AscensionBranch('Chispa', 'crit', 'mag', ['b1', 'b2', 'b3']),
    AscensionBranch('Tormenta', 'ult', 'spd', ['c1', 'c2', 'k']),
  ],
  'francotirador': [
    AscensionBranch('Marca', 'crit', 'atk', ['a1', 'a2', 'a3']),
    AscensionBranch('Recarga', 'atk', 'ult', ['b1', 'b2', 'b3']),
    AscensionBranch('Gatillo', 'spd', 'crit', ['c1', 'c2', 'k']),
  ],
  'trampero': [
    AscensionBranch('Trampa', 'atk', 'hp', ['a1', 'a2', 'a3']),
    AscensionBranch('Área', 'crit', 'atk', ['b1', 'b2', 'b3']),
    AscensionBranch('Cazador', 'ult', 'spd', ['c1', 'c2', 'k']),
  ],
  'templario': [
    AscensionBranch('Condena', 'mag', 'crit', ['a1', 'a2', 'a3']),
    AscensionBranch('Aura', 'hp', 'def', ['b1', 'b2', 'b3']),
    AscensionBranch('Fervor', 'ult', 'mag', ['c1', 'c2', 'k']),
  ],
  'guardian': [
    AscensionBranch('Escudo', 'def', 'hp', ['a1', 'a2', 'a3']),
    AscensionBranch('Mártir', 'hp', 'heal', ['b1', 'b2', 'b3']),
    AscensionBranch('Juramento', 'heal', 'def', ['c1', 'c2', 'k']),
  ],
};

/// Shared branches 4 (Echoes) and 5 (Trades), § 3.4 / 3.5.
const kEchoBranch = AscensionBranch('Ecos', 'spd', 'ult', ['e1', 'e2', 'e3']);
const kTradeBranch = AscensionBranch('Oficios', 'hp', 'atk', []);

/// The 5 branches of [ascensionId], in canvas order.
List<AscensionBranch> branchesOf(String ascensionId) => [
      ...?kAscensionBranches[ascensionId],
      kEchoBranch,
      kTradeBranch,
    ];

/// Tiers (§ 3.0) and the tree size.
abstract final class AscTree {
  static const branches = 5;
  static const tiers = 10;
  static const notableTiers = {3: 0, 6: 1};
  static const majorTier = 9;
  static const capstoneTier = 10;

  static AscNodeKind kindAt(int tier) => tier == capstoneTier
      ? AscNodeKind.capstone
      : tier == majorTier
          ? AscNodeKind.major
          : notableTiers.containsKey(tier)
              ? AscNodeKind.notable
              : AscNodeKind.minor;

  static int costOf(AscNodeKind k) => switch (k) {
        AscNodeKind.root => 0,
        AscNodeKind.minor => 1,
        AscNodeKind.notable || AscNodeKind.major => 2,
        AscNodeKind.capstone => 3,
      };
}

/// The Trades branch (§ 3.5): (name, condition, stat multiples) by tier.
const List<(String, AscCondition, Map<String, double>)> _trades = [
  ('Pan del Camino', AscCondition.meal, {'hp': 2}),
  ('Filo Templado', AscCondition.forged, {'atk': 1, 'mag': 1}),
  ('Mesa Compartida', AscCondition.meal, {'atk': 2, 'mag': 2, 'ult': 1}),
  ('Manos de Oficio', AscCondition.trade, {'hp': 2}),
  ('Temple de Fragua', AscCondition.forged, {'def': 2}),
  ('Memoria del Eco', AscCondition.mastery, {'atk': 2, 'mag': 2, 'crit': 2}),
  ('Caldo de Viaje', AscCondition.meal, {'ult': 2}),
  ('Oficio Paciente', AscCondition.trade, {'heal': 2, 'hp': 1}),
  ('Acero con Nombre', AscCondition.forged, {'atk': 3, 'mag': 3}),
  ('Corazón del Pueblo', AscCondition.town, {}),
];

/// Source texts of the Trades nodes (the UI lists the stats after them).
const Map<AscCondition, String> _tradeTexts = {
  AscCondition.meal: 'Si comiste antes de la misión, la mesa del pueblo te '
      'sostiene.',
  AscCondition.forged: 'Si tu arma tiene mejoras de forja, el acero recuerda '
      'la fragua.',
  AscCondition.trade: 'Si tenés poder de algún oficio, tus manos saben '
      'trabajar.',
  AscCondition.mastery: 'Si tu Maestría de los Ecos es alta, lo vivido '
      'vuelve a vos.',
  AscCondition.town: 'Por cada cosa del pueblo que llevás, más vida, ATQ y '
      'MAG (comida, forja, oficio y Maestría de los Ecos).',
};

/// The 51 nodes of an ascension tree (§ 3.0): root + 5 branches × 10.
List<AscensionNode> _tree(String a) {
  final out = <AscensionNode>[];
  final rm = kAscensionMechanics['${a}_r'];
  final branches = branchesOf(a);
  out.add(AscensionNode(
    id: '${a}_r',
    name: rm?.name ?? '',
    cost: 0,
    x: 2,
    y: 0,
    links: [
      for (var b = 0; b < branches.length; b++) _nodeId(a, b, 1, branches[b]),
    ],
    text: rm?.description ?? '',
    mechanicId: rm?.id,
    kind: AscNodeKind.root,
  ));
  for (var b = 0; b < branches.length; b++) {
    final br = branches[b];
    for (var t = 1; t <= AscTree.tiers; t++) {
      final kind = AscTree.kindAt(t);
      final id = _nodeId(a, b, t, br);
      final links = [
        t == 1 ? '${a}_r' : _nodeId(a, b, t - 1, br),
        if (t < AscTree.tiers) _nodeId(a, b, t + 1, br),
      ];
      if (br.notables.isEmpty) {
        final (name, cond, mults) = _trades[t - 1];
        out.add(AscensionNode(
          id: id,
          name: name,
          cost: AscTree.costOf(kind),
          x: b,
          y: t,
          links: links,
          text: _tradeTexts[cond]!,
          statMults: mults,
          kind: kind,
          condition: cond,
        ));
        continue;
      }
      final m = kAscensionMechanics[id];
      final overload = id == 'elementalista_a2';
      out.add(AscensionNode(
        id: id,
        name: m?.name ?? (overload ? 'Sobrecarga' : ''),
        cost: AscTree.costOf(kind),
        x: b,
        y: t,
        links: links,
        text: m?.description ?? (overload ? _overloadText : ''),
        mechanicId: m?.id,
        statMults: switch (kind) {
          AscNodeKind.minor => {br.stat: 1},
          AscNodeKind.major => {br.stat: 2, br.second: 1},
          _ => const {},
        },
        fixedStats: overload
            ? const {'burn': 1, 'frz': 1, 'poi': 1}
            : const <String, num>{},
        kind: kind,
      ));
    }
  }
  return out;
}

/// Id of the node at tier [t] of branch [b] (§ 3.0).
String _nodeId(String a, int b, int t, AscensionBranch br) {
  if (br.notables.isEmpty) return '${a}_of$t';
  return switch (AscTree.kindAt(t)) {
    AscNodeKind.notable => '${a}_${br.notables[AscTree.notableTiers[t]!]}',
    AscNodeKind.capstone => '${a}_${br.notables[2]}',
    _ => '${a}_m${b + 1}$t',
  };
}

const _overloadText = '+1 stack a toda Quemadura, Congelación y Veneno que '
    'aplicás (Explosiones tóxicas más grandes).';

// Las 8 ascensiones por id (contrato fijo con el arte).
final Map<String, AscensionDef> kAscensions = {
  for (final a in [
    AscensionDef(id: 'berserker', classId: 'guerrero', name: 'Berserker', theme: 'vida baja = más daño, robo de vida', motto: 'Cuanto más sangra, más pega.', color: 0xFFFF4757, skillIds: const ['sangria', 'torbellino'], ultId: 'ult_berserker', nodes: _tree('berserker')),
    AscensionDef(id: 'senorGuerra', classId: 'guerrero', name: 'Señor de la Guerra', theme: 'gritos que buffean al grupo', motto: 'Su voz es el estandarte del grupo.', color: 0xFFFFB142, skillIds: const ['gritoGuerra', 'estandarte'], ultId: 'ult_senorGuerra', nodes: _tree('senorGuerra')),
    AscensionDef(id: 'cronomante', classId: 'maga', name: 'Cronomante', theme: 'adelanta aliados, retrasa enemigos', motto: 'El tiempo obedece a su mano.', color: 0xFFA29BFE, skillIds: const ['aceleron', 'grietaTemporal'], ultId: 'ult_cronomante', nodes: _tree('cronomante')),
    AscensionDef(id: 'elementalista', classId: 'maga', name: 'Elementalista', theme: 'prepara y detona reacciones', motto: 'Ella prepara la tormenta; cualquiera la desata.', color: 0xFFFF9F43, skillIds: const ['prismaElemental', 'detonar'], ultId: 'ult_elementalista', nodes: _tree('elementalista')),
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
