import '../data/enemy_families.dart' show ComboRulesDef, HitCapDef;
import '../data/ults_v2_catalog.dart' show kUltV2;
import '../data/zone_curve.dart';
import '../data/tuning_catalog.dart';
import '../models/abyss.dart';
import '../models/achievement.dart';
import '../models/class_def.dart';
import '../models/elements.dart';
import '../models/enemy_def.dart';
import '../models/item.dart';
import '../models/passive_mechanic.dart';
import '../models/passive_tree.dart';
import '../models/skill.dart';
import '../models/weapon.dart';
import 'balance_fields.dart';

/// Tipos de entidad que un parche de balance puede tocar
/// (docs/specs/balance_admin.md § 1.1). [jsonKey] es la clave en
/// `overrides`.
enum BalanceKind {
  skill('skill', 'Habilidades', 'Habilidad', disable: true),
  ultimate('ultimate', 'ULT', 'ULT'),
  dual('dual', 'Duales', 'Dual'),
  weapon('weapon', 'Armas', 'Arma'),
  enemy('enemy', 'Enemigos', 'Enemigo'),
  enemyUlt('enemyUlt', 'ULT enemigas', 'ULT enemiga'),
  classDef('class', 'Clases', 'Clase'),
  affix('affix', 'Afijos', 'Afijo', disable: true),
  passiveNode('passiveNode', 'Nodos del árbol', 'Nodo', disable: true),
  mechanic('mechanic', 'Mecánicas', 'Mecánica', disable: true),

  /// Reacciones elementales v0.7 (elemental_reactions.md § 2).
  reaction('reaction', 'Reacciones', 'Reacción'),

  /// Mojado, Cargado y Congelación (elemental_reactions.md § 1 y § 7).
  elementStatus('elementStatus', 'Estados elementales', 'Estado elemental'),

  /// Jefes del Abismo v0.8 (abyss_bosses.md § 2–3).
  abyssBoss('abyssBoss', 'Jefes del Abismo', 'Jefe del Abismo'),

  /// Drop de Fragmentos del Abismo (abyss_bosses.md § 1.1).
  fragmentDrop('fragmentDrop', 'Fragmentos', 'Drop de Fragmentos'),

  /// Tope por golpe sin debilidad (combo_balance.md § 3.2).
  hitCap('hitCap', 'Tope por golpe', 'Tope por golpe'),

  /// Convergencias, área y quiebre (combo_balance.md § 4-5).
  combo('combo', 'Combos y quiebre', 'Reglas de combos'),

  /// Curva por tramos y grupo (combo_balance.md § 1 y § 3.3).
  curve('curve', 'Curva y grupo', 'Curva y grupo'),

  // ---- Ajustes (tuning_catalog.dart): un grupo de números por tipo ----

  /// Escalado de ULT por nivel (ultimates_v2.md § 2.4).
  ultLevel('ultLevel', 'ULT: escalado por nivel', 'Escalado de ULT'),

  /// Costo de mejorar una ULT (ultimates_v2.md § 2.4).
  ultUpgrade('ultUpgrade', 'ULT: costo de mejora', 'Mejora de ULT'),

  /// Carga de la barra ULT (golpes, daño recibido, enemigos).
  ultCharge('ultCharge', 'ULT: carga de la barra', 'Carga de ULT'),

  /// Recetas de Condensar (materials_economy.md § 4.3).
  condense('condense', 'Condensar', 'Recetas de Condensar'),

  /// Drop de materiales, desarme y costos por rareza (economía v0.15).
  materials('materials', 'Economía de materiales', 'Economía de materiales'),

  /// Bonus de cantidad por tier y grupo en los Ecos (§ 4.4).
  ecoTier('ecoTier', 'Ecos: bonus de tier', 'Bonus de Ecos'),

  /// Recompensa de cada hazaña (achievements.md § 1).
  featReward('featReward', 'Hazañas', 'Hazaña');

  const BalanceKind(this.jsonKey, this.plural, this.singular,
      {this.disable = false});

  final String jsonKey;
  final String plural;
  final String singular;

  /// Admite `disabled` (§ 1.2).
  final bool disable;

  static BalanceKind? byJsonKey(String key) {
    for (final k in values) {
      if (k.jsonKey == key) return k;
    }
    return null;
  }
}

/// Lector tipado de un mapa de campos ya validado (valores base +
/// overrides).
class BalanceFieldReader {
  const BalanceFieldReader(this.values);
  final Map<String, Object?> values;

  int i(String k) => (values[k] as num).toInt();
  double d(String k) => (values[k] as num).toDouble();
  bool b(String k) => values[k] == true;
  bool get disabled => values['disabled'] == true;
}

/// Cómo leer y reconstruir una entidad de un tipo. No es genérica a
/// propósito: el admin trata todas las entidades igual (`Object`).
class EntityCodec {
  const EntityCodec({
    required this.kind,
    required this.fields,
    required this.read,
    required this.write,
    required this.nameOf,
  });

  final BalanceKind kind;
  final List<BalanceField> fields;

  /// Valores actuales de la entidad, codificados (todos los [fields]).
  final Map<String, Object?> Function(Object e) read;

  /// La entidad con los valores de [f] (los no editables, de [base]).
  final Object Function(Object base, BalanceFieldReader f) write;
  final String Function(Object e) nameOf;

  BalanceField? field(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }
}

const _int = BalanceFieldType.integer;
const _dec = BalanceFieldType.decimal;
const _frac = BalanceFieldType.fraction;
const _flag = BalanceFieldType.flag;

const _disabled = BalanceField('disabled', 'Desactivada', _flag);

// ---------------------------------------------------------------------
// Habilidades y ULT
// ---------------------------------------------------------------------

const _skillCombat = <BalanceField>[
  BalanceField('power', 'Poder', _dec, max: 20, step: 0.05),
  BalanceField('hits', 'Golpes', _int, min: 1, max: 10),
  BalanceField('critBonus', 'Crítico extra', _frac, max: 1, step: 0.01),
  BalanceField('delay', 'Retraso al objetivo', _dec, max: 3, step: 0.05),
  BalanceField('allTargets', 'A todos los enemigos', _flag),
  BalanceField('status', 'Estado', BalanceFieldType.status, nullable: true),
  BalanceField('extraStatuses', 'Estados extra', BalanceFieldType.statusList),
  BalanceField('debuffs', 'Debuffs', BalanceFieldType.buffList),
  BalanceField('partyBuffs', 'Buffs de grupo', BalanceFieldType.buffList),
  BalanceField('selfBuff', 'Buff propio', BalanceFieldType.buff, nullable: true),
  BalanceField('cleanse', 'Limpia estados', _int, max: 10),
  BalanceField('amount', 'Cantidad (turnos / DEF)', _int, max: 30),
  BalanceField('hpCost', 'Costo de vida', _frac, max: 1, step: 0.01),
  BalanceField('lifeSteal', 'Robo de vida', _frac, max: 2, step: 0.01),
  BalanceField('detonate', 'Detonar (por stack)', _dec, max: 5, step: 0.05),
  BalanceField('catalyst', 'Catalizador (× al detonar)', _dec, max: 5, step: 0.05),
  BalanceField('execute', 'Remate bajo', _frac, max: 1, step: 0.01),
  BalanceField('trap', 'Trampa (× ATQ)', _dec, max: 10, step: 0.05),
  BalanceField('partyShield', 'Escudo de grupo', _frac, max: 2, step: 0.01),
  BalanceField('partyShieldTurns', 'Turnos del escudo de grupo', _int, max: 10),
  BalanceField('advanceAllies', 'Adelanta aliados', _frac, max: 1, step: 0.01),
  BalanceField('selfTurn', 'Factor del próximo turno', _dec, max: 2, step: 0.05),
  BalanceField('protect', 'Pone Protección', _flag),
  BalanceField('revive', 'Revive con', _frac, max: 1, step: 0.01),
  BalanceField('overheal', 'Sobrecura a escudo', _frac, max: 2, step: 0.01),
  BalanceField('drainHeal', 'Drenaje al más herido', _frac, max: 2, step: 0.01),
  BalanceField('allyShield', 'Escudo al más herido', _frac, max: 2, step: 0.01),
  BalanceField('selfShield', 'Escudo propio', _frac, max: 2, step: 0.01),
  BalanceField('shieldTurns', 'Turnos de escudo', _int, max: 10),
  BalanceField('shieldReflect', 'Reflejo del escudo', _frac, max: 2, step: 0.01),
  BalanceField('shieldBurst', 'Explosión del escudo (× ATQ)', _dec, max: 10, step: 0.05),
  BalanceField('shieldGrow', 'Crecimiento del escudo', _frac, max: 2, step: 0.01),
  BalanceField('pierce', 'Atraviesa', _frac, max: 2, step: 0.01),
  BalanceField('bounces', 'Rebotes', _int, max: 10),
  BalanceField('charge', 'Disparo cargado (× ATQ)', _dec, max: 20, step: 0.05),
  BalanceField('breakBonus', 'Quiebre extra', _frac, max: 5, step: 0.05),
  BalanceField('ultDrain', 'Quita carga de ULT', _dec, max: 100, step: 1),
  BalanceField('breaks', 'Quebrar (quiebra a un Fisurado)', _flag),
];

const _mpField = BalanceField('mp', 'MP', _int, max: 99);

// Pulso e Instante (combo_balance.md § 5.2). Las precondiciones no se
// editan en el admin: se conservan las del catálogo.
const _pulseField = BalanceField('pulse', 'Pulso', _int, max: 5);
const _instantField = BalanceField('instant', 'Instante (no termina el turno)', _flag);

Map<String, Object?> _readSkill(Object o) {
  final s = o as SkillDef;
  return {
    'mp': s.mp,
    'power': s.power,
    'hits': s.hits,
    'critBonus': s.critBonus,
    'delay': s.delay,
    'allTargets': s.allTargets,
    'status': encodeStatus(s.status),
    'extraStatuses': encodeStatusList(s.extraStatuses),
    'debuffs': encodeBuffList(s.debuffs),
    'partyBuffs': encodeBuffList(s.partyBuffs),
    'selfBuff': encodeBuff(s.selfBuff),
    'cleanse': s.cleanse,
    'amount': s.amount,
    'hpCost': s.hpCost,
    'lifeSteal': s.lifeSteal,
    'detonate': s.detonate,
    'catalyst': s.catalyst,
    'execute': s.execute,
    'trap': s.trap,
    'partyShield': s.partyShield,
    'partyShieldTurns': s.partyShieldTurns,
    'advanceAllies': s.advanceAllies,
    'selfTurn': s.selfTurn,
    'protect': s.protect,
    'revive': s.revive,
    'overheal': s.overheal,
    'drainHeal': s.drainHeal,
    'allyShield': s.allyShield,
    'selfShield': s.selfShield,
    'shieldTurns': s.shieldTurns,
    'shieldReflect': s.shieldReflect,
    'shieldBurst': s.shieldBurst,
    'shieldGrow': s.shieldGrow,
    'pierce': s.pierce,
    'bounces': s.bounces,
    'charge': s.charge,
    'breakBonus': s.breakBonus,
    'ultDrain': s.ultDrain,
    'breaks': s.breaks,
    'pulse': s.pulse,
    'instant': s.instant,
    // ULT v2 (ultimates_v2.md § 5.4).
    'pulseParty': s.pulseParty,
    'openerBonus': s.openerBonus,
    'echoLast': s.echoLast,
    'delayedHit': s.delayedHit,
    'perAlly': s.perAlly,
    'stripBuffs': s.stripBuffs,
    'disabled': false,
  };
}

Object _writeSkill(Object o, BalanceFieldReader f) {
  final b = o as SkillDef;
  return SkillDef(
    id: b.id,
    name: b.name,
    kind: b.kind,
    mp: f.i('mp'),
    power: f.d('power'),
    allTargets: f.b('allTargets'),
    delay: f.d('delay'),
    status: decodeStatus(f.values['status']),
    critBonus: f.d('critBonus'),
    cleanse: f.i('cleanse'),
    amount: f.i('amount'),
    hpCost: f.d('hpCost'),
    lifeSteal: f.d('lifeSteal'),
    extraStatuses: decodeStatusList(f.values['extraStatuses']),
    detonate: f.d('detonate'),
    catalyst: f.d('catalyst'),
    execute: f.d('execute'),
    trap: f.d('trap'),
    partyBuffs: decodeBuffList(f.values['partyBuffs']),
    partyShield: f.d('partyShield'),
    partyShieldTurns: f.i('partyShieldTurns'),
    advanceAllies: f.d('advanceAllies'),
    selfBuff: decodeBuff(f.values['selfBuff']),
    selfTurn: f.d('selfTurn'),
    protect: f.b('protect'),
    lowestAlly: b.lowestAlly,
    revive: f.d('revive'),
    overheal: f.d('overheal'),
    drainHeal: f.d('drainHeal'),
    allyShield: f.d('allyShield'),
    selfShield: f.d('selfShield'),
    shieldTurns: f.i('shieldTurns'),
    shieldReflect: f.d('shieldReflect'),
    shieldBurst: f.d('shieldBurst'),
    shieldGrow: f.d('shieldGrow'),
    pierce: f.d('pierce'),
    bounces: f.i('bounces'),
    hits: f.i('hits'),
    charge: f.d('charge'),
    debuffs: decodeBuffList(f.values['debuffs']),
    breakBonus: f.d('breakBonus'),
    ultDrain: f.d('ultDrain'),
    breaks: f.b('breaks'),
    pulse: f.values.containsKey('pulse') ? f.i('pulse') : b.pulse,
    instant: f.values.containsKey('instant') ? f.b('instant') : b.instant,
    requires: b.requires,
    pulseParty:
        f.values.containsKey('pulseParty') ? f.i('pulseParty') : b.pulseParty,
    openerBonus: f.values.containsKey('openerBonus')
        ? f.d('openerBonus')
        : b.openerBonus,
    echoLast: f.values.containsKey('echoLast') ? f.d('echoLast') : b.echoLast,
    delayedHit:
        f.values.containsKey('delayedHit') ? f.d('delayedHit') : b.delayedHit,
    perAlly: f.values.containsKey('perAlly') ? f.d('perAlly') : b.perAlly,
    stripBuffs:
        f.values.containsKey('stripBuffs') ? f.b('stripBuffs') : b.stripBuffs,
  );
}

String _skillName(Object o) => (o as SkillDef).name;

/// ULT v2 (ultimates_v2.md § 5.3): nombre, fuente y compatibilidad.
String _ultName(Object o) {
  final s = o as SkillDef;
  final u = kUltV2[s.id];
  if (u == null) return s.name;
  final compat = [...u.weapons, ...u.classes];
  return '${s.name} · ${u.source.label}'
      '${compat.isEmpty ? '' : ' · ${compat.join('/')}'}';
}

const skillCodec = EntityCodec(
  kind: BalanceKind.skill,
  fields: [_mpField, _pulseField, _instantField, ..._skillCombat, _disabled],
  read: _readSkill,
  write: _writeSkill,
  nameOf: _skillName,
);

/// Campos propios de las ULT (ultimates_v2.md § 2.2 y § 5.4).
const _ultFields = <BalanceField>[
  _pulseField,
  _instantField,
  BalanceField('pulseParty', 'Pulso al grupo', _int, max: 5),
  BalanceField('openerBonus', 'Extra con vida llena', _frac, max: 3, step: 0.05),
  BalanceField('echoLast', 'Repite la última habilidad (×)', _dec, max: 2, step: 0.05),
  BalanceField('delayedHit', 'Golpe diferido (× ATQ/MAG)', _dec, max: 20, step: 0.05),
  BalanceField('perAlly', 'Poder por aliado vivo', _dec, max: 2, step: 0.05),
  BalanceField('stripBuffs', 'Quita buffs enemigos', _flag),
];

final ultimateCodec = EntityCodec(
  kind: BalanceKind.ultimate,
  fields: [..._ultFields, ..._skillCombat],
  read: (o) => _readSkill(o)..remove('disabled'),
  write: _writeSkill,
  nameOf: _ultName,
);

// ---------------------------------------------------------------------
// Duales
// ---------------------------------------------------------------------

final dualCodec = EntityCodec(
  kind: BalanceKind.dual,
  fields: const [
    BalanceField('power', 'Poder', _dec, max: 20, step: 0.05),
    BalanceField('status', 'Estado', BalanceFieldType.status),
  ],
  read: (o) {
    final d = o as DualDef;
    return {'power': d.power, 'status': encodeStatus(d.status)};
  },
  write: (o, f) {
    final d = o as DualDef;
    return DualDef(d.name, decodeStatus(f.values['status'])!, f.d('power'),
        weapons: d.weapons);
  },
  nameOf: (o) => (o as DualDef).name,
);

// ---------------------------------------------------------------------
// Armas
// ---------------------------------------------------------------------

final weaponCodec = EntityCodec(
  kind: BalanceKind.weapon,
  fields: const [
    BalanceField('level', 'Nivel requerido', _int, min: 1, max: 60),
    BalanceField('tier', 'Tier', _int, max: 10),
    BalanceField('price', 'Precio', _int, max: 1000000, step: 50),
    BalanceField('weight', 'Peso (−velocidad)', _dec, max: 10, step: 0.1),
    BalanceField('shieldDefense', 'DEF del escudo', _int, max: 200),
    BalanceField('requirements', 'Requisitos', BalanceFieldType.attributes),
    BalanceField('atk', 'Fórmula de ATQ', BalanceFieldType.formula),
    BalanceField('mag', 'Fórmula de MAG', BalanceFieldType.formula, nullable: true),
    BalanceField('skillIds', 'Habilidades', BalanceFieldType.idList),
  ],
  read: (o) {
    final w = o as WeaponDef;
    return {
      'level': w.level,
      'tier': w.tier,
      'price': w.price,
      'weight': w.weight,
      'shieldDefense': w.shieldDefense,
      'requirements': encodeAttributes(w.requirements),
      'atk': encodeFormula(w.atk),
      'mag': encodeFormula(w.mag),
      'skillIds': List<String>.from(w.skillIds),
    };
  },
  write: (o, f) {
    final w = o as WeaponDef;
    return WeaponDef(
      id: w.id,
      name: w.name,
      classId: w.classId,
      type: w.type,
      tier: f.i('tier'),
      level: f.i('level'),
      price: f.i('price'),
      requirements: decodeAttributes(f.values['requirements']),
      atk: decodeFormula(f.values['atk'])!,
      mag: decodeFormula(f.values['mag']),
      skillIds: List<String>.unmodifiable(f.values['skillIds'] as List),
      weight: f.d('weight'),
      shieldDefense: f.i('shieldDefense'),
      implicit: w.implicit,
    );
  },
  nameOf: (o) => (o as WeaponDef).name,
);

/// [w] con otras habilidades (habilidades desactivadas, § 1.2).
WeaponDef weaponWithSkills(WeaponDef w, List<String> skillIds) => WeaponDef(
      id: w.id,
      name: w.name,
      classId: w.classId,
      type: w.type,
      tier: w.tier,
      level: w.level,
      price: w.price,
      requirements: w.requirements,
      atk: w.atk,
      mag: w.mag,
      skillIds: List.unmodifiable(skillIds),
      weight: w.weight,
      shieldDefense: w.shieldDefense,
      implicit: w.implicit,
    );

// ---------------------------------------------------------------------
// Enemigos y ULT enemigas
// ---------------------------------------------------------------------

final enemyCodec = EntityCodec(
  kind: BalanceKind.enemy,
  fields: const [
    BalanceField('hp', 'Vida', _int, min: 1, max: 100000, step: 5),
    BalanceField('attack', 'ATQ', _int, max: 5000),
    BalanceField('speed', 'Velocidad', _dec, min: 0.5, max: 50, step: 0.5),
    BalanceField('xp', 'XP', _int, max: 100000, step: 5),
    BalanceField('credits', 'Créditos', _int, max: 100000, step: 5),
    BalanceField('breakMax', 'Umbral de quiebre', _int, max: 100000, step: 5),
    BalanceField('armor', 'Armadura', _frac, max: 0.9, step: 0.01),
    BalanceField('evasion', 'Evasión', _frac, max: 0.9, step: 0.01),
    BalanceField('delayHit', 'Retraso por golpe', _dec, max: 2, step: 0.05),
    BalanceField('markHit', 'Marca por golpe', _frac, max: 2, step: 0.01),
    BalanceField('pierce', 'Perforante', _flag),
    BalanceField('areaAttack', 'Ataque en área', _flag),
    BalanceField('inflicts', 'Estado que aplica', BalanceFieldType.status, nullable: true),
    BalanceField('inflictCycle', 'Estados en ciclo', BalanceFieldType.statusList),
  ],
  read: (o) {
    final e = o as EnemyDef;
    return {
      'hp': e.hp,
      'attack': e.attack,
      'speed': e.speed,
      'xp': e.xp,
      'credits': e.credits,
      'breakMax': e.breakMax,
      'armor': e.armor,
      'evasion': e.evasion,
      'delayHit': e.delayHit,
      'markHit': e.markHit,
      'pierce': e.pierce,
      'areaAttack': e.areaAttack,
      'inflicts': encodeStatus(e.inflicts),
      'inflictCycle': encodeStatusList(e.inflictCycle),
    };
  },
  write: (o, f) {
    final e = o as EnemyDef;
    return EnemyDef(
      id: e.id,
      name: e.name,
      hp: f.i('hp'),
      attack: f.i('attack'),
      speed: f.d('speed'),
      xp: f.i('xp'),
      credits: f.i('credits'),
      inflicts: decodeStatus(f.values['inflicts']),
      pierce: f.b('pierce'),
      boss: e.boss,
      areaAttack: f.b('areaAttack'),
      breakMax: f.i('breakMax'),
      ultId: e.ultId,
      eliteUltId: e.eliteUltId,
      title: e.title,
      mechanicId: e.mechanicId,
      legendaryId: e.legendaryId,
      armor: f.d('armor'),
      passive: e.passive,
      feminine: e.feminine,
      evasion: f.d('evasion'),
      delayHit: f.d('delayHit'),
      markHit: f.d('markHit'),
      inflictCycle: decodeStatusList(f.values['inflictCycle']),
    );
  },
  nameOf: (o) => (o as EnemyDef).name,
);

final enemyUltCodec = EntityCodec(
  kind: BalanceKind.enemyUlt,
  fields: const [
    BalanceField('power', 'Poder (× ATQ)', _dec, max: 20, step: 0.05),
    BalanceField('allTargets', 'A todo el grupo', _flag),
    BalanceField('status', 'Estado', BalanceFieldType.status, nullable: true),
    BalanceField('delayAll', 'Retraso al grupo', _dec, max: 3, step: 0.05),
    BalanceField('wipeBuffs', 'Borra buffs', _flag),
    BalanceField('guaranteedCrit', 'Crítico garantizado', _flag),
    BalanceField('perAdd', 'Poder por invocación', _dec, max: 5, step: 0.05),
    BalanceField('turns', 'Turnos', _int, max: 10),
    // ULT de élite v2 (ultimates_v2.md § 4.3).
    BalanceField('hits', 'Golpes', _int, min: 1, max: 10),
    BalanceField('selfShield', 'Escudo propio', _frac, max: 2, step: 0.01),
    BalanceField('selfShieldTurns', 'Turnos del escudo', _int, max: 10),
    BalanceField('drainHeal', 'Se cura del daño', _frac, max: 2, step: 0.01),
    BalanceField('delayTarget', 'Retraso al golpeado', _dec, max: 3, step: 0.05),
    BalanceField('debuffs', 'Debuffs', BalanceFieldType.buffList),
    BalanceField('extraStatuses', 'Estados extra', BalanceFieldType.statusList),
    BalanceField('cycleStatus', 'Estado de su ciclo', _flag),
  ],
  read: (o) {
    final u = o as EnemyUltDef;
    return {
      'power': u.power,
      'allTargets': u.allTargets,
      'status': encodeStatus(u.status),
      'delayAll': u.delayAll,
      'wipeBuffs': u.wipeBuffs,
      'guaranteedCrit': u.guaranteedCrit,
      'perAdd': u.perAdd,
      'turns': u.turns,
      'hits': u.hits,
      'selfShield': u.selfShield,
      'selfShieldTurns': u.selfShieldTurns,
      'drainHeal': u.drainHeal,
      'delayTarget': u.delayTarget,
      'debuffs': encodeBuffList(u.debuffs),
      'extraStatuses': encodeStatusList(u.extraStatuses),
      'cycleStatus': u.cycleStatus,
    };
  },
  write: (o, f) {
    final u = o as EnemyUltDef;
    return EnemyUltDef(
      id: u.id,
      name: u.name,
      power: f.d('power'),
      allTargets: f.b('allTargets'),
      status: decodeStatus(f.values['status']),
      delayAll: f.d('delayAll'),
      wipeBuffs: f.b('wipeBuffs'),
      guaranteedCrit: f.b('guaranteedCrit'),
      extra: u.extra,
      perAdd: f.d('perAdd'),
      turns: f.i('turns'),
      hits: f.values.containsKey('hits') ? f.i('hits') : u.hits,
      selfShield:
          f.values.containsKey('selfShield') ? f.d('selfShield') : u.selfShield,
      selfShieldTurns: f.values.containsKey('selfShieldTurns')
          ? f.i('selfShieldTurns')
          : u.selfShieldTurns,
      drainHeal:
          f.values.containsKey('drainHeal') ? f.d('drainHeal') : u.drainHeal,
      delayTarget: f.values.containsKey('delayTarget')
          ? f.d('delayTarget')
          : u.delayTarget,
      debuffs: f.values.containsKey('debuffs')
          ? decodeBuffList(f.values['debuffs'])
          : u.debuffs,
      extraStatuses: f.values.containsKey('extraStatuses')
          ? decodeStatusList(f.values['extraStatuses'])
          : u.extraStatuses,
      cycleStatus: f.values.containsKey('cycleStatus')
          ? f.b('cycleStatus')
          : u.cycleStatus,
    );
  },
  nameOf: (o) => (o as EnemyUltDef).name,
);

// ---------------------------------------------------------------------
// Clases
// ---------------------------------------------------------------------

final classCodec = EntityCodec(
  kind: BalanceKind.classDef,
  fields: const [
    BalanceField('baseDefense', 'DEF base', _int, max: 100),
    BalanceField('baseAttributes', 'Atributos base', BalanceFieldType.attributes),
    BalanceField('stunOnAttackChance', 'Aturdir con ataque', _frac, max: 1, step: 0.01),
    BalanceField('pierceWeakness', 'Debilidad a perforantes (×)', _dec, max: 5, step: 0.05),
    BalanceField('statusWeakness', 'Stacks extra recibidos', _int, max: 5),
  ],
  read: (o) {
    final c = o as ClassDef;
    return {
      'baseDefense': c.baseDefense,
      'baseAttributes': encodeAttributes(c.baseAttributes),
      'stunOnAttackChance': c.stunOnAttackChance,
      'pierceWeakness': c.pierceWeakness,
      'statusWeakness': c.statusWeakness,
    };
  },
  write: (o, f) {
    final c = o as ClassDef;
    return ClassDef(
      id: c.id,
      name: c.name,
      description: c.description,
      allowedWeaponTypes: c.allowedWeaponTypes,
      startWeaponId: c.startWeaponId,
      baseDefense: f.i('baseDefense'),
      kitSkillIds: c.kitSkillIds,
      baseAttributes: decodeAttributes(f.values['baseAttributes']),
      stunOnAttackChance: f.d('stunOnAttackChance'),
      pierceWeakness: f.d('pierceWeakness'),
      statusWeakness: f.i('statusWeakness'),
    );
  },
  nameOf: (o) => (o as ClassDef).name,
);

// ---------------------------------------------------------------------
// Afijos, nodos del árbol, mecánicas
// ---------------------------------------------------------------------

final affixCodec = EntityCodec(
  kind: BalanceKind.affix,
  fields: const [
    BalanceField('weight', 'Peso de aparición', _int, max: 100000, step: 50),
    BalanceField('tiers', 'Tiers', BalanceFieldType.tiers),
    BalanceField('disabled', 'Desactivado', _flag),
  ],
  read: (o) {
    final a = o as AffixDef;
    return {'weight': a.weight, 'tiers': encodeTiers(a.tiers), 'disabled': false};
  },
  write: (o, f) {
    final a = o as AffixDef;
    return AffixDef(
      id: a.id,
      name: a.name,
      slot: a.slot,
      stat: a.stat,
      tiers: List.unmodifiable(decodeTiers(f.values['tiers'])),
      weight: f.disabled ? 0 : f.i('weight'),
      types: a.types,
    );
  },
  nameOf: (o) => (o as AffixDef).name,
);

final passiveNodeCodec = EntityCodec(
  kind: BalanceKind.passiveNode,
  fields: const [
    BalanceField('effects', 'Efectos', BalanceFieldType.numberMap),
    BalanceField('disabled', 'Desactivado', _flag),
  ],
  read: (o) {
    final n = o as PassiveNode;
    return {'effects': Map<String, Object?>.from(n.effects), 'disabled': false};
  },
  write: (o, f) {
    final n = o as PassiveNode;
    return PassiveNode(
      id: n.id,
      x: n.x,
      y: n.y,
      name: n.name,
      effects: f.disabled
          ? const {}
          : Map.unmodifiable(decodeNumberMap(f.values['effects'])),
      kind: n.kind,
      links: n.links,
      keystoneId: n.keystoneId,
      pathId: n.pathId,
      mechanicId: n.mechanicId,
    );
  },
  nameOf: (o) => (o as PassiveNode).name,
);

final mechanicCodec = EntityCodec(
  kind: BalanceKind.mechanic,
  fields: const [
    BalanceField('chance', 'Probabilidad', _frac, max: 1, step: 0.01),
    BalanceField('threshold', 'Umbral de vida', _frac, max: 1, step: 0.01),
    BalanceField('minStacks', 'Stacks mínimos', _int, min: 1, max: 20),
    BalanceField('status', 'Estado (filtro)', BalanceFieldType.statusKind, nullable: true),
    BalanceField('effects', 'Efectos', BalanceFieldType.procEffects),
    BalanceField('description', 'Descripción', BalanceFieldType.text),
    _disabled,
  ],
  read: (o) {
    final m = o as PassiveMechanic;
    return {
      'chance': m.chance,
      'threshold': m.threshold,
      'minStacks': m.minStacks,
      'status': m.status?.name,
      'effects': encodeProcEffects(m.effects),
      'description': m.description,
      'disabled': false,
    };
  },
  write: (o, f) {
    final m = o as PassiveMechanic;
    return PassiveMechanic(
      id: m.id,
      name: m.name,
      trigger: m.trigger,
      effects: f.disabled
          ? const []
          : List.unmodifiable(decodeProcEffects(f.values['effects'])),
      description: f.values['description'] as String,
      filter: m.filter,
      chance: f.d('chance'),
      status: decodeStatusKind(f.values['status']),
      minStacks: f.i('minStacks'),
      threshold: f.d('threshold'),
      reaction: m.reaction,
      family: m.family,
    );
  },
  nameOf: (o) => (o as PassiveMechanic).name,
);

// ---------------------------------------------------------------------
// Elementos v0.7: reacciones y estados elementales
// ---------------------------------------------------------------------

final reactionCodec = EntityCodec(
  kind: BalanceKind.reaction,
  fields: const [
    BalanceField('damageMult', 'Multiplicador del golpe', _dec, min: 1, max: 5, step: 0.05),
    BalanceField('perStack', 'Convergencia: vida máx. por stack', _frac, max: 0.5, step: 0.005),
    BalanceField('splash', 'Salpicadura / salto', _frac, max: 2, step: 0.05),
    BalanceField('commonCap', 'Convergencia: tope común (vida máx.)', _frac, max: 1, step: 0.01),
    BalanceField('eliteCap', 'Convergencia: tope élite (vida máx.)', _frac, max: 1, step: 0.01),
    BalanceField('bossCap', 'Convergencia: tope jefe (vida máx.)', _frac, max: 1, step: 0.01),
    BalanceField('stunTurns', 'Turnos de Aturdido', _int, max: 5),
  ],
  read: (o) {
    final r = o as ReactionDef;
    return {
      'damageMult': r.damageMult,
      'perStack': r.perStack,
      'splash': r.splash,
      'commonCap': r.commonCap,
      'eliteCap': r.eliteCap,
      'bossCap': r.bossCap,
      'stunTurns': r.stunTurns,
    };
  },
  write: (o, f) {
    final r = o as ReactionDef;
    return ReactionDef(
      kind: r.kind,
      damageMult: f.d('damageMult'),
      perStack: f.d('perStack'),
      splash: f.d('splash'),
      commonCap: f.d('commonCap'),
      eliteCap: f.d('eliteCap'),
      bossCap: f.d('bossCap'),
      stunTurns: f.i('stunTurns'),
    );
  },
  nameOf: (o) => (o as ReactionDef).name,
);

final elementStatusCodec = EntityCodec(
  kind: BalanceKind.elementStatus,
  fields: const [
    BalanceField('turns', 'Turnos (Congelación: resistencia)', _int, max: 10),
    BalanceField('slowPerStack', '−Velocidad por stack', _frac, max: 0.5, step: 0.01),
    BalanceField('breakPerStack', '+Quiebre por stack', _frac, max: 1, step: 0.01),
    BalanceField('brittleMult', 'Golpe a Quebradizo (×)', _dec, min: 1, max: 5, step: 0.05),
  ],
  read: (o) {
    final e = o as ElementStatusDef;
    return {
      'turns': e.turns,
      'slowPerStack': e.slowPerStack,
      'breakPerStack': e.breakPerStack,
      'brittleMult': e.brittleMult,
    };
  },
  write: (o, f) {
    final e = o as ElementStatusDef;
    return ElementStatusDef(
      kind: e.kind,
      turns: f.i('turns'),
      slowPerStack: f.d('slowPerStack'),
      breakPerStack: f.d('breakPerStack'),
      brittleMult: f.d('brittleMult'),
    );
  },
  nameOf: (o) => (o as ElementStatusDef).name,
);

// ---------------------------------------------------------------------
// Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md)
// ---------------------------------------------------------------------

final abyssBossCodec = EntityCodec(
  kind: BalanceKind.abyssBoss,
  fields: const [
    BalanceField('fragmentCost', 'Fragmentos para abrirlo', _int, min: 1, max: 50),
    BalanceField('enrageTurns', 'Furia: turno propio', _int, min: 5, max: 200),
    BalanceField('enragePower', 'Furia: ATQ ×', _dec, min: 1, max: 5, step: 0.05),
    BalanceField('healHurts', 'Las curas lo dañan (fracción)', _frac, max: 2, step: 0.05),
    BalanceField('aspectResist', 'Daño de su aspecto (×)', _frac, max: 1, step: 0.05),
    BalanceField('legendaryChance', 'Chance del exclusivo (repetido)', _frac, max: 1, step: 0.01),
    BalanceField('essence', 'Esencias seguras', _int, max: 10),
    BalanceField('essenceExtra', 'Chance de 1 Esencia más', _frac, max: 1, step: 0.05),
    BalanceField('atlasPoints', 'Puntos de Atlas (1.ª vez)', _int, max: 10),
  ],
  read: (o) {
    final d = o as AbyssBossDef;
    return {
      'fragmentCost': d.fragmentCost,
      'enrageTurns': d.enrageTurns,
      'enragePower': d.enragePower,
      'healHurts': d.healHurts,
      'aspectResist': d.aspectResist,
      'legendaryChance': d.legendaryChance,
      'essence': d.essence,
      'essenceExtra': d.essenceExtra,
      'atlasPoints': d.atlasPoints,
    };
  },
  write: (o, f) {
    final d = o as AbyssBossDef;
    return AbyssBossDef(
      number: d.number,
      enemyId: d.enemyId,
      name: d.name,
      level: d.level,
      phases: d.phases,
      arenaZone: d.arenaZone,
      legendaryIds: d.legendaryIds,
      fragment: d.fragment,
      matchBoss: d.matchBoss,
      secret: d.secret,
      fragmentCost: f.i('fragmentCost'),
      enrageTurns: f.i('enrageTurns'),
      enragePower: f.d('enragePower'),
      healHurts: f.d('healHurts'),
      aspectResist: f.d('aspectResist'),
      legendaryChance: f.d('legendaryChance'),
      essence: f.i('essence'),
      essenceExtra: f.d('essenceExtra'),
      atlasPoints: f.i('atlasPoints'),
    );
  },
  nameOf: (o) => (o as AbyssBossDef).name,
);

final fragmentDropCodec = EntityCodec(
  kind: BalanceKind.fragmentDrop,
  fields: const [
    BalanceField('minTier', 'Tier mínimo del Eco', _int, min: 1, max: 16),
    BalanceField('battle', 'Chance en batalla', _frac, max: 1, step: 0.005),
    BalanceField('chest', 'Chance en cofre', _frac, max: 1, step: 0.005),
    BalanceField('elite', 'Chance en élite', _frac, max: 1, step: 0.005),
    BalanceField('boss', 'Chance en jefe', _frac, max: 1, step: 0.01),
    BalanceField('mission', 'Chance al completar el Eco', _frac, max: 1, step: 0.01),
    BalanceField('perTier', '+ por tier sobre el mínimo', _frac, max: 1, step: 0.01),
    BalanceField('perRarity', '+ por rareza del Eco', _frac, max: 1, step: 0.01),
    BalanceField('perMod', '+ por mod del Eco', _frac, max: 1, step: 0.01),
    BalanceField('matchChance', 'Jefe que coincide: chance ×', _dec, min: 1, max: 5, step: 0.05),
    BalanceField('matchWeight', 'Jefe que coincide: peso ×', _dec, min: 1, max: 20, step: 0.5),
    BalanceField('cap', 'Tope de la chance', _frac, max: 1, step: 0.01),
  ],
  read: (o) {
    final d = o as FragmentDropDef;
    return {
      'minTier': d.minTier,
      'battle': d.battle,
      'chest': d.chest,
      'elite': d.elite,
      'boss': d.boss,
      'mission': d.mission,
      'perTier': d.perTier,
      'perRarity': d.perRarity,
      'perMod': d.perMod,
      'matchChance': d.matchChance,
      'matchWeight': d.matchWeight,
      'cap': d.cap,
    };
  },
  write: (o, f) => FragmentDropDef(
    minTier: f.i('minTier'),
    battle: f.d('battle'),
    chest: f.d('chest'),
    elite: f.d('elite'),
    boss: f.d('boss'),
    mission: f.d('mission'),
    perTier: f.d('perTier'),
    perRarity: f.d('perRarity'),
    perMod: f.d('perMod'),
    matchChance: f.d('matchChance'),
    matchWeight: f.d('matchWeight'),
    cap: f.d('cap'),
  ),
  nameOf: (o) => (o as FragmentDropDef).name,
);

final hitCapCodec = EntityCodec(
  kind: BalanceKind.hitCap,
  fields: const [
    BalanceField('common', 'Común: tope (vida máx.)', _frac, min: 0.05, max: 1, step: 0.01),
    BalanceField('commonC', 'Común en zona C: tope (vida máx.)', _frac, min: 0.05, max: 1, step: 0.01),
    BalanceField('eliteSolo', 'Élite solo: tope (vida máx.)', _frac, min: 0.05, max: 1, step: 0.01),
    BalanceField('elite', 'Élite a 4: tope (vida máx.)', _frac, min: 0.05, max: 1, step: 0.01),
    BalanceField('bossSolo', 'Jefe solo: tope (vida máx.)', _frac, min: 0.05, max: 1, step: 0.01),
    BalanceField('boss', 'Jefe a 4: tope (vida máx.)', _frac, min: 0.05, max: 1, step: 0.01),
    BalanceField('overLevel', 'Sin tope desde (niveles de más)', _int, min: 1, max: 50),
  ],
  read: (o) {
    final h = o as HitCapDef;
    return {
      'common': h.common,
      'commonC': h.commonC,
      'eliteSolo': h.eliteSolo,
      'elite': h.elite,
      'bossSolo': h.bossSolo,
      'boss': h.boss,
      'overLevel': h.overLevel,
    };
  },
  write: (o, f) => HitCapDef(
    common: f.d('common'),
    commonC: f.d('commonC'),
    eliteSolo: f.d('eliteSolo'),
    elite: f.d('elite'),
    bossSolo: f.d('bossSolo'),
    boss: f.d('boss'),
    overLevel: f.i('overLevel'),
  ),
  nameOf: (o) => (o as HitCapDef).name,
);

final comboCodec = EntityCodec(
  kind: BalanceKind.combo,
  fields: const [
    BalanceField('weakMult', 'Convergencia: débil al detonador (×)', _dec, min: 1, max: 3, step: 0.05),
    BalanceField('resistMult', 'Convergencia: resiste el detonador (×)', _frac, max: 1, step: 0.05),
    BalanceField('ultBonus', 'Carga de ULT si detona otro', _dec, max: 50, step: 1),
    BalanceField('stackCap', 'Tope de stacks (Quemadura, Veneno)', _int, min: 1, max: 200),
    BalanceField('areaMult', 'Área: daño por blanco (×)', _frac, min: 0.1, max: 1, step: 0.05),
    BalanceField('breakAttack', 'Quiebre: ataque básico', _dec, max: 50, step: 1),
    BalanceField('breakPhysical', 'Quiebre: habilidad física', _dec, max: 50, step: 1),
    BalanceField('breakMagical', 'Quiebre: habilidad mágica', _dec, max: 50, step: 1),
    BalanceField('breakUltimate', 'Quiebre: ULT', _dec, max: 100, step: 1),
    BalanceField('breakDual', 'Quiebre: dúo', _dec, max: 100, step: 1),
    BalanceField('breakQuebrar', 'Quiebre: habilidad base Quebrar', _dec, max: 50, step: 1),
    BalanceField('breakWeak', 'Quiebre: + a una debilidad', _frac, max: 3, step: 0.05),
    BalanceField('breakStatus', 'Quiebre: Aturdido o Congelación', _dec, max: 50, step: 1),
    BalanceField('breakReaction', 'Quiebre: reacción o Convergencia', _dec, max: 50, step: 1),
    BalanceField('heavyBreak', 'Quiebre: + armas pesadas', _frac, max: 2, step: 0.05),
    BalanceField('eliteBreak', 'Umbral del élite (×)', _dec, min: 1, max: 10, step: 0.1),
    BalanceField('groupBreakBase', 'Umbral: base del grupo', _dec, max: 3, step: 0.05),
    BalanceField('groupBreakPer', 'Umbral: + por jugador', _dec, max: 3, step: 0.05),
    BalanceField('steadyGauge', 'Fisurado que no se quiebra: barra a', _frac, max: 1, step: 0.05),
  ],
  read: (o) {
    final c = o as ComboRulesDef;
    return {
      'weakMult': c.weakMult,
      'resistMult': c.resistMult,
      'ultBonus': c.ultBonus,
      'stackCap': c.stackCap,
      'areaMult': c.areaMult,
      'breakAttack': c.breakAttack,
      'breakPhysical': c.breakPhysical,
      'breakMagical': c.breakMagical,
      'breakUltimate': c.breakUltimate,
      'breakDual': c.breakDual,
      'breakQuebrar': c.breakQuebrar,
      'breakWeak': c.breakWeak,
      'breakStatus': c.breakStatus,
      'breakReaction': c.breakReaction,
      'heavyBreak': c.heavyBreak,
      'eliteBreak': c.eliteBreak,
      'groupBreakBase': c.groupBreakBase,
      'groupBreakPer': c.groupBreakPer,
      'steadyGauge': c.steadyGauge,
    };
  },
  write: (o, f) => ComboRulesDef(
    weakMult: f.d('weakMult'),
    resistMult: f.d('resistMult'),
    ultBonus: f.d('ultBonus'),
    stackCap: f.i('stackCap'),
    areaMult: f.d('areaMult'),
    breakAttack: f.d('breakAttack'),
    breakPhysical: f.d('breakPhysical'),
    breakMagical: f.d('breakMagical'),
    breakUltimate: f.d('breakUltimate'),
    breakDual: f.d('breakDual'),
    breakQuebrar: f.d('breakQuebrar'),
    breakWeak: f.d('breakWeak'),
    breakStatus: f.d('breakStatus'),
    breakReaction: f.d('breakReaction'),
    heavyBreak: f.d('heavyBreak'),
    eliteBreak: f.d('eliteBreak'),
    groupBreakBase: f.d('groupBreakBase'),
    groupBreakPer: f.d('groupBreakPer'),
    steadyGauge: f.d('steadyGauge'),
  ),
  nameOf: (o) => (o as ComboRulesDef).name,
);

final curveCodec = EntityCodec(
  kind: BalanceKind.curve,
  fields: const [
    BalanceField('tramoSize', 'Niveles por tramo', _int, min: 1, max: 50),
    BalanceField('aEnd', 'Fin de A (posición en el tramo)', _int, min: 0, max: 50),
    BalanceField('bEnd', 'Fin de B (posición en el tramo)', _int, min: 0, max: 50),
    BalanceField('hpSlopeAB', 'Vida: + por nivel en A y B', _frac, max: 2, step: 0.01),
    BalanceField('hpSlopeC', 'Vida: + por nivel en C', _frac, max: 2, step: 0.01),
    BalanceField('atkSlope', 'ATQ: + por nivel', _frac, max: 2, step: 0.01),
    BalanceField('commonAtkC', 'Comunes en C: + ATQ', _frac, max: 2, step: 0.01),
    BalanceField('eliteEveryC', 'Zonas C: 1 élite cada N grupos', _int, min: 1, max: 20),
    BalanceField('groupHpBase', 'Vida en grupo: base', _dec, max: 3, step: 0.05),
    BalanceField('groupHpPer', 'Vida en grupo: + por jugador', _dec, max: 3, step: 0.05),
    BalanceField('groupMitigation', 'Mitigación: − por jugador extra', _frac, max: 0.3, step: 0.01),
    BalanceField('zoneCMitigation', 'Mitigación: − en zonas C', _frac, max: 0.5, step: 0.01),
    BalanceField('soloBossHp', 'Jefe en solitario: vida (×)', _dec, min: 0.1, max: 3, step: 0.05),
    BalanceField('soloBossAtk', 'Jefe en solitario: ATQ (×)', _dec, min: 0.1, max: 3, step: 0.05),
    BalanceField('soloEscorts', 'Jefe en solitario: escolta (máx.)', _int, max: 10),
    BalanceField('groupAtkPer', 'ATQ enemigo: + por jugador extra', _frac, max: 1, step: 0.01),
    BalanceField('groupAtkMax', 'ATQ enemigo en grupo: tope (×)', _dec, min: 1, max: 6, step: 0.05),
    BalanceField('groupHpMax', 'Vida en grupo: tope (×)', _dec, min: 1, max: 10, step: 0.05),
    BalanceField('groupMitigationMax', 'Mitigación de grupo: tope', _frac, max: 0.9, step: 0.01),
    BalanceField('delayFalloff', 'Retraso sucesivo: rinde (×)', _frac, max: 1, step: 0.05),
    BalanceField('groupInitiativeC', 'Zona C en grupo: primer turno enemigo (×)', _frac, min: 0.05, max: 1, step: 0.05),
  ],
  read: (o) {
    final c = o as CurveDef;
    return {
      'tramoSize': c.tramoSize,
      'aEnd': c.aEnd,
      'bEnd': c.bEnd,
      'hpSlopeAB': c.hpSlopeAB,
      'hpSlopeC': c.hpSlopeC,
      'atkSlope': c.atkSlope,
      'commonAtkC': c.commonAtkC,
      'eliteEveryC': c.eliteEveryC,
      'groupHpBase': c.groupHpBase,
      'groupHpPer': c.groupHpPer,
      'groupMitigation': c.groupMitigation,
      'zoneCMitigation': c.zoneCMitigation,
      'soloBossHp': c.soloBossHp,
      'soloBossAtk': c.soloBossAtk,
      'soloEscorts': c.soloEscorts,
      'groupAtkPer': c.groupAtkPer,
      'groupAtkMax': c.groupAtkMax,
      'groupMitigationMax': c.groupMitigationMax,
      'groupHpMax': c.groupHpMax,
      'delayFalloff': c.delayFalloff,
      'groupInitiativeC': c.groupInitiativeC,
    };
  },
  write: (o, f) => CurveDef(
    tramoSize: f.i('tramoSize'),
    aEnd: f.i('aEnd'),
    bEnd: f.i('bEnd'),
    hpSlopeAB: f.d('hpSlopeAB'),
    hpSlopeC: f.d('hpSlopeC'),
    atkSlope: f.d('atkSlope'),
    commonAtkC: f.d('commonAtkC'),
    eliteEveryC: f.i('eliteEveryC'),
    groupHpBase: f.d('groupHpBase'),
    groupHpPer: f.d('groupHpPer'),
    groupMitigation: f.d('groupMitigation'),
    zoneCMitigation: f.d('zoneCMitigation'),
    soloBossHp: f.d('soloBossHp'),
    soloBossAtk: f.d('soloBossAtk'),
    soloEscorts: f.i('soloEscorts'),
    groupAtkPer: f.d('groupAtkPer'),
    groupAtkMax: f.d('groupAtkMax'),
    groupMitigationMax: f.d('groupMitigationMax'),
    groupHpMax: f.d('groupHpMax'),
    delayFalloff: f.d('delayFalloff'),
    groupInitiativeC: f.d('groupInitiativeC'),
  ),
  nameOf: (o) => (o as CurveDef).name,
);

// ---------------------------------------------------------------------
// Ajustes (tuning_catalog.dart) y hazañas
// ---------------------------------------------------------------------

EntityCodec _tuningCodec(BalanceKind kind, List<BalanceField> fields) =>
    EntityCodec(
      kind: kind,
      fields: fields,
      read: (o) => {...(o as TuningDef).values},
      write: (o, f) {
        final t = o as TuningDef;
        return TuningDef(t.name, {
          for (final k in t.values.keys) k: f.values[k] as num,
        });
      },
      nameOf: (o) => (o as TuningDef).name,
    );

final ultLevelCodec = _tuningCodec(BalanceKind.ultLevel, const [
  BalanceField('perLevel', 'Poder extra por nivel sobre el 1', _frac, max: 0.5, step: 0.01),
]);

final ultUpgradeCodec = _tuningCodec(BalanceKind.ultUpgrade, const [
  BalanceField('credits', 'Créditos × nivel', _int, max: 100000, step: 100),
  BalanceField('cristal', 'Cristales de Era × nivel', _int, max: 20),
  BalanceField('prismaFrom', 'Prismas desde el nivel (1 + uno por nivel)', _int, min: 1, max: 6),
  BalanceField('fragFrom', 'Fragmento de jefe desde el nivel', _int, min: 1, max: 6),
]);

final ultChargeCodec = _tuningCodec(BalanceKind.ultCharge, const [
  BalanceField('takenFactor', 'Carga por recibir el 100% de la vida', _dec, max: 500, step: 5),
  BalanceField('dealtBase', 'Carga base por hacer daño', _dec, max: 50, step: 0.5),
  BalanceField('dealtScale', 'Carga por daño (× fracción de la vida del objetivo)', _dec, max: 200, step: 1),
  BalanceField('dealtCap', 'Tope de carga por hacer daño', _dec, max: 100, step: 1),
  BalanceField('enemyPerTurn', 'Enemigos: carga por turno', _dec, max: 100, step: 1),
  BalanceField('enemyPerHp', 'Enemigos: carga por perder el 100% de la vida', _dec, max: 500, step: 5),
]);

final condenseCodec = _tuningCodec(BalanceKind.condense, const [
  BalanceField('cristalCost', 'Cristal: Esquirlas que gasta', _int, min: 1, max: 99),
  BalanceField('cristalCredits', 'Cristal: créditos', _int, max: 100000, step: 50),
  BalanceField('prismaCost', 'Prisma: Cristales que gasta', _int, min: 1, max: 99),
  BalanceField('prismaCredits', 'Prisma: créditos', _int, max: 100000, step: 50),
]);

final materialsCodec = _tuningCodec(BalanceKind.materials, const [
  BalanceField('chanceEsquirla', 'Drop: Esquirla (prob. base)', _frac, max: 1, step: 0.005),
  BalanceField('chanceCristal', 'Drop: Cristal (prob. base)', _frac, max: 1, step: 0.005),
  BalanceField('chancePrisma', 'Drop: Prisma (prob. base)', _frac, max: 1, step: 0.001),
  BalanceField('multBattle', 'Drop: × en batalla', _dec, max: 20, step: 0.5),
  BalanceField('multChest', 'Drop: × en cofre', _dec, max: 20, step: 0.5),
  BalanceField('multMission', 'Drop: × en misión', _dec, max: 20, step: 0.5),
  BalanceField('multElite', 'Drop: × de élite', _dec, max: 20, step: 0.5),
  BalanceField('multBoss', 'Drop: × de jefe', _dec, max: 20, step: 0.5),
  BalanceField('weightComun', 'Rareza: peso Común', _dec, max: 1000, step: 1),
  BalanceField('weightMagico', 'Rareza: peso Mágico', _dec, max: 1000, step: 1),
  BalanceField('weightRaro', 'Rareza: peso Raro', _dec, max: 1000, step: 0.5),
  BalanceField('weightEpico', 'Rareza: peso Épico (Ecos)', _dec, max: 1000, step: 0.1),
  BalanceField('weightLegendario', 'Rareza: peso Legendario', _dec, max: 1000, step: 0.1),
  BalanceField('zoneEpicWeight', 'Rareza: peso Épico fuera de Ecos', _dec, max: 1000, step: 0.1),
  BalanceField('salvageHighLevel', 'Desarme: +1 material desde nivel', _int, min: 1, max: 100),
  BalanceField('upComunPrismas', 'Subir Común: Prismas', _int, max: 99),
  BalanceField('upComunCredits', 'Subir Común: créditos', _int, max: 100000, step: 50),
  BalanceField('upMagicoPrismas', 'Subir Mágico: Prismas', _int, max: 99),
  BalanceField('upMagicoCredits', 'Subir Mágico: créditos', _int, max: 100000, step: 50),
  BalanceField('upRaroPrismas', 'Subir Raro: Prismas', _int, max: 99),
  BalanceField('upRaroCredits', 'Subir Raro: créditos', _int, max: 100000, step: 50),
  BalanceField('transferCredits', 'Trasladar habilidad: créditos × rareza', _int, max: 100000, step: 10),
  BalanceField('transferCristales', 'Trasladar a Raro+: Cristales', _int, max: 99),
  BalanceField('addAffixCredits', 'Agregar afijo: créditos × rareza', _int, max: 100000, step: 5),
  BalanceField('rerollCredits', 'Retirar afijo: créditos × rareza', _int, max: 100000, step: 5),
]);

final ecoTierCodec = _tuningCodec(BalanceKind.ecoTier, const [
  BalanceField('tierQuantity', 'Cantidad extra por tier sobre T1', _frac, max: 1, step: 0.005),
  BalanceField('partyQuantity', 'Cantidad extra por jugador extra', _frac, max: 1, step: 0.01),
]);

final featRewardCodec = EntityCodec(
  kind: BalanceKind.featReward,
  fields: const [
    BalanceField('credits', 'Créditos', _int, max: 1000000, step: 100),
    BalanceField('esquirlas', 'Esquirlas del Eco', _int, max: 999),
    BalanceField('cristales', 'Cristales de Era', _int, max: 999),
    BalanceField('prismas', 'Prismas Rotos', _int, max: 999),
    BalanceField('potions', 'Pociones de vida', _int, max: 99),
    BalanceField('ethers', 'Pociones de maná', _int, max: 99),
  ],
  read: (o) {
    final r = (o as AchievementDef).baseReward;
    return {
      'credits': r.credits,
      'esquirlas': r.esquirlas,
      'cristales': r.cristales,
      'prismas': r.prismas,
      'potions': r.potions,
      'ethers': r.ethers,
    };
  },
  // Devuelve la recompensa (lo que instala el registro), no la hazaña.
  write: (o, f) => AchievementReward(
    credits: f.i('credits'),
    esquirlas: f.i('esquirlas'),
    cristales: f.i('cristales'),
    prismas: f.i('prismas'),
    potions: f.i('potions'),
    ethers: f.i('ethers'),
    ult: (o as AchievementDef).baseReward.ult,
  ),
  nameOf: (o) => (o as AchievementDef).name,
);

/// El codec de cada tipo.
EntityCodec codecOf(BalanceKind k) => switch (k) {
      BalanceKind.abyssBoss => abyssBossCodec,
      BalanceKind.fragmentDrop => fragmentDropCodec,
      BalanceKind.hitCap => hitCapCodec,
      BalanceKind.combo => comboCodec,
      BalanceKind.curve => curveCodec,
      BalanceKind.skill => skillCodec,
      BalanceKind.ultimate => ultimateCodec,
      BalanceKind.dual => dualCodec,
      BalanceKind.weapon => weaponCodec,
      BalanceKind.enemy => enemyCodec,
      BalanceKind.enemyUlt => enemyUltCodec,
      BalanceKind.classDef => classCodec,
      BalanceKind.affix => affixCodec,
      BalanceKind.passiveNode => passiveNodeCodec,
      BalanceKind.mechanic => mechanicCodec,
      BalanceKind.reaction => reactionCodec,
      BalanceKind.elementStatus => elementStatusCodec,
      BalanceKind.ultLevel => ultLevelCodec,
      BalanceKind.ultUpgrade => ultUpgradeCodec,
      BalanceKind.ultCharge => ultChargeCodec,
      BalanceKind.condense => condenseCodec,
      BalanceKind.materials => materialsCodec,
      BalanceKind.ecoTier => ecoTierCodec,
      BalanceKind.featReward => featRewardCodec,
    };

/// Tipos de "Ajustes": un grupo de [kTuning] cada uno (id = jsonKey).
const kTuningKinds = [
  BalanceKind.ultLevel,
  BalanceKind.ultUpgrade,
  BalanceKind.ultCharge,
  BalanceKind.condense,
  BalanceKind.materials,
  BalanceKind.ecoTier,
];
