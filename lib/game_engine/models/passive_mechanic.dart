import '../data/enemy_families.dart' show EnemyFamily;
import 'elements.dart' show ReactionKind;
import 'status.dart';

/// Cuándo se evalúa una mecánica del árbol (notable o keystone v2). Ver
/// docs/specs/passive_tree_v2.md § 5.
enum ProcTrigger {
  /// Un golpe primario tuyo salió crítico.
  onCrit,

  /// Un golpe primario tuyo le pegó a un enemigo.
  onHit,

  /// Murió algún enemigo durante tu acción (1 vez por acción).
  onKill,

  /// Murió un enemigo por cualquier causa (el dueño está vivo).
  onEnemyDeath,

  /// Recibiste un golpe enemigo.
  onHitTaken,

  /// Recibiste un golpe dirigido a un aliado (Protección).
  onProtectHit,

  /// Un golpe primario tuyo aplicó un estado a un enemigo.
  onStatusApplied,

  /// Usaste una habilidad (después de resolverla).
  onSkill,

  /// Una habilidad tuya curó a un aliado.
  onHeal,

  /// Empieza tu turno (después de los estados, si seguís vivo).
  onTurnStart,

  /// Condición: tu vida está por debajo de `threshold` al actuar.
  whileLowHealth,

  /// Condición: el objetivo tiene el estado `status`.
  vsStatus,

  /// Condición: el objetivo está marcado.
  vsMarked,

  /// Condición siempre cierta (modificadores fijos de pasivas de arma).
  always,

  // ---- ascensión (docs/specs/ascension.md § 3.1) ----

  /// Un golpe primario tuyo retrasó a un enemigo.
  onDelayApplied,

  /// Usaste tu ULT (después de resolverla).
  onUltimate,

  /// Cualquier aliado quebró a un enemigo (el dueño está vivo).
  onBreak,

  /// Cayó un aliado (el dueño está vivo).
  onAllyDown,

  /// Saltó una trampa tuya.
  onTrap,

  /// Condición para TODO el grupo mientras el dueño esté en pie.
  partyAura,

  /// Condición que escala con la vida que le falta al dueño.
  whileMissingHealth,

  /// Condición: el objetivo tiene `minStacks`+ estados elementales
  /// distintos (Quemadura, Congelación, Veneno).
  vsElements,

  // ---- árbol v3 (docs/specs/passive_tree_v3.md § 9) ----

  /// Condición: el objetivo está quebrado.
  vsBroken,

  // ---- reacciones v0.7 (docs/specs/passive_tree_v4.md § 8) ----

  /// Un golpe tuyo detonó una reacción ([PassiveMechanic.reaction]
  /// filtra el tipo).
  onReaction,

  /// Una reacción (de cualquiera del grupo, vos incluido) consumió un
  /// estado que preparaste vos.
  onPrimedReaction,

  /// Vos o un aliado detonaron una reacción (el dueño está vivo).
  onPartyReaction,

  /// Condición: el objetivo es de la familia [PassiveMechanic.family].
  vsFamily,
}

/// Filtro extra sobre la acción o el golpe que disparó la mecánica.
enum ProcFilter {
  any,

  /// Ataque básico (sin Golpe Imparable), habilidad o ULT de daño a un
  /// solo enemigo.
  singleTarget,

  /// Habilidad mágica a un solo enemigo.
  magicalSingle,

  /// Habilidad mágica (no ULT).
  magicalSkill,

  /// Habilidad de daño a todos (no ULT).
  areaSkill,

  /// El dueño estaba defendiendo.
  defending,

  /// Provocar, Protección o Escudo de Fe.
  guardSkill,

  /// La vida del dueño está por debajo de `threshold`.
  belowThreshold,

  /// Habilidad o ULT con efecto de grupo (gritos, escudos, adelantos).
  rallySkill,
}

/// Qué hace una mecánica. El motor tiene código por tipo de efecto, no
/// por notable.
enum ProcEffectKind {
  buffSelf,
  debuffTarget,
  markTarget,
  advanceTurn,
  extraTurn,
  healSelf,
  healLowestAlly,
  chain,
  explode,
  reflect,
  shatterStun,
  delayTarget,
  repeatSkill,
  spreadStatus,
  freeAttack,
  shieldHealed,
  shieldSelf,
  ultCharge,
  stunExtend,
  holyDamage,

  /// Modificador de las condiciones (`whileLowHealth`, `vsStatus`,
  /// `vsMarked`) sobre [ProcEffect.stat].
  statBonus,

  /// Pasivas de arma: suma `value` stacks del estado recién aplicado
  /// ([ProcEffect.status] o el de la mecánica) al mismo objetivo.
  extraStacks,

  /// Pasivas de arma: aplica [ProcEffect.status] (`value` stacks) al
  /// objetivo del golpe. Secundario: no dispara nada.
  inflict,

  /// Pasivas de arma: modificador de condición, +`value` (fracción) al
  /// llenado de la barra de quiebre.
  breakBonus,

  // ---- ascensión (docs/specs/ascension.md § 3.1) ----
  buffParty,
  shieldParty,
  shieldLowestAlly,
  healParty,
  advanceAlly,
  advanceParty,
  ultChargeParty,
  drainUlt,
  execute,
  plantTrap,
  burst,
  spreadAll,
  addElement,

  /// Modificador: el primer golpe mortal deja en 1 HP (1 vez por batalla).
  cheatDeath,

  // ---- reacciones v0.7 (docs/specs/passive_tree_v4.md § 8) ----

  /// Cortocircuito: salta a `value` enemigos más (mismo daño del salto).
  extraJump,

  /// Devuelve el MP de la habilidad de la acción (no la ULT).
  refundMp,

  /// Aplica [ProcEffect.status] × ⌈stacks consumidos × `value`⌉ al
  /// objetivo de la reacción.
  reactionStatus,

  /// Los demás enemigos con Congelación quedan Quebradizos.
  brittleAll,

  /// El objetivo aturdido sigue aturdido 1 turno más (no jefes).
  lockStun,

  /// Buff a vos y a quien detonó la reacción ([ProcEffect.stat]).
  buffDuo,

  /// Modificador: +`value` (fracción) al golpe que detona una reacción.
  reactionBonus,

  /// Modificador: +`value` (fracción) al daño de tus curas a las
  /// familias que las curas dañan.
  healHarmBonus,

  /// Modificador de invocaciones (docs/specs/summoner.md § 5): solo lo
  /// lee el motor de invocaciones, según la mecánica.
  summon,
}

/// Stat que toca un efecto con duración o un modificador.
enum BuffStat {
  speed('velocidad'),
  attack('ATQ'),
  crit('crítico'),

  /// Daño recibido (Marca del Cazador).
  damageTaken('daño recibido'),

  /// Daño hecho (Fractura).
  damage('daño'),
  shield('escudo'),

  /// Aturdimiento extendido (Martillo Bendito).
  stunLock('aturdido +1'),

  // ---- ascensión (docs/specs/ascension.md § 3.1) ----
  lifeSteal('robo de vida'),

  /// Daño recibido − (Estandarte, Bandera Firme).
  guard('defensa'),
  critMulti('multiplicador de crítico'),
  delayPower('retraso'),
  buffPower('poder de buffs'),
  buffTurns('duración de buffs'),
  trapPower('daño de trampas'),
  trapTurns('turnos de trampas'),
  shieldPower('escudos'),
  shieldReflect('reflejo de escudo'),
  holyPower('Sagrado'),
  shareDamage('daño compartido'),

  /// Trampa puesta en un enemigo (valor = daño).
  trap('trampa'),

  /// Disparo cargado de un jugador (valor = daño; `ownerId` = objetivo).
  /// Cae al empezar su próximo turno (combat.md § "Variantes").
  charge('disparo cargado');

  const BuffStat(this.label);
  final String label;
}

/// Un efecto de una mecánica con sus parámetros. `value` depende del
/// tipo: fracción (0.2 = 20%), puntos de ULT, etc.
class ProcEffect {
  const ProcEffect(this.kind,
      {this.value = 0, this.turns = 0, this.stat, this.status});

  final ProcEffectKind kind;
  final double value;
  final int turns;
  final BuffStat? stat;

  /// Estado que aplica (`inflict`, `extraStacks`).
  final StatusKind? status;

  /// Efectos que caen sobre el objetivo (se disparan una vez por objetivo
  /// y acción en vez de una vez por acción).
  bool get onTarget => switch (kind) {
        ProcEffectKind.debuffTarget ||
        ProcEffectKind.markTarget ||
        ProcEffectKind.shatterStun ||
        ProcEffectKind.delayTarget ||
        ProcEffectKind.holyDamage ||
        ProcEffectKind.shieldHealed ||
        ProcEffectKind.extraStacks ||
        ProcEffectKind.inflict ||
        ProcEffectKind.execute ||
        ProcEffectKind.plantTrap ||
        ProcEffectKind.drainUlt ||
        ProcEffectKind.addElement ||
        ProcEffectKind.reactionStatus ||
        ProcEffectKind.lockStun =>
          true,
        _ => false,
      };
}

/// Notable o keystone v2 declarado como datos: disparador + filtro +
/// probabilidad + efectos.
class PassiveMechanic {
  const PassiveMechanic({
    required this.id,
    required this.name,
    required this.trigger,
    required this.effects,
    required this.description,
    this.filter = ProcFilter.any,
    this.chance = 1,
    this.status,
    this.minStacks = 1,
    this.threshold = 0,
    this.reaction,
    this.family,
  });

  final String id;
  final String name;
  final ProcTrigger trigger;
  final ProcFilter filter;

  /// Probabilidad (1 = siempre; solo se tira azar si es < 1).
  final double chance;

  /// Estado que filtra el disparador (`onStatusApplied`, `vsStatus`,
  /// `onHit` con [minStacks], `onEnemyDeath`) o que se contagia.
  final StatusKind? status;
  final int minStacks;

  /// Umbral de vida de `whileLowHealth` (0.3 = 30%).
  final double threshold;

  /// Reacción que filtra `onReaction` / `onPrimedReaction` /
  /// `onPartyReaction` (`null` = cualquiera).
  final ReactionKind? reaction;

  /// Familia de `vsFamily`.
  final EnemyFamily? family;
  final List<ProcEffect> effects;

  /// Texto completo para el tooltip del árbol.
  final String description;

  /// La misma mecánica con otro id (dos ids iguales en el conjunto de un
  /// jugador cuentan una vez; con otro id suman).
  PassiveMechanic withId(String newId) => PassiveMechanic(
        id: newId,
        name: name,
        trigger: trigger,
        filter: filter,
        chance: chance,
        status: status,
        minStacks: minStacks,
        threshold: threshold,
        reaction: reaction,
        family: family,
        effects: effects,
        description: description,
      );

  bool get isCondition =>
      trigger == ProcTrigger.whileLowHealth ||
      trigger == ProcTrigger.vsStatus ||
      trigger == ProcTrigger.vsMarked ||
      trigger == ProcTrigger.always ||
      trigger == ProcTrigger.partyAura ||
      trigger == ProcTrigger.whileMissingHealth ||
      trigger == ProcTrigger.vsElements ||
      trigger == ProcTrigger.vsBroken ||
      trigger == ProcTrigger.vsFamily;
}

/// Un efecto con duración sobre un combatiente (buff, debuff, marca,
/// escudo). Inmutable: el motor reemplaza la entrada.
class TimedEffect {
  const TimedEffect({
    required this.sourceId,
    required this.stat,
    required this.value,
    required this.turns,
    this.ownerId,
    this.fresh = false,
  });

  /// Id de la mecánica que lo puso (`frenesi`, `marcaCazador`...).
  final String sourceId;
  final BuffStat stat;

  /// Fracción (0.2 = +20%) o, en escudos, la vida que todavía absorbe.
  final double value;

  /// Turnos que le quedan (ver passive_tree_v2.md § 5).
  final int turns;

  /// Quién lo aplicó.
  final String? ownerId;

  /// Se aplicó durante el turno del propio portador: ese turno no lo
  /// descuenta (passive_tree_v2.md § 5).
  final bool fresh;

  TimedEffect copyWith({double? value, int? turns, bool? fresh}) => TimedEffect(
        sourceId: sourceId,
        stat: stat,
        value: value ?? this.value,
        turns: turns ?? this.turns,
        ownerId: ownerId,
        fresh: fresh ?? this.fresh,
      );
}
