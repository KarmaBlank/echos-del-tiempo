import 'dart:math' as math;

import '../models/battle_command.dart';
import '../models/game_session.dart';
import 'js_math.dart';

/// Pociones fuera de combate (docs/specs/loot.md § 17.5): mismo efecto
/// que en batalla, sobre el propio jugador. Puro: la UI lo usa para el
/// motivo de desactivado y el host para validar.
abstract final class ConsumableRules {
  /// Motivo por el que [p] no puede usar [item] ahora, o `null` si puede.
  static String? blockReason(GameSession s, SessionPlayer p, BattleItem item) {
    if (s.mode == SessionMode.battle) return 'En batalla, usa su menú';
    final potion = item == BattleItem.potion;
    final left = potion ? p.profile.potions : p.profile.ethers;
    if (left <= 0) return 'No te quedan';
    if (potion ? p.hp >= p.maxHp : p.mp >= p.maxMp) {
      return potion ? 'Vida llena' : 'Maná lleno';
    }
    return null;
  }

  /// Aplica [item] a [p] (ya validado). Devuelve lo que restauró.
  static int apply(SessionPlayer p, BattleItem item) {
    if (item == BattleItem.potion) {
      final a = jsRound(p.maxHp * 0.45);
      p
        ..hp = math.min(p.maxHp.toDouble(), p.hp + a)
        ..profile = p.profile.copyWith(potions: p.profile.potions - 1);
      return a;
    }
    final a = jsRound(p.maxMp * 0.5);
    p
      ..mp = math.min(p.maxMp.toDouble(), p.mp + a)
      ..profile = p.profile.copyWith(ethers: p.profile.ethers - 1);
    return a;
  }
}
