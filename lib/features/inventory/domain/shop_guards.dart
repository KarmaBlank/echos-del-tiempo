import 'dart:math' as math;

import '../../../game_engine/data/items_catalog.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/battle_command.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/models/upgrade_stat.dart';
import '../../../game_engine/rules/craft_rules.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import 'item_text.dart';

/// Por qué el motor rechazaría una acción de los paneles, en el mismo
/// orden en que la comprueba (`SessionEngine.apply` + `ProgressionRules`
/// + `CraftRules` / `InventoryRules`). `null` = el botón está habilitado.
/// Ver docs/specs/panels.md § "Botones con motivo". Solo explica: la
/// validación real la sigue haciendo el host.
class ShopGuards {
  const ShopGuards(this.rules, this.mode);

  final ProgressionRules rules;
  final SessionMode mode;

  static const notShopping = 'Solo en el lobby o la preparación';

  bool get canShop => mode == SessionMode.lobby || mode == SessionMode.prep;

  static const notDiscarding = 'No en batalla';

  /// Desarmar / vender / limpiar: también en la aventura (no en batalla).
  bool get canDiscard => canShop || mode == SessionMode.field;

  static String _missing(int need, int have) => 'Faltan \$${need - have}';

  /// `BuyWeaponAction`: cualquier base a la venta (loot v2: sin clase).
  String? buyWeapon(PlayerProfile p, String weaponId) {
    if (!canShop) return notShopping;
    final w = rules.catalog.weapons[weaponId];
    if (w == null || w.price <= 0) return 'No está a la venta';
    if (p.items.any((i) => i.baseId == weaponId)) return 'Ya la tienes';
    if (p.credits < w.price) return _missing(w.price, p.credits);
    if (InventoryRules.freeCells(p) <= 0) return 'Inventario lleno';
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

  /// `EquipAction` ([weaponId] = `uid` o base). Cualquier clase: nivel y
  /// requisitos. Con [pending] (reparto sin confirmar) distingue
  /// "Confirma puntos" de los requisitos que faltan.
  String? equip(PlayerProfile p, String weaponId,
      {Map<Attribute, int> pending = const {}}) {
    if (!canShop) return notShopping;
    final it = p.item(weaponId);
    if (it == null) return 'No la tienes';
    if (it.uid == p.equippedUid) return 'Equipada';
    if (rules.canEquip(p, it.uid)) return null;
    final w = rules.baseFor(p, it.uid);
    if (w == null) return 'No se puede equipar';
    if (p.level < w.level) return 'Nivel ${w.level}';
    if (pending.values.any((v) => v > 0) &&
        w.meetsRequirements(
            p.attributes.add(ProgressionRules.rawOf(pending)))) {
      return 'Confirma puntos';
    }
    return 'Requisitos: ${missingRequirements(w, p.attributes)}';
  }

  /// `UpgradeAction` (forja de una instancia): el tope por estadística y
  /// el de la rareza los dice el motor (`CraftRules.forge`).
  String? upgrade(PlayerProfile p, String weaponId, UpgradeStat stat) {
    if (!canShop) return notShopping;
    final it = p.item(weaponId);
    if (it == null) return 'No la tienes';
    return rules.crafting.forge(p, it.uid, stat).error;
  }

  /// Vista previa de una operación de la mesa de fusión (sin azar: las
  /// aleatorias solo dicen costo y qué puede salir).
  CraftResult craftPreview(PlayerProfile p, CraftAction a) =>
      rules.crafting.apply(p, a.op, a.targetUid,
          sourceUid: a.sourceUid,
          index: a.index,
          skillId: a.skillId,
          replaceSkillId: a.replaceSkillId,
          uids: a.uids);

  /// `CraftAction`.
  String? craft(PlayerProfile p, CraftAction a) {
    if (a.op.destroys ? !canDiscard : !canShop) {
      return a.op.destroys ? notDiscarding : notShopping;
    }
    return craftPreview(p, a).error;
  }

  /// Armas que se pueden sacrificar en un traslado hacia [targetUid]: no
  /// la destino, ni la equipada, ni la última del arma inicial.
  List<ItemInstance> sacrifices(PlayerProfile p, String? targetUid) => [
        for (final i in p.items)
          if (i.uid != targetUid && !rules.inventory.isProtected(p, i.uid)) i,
      ];

  /// `GiveItemAction` de [count] de [token] a [to] (`null` = sin
  /// compañeros en la sala).
  String? give(PlayerProfile p, String token, SessionPlayer? to,
      {int count = 1}) {
    if (mode == SessionMode.battle) return 'No en batalla';
    if (to == null) return 'No hay compañeros en la sala';
    final t = rules.inventory.take(p, token, count: count);
    final drop = t.drop;
    if (drop == null) return t.error ?? 'No se puede dar';
    final why = InventoryRules.cannotReceive(to.profile, drop);
    return why == null ? null : '${to.name}: $why';
  }

  /// `DropItemAction`: al piso, en el lobby o el campo, vivo.
  String? drop(PlayerProfile p, String token,
      {int count = 1, bool alive = true}) {
    if (mode != SessionMode.lobby && mode != SessionMode.field) {
      return 'Solo en el lobby o en el campo';
    }
    if (!alive) return 'Estás K.O.';
    final t = rules.inventory.take(p, token, count: count);
    return t.drop == null ? t.error ?? 'No se puede tirar' : null;
  }

  /// `SetLootFilterAction` desde el editor: [saved] es el texto guardado
  /// (`null` = por defecto) y [errors] los del parser.
  static String? saveFilter(String text, String? saved, int errors,
      {required String defaultText}) {
    final current = saved ?? defaultText;
    if (text == current) return 'Sin cambios';
    if (text.length > SetLootFilterAction.maxLength) {
      return 'Máximo ${SetLootFilterAction.maxLength} caracteres';
    }
    if (errors > 0) return 'Corrige $errors error${errors == 1 ? '' : 'es'}';
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
