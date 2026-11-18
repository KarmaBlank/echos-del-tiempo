import '../models/passive_mechanic.dart';
import '../models/status.dart';

// Mecánicas de los nodos de ascensión como datos (mismo sistema que los
// notables del árbol). Números en docs/specs/ascension.md § 3. El id de
// cada mecánica es el id de su nodo.

/// Mecánicas de ascensión por id.
final Map<String, PassiveMechanic> kAscensionMechanics = {
  for (final m in _list) m.id: m,
};

const _fx = ProcEffectKind.statBonus;

const List<PassiveMechanic> _list = [
  // ---------------- Guerrero · Berserker ----------------
  PassiveMechanic(
    id: 'berserker_r',
    name: 'Sed Roja',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.belowThreshold,
    threshold: 0.5,
    effects: [ProcEffect(ProcEffectKind.advanceTurn, value: 0.5)],
    description: 'Con menos de 50% de vida, cada acción que golpea hace que '
        'tu próximo turno llegue 50% antes (turno parcial).',
  ),
  PassiveMechanic(
    id: 'berserker_a1',
    name: 'Furia Creciente',
    trigger: ProcTrigger.whileMissingHealth,
    effects: [ProcEffect(_fx, value: 0.8, stat: BuffStat.damage)],
    description: '+0.8% de daño por cada 1% de vida que te falta (con 10% '
        'de vida: +72%).',
  ),
  PassiveMechanic(
    id: 'berserker_a2',
    name: 'Golpe Desesperado',
    trigger: ProcTrigger.whileLowHealth,
    threshold: 0.3,
    effects: [ProcEffect(_fx, value: 1.0, stat: BuffStat.crit)],
    description: 'Con menos de 30% de vida todos tus golpes son críticos.',
  ),
  PassiveMechanic(
    id: 'berserker_a3',
    name: 'Carnicero',
    trigger: ProcTrigger.onKill,
    effects: [ProcEffect(ProcEffectKind.extraTurn)],
    description: 'Al matar: turno extra inmediato (uno por acción; un turno '
        'extra no da otro).',
  ),
  PassiveMechanic(
    id: 'berserker_b1',
    name: 'Sangre por Sangre',
    trigger: ProcTrigger.whileLowHealth,
    threshold: 0.5,
    effects: [ProcEffect(_fx, value: 0.30, stat: BuffStat.lifeSteal)],
    description: 'Con menos de 50% de vida robás 30% del daño que hacés.',
  ),
  PassiveMechanic(
    id: 'berserker_b2',
    name: 'Cicatrices',
    trigger: ProcTrigger.onHitTaken,
    filter: ProcFilter.belowThreshold,
    threshold: 0.5,
    effects: [
      ProcEffect(ProcEffectKind.shieldSelf,
          value: 0.12, turns: 1, stat: BuffStat.shield)
    ],
    description: 'Al recibir un golpe con menos de 50% de vida: escudo del '
        '12% de tu vida máx. (1 turno).',
  ),
  PassiveMechanic(
    id: 'berserker_b3',
    name: 'Inmortal',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(ProcEffectKind.cheatDeath)],
    description: 'El primer golpe que te dejaría en 0 te deja en 1 HP (1 vez '
        'por batalla).',
  ),
  PassiveMechanic(
    id: 'berserker_k',
    name: 'Berserker Desatado',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.belowThreshold,
    threshold: 0.5,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 15)],
    description: 'Con menos de 50% de vida, cada acción que golpea da +15 de '
        'carga de ULT.',
  ),
  // ---------------- Guerrero · Señor de la Guerra ----------------
  PassiveMechanic(
    id: 'senorGuerra_r',
    name: 'Voz de Mando',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.rallySkill,
    effects: [ProcEffect(ProcEffectKind.advanceParty, value: 0.25)],
    description: 'Tus gritos (habilidades de grupo y tu ULT) adelantan a cada '
        'aliado 25% de su espera (solo: tu propio próximo turno).',
  ),
  PassiveMechanic(
    id: 'senorGuerra_a1',
    name: 'Eco del Grito',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_fx, value: 1, stat: BuffStat.buffTurns)],
    description: 'Tus buffs de grupo duran +1 turno.',
  ),
  PassiveMechanic(
    id: 'senorGuerra_a2',
    name: 'Inspiración',
    trigger: ProcTrigger.onTurnStart,
    effects: [ProcEffect(ProcEffectKind.ultChargeParty, value: 6)],
    description: 'Al empezar tu turno, cada aliado (no vos) gana +6 de carga '
        'de ULT.',
  ),
  PassiveMechanic(
    id: 'senorGuerra_a3',
    name: 'Estratega',
    trigger: ProcTrigger.onBreak,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.20, turns: 2, stat: BuffStat.attack)
    ],
    description: 'Cuando cualquier aliado quiebra a un enemigo: +20% ATQ a '
        'todo el grupo (2 turnos).',
  ),
  PassiveMechanic(
    id: 'senorGuerra_b1',
    name: 'Bandera Firme',
    trigger: ProcTrigger.partyAura,
    effects: [ProcEffect(_fx, value: 0.10, stat: BuffStat.guard)],
    description: 'Mientras estés en pie, todo el grupo recibe −10% de daño.',
  ),
  PassiveMechanic(
    id: 'senorGuerra_b2',
    name: 'Muralla de Voces',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.rallySkill,
    effects: [
      ProcEffect(ProcEffectKind.shieldParty,
          value: 0.08, turns: 2, stat: BuffStat.shield)
    ],
    description: 'Tus gritos dan a cada aliado un escudo del 8% de tu vida '
        'máx. (2 turnos).',
  ),
  PassiveMechanic(
    id: 'senorGuerra_b3',
    name: 'Último Bastión',
    trigger: ProcTrigger.onAllyDown,
    effects: [
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.30, turns: 3, stat: BuffStat.attack),
      ProcEffect(ProcEffectKind.buffParty,
          value: 0.20, turns: 3, stat: BuffStat.guard),
    ],
    description: 'Cuando cae un aliado: el resto gana +30% ATQ y −20% de daño '
        'recibido (3 turnos).',
  ),
  PassiveMechanic(
    id: 'senorGuerra_k',
    name: 'Señor de la Guerra',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_fx, value: 0.5, stat: BuffStat.buffPower)],
    description: 'Tus buffs de grupo son 50% más fuertes.',
  ),
  // ---------------- Maga · Cronomante ----------------
  PassiveMechanic(
    id: 'cronomante_r',
    name: 'Bucle Temporal',
    trigger: ProcTrigger.onDelayApplied,
    effects: [ProcEffect(ProcEffectKind.advanceAlly, value: 0.30)],
    description: 'Tus habilidades que retrasan también adelantan al aliado '
        'más lento 30% de su espera (solo: tu próximo turno).',
  ),
  PassiveMechanic(
    id: 'cronomante_a1',
    name: 'Ecos del Reloj',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_fx, value: 0.5, stat: BuffStat.delayPower)],
    description: 'Tus retrasos son 50% más largos.',
  ),
  PassiveMechanic(
    id: 'cronomante_a2',
    name: 'Ancla del Tiempo',
    trigger: ProcTrigger.onDelayApplied,
    effects: [ProcEffect(ProcEffectKind.drainUlt, value: 20)],
    description: 'Al retrasar a un enemigo con ULT, pierde 20 de carga (si '
        'ya la avisó, no).',
  ),
  PassiveMechanic(
    id: 'cronomante_a3',
    name: 'Tiempo Robado',
    trigger: ProcTrigger.onDelayApplied,
    effects: [ProcEffect(ProcEffectKind.advanceTurn, value: 0.35)],
    description: 'Al retrasar: tu próximo turno llega 35% antes.',
  ),
  PassiveMechanic(
    id: 'cronomante_b1',
    name: 'Sincronía',
    trigger: ProcTrigger.onTurnStart,
    effects: [ProcEffect(ProcEffectKind.advanceAlly, value: 0.15)],
    description: 'Al empezar tu turno, el aliado más lento se adelanta 15%.',
  ),
  PassiveMechanic(
    id: 'cronomante_b2',
    name: 'Contratiempo',
    trigger: ProcTrigger.onHitTaken,
    effects: [ProcEffect(ProcEffectKind.delayTarget, value: 0.30)],
    description: 'Al recibir un golpe, el atacante se retrasa 30%.',
  ),
  PassiveMechanic(
    id: 'cronomante_b3',
    name: 'Instante Eterno',
    trigger: ProcTrigger.onUltimate,
    effects: [ProcEffect(ProcEffectKind.advanceParty, value: 1.0)],
    description: 'Al usar tu ULT, todos los aliados actúan ya (solo: tu '
        'próximo turno llega 50% antes).',
  ),
  PassiveMechanic(
    id: 'cronomante_k',
    name: 'Desfase',
    trigger: ProcTrigger.onDelayApplied,
    effects: [
      ProcEffect(ProcEffectKind.debuffTarget,
          value: 0.20, turns: 2, stat: BuffStat.damageTaken)
    ],
    description: 'Los enemigos que retrasás reciben +20% de daño de todos (2 '
        'turnos).',
  ),
  // ---------------- Maga · Elementalista ----------------
  PassiveMechanic(
    id: 'elementalista_r',
    name: 'Reacción Elemental',
    trigger: ProcTrigger.vsElements,
    minStacks: 2,
    effects: [ProcEffect(_fx, value: 0.30, stat: BuffStat.damage)],
    description: '+30% de daño contra enemigos con 2 o más estados '
        'elementales distintos.',
  ),
  PassiveMechanic(
    id: 'elementalista_a1',
    name: 'Contagio Elemental',
    trigger: ProcTrigger.onStatusApplied,
    effects: [ProcEffect(ProcEffectKind.addElement, value: 1)],
    description: 'Al aplicar Quemadura, Congelación o Veneno, el objetivo '
        'recibe además 1 stack del primero que no tiene.',
  ),
  PassiveMechanic(
    id: 'elementalista_a3',
    name: 'Detonación',
    trigger: ProcTrigger.onEnemyDeath,
    effects: [ProcEffect(ProcEffectKind.spreadAll, value: 0.5)],
    description: 'Al morir un enemigo con estados elementales, la mitad de '
        'cada uno pasa a cada enemigo vivo.',
  ),
  PassiveMechanic(
    id: 'elementalista_b1',
    name: 'Estallido Glacial',
    trigger: ProcTrigger.onHit,
    status: StatusKind.freeze,
    minStacks: 3,
    effects: [ProcEffect(ProcEffectKind.explode, value: 0.6)],
    description: 'Golpear a un enemigo con 3+ Congelación lo hace estallar: '
        '60% del golpe a cada otro enemigo.',
  ),
  PassiveMechanic(
    id: 'elementalista_b2',
    name: 'Fiebre',
    trigger: ProcTrigger.vsStatus,
    status: StatusKind.burn,
    effects: [ProcEffect(_fx, value: 0.25, stat: BuffStat.crit)],
    description: '+25% de crítico contra enemigos con Quemadura.',
  ),
  PassiveMechanic(
    id: 'elementalista_b3',
    name: 'Eco Elemental',
    trigger: ProcTrigger.onSkill,
    filter: ProcFilter.magicalSkill,
    chance: 0.35,
    effects: [ProcEffect(ProcEffectKind.repeatSkill, value: 0.6)],
    description: '35% de que una habilidad mágica (no ULT) se repita gratis '
        'al 60%.',
  ),
  PassiveMechanic(
    id: 'elementalista_k',
    name: 'Tormenta Perfecta',
    trigger: ProcTrigger.vsElements,
    minStacks: 3,
    effects: [
      ProcEffect(_fx, value: 0.5, stat: BuffStat.damage),
      ProcEffect(_fx, value: 0.25, stat: BuffStat.crit),
    ],
    description: 'Contra enemigos con los 3 estados: +50% de daño y +25% de '
        'crítico.',
  ),
  // ---------------- Tirador · Francotirador ----------------
  PassiveMechanic(
    id: 'francotirador_r',
    name: 'Un Disparo, Una Baja',
    trigger: ProcTrigger.always,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(_fx, value: 0.75, stat: BuffStat.critMulti)],
    description: 'En acciones a un solo objetivo tus críticos hacen +0.75 de '
        'multiplicador.',
  ),
  PassiveMechanic(
    id: 'francotirador_a1',
    name: 'Marca Letal',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    effects: [
      ProcEffect(ProcEffectKind.markTarget,
          value: 0.15, turns: 3, stat: BuffStat.damageTaken)
    ],
    description: 'Tu golpe a un solo objetivo lo marca: +15% de daño '
        'recibido (3 turnos).',
  ),
  PassiveMechanic(
    id: 'francotirador_a2',
    name: 'Tiro Seguro',
    trigger: ProcTrigger.vsMarked,
    effects: [ProcEffect(_fx, value: 0.40, stat: BuffStat.crit)],
    description: '+40% de crítico contra enemigos marcados.',
  ),
  PassiveMechanic(
    id: 'francotirador_a3',
    name: 'Ejecución',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(ProcEffectKind.execute, value: 0.20)],
    description: 'Tus golpes a un solo objetivo rematan a enemigos (no jefes '
        'ni élites) que queden con menos de 20% de vida.',
  ),
  PassiveMechanic(
    id: 'francotirador_b1',
    name: 'Recarga',
    trigger: ProcTrigger.onCrit,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 15)],
    description: 'Al hacer crítico: +15 de carga de ULT.',
  ),
  PassiveMechanic(
    id: 'francotirador_b2',
    name: 'Concentración',
    trigger: ProcTrigger.onCrit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(ProcEffectKind.advanceTurn, value: 0.30)],
    description: 'Al hacer crítico a un solo objetivo: tu próximo turno llega '
        '30% antes.',
  ),
  PassiveMechanic(
    id: 'francotirador_b3',
    name: 'Disparo Perforante',
    trigger: ProcTrigger.onCrit,
    filter: ProcFilter.singleTarget,
    effects: [ProcEffect(ProcEffectKind.chain, value: 0.75)],
    description: 'Al hacer crítico a un solo objetivo: el disparo atraviesa '
        'al siguiente enemigo con el 75% del daño.',
  ),
  PassiveMechanic(
    id: 'francotirador_k',
    name: 'Leyenda del Gatillo',
    trigger: ProcTrigger.onCrit,
    effects: [
      ProcEffect(ProcEffectKind.buffSelf,
          value: 0.5, turns: 2, stat: BuffStat.critMulti)
    ],
    description: 'Al hacer crítico: +0.5 de multiplicador de crítico (2 '
        'turnos, renueva).',
  ),
  // ---------------- Tirador · Trampero ----------------
  PassiveMechanic(
    id: 'trampero_r',
    name: 'Maestro de Trampas',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.singleTarget,
    effects: [
      ProcEffect(ProcEffectKind.plantTrap,
          value: 0.6, turns: 1, stat: BuffStat.trap)
    ],
    description: 'Tus golpes a un solo objetivo le dejan una trampa de ATQ × '
        '0.6 (salta al empezar su turno).',
  ),
  PassiveMechanic(
    id: 'trampero_a1',
    name: 'Púas Envenenadas',
    trigger: ProcTrigger.onTrap,
    effects: [
      ProcEffect(ProcEffectKind.inflict, value: 2, status: StatusKind.poison)
    ],
    description: 'Tus trampas aplican 2 Veneno al saltar.',
  ),
  PassiveMechanic(
    id: 'trampero_a2',
    name: 'Trampa Persistente',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_fx, value: 1, stat: BuffStat.trapTurns)],
    description: 'Tus trampas saltan 1 turno más.',
  ),
  PassiveMechanic(
    id: 'trampero_a3',
    name: 'Detonador',
    trigger: ProcTrigger.onTrap,
    effects: [ProcEffect(ProcEffectKind.burst, value: 0.5)],
    description: 'Al saltar una trampa, explota: 50% de su daño a cada otro '
        'enemigo.',
  ),
  PassiveMechanic(
    id: 'trampero_b1',
    name: 'Lluvia Constante',
    trigger: ProcTrigger.always,
    filter: ProcFilter.areaSkill,
    effects: [ProcEffect(_fx, value: 0.25, stat: BuffStat.damage)],
    description: 'Tus habilidades a todos (no ULT) hacen +25% de daño.',
  ),
  PassiveMechanic(
    id: 'trampero_b2',
    name: 'Fragmentación',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.areaSkill,
    effects: [
      ProcEffect(ProcEffectKind.inflict, value: 1, status: StatusKind.poison)
    ],
    description: 'Tus habilidades a todos aplican 1 Veneno a cada golpeado.',
  ),
  PassiveMechanic(
    id: 'trampero_b3',
    name: 'Campo de Muerte',
    trigger: ProcTrigger.onHit,
    filter: ProcFilter.areaSkill,
    effects: [
      ProcEffect(ProcEffectKind.plantTrap,
          value: 0.4, turns: 1, stat: BuffStat.trap)
    ],
    description: 'Tus habilidades a todos dejan una trampa de ATQ × 0.4 en '
        'cada golpeado.',
  ),
  PassiveMechanic(
    id: 'trampero_k',
    name: 'Cazador Supremo',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_fx, value: 0.8, stat: BuffStat.trapPower)],
    description: 'Tus trampas hacen +80% de daño.',
  ),
  // ---------------- Paladín · Templario ----------------
  PassiveMechanic(
    id: 'templario_r',
    name: 'Martillo de la Fe',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.stun,
    effects: [
      ProcEffect(ProcEffectKind.holyDamage, value: 0.8),
      ProcEffect(ProcEffectKind.inflict, value: 1, status: StatusKind.holy),
    ],
    description: 'Al aturdir a un enemigo: daño sagrado MAG × 0.8 y +1 '
        'Sagrado.',
  ),
  PassiveMechanic(
    id: 'templario_a1',
    name: 'Condena',
    trigger: ProcTrigger.vsStatus,
    status: StatusKind.stun,
    effects: [ProcEffect(_fx, value: 0.35, stat: BuffStat.damage)],
    description: '+35% de daño a enemigos aturdidos.',
  ),
  PassiveMechanic(
    id: 'templario_a2',
    name: 'Fervor',
    trigger: ProcTrigger.onStatusApplied,
    status: StatusKind.stun,
    effects: [ProcEffect(ProcEffectKind.ultCharge, value: 12)],
    description: 'Al aturdir: +12 de carga de ULT.',
  ),
  PassiveMechanic(
    id: 'templario_a3',
    name: 'Sentencia',
    trigger: ProcTrigger.vsStatus,
    status: StatusKind.stun,
    effects: [ProcEffect(ProcEffectKind.breakBonus, value: 1.0)],
    description: 'Tus golpes a aturdidos llenan la barra de quiebre al doble.',
  ),
  PassiveMechanic(
    id: 'templario_b1',
    name: 'Aura Sagrada',
    trigger: ProcTrigger.partyAura,
    effects: [ProcEffect(_fx, value: 0.10, stat: BuffStat.damage)],
    description: 'Mientras estés en pie, todo el grupo hace +10% de daño.',
  ),
  PassiveMechanic(
    id: 'templario_b2',
    name: 'Penitencia',
    trigger: ProcTrigger.onHitTaken,
    effects: [
      ProcEffect(ProcEffectKind.inflict, value: 2, status: StatusKind.holy)
    ],
    description: 'Al recibir un golpe, el atacante recibe 2 Sagrado.',
  ),
  PassiveMechanic(
    id: 'templario_b3',
    name: 'Ira Divina',
    trigger: ProcTrigger.partyAura,
    effects: [ProcEffect(_fx, value: 1.0, stat: BuffStat.holyPower)],
    description: 'Mientras estés en pie, el Sagrado de los enemigos hace el '
        'doble por turno.',
  ),
  PassiveMechanic(
    id: 'templario_k',
    name: 'Avatar de Luz',
    trigger: ProcTrigger.onUltimate,
    effects: [
      ProcEffect(ProcEffectKind.healParty, value: 0.20),
      ProcEffect(ProcEffectKind.shieldParty,
          value: 0.10, turns: 3, stat: BuffStat.shield),
    ],
    description: 'Al usar tu ULT: el grupo se cura 20% y gana un escudo del '
        '10% de tu vida máx. (3 turnos).',
  ),
  // ---------------- Paladín · Guardián ----------------
  PassiveMechanic(
    id: 'guardian_r',
    name: 'Escudo Viviente',
    trigger: ProcTrigger.onTurnStart,
    effects: [
      ProcEffect(ProcEffectKind.shieldLowestAlly,
          value: 0.10, turns: 2, stat: BuffStat.shield)
    ],
    description: 'Al empezar tu turno, el aliado con menor % de vida (vos '
        'incluido) gana un escudo del 10% de tu vida máx. (2 turnos).',
  ),
  PassiveMechanic(
    id: 'guardian_a1',
    name: 'Égida Reflectante',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_fx, value: 0.5, stat: BuffStat.shieldReflect)],
    description: 'Cuando un escudo tuyo absorbe un golpe, el atacante recibe '
        'el 50% de lo absorbido.',
  ),
  PassiveMechanic(
    id: 'guardian_a2',
    name: 'Escudos Duraderos',
    trigger: ProcTrigger.always,
    effects: [ProcEffect(_fx, value: 0.30, stat: BuffStat.shieldPower)],
    description: 'Tus escudos son 30% más grandes.',
  ),
  PassiveMechanic(
    id: 'guardian_a3',
    name: 'Bastión Inquebrantable',
    trigger: ProcTrigger.partyAura,
    effects: [ProcEffect(_fx, value: 0.15, stat: BuffStat.guard)],
    description: 'Mientras estés en pie, todo el grupo recibe −15% de daño.',
  ),
  PassiveMechanic(
    id: 'guardian_b1',
    name: 'Represalia del Guardián',
    trigger: ProcTrigger.onProtectHit,
    effects: [ProcEffect(ProcEffectKind.reflect, value: 0.6)],
    description: 'Al recibir un golpe dirigido a un aliado (Protección): '
        'devolvés el 60%.',
  ),
  PassiveMechanic(
    id: 'guardian_b2',
    name: 'Muralla Viviente',
    trigger: ProcTrigger.onTurnStart,
    effects: [
      ProcEffect(ProcEffectKind.shieldParty,
          value: 0.06, turns: 1, stat: BuffStat.shield)
    ],
    description: 'Al empezar tu turno, todo el grupo gana un escudo del 6% de '
        'tu vida máx. (1 turno).',
  ),
  PassiveMechanic(
    id: 'guardian_b3',
    name: 'Mártir',
    trigger: ProcTrigger.partyAura,
    effects: [ProcEffect(ProcEffectKind.cheatDeath)],
    description: 'El primer aliado (o vos) que caería por un golpe queda en 1 '
        'HP (1 vez por batalla).',
  ),
  PassiveMechanic(
    id: 'guardian_k',
    name: 'Juramento Eterno',
    trigger: ProcTrigger.partyAura,
    effects: [ProcEffect(_fx, value: 0.25, stat: BuffStat.shareDamage)],
    description: 'Mientras estés en pie, recibís el 25% del daño que reciben '
        'tus aliados (tus escudos lo absorben).',
  ),
];
