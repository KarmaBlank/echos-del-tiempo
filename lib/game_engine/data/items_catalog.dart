import '../models/battle_command.dart';
import '../models/item_def.dart';

/// Máximo de cada consumible que se puede llevar (`MAX_ITEM`).
const int kMaxItemStack = 9;

/// `ITEMS` del prototipo, 1:1.
const Map<BattleItem, ItemDef> kItems = {
  BattleItem.potion: ItemDef(
    item: BattleItem.potion,
    key: 'pot',
    name: 'Poción de vida',
    description: 'En combate eliges a quién: cura 45% de su vida máx., '
        'revive y quita quemadura y veneno',
    price: 30,
  ),
  BattleItem.ether: ItemDef(
    item: BattleItem.ether,
    key: 'eter',
    name: 'Poción de maná',
    description: 'En combate eliges a quién: restaura 50% de su maná máx.',
    price: 40,
  ),
};
