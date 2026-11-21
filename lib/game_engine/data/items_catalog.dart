import '../models/battle_command.dart';
import '../models/item_def.dart';

/// Máximo de cada consumible que se puede llevar (`MAX_ITEM`).
const int kMaxItemStack = 9;

/// `ITEMS` del prototipo + el Éter (loot.md § 17.6). Los precios salen
/// de `kTuning` (Editor → Balance → Consumibles).
const Map<BattleItem, ItemDef> kItems = {
  BattleItem.potion: ItemDef(
    item: BattleItem.potion,
    key: 'pot',
    name: 'Poción de vida',
    description: 'En combate eliges a quién: cura 45% de su vida máx., '
        'revive y quita quemadura y veneno',
  ),
  BattleItem.ether: ItemDef(
    item: BattleItem.ether,
    key: 'eter',
    name: 'Poción de maná',
    description: 'En combate eliges a quién: restaura 50% de su maná máx.',
  ),
  BattleItem.aether: ItemDef(
    item: BattleItem.aether,
    key: 'eterV',
    name: 'Éter',
    description: 'Solo en combate: un eco de su presente devuelve a un '
        'aliado caído con toda la vida y le quita quemadura y veneno',
  ),
};
