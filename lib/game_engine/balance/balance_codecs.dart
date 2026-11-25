import '../data/life_tree_catalog.dart' show kLifeTrees;
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
  featReward('featReward', 'Hazañas', 'Hazaña'),

  /// Precios de consumibles, Éter en cofres (loot.md § 17.6) y sinergia
  /// de revivir con el árbol (combat.md § "Revivir y el árbol").
  consumables('consumables', 'Apoyo', 'Consumibles y revivir'),

  /// Mejoras directas, progreso entre runs y dificultad de la Travesía
  /// (roguelike.md § 4 y § 8). El Mundo no lo lee.
  travesia('travesia', 'Travesía', 'Ajustes de la Travesía'),

  /// Efectos encadenados, tope por golpe de jefes y élites, "aguanta una
  /// ronda" y velocidad (combat.md § "Límites").
  combatLimits('combatLimits', 'Combate: límites', 'Límites de combate'),
  /// Movimiento en el mapa de campo (world.md § "Colisión y movimiento").
  exploration('exploration', 'Exploración', 'Ajustes de exploración'),

  /// Cultivo, huerta y agropecuario (farming.md, v0.23.0).
  farming('farming', 'Cultivo', 'Ajustes de Cultivo'),

  /// Ampliaciones, lago y ayudante (farming.md § 6–8).
  town('town', 'Pueblo', 'Ajustes del pueblo'),

  /// Pesca y pedido del día del pescador nativo (fishing.md, § 12).
  fishing('fishing', 'Pesca', 'Ajustes de Pesca'),

  /// Puntos y valor de los nodos de oficios (life_skill_trees.md).
  lifeTree('lifeTree', 'Oficios: árboles', 'Árboles de oficios'),

  /// Minas, vetas, fundir y forjar armas (mining_smithing.md).
  smithing('smithing', 'Minería y herrería', 'Ajustes de minería y herrería'),

  /// Generated biome regions and region foraging (biome_regions.md).
  regions('regions', 'Regiones de bioma', 'Ajustes de regiones de bioma');

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
    BalanceField('dropWeight', 'Peso al salir de loot', _dec, max: 10, step: 0.05),
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
      'dropWeight': w.dropWeight,
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
      dropWeight: f.d('dropWeight'),
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
      dropWeight: w.dropWeight,
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
    BalanceField('tank', 'Tanque (defiende y alza escudo elemental)', _flag),
    BalanceField('silencer', 'Silenciador (lanza Silencio al jugador de más poder de habilidad)', _flag),
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
      'tank': e.tank,
      'silencer': e.silencer,
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
      tank: f.b('tank'),
      silencer: f.b('silencer'),
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
    BalanceField('duoStunBonus', 'Aturdir extra con aliado', _frac, max: 1, step: 0.01),
    BalanceField('pierceWeakness', 'Debilidad a perforantes (×)', _dec, max: 5, step: 0.05),
    BalanceField('statusWeakness', 'Stacks extra recibidos', _int, max: 5),
  ],
  read: (o) {
    final c = o as ClassDef;
    return {
      'baseDefense': c.baseDefense,
      'baseAttributes': encodeAttributes(c.baseAttributes),
      'stunOnAttackChance': c.stunOnAttackChance,
      'duoStunBonus': c.duoStunBonus,
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
      duoStunBonus: f.d('duoStunBonus'),
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
    BalanceField('healFoeMult', 'Cura lanzada a un no muerto (×)', _dec, max: 5, step: 0.05),
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
      'healFoeMult': c.healFoeMult,
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
    healFoeMult: f.d('healFoeMult'),
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
  BalanceField('fragFrom', 'Fragmento del Abismo desde el nivel', _int, min: 1, max: 6),
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

final consumablesCodec = _tuningCodec(BalanceKind.consumables, const [
  BalanceField('potionPrice', 'Precio de la Poción de vida', _int, min: 1, max: 100000, step: 5),
  BalanceField('etherPrice', 'Precio de la Poción de maná', _int, min: 1, max: 100000, step: 5),
  BalanceField('aetherMult', 'Éter: precio × Poción de vida', _dec, min: 1, max: 50, step: 0.5),
  BalanceField('aetherChestChance', 'Éter: chance en el consumible de un cofre', _frac, max: 1, step: 0.01),
  BalanceField('espPer', 'Vida extra al revivir por punto de ESP', _frac, max: 0.05, step: 0.0005),
  BalanceField('healScale', 'Vida extra al revivir × Curación del árbol', _dec, max: 5, step: 0.05),
  BalanceField('shieldScale', 'Escudo al revivido × Curación del árbol', _dec, max: 5, step: 0.05),
  BalanceField('shieldCap', 'Tope del escudo (fracción de su vida)', _frac, max: 1, step: 0.01),
  BalanceField('shieldTurns', 'Turnos del escudo', _int, min: 1, max: 9),
]);

final explorationCodec = _tuningCodec(BalanceKind.exploration, const [
  BalanceField('playerSpeed', 'Velocidad del personaje en el mapa (px/s)', _dec, min: 20, max: 300, step: 1),
  BalanceField('departureSec', 'Cinemática de partida del pueblo (s)', _dec, max: 4, step: 0.5),
]);

final travesiaCodec = _tuningCodec(BalanceKind.travesia, const [
  BalanceField('boonSpell', 'Mejora: % daño de hechizos', _int, max: 200),
  BalanceField('boonAttack', 'Mejora: % ataque básico y físico', _int, max: 200),
  BalanceField('boonHeal', 'Mejora: % curación', _int, max: 200),
  BalanceField('boonCrit', 'Mejora: % crítico', _int, max: 100),
  BalanceField('boonUlt', 'Mejora: % carga de ULT', _int, max: 200),
  BalanceField('boonElite', 'Mejora: % daño contra élites y jefes', _int, max: 200),
  BalanceField('boonPulse', 'Mejora: Pulso al empezar la pelea', _int, max: 5),
  BalanceField('boonDefense', 'Mejora: DEF', _int, max: 100),
  BalanceField('boonSteal', 'Mejora: % robo de vida', _int, max: 100),
  BalanceField('boonsInExtra', 'Mejoras en el sorteo de la fila Extra', _int, max: 5),
  BalanceField('coinPerFloor', 'Moneda por piso alcanzado', _int, max: 1000),
  BalanceField('coinElite', 'Moneda por élite vencida', _int, max: 1000),
  BalanceField('coinBoss', 'Moneda por jefe vencido', _int, max: 1000),
  BalanceField('coinWin', 'Moneda por ganar la Travesía', _int, max: 1000),
  BalanceField('zonesStart', 'Zonas en el sorteo al empezar', _int, min: 1, max: 20),
  BalanceField('zoneUnlockFloor', 'Piso a alcanzar para sumar una zona', _int, min: 1, max: 3),
  BalanceField('eliteRepeatLevel', 'Élite repetida: niveles extra por victoria', _int, max: 10),
  BalanceField('diffAtk', 'Dificultad: + ATQ enemigo por nivel', _frac, max: 1, step: 0.01),
  BalanceField('diffHp', 'Dificultad: + vida enemiga por nivel', _frac, max: 1, step: 0.01),
  BalanceField('diffMax', 'Dificultad: niveles', _int, max: 20),
  BalanceField('enemyHp', 'Vida enemiga (×, antes de la dificultad)', _dec, min: 0.1, max: 5, step: 0.05),
  BalanceField('enemyAtk', 'ATQ enemigo (×, antes de la dificultad)', _dec, min: 0.1, max: 5, step: 0.05),
  BalanceField('levelPerFloor', 'Nivel enemigo: + por piso', _int, max: 20),
  BalanceField('levelPerLayer', 'Nivel enemigo: + por capa', _frac, max: 2, step: 0.05),
  BalanceField('ultChanceCombate', 'ULT en la recompensa: combate', _frac, max: 1, step: 0.01),
  BalanceField('ultChanceElite', 'ULT en la recompensa: élite', _frac, max: 1, step: 0.01),
  BalanceField('ultChanceJefe', 'ULT en la recompensa: jefe', _frac, max: 1, step: 0.01),
  BalanceField('shopUlts', 'ULT a la venta por tienda', _int, max: 6),
  BalanceField('ultPrice', 'Precio de una ULT en la tienda', _int, min: 1, max: 5000),
  BalanceField('maxSkills', 'Máximo de habilidades (con ATACAR y DEFENDER)', _int, min: 2, max: 12),
  BalanceField('skillsInExtra', 'Habilidades nuevas en la fila Extra', _int, max: 3),
  BalanceField('skillUpCost', 'Mejora de habilidad: oro × nivel', _int, min: 1, max: 2000),
  BalanceField('skillUpPower', 'Mejora de habilidad: + poder por nivel', _frac, max: 2, step: 0.01),
  BalanceField('skillUpMax', 'Mejora de habilidad: nivel máximo', _int, max: 10),
  BalanceField('attrReward', 'Recompensa de atributo: puntos', _int, min: 1, max: 30),
  BalanceField('weaponLevelAhead', 'Armas ofrecidas: niveles sobre los enemigos', _int, max: 20),
]);

final combatLimitsCodec = _tuningCodec(BalanceKind.combatLimits, const [
  BalanceField('procMax', 'Efectos encadenados: máximo por acción', _int, min: 1, max: 200),
  BalanceField('procDepth', 'Efectos encadenados: profundidad máxima', _int, min: 1, max: 20),
  BalanceField('capBoss', 'Tope por golpe: jefe (fracción de vida, 0 = sin tope)', _frac, max: 1, step: 0.01),
  BalanceField('capElite', 'Tope por golpe: élite (fracción de vida, 0 = sin tope)', _frac, max: 1, step: 0.01),
  BalanceField('capCommon', 'Tope por golpe: común (fracción de vida, 0 = sin tope)', _frac, max: 1, step: 0.01),
  BalanceField('holdCoop', 'Aguanta una ronda en cooperativo (1 = sí)', _int, max: 1),
  BalanceField('holdSolo', 'Aguanta una ronda en solitario (1 = sí)', _int, max: 1),
  BalanceField('phaseHold', 'Nadie solo lo mata en una fase desde (fracción de vida, 0 = no)', _frac, max: 1, step: 0.05),
  BalanceField('wardMult', 'Escudo elemental del tanque (× daño del elemento)', _frac, max: 1, step: 0.05),
  BalanceField('wardTurns', 'Turnos del escudo elemental del tanque', _int, max: 9),
  BalanceField('tankGuard', 'Defensa del tanque (× daño recibido)', _frac, max: 1, step: 0.05),
  BalanceField('silenceTurns', 'Silencio: turnos propios del jugador silenciado', _int, max: 9),
  BalanceField('silenceEvery', 'Silencio: el silenciador lo repite cada N acciones (0 = solo al abrir)', _int, max: 20),
  BalanceField('silenceCooldown', 'Silencio: turnos propios sin poder ser silenciado de nuevo al terminar', _int, max: 9),
  BalanceField('silenceUlt', 'Silencio también bloquea la ULT (1 = sí)', _int, max: 1),
  BalanceField('pBreakOn', 'Quiebre de jugadores activo (1 = sí)', _int, max: 1),
  BalanceField('pBreakMax', 'Quiebre de jugador: umbral de la barra', _dec, min: 1, max: 1000, step: 5),
  BalanceField('pBreakHit', 'Quiebre de jugador: puntos por golpe enemigo', _dec, max: 200, step: 1),
  BalanceField('pBreakHp', 'Quiebre de jugador: puntos por % de vida perdida', _dec, max: 10, step: 0.05),
  BalanceField('pBreakDecay', 'Quiebre de jugador: baja al empezar su turno (fracción del umbral)', _frac, max: 1, step: 0.05),
  BalanceField('pBrokenTurns', 'Quiebre de jugador: turnos propios vulnerable', _int, min: 1, max: 9),
  BalanceField('pBrokenMult', 'Quiebre de jugador: × daño recibido quebrado', _dec, min: 1, max: 3, step: 0.05),
  BalanceField('eConvOn', 'Convergencias enemigas activas (1 = sí)', _int, max: 1),
  BalanceField('eConvCapPlayer', 'Convergencia contra jugador: tope (fracción de vida)', _frac, max: 1, step: 0.01),
  BalanceField('eComboFocus', 'Combo enemigo: chance de ir al jugador preparado', _frac, max: 1, step: 0.05),
  BalanceField('eComboMinStacks', 'Combo enemigo: stacks para detonar', _int, min: 1, max: 30),
  BalanceField('eSoloChance', 'Enemigo solo (con ambos elementos): chance de buscar el combo', _frac, max: 1, step: 0.05),
  BalanceField('eSoloMinStacks', 'Enemigo solo: stacks para detonar', _int, min: 1, max: 30),
  BalanceField('turnsPerSlowest', 'Turnos máx. por turno del aliado más lento (0 = sin tope)', _dec, max: 10, step: 0.5),
  BalanceField('speedSoftCap', 'Velocidad: umbral de rendimiento decreciente', _dec, min: 1, max: 100, step: 1),
  BalanceField('speedSoftFactor', 'Velocidad: rinde × sobre el umbral', _frac, max: 1, step: 0.05),
  BalanceField('ultBonusAction', 'ULT extra (árbol, mods, efectos): tope por acción', _dec, max: 100, step: 1),
  BalanceField('ultBonusTurn', 'ULT extra (árbol, mods, efectos): tope por turno', _dec, max: 100, step: 1),
  BalanceField('modeCoop', 'Modo de combate por defecto, cooperativo (0 línea de tiempo, 1 rondas, 2 fases)', _int, max: 2),
  BalanceField('modeSolo', 'Modo de combate por defecto, solitario (0 línea de tiempo, 1 rondas, 2 fases)', _int, max: 2),
  BalanceField('planPause', 'Por fases: pausa de planificación (s)', _dec, max: 10, step: 0.5),
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
  BalanceField('restoreQuebrarCredits', 'Restaurar Quebrar: créditos × rareza', _int, max: 100000, step: 10),
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

/// Campos de un grupo de ajustes armados desde sus valores por defecto
/// (v0.23.0): entero si el valor lo es, decimal si no; la etiqueta sale
/// de [labels] (o de la clave).
List<BalanceField> _autoFields(String id, Map<String, String> labels) {
  final out = <BalanceField>[];
  for (final e in kTuningDefaults[id]!.values.entries) {
    final v = e.value;
    final label = labels[e.key] ?? e.key;
    if (v is int) {
      final max = v <= 0 ? 100.0 : (v * 10).toDouble().clamp(10.0, 1e7);
      out.add(BalanceField(e.key, label, _int,
          max: max, step: v >= 1000 ? 50 : 1));
    } else {
      final d = v.toDouble();
      out.add(BalanceField(e.key, label, _dec,
          max: (d * 10).clamp(1.0, 1e6), step: 0.01));
    }
  }
  return out;
}

const _farmLabels = {
  'maxLevel': 'Nivel máximo',
  'xpBase': 'XP base por nivel',
  'xpExp': 'Exponente de XP',
  'xpComun': 'XP × común',
  'xpRaro': 'XP × rara',
  'xpEpico': 'XP × épica',
  'xpLegendario': 'XP × legendaria',
  'charXpComun': 'XP de personaje: común',
  'charXpRaro': 'XP de personaje: rara',
  'charXpEpico': 'XP de personaje: épica',
  'charXpLegendario': 'XP de personaje: legendaria',
  'charXpCap': 'Tope de XP de personaje por estadía',
  'bonusFloor': 'Herramienta: piso de efectividad',
  'bonusCurve': 'Herramienta: curva de efectividad',
  'dryRate': 'Crecimiento sin regar (×)',
  'waterSec': 'Segundos que dura un riego',
  'waterRateMin': 'Ritmo de riego con nivel 1 (×)',
  'missionGrowSec': 'Segundos que suma cada misión ganada',
  'workXp': 'XP por arar, plantar o regar',
  'wQNormal': 'Peso calidad normal',
  'wQRaro': 'Peso calidad rara',
  'wQEpico': 'Peso calidad épica',
  'wQLegendario': 'Peso calidad legendaria',
  'sPlant': 'Peso de quien planta',
  'sWater': 'Peso de los riegos',
  'sHarvest': 'Peso de quien cosecha',
  'pBase': 'Puntaje base de una persona',
  'pPerLevel': 'Puntaje por nivel',
  'fertComunBias': 'Abono: sesgo',
  'fertComunSpeed': 'Abono: crecimiento (×)',
  'fertRunicoBias': 'Abono rúnico: sesgo',
  'fertRunicoSpeed': 'Abono rúnico: crecimiento (×)',
  'fertEcoBias': 'Abono del Eco: sesgo',
  'fertEcoSpeed': 'Abono del Eco: crecimiento (×)',
  'qualityMultNormal': 'Precio y XP × normal',
  'qualityMultRaro': 'Precio y XP × rara',
  'qualityMultEpico': 'Precio y XP × épica',
  'qualityMultLegendario': 'Precio y XP × legendaria',
  'seedDropChance': 'Chance de devolver semilla',
  'lootChance': 'Chance de hallazgo',
  'lootSemilla': 'Peso hallazgo: semilla rara o épica',
  'lootMateriales': 'Peso hallazgo: Esquirlas',
  'lootLegendaria': 'Peso hallazgo: semilla legendaria',
  'lootLevelBonus': 'Hallazgo extra por nivel',
  'lootPityAfter': 'Pity de hallazgo (cosechas)',
  'legendPityAfter': 'Pity de semilla legendaria (cosechas)',
  'lootMatMin': 'Esquirlas mínimas',
  'lootMatMax': 'Esquirlas máximas',
  'matRate': 'Cobro en materiales (×)',
  'matValue': 'Oro por Esquirla',
  'legendCristales': 'Canje legendario: Cristales de Era',
  'legendPrismas': 'Canje legendario: Prismas Rotos',
  'seasonPriceMult': 'Estación: × de precio del cultivo de estación',
  'seasonGrowMult': 'Estación: × de crecimiento del cultivo de estación',
  'mealBuffBase': 'Cocina: buff base de una comida',
  'mealBuffPerQuality': 'Cocina: buff extra por escalón de calidad',
  'mealMissions': 'Cocina: misiones que dura una comida',
  'reachPx': 'Alcance de una labor (px)',
  'minWorkSec': 'Segundos entre labores',
};

const _townLabels = {
  'maxExpansions': 'Ampliaciones máximas',
  'expGoldBase': 'Oro de la primera ampliación',
  'expGoldMult': 'Oro × por ampliación',
  'expEsquirlas': 'Esquirlas × ampliación',
  'expCristales': 'Cristales de Era desde la segunda',
  'maxPerSide': 'Ampliaciones máximas por lado',
  'lakeMin': 'Capacidad mínima de un lago',
  'lakePerTile': 'Capacidad por tile de agua',
  'stockWeight': 'Peso extra por pez soltado',
  'stockWeightCap': 'Tope de peso por especie',
  'lakeZoneRare': 'Rareza por 36 tiles de agua extra',
  'breedRare': 'Rareza por especie criando',
  'breedRareCap': 'Tope de rareza por cría',
  'breedChance': 'Chance de cría por misión ganada',
  'helperLevel': 'Ayudante: nivel del oficio para contratar',
  'helperCost': 'Ayudante: oro por ayudante',
  'helperPlots': 'Granjero: parcelas que atiende',
  'fisherTiles': 'Pescador: tiles de lago por pescador',
  'fisherCatch': 'Pescador: peces por vuelta',
  'helperEverySec': 'Ayudante: segundos entre rondas',
  'fisherBreathSec': 'Pescador: segundos por respiración',
  'fisherCatchSec': 'Pescador: segundos del momento de pesca',
  'fisherMoveSec': 'Pescador: segundos entre cambios de lugar',
  'fisherWalkTileSec': 'Pescador: segundos por tile al caminar',
  'helperXpShare': 'Cofre: parte de la XP',
  'chestMax': 'Cofre: tope de cosas',
  'helperMaxLevel': 'Ayudante: nivel máximo',
  'helperXpBase': 'Ayudante: XP base por nivel',
  'helperXpExp': 'Ayudante: exponente de XP',
  'hireMat': 'Contratar: fibras o cebos',
  'upGold': 'Mejora: oro × rango',
  'upMat': 'Mejora: fibras o cebos × rango',
  'upTabla': 'Mejora: tablas × rango',
  'upRankLevels': 'Mejora: niveles del ayudante por rango',
  'upMaxRank': 'Mejora: rangos máximos',
  'upPlots': 'Mejora Parcelas: parcelas por rango',
  'upRitmo': 'Mejora Ritmo: chance de vuelta extra por rango',
  'upCalidad': 'Mejora Calidad: chance de subir calidad por rango',
  'upRareSeed': 'Mejora Hallazgo: chance de semilla rara por rango',
  'upPeces': 'Mejora Red: peces por rango',
  'upRareza': 'Mejora Rareza: chance de pez mejor por rango',
  'fibraIn': 'Fibra: cosechas por fibra',
  'ceboIn': 'Cebo: pescados por cebo',
  'lifeEsq': 'Fibra / cebo: Esquirlas',
  'lifeCr': 'Fibra / cebo: oro',
  'tablaFibra': 'Tabla: fibras',
  'tablaEsq': 'Tabla: Esquirlas',
  'tablaCr': 'Tabla: oro',
  'daySec': 'Día: segundos de luz',
  'nightSec': 'Día: segundos de noche',
  'duskSec': 'Día: segundos de atardecer y amanecer',
  'seasonDays': 'Estaciones: días por estación',
  'wSpringClear': 'Clima en primavera: peso de despejado',
  'wSpringRain': 'Clima en primavera: peso de lluvia',
  'wSpringStorm': 'Clima en primavera: peso de tormenta',
  'wSpringFog': 'Clima en primavera: peso de niebla',
  'wSummerClear': 'Clima en verano: peso de despejado',
  'wSummerRain': 'Clima en verano: peso de lluvia',
  'wSummerStorm': 'Clima en verano: peso de tormenta',
  'wSummerFog': 'Clima en verano: peso de niebla',
  'wAutumnClear': 'Clima en otoño: peso de despejado',
  'wAutumnRain': 'Clima en otoño: peso de lluvia',
  'wAutumnStorm': 'Clima en otoño: peso de tormenta',
  'wAutumnFog': 'Clima en otoño: peso de niebla',
  'wWinterClear': 'Clima en invierno: peso de despejado',
  'wWinterRain': 'Clima en invierno: peso de lluvia',
  'wWinterStorm': 'Clima en invierno: peso de tormenta',
  'wWinterFog': 'Clima en invierno: peso de niebla',
  'wWinterSnow': 'Clima en invierno: peso de nieve',
  'bioPuebloRain': 'Clima en PUEBLO: × lluvia',
  'bioPuebloStorm': 'Clima en PUEBLO: × tormenta',
  'bioPuebloFog': 'Clima en PUEBLO: × niebla',
  'bioPuebloSnow': 'Clima en PUEBLO: × nieve',
  'bioBosqueRain': 'Clima en BOSQUE: × lluvia',
  'bioBosqueStorm': 'Clima en BOSQUE: × tormenta',
  'bioBosqueFog': 'Clima en BOSQUE: × niebla',
  'bioBosqueSnow': 'Clima en BOSQUE: × nieve',
  'bioRuinasRain': 'Clima en RUINAS: × lluvia',
  'bioRuinasStorm': 'Clima en RUINAS: × tormenta',
  'bioRuinasFog': 'Clima en RUINAS: × niebla',
  'bioRuinasSnow': 'Clima en RUINAS: × nieve',
  'bioGrietaRain': 'Clima en GRIETA: × lluvia',
  'bioGrietaStorm': 'Clima en GRIETA: × tormenta',
  'bioGrietaFog': 'Clima en GRIETA: × niebla',
  'bioGrietaSnow': 'Clima en GRIETA: × nieve',
  'bioAbismoRain': 'Clima en ABISMO: × lluvia',
  'bioAbismoStorm': 'Clima en ABISMO: × tormenta',
  'bioAbismoFog': 'Clima en ABISMO: × niebla',
  'bioAbismoSnow': 'Clima en ABISMO: × nieve',
  'fogBite': 'Niebla: chance de que pique',
  'snowBite': 'Nieve: chance de que pique',
  'fogFisher': 'Niebla: parte de la pesca de los pescadores',
  'snowFisher': 'Nieve: parte de la pesca de los pescadores',
  'weatherMinFrac': 'Clima: parte mínima del día',
  'weatherMaxFrac': 'Clima: parte máxima del día',
  'boltEverySec': 'Tormenta: segundos entre tiradas de rayo',
  'boltChance': 'Tormenta: chance de rayo por tirada',
  'stormBite': 'Tormenta: chance de que pique',
  'stormFisher': 'Tormenta: parte de la pesca de los pescadores',
  'autoWaitMult': 'Auto-pesca: × espera de la picada',
  'autoPassiveMult': 'Auto-pesca: × bonus de caña y pasivas',
  'autoEpicMult': 'Auto-pesca: × chance de épico',
  'autoXpMult': 'Auto-pesca: × XP',
  'faroCost': 'Faro: oro',
  'forageRespawnSec': 'Biomas: segundos de rebrote de una mata',
  'forageSeedChance': 'Biomas: chance de semilla al recolectar',
  'forageXp': 'Biomas: XP de Cultivo por recolectar',
  'reinforceDelay': 'Refuerzo: turnos de espera al entrar a una pelea',
  'absentWeight': 'Dificultad: peso de cada ausente de la sala',
  'resInviteRep': 'Habitantes: relación para invitarlo al pueblo',
  'resWalkSpeed': 'Habitantes: velocidad al mudarse (px/s)',
  'resNightOutBase': 'Habitantes: chance base de salir de noche',
  'resNightOutIlda': 'Habitantes: chance de que Ilda salga de noche',
  'resNightOutVelda': 'Habitantes: chance de que Velda salga de noche',
  'resNightOutKael': 'Habitantes: chance de que Kael salga de noche',
  'resNightOutBrann': 'Habitantes: chance de que Brann salga de noche',
  'resNightOutOren': 'Habitantes: chance de que Oren salga de noche',
  'resSettledRep': 'Habitantes: relación para Asentado',
  'resRootedRep': 'Habitantes: relación para Arraigado',
  'resMaxTier': 'Habitantes: nivel máximo del beneficio',
  'resMaxHouse': 'Habitantes: niveles del edificio',
  'resHouseGold': 'Habitantes: oro por nivel del edificio',
  'resRequestEveryDays': 'Habitantes: días entre pedidos',
  'resUnhappyDays': 'Habitantes: días de pedido ignorado para descontento',
  'resRequestRep': 'Habitantes: relación por pedido cumplido',
  'resHouseMat': 'Casa: tablas × nivel',
  'resHouseLoot': 'Casa: botín del bioma × nivel',
  'resNearTiles': 'Pedidos: tiles de cercanía a la casa',
  'resStockRare': 'Tienda: nivel para la semilla rara',
  'resStockLegend': 'Tienda: nivel para la legendaria',
  'orderEveryDays': 'Órdenes: días entre órdenes',
  'orderXpPerValue': 'Órdenes: XP por oro de valor',
  'orderXpDayCap': 'Órdenes: tope de XP por día',
  'orderGoldPerValue': 'Órdenes: oro × valor',
  'orderSkillEvery': 'Órdenes: punto de árbol cada N',
  'orderRep': 'Órdenes: relación por entrega',
  'lifeLevelCharXp': 'Oficios: XP de personaje × nivel de oficio',
  'orderRarityLevels': 'Órdenes: niveles de oficio por rareza',
  'orderAnyBiomeLevel': 'Órdenes: nivel para pedir de otros biomas',
  'orderQualityLevel': 'Órdenes: nivel de Cultivo para pedir calidad',
  'orderSizeLevel': 'Órdenes: nivel de Pesca para pedir tamaño',
  'comGold': 'Forja de Brann: oro × nivel',
  'comMat': 'Forja de Brann: materiales',
  'comLoot': 'Forja de Brann: botín del bioma',
  'comRareScore': 'Forja de Brann: puntaje para rara',
  'comEpicScore': 'Forja de Brann: puntaje para épica',
  'comLegendLevel': 'Forja de Brann: oficio para legendaria',
  'comIlGap': 'Forja de Brann: niveles debajo del personaje',
  'resherbolariaBase': 'Herbolaria: curación extra de pociones (%)',
  'resherbolariaStep': 'Herbolaria: extra por nivel (%)',
  'resarchivistaBase': 'Archivista: salas reveladas',
  'resarchivistaStep': 'Archivista: salas extra por nivel',
  'resinstructorBase': 'Instructor: XP extra (%)',
  'resinstructorStep': 'Instructor: XP extra por nivel (%)',
  'resforjadorBase': 'Forjador: descuento de mejoras (%)',
  'resforjadorStep': 'Forjador: descuento extra por nivel (%)',
  'resvidenteBase': 'Vidente: vida máxima extra (%)',
  'resvidenteStep': 'Vidente: vida extra por nivel (%)',
};

Map<String, String> _lifeTreeLabels() => {
      'pointsPerLevel': 'Puntos por nivel',
      'smithMaxLevel': 'Herrería: nivel máximo',
      'smithXpBase': 'Herrería: XP base por nivel',
      'smithXpExp': 'Herrería: exponente de la curva',
      'smithXpForge': 'Herrería: XP por forja',
      'smithXpCommission': 'Herrería: XP por encargo de forja',
      'smithXpCondense': 'Herrería: XP por condensado',
      'smithForgeCap': 'Herrería: descuento máximo de forja',
      for (final e in kLifeTrees.entries)
        for (final n in e.value) ...{
          n.id: '${e.key.label}: ${n.name}',
          '${n.id}_2': '${e.key.label}: ${n.name} (2.º)',
        },
    };

final farmingCodec =
    _tuningCodec(BalanceKind.farming, _autoFields('farming', _farmLabels));
final townCodec =
    _tuningCodec(BalanceKind.town, _autoFields('town', _townLabels));
final fishingCodec =
    _tuningCodec(BalanceKind.fishing, _autoFields('fishing', _fishLabels));

const _fishLabels = {
  'ambMusicLevel': 'Ambiente al pescar: nivel de la música',
  'ambDuckSec': 'Ambiente al pescar: segundos para bajar la música',
  'ambVolume': 'Ambiente al pescar: volumen de los sonidos',
  'ambGapMinSec': 'Ambiente al pescar: espera mínima (s)',
  'ambGapMaxSec': 'Ambiente al pescar: espera máxima (s)',
  'baitAffinity': 'Cebo: × peso de los peces que atrae',
  'baitWaterChance': 'Cebo: chance de cebo en el botín de materiales',
  'baitLombrizBite': 'Cebo (lombriz común): picada más rápida',
  'baitLombrizRare': 'Cebo (lombriz común): bonus de rareza',
  'baitLombrizSize': 'Cebo (lombriz común): bonus de tamaño',
  'baitLombrizPrice': 'Cebo (lombriz común): precio',
  'baitLombrizGold': 'Cebo (lombriz común): oro de la receta',
  'baitLarvaBite': 'Cebo (larva brillante): picada más rápida',
  'baitLarvaRare': 'Cebo (larva brillante): bonus de rareza',
  'baitLarvaSize': 'Cebo (larva brillante): bonus de tamaño',
  'baitLarvaPrice': 'Cebo (larva brillante): precio',
  'baitLarvaGold': 'Cebo (larva brillante): oro de la receta',
  'baitEscarchaBite': 'Cebo (cebo de escarcha): picada más rápida',
  'baitEscarchaRare': 'Cebo (cebo de escarcha): bonus de rareza',
  'baitEscarchaSize': 'Cebo (cebo de escarcha): bonus de tamaño',
  'baitEscarchaPrice': 'Cebo (cebo de escarcha): precio',
  'baitEscarchaGold': 'Cebo (cebo de escarcha): oro de la receta',
  'baitTormentaBite': 'Cebo (cebo de tormenta): picada más rápida',
  'baitTormentaRare': 'Cebo (cebo de tormenta): bonus de rareza',
  'baitTormentaSize': 'Cebo (cebo de tormenta): bonus de tamaño',
  'baitTormentaPrice': 'Cebo (cebo de tormenta): precio',
  'baitTormentaGold': 'Cebo (cebo de tormenta): oro de la receta',
  'baitEcoBite': 'Cebo (señuelo del eco): picada más rápida',
  'baitEcoRare': 'Cebo (señuelo del eco): bonus de rareza',
  'baitEcoSize': 'Cebo (señuelo del eco): bonus de tamaño',
  'baitEcoPrice': 'Cebo (señuelo del eco): precio',
  'baitEcoGold': 'Cebo (señuelo del eco): oro de la receta',
  'fisherRarityLevels': 'Pescador: niveles por rareza',
  'fisherXpBase': 'Pescador: XP de Pesca base',
  'fisherXpStep': 'Pescador: XP de Pesca por nivel',
  'fisherCharXpPerValue': 'Pescador: XP × valor',
  'fisherGoldPerValue': 'Pescador: oro × valor',
};

final smithingCodec = _tuningCodec(
    BalanceKind.smithing, _autoFields('smithing', _smithingLabels));

const _smithingLabels = {
  'mineLevels': 'Mina: niveles por mina',
  'mineW': 'Mina: ancho del nivel (tiles)',
  'mineH': 'Mina: alto del nivel (tiles)',
  'mineReach': 'Mina: distancia para picar (px)',
  'caveDensity': 'Mina: densidad de cuevas abiertas (0 = todo roca)',
  'formations': 'Mina: formaciones irrompibles',
  'streamChance': 'Mina: chance de arroyo (decorado, sellado en la roca)',
  'lakeChance': 'Mina: chance de charco en una cámara',
  'discoverLit': 'Mina: radio (tiles) en que se descubre una veta',
  'discoverView': 'Mina: distancia (tiles) para ver una veta en la cara de un túnel',
  'veinGlow': 'Mina: brillo de las vetas comunes',
  'veinGlowRich': 'Mina: brillo de las vetas ricas',
  'veinGlowDeep': 'Mina: brillo de las vetas profundas',
  'veinGlowGem': 'Mina: brillo de las vetas de gema',
  'minerYield': 'Minero: fracción de lo que da una veta (< jugador)',
  'minerUpGold': 'Minero: oro por nivel de pico al mejorarlo',
  'minerUpIngots': 'Minero: lingotes por nivel de pico al mejorarlo',
  'chambers': 'Mina: cámaras selladas por nivel',
  'chamberMin': 'Mina: radio mínimo de cámara',
  'chamberMax': 'Mina: radio máximo de cámara',
  'grottoChance': 'Mina: chance de gruta de cristal',
  'secretChance': 'Mina: chance de gruta oculta',
  'relicChance': 'Mina: chance de cofre reliquia',
  'mushroomChance': 'Mina: chance de hongos',
  'loreChance': 'Mina: chance de piedra de memoria',
  'chestRate': 'Mina: chance de cofre por cámara',
  'rockHits': 'Roca: golpes base',
  'rockHitsPerLevel': 'Roca: golpes extra por nivel',
  'veinHitMult': 'Veta: golpes × roca',
  'reqTierLv0': 'Nivel 1: grado de pico necesario',
  'reqTierLv1': 'Nivel 2: grado de pico necesario',
  'reqTierLv2': 'Nivel 3: grado de pico necesario',
  'reqTierLv3': 'Nivel 4: grado de pico necesario',
  'reqTierLv4': 'Nivel 5: grado de pico necesario',
  'veinClusters': 'Vetas: grupos base',
  'veinClustersPerLevel': 'Vetas: grupos extra por nivel',
  'veinSizeMin': 'Vetas: tamaño mínimo',
  'veinSizeMax': 'Vetas: tamaño máximo',
  'wCommon': 'Peso: veta común',
  'wRich': 'Peso: veta rica',
  'wRichPerLevel': 'Peso: veta rica por nivel',
  'wDeep': 'Peso: veta profunda',
  'wDeepPerLevel': 'Peso: veta profunda por nivel',
  'wGem': 'Peso: veta de gema',
  'wGemPerLevel': 'Peso: gema por nivel',
  'rich_bosque': 'Riqueza de vetas: bosque',
  'rich_ruinas': 'Riqueza de vetas: ruinas',
  'rich_cavernas': 'Riqueza de vetas: cavernas',
  'rich_grieta': 'Riqueza de vetas: grieta',
  'rich_abismo': 'Riqueza de vetas: abismo',
  'richOreBonus': 'Veta rica: menas extra',
  'richRareChance': 'Veta rica: chance de raro',
  'crystalRareChance': 'Cristal: chance de raro',
  'digXp': 'Picar roca: XP de Herrería',
  'tool0Power': 'Herramienta 0: golpes por picada',
  'tool0Swing': 'Herramienta 0: segundos entre picadas',
  'tool0Yield': 'Herramienta 0: chance de mena extra',
  'tool0Gold': 'Herramienta 0: oro',
  'tool0Ingots': 'Herramienta 0: lingotes',
  'tool1Power': 'Herramienta 1: golpes por picada',
  'tool1Swing': 'Herramienta 1: segundos entre picadas',
  'tool1Yield': 'Herramienta 1: chance de mena extra',
  'tool1Gold': 'Herramienta 1: oro',
  'tool1Ingots': 'Herramienta 1: lingotes',
  'tool2Power': 'Herramienta 2: golpes por picada',
  'tool2Swing': 'Herramienta 2: segundos entre picadas',
  'tool2Yield': 'Herramienta 2: chance de mena extra',
  'tool2Gold': 'Herramienta 2: oro',
  'tool2Ingots': 'Herramienta 2: lingotes',
  'tool3Power': 'Herramienta 3: golpes por picada',
  'tool3Swing': 'Herramienta 3: segundos entre picadas',
  'tool3Yield': 'Herramienta 3: chance de mena extra',
  'tool3Gold': 'Herramienta 3: oro',
  'tool3Ingots': 'Herramienta 3: lingotes',
  'tool4Power': 'Herramienta 4: golpes por picada',
  'tool4Swing': 'Herramienta 4: segundos entre picadas',
  'tool4Yield': 'Herramienta 4: chance de mena extra',
  'tool4Gold': 'Herramienta 4: oro',
  'tool4Ingots': 'Herramienta 4: lingotes',
  'torchGold': 'Antorcha: oro',
  'torchOre': 'Antorcha: menas para fabricar',
  'torchBatch': 'Antorcha: por fabricación',
  'bombGold': 'Bomba: oro',
  'bombOre': 'Bomba: menas para fabricar',
  'bombRadius': 'Bomba: radio (tiles)',
  'bombFuse': 'Bomba: mecha (s)',
  'oilGold': 'Aceite de veta: oro',
  'oilOre': 'Aceite de veta: menas para fabricar',
  'boostSec': 'Aceite de veta: duración (s)',
  'boostRare': 'Aceite de veta: + chance de raro (× 1)',
  'boostYield': 'Aceite de veta: chance de mena extra',
  'regrowSec': 'Vetas: segundos para volver',
  'regrowRadius': 'Vetas: radio donde vuelven',
  'regrowSafeTiles': 'Vetas: tiles mínimos lejos de los jugadores',
  'minerCost': 'Minero: oro para contratar',
  'minerMax': 'Minero: máximo por nivel',
  'minerStepSec': 'Minero: segundos por paso',
  'minerPower': 'Minero: golpes por paso',
  'minerTorchEvery': 'Minero: antorcha cada N tiles',
  'stationGold': 'Estación: oro',
  'stationIngots': 'Estación: lingotes de cobre',
  'cartCap': 'Vagoneta: capacidad',
  'cartTravelSec': 'Vagoneta: segundos hasta el pueblo',
  'cartBackSec': 'Vagoneta: segundos de vuelta',
  'orePricePerTier': 'Venta: mena × nivel',
  'ingotPricePerTier': 'Venta: lingote × nivel',
  'rarePricePerTier': 'Venta: material raro × nivel',
  'specialPrice': 'Venta: Plano / Núcleo',
  'forgedSellMult': 'Venta: arma forjada × (base)',
  'forgedSellPerRarity': 'Venta: arma forjada × por rareza',
  'smithOrderChance': 'Pedido de herrería: chance por día',
  'smithOrderMin': 'Pedido de herrería: lingotes mínimos',
  'smithOrderMax': 'Pedido de herrería: lingotes máximos',
  'smithOrderPay': 'Pedido de herrería: pago × valor',
  'mineOreMin': 'Mina: menas mínimas por veta',
  'mineOreMax': 'Mina: menas máximas por veta',
  'mineRareChance': 'Mina: chance de material raro',
  'mineBaitChance': 'Mina: chance de cebo en una veta',
  'mineNpcChance': 'Mina: chance de un PNJ',
  'mineXp': 'Mina: XP de Herrería × nivel de mena',
  'dungeonOreChance': 'Mazmorra: chance de veta rara por piso',
  'dungeonSchematicChance': 'Mazmorra: chance de Plano antiguo',
  'bossCore': 'Jefe: Núcleos de guardián',
  'smeltOre': 'Fundir: menas por lingote',
  'smeltGoldPerTier': 'Fundir: oro × nivel de mena',
  'smeltXp': 'Fundir: XP × nivel por lingote',
  'ingotIlPerTier': 'Forjar: nivel de objeto máximo × nivel del lingote',
  'craftIlGap': 'Forjar: niveles debajo del personaje',
  'craftGoldPerIl': 'Forjar: oro × nivel de objeto',
  'brannGoldPerIl': 'Brann: oro × nivel de objeto',
  'craftXp': 'Forjar: XP × (rareza + 1)',
  'lvMagico': 'Herrería: nivel para Mágico',
  'lvRaro': 'Herrería: nivel para Raro',
  'lvEpico': 'Herrería: nivel para Épico',
  'lvLegend': 'Herrería: nivel para Legendario',
  'ingotsComun': 'Lingotes: Común',
  'ingotsMagico': 'Lingotes: Mágico',
  'ingotsRaro': 'Lingotes: Raro',
  'ingotsEpico': 'Lingotes: Épico',
  'ingotsLegend': 'Lingotes: Legendario',
  'rareRaro': 'Material raro: Raro',
  'rareEpico': 'Material raro: Épico',
  'rareLegend': 'Material raro: Legendario',
  'stackCap': 'Tope por material',
};

final regionsCodec = _tuningCodec(
    BalanceKind.regions, _autoFields('regions', _regionsLabels));

const _regionsLabels = {
  'secondLakeChance': 'Región: chance de un segundo lago',
  'lakeRxMin': 'Lago: radio horizontal mínimo',
  'lakeRxMax': 'Lago: radio horizontal máximo',
  'lakeRyMin': 'Lago: radio vertical mínimo',
  'lakeRyMax': 'Lago: radio vertical máximo',
  'treeDensity': 'Región: árboles cada 100 tiles libres',
  'plantSpots': 'Recolección: matas del bioma',
  'seedBushes': 'Recolección: matas de semillas',
  'seasonalSpots': 'Recolección: brotes de estación',
  'mainPathMax': 'Camino principal: pasos máximos',
  'seedBushRareMul': 'Mata de semillas: × peso de las raras',
  'echoBloomRespawnSec': 'Flor del eco: segundos de rebrote',
  'seasonalXpMul': 'Brotes de estación: × XP',
  'echoBloomXpMul': 'Flor del eco: × XP',
  'forageHideRadius': 'Rebrote: distancia de vista (px)',
  'forageRecheckSec': 'Rebrote: segundos entre chequeos',
  'waystoneReach': 'Piedra de paso: distancia (px)',
  'caveRoofLip': 'Gruta: alero del techo (px)',
  'cavePoolAlpha': 'Gruta: opacidad de los charcos de luz',
  'cavePoolSize': 'Gruta: tamaño de los charcos de luz (px)',
  'cavePoolPixel': 'Gruta: pixelado de los charcos de luz (px)',
  'caveMotes': 'Gruta: motas de polvo por charco',
  'caveMoteSpeed': 'Gruta: velocidad de las motas',
  'swayAmp': 'Viento: vaivén de la vegetación (px)',
  'swaySpeed': 'Viento: velocidad del vaivén',
  'swayDensity': 'Viento: fracción de vegetación que se mece',
};

final lifeTreeCodec = _tuningCodec(
    BalanceKind.lifeTree, _autoFields('lifeTree', _lifeTreeLabels()));

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
      BalanceKind.consumables => consumablesCodec,
      BalanceKind.travesia => travesiaCodec,
      BalanceKind.combatLimits => combatLimitsCodec,
      BalanceKind.exploration => explorationCodec,
      BalanceKind.farming => farmingCodec,
      BalanceKind.town => townCodec,
      BalanceKind.fishing => fishingCodec,
      BalanceKind.lifeTree => lifeTreeCodec,
      BalanceKind.smithing => smithingCodec,
      BalanceKind.regions => regionsCodec,
    };

/// Tipos de "Ajustes": un grupo de [kTuning] cada uno (id = jsonKey).
const kTuningKinds = [
  BalanceKind.ultLevel,
  BalanceKind.ultUpgrade,
  BalanceKind.ultCharge,
  BalanceKind.condense,
  BalanceKind.materials,
  BalanceKind.ecoTier,
  BalanceKind.consumables,
  BalanceKind.travesia,
  BalanceKind.combatLimits,
  BalanceKind.exploration,
  BalanceKind.farming,
  BalanceKind.town,
  BalanceKind.fishing,
  BalanceKind.lifeTree,
  BalanceKind.smithing,
  BalanceKind.regions,
];
