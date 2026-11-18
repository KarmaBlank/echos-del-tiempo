import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/inventory_sort.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/inventory/loot_fixtures.dart';
import 'session_test_helpers.dart';

/// Inventario v0.5.1 (loot.md § 17): secciones de pilas fuera de la
/// grilla, ORDENAR y la elección manual de LIMPIAR INVENTARIO.
void main() {
  final inv = progression.inventory;
  final craft = progression.crafting;

  /// [p] con la grilla llena de armas Comunes.
  PlayerProfile fill(PlayerProfile p) {
    while (InventoryRules.freeCells(p) > 0) {
      p = InventoryRules.addItem(
              p, const ItemInstance(uid: 'x', baseId: 'espada_ignea'))
          .$1;
    }
    return p;
  }

  group('secciones de pilas', () {
    test('las pilas no ocupan casilla: solo armas y Ecos', () {
      final p = lootWarrior(materials: const {
        CraftMaterial.esquirla: 5,
        CraftMaterial.ancla: 1,
      });
      expect(p.potions, greaterThan(0));
      final toks = InventoryRules.tokens(p);
      expect(toks, ['e1', 'r1', 'm1', 'c1', 'l1']);
      expect(InventoryRules.cellsUsed(p), 5);
      expect(InventoryRules.freeCells(p), 35);
      expect(InventoryRules.consumables, [StackKind.potion, StackKind.ether]);
      expect(InventoryRules.materials, [
        StackKind.esquirla,
        StackKind.cristal,
        StackKind.prisma,
        StackKind.ancla,
        // v0.8: Fragmentos y Esencia del Abismo.
        StackKind.fragReloj,
        StackKind.fragEco,
        StackKind.fragCorona,
        StackKind.fragEras,
        StackKind.esencia,
      ]);
    });

    test('migración: pilas guardadas en la grilla liberan su casilla', () {
      final base = lootWarrior();
      final old = base.copyWith(grid: [
        'pot', 'eter', 'mat:esquirla', //
        'r1', 'e1', 'm1', 'c1', 'l1',
      ]);
      final l = InventoryRules.layout(old);
      expect(l.cells.take(3), [null, null, null]);
      expect(l.cells[3], 'r1', reason: 'las armas conservan su lugar');
      // Guardado viejo (JSON) → normalize: nada se pierde.
      final json = old.toJson();
      final back = progression.normalize(PlayerProfile.fromJson(json));
      expect(back.grid, isNot(contains('pot')));
      expect(back.grid, isNot(contains('mat:esquirla')));
      expect(back.grid.indexOf('r1'), 3);
      expect(back.potions, base.potions);
      expect(back.ethers, base.ethers);
      expect(back.material(CraftMaterial.esquirla),
          base.material(CraftMaterial.esquirla));
    });

    test('grilla llena: entran pilas (nuevas o no), no armas', () {
      final p = fill(lootWarrior(materials: const {}));
      expect(InventoryRules.freeCells(p), 0);
      expect(
          InventoryRules.cannotReceive(
              p, const LootDrop.stack(StackKind.prisma, 1)),
          isNull);
      expect(InventoryRules.receive(p, const LootDrop.stack(StackKind.prisma, 2))!
          .material(CraftMaterial.prisma), 2);
      expect(InventoryRules.cannotReceive(p, const LootDrop.item(rareAxe)),
          'Inventario lleno');
      // Comprar pociones con la grilla llena: sí (con lugar en la pila).
      final rich = p.copyWith(credits: 9999, potions: 0);
      expect(progression.buyItem(rich, BattleItem.potion)!.potions, 1);
    });

    test('dar y levantar pilas con la grilla llena (host)', () {
      final e = sessionEngine();
      final full = fill(lootWarrior(materials: const {}));
      var s = e.addPlayer(e.create(), 'p0',
          lootWarrior(materials: const {CraftMaterial.cristal: 4}))!.state;
      s = e.addPlayer(s, 'p1', full)!.state;
      final s2 = e.apply(
          s, 'p0', const GiveItemAction('p1', 'mat:cristal', count: 3))!.state;
      expect(s2.players['p1']!.profile.material(CraftMaterial.cristal), 3);
      expect(e.apply(s2, 'p0', const GiveItemAction('p1', 'r1')), isNull,
          reason: 'arma: sin casilla');
      // Levantar del piso: pila sí.
      final p1 = s2.players['p1']!;
      s2.ground.add(GroundLoot(
          id: 7,
          drop: const LootDrop.stack(StackKind.esquirla, 2),
          x: p1.x,
          y: p1.y));
      final s3 = e.apply(s2, 'p1', const PickUpAction(7))!.state;
      expect(s3.players['p1']!.profile.material(CraftMaterial.esquirla), 2);
    });

    test('alijo: materiales salen con la grilla llena; armas no', () {
      final rules = StashRules(inventory: inv);
      final p = fill(lootWarrior(materials: const {}));
      final s = Stash.empty()
          .put(0, const StashEntry.material(CraftMaterial.cristal, 5))
          .put(1, const StashEntry.item(rareAxe));
      final m = rules.withdraw(p, s, 0);
      expect(m.ok, isTrue);
      expect(m.profile!.material(CraftMaterial.cristal), 5);
      expect(rules.withdraw(p, s, 1).error, 'Inventario lleno');
      // Guardar materiales no cambia la grilla.
      final d = rules.deposit(m.profile!, Stash.empty(), 'mat:cristal');
      expect(InventoryRules.cellsUsed(d.profile!), InventoryRules.cellsUsed(p));
    });
  });

  group('ORDENAR', () {
    final p = lootWarrior();

    test('rareza: de mayor a menor, la equipada primero', () {
      expect(inv.sortOrder(p, InventorySortKey.rarity),
          ['espada_bronce', 'l1', 'e1', 'r1', 'm1', 'c1']);
      final sorted = inv.sort(p, InventorySortKey.rarity);
      expect(InventoryRules.layout(sorted).cells.take(5),
          ['l1', 'e1', 'r1', 'm1', 'c1']);
      expect(InventoryRules.tokens(sorted), isNot(contains('espada_bronce')));
    });

    test('nivel de objeto: mayor primero, empata la rareza', () {
      expect(inv.sortOrder(p, InventorySortKey.itemLevel),
          ['espada_bronce', 'e1', 'r1', 'l1', 'm1', 'c1']);
    });

    test('tipo de arma: alfabético; dentro, rareza', () {
      final order = inv.sortOrder(p, InventorySortKey.weaponType).skip(1);
      String type(String uid) =>
          progression.catalog.weapons[p.itemByUid(uid)!.baseId]!.type;
      final types = order.map(type).toList();
      expect(types, [...types]..sort());
      final hachas = [for (final u in order) if (type(u) == type('r1')) u];
      expect(hachas, ['l1', 'r1']);
    });

    test('nombre: alfabético sin tildes', () {
      final order = inv.sortOrder(p, InventorySortKey.name).skip(1);
      final names = [
        for (final u in order)
          progression.items.displayName(p.itemByUid(u)!).toLowerCase()
      ];
      expect(names, [...names]..sort());
    });

    test('recientes: lo nuevo primero (armas y Ecos)', () {
      var q = InventoryRules.addItem(p, rareAxe).$1;
      final newest = q.items.last.uid;
      expect(newest, startsWith('i'));
      final order = inv.sortOrder(q, InventorySortKey.recent);
      expect(order.first, 'espada_bronce');
      expect(order[1], newest);
      // Sin número: el orden de llegada, de la última a la primera.
      expect(order.sublist(2), ['l1', 'c1', 'm1', 'r1', 'e1']);
    });

    test('determinístico: no depende del orden de la lista', () {
      final shuffled = p.copyWith(items: p.items.reversed.toList());
      for (final k in InventorySortKey.values) {
        if (k == InventorySortKey.recent) continue;
        expect(inv.sortOrder(shuffled, k), inv.sortOrder(p, k), reason: k.name);
        expect(inv.sort(inv.sort(p, k), k).grid, inv.sort(p, k).grid);
      }
    });

    test('host: SortInventoryAction, también en pausa', () {
      final e = sessionEngine();
      final s = e.addPlayer(e.create(), 'p0', p)!.state;
      final s2 = e.apply(s, 'p0',
          const SortInventoryAction(InventorySortKey.rarity))!.state;
      expect(InventoryRules.layout(s2.players['p0']!.profile).cells.first, 'l1');
      s2.pausedBy = 'p0';
      expect(
          e.apply(s2, 'p0', const SortInventoryAction(InventorySortKey.name)),
          isNotNull);
    });
  });

  group('LIMPIAR: elección manual', () {
    final p = lootWarrior();

    test('protegidas: la equipada y la última inicial no se eligen', () {
      expect(craft.salvageSelected(p, ['e1', 'espada_bronce']).error,
          'Está equipada');
      final q = p.copyWith(equipped: 'r1');
      expect(craft.selectionBlock(q, 'espada_bronce'), 'Arma inicial');
      expect(craft.sellSelected(q, ['espada_bronce']).error, 'Arma inicial');
      expect(craft.sellSelected(p, ['nada']).error, 'No la tienes');
      expect(craft.sellSelected(p, const []).error, 'Elige armas');
      // Dos iniciales: se elige una sola.
      final two = InventoryRules.addItem(
              q, const ItemInstance(uid: 'x', baseId: 'espada_bronce'))
          .$1;
      final copy = two.items.last.uid;
      expect(craft.selectionBlock(two, 'espada_bronce'), isNull);
      expect(craft.selectionBlock(two, 'espada_bronce', others: [copy]),
          'Arma inicial');
      expect(craft.sellSelected(two, ['espada_bronce', copy]).error,
          'Arma inicial');
      expect(craft.sellSelected(two, [copy]).ok, isTrue);
    });

    test('vender: vista previa = resultado; repetidos cuentan una vez', () {
      final r = craft.sellSelected(p, ['m1', 'c1', 'm1']);
      expect(r.ok, isTrue);
      expect(r.consumed, ['m1', 'c1']);
      final price = craft.sellPrice(magicKatana) + craft.sellPrice(commonStaff);
      expect(r.gainedCredits, price);
      expect(r.profile!.credits, p.credits + price);
      expect(r.profile!.itemByUid('m1'), isNull);
      // Host: lo mismo.
      final e = sessionEngine();
      final s = e.addPlayer(e.create(), 'p0', p)!.state;
      final s2 = e.apply(s, 'p0',
          CraftAction.selected(CraftOp.sellSelected, const ['m1', 'c1']))!.state;
      final after = s2.players['p0']!.profile;
      expect(after.credits, p.credits + price);
      expect(after.itemByUid('c1'), isNull);
      expect(e.apply(s, 'p0',
              CraftAction.selected(CraftOp.sellSelected, const ['espada_bronce'])),
          isNull);
    });

    test('desarmar sin tirada (Común, Legendario): vista previa = resultado',
        () {
      final preview = craft.salvageSelected(p, ['c1', 'l1']);
      expect(preview.ok, isTrue);
      expect(preview.chances, isEmpty);
      final done = craft.salvageSelected(p, ['c1', 'l1'], random: () => 0.0);
      expect(done.gainedMaterials, preview.gainedMaterials);
      for (final m in preview.gainedMaterials.keys) {
        expect(done.profile!.material(m),
            p.material(m) + preview.gainedMaterials[m]!);
      }
      // Igual que el lote de la rareza cuando la elección es la misma.
      expect(craft.salvageSelected(p, ['c1']).gainedMaterials,
          craft.salvageAll(p, Rarity.comun).gainedMaterials);
    });
  });

  group('red (protocolo 6, aditivo)', () {
    test('invSort ida y vuelta, todas las claves', () {
      for (final k in InventorySortKey.values) {
        final j = ActionJson.toJson(SortInventoryAction(k));
        expect(j, {'t': 'invSort', 'k': k.name});
        final back = ActionJson.fromJson(j) as SortInventoryAction;
        expect(back.key, k);
      }
      expect(() => ActionJson.fromJson({'t': 'invSort', 'k': 'peso'}),
          throwsFormatException);
    });

    test('craft con uids ida y vuelta; sin uids no cambia el formato', () {
      final a = CraftAction.selected(CraftOp.salvageSelected, const ['a', 'b']);
      final j = ActionJson.toJson(a);
      expect(j, {'t': 'craft', 'op': 'salvageSelected', 'w': '*', 'us': ['a', 'b']});
      final back = ActionJson.fromJson(j) as CraftAction;
      expect(back.op, CraftOp.salvageSelected);
      expect(back.uids, ['a', 'b']);
      final old = ActionJson.toJson(CraftAction.batch(CraftOp.sellAll, Rarity.raro));
      expect(old.containsKey('us'), isFalse);
      expect((ActionJson.fromJson(old) as CraftAction).uids, isEmpty);
      expect(() => ActionJson.fromJson({
            't': 'craft',
            'op': 'sellSelected',
            'w': '*',
            'us': [1],
          }), throwsFormatException);
    });
  });
}
