import 'dart:math' as math;

import '../../../game_engine/data/items_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/rules/progression_rules.dart';

/// Por qué el motor rechazaría una acción de los paneles, en el mismo
/// orden en que la comprueba (`SessionEngine.apply` + `ProgressionRules`).
/// `null` = el botón está habilitado. Ver docs/specs/panels.md § "Botones
/// con motivo". Solo explica: la validación real la sigue haciendo el host.
class ShopGuards {
  const ShopGuards(this.rules, this.mode);

  final ProgressionRules rules;
  final SessionMode mode;

  static const notShopping = 'Solo en el lobby o la preparación';

  bool get canShop => mode == SessionMode.lobby || mode == SessionMode.prep;

  static String _missing(int need, int have) => 'Faltan \$${need - have}';

  /// `BuyWeaponAction` (armas de su clase a la venta).
  String? buyWeapon(PlayerProfile p, String weaponId) {
    if (!canShop) return notShopping;
    final w = rules.catalog.weapons[weaponId];
    if (w == null || w.classId != p.classId || w.price <= 0) {
      return 'No está a la venta';
    }
    if (p.inventory.contains(weaponId)) return 'Ya la tienes';
    if (p.credits < w.price) return _missing(w.price, p.credits);
    return null;
  }

  /// `BuyItemAction`.
  String? buyItem(PlayerProfile p, BattleItem item) {
    if (!canShop) return notShopping;
    final have = item == BattleItem.potion ? p.potions : p.ethers;
    if (have >= ProgressionRules.maxItems) {
      return 'Máximo ${ProgressionRules.maxItems}';
    }
    final price = kItems[item]!.price;
    if (p.credits < price) return _missing(price, p.credits);
    return null;
  }

  /// `EquipAction`. Con [pending] (reparto sin confirmar) distingue
  /// "Confirma puntos" de "Requisitos", como el botón del prototipo.
  String? equip(PlayerProfile p, String weaponId,
      {Map<Attribute, int> pending = const {}}) {
    if (!canShop) return 'Solo en preparación';
    if (!p.inventory.contains(weaponId)) return 'No la tienes';
    if (p.equipped == weaponId) return 'Equipada';
    if (rules.canEquip(p, weaponId)) return null;
    final w = rules.catalog.weapons[weaponId];
    if (w != null &&
        w.classId == p.classId &&
        pending.values.any((v) => v > 0) &&
        w.meetsRequirements(p.attributes.add(pending))) {
      return 'Confirma puntos';
    }
    return 'Requisitos';
  }

  /// `UpgradeAction`.
  String? upgrade(PlayerProfile p, String weaponId, UpgradeStat stat) {
    if (!canShop) return notShopping;
    final w = rules.catalog.weapons[weaponId];
    if (w == null ||
        !rules.upgradeStatsFor(w).contains(stat) ||
        !p.inventory.contains(weaponId) ||
        w.classId != p.classId) {
      return 'No se puede mejorar';
    }
    final l = p.upgradesFor(weaponId).level(stat);
    if (l >= ProgressionRules.upgradeMax) return 'MAX';
    final cost = rules.upgradeCost(weaponId, l);
    if (p.credits < cost) return _missing(cost, p.credits);
    return null;
  }

  /// Armas que pueden ser base de una fusión (`mine`).
  List<String> fuseBases(PlayerProfile p) => p.inventory
      .where((id) => rules.catalog.weapons[id]?.classId == p.classId)
      .toList();

  /// Armas que se pueden sacrificar con [baseId] como base (`others`).
  List<String> fuseSacrifices(PlayerProfile p, String? baseId) {
    final start = rules.catalog.classes[p.classId]?.startWeaponId;
    return fuseBases(p)
        .where((id) => id != baseId && id != start && id != p.equipped)
        .toList();
  }

  /// `FuseAction`.
  String? fuse(PlayerProfile p, String? baseId, String? sacrificeId,
      String? skillId) {
    if (!canShop) return notShopping;
    if (baseId == null || sacrificeId == null) {
      return 'Elige un arma a sacrificar';
    }
    if (!fuseSacrifices(p, baseId).contains(sacrificeId) ||
        !fuseBases(p).contains(baseId)) {
      return 'No se puede fusionar';
    }
    final b = rules.catalog.weapons[sacrificeId]!;
    if (skillId == null || !b.skillIds.contains(skillId)) {
      return 'Elige una habilidad';
    }
    if (p.credits < ProgressionRules.fuseCost) {
      return _missing(ProgressionRules.fuseCost, p.credits);
    }
    return null;
  }

  /// Motivo por el que no se puede reiniciar (`ProgressionRules.canRespec`).
  String? _respecMode() => rules.canRespec(mode)
      ? null
      : ProgressionRules.freeRespec
          ? 'No en batalla'
          : notShopping;

  /// Si la UI ofrece reiniciar puntos / árbol en este modo.
  bool get showRespec => rules.canRespec(mode);

  /// `RespecAction`.
  String? respec() => _respecMode();

  /// `ChangeClassAction`.
  String? changeClass(PlayerProfile p, String classId) {
    if (mode != SessionMode.lobby) return 'Solo en el lobby';
    if (p.classId == classId) return 'Es tu clase';
    return null;
  }

  /// `ResetTreeAction` (la UI no lo ofrece sin nodos tomados).
  String? resetTree(PlayerProfile p) {
    final m = _respecMode();
    if (m != null) return m;
    if (p.tree.isEmpty) return 'No hay nodos tomados';
    return null;
  }

  /// `AllocateStatsAction` con el reparto [add].
  String? allocate(PlayerProfile p, Map<Attribute, int> add) {
    if (mode == SessionMode.battle) return 'No en batalla';
    final total = add.values.fold(0, (a, b) => a + math.max(0, b));
    if (total <= 0) return 'Reparte algún punto';
    if (total > p.points) return 'No tienes tantos puntos';
    return null;
  }
}
