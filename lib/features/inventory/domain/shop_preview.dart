import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/progression_rules.dart';

/// Vistas previas de los paneles: los stats con otra arma (instancia o
/// base Común) o con el resultado de una forja. No valida nada (eso es
/// del motor y de `ShopGuards`): calcula sobre una build hipotética para
/// mostrar el resultado antes de confirmar. Ver docs/specs/panels.md §
/// "Armería".
class ShopPreview {
  const ShopPreview(this.rules);

  final ProgressionRules rules;

  /// Stats derivados si [p] usara la instancia [item] (con sus mods,
  /// pasiva y forja) con [attributes] (por defecto, los suyos).
  DerivedStats withItem(PlayerProfile p, ItemInstance item,
      {PlayerAttributes? attributes}) {
    final w = rules.catalog.weapons[item.baseId]!;
    return rules.stats.calculate(PlayerBuild(
      classId: p.classId,
      level: p.level,
      attributes: attributes ?? p.attributes,
      equippedWeapon: w,
      weaponUpgrades: item.forge,
      passiveProgress: p.passiveProgress,
      item: item,
    ));
  }

  /// Stats con la base [w] Común (lo que se compra en la tienda).
  DerivedStats withBase(PlayerProfile p, WeaponDef w,
          {PlayerAttributes? attributes}) =>
      withItem(p, ItemInstance.common('_preview', w.id, itemLevel: w.level),
          attributes: attributes);

  /// Stats con el arma que hoy usa (como `derivedStats`), con
  /// [attributes] opcionales.
  DerivedStats current(PlayerProfile p, {PlayerAttributes? attributes}) =>
      rules.stats.calculate(rules.buildOf(p, attributes: attributes));
}
