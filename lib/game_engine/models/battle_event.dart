import 'status.dart';

/// Lo que pasó en un paso del motor, en orden, para que la UI lo anime
/// (números flotantes, auras, textos). Equivale a los `addFx` del
/// prototipo, sin coordenadas ni colores: eso lo decide la UI.
sealed class BattleEvent {
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

  const DamageEvent(
    this.targetId,
    this.amount, {
    this.critical = false,
    this.critMultiplier = 1,
    this.pierceMultiplier = 1,
    this.fromStatus = false,
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
