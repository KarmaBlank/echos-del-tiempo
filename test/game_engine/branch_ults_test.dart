import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/branch_ults_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/elements_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/summoner_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/loot_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ult_def.dart';
import 'package:flutter_test/flutter_test.dart';

// ULT de camino en armas (docs/specs/branch_ults.md).

const _startNodes = PassiveTreeCatalog(
  nodes: {
    's_gue': PassiveNode(id: 's_gue', x: 0, y: -1.1, name: 'Inicio: Guerrero', kind: 'st', effects: {}, links: []),
    's_mag': PassiveNode(id: 's_mag', x: 1.1, y: 0, name: 'Inicio: Maga', kind: 'st', effects: {}, links: []),
    's_tir': PassiveNode(id: 's_tir', x: 0, y: 1.1, name: 'Inicio: Tirador', kind: 'st', effects: {}, links: []),
    's_pal': PassiveNode(id: 's_pal', x: -1.1, y: 0, name: 'Inicio: Paladín', kind: 'st', effects: {}, links: []),
  },
  startNodeByClass: {'guerrero': 's_gue', 'maga': 's_mag', 'tirador': 's_tir', 'paladin': 's_pal'},
  exclusions: {},
);

const _stats = StatsCalculator(classes: kClasses, treeRules: PassiveTreeRules(_startNodes));

/// Primera base de [type] (la de menor nivel).
String _baseOf(String type) => (kWeapons.values.where((w) => w.type == type).toList()
      ..sort((a, b) => a.level.compareTo(b.level)))
    .first
    .id;

void main() {
  group('catálogo', () {
    test('3 ULT por cada camino del árbol (menos el Invocador), ids únicos', () {
      final paths = kPassiveTree.paths.keys.toSet()..remove('invocador');
      expect(kBranchUlts.keys.toSet(), paths);
      for (final e in kBranchUlts.entries) {
        expect(e.value, hasLength(3), reason: e.key);
      }
      expect(kBranchUltSkills, hasLength(kBranchUltList.length));
      expect(kBranchUltSkills.length, paths.length * 3);
      final names = {for (final s in kBranchUltSkills.values) s.name};
      expect(names, hasLength(kBranchUltSkills.length), reason: 'nombres repetidos');
      final taken = {
        ...kSkills.keys,
        for (final u in kAllUltimates.values) u.id,
        for (final u in kAscensionUltimates.values) u.id,
        ...kSummonerUltimates.keys,
      };
      for (final id in kBranchUltSkills.keys) {
        expect(taken, isNot(contains(id)), reason: id);
      }
    });

    test('tipos de arma válidos, look de una ULT existente y elemento', () {
      final looks = {
        for (final u in kAllUltimates.values) u.id,
        for (final u in kAscensionUltimates.values) u.id,
      };
      for (final id in kBranchUltSkills.keys) {
        final types = kBranchUltWeaponTypes[id]!;
        expect(types, isNotEmpty, reason: id);
        for (final t in types) {
          expect(kWeaponTypeCategory, contains(t), reason: '$id: $t');
        }
        expect(looks, contains(kBranchUltLooks[id]), reason: id);
        expect(kBranchUltElement, contains(id));
      }
      expect(elementOf('ult_infierno'), GameElement.fuego);
      expect(elementOf('ult_tsunami'), GameElement.agua);
      expect(elementOf('ult_tormentaRayos'), GameElement.electro);
      // Todo tipo de arma tiene al menos una ULT posible.
      for (final t in kWeaponTypeCategory.keys) {
        expect(branchUltsForType(t), isNotEmpty, reason: t);
      }
    });

    test('las ULT de los legendarios (de camino o v2) van con el tipo de su base', () {
      final withUlt = kUniques.values.where((u) => u.ultId != null).toList();
      expect(withUlt.length, greaterThanOrEqualTo(12));
      for (final u in withUlt) {
        final type = kWeapons[u.baseId]!.type;
        final types = kBranchUltWeaponTypes[u.ultId] ?? kUltV2[u.ultId]!.weapons;
        expect(types, contains(type), reason: u.id);
      }
    });
  });

  group('objeto', () {
    const items = ItemRules();

    test('JSON ida y vuelta con el mod ULT', () {
      const it = ItemInstance(uid: 'x', baseId: 'espada_bronce', rarity: Rarity.raro, ultId: 'ult_guillotina');
      final back = ItemInstance.fromJson(it.toJson())!;
      expect(back, it);
      expect(back.ultId, 'ult_guillotina');
      // Sin mod: el JSON no cambia (aditivo).
      const plain = ItemInstance(uid: 'y', baseId: 'espada_bronce');
      expect(plain.toJson().containsKey('ul'), isFalse);
    });

    test('sanitize: descarta el mod en un tipo incompatible, desconocido o en Común', () {
      final ok = items.sanitize(const ItemInstance(uid: 'a', baseId: 'espada_bronce', rarity: Rarity.epico, ultId: 'ult_guillotina'))!;
      expect(ok.ultId, 'ult_guillotina');
      final wrongType = items.sanitize(const ItemInstance(uid: 'b', baseId: 'espada_bronce', rarity: Rarity.raro, ultId: 'ult_tsunami'))!;
      expect(wrongType.ultId, isNull);
      final unknown = items.sanitize(const ItemInstance(uid: 'c', baseId: 'espada_bronce', rarity: Rarity.raro, ultId: 'nada'))!;
      expect(unknown.ultId, isNull);
      final common = items.sanitize(const ItemInstance(uid: 'd', baseId: 'espada_bronce', ultId: 'ult_guillotina'))!;
      expect(common.ultId, isNull);
    });

    test('itemUlt: mod > legendario; sin nada, null', () {
      expect(itemUlt(const ItemInstance(uid: 'a', baseId: 'espada_bronce', rarity: Rarity.raro, ultId: 'ult_guillotina'))!.name,
          'Guillotina');
      final u = kUniques['segadoraEras']!;
      expect(itemUlt(ItemInstance(uid: 'b', baseId: u.baseId, rarity: Rarity.legendario, uniqueId: u.id))!.id, u.ultId);
      expect(itemUlt(const ItemInstance(uid: 'c', baseId: 'espada_bronce')), isNull);
    });
  });

  group('botín', () {
    const loot = LootRules();

    test('probabilidad por rareza y compatibilidad de tipo', () {
      expect(loot.rollUltMod(() => 0.079, Rarity.raro, 'arco'), isNotNull);
      expect(loot.rollUltMod(() => 0.081, Rarity.raro, 'arco'), isNull);
      expect(loot.rollUltMod(() => 0.19, Rarity.epico, 'arco'), isNotNull);
      expect(loot.rollUltMod(() => 0.21, Rarity.epico, 'arco'), isNull);
      expect(loot.rollUltMod(() => 0.0, Rarity.magico, 'arco'), isNull);
      expect(loot.rollUltMod(() => 0.0, Rarity.comun, 'arco'), isNull);
      for (var i = 0; i < 20; i++) {
        final r = i / 20;
        var first = true;
        final u = loot.rollUltMod(() {
          if (first) {
            first = false;
            return 0.0;
          }
          return r;
        }, Rarity.epico, 'arco');
        // v0.17: el pool del mod son las ULT v2 del tipo (§ 6, resp. 1).
        expect(kUltV2[u]!.weapons, contains('arco'));
        expect(kUltV2[u]!.source, UltSource.weaponMod);
      }
    });

    test('generate: un Raro con el mod sale con una ULT de su tipo', () {
      final it = loot.generate(() => 0.0, itemLevel: 10, rarity: Rarity.raro, baseId: 'espada_bronce');
      expect(it.ultId, isNotNull);
      expect(kUltV2[it.ultId]!.weapons, contains('espada'));
      final no = loot.generate(() => 0.99, itemLevel: 10, rarity: Rarity.raro, baseId: 'espada_bronce');
      expect(no.ultId, isNull);
    });
  });

  group('filtro', () {
    test('ULT / ULT <nombre> / ULT No', () {
      const it = ItemInstance(uid: 'a', baseId: 'espada_bronce', rarity: Rarity.raro, ultId: 'ult_guillotina');
      expect(const UltCondition().text, 'ULT');
      expect(const UltCondition(name: 'Guillotina').text, 'ULT Guillotina');
      expect(const UltCondition(has: false).text, 'ULT No');
      expect(itemUlt(it), isNotNull);
    });
  });

  group('motor', () {
    BattleState start(BattleEngine e, ItemInstance it, {String? ultSel}) {
      final w = kWeapons[it.baseId]!;
      final cls = kClasses[w.classId] ?? kClasses['guerrero']!;
      final s = e.start(party: [
        BattlePartyMember(
          id: 'p1',
          name: 'P1',
          build: PlayerBuild(
            classId: cls.id,
            level: 20,
            attributes: PlayerAttributes.base(cls.baseAttributes),
            equippedWeapon: w,
            item: it,
            ultSel: ultSel,
          ),
        ),
      ], enemyTypes: const ['golem', 'golem']).state;
      s.party.first
        ..mp = 999
        ..ult = 100;
      s.currentId = 'p1';
      return s;
    }

    test('el mod no impone su ULT: vale solo si se elige en el menú, y cada ULT de camino se ejecuta', () {
      final e = BattleEngine(stats: _stats, random: () => 0.5, breakEnabled: false, familiesEnabled: false);
      for (final s in kBranchUltSkills.values) {
        final base = _baseOf(kBranchUltWeaponTypes[s.id]!.first);
        final it = ItemInstance(uid: 'u', baseId: base, rarity: Rarity.raro, ultId: s.id);
        // Sin elegirla en el menú, manda la del tipo de arma.
        final plain = start(e, it);
        expect(ultimateOf(plain.party.first)!.id, isNot(s.id), reason: s.id);
        final st = start(e, it, ultSel: s.id);
        expect(ultimateOf(st.party.first)!.id, s.id, reason: s.id);
        final r = e.command(st, 'p1', const UltimateCommand(targetId: 'e0'));
        expect(r, isNotNull, reason: s.id);
        expect(r!.state.party.first.ult, lessThan(100), reason: s.id);
      }
    });

    test('sin mod, la ULT del tipo de arma', () {
      final e = BattleEngine(stats: _stats, random: () => 0.5, breakEnabled: false, familiesEnabled: false);
      final st = start(e, const ItemInstance(uid: 'u', baseId: 'espada_bronce'));
      expect(ultimateOf(st.party.first)!.id, 'ult_espada');
    });
  });
}
