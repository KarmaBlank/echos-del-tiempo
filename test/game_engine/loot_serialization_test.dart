import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

Json _wire(Json j) => asJson(jsonDecode(jsonEncode(j)));

const _epic = ItemInstance(
  uid: 'i7',
  baseId: 'espada_templada',
  rarity: Rarity.epico,
  itemLevel: 22,
  name: 'Eco Voraz',
  affixes: [AffixRoll('feroz', 3, 20), AffixRoll('del_oso', 4, 6)],
  passiveId: 'impetu',
  passiveLevel: 2,
  forge: WeaponUpgradeLevels(pow: 2, crit: 1),
  extraSkills: ['sismo'],
);

void main() {
  group('migración del perfil', () {
    Map<String, Object?> v1({int? tv}) => {
          'name': 'Bo',
          'cls': 'maga',
          'lvl': 3,
          'st': {'VIT': 6, 'ESP': 14, 'AGI': 7, 'FUE': 4, 'DES': 6},
          'pts': 5,
          'inv': ['baculo_aprendiz', 'baculo_fuego', 'baculo_fuego'],
          'eq': 'baculo_fuego',
          'up': {
            'baculo_fuego': {'pow': 4, 'crit': 2},
          },
          'fuse': {'baculo_fuego': 'cura'},
          'tree': ['brasa_1'],
          if (tv != null) 'tv': tv,
        };

    for (final tv in [null, 2]) {
      test('v${tv ?? 1} → v3: cada id es un arma Común con su forja y fusión',
          () {
        final raw = PlayerProfile.fromJson(v1(tv: tv));
        final p = progression.normalize(raw);
        expect(p.items.map((i) => i.uid),
            ['baculo_aprendiz', 'baculo_fuego', 'baculo_fuego#2']);
        expect(p.items.every((i) => i.rarity == Rarity.comun), isTrue);
        final f = p.itemByUid('baculo_fuego')!;
        expect(f.forge.pow, 4, reason: 'la forja vieja se conserva');
        expect(f.forge.crit, 2);
        expect(f.extraSkills, ['cura']);
        expect(p.itemByUid('baculo_fuego#2')!.forge.total, 0);
        expect(p.equippedUid, 'baculo_fuego');
        expect(p.equipped, 'baculo_fuego');
        // Vistas viejas.
        expect(p.inventory, ['baculo_aprendiz', 'baculo_fuego']);
        expect(p.upgradesFor('baculo_fuego').pow, 4);
        expect(p.fused, {'baculo_fuego': 'cura'});
        // Árbol: v1 se reinicia; de la v2 solo quedan anillo e inicios
        // (passive_tree_v3.md § 11), así que brasa_1 también vuelve.
        expect(raw.treeRefunded, 1);
        // Más allá del tope de Común no se sigue forjando.
        expect(progression.upgrade(p.copyWith(credits: 9999), 'baculo_fuego',
            UpgradeStat.spd), isNull);
        // Se guarda en v3 y vuelve igual.
        final j = p.toJson();
        expect(j['pv'], 4);
        expect(j.containsKey('inv'), isFalse);
        final back = progression.normalize(PlayerProfile.fromJson(
            asJson(jsonDecode(jsonEncode(j)))));
        expect(back.toJson(), j);
      });
    }

    test('v3: ida y vuelta con todo', () {
      final p = progression.normalize(PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        level: 20,
        items: const [
          ItemInstance(uid: 'espada_bronce', baseId: 'espada_bronce'),
          _epic,
          ItemInstance(
            uid: 'i9',
            baseId: 'mandoble_eras',
            rarity: Rarity.legendario,
            itemLevel: 40,
            uniqueId: 'segadoraEras',
            passiveId: 'cosecha',
            affixes: [AffixRoll('feroz', 0, 40), AffixRoll('del_vampiro', 0, 4)],
          ),
        ],
        equipped: 'espada_bronce',
        materials: const {CraftMaterial.prisma: 2},
        grid: const [null, 'i7'],
        lootFilter: 'Ocultar\n  Rareza Común\n',
        itemSeq: 9,
      ));
      expect(p.items, hasLength(3));
      final text = jsonEncode(p.toJson());
      final back = progression
          .normalize(PlayerProfile.fromJson(asJson(jsonDecode(text))));
      expect(back.toJson(), p.toJson());
      expect(back.itemByUid('i7'), _epic);
      expect(back.grid[1], 'i7');
    });

    test('lo inválido se corrige', () {
      final p = progression.normalize(PlayerProfile.fromJson({
        'cls': 'guerrero',
        'items': [
          {'u': 'a', 'b': 'nada'},
          {'u': 'b', 'b': 'espada_ignea', 'r': 'comun', 'a': [['feroz', 5, 7]]},
          {'u': 'c', 'b': 'espada_ignea', 'r': 'magico',
           'a': [['feroz', 5, 99], ['gelido', 2, 1], ['xx', 1, 1]],
           'p': 'impetu'},
          {'u': 'c', 'b': 'espada_bronce', 'r': 'legendario', 'q': 'otro'},
          'basura',
        ],
        'eq': 'zzz',
        'mats': {'esquirla': 500, 'nada': 3},
      }));
      expect(p.items.map((i) => i.uid), ['b', 'c', 'c#2']);
      expect(p.itemByUid('b')!.affixes, isEmpty, reason: 'Común: 0 mods');
      final c = p.itemByUid('c')!;
      expect(c.affixes, [const AffixRoll('feroz', 5, 9)],
          reason: 'valor recortado; Congelación no sale en espadas');
      expect(c.passiveId, isNull, reason: 'Mágico sin pasiva');
      expect(p.itemByUid('c#2')!.rarity, Rarity.epico,
          reason: 'legendario sin único válido');
      expect(p.equippedUid, 'c#2', reason: 'la inicial (Bronce)');
      expect(p.material(CraftMaterial.esquirla), 99);
    });
  });

  group('red', () {
    test('sesión con piso, zona y arma en el build', () {
      final e = sessionEngine();
      var s = inField(e, 'm2', profiles: [
        progression.normalize(PlayerProfile(
            name: 'A', classId: 'guerrero', items: const [_epic])),
      ]);
      s.ground
        ..add(const GroundLoot(
            id: 1,
            drop: LootDrop.item(_epic),
            x: 10,
            y: 20,
            ownerId: 'p0'))
        ..add(const GroundLoot(
            id: 2, drop: LootDrop.stack(StackKind.cristal, 3), x: 1, y: 2));
      s.groundSeq = 2;
      s.mission!.eliteDrops
          .add(const WeaponDrop('p0', 'espada_templada', rarity: Rarity.epico));
      const sj = SessionJson();
      final j = _wire(sj.toJson(s));
      final back = sj.fromJson(j);
      expect(sj.toJson(back), j);
      expect(back.ground.first.drop.item, _epic);
      expect(back.ground.last.ownerId, isNull);
      expect(back.groundFor('p1').single.id, 2);
      expect(back.mission!.zoneLevel, 5);
      expect(back.mission!.eliteDrops.single.rarity, Rarity.epico);

      // Combatiente: build con la instancia y afijos de combate.
      final b = progression.buildOf(back.players['p0']!.profile);
      final c = e.battles
          .start(party: [e.partyMember(back.players['p0']!)], enemyTypes: ['slime'])
          .state
          .party
          .single
        ..lifeSteal = 0.03
        ..statusResist = 1;
      final cj = _wire(sj.combatantToJson(c));
      final c2 = sj.combatantFromJson(cj);
      expect(sj.combatantToJson(c2), cj);
      expect(c2.build!.item, b.item);
      expect(c2.lifeSteal, 0.03);
    });

    test('acciones nuevas', () {
      const actions = <SessionAction>[
        CraftAction(CraftOp.transferSkill, 'a', sourceUid: 'b', skillId: 'giro'),
        CraftAction(CraftOp.transferAffix, 'a', sourceUid: 'b', index: 2),
        CraftAction(CraftOp.reroll, 'a'),
        GiveItemAction('p1', 'mat:esquirla', count: 3),
        GiveItemAction('p1', 'i4'),
        DropItemAction('pot', count: 2),
        PickUpAction(7),
        MoveInventoryAction(0, 39),
        SetLootFilterAction('Mostrar\n  Rareza Raro\n'),
        SetLootFilterAction(null),
      ];
      for (final a in actions) {
        final j = _wire(ActionJson.toJson(a));
        expect(ActionJson.toJson(ActionJson.fromJson(j)), j);
      }
      expect(() => ActionJson.fromJson({'t': 'craft', 'op': 'nada', 'w': 'a'}),
          throwsFormatException);
    });

    test('eventos nuevos', () {
      const ev = EventJson();
      final events = <SessionEvent>[
        const LootDropEvent('p0', LootDrop.item(_epic), LootSource.boss, uid: 'i7'),
        const LootDropEvent('p0', LootDrop.stack(StackKind.prisma, 1),
            LootSource.chest, groundId: 4),
        const LootPickedEvent('p1', 4, LootDrop.stack(StackKind.potion, 1)),
        const ItemGivenEvent('p0', 'p1', LootDrop.item(_epic)),
        const CraftedEvent('p0', CraftOp.upgradeRarity, 'i7'),
      ];
      for (final e in events) {
        final j = _wire(ev.toJson(e));
        expect(ev.toJson(ev.fromJson(j)), j);
      }
    });
  });
}
