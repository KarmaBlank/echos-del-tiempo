import '../models/passive_mechanic.dart';
import '../models/status.dart';
import 'weapon_passives.dart';

// Notables y keystones v2 como datos: disparador + filtro + efectos.
// Números exactos en docs/specs/passive_tree_v2.md § 3 y § 4.

/// Mecánicas por id (el mismo id que usan `PassiveNode.mechanicId` y las
/// keystones nuevas).
final Map<String, PassiveMechanic> kMechanics = {
  for (final m in _list) m.id: m,
};

/// Una mecánica por id: del árbol ([kMechanics]) o de una pasiva de arma
/// (`wp:<pasiva>:<nivel>`, ver weapon_passives.dart).
PassiveMechanic? mechanicById(String id) =>
    kMechanics[id] ?? weaponPassiveMechanic(id);

const List<PassiveMechanic> _list = [
  // ---------------- Guerrero: Filo ----------------
  PassiveMechanic(
    id: 'frenesi',
    name: 'Frenesí',
    trigger: ProcTrigger.onCrit,
    effects: [
      ProcEffect(ProcEffectKind.buffSelf,
          value: 0.20, turns: 2, stat: BuffStat.speed)
    ],
    description: 'Al hacer crítico: +20% velocidad por 2 turnos (tu próximo '
        'turno llega antes). No acumula: renueva.',
  ),
  PassiveMechanic(
    id: 'corteCadena',
    name: 'Corte en Cadena',
    trigger: ProcTrigger.onCrit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(ProcEffectKind.chain, value: 0.50)],
    description: 'Al hacer crítico a un solo objetivo: el golpe rebota a '
        'otro enemigo con el 50% del daño.',
  ),
  PassiveMechanic(
    id: 'danza',
    name: 'Danza de Cuchillas',
    trigger: ProcTrigger.onCrit,
    effects: [ProcEffect(ProcEffectKind.extraTurn)],
    description: 'Cada crítico te da otro turno inmediato (un turno extra no '
        'da otro). Pero tu crítico máximo baja a 40%.',
  ),
  // ---------------- Guerrero: Sangre ----------------
  PassiveMechanic(
    id: 'ultimoAliento',
    name: 'Último Aliento',
    trigger: ProcTrigger.whileLowHealth,
    threshold: 0.30,
    effects: [
      ProcEffect(ProcEffectKind.statBonus, value: 0.25, stat: BuffStat.attack),
      ProcEffect(ProcEffectKind.statBonus, value: 0.10, stat: BuffStat.crit),
    ],
    description: 'Con menos de 30% de vida: +25% ATQ y +10% crítico.',
  ),
  PassiveMechanic(
    id: 'sedSangre',
    name: 'Sed de Sangre',
    trigger: ProcTrigger.onKill,
    effects: [
      ProcEffect(ProcEffectKind.advanceTurn, value: 0.50),
      ProcEffect(ProcEffectKind.healSelf, value: 0.10)
    ],
    description: 'Al matar: tu próximo turno llega un 50% antes y te curás '
        '10% de tu vida máx. (1 vez por acción).',
  ),
  // ---------------- Guerrero: Muralla ----------------
  PassiveMechanic(
    id: 'contraataque',
    name: 'Contraataque',
    trigger: ProcTrigger.onHitTaken,
    filter: ProcFilter.defending,
    effects: [ProcEffect(ProcEffectKind.reflect, value: 0.50)],
    description: 'Al recibir un golpe defendiendo: devolvés el 50% del daño '
        'al atacante.',
  ),
  PassiveMechanic(
    id: 'represalia',
    name: 'Represalia',
    trigger: ProcTrigger.onHitTaken,
    effects: [
      ProcEffect(ProcEffectKind.buffSelf,
          value: 0.30, turns: 1, stat: BuffStat.attack)
    ],
    description: 'Al recibir un golpe: +30% ATQ por 1 turno. No acumula.',
  ),
  // ---------------- Maga: Brasa ----------------
  PassiveMechanic(
    id: 'combustion',
    name: 'Combustión',
    trigger: ProcTrigger.onHit,
    status: StatusKind.burn,
    minStacks: 3,
    effects: [ProcEffect(ProcEffectKind.explode, value: 0.50)],
    description: 'Al golpear a un enemigo que ya tenía 3+ Quemadura: explota '
        'y hace el 50% de ese golpe a cada otro enemigo (1 por acción).',
  ),
  PassiveMechanic(
    id: 'choqueTermico',
    name: 'Choque Térmico',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.burn,
    effects: [ProcEffect(ProcEffectKind.shatterStun)],
    description: 'Quemar a un enemigo con Congelación le quita toda la '
        'Congelación y lo aturde.',
  ),
  // ---------------- Maga: Escarcha ----------------
  PassiveMechanic(
    id: 'tiempoGelido',
    name: 'Tiempo Gélido',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.freeze,
    effects: [ProcEffect(ProcEffectKind.delayTarget, value: 0.20)],
    description: 'Al congelar a un enemigo: se retrasa un 20% de su espera '
        'en el timeline.',
  ),
  PassiveMechanic(
    id: 'fractura',
    name: 'Fractura',
    trigger: ProcTrigger.vsStatus,
    status: StatusKind.freeze,
    effects: [
      ProcEffect(ProcEffectKind.statBonus, value: 0.25, stat: BuffStat.damage)
    ],
    description: 'Tus golpes a enemigos con Congelación hacen +25% de daño.',
  ),
  PassiveMechanic(
    id: 'almaHielo',
    name: 'Alma de Hielo',
    trigger: ProcTrigger.onTurnStart,
    effects: [],
    description: 'Mientras estés en pie, la Congelación de los enemigos no se '
        'derrite sola. Pero no podés aplicar Quemadura.',
  ),
  // ---------------- Maga: Arcano ----------------
  PassiveMechanic(
    id: 'arcoVoltaico',
    name: 'Arco Voltaico',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.magicalSingle,
    effects: [ProcEffect(ProcEffectKind.chain, value: 0.50)],
    description: 'Tus habilidades mágicas a un solo objetivo rebotan a otro '
        'enemigo con el 50% del daño.',
  ),
  PassiveMechanic(
    id: 'ecoArcano',
    name: 'Eco Arcano',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.magicalSkill,
    chance: 0.20,
    effects: [ProcEffect(ProcEffectKind.repeatSkill, value: 0.50)],
    description: '20% de que una habilidad mágica (no ULT) se repita gratis: '
        '50% del daño base, mismos objetivos, vuelve a aplicar su estado.',
  ),
  // ---------------- Tirador: Precisión ----------------
  PassiveMechanic(
    id: 'marcaCazador',
    name: 'Marca del Cazador',
    trigger: ProcTrigger.onHit,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.15, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Tu primer golpe a un enemigo sin marca lo marca: recibe '
        '+15% de daño de todos por 3 turnos.',
  ),
  PassiveMechanic(
    id: 'puntoDebil',
    name: 'Punto Débil',
    trigger: ProcTrigger.vsMarked,
    effects: [
      ProcEffect(ProcEffectKind.statBonus, value: 0.20, stat: BuffStat.crit)
    ],
    description: '+20% crítico contra enemigos marcados.',
  ),
  // ---------------- Tirador: Toxina ----------------
  PassiveMechanic(
    id: 'debilitar',
    name: 'Debilitar',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.poison,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.15, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al envenenar a un enemigo: pega −15% ATQ por 2 turnos. No '
        'acumula.',
  ),
  PassiveMechanic(
    id: 'plagaContagiosa',
    name: 'Plaga Contagiosa',
    trigger: ProcTrigger.onEnemyDeath,
    status: StatusKind.poison,
    effects: [ProcEffect(ProcEffectKind.spreadStatus)],
    description: 'Al morir un enemigo envenenado: sus stacks de Veneno pasan '
        'al enemigo vivo con más vida.',
  ),
  // ---------------- Tirador: Viento ----------------
  PassiveMechanic(
    id: 'vientoFavor',
    name: 'Viento a Favor',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.areaSkill,
    effects: [ProcEffect(ProcEffectKind.freeAttack)],
    description: 'Después de una habilidad de daño a todos (no ULT): ataque '
        'básico gratis al enemigo con menos vida.',
  ),
  PassiveMechanic(
    id: 'rebote',
    name: 'Rebote',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(ProcEffectKind.chain, value: 0.40)],
    description: 'Tus golpes a un solo objetivo rebotan a otro enemigo con el '
        '40% del daño (1 salto).',
  ),
  PassiveMechanic(
    id: 'cadena',
    name: 'Cadena Infinita',
    trigger: ProcTrigger.onHit,
    effects: [],
    description: 'Tus rebotes saltan a todos los enemigos (cada salto 60% del '
        'anterior). Pero tus acciones a un solo objetivo hacen −20%.',
  ),
  // ---------------- Paladín: Fe ----------------
  PassiveMechanic(
    id: 'manoSanadora',
    name: 'Mano Sanadora',
    trigger: ProcTrigger.onHeal,
    effects: [
      ProcEffect(ProcEffectKind.shieldHealed,
          value: 0.20, turns: 3, stat: BuffStat.shield)
    ],
    description: 'Tus habilidades de curación dan un escudo del 20% de lo '
        'curado por 3 turnos.',
  ),
  PassiveMechanic(
    id: 'plegaria',
    name: 'Plegaria',
    trigger: ProcTrigger.onTurnStart,
    effects: [ProcEffect(ProcEffectKind.healLowestAlly, value: 0.05)],
    description: 'Al empezar tu turno: el aliado con menor % de vida se cura '
        '5% de su vida máx.',
  ),
  // ---------------- Paladín: Bastión ----------------
  PassiveMechanic(
    id: 'guardian',
    name: 'Guardián',
    trigger: ProcTrigger.onProtectHit,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 8)],
    description: 'Cuando recibís un golpe dirigido a un aliado bajo tu '
        'Protección: +8 carga de ULT.',
  ),
  PassiveMechanic(
    id: 'desafio',
    name: 'Desafío',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.guardSkill,
    effects: [
      ProcEffect(ProcEffectKind.shieldSelf,
          value: 0.15, turns: 2, stat: BuffStat.shield)
    ],
    description: 'Al usar Provocar, Protección o Escudo de Fe: escudo del 15% '
        'de tu vida máx. por 2 turnos.',
  ),
  PassiveMechanic(
    id: 'egida',
    name: 'Égida Eterna',
    trigger: ProcTrigger.onTurnStart,
    effects: [
      ProcEffect(ProcEffectKind.shieldSelf,
          value: 0.10, turns: 1, stat: BuffStat.shield)
    ],
    description: 'Al empezar tu turno: escudo del 10% de tu vida máx. por 1 '
        'turno (no acumula). Pero −20% ATQ y −20% MAG.',
  ),
  // ---------------- Paladín: Juicio ----------------
  PassiveMechanic(
    id: 'martilloBendito',
    name: 'Martillo Bendito',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.stun,
    effects: [
      ProcEffect(ProcEffectKind.stunExtend, turns: 1, stat: BuffStat.stunLock)
    ],
    description: 'Tus aturdimientos duran 1 turno más (no a jefes).',
  ),
  PassiveMechanic(
    id: 'castigoDivino',
    name: 'Castigo Divino',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.stun,
    effects: [ProcEffect(ProcEffectKind.holyDamage, value: 0.60)],
    description: 'Al aturdir a un enemigo: daño sagrado MAG × 0.6.',
  ),
];
