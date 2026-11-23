import 'package:material_ui/material_ui.dart';
import '../domain/item_names.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../core/procedural/item_icons.dart' show procKeyForType;
import '../domain/item_text.dart';
import '../domain/weapon_compare.dart' show stripStats;
import 'inventory_strings.dart';
import 'item_hover_tip.dart';
import 'item_widgets.dart';
import 'shop_sections.dart';
import 'weapon_compare_view.dart' show ChangeStrip;

/// ARMERÍA (panels.md § "Armería y Forja", v0.32.3 / v0.36.1): comprar y
/// vender armas en la plantilla `DsCraftGridTemplate` (buscador, chips,
/// grilla estilo INVENTARIO y detalle a la derecha). Como el INVENTARIO:
/// la ficha del mouse en cada casilla y, a la izquierda, la franja de
/// stats con los cambios contra la equipada. Mejorar, condensar y
/// fusionar están en la FORJA.

/// Key of the title of the long-text fold in the armory detail.
const kArmoryMoreDetail = 'ui.inventory.armory.more_detail';

/// Full weapon sheet for the armory detail panel: the same summary as
/// the inventory tooltip (name, rarity, base stats, mods, passive) with
/// the long text folded under [kArmoryMoreDetail].
class ArmoryItemSheet extends StatelessWidget {
  const ArmoryItemSheet({super.key, required this.shop, required this.item});

  final ShopContext shop;
  final ItemInstance item;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final parts = itemTipSummaryParts(shop.rules, item,
        level: p.level,
        attributes: p.attributes,
        equipped: item.uid == p.equippedUid);
    return RetroTipFolds(
        key: const ValueKey('armory-sheet'),
        summary: parts.summary,
        sections: [for (final (_, body) in parts.sections) (invStrings(context).t(kArmoryMoreDetail), body)],
        maxWidth: DsCraftGridTemplate.detailWidth);
  }
}

/// Shared wiring of both armory grids: tooltip per cell and the stats
/// strip of the inventory on the left.
class _ArmoryWeapons {
  _ArmoryWeapons(this.shop);

  final ShopContext shop;
  final _byId = <String, ItemInstance>{};

  Widget Function(Widget) tip(String id, ItemInstance it) {
    _byId[id] = it;
    final p = shop.profile;
    return (cell) => itemHoverTip(
        rules: shop.rules,
        viewer: p,
        item: it,
        attributes: p.attributes,
        equipped: it.uid == p.equippedUid,
        child: cell);
  }

  Widget side(DsCraftItem? focus) {
    final p = shop.profile;
    final it = focus == null ? null : _byId[focus.id];
    final using = shop.rules.equippedItem(p)?.uid;
    final to = it != null && it.uid != using ? it : null;
    return ChangeStrip(
        stats: stripStats(shop.rules, p, to: to, attributes: p.attributes),
        hovering: to != null);
  }
}

/// COMPRAR: las bases a la venta, con chips por clase.
class ArmoryBuyGrid extends StatelessWidget {
  const ArmoryBuyGrid({super.key, required this.shop});

  final ShopContext shop;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final rules = shop.rules;
    final classes = rules.catalog.classes;
    final list = shop.forSale()..sort((a, b) => a.level.compareTo(b.level));
    final weapons = _ArmoryWeapons(shop);
    final s = invStrings(context);
    return DsCraftGridTemplate(
      key: const ValueKey('armory-buy'),
      keyPrefix: 'armory-buy',
      searchHint: s.t('ui.inventory.armory.search_hint'),
      empty: s.t('ui.inventory.shop.buy.none_for_sale'),
      side: weapons.side,
      filters: [
        DsTransferFilter(s.t('ui.inventory.craft.all'), null),
        for (final c in classes.values)
          if (list.any((w) => w.classId == c.id))
            DsTransferFilter(c.name.toUpperCase(), c.id),
      ],
      items: [
        for (final w in list)
          () {
            final owned = p.items.any((i) => i.baseId == w.id);
            final why = owned ? s.t('ui.inventory.armory.owned') : shop.guards.buyWeapon(p, w.id);
            final sample =
                ItemInstance.common('_shop-${w.id}', w.id, itemLevel: w.level);
            return DsCraftItem(
              id: w.id,
              icon: PixelIcon(iconKeyForType(w.type),
                  accent: RarityColors.of(Rarity.comun),
                  procKey: procKeyForType(w.type)),
              border: RarityColors.of(Rarity.comun),
              name: w.text,
              tag: w.classId,
              search: '${w.text} ${w.name} ${w.type}',
              description:
                  '${w.type} · ${classes[w.classId]?.name ?? w.classId}',
              cellWrap: weapons.tip(w.id, sample),
              body: ArmoryItemSheet(shop: shop, item: sample),
              lines: [
                if (!rules.ignoreRequirements)
                  s.t('ui.inventory.armory.level', {'n': w.level}),
                s.t('ui.inventory.armory.price_have',
                    {'price': '₵${w.price}', 'credits': '₵${p.credits}'}),
                if (owned) s.t('ui.inventory.armory.owned'),
              ],
              actions: [
                DsButton(s.t('ui.inventory.shop.items.buy', {'price': '₵${w.price}'}),
                    key: ValueKey('buy-${w.id}'),
                    kind: DsButtonKind.primary,
                    size: DsButtonSize.compact,
                    tooltip: why,
                    onPressed: why == null
                        ? () => shop.controller.buyWeapon(w.id)
                        : null),
              ],
            );
          }(),
      ],
    );
  }
}

/// VENDER: tus armas (la equipada primero), con chips por rareza.
class ArmorySellGrid extends StatelessWidget {
  const ArmorySellGrid({super.key, required this.shop});

  final ShopContext shop;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final rules = shop.rules;
    final weapons = _ArmoryWeapons(shop);
    final s = invStrings(context);
    return DsCraftGridTemplate(
      key: const ValueKey('armory-sell'),
      keyPrefix: 'armory-sell',
      searchHint: s.t('ui.inventory.armory.search_hint'),
      empty: s.t('ui.inventory.armory.none_to_sell'),
      side: weapons.side,
      filters: [
        DsTransferFilter(s.t('ui.inventory.craft.all'), null),
        for (final r in Rarity.values)
          if (p.items.any((i) => i.rarity == r))
            DsTransferFilter(r.label.toUpperCase(), r.name),
      ],
      items: [
        for (final it in shop.owned)
          () {
            final w = rules.catalog.weapons[it.baseId];
            final a = CraftAction(CraftOp.sell, it.uid);
            final why = it.uid == p.equippedUid
                ? s.t('ui.inventory.armory.is_equipped')
                : shop.guards.craft(p, a);
            final price = rules.crafting.sellPrice(it);
            final name = shop.itemName(it);
            return DsCraftItem(
              id: it.uid,
              icon: PixelIcon(iconKeyForType(w?.type ?? ''),
                  accent: RarityColors.of(it.rarity),
                  procKey: procKeyForType(w?.type ?? '')),
              border: RarityColors.of(it.rarity),
              name: name,
              tag: it.rarity.name,
              search: '$name ${w?.type ?? ''}',
              description: '${w?.type ?? ''} · ${it.rarity.text} · '
                  '${s.t('ui.inventory.craft.level_short', {'n': it.itemLevel})}',
              cellWrap: weapons.tip(it.uid, it),
              body: ArmoryItemSheet(shop: shop, item: it),
              lines: [
                if (it.uid == p.equippedUid) s.t('ui.inventory.bag.equipped'),
                s.t('ui.inventory.armory.sells_for', {'price': '₵$price'}),
              ],
              actions: [
                DsButton(s.t('ui.inventory.bag.sell_for', {'price': '₵$price'}),
                    key: ValueKey('sell-${it.uid}'),
                    kind: DsButtonKind.primary,
                    size: DsButtonSize.compact,
                    tooltip: why,
                    onPressed:
                        why == null ? () => shop.controller.craft(a) : null),
              ],
            );
          }(),
      ],
    );
  }
}
