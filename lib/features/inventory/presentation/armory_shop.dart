import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../core/procedural/item_icons.dart' show procKeyForType;
import 'item_widgets.dart';
import 'shop_sections.dart';

/// ARMERÍA (panels.md § "Armería", v0.32.3): comprar y vender armas en la
/// plantilla `DsCraftGridTemplate` (buscador, chips, grilla estilo
/// INVENTARIO y detalle a la derecha). Mejorar, condensar y fusionar
/// están en la FORJA.

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
    return DsCraftGridTemplate(
      key: const ValueKey('armory-buy'),
      keyPrefix: 'armory-buy',
      searchHint: 'BUSCAR ARMA',
      empty: 'No hay armas a la venta.',
      filters: [
        const DsTransferFilter('TODAS', null),
        for (final c in classes.values)
          if (list.any((w) => w.classId == c.id))
            DsTransferFilter(c.name.toUpperCase(), c.id),
      ],
      items: [
        for (final w in list)
          () {
            final owned = p.items.any((i) => i.baseId == w.id);
            final why = owned ? 'Ya la tenés' : shop.guards.buyWeapon(p, w.id);
            return DsCraftItem(
              id: w.id,
              icon: PixelIcon(iconKeyForType(w.type),
                  accent: RarityColors.of(Rarity.comun),
                  procKey: procKeyForType(w.type)),
              border: RarityColors.of(Rarity.comun),
              name: w.name,
              tag: w.classId,
              search: '${w.name} ${w.type}',
              description:
                  '${w.type} · ${classes[w.classId]?.name ?? w.classId}',
              lines: [
                if (!rules.ignoreRequirements) 'Nivel ${w.level}',
                'Precio ₵${w.price} · tenés ₵${p.credits}',
                if (owned) 'Ya la tenés',
              ],
              actions: [
                DsButton('COMPRAR ₵${w.price}',
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
    return DsCraftGridTemplate(
      key: const ValueKey('armory-sell'),
      keyPrefix: 'armory-sell',
      searchHint: 'BUSCAR ARMA',
      empty: 'No tenés armas para vender.',
      filters: [
        const DsTransferFilter('TODAS', null),
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
                ? 'Es la equipada'
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
              description: '${w?.type ?? ''} · ${it.rarity.label} · '
                  'Nv ${it.itemLevel}',
              lines: [
                if (it.uid == p.equippedUid) 'EQUIPADA',
                'Se vende por ₵$price',
              ],
              actions: [
                DsButton('VENDER ₵$price',
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
