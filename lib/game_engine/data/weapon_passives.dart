import '../models/passive_mechanic.dart';
import '../models/status.dart';
import '../models/weapon_passive.dart';

// Pasivas de arma (docs/specs/loot.md § 10). Usan el mismo sistema de
// disparadores que los notables del árbol v2 (`PassiveMechanic`); el
// motor las resuelve con `mechanicById` (passive_mechanics.dart).

String _pct(double v) => '${(v * 100).round()}%';

PassiveMechanic _m(
  String id,
  String name,
  ProcTrigger trigger,
  List<ProcEffect> effects,
  String description, {
  ProcFilter filter = ProcFilter.any,
  double chance = 1,
  StatusKind? status,
  int minStacks = 1,
  double threshold = 0,
}) =>
    PassiveMechanic(
      id: id,
      name: name,
      trigger: trigger,
      effects: effects,
      description: description,
      filter: filter,
      chance: chance,
      status: status,
      minStacks: minStacks,
      threshold: threshold,
    );

/// Una pasiva de una sola mecánica: el texto sale de [describe].
WeaponPassiveDef _one({
  required String id,
  required String name,
  required List<double> values,
  required String Function(double v) describe,
  required PassiveMechanic Function(String mid, String n, double v, String d)
      mech,
  Set<String> types = const {},
  bool unique = false,
}) =>
    WeaponPassiveDef(
      id: id,
      name: name,
      types: types,
      unique: unique,
      values: values,
      describe: describe,
      build: (mid, n, v) => [mech(mid, n, v, describe(v))],
    );

/// Pasivas por id: las del pool de Épicos y las únicas de Legendarios.
final Map<String, WeaponPassiveDef> kWeaponPassives = {
  for (final p in [..._pool, ..._uniques]) p.id: p,
};

/// Pool de un tipo de arma (Épicos).
List<WeaponPassiveDef> weaponPassivePool(String weaponType) => [
      for (final p in _pool)
        if (p.types.contains(weaponType)) p,
    ];

/// Ids de las mecánicas de la pasiva [passiveId] a [level] (vacío si no
/// existe).
List<String> weaponPassiveMechanicIds(String passiveId, int level) => [
      for (final m in kWeaponPassives[passiveId]?.mechanicsAt(level) ??
          const <PassiveMechanic>[])
        m.id,
    ];

final Map<String, PassiveMechanic?> _byMechanicId = {};

/// La mecánica de una pasiva de arma por su id (`wp:<pasiva>:<nivel>` y
/// `#2`, `#3`... para las siguientes). `null` si no es de una pasiva.
PassiveMechanic? weaponPassiveMechanic(String id) {
  if (!id.startsWith('wp:')) return null;
  return _byMechanicId.putIfAbsent(id, () {
    final hash = id.indexOf('#');
    final head = hash < 0 ? id : id.substring(0, hash);
    final parts = head.split(':');
    if (parts.length != 3) return null;
    final def = kWeaponPassives[parts[1]];
    final level = int.tryParse(parts[2]);
    if (def == null || level == null) return null;
    for (final m in def.mechanicsAt(level)) {
      if (m.id == id) return m;
    }
    return null;
  });
}

// ----------------------------------------------------------------------
// Pool (Épico)
// ----------------------------------------------------------------------

final List<WeaponPassiveDef> _pool = [
  _one(
    id: 'filoResonante',
    name: 'Filo Resonante',
    types: {'espada', 'lanza', 'dagas', 'espada+escudo'},
    values: [0.25, 0.30, 0.35, 0.40, 0.45],
    describe: (v) => 'Tus golpes a un solo objetivo golpean también a un 2.º '
        'enemigo con el ${_pct(v)} del daño.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHit,
        [ProcEffect(ProcEffectKind.chain, value: v)], d,
        filter: ProcFilter.singleTarget),
  ),
  _one(
    id: 'impetu',
    name: 'Ímpetu',
    types: {'espada', 'dagas', 'arco'},
    values: [0.10, 0.12, 0.15, 0.17, 0.20],
    describe: (v) => 'Al hacer crítico: +${_pct(v)} velocidad por 2 turnos.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onCrit, [
      ProcEffect(ProcEffectKind.buffSelf,
          value: v, turns: 2, stat: BuffStat.speed)
    ], d),
  ),
  _one(
    id: 'rompehielos',
    name: 'Rompehielos',
    types: {'hacha', 'martillo+escudo', 'lanza', 'rifle'},
    values: [0.20, 0.25, 0.30, 0.35, 0.40],
    describe: (v) =>
        'Golpear a un enemigo congelado llena su quiebre un ${_pct(v)} más.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.vsStatus,
        [ProcEffect(ProcEffectKind.breakBonus, value: v)], d,
        status: StatusKind.freeze),
  ),
  _one(
    id: 'escarchaViva',
    name: 'Escarcha Viva',
    types: {'báculo', 'tomo', 'varita', 'rifle'},
    values: [0.40, 0.50, 0.60, 0.70, 0.80],
    describe: (v) =>
        'Al aplicar Congelación: ${_pct(v)} de sumar +1 stack más.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onStatusApplied,
        [const ProcEffect(ProcEffectKind.extraStacks, value: 1)], d,
        status: StatusKind.freeze, chance: v),
  ),
  _one(
    id: 'brasaAvivada',
    name: 'Brasa Avivada',
    types: {'báculo', 'varita', 'espada', 'arco'},
    values: [0.40, 0.50, 0.60, 0.70, 0.80],
    describe: (v) => 'Al aplicar Quemadura: ${_pct(v)} de sumar +1 stack más.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onStatusApplied,
        [const ProcEffect(ProcEffectKind.extraStacks, value: 1)], d,
        status: StatusKind.burn, chance: v),
  ),
  _one(
    id: 'toxinaPersistente',
    name: 'Toxina Persistente',
    types: {'tomo', 'arco', 'dagas', 'ballesta'},
    values: [0.40, 0.50, 0.60, 0.70, 0.80],
    describe: (v) => 'Al aplicar Veneno: ${_pct(v)} de sumar +1 stack más.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onStatusApplied,
        [const ProcEffect(ProcEffectKind.extraStacks, value: 1)], d,
        status: StatusKind.poison, chance: v),
  ),
  _one(
    id: 'egidaSanadora',
    name: 'Égida Sanadora',
    types: {'báculo', 'tomo', 'maza+escudo', 'espada+escudo'},
    values: [0.10, 0.15, 0.20, 0.25, 0.30],
    describe: (v) => 'Al curar a un aliado, gana un escudo del ${_pct(v)} de '
        'lo curado por 2 turnos.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHeal, [
      ProcEffect(ProcEffectKind.shieldHealed,
          value: v, turns: 2, stat: BuffStat.shield)
    ], d),
  ),
  _one(
    id: 'sedDelArma',
    name: 'Sed del Arma',
    types: {'hacha', 'espada', 'lanza', 'dagas'},
    values: [0.04, 0.06, 0.08, 0.10, 0.12],
    describe: (v) => 'Al matar: te curás ${_pct(v)} de tu vida máx.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onKill,
        [ProcEffect(ProcEffectKind.healSelf, value: v)], d),
  ),
  _one(
    id: 'conmocion',
    name: 'Golpe Conmocionante',
    types: {'maza+escudo', 'martillo+escudo', 'hacha', 'ballesta'},
    values: [0.06, 0.08, 0.10, 0.12, 0.15],
    describe: (v) => 'Tus golpes a un solo objetivo tienen ${_pct(v)} de '
        'aturdirlo.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHit, [
      const ProcEffect(ProcEffectKind.inflict,
          value: 1, status: StatusKind.stun)
    ], d, filter: ProcFilter.singleTarget, chance: v),
  ),
  _one(
    id: 'marcaPresa',
    name: 'Marca de la Presa',
    types: {'arco', 'ballesta', 'rifle', 'lanza'},
    values: [0.06, 0.08, 0.10, 0.12, 0.14],
    describe: (v) => 'Tu primer golpe a un enemigo sin marca lo marca: recibe '
        '+${_pct(v)} de daño de todos por 2 turnos.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHit, [
      ProcEffect(ProcEffectKind.markTarget,
          value: v, turns: 2, stat: BuffStat.damageTaken)
    ], d),
  ),
  _one(
    id: 'vientoDeCola',
    name: 'Viento de Cola',
    types: {'arco', 'varita', 'tomo', 'hacha'},
    values: [0.10, 0.15, 0.20, 0.25, 0.30],
    describe: (v) => 'Después de una habilidad de daño a todos: tu próximo '
        'turno llega ${_pct(v)} antes.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onSkill,
        [ProcEffect(ProcEffectKind.advanceTurn, value: v)], d,
        filter: ProcFilter.areaSkill),
  ),
  _one(
    id: 'ecoMistico',
    name: 'Eco Místico',
    types: {'varita', 'báculo', 'tomo'},
    values: [0.06, 0.08, 0.10, 0.12, 0.14],
    describe: (v) => '${_pct(v)} de que una habilidad mágica se repita gratis '
        'al 50% del daño base.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onSkill,
        [const ProcEffect(ProcEffectKind.repeatSkill, value: 0.5)], d,
        filter: ProcFilter.magicalSkill, chance: v),
  ),
  _one(
    id: 'cargaHeroica',
    name: 'Carga Heroica',
    types: {'rifle', 'ballesta', 'espada', 'martillo+escudo'},
    values: [3, 4, 5, 6, 7],
    describe: (v) => 'Al hacer crítico: +${v.round()} carga de ULT.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onCrit,
        [ProcEffect(ProcEffectKind.ultCharge, value: v)], d),
  ),
  _one(
    id: 'espinas',
    name: 'Espinas',
    types: {'espada+escudo', 'maza+escudo', 'martillo+escudo', 'hacha'},
    values: [0.15, 0.20, 0.25, 0.30, 0.35],
    describe: (v) =>
        'Al recibir un golpe: devolvés el ${_pct(v)} del daño al atacante.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHitTaken,
        [ProcEffect(ProcEffectKind.reflect, value: v)], d),
  ),
  _one(
    id: 'bastionVivo',
    name: 'Bastión Vivo',
    types: {'espada+escudo', 'maza+escudo', 'martillo+escudo'},
    values: [0.06, 0.08, 0.10, 0.12, 0.14],
    describe: (v) => 'Al usar Provocar, Protección o Escudo de Fe: escudo del '
        '${_pct(v)} de tu vida máx. por 2 turnos.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onSkill, [
      ProcEffect(ProcEffectKind.shieldSelf,
          value: v, turns: 2, stat: BuffStat.shield)
    ], d, filter: ProcFilter.guardSkill),
  ),
  _one(
    id: 'filoDesesperado',
    name: 'Filo Desesperado',
    types: {'hacha', 'dagas', 'lanza', 'espada'},
    values: [0.10, 0.15, 0.20, 0.25, 0.30],
    describe: (v) => 'Con menos de 35% de vida: +${_pct(v)} ATQ.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.whileLowHealth, [
      ProcEffect(ProcEffectKind.statBonus, value: v, stat: BuffStat.attack)
    ], d, threshold: 0.35),
  ),
  _one(
    id: 'cazadorGelido',
    name: 'Cazador Gélido',
    types: {'rifle', 'ballesta', 'arco', 'varita'},
    values: [0.08, 0.12, 0.16, 0.20, 0.24],
    describe: (v) => 'Tus golpes a enemigos con Congelación hacen +${_pct(v)} '
        'de daño.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.vsStatus, [
      ProcEffect(ProcEffectKind.statBonus, value: v, stat: BuffStat.damage)
    ], d, status: StatusKind.freeze),
  ),
  _one(
    id: 'fuegoHambriento',
    name: 'Fuego Hambriento',
    types: {'báculo', 'varita', 'espada', 'ballesta'},
    values: [0.08, 0.12, 0.16, 0.20, 0.24],
    describe: (v) => 'Tus golpes a enemigos con Quemadura hacen +${_pct(v)} '
        'de daño.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.vsStatus, [
      ProcEffect(ProcEffectKind.statBonus, value: v, stat: BuffStat.damage)
    ], d, status: StatusKind.burn),
  ),
  _one(
    id: 'plegariaAcero',
    name: 'Plegaria del Acero',
    types: {'maza+escudo', 'tomo', 'espada+escudo'},
    values: [0.02, 0.03, 0.04, 0.05, 0.06],
    describe: (v) => 'Al empezar tu turno: el aliado con menor % de vida se '
        'cura ${_pct(v)} de su vida máx.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onTurnStart,
        [ProcEffect(ProcEffectKind.healLowestAlly, value: v)], d),
  ),
  _one(
    id: 'pesoDelTiempo',
    name: 'Peso del Tiempo',
    types: {'martillo+escudo', 'tomo', 'ballesta', 'lanza'},
    values: [0.08, 0.11, 0.14, 0.17, 0.20],
    describe: (v) => 'Tus golpes a un solo objetivo lo retrasan un ${_pct(v)} '
        'de su espera.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHit,
        [ProcEffect(ProcEffectKind.delayTarget, value: v)], d,
        filter: ProcFilter.singleTarget),
  ),
  _one(
    id: 'ojoCertero',
    name: 'Ojo Certero',
    types: {'arco', 'rifle', 'dagas'},
    values: [0.06, 0.09, 0.12, 0.15, 0.18],
    describe: (v) => '+${_pct(v)} crítico contra enemigos marcados.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.vsMarked, [
      ProcEffect(ProcEffectKind.statBonus, value: v, stat: BuffStat.crit)
    ], d),
  ),
];

// ----------------------------------------------------------------------
// Únicas (Legendarios, ver uniques_catalog.dart)
// ----------------------------------------------------------------------

final List<WeaponPassiveDef> _uniques = [
  // ---- ULT v2 (ultimates_v2.md § 3.2): legendarios nuevos ----
  _one(
    id: 'latidoMagitec',
    name: 'Latido Magitec',
    unique: true,
    values: [0.10, 0.125, 0.15, 0.175, 0.20],
    describe: (v) => 'Al usar la ULT: +${_pct(v)} crítico por 2 turnos.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onUltimate, [
      ProcEffect(ProcEffectKind.buffSelf,
          value: v, turns: 2, stat: BuffStat.crit)
    ], d),
  ),
  _one(
    id: 'resuenaYunque',
    name: 'Resuena el Yunque',
    unique: true,
    values: [0.10, 0.15, 0.20, 0.25, 0.30],
    describe: (v) =>
        'Al quebrar a un enemigo: +${_pct(v)} defensa por 2 turnos.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onBreak, [
      ProcEffect(ProcEffectKind.buffSelf,
          value: v, turns: 2, stat: BuffStat.guard)
    ], d),
  ),
  _one(
    id: 'albaImplacable',
    name: 'Alba Implacable',
    unique: true,
    values: [0.15, 0.20, 0.25, 0.30, 0.35],
    describe: (v) => 'Al hacer crítico: +${_pct(v)} ATQ por 2 turnos.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onCrit, [
      ProcEffect(ProcEffectKind.buffSelf,
          value: v, turns: 2, stat: BuffStat.attack)
    ], d),
  ),
  WeaponPassiveDef(
    id: 'cosecha',
    name: 'Cosecha',
    unique: true,
    values: [0.20, 0.30, 0.40, 0.50, 0.60],
    describe: (v) => 'Al matar: tu próximo turno llega ${_pct(v)} antes y te '
        'curás ${_pct(v / 6)} de tu vida máx.',
    build: (id, n, v) => [
      _m(id, n, ProcTrigger.onKill, [
        ProcEffect(ProcEffectKind.advanceTurn, value: v),
        ProcEffect(ProcEffectKind.healSelf, value: v / 6),
      ], 'Al matar: tu próximo turno llega ${_pct(v)} antes y te curás '
          '${_pct(v / 6)} de tu vida máx.'),
    ],
  ),
  _one(
    id: 'erupcionInterna',
    name: 'Erupción Interna',
    unique: true,
    values: [0.30, 0.375, 0.45, 0.525, 0.60],
    describe: (v) => 'Al golpear a un enemigo con 3+ Quemadura: explota y '
        'hace el ${_pct(v)} de ese golpe a cada otro enemigo.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHit,
        [ProcEffect(ProcEffectKind.explode, value: v)], d,
        status: StatusKind.burn, minStacks: 3),
  ),
  _one(
    id: 'grieta',
    name: 'Grieta',
    unique: true,
    values: [0.25, 0.35, 0.45, 0.55, 0.65],
    describe: (v) => 'Todos tus golpes llenan el quiebre un ${_pct(v)} más.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.always,
        [ProcEffect(ProcEffectKind.breakBonus, value: v)], d),
  ),
  _one(
    id: 'horizonte',
    name: 'Horizonte',
    unique: true,
    values: [0.45, 0.50, 0.55, 0.60, 0.65],
    describe: (v) => 'Tus golpes a un solo objetivo rebotan a otro enemigo con '
        'el ${_pct(v)} del daño.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHit,
        [ProcEffect(ProcEffectKind.chain, value: v)], d,
        filter: ProcFilter.singleTarget),
  ),
  _one(
    id: 'ascuaEterna',
    name: 'Ascua Eterna',
    unique: true,
    values: [0.50, 0.625, 0.75, 0.875, 1.0],
    describe: (v) => 'Al aplicar Quemadura: ${_pct(v)} de sumar +1 stack más.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onStatusApplied,
        [const ProcEffect(ProcEffectKind.extraStacks, value: 1)], d,
        status: StatusKind.burn, chance: v),
  ),
  _one(
    id: 'escarchaPerpetua',
    name: 'Escarcha Perpetua',
    unique: true,
    values: [0.15, 0.20, 0.25, 0.30, 0.35],
    describe: (v) =>
        'Al congelar a un enemigo: se retrasa un ${_pct(v)} de su espera.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onStatusApplied,
        [ProcEffect(ProcEffectKind.delayTarget, value: v)], d,
        status: StatusKind.freeze),
  ),
  _one(
    id: 'paradojaViva',
    name: 'Paradoja Viva',
    unique: true,
    values: [0.15, 0.20, 0.25, 0.30, 0.35],
    describe: (v) => '${_pct(v)} de que una habilidad mágica se repita gratis '
        'al 60% del daño base.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onSkill,
        [const ProcEffect(ProcEffectKind.repeatSkill, value: 0.6)], d,
        filter: ProcFilter.magicalSkill, chance: v),
  ),
  _one(
    id: 'arcoDormido',
    name: 'Arco Dormido',
    unique: true,
    values: [0.35, 0.40, 0.45, 0.50, 0.55],
    describe: (v) => 'Tus habilidades mágicas a un solo objetivo rebotan a '
        'otro enemigo con el ${_pct(v)} del daño.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHit,
        [ProcEffect(ProcEffectKind.chain, value: v)], d,
        filter: ProcFilter.magicalSingle),
  ),
  _one(
    id: 'mordida',
    name: 'Mordida',
    unique: true,
    values: [2, 2, 3, 3, 4],
    describe: (v) => 'Al hacer crítico: +${v.round()} Veneno al objetivo.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onCrit, [
      ProcEffect(ProcEffectKind.inflict,
          value: v, status: StatusKind.poison)
    ], d),
  ),
  WeaponPassiveDef(
    id: 'solCenital',
    name: 'Sol Cenital',
    unique: true,
    values: [0.10, 0.15, 0.20, 0.25, 0.30],
    describe: (v) => 'Tus golpes marcan al enemigo (+10% de daño recibido, 2 '
        'turnos) y tenés +${_pct(v)} crítico contra marcados.',
    build: (id, n, v) => [
      _m(id, n, ProcTrigger.onHit, const [
        ProcEffect(ProcEffectKind.markTarget,
            value: 0.10, turns: 2, stat: BuffStat.damageTaken)
      ], 'Tus golpes marcan al enemigo: +10% de daño recibido por 2 turnos.'),
      _m('$id#2', n, ProcTrigger.vsMarked, [
        ProcEffect(ProcEffectKind.statBonus, value: v, stat: BuffStat.crit)
      ], '+${_pct(v)} crítico contra enemigos marcados.'),
    ],
  ),
  _one(
    id: 'estampido',
    name: 'Estampido',
    unique: true,
    values: [0.25, 0.35, 0.45, 0.55, 0.65],
    describe: (v) => 'Al hacer crítico: ${_pct(v)} de aturdir al objetivo.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onCrit, [
      const ProcEffect(ProcEffectKind.inflict,
          value: 1, status: StatusKind.stun)
    ], d, chance: v),
  ),
  _one(
    id: 'viroteFinal',
    name: 'Virote Final',
    unique: true,
    values: [10, 15, 20, 25, 30],
    describe: (v) => 'Al matar: +${v.round()} carga de ULT.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onKill,
        [ProcEffect(ProcEffectKind.ultCharge, value: v)], d),
  ),
  _one(
    id: 'florecer',
    name: 'Florecer',
    unique: true,
    values: [0.10, 0.15, 0.20, 0.25, 0.30],
    describe: (v) => 'Después de una habilidad de daño a todos: ataque básico '
        'gratis al enemigo con menos vida y tu próximo turno llega '
        '${_pct(v)} antes.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onSkill, [
      const ProcEffect(ProcEffectKind.freeAttack),
      ProcEffect(ProcEffectKind.advanceTurn, value: v),
    ], d, filter: ProcFilter.areaSkill),
  ),
  _one(
    id: 'coronaEscudos',
    name: 'Corona de Escudos',
    unique: true,
    values: [0.04, 0.06, 0.08, 0.10, 0.12],
    describe: (v) => 'Al empezar tu turno: escudo del ${_pct(v)} de tu vida '
        'máx. por 1 turno.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onTurnStart, [
      ProcEffect(ProcEffectKind.shieldSelf,
          value: v, turns: 1, stat: BuffStat.shield)
    ], d),
  ),
  _one(
    id: 'juicioFinal',
    name: 'Juicio Final',
    unique: true,
    values: [0.50, 0.65, 0.80, 0.95, 1.10],
    describe: (v) => 'Al aturdir a un enemigo: daño sagrado MAG × '
        '${v.toStringAsFixed(2)}.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onStatusApplied,
        [ProcEffect(ProcEffectKind.holyDamage, value: v)], d,
        status: StatusKind.stun),
  ),
  _one(
    id: 'misericordia',
    name: 'Misericordia',
    unique: true,
    values: [0.04, 0.055, 0.07, 0.085, 0.10],
    describe: (v) => 'Al empezar tu turno: el aliado con menor % de vida se '
        'cura ${_pct(v)} de su vida máx.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onTurnStart,
        [ProcEffect(ProcEffectKind.healLowestAlly, value: v)], d),
  ),
  _one(
    id: 'milEras',
    name: 'Mil Eras',
    unique: true,
    values: [0.30, 0.40, 0.50, 0.60, 0.70],
    describe: (v) =>
        'Al recibir un golpe: devolvés el ${_pct(v)} del daño al atacante.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHitTaken,
        [ProcEffect(ProcEffectKind.reflect, value: v)], d),
  ),

  // ---- Exclusivos de los Jefes del Abismo v0.8 (abyss_bosses.md § 3) ----
  _one(
    id: 'tiempoPrestado',
    name: 'Tiempo Prestado',
    unique: true,
    values: [0.25, 0.30, 0.35, 0.40, 0.45],
    describe: (v) =>
        'Al detonar una reacción: tu próximo turno llega ${_pct(v)} antes.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onReaction,
        [ProcEffect(ProcEffectKind.advanceTurn, value: v)], d),
  ),
  _one(
    id: 'preparacionCompartida',
    name: 'Preparación Compartida',
    unique: true,
    values: [8, 10, 12, 14, 16],
    describe: (v) => 'Si una reacción consume un estado que preparaste: '
        '+${v.round()} carga de ULT a tus aliados.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onPrimedReaction,
        [ProcEffect(ProcEffectKind.ultChargeParty, value: v)], d),
  ),
  _one(
    id: 'luzInvertida',
    name: 'Luz Invertida',
    unique: true,
    values: [0.40, 0.50, 0.60, 0.70, 0.80],
    describe: (v) => 'Al curar a un aliado: escudo del ${_pct(v)} de lo '
        'curado por 2 turnos.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHeal, [
      ProcEffect(ProcEffectKind.shieldHealed,
          value: v, turns: 2, stat: BuffStat.shield)
    ], d),
  ),
  _one(
    id: 'hambreEterna',
    name: 'Hambre Eterna',
    unique: true,
    values: [0.20, 0.25, 0.30, 0.35, 0.40],
    describe: (v) =>
        'Cuando el grupo quiebra a un enemigo: +${_pct(v)} ATQ por 3 turnos.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onBreak, [
      ProcEffect(ProcEffectKind.buffSelf,
          value: v, turns: 3, stat: BuffStat.attack)
    ], d),
  ),
  _one(
    id: 'todasReacciones',
    name: 'Todas las Reacciones',
    unique: true,
    values: [0.40, 0.50, 0.60, 0.70, 0.80],
    describe: (v) => '+${_pct(v)} al golpe que detona una reacción.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.always,
        [ProcEffect(ProcEffectKind.reactionBonus, value: v)], d),
  ),
  _one(
    id: 'ecoGolpe',
    name: 'Eco del Golpe',
    unique: true,
    values: [0.15, 0.20, 0.25, 0.30, 0.35],
    describe: (v) => 'Al detonar una reacción: ${_pct(v)} de un turno extra.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onReaction,
        [const ProcEffect(ProcEffectKind.extraTurn)], d, chance: v),
  ),
  // Exclusivas de los legendarios del agua (fishing.md § 8.3, v0.22.2).
  _one(
    id: 'mareaHundida',
    name: 'Marea Hundida',
    unique: true,
    values: [0.20, 0.25, 0.30, 0.35, 0.40],
    describe: (v) => 'Todos tus golpes llenan el quiebre un ${_pct(v)} más.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.always,
        [ProcEffect(ProcEffectKind.breakBonus, value: v)], d),
  ),
  _one(
    id: 'engranajeAhogado',
    name: 'Engranaje Ahogado',
    unique: true,
    values: [0.10, 0.14, 0.18, 0.22, 0.26],
    describe: (v) => '${_pct(v)} de que una habilidad mágica se repita gratis '
        'al 50% del daño base.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onSkill,
        [const ProcEffect(ProcEffectKind.repeatSkill, value: 0.5)], d,
        filter: ProcFilter.magicalSkill, chance: v),
  ),
  _one(
    id: 'ecoDeOrilla',
    name: 'Eco de Orilla',
    unique: true,
    values: [0.30, 0.35, 0.40, 0.45, 0.50],
    describe: (v) => 'Tus golpes a un solo objetivo rebotan a otro enemigo con '
        'el ${_pct(v)} del daño.',
    mech: (id, n, v, d) => _m(id, n, ProcTrigger.onHit,
        [ProcEffect(ProcEffectKind.chain, value: v)], d,
        filter: ProcFilter.singleTarget),
  ),
];
