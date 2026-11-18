import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';
import '../inventory/loot_fixtures.dart';

void main() {
  final rules = StashRules(inventory: progression.inventory);

  /// Guerrero con dos armas extra y materiales.
  PlayerProfile hero({Map<CraftMaterial, int> mats = const {}}) {
    var p = newProfile('Ana', 'guerrero');
    p = InventoryRules.addItem(p, epicSword).$1;
    p = InventoryRules.addItem(p, rareAxe).$1;
    return InventoryRules.relayout(p.copyWith(materials: mats));
  }

  String uidOf(PlayerProfile p, String base) =>
      p.items.firstWhere((i) => i.baseId == base).uid;

  group('guardar en el alijo', () {
    test('un arma pasa al alijo y deja de estar en el personaje', () {
      final p = hero();
      final uid = uidOf(p, 'espada_ignea');
      final m = rules.deposit(p, Stash.empty(), uid);
      expect(m.ok, isTrue);
      expect(m.profile!.itemByUid(uid), isNull);
      expect(InventoryRules.cellsUsed(m.profile!),
          InventoryRules.cellsUsed(p) - 1);
      expect(m.stash!.cells[0]!.item!.name, 'Filo del Alba');
      expect(m.stash!.cells[0]!.item!.rarity, Rarity.epico);
    });

    test('en la pestaña a la vista; si está llena, la otra', () {
      final p = hero();
      final m =
          rules.deposit(p, Stash.empty(), uidOf(p, 'hacha_rompe'), tab: 1);
      expect(m.stash!.cells[Stash.perTab], isNotNull);
      var full = Stash.empty();
      for (var i = Stash.perTab; i < Stash.size; i++) {
        full = full.put(i, const StashEntry.item(rareAxe));
      }
      final m2 = rules.deposit(p, full, uidOf(p, 'hacha_rompe'), tab: 1);
      expect(m2.stash!.cells[0], isNotNull);
    });

    test('no se guardan la equipada, la última inicial ni pociones', () {
      final p = hero();
      expect(rules.deposit(p, Stash.empty(), p.equippedUid!).error, 'Equipada');
      // Equipada otra: la inicial (única) sigue protegida.
      final q = p.copyWith(equipped: uidOf(p, 'hacha_rompe'));
      expect(rules.deposit(q, Stash.empty(), uidOf(q, 'espada_bronce')).error,
          'Arma inicial');
      expect(rules.deposit(p, Stash.empty(), 'pot').error,
          StashRules.potionsError);
      expect(rules.deposit(p, Stash.empty(), 'eter').error,
          StashRules.potionsError);
    });

    test('alijo lleno', () {
      var full = Stash.empty();
      for (var i = 0; i < Stash.size; i++) {
        full = full.put(i, const StashEntry.item(rareAxe));
      }
      final p = hero();
      expect(rules.deposit(p, full, uidOf(p, 'hacha_rompe')).error,
          StashRules.stashFull);
    });

    test('materiales: se apilan en una casilla hasta 999', () {
      final p = hero(mats: {CraftMaterial.cristal: 60});
      final s = Stash.empty()
          .put(7, const StashEntry.material(CraftMaterial.cristal, 950));
      final m = rules.deposit(p, s, 'mat:cristal');
      expect(m.stash!.cells[7]!.count, 999);
      expect(m.stash!.used, 1);
      expect(m.profile!.material(CraftMaterial.cristal), 11,
          reason: 'lo que no entra queda en el personaje');
      expect(rules.deposit(m.profile!, m.stash!, 'mat:cristal').error,
          contains('999'));

      final m2 = rules.deposit(
          hero(mats: {CraftMaterial.prisma: 5}), Stash.empty(), 'mat:prisma');
      expect(m2.stash!.cells[0]!.material, CraftMaterial.prisma);
      expect(m2.stash!.cells[0]!.count, 5);
      expect(m2.profile!.material(CraftMaterial.prisma), 0);
      expect(InventoryRules.tokens(m2.profile!), isNot(contains('mat:prisma')));
    });
  });

  group('sacar del alijo', () {
    test('un arma vuelve con un uid nuevo del personaje', () {
      final p = newProfile('Bo', 'tirador');
      final s = Stash.empty().put(12, const StashEntry.item(epicSword));
      final m = rules.withdraw(p, s, 12);
      expect(m.ok, isTrue);
      expect(m.stash!.cells[12], isNull);
      final got =
          m.profile!.items.firstWhere((i) => i.baseId == 'espada_ignea');
      expect(got.name, 'Filo del Alba');
      expect(got.affixes, epicSword.affixes);
      expect(m.profile!.items.map((i) => i.uid).toSet().length,
          m.profile!.items.length);
      expect(rules.withdraw(p, s, 3).error, 'Casilla vacía');
    });

    test('inventario lleno: no sale', () {
      var p = newProfile('Bo', 'tirador');
      while (InventoryRules.freeCells(p) > 0) {
        p = InventoryRules.addItem(p, rareAxe).$1;
      }
      final s = Stash.empty().put(0, const StashEntry.item(epicSword));
      expect(rules.withdraw(p, s, 0).error, 'Inventario lleno');
    });

    test('materiales: lo que entre (tope 99), el resto queda', () {
      final p = hero(mats: {CraftMaterial.esquirla: 90});
      final s = Stash.empty()
          .put(4, const StashEntry.material(CraftMaterial.esquirla, 30));
      final m = rules.withdraw(p, s, 4);
      expect(m.profile!.material(CraftMaterial.esquirla), 99);
      expect(m.stash!.cells[4]!.count, 21);
      expect(rules.withdraw(m.profile!, m.stash!, 4).error, 'Máximo 99');
      final all = rules.withdraw(hero(), s, 4);
      expect(all.profile!.material(CraftMaterial.esquirla), 30);
      expect(all.stash!.cells[4], isNull);
    });
  });

  test('mover dentro del alijo intercambia casillas', () {
    final s = Stash.empty().put(0, const StashEntry.item(epicSword));
    final t = StashRules.move(s, 0, 60)!;
    expect(t.cells[0], isNull);
    expect(t.cells[60]!.item!.uid, 'e1');
    expect(StashRules.move(s, 5, 6), isNull, reason: 'origen vacío');
    expect(StashRules.move(s, 0, Stash.size), isNull);
  });

  test('JSON: sanea armas, descarta lo inválido y junta pilas', () {
    final s = Stash.fromJson({
      'cells': [
        {'i': 0, ...const StashEntry.item(epicSword).toJson()},
        {
          'i': 1,
          'it': {'u': 'z', 'b': 'no_existe'}
        },
        {'i': 2, 'm': 'cristal', 'n': 10},
        {'i': 3, 'm': 'cristal', 'n': 995},
        {'i': 4, 'm': 'oro', 'n': 3},
        {'i': 999, 'm': 'prisma', 'n': 1},
        {'i': 0, 'm': 'prisma', 'n': 1},
        'basura',
      ],
    });
    expect(s.cells[0]!.item!.name, 'Filo del Alba');
    expect(s.cells[1], isNull);
    expect(s.cells[2]!.count, Stash.maxMaterialStack);
    expect(s.cells[3], isNull);
    expect(s.used, 2);
  });
}
