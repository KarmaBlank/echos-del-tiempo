import '../data/game_catalog.dart';
import '../models/battle_command.dart';
import '../models/battle_state.dart';
import '../models/skill.dart';
import 'battle_engine.dart' show ultimateOf;

/// AUTO de un compañero de la party (docs/specs/solo_party.md § 4.1).
/// Determinística: el mismo estado elige siempre lo mismo.
class CompanionAi {
  const CompanionAi([this.catalog = GameCatalog.standard]);

  final GameCatalog catalog;

  /// Vida (fracción) por debajo de la cual se cura a un aliado.
  static const healBelow = 0.4;

  /// Lo que hace [actorId] en su turno; `null` si no está o no es su
  /// turno de jugador.
  BattleCommand? choose(BattleState state, String actorId) {
    final me = state.byId(actorId);
    if (me == null || !me.isPlayer || !me.alive) return null;
    final foes = state.enemies.where((e) => e.alive).toList();
    if (foes.isEmpty) return const DefendCommand();
    var weakest = foes.first;
    for (final f in foes.skip(1)) {
      if (f.hp < weakest.hp) weakest = f;
    }

    // 1. Curar a quien esté por debajo del 40 % (o caído).
    Combatant? hurt;
    var low = healBelow;
    for (final q in state.party) {
      final frac = q.maxHp <= 0 ? 1.0 : q.hp / q.maxHp;
      if (frac < low) {
        low = frac;
        hurt = q;
      }
    }
    if (hurt != null) {
      for (final id in me.skillIds) {
        final sk = catalog.skills[id];
        if (sk != null && sk.kind == SkillKind.heal && me.mp >= sk.mp) {
          return SkillCommand(id);
        }
      }
      if (me.potions > 0) {
        return ItemCommand(BattleItem.potion, targetPlayerId: hurt.id);
      }
    }

    // 2. ULT lista.
    if (me.ult >= 100 && ultimateOf(me, catalog) != null) {
      return UltimateCommand(targetId: weakest.id);
    }

    // 3. Atacar al enemigo con menos vida.
    return AttackCommand(targetId: weakest.id);
  }

  /// Si el motor rechaza la elección: atacar y, si no, defender.
  static const fallbacks = <BattleCommand>[AttackCommand(), DefendCommand()];
}
