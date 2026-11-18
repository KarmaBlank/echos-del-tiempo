import 'elements.dart';
import 'passive_mechanic.dart';
import 'status.dart';

/// Lo que pasó en un paso del motor, en orden, para que la UI lo anime
/// (números flotantes, auras, textos). Equivale a los `addFx` del
/// prototipo, sin coordenadas ni colores: eso lo decide la UI.
///
/// No es `sealed` a propósito: el árbol v2 agrega eventos opcionales
/// ([ProcEvent], [BuffAppliedEvent], [ShieldEvent]) y quien no los
/// conoce (un `switch` sin `default`) los ignora sin dejar de compilar.
abstract class BattleEvent {
  const BattleEvent();
}

class TurnStartedEvent extends BattleEvent {
  final String actorId;
  const TurnStartedEvent(this.actorId);
}

class DamageEvent extends BattleEvent {
  final String targetId;
  final int amount;
  final bool critical;
  final double critMultiplier;
  final double pierceMultiplier;

  /// Daño de Quemadura / Veneno / Sagrado al empezar el turno.
  final bool fromStatus;

  /// Con [fromStatus]: el estado que manda en el efecto visual
  /// (Quemadura si tenía, si no Veneno, si no Sagrado). `null` si no.
  final StatusKind? statusSource;

  /// Daño secundario de una mecánica del árbol (`rebote`, `combustion`,
  /// `contraataque`...). `null` en el daño normal.
  final String? sourceId;

  /// El objetivo estaba quebrado: el golpe lleva el +50% del quiebre.
  final bool vulnerable;

  /// Ráfaga (`SkillDef.hits`): número de golpe al mismo objetivo (0 = el
  /// primero). Ver docs/specs/battle_presentation.md § "Saltos".
  final int hitIndex;

  /// Rebote (`SkillDef.bounces`): de quién salta a este objetivo.
  final String? chainFrom;

  /// Atraviesa (`SkillDef.pierce`): golpe al de atrás del objetivo.
  final bool pierced;

  /// Factor de la familia del objetivo (docs/specs/bestiary.md § 1.3):
  /// > 1 = débil (DÉBIL en la escena), < 1 = resiste, 1 = neutro.
  final double affinity;

  const DamageEvent(
    this.targetId,
    this.amount, {
    this.critical = false,
    this.critMultiplier = 1,
    this.pierceMultiplier = 1,
    this.fromStatus = false,
    this.statusSource,
    this.sourceId,
    this.vulnerable = false,
    this.hitIndex = 0,
    this.chainFrom,
    this.pierced = false,
    this.affinity = 1,
  });
}

/// Qué tipo de acción abre un [ActionEvent].
enum BattleActionKind {
  attack,
  skill,
  ultimate,
  dual,
  potion,
  ether,
  defend,

  /// Ataque normal de un enemigo.
  enemyAttack,

  /// Golpe Brutal de un jefe (cada 4 acciones).
  enemyHeavy,

  /// Colapso Temporal: ataque a todo el equipo (cada 3 acciones).
  enemyArea,
}

/// Un actor empieza una acción (el `addFx({k:'act'})` del prototipo, con
/// lo que la UI necesita para elegir proyectiles, anillos y colores).
/// Va antes de los eventos que esa acción produce, en el mismo paso.
class ActionEvent extends BattleEvent {
  final String actorId;
  final BattleActionKind kind;

  /// `SkillDef.id` de la habilidad o ULT usada (`kind` skill/ultimate).
  final String? skillId;

  /// Aliado del dúo (`kind` dual).
  final String? partnerId;

  /// Objetivo principal (enemigo, jugador elegido o aliado de la poción).
  final String? targetId;

  /// Golpea a todos los enemigos (o, de un enemigo, a todo el equipo).
  final bool allTargets;

  const ActionEvent(
    this.actorId,
    this.kind, {
    this.skillId,
    this.partnerId,
    this.targetId,
    this.allTargets = false,
  });
}

class HealEvent extends BattleEvent {
  final String targetId;
  final int amount;
  final bool mana;
  const HealEvent(this.targetId, this.amount, {this.mana = false});
}

class StatusAppliedEvent extends BattleEvent {
  final String targetId;
  final StatusKind kind;
  final int stacks;
  final bool weakness;
  const StatusAppliedEvent(this.targetId, this.kind, this.stacks,
      {this.weakness = false});
}

class TurnSkippedEvent extends BattleEvent {
  final String actorId;
  final StatusKind cause; // stun | freeze
  const TurnSkippedEvent(this.actorId, this.cause);
}

class DelayedEvent extends BattleEvent {
  final String targetId;
  const DelayedEvent(this.targetId);
}

class KnockedOutEvent extends BattleEvent {
  final String targetId;
  const KnockedOutEvent(this.targetId);
}

class RevivedEvent extends BattleEvent {
  final String targetId;
  const RevivedEvent(this.targetId);
}

class UltimateUsedEvent extends BattleEvent {
  final String actorId;
  final String name;
  const UltimateUsedEvent(this.actorId, this.name);
}

class BattleEndedEvent extends BattleEvent {
  final bool victory;
  final int xp;
  final int credits;
  const BattleEndedEvent(this.victory, this.xp, this.credits);
}

/// Disparó una mecánica del árbol v2 de [actorId] (`sourceId` = id en
/// `kMechanics`). Va antes de los eventos que produce.
class ProcEvent extends BattleEvent {
  final String actorId;
  final String sourceId;
  final String? targetId;
  const ProcEvent(this.actorId, this.sourceId, {this.targetId});
}

/// Un efecto con duración (buff, debuff, marca) cayó sobre [targetId].
class BuffAppliedEvent extends BattleEvent {
  final String targetId;
  final String sourceId;
  final BuffStat stat;
  final double value;
  final int turns;
  const BuffAppliedEvent(
      this.targetId, this.sourceId, this.stat, this.value, this.turns);
}

/// [targetId] ganó un escudo de [amount] (o, con [absorbed], su escudo
/// absorbió [amount] de daño).
class ShieldEvent extends BattleEvent {
  final String targetId;
  final int amount;
  final bool absorbed;
  const ShieldEvent(this.targetId, this.amount, {this.absorbed = false});
}

/// Qué le pasó a la barra de quiebre de un enemigo.
enum BreakPhase {
  /// Un golpe la llenó (sin llegar al máximo).
  fill,

  /// Bajó al empezar su turno.
  decay,

  /// Llegó al máximo: ¡QUIEBRE!
  broken,

  /// Pierde su turno por estar quebrado.
  skipped,

  /// Se terminó la vulnerabilidad: la barra vuelve a 0.
  recovered,
}

/// Cambio en la barra de quiebre de [targetId] (docs/specs/
/// break_and_enemy_ults.md § 1). [gauge] y [max] son los valores después
/// del cambio; [cancelledUlt]: el quiebre canceló la ULT avisada.
class BreakEvent extends BattleEvent {
  final String targetId;
  final BreakPhase phase;
  final double gauge;
  final double max;
  final bool cancelledUlt;
  const BreakEvent(this.targetId, this.phase, this.gauge, this.max,
      {this.cancelledUlt = false});
}

/// Un enemigo avisa su ULT: la lanza en su próximo turno.
class EnemyUltWarningEvent extends BattleEvent {
  final String actorId;

  /// `EnemyUltDef.id`.
  final String ultId;
  final String name;
  const EnemyUltWarningEvent(this.actorId, this.ultId, this.name);
}

/// Un enemigo lanza su ULT. Abre la acción (como un [ActionEvent]): los
/// golpes, estados y retrasos que siguen son de la ULT.
class EnemyUltEvent extends BattleEvent {
  final String actorId;
  final String ultId;
  final String name;

  /// Víctima elegida (antes de la Protección); `null` si es a todos.
  final String? targetId;
  final bool allTargets;

  /// Borró los buffs del equipo (Fin de las Eras).
  final bool wipedBuffs;
  const EnemyUltEvent(this.actorId, this.ultId, this.name,
      {this.targetId, this.allTargets = false, this.wipedBuffs = false});
}

/// Qué hizo la mecánica propia de un jefe (docs/specs/bosses.md § "v0.2").
enum BossMechanicPhase {
  /// La Matriarca atrapa a [BossMechanicEvent.targetId] en su telaraña.
  webCast,

  /// [BossMechanicEvent.actorId] (un jugador) libera a `targetId`.
  webFreed,

  /// El atrapado pierde su turno (`targetId`).
  webSkip,

  /// Solo: el atrapado forcejea y pierde medio turno (`targetId`).
  webStruggle,

  /// La Sierpe congela el campo: `value` = velocidad perdida total
  /// (0.2 = −20%).
  frost,

  /// Cayeron todos los cristales: el campo se descongela.
  thaw,

  /// El quiebre de la Sierpe rompe el cristal `targetId`.
  shatter,

  /// Aliento Glacial vuelve a formar el cristal `targetId`.
  reform,

  /// El Caballero Hueco cambia de postura: `value` = 1 escudo, 2 espada.
  stanceShift,

  /// La postura bloqueó parte del golpe: `value` = fracción bloqueada.
  resisted,

  // ---- v0.3 (docs/specs/bosses.md § "v0.3") ----

  /// La Hechicera crea (o rehace) el eco `targetId`.
  echoSummon,

  /// Un eco recibe daño reducido: `value` = fracción que recibe (0.5).
  echoResist,

  /// La lava sube: `value` = turnos.
  lavaRise,

  /// La lava quema a `targetId`, que se estaba defendiendo: `value` =
  /// stacks de Quemadura.
  lavaBurn,

  /// La lava se enfría.
  lavaFade,

  /// El Espectro invoca (o revive) al siervo `targetId`.
  summon,

  /// El jefe es inmune a los estados (séquito vivo).
  immune,

  /// El Centinela marca a `targetId`.
  markCast,

  /// El golpe al marcado `targetId` pega × `value`.
  markHit,

  /// [BossMechanicEvent.actorId] (protector, o el marcado defendiéndose en
  /// solo) contrarresta la marca de `targetId`.
  markGuarded,

  /// El jefe se transforma: `value` = fase nueva (2).
  phaseShift,

  /// Un común esquiva (el golpe solo lo roza): `actorId` = el enemigo.
  evaded,

  // ---- Jefes del Abismo v0.8 (docs/specs/abyss_bosses.md § 2) ----

  /// Aviso: la próxima acción es el movimiento `value`
  /// (`AbyssMoveKind.index`).
  abyssTelegraph,

  /// Entra en furia (`value` = multiplicador de ATQ).
  enrage,

  /// Levanta un sello: `value` = `ReactionKind.index` que lo rompe.
  sealCast,

  /// Se rompe el sello (`targetId` = quien lo rompió, si fue un jugador).
  sealBroken,

  /// El sello se apaga solo.
  sealFade,

  /// Rebobina: `value` = vida recuperada.
  rewind,

  /// Distorsión: retrasa al grupo (`value` = fracción de turno).
  timeWarp,

  /// Un eco (`actorId`) copia la habilidad del grupo sobre `targetId`.
  mirror,

  /// Se come `value` buffs del grupo.
  devour,

  /// Cambia de aspecto: `value` = `GameElement.index`.
  aspect,
}

/// Una mecánica de jefe. [actorId]: el jefe (o el jugador que libera).
class BossMechanicEvent extends BattleEvent {
  final String actorId;
  final BossMechanicPhase phase;
  final String? targetId;
  final double value;
  const BossMechanicEvent(this.actorId, this.phase,
      {this.targetId, this.value = 0});
}

/// Reacción elemental (docs/specs/elemental_reactions.md § 2): el golpe
/// de [sourceId] detonó el estado de [targetId]. Va después del
/// `DamageEvent` del golpe que la detona y antes de los daños extra de la
/// reacción (`DamageEvent.sourceId` = [reactionSourceId]).
///
/// [amount]: Electrocución / Derretir, el daño del golpe (ya con ×1.5);
/// Explosión tóxica, el daño extra al objetivo (con el tope de jefe);
/// Cortocircuito, el daño del salto; Congelación súbita, 0.
/// [consumedStacks]: stacks / turnos del estado consumido (Veneno,
/// Mojado, Congelación, Cargado). [splash]: daño a cada otro afectado
/// (salpicadura de la explosión o salto del cortocircuito), por id.
class ReactionEvent extends BattleEvent {
  final String targetId;
  final ReactionKind kind;
  final int amount;
  final String? sourceId;
  final int consumedStacks;
  final Map<String, int> splash;

  const ReactionEvent(
    this.targetId,
    this.kind,
    this.amount, {
    this.sourceId,
    this.consumedStacks = 0,
    this.splash = const {},
  });
}

/// `DamageEvent.sourceId` del daño extra de una reacción.
String reactionSourceId(ReactionKind k) => 'reaction.${k.name}';

/// Qué le pasó al hielo de un combatiente (docs/specs/elemental_reactions.md
/// § 7).
enum IcePhase {
  /// Perdió el turno congelado y queda Quebradizo.
  brittle,

  /// Un golpe físico lo rompió (×1.5) y se descongeló.
  shattered,

  /// Se descongeló solo (o lo derritió el fuego): resistencia 2 turnos.
  thawed,

  /// Resiste la Congelación (recién descongelado).
  resisted,
}

class IceEvent extends BattleEvent {
  final String targetId;
  final IcePhase phase;
  const IceEvent(this.targetId, this.phase);
}
