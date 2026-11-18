import '../models/passive_mechanic.dart';
import '../models/status.dart';
import 'ascension_mechanics.dart';
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
    kMechanics[id] ?? kAscensionMechanics[id] ?? weaponPassiveMechanic(id);

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
  ..._v3,
  ..._v4,
];

const _bonus = ProcEffectKind.statBonus;

/// Notables y keystones nuevos del árbol v3 (passive_tree_v3.md § 5-8).
const List<PassiveMechanic> _v3 = [
  // ---------------- Guerrero: Quiebre ----------------
  PassiveMechanic(
    id: 'rompeguardias',
    name: 'Rompeguardias',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(ProcEffectKind.breakBonus, value: 0.30)],
    description: 'Tus golpes llenan la barra de quiebre un 30% más.',
  ),
  PassiveMechanic(
    id: 'ensanamiento',
    name: 'Ensañamiento',
    trigger: ProcTrigger.vsBroken,
    effects: [ProcEffect(_bonus, value: 0.25, stat: BuffStat.damage)],
    description: '+25% de daño a enemigos quebrados (además del bonus del '
        'QUIEBRE).',
  ),
  PassiveMechanic(
    id: 'demoledor',
    name: 'Demoledor',
    trigger: ProcTrigger.onBreak,
    effects: [
      ProcEffect(ProcEffectKind.ultCharge, value: 20),
      ProcEffect(ProcEffectKind.buffSelf,
          value: 0.25, turns: 2, stat: BuffStat.attack),
    ],
    description: 'Cuando vos o un aliado quiebran a un enemigo: +20 de carga '
        'de ULT y +25% ATQ por 2 turnos (renueva). Pero −15% vida máx.',
  ),
  // ---------------- Guerrero: Gritos ----------------
  PassiveMechanic(
    id: 'clamor',
    name: 'Clamor',
    trigger: ProcTrigger.onUltimate,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.15, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al usar tu ULT: todo el grupo (vos incluido) +15% ATQ por 2 '
        'turnos.',
  ),
  PassiveMechanic(
    id: 'rugido',
    name: 'Rugido',
    trigger: ProcTrigger.onKill,
    effects: [
      ProcEffect(ProcEffectKind.ultCharge, value: 5),
      ProcEffect(ProcEffectKind.ultChargeParty, value: 8),
    ],
    description: 'Al matar: +5 de carga de ULT para vos y +8 para cada aliado '
        '(1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'caudillo',
    name: 'Caudillo',
    trigger: ProcTrigger.onTurnStart,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.12, turns: 1, stat: BuffStat.attack)
    ],
    description: 'Al empezar tu turno: todo el grupo (vos incluido) +12% ATQ '
        'por 1 turno (renueva). Pero tu ULT carga 30% menos.',
  ),
  // ---------------- Maga: Cronos ----------------
  PassiveMechanic(
    id: 'relojRoto',
    name: 'Reloj Roto',
    trigger: ProcTrigger.onDelayApplied,
    effects: [ProcEffect(ProcEffectKind.advanceTurn, value: 0.25)],
    description: 'Al retrasar a un enemigo: tu próximo turno llega 25% antes.',
  ),
  PassiveMechanic(
    id: 'pasoCompartido',
    name: 'Paso Compartido',
    trigger: ProcTrigger.onDelayApplied,
    effects: [ProcEffect(ProcEffectKind.advanceAlly, value: 0.20)],
    description: 'Al retrasar a un enemigo: el aliado más lento se adelanta '
        '20% de su espera (solo: tu próximo turno llega 20% antes).',
  ),
  PassiveMechanic(
    id: 'bucle',
    name: 'Bucle Eterno',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_bonus, value: 0.60, stat: BuffStat.delayPower)],
    description: 'Tus retrasos son 60% más largos. Pero −1 velocidad.',
  ),
  // ---------------- Maga: Prisma ----------------
  PassiveMechanic(
    id: 'refraccion',
    name: 'Refracción',
    trigger: ProcTrigger.vsElements,
    minStacks: 2,
    effects: [ProcEffect(_bonus, value: 0.15, stat: BuffStat.damage)],
    description: '+15% de daño contra enemigos con 2 o más estados '
        'elementales distintos (Quemadura, Congelación, Veneno).',
  ),
  PassiveMechanic(
    id: 'catalizador',
    name: 'Catalizador',
    trigger: ProcTrigger.onStatusApplied,
    chance: 0.5,
    effects: [ProcEffect(ProcEffectKind.addElement, value: 1)],
    description: '50% de que, al aplicar Quemadura, Congelación o Veneno, el '
        'objetivo reciba además 1 stack del primero que no tiene.',
  ),
  PassiveMechanic(
    id: 'singularidad',
    name: 'Singularidad',
    trigger: ProcTrigger.vsElements,
    minStacks: 2,
    effects: [
      ProcEffect(_bonus, value: 0.30, stat: BuffStat.damage),
      ProcEffect(_bonus, value: 0.10, stat: BuffStat.crit),
    ],
    description: 'Contra enemigos con 2 o más estados elementales distintos: '
        '+30% de daño y +10% crítico. Pero −10% MAG.',
  ),
  // ---------------- Tirador: Lluvia ----------------
  PassiveMechanic(
    id: 'aguacero',
    name: 'Aguacero',
    trigger: ProcTrigger.always,
    filter: ProcFilter.areaSkill,
    effects: [ProcEffect(_bonus, value: 0.15, stat: BuffStat.damage)],
    description: 'Tus habilidades de daño a todos (no ULT) hacen +15%.',
  ),
  PassiveMechanic(
    id: 'esquirlas',
    name: 'Esquirlas',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.areaSkill,
    effects: [ProcEffect(ProcEffectKind.advanceTurn, value: 0.20)],
    description: 'Después de una habilidad de daño a todos (no ULT): tu '
        'próximo turno llega 20% antes.',
  ),
  PassiveMechanic(
    id: 'diluvio',
    name: 'Diluvio',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.areaSkill,
    effects: [ProcEffect(ProcEffectKind.repeatSkill, value: 0.40)],
    description: 'Tus habilidades de daño a todos (no ULT) se repiten gratis '
        'al 40% del daño base (1 eco por acción). Pero −15% ATQ.',
  ),
  // ---------------- Tirador: Acecho ----------------
  PassiveMechanic(
    id: 'presaHerida',
    name: 'Presa Herida',
    trigger: ProcTrigger.vsMarked,
    effects: [ProcEffect(_bonus, value: 0.15, stat: BuffStat.damage)],
    description: '+15% de daño contra enemigos marcados.',
  ),
  PassiveMechanic(
    id: 'rematar',
    name: 'Rematar',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(ProcEffectKind.execute, value: 0.12)],
    description: 'Tus golpes a un solo objetivo rematan a enemigos (no jefes '
        'ni élites) que queden con menos de 12% de vida.',
  ),
  PassiveMechanic(
    id: 'depredador',
    name: 'Depredador',
    trigger: ProcTrigger.onHit,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.25, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Cada golpe tuyo marca al enemigo que no tenga marca: recibe '
        '+25% de daño de todos por 3 turnos. Pero −20% vida máx.',
  ),
  // ---------------- Paladín: Luz ----------------
  PassiveMechanic(
    id: 'llamaSagrada',
    name: 'Llama Sagrada',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    chance: 0.30,
    effects: [
      ProcEffect(ProcEffectKind.inflict, value: 1, status: StatusKind.holy)
    ],
    description: 'Tus golpes a un solo objetivo tienen 30% de aplicar 1 '
        'Sagrado.',
  ),
  PassiveMechanic(
    id: 'resplandor',
    name: 'Resplandor',
    trigger: ProcTrigger.vsStatus,
    status: StatusKind.holy,
    effects: [ProcEffect(_bonus, value: 0.20, stat: BuffStat.damage)],
    description: '+20% de daño contra enemigos con Sagrado.',
  ),
  PassiveMechanic(
    id: 'solInterior',
    name: 'Sol Interior',
    trigger: ProcTrigger.onHit,
    effects: [
      ProcEffect(ProcEffectKind.inflict, value: 1, status: StatusKind.holy)
    ],
    description: 'Cada golpe tuyo (ataque, habilidad, ULT) aplica 1 Sagrado. '
        'Pero −15% ATQ.',
  ),
  // ---------------- Paladín: Vigilia ----------------
  PassiveMechanic(
    id: 'guardiaAlta',
    name: 'Guardia Alta',
    trigger: ProcTrigger.onHitTaken,
    filter: ProcFilter.defending,
    effects: [
      ProcEffect(ProcEffectKind.shieldSelf,
          value: 0.10, turns: 2, stat: BuffStat.shield)
    ],
    description: 'Al recibir un golpe defendiendo: escudo del 10% de tu vida '
        'máx. por 2 turnos.',
  ),
  PassiveMechanic(
    id: 'votoHierro',
    name: 'Voto de Hierro',
    trigger: ProcTrigger.whileLowHealth,
    threshold: 0.5,
    effects: [ProcEffect(_bonus, value: 0.15, stat: BuffStat.guard)],
    description: 'Con menos de 50% de vida: recibís −15% de daño.',
  ),
  PassiveMechanic(
    id: 'inamovible',
    name: 'Inamovible',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_bonus, value: 0.25, stat: BuffStat.guard)],
    description: 'Recibís −25% de daño (suma con la defensa de grupo, tope '
        '60%). Pero −1 velocidad.',
  ),
  // ---------------- Puente Hoja Arcana (Guerrero–Maga) ----------------
  PassiveMechanic(
    id: 'filoRunico',
    name: 'Filo Rúnico',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.magicalSkill,
    effects: [
      ProcEffect(ProcEffectKind.buffSelf,
          value: 0.20, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al usar una habilidad mágica (no ULT): +20% ATQ por 2 '
        'turnos (renueva).',
  ),
  PassiveMechanic(
    id: 'hechizoAfilado',
    name: 'Hechizo Afilado',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.magicalSingle,
    effects: [
      ProcEffect(ProcEffectKind.inflict, value: 1, status: StatusKind.burn)
    ],
    description: 'Tus habilidades mágicas a un solo objetivo aplican además 1 '
        'Quemadura.',
  ),
  PassiveMechanic(
    id: 'egidaRunica',
    name: 'Égida Rúnica',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.magicalSkill,
    effects: [
      ProcEffect(ProcEffectKind.shieldSelf,
          value: 0.08, turns: 2, stat: BuffStat.shield)
    ],
    description: 'Al usar una habilidad mágica (no ULT): escudo del 8% de tu '
        'vida máx. por 2 turnos.',
  ),
  // ---------------- Puente Runas (Maga–Tirador) ----------------
  PassiveMechanic(
    id: 'ojoArcano',
    name: 'Ojo Arcano',
    trigger: ProcTrigger.always,
    filter: ProcFilter.magicalSkill,
    effects: [ProcEffect(_bonus, value: 0.15, stat: BuffStat.crit)],
    description: 'Tus habilidades mágicas (no ULT) tienen +15% crítico.',
  ),
  PassiveMechanic(
    id: 'sobrecarga',
    name: 'Sobrecarga',
    trigger: ProcTrigger.onCrit,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 8)],
    description: 'Al hacer crítico: +8 de carga de ULT (1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'disparoRunico',
    name: 'Disparo Rúnico',
    trigger: ProcTrigger.onCrit,
    filter: ProcFilter.singleTarget,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.10, turns: 2, stat: BuffStat.damageTaken)
    ],
    description: 'Al hacer crítico a un solo objetivo sin marca: lo marca '
        '(+10% de daño recibido de todos, 2 turnos).',
  ),
  // ---------------- Puente Centinela (Tirador–Paladín) ----------------
  PassiveMechanic(
    id: 'vigia',
    name: 'Ojo del Vigía',
    trigger: ProcTrigger.onHitTaken,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.15, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Al recibir un golpe: marcás al atacante si no tiene marca '
        '(+15% de daño recibido de todos, 3 turnos).',
  ),
  PassiveMechanic(
    id: 'saetaSagrada',
    name: 'Saeta Sagrada',
    trigger: ProcTrigger.onCrit,
    effects: [
      ProcEffect(ProcEffectKind.inflict, value: 1, status: StatusKind.holy)
    ],
    description: 'Al hacer crítico: +1 Sagrado al objetivo.',
  ),
  PassiveMechanic(
    id: 'cobertura',
    name: 'Cobertura',
    trigger: ProcTrigger.onTurnStart,
    effects: [
      ProcEffect(ProcEffectKind.shieldLowestAlly,
          value: 0.06, turns: 1, stat: BuffStat.shield)
    ],
    description: 'Al empezar tu turno: el aliado con menor % de vida (vos '
        'incluido) gana un escudo del 6% de tu vida máx. (1 turno).',
  ),
  // ---------------- Puente Coloso (Paladín–Guerrero) ----------------
  PassiveMechanic(
    id: 'pielPiedra',
    name: 'Piel de Piedra',
    trigger: ProcTrigger.onHitTaken,
    effects: [
      ProcEffect(ProcEffectKind.shieldSelf,
          value: 0.05, turns: 1, stat: BuffStat.shield)
    ],
    description: 'Al recibir un golpe: escudo del 5% de tu vida máx. por 1 '
        'turno (no acumula).',
  ),
  PassiveMechanic(
    id: 'desquite',
    name: 'Desquite',
    trigger: ProcTrigger.onHitTaken,
    filter: ProcFilter.belowThreshold,
    threshold: 0.5,
    effects: [ProcEffect(ProcEffectKind.reflect, value: 0.40)],
    description: 'Al recibir un golpe con menos de 50% de vida: devolvés el '
        '40% del daño al atacante.',
  ),
  PassiveMechanic(
    id: 'pesoMuerto',
    name: 'Peso Muerto',
    trigger: ProcTrigger.onHitTaken,
    effects: [
      ProcEffect(ProcEffectKind.buffSelf,
          value: 0.15, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al recibir un golpe: +15% ATQ por 2 turnos (renueva).',
  ),
  // ---------------- Grupo: Estandarte ----------------
  PassiveMechanic(
    id: 'banderaGuerra',
    name: 'Bandera de Guerra',
    trigger: ProcTrigger.partyAura,
    effects: [ProcEffect(_bonus, value: 0.05, stat: BuffStat.damage)],
    description: 'Mientras estés en pie, todo el grupo (vos incluido) hace '
        '+5% de daño.',
  ),
  PassiveMechanic(
    id: 'cargaConjunta',
    name: 'Carga Conjunta',
    trigger: ProcTrigger.onBreak,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.10, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Cuando vos o un aliado quiebran a un enemigo: todo el grupo '
        '+10% ATQ por 2 turnos.',
  ),
  // ---------------- Grupo: Sintonía ----------------
  PassiveMechanic(
    id: 'relevo',
    name: 'Relevo',
    trigger: ProcTrigger.onUltimate,
    effects: [
      ProcEffect(ProcEffectKind.ultChargeParty, value: 10),
      ProcEffect(ProcEffectKind.ultCharge, value: 5),
    ],
    description: 'Al usar tu ULT: +10 de carga de ULT a cada aliado y +5 '
        'para vos.',
  ),
  PassiveMechanic(
    id: 'alaCarga',
    name: 'A la Carga',
    trigger: ProcTrigger.onKill,
    effects: [ProcEffect(ProcEffectKind.advanceAlly, value: 0.20)],
    description: 'Al matar: el aliado más lento se adelanta 20% de su espera '
        '(solo: tu próximo turno llega 20% antes).',
  ),
  // ---------------- Grupo: Vínculo ----------------
  PassiveMechanic(
    id: 'lazoVital',
    name: 'Lazo Vital',
    trigger: ProcTrigger.onKill,
    effects: [ProcEffect(ProcEffectKind.healParty, value: 0.04)],
    description: 'Al matar: todo el grupo (vos incluido) se cura 4% de su '
        'vida máx. (1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'escudoCompartido',
    name: 'Escudo Compartido',
    trigger: ProcTrigger.onUltimate,
    effects: [
      ProcEffect(ProcEffectKind.shieldParty,
          value: 0.10, turns: 2, stat: BuffStat.shield)
    ],
    description: 'Al usar tu ULT: todo el grupo gana un escudo del 10% de tu '
        'vida máx. por 2 turnos.',
  ),
  // ---------------- Grupo: Refugio ----------------
  PassiveMechanic(
    id: 'formacion',
    name: 'Formación',
    trigger: ProcTrigger.partyAura,
    effects: [ProcEffect(_bonus, value: 0.05, stat: BuffStat.guard)],
    description: 'Mientras estés en pie, todo el grupo (vos incluido) recibe '
        '−5% de daño.',
  ),
  PassiveMechanic(
    id: 'hermandad',
    name: 'Hermandad',
    trigger: ProcTrigger.onTurnStart,
    effects: [ProcEffect(ProcEffectKind.healLowestAlly, value: 0.03)],
    description: 'Al empezar tu turno: el aliado con menor % de vida (vos '
        'incluido) se cura 3% de su vida máx.',
  ),
];

const _fxStatus = ProcEffectKind.inflict;

/// Notables nuevos del árbol v4 (passive_tree_v4.md § 3-4): el de entrada
/// (`_n1`) y el de unión (`_nc`) de cada cluster de clase y la punta
/// (`_nt`) de cada cluster de grupo. Solo disparadores y efectos que ya
/// existían.
const List<PassiveMechanic> _v4 = [
  // ---------------- Guerrero ----------------
  PassiveMechanic(
    id: 'rompeolas',
    name: 'Rompeolas',
    trigger: ProcTrigger.onHitTaken,
    filter: ProcFilter.defending,
    effects: [ProcEffect(ProcEffectKind.delayTarget, value: 0.25)],
    description: 'Al recibir un golpe defendiendo: el atacante se retrasa un '
        '25% de su espera en el timeline.',
  ),
  PassiveMechanic(
    id: 'corazaEspinas',
    name: 'Coraza de Espinas',
    trigger: ProcTrigger.onHitTaken,
    effects: [ProcEffect(ProcEffectKind.reflect, value: 0.20)],
    description: 'Al recibir cualquier golpe: devolvés el 20% del daño al '
        'atacante (suma con Contraataque).',
  ),
  PassiveMechanic(
    id: 'sangriaVital',
    name: 'Sangría',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_bonus, value: 0.10, stat: BuffStat.lifeSteal)],
    description: 'Robás el 10% del daño que hacés como vida.',
  ),
  PassiveMechanic(
    id: 'frenesiSangriento',
    name: 'Frenesí Sangriento',
    trigger: ProcTrigger.whileMissingHealth,
    effects: [ProcEffect(_bonus, value: 0.40, stat: BuffStat.damage)],
    description: 'Hacés más daño cuanta más vida te falta: hasta +40% (a '
        'media vida, +20%).',
  ),
  PassiveMechanic(
    id: 'mazazo',
    name: 'Mazazo',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    chance: 0.12,
    effects: [ProcEffect(_fxStatus, value: 1, status: StatusKind.stun)],
    description: 'Tus golpes a un solo objetivo tienen 12% de aturdirlo (el '
        'aturdimiento también llena su barra de quiebre).',
  ),
  PassiveMechanic(
    id: 'brecha',
    name: 'Brecha',
    trigger: ProcTrigger.onBreak,
    effects: [ProcEffect(ProcEffectKind.advanceAlly, value: 0.30)],
    description: 'Cuando vos o un aliado quiebran a un enemigo: el aliado más '
        'lento se adelanta 30% de su espera (solo: tu próximo turno llega '
        '30% antes).',
  ),
  PassiveMechanic(
    id: 'arenga',
    name: 'Arenga',
    trigger: ProcTrigger.onKill,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.15, turns: 2, stat: BuffStat.speed)
    ],
    description: 'Al matar: todo el grupo (vos incluido) +15% velocidad por 2 '
        'turnos (1 vez por acción).',
  ),
  PassiveMechanic(
    id: 'estruendo',
    name: 'Estruendo',
    trigger: ProcTrigger.always,
    effects: [
      ProcEffect(_bonus, value: 0.30, stat: BuffStat.buffPower),
      ProcEffect(_bonus, value: 1, stat: BuffStat.buffTurns),
    ],
    description: 'Tus buffs de grupo (Clamor, Arenga, Caudillo, gritos) son '
        '30% más fuertes y duran 1 turno más.',
  ),
  PassiveMechanic(
    id: 'estocadaPrecisa',
    name: 'Estocada Precisa',
    trigger: ProcTrigger.always,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(_bonus, value: 0.30, stat: BuffStat.critMulti)],
    description: 'Tus críticos a un solo objetivo pegan ×0.3 más (×1.8 en vez '
        'de ×1.5).',
  ),
  PassiveMechanic(
    id: 'desarme',
    name: 'Desarme',
    trigger: ProcTrigger.onCrit,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.20, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Al hacer crítico: el objetivo pega −20% ATQ por 2 turnos. '
        'No acumula.',
  ),
  // ---------------- Maga ----------------
  PassiveMechanic(
    id: 'canalizar',
    name: 'Canalizar',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.magicalSkill,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 4)],
    description: 'Cada habilidad mágica (no ULT): +4 de carga de ULT.',
  ),
  PassiveMechanic(
    id: 'pulsoArcano',
    name: 'Pulso Arcano',
    trigger: ProcTrigger.onUltimate,
    effects: [ProcEffect(ProcEffectKind.advanceTurn, value: 0.50)],
    description: 'Después de tu ULT: tu próximo turno llega 50% antes.',
  ),
  PassiveMechanic(
    id: 'ascuasVivas',
    name: 'Ascuas Vivas',
    trigger: ProcTrigger.vsStatus,
    status: StatusKind.burn,
    effects: [ProcEffect(_bonus, value: 0.15, stat: BuffStat.crit)],
    description: '+15% crítico contra enemigos con Quemadura.',
  ),
  PassiveMechanic(
    id: 'pira',
    name: 'Pira',
    trigger: ProcTrigger.onEnemyDeath,
    status: StatusKind.burn,
    effects: [ProcEffect(ProcEffectKind.spreadStatus)],
    description: 'Al morir un enemigo quemado: su Quemadura pasa al enemigo '
        'vivo con más vida.',
  ),
  PassiveMechanic(
    id: 'arenaTiempo',
    name: 'Arena del Tiempo',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    chance: 0.25,
    effects: [ProcEffect(ProcEffectKind.delayTarget, value: 0.15)],
    description: 'Tus golpes a un solo objetivo tienen 25% de retrasarlo un '
        '15% de su espera.',
  ),
  PassiveMechanic(
    id: 'anclaTemporal',
    name: 'Ancla Temporal',
    trigger: ProcTrigger.onDelayApplied,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.20, turns: 2, stat: BuffStat.speed)
    ],
    description: 'Al retrasar a un enemigo con una habilidad: queda −20% '
        'velocidad por 2 turnos (sus turnos tardan más).',
  ),
  PassiveMechanic(
    id: 'frioPenetrante',
    name: 'Frío Penetrante',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.freeze,
    chance: 0.5,
    effects: [ProcEffect(ProcEffectKind.extraStacks, value: 1)],
    description: 'Al congelar a un enemigo: 50% de +1 Congelación (con 5 '
        'pierde el turno).',
  ),
  PassiveMechanic(
    id: 'hieloQuebradizo',
    name: 'Hielo Quebradizo',
    trigger: ProcTrigger.vsStatus,
    status: StatusKind.freeze,
    effects: [ProcEffect(ProcEffectKind.breakBonus, value: 0.50)],
    description: 'Contra enemigos con Congelación tus golpes llenan la barra '
        'de quiebre un 50% más.',
  ),
  PassiveMechanic(
    id: 'chispaPrismatica',
    name: 'Chispa Prismática',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.magicalSingle,
    effects: [ProcEffect(_fxStatus, value: 1, status: StatusKind.freeze)],
    description: 'Tus habilidades mágicas a un solo objetivo aplican además 1 '
        'Congelación (2 elementos con un solo hechizo de fuego o veneno).',
  ),
  PassiveMechanic(
    id: 'descomposicion',
    name: 'Descomposición',
    trigger: ProcTrigger.onEnemyDeath,
    effects: [ProcEffect(ProcEffectKind.spreadAll, value: 0.5)],
    description: 'Al morir un enemigo: la mitad de sus Quemadura, '
        'Congelación y Veneno (redondeo arriba) pasa a todos los demás.',
  ),
  // ---------------- Tirador ----------------
  PassiveMechanic(
    id: 'vientoCortante',
    name: 'Viento Cortante',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.areaSkill,
    effects: [
      ProcEffect(ProcEffectKind.buffSelf,
          value: 0.15, turns: 2, stat: BuffStat.crit)
    ],
    description: 'Después de una habilidad de daño a todos (no ULT): +15% '
        'crítico por 2 turnos (renueva).',
  ),
  PassiveMechanic(
    id: 'huracan',
    name: 'Huracán',
    trigger: ProcTrigger.onKill,
    chance: 0.35,
    effects: [ProcEffect(ProcEffectKind.extraTurn)],
    description: 'Al matar: 35% de turno extra inmediato (un turno extra no '
        'da otro).',
  ),
  PassiveMechanic(
    id: 'lluviaAcida',
    name: 'Lluvia Ácida',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.areaSkill,
    effects: [ProcEffect(_fxStatus, value: 1, status: StatusKind.poison)],
    description: 'Tus habilidades de daño a todos (no ULT) aplican 1 Veneno a '
        'cada enemigo.',
  ),
  PassiveMechanic(
    id: 'granizo',
    name: 'Granizo',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.areaSkill,
    effects: [ProcEffect(ProcEffectKind.delayTarget, value: 0.10)],
    description: 'Tus habilidades de daño a todos (no ULT) retrasan un 10% a '
        'cada enemigo.',
  ),
  PassiveMechanic(
    id: 'tiroALaCabeza',
    name: 'Tiro a la Cabeza',
    trigger: ProcTrigger.onCrit,
    filter: ProcFilter.singleTarget,
    chance: 0.25,
    effects: [ProcEffect(_fxStatus, value: 1, status: StatusKind.stun)],
    description: 'Al hacer crítico a un solo objetivo: 25% de aturdirlo.',
  ),
  PassiveMechanic(
    id: 'grietaExpuesta',
    name: 'Grieta Expuesta',
    trigger: ProcTrigger.vsMarked,
    effects: [ProcEffect(ProcEffectKind.breakBonus, value: 0.40)],
    description: 'Contra enemigos marcados tus golpes llenan la barra de '
        'quiebre un 40% más.',
  ),
  PassiveMechanic(
    id: 'trampaCaza',
    name: 'Trampa de Caza',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    chance: 0.30,
    effects: [
      ProcEffect(ProcEffectKind.plantTrap,
          value: 0.6, turns: 2, stat: BuffStat.trap)
    ],
    description: 'Tus golpes a un solo objetivo tienen 30% de dejarle una '
        'trampa: ATQ × 0.6 al empezar su turno (2 turnos).',
  ),
  PassiveMechanic(
    id: 'caceria',
    name: 'Cacería',
    trigger: ProcTrigger.onTrap,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.20, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Cuando salta una trampa tuya: marca al enemigo si no tiene '
        'marca (+20% de daño recibido de todos, 3 turnos).',
  ),
  PassiveMechanic(
    id: 'toxinaParalizante',
    name: 'Toxina Paralizante',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.poison,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: -0.15, turns: 2, stat: BuffStat.speed)
    ],
    description: 'Al envenenar a un enemigo: −15% velocidad por 2 turnos. No '
        'acumula.',
  ),
  PassiveMechanic(
    id: 'nubeToxica',
    name: 'Nube Tóxica',
    trigger: ProcTrigger.onHit,
    status: StatusKind.poison,
    minStacks: 4,
    effects: [ProcEffect(ProcEffectKind.burst, value: 0.40)],
    description: 'Al golpear a un enemigo con 4+ Veneno: el 40% de ese golpe '
        'salpica a cada otro enemigo.',
  ),
  // ---------------- Paladín ----------------
  PassiveMechanic(
    id: 'manoLuminosa',
    name: 'Mano Luminosa',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(ProcEffectKind.healLowestAlly, value: 0.03)],
    description: 'Tus golpes a un solo objetivo curan 3% de su vida máx. al '
        'aliado con menor % de vida (vos incluido).',
  ),
  PassiveMechanic(
    id: 'estallidoSolar',
    name: 'Estallido Solar',
    trigger: ProcTrigger.onHit,
    status: StatusKind.holy,
    minStacks: 3,
    effects: [ProcEffect(ProcEffectKind.holyDamage, value: 0.50)],
    description: 'Al golpear a un enemigo con 3+ Sagrado: daño sagrado extra '
        'MAG × 0.5.',
  ),
  PassiveMechanic(
    id: 'sentencia',
    name: 'Sentencia',
    trigger: ProcTrigger.vsStatus,
    status: StatusKind.stun,
    effects: [ProcEffect(_bonus, value: 0.30, stat: BuffStat.damage)],
    description: '+30% de daño a enemigos aturdidos.',
  ),
  PassiveMechanic(
    id: 'veredicto',
    name: 'Veredicto',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.stun,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.20, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Al aturdir a un enemigo: lo marca si no tiene marca (+20% '
        'de daño recibido de todos, 3 turnos).',
  ),
  PassiveMechanic(
    id: 'comunion',
    name: 'Comunión',
    trigger: ProcTrigger.onHeal,
    effects: [ProcEffect(ProcEffectKind.healSelf, value: 0.05)],
    description: 'Cada curación tuya también te cura 5% de tu vida máx. (1 '
        'vez por acción).',
  ),
  PassiveMechanic(
    id: 'milagro',
    name: 'Milagro',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(ProcEffectKind.cheatDeath)],
    description: 'Una vez por batalla, el primer golpe que te mataría te deja '
        'en 1 HP.',
  ),
  PassiveMechanic(
    id: 'represaliaSagrada',
    name: 'Represalia Sagrada',
    trigger: ProcTrigger.onHitTaken,
    effects: [ProcEffect(_fxStatus, value: 1, status: StatusKind.holy)],
    description: 'Al recibir un golpe: +1 Sagrado al atacante.',
  ),
  PassiveMechanic(
    id: 'resiliencia',
    name: 'Resiliencia',
    trigger: ProcTrigger.whileMissingHealth,
    effects: [ProcEffect(_bonus, value: 0.30, stat: BuffStat.guard)],
    description: 'Recibís menos daño cuanta más vida te falta: hasta −30% (a '
        'media vida, −15%; tope de defensa 60%).',
  ),
  PassiveMechanic(
    id: 'puas',
    name: 'Púas',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_bonus, value: 0.40, stat: BuffStat.shieldReflect)],
    description: 'Tus escudos (los que das vos, a vos o a aliados) devuelven '
        'el 40% de lo que absorben al atacante.',
  ),
  PassiveMechanic(
    id: 'escudoSolidario',
    name: 'Escudo Solidario',
    trigger: ProcTrigger.onHitTaken,
    effects: [
      ProcEffect(ProcEffectKind.shieldLowestAlly,
          value: 0.06, turns: 1, stat: BuffStat.shield)
    ],
    description: 'Al recibir un golpe: el aliado con menor % de vida (vos '
        'incluido) gana un escudo del 6% de tu vida máx. (1 turno).',
  ),
  // ---------------- Clusters de grupo (punta) ----------------
  PassiveMechanic(
    id: 'estandarteAlzado',
    name: 'Estandarte Alzado',
    trigger: ProcTrigger.onUltimate,
    effects: [ProcEffect(ProcEffectKind.advanceParty, value: 0.25)],
    description: 'Al usar tu ULT: todos tus aliados se adelantan 25% de su '
        'espera (solo: tu próximo turno llega 25% antes).',
  ),
  PassiveMechanic(
    id: 'resonanciaGrupal',
    name: 'Resonancia',
    trigger: ProcTrigger.onBreak,
    effects: [
      ProcEffect(ProcEffectKind.ultCharge, value: 6),
      ProcEffect(ProcEffectKind.ultChargeParty, value: 6),
    ],
    description: 'Cuando vos o un aliado quiebran a un enemigo: +6 de carga de '
        'ULT para todo el grupo.',
  ),
  PassiveMechanic(
    id: 'angelGuardian',
    name: 'Ángel Guardián',
    trigger: ProcTrigger.partyAura,
    effects: [ProcEffect(ProcEffectKind.cheatDeath)],
    description: 'Una vez por batalla, mientras estés en pie, el primer golpe '
        'mortal a alguien del grupo (vos incluido) lo deja en 1 HP.',
  ),
  PassiveMechanic(
    id: 'muroEscudos',
    name: 'Muro de Escudos',
    trigger: ProcTrigger.onHitTaken,
    filter: ProcFilter.defending,
    effects: [
      ProcEffect(ProcEffectKind.shieldParty,
          value: 0.06, turns: 2, stat: BuffStat.shield)
    ],
    description: 'Al recibir un golpe defendiendo: todo el grupo gana un '
        'escudo del 6% de tu vida máx. (2 turnos).',
  ),
];
