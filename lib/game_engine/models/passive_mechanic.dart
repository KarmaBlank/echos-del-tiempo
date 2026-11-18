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
  trap('trampa');

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
        ProcEffectKind.addElement =>
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
  final List<ProcEffect> effects;

  /// Texto completo para el tooltip del árbol.
  final String description;

  bool get isCondition =>
      trigger == ProcTrigger.whileLowHealth ||
      trigger == ProcTrigger.vsStatus ||
      trigger == ProcTrigger.vsMarked ||
      trigger == ProcTrigger.always ||
      trigger == ProcTrigger.partyAura ||
      trigger == ProcTrigger.whileMissingHealth ||
      trigger == ProcTrigger.vsElements;
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
