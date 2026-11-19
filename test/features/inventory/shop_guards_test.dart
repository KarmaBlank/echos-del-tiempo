import 'package:echos_del_tiempo/features/inventory/domain/shop_guards.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// La UI deshabilita exactamente lo que el motor rechaza: para cada
/// acción de los paneles, `guard == null` ⇔ `engine.apply != null`.
void main() {
  final profiles = [
    progression.normalize(PlayerProfile(
        name: 'A',
        classId: 'guerrero',
        level: 5,
        credits: 700,
        attributes: const PlayerAttributes({
          Attribute.vit: 10,
          Attribute.esp: 4,
          Attribute.agi: 6,
          Attribute.fue: 16,
          Attribute.des: 10,
        }),
        points: 4,
        potions: 9,
        inventory: const ['espada_bronce', 'espada_ignea', 'hacha_rompe'],
        upgrades: const {})),
    progression.normalize(PlayerProfile(
        name: 'B', classId: 'maga', credits: 45, ethers: 0)),
  ];

  /// Una sala en [mode] con el perfil [p] como 'p0'.
  (SessionEngine, GameSession) room(PlayerProfile p, SessionMode mode) {
    final e = sessionEngine();
    if (mode == SessionMode.field) {
      return (e, inField(e, 'm1', profiles: [p]));
    }
    var s = e.addPlayer(e.create(), 'p0', p)!.state;
    if (mode == SessionMode.prep) {
      s = act(e, s, 'p0', const ProposeMissionAction('m1'));
      s = e.tick(s, 0.05).state;
    }
    expect(s.mode, mode);
    return (e, s);
  }

  for (final mode in [SessionMode.lobby, SessionMode.prep, SessionMode.field]) {
    for (final p in profiles) {
      test('${p.classId} en ${mode.name}: motivos = rechazos del motor', () {
        final (e, s) = room(p, mode);
        final prof = s.players['p0']!.profile;
        final g = ShopGuards(e.progression, s.mode);
        void same(String? reason, SessionAction a) {
          final ok = e.apply(s, 'p0', a) != null;
          expect(reason == null, ok, reason: '$a: "$reason" vs motor $ok');
        }

        // Loot v2: cualquier base a la venta, cualquier clase.
        for (final w in kWeapons.values) {
          if (w.price > 0) same(g.buyWeapon(prof, w.id), BuyWeaponAction(w.id));
        }
        for (final it in prof.items) {
          if (it.uid != prof.equippedUid) {
            same(g.equip(prof, it.uid), EquipAction(it.uid));
          }
          final w = kWeapons[it.baseId]!;
          for (final st in e.progression.upgradeStatsFor(w)) {
            same(g.upgrade(prof, it.uid, st), UpgradeAction(it.uid, st));
          }
          // Mesa de fusión: cada operación contra cada fuente posible.
          for (final op in CraftOp.values) {
            final sources = op == CraftOp.transferAffix ||
                    op == CraftOp.transferPassive ||
                    op == CraftOp.transferSkill
                ? [for (final x in prof.items) x.uid]
                : <String?>[null];
            for (final src in sources) {
              final skills = src == null
                  ? <String?>[null]
                  : e.progression.items.skillsOf(prof.itemByUid(src)!);
              for (final sk in op == CraftOp.transferSkill ? skills : [null]) {
                final a = CraftAction(op, it.uid,
                    sourceUid: src, index: 0, skillId: sk);
                same(g.craft(prof, a), a);
              }
            }
          }
        }
        for (final it in BattleItem.values) {
          same(g.buyItem(prof, it), BuyItemAction(it));
        }
        // Dar sin compañeros y tirar al piso.
        for (final t in InventoryRules.tokens(prof)) {
          expect(g.give(prof, t, null), isNotNull);
          same(g.drop(prof, t, alive: s.players['p0']!.alive),
              DropItemAction(t));
        }
        same(g.respec(), const RespecAction());
        for (final cls in ['guerrero', 'maga']) {
          same(g.changeClass(prof, cls), ChangeClassAction(cls));
        }
        if (prof.points > 0) {
          same(g.allocate(prof, {Attribute.vit: 1}),
              const AllocateStatsAction({Attribute.vit: 1}));
        }
      });
    }
  }

  test('upgrade al máximo: MAX', () {
    // Loot v2: el tope total de forja depende de la rareza (Común 3); una
    // Épica (8) llega al tope de 5 por estadística. v0.9: y del nivel de
    // objeto (2 + nivel/5), por eso nivel 30.
    final p = progression.normalize(PlayerProfile(
        name: 'A',
        classId: 'guerrero',
        credits: 5000,
        items: const [
          ItemInstance(
              uid: 'espada_bronce',
              baseId: 'espada_bronce',
              rarity: Rarity.epico,
              itemLevel: 30),
        ]));
    var q = p;
    for (var i = 0; i < 5; i++) {
      q = progression.upgrade(q, 'espada_bronce', UpgradeStat.pow)!;
    }
    final g = ShopGuards(progression, SessionMode.lobby);
    expect(g.upgrade(q, 'espada_bronce', UpgradeStat.pow), 'MAX');
    expect(g.upgrade(q, 'espada_bronce', UpgradeStat.crit), isNull);
  });

  test('reiniciar es gratis y vale en todo modo salvo batalla (freeRespec)',
      () {
    final p = newProfile('A', 'guerrero');
    final withTree = p.copyWith(level: 3, tree: ['gue_r1']);
    for (final m in SessionMode.values) {
      final g = ShopGuards(progression, m);
      final battle = m == SessionMode.battle;
      expect(g.showRespec, !battle, reason: m.name);
      expect(g.respec(), battle ? 'No en batalla' : isNull, reason: m.name);
      expect(g.resetTree(withTree), battle ? 'No en batalla' : isNull,
          reason: m.name);
    }
  });
}
