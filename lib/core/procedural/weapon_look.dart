import 'dart:ui';

import '../../game_engine/data/uniques_catalog.dart';
import '../../game_engine/data/weapon_elements_catalog.dart';
import '../../game_engine/models/battle_state.dart';
import '../../game_engine/models/elements.dart';
import '../../game_engine/models/item.dart';
import '../../game_engine/rules/loot_filter_rules.dart';

/// Identidad visual de un arma concreta (docs/specs/weapon_identity.md
/// § 3, aprobado): todo sale de datos que ya viajan con el arma
/// (rareza, elemento, ULT, uid), así que el compañero en co-op ve lo
/// mismo sin mensajes de red nuevos.
class WeaponLook {
  const WeaponLook({
    this.element,
    this.rarity = Rarity.comun,
    this.hasUlt = false,
    this.variant = 0,
  });

  /// Aspecto de [i] (`null` = el genérico del tipo).
  factory WeaponLook.of(ItemInstance i) => WeaponLook(
        element: weaponElementOf(i),
        rarity: i.rarity,
        hasUlt: i.ultId != null || kUniques[i.uniqueId]?.ultId != null,
        variant: variantOf(i.uid),
      );

  final GameElement? element;
  final Rarity rarity;
  final bool hasUlt;

  /// Variante suave dentro de la familia (0..[variants]-1).
  final int variant;

  static const variants = 3;

  /// Variante determinista por el uid (FNV-1a de 32 bits): la misma en
  /// todos los clientes.
  static int variantOf(String uid) {
    var h = 0x811c9dc5;
    for (final c in uid.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h % variants;
  }

  bool get legendary => rarity == Rarity.legendario;

  /// Acento por rareza (la misma regla que el inventario).
  Color get rarityAccent {
    final c = LootFilterRules.rarityColor(rarity);
    return Color.fromARGB(255, c.r, c.g, c.b);
  }

  Color? get auraColor => element == null ? null : elementColor(element!);

  @override
  bool operator ==(Object other) =>
      other is WeaponLook &&
      other.element == element &&
      other.rarity == rarity &&
      other.hasUlt == hasUlt &&
      other.variant == variant;

  @override
  int get hashCode => Object.hash(element, rarity, hasUlt, variant);
}

/// Color del aura de cada elemento (arte; mismos tonos que los FX).
Color elementColor(GameElement e) => switch (e) {
      GameElement.fisico => const Color(0xFFDFE6E9),
      GameElement.fuego => const Color(0xFFFF7B29),
      GameElement.hielo => const Color(0xFF74B9FF),
      GameElement.veneno => const Color(0xFF7BED9F),
      GameElement.sagrado => const Color(0xFFFFF3B0),
      GameElement.agua => const Color(0xFF3FA9F5),
      GameElement.electro => const Color(0xFFC39BFF),
    };

/// Color de la marca de ULT (píxel en el pomo).
const kUltMarkColor = Color(0xFFFF5FC8);

/// Aspecto del arma de un combatiente (jugador local o compañero: su
/// build viaja en el snapshot). `null` sin arma concreta.
WeaponLook? lookOfCombatant(Combatant c) {
  final i = c.build?.item;
  return i == null ? null : WeaponLook.of(i);
}
