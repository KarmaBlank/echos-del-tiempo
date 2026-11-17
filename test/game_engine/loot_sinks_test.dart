import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Sumideros de loot: desarmar, vender, reforjar (loot.md § 21).

final _craft = progression.crafting;

/// Guerrero con la inicial equipada, otra inicial, Comunes, un Mágico, un
/// Raro, un Épico, un escudo forjado y un Legendario.
PlayerProfile _p({
  int credits = 10000,
  Map<CraftMaterial, int> mats = const {
    CraftMaterial.cristal: 2,
    CraftMaterial.prisma: 2,
  },
}) =>
    progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: credits,
      materials: mats,
      items: const [
        ItemInstance(uid: 'espada_bronce', baseId: 'espada_bronce'),
        ItemInstance(uid: 'c4', baseId: 'espada_bronce'),
        ItemInstance(uid: 'c2', baseId: 'baculo_fuego', itemLevel: 2),
        ItemInstance(
            uid: 'c3',
            baseId: 'arco_corto',
            itemLevel: 30,
            forge: WeaponUpgradeLevels(pow: 2)),
        ItemInstance(
          uid: 'm1',
          baseId: 'hacha_rompe',
          rarity: Rarity.magico,
          itemLevel: 10,
          affixes: [AffixRoll('certero', 5, 3), AffixRoll('del_toro', 5, 4)],
        ),
        ItemInstance(
          uid: 'e1',
          baseId: 'arco_corto',
          rarity: Rarity.epico,
          itemLevel: 20,
          name: 'Alba Silente',
          passiveId: 'impetu',
          affixes: [
            AffixRoll('feroz', 5, 7),
            AffixRoll('ponzonoso', 2, 1),
            AffixRoll('del_oso', 5, 3),
          ],
        ),
        ItemInstance(
          uid: 'sh',
          baseId: 'maza_escudo_roble',
          rarity: Rarity.raro,
          itemLevel: 5,
          name: 'Muro Fiel',
          forge: WeaponUpgradeLevels(def: 1),
          affixes: [AffixRoll('del_baluarte', 5, 1)],
        ),
        ItemInstance(
          uid: 'l1',
          baseId: 'hacha_volcanica',
          rarity: Rarity.legendario,
          itemLevel: 6,
          uniqueId: 'fauceVolcan',
          passiveId: 'erupcionInterna',
          affixes: [AffixRoll('afilado', 0, 5), AffixRoll('abrasador', 0, 1)],
        ),
      ],
      equipped: 'espada_bronce',
    ));

Map<String, Object?> _wire(Map<String, Object?> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, Object?>;

void main() {
  group('desarmar', () {
    test('rendimiento por rareza, nivel de objeto y forja', () {
      Map<CraftMaterial, int> g(String uid) =>
          CraftRules.salvageYield(_p().itemByUid(uid)!).guaranteed;
      expect(g('c2'), {CraftMaterial.esquirla: 1});
      // Nivel 30 (+1) y forja 2 (+1).
      expect(g('c3'), {CraftMaterial.esquirla: 3});
      expect(g('m1'), {CraftMaterial.esquirla: 2});
      expect(g('e1'), {CraftMaterial.cristal: 2});
      expect(g('sh'), {CraftMaterial.cristal: 1, CraftMaterial.esquirla: 1});
      expect(g('l1'), {CraftMaterial.prisma: 1, CraftMaterial.cristal: 2});
      final e = CraftRules.salvageYield(_p().itemByUid('e1')!).chances.single;
      expect([e.material, e.chance], [CraftMaterial.prisma, 0.35]);
      expect(e.text, '35% de +1 Prisma Roto');
    });

    test('Común: determinística, vista previa = resultado', () {
      final p = _p();
      final pv = _craft.salvage(p, 'c3');
      expect(pv.ok, isTrue);
      expect(pv.chances, isEmpty);
      expect(pv.gainedMaterials, {CraftMaterial.esquirla: 3});
      expect(pv.consumed, ['c3']);
      final next = pv.profile!;
      expect(next.itemByUid('c3'), isNull);
      expect(next.material(CraftMaterial.esquirla), 3);
      expect(
          _craft.salvage(p, 'c3', random: rolls(const [0.0])).profile!.toJson(),
          next.toJson());
    });

    test('Mágico: lo seguro + lo que puede salir; el azar decide', () {
      final p = _p();
      final pv = _craft.salvage(p, 'm1');
      expect(pv.ok, isTrue);
      expect(pv.profile, isNull, reason: 'vista previa sin azar');
      expect(pv.gainedMaterials, {CraftMaterial.esquirla: 2});
      expect(pv.outcomes, ['25% de +1 Cristal de Era']);
      final yes = _craft.salvage(p, 'm1', random: rolls(const [0.1]));
      expect(yes.profile!.material(CraftMaterial.cristal), 3);
      expect(yes.gainedMaterials,
          {CraftMaterial.esquirla: 2, CraftMaterial.cristal: 1});
      final no = _craft.salvage(p, 'm1', random: rolls(const [0.9]));
      expect(no.profile!.material(CraftMaterial.cristal), 2);
      expect(no.profile!.material(CraftMaterial.esquirla), 2);
    });

    test('no la equipada ni la última inicial; tope de 99', () {
      final p = _p();
      expect(_craft.salvage(p, 'espada_bronce').error, 'Está equipada');
      expect(_craft.salvage(p, 'nada').error, 'No la tienes');
      // La última inicial con otra arma equipada.
      final q = p.copyWith(
          items: [for (final i in p.items) if (i.uid != 'c4') i],
          equipped: 'c2');
      expect(q.equippedUid, 'c2');
      expect(_craft.salvage(q, 'espada_bronce').error, 'Arma inicial');
      final full = _p(mats: const {CraftMaterial.esquirla: 98});
      final r = _craft.salvage(full, 'c3');
      expect(r.profile!.material(CraftMaterial.esquirla), 99);
      expect(r.gainedMaterials, {CraftMaterial.esquirla: 1});
      expect(r.lost, ['2 Esquirla del Eco (tope 99)']);
    });

    test('lote: todos los Comunes no equipados (queda una inicial)', () {
      final p = _p();
      expect([for (final i in _craft.batchTargets(p, Rarity.comun)) i.uid],
          ['c4', 'c2', 'c3']);
      final r = _craft.salvageAll(p, Rarity.comun);
      expect(r.ok, isTrue);
      expect(r.consumed, ['c4', 'c2', 'c3']);
      expect(r.gainedMaterials, {CraftMaterial.esquirla: 5});
      final next = r.profile!;
      expect(next.items.where((i) => i.rarity == Rarity.comun).map((i) => i.uid),
          ['espada_bronce']);
      expect(next.material(CraftMaterial.esquirla), 5);
      expect(_craft.salvageAll(next, Rarity.comun).error,
          'No hay armas de rareza Común');
    });

    test('lote con tiradas: vista previa agrupa las chances', () {
      final p = _p().copyWith(items: [
        ..._p().items,
        const ItemInstance(
            uid: 'm2',
            baseId: 'katana_escarcha',
            rarity: Rarity.magico,
            itemLevel: 5,
            affixes: [AffixRoll('afilado', 5, 2)]),
      ]);
      final pv = _craft.salvageAll(p, Rarity.magico);
      expect(pv.profile, isNull);
      expect(pv.gainedMaterials, {CraftMaterial.esquirla: 4});
      expect(pv.outcomes, ['25% de +1 Cristal de Era (×2 armas)']);
      final r = _craft.salvageAll(p, Rarity.magico,
          random: rolls(const [0.1, 0.9]));
      expect(r.profile!.material(CraftMaterial.cristal), 3);
      expect(r.consumed, ['m1', 'm2']);
    });
  });

  group('vender', () {
    test('precio: valor del nivel × fracción + 25% de la forja', () {
      final p = _p();
      expect(CraftRules.itemValue(30), 6600);
      expect(_craft.sellPrice(p.itemByUid('c2')!), 22);
      // 6600 × 0.10 + (44 + 88) × 0.25.
      expect(_craft.sellPrice(p.itemByUid('c3')!), 693);
      expect(_craft.sellPrice(p.itemByUid('e1')!),
          (CraftRules.itemValue(20) * 0.40).round());
      expect(_craft.sellPrice(const ItemInstance(uid: 'x', baseId: 'espada_bronce')),
          10);
    });

    test('vista previa = resultado; motivos', () {
      final p = _p();
      final r = _craft.sell(p, 'c3');
      expect(r.gainedCredits, 693);
      expect(r.profile!.credits, 10693);
      expect(r.profile!.itemByUid('c3'), isNull);
      expect(_craft.sell(p, 'espada_bronce').error, 'Está equipada');
      final all = _craft.sellAll(p, Rarity.comun);
      expect(all.gainedCredits, 10 + 22 + 693);
      expect(all.profile!.credits, 10000 + 725);
      expect(_craft.sellAll(p, Rarity.legendario).consumed, ['l1']);
    });
  });

  group('reforjar base', () {
    test('conserva rareza, mods, pasiva y forja; pierde lo que no sale', () {
      final p = _p();
      final cost = CraftRules.reforgeCost(p.itemByUid('e1')!)!;
      expect(cost.$1, 1200);
      expect(cost.$2, {CraftMaterial.cristal: 1, CraftMaterial.prisma: 1});
      // Arco → espada: Ponzoñoso no sale en espada; Ímpetu sí.
      final r = _craft.reforge(p, 'e1', 'espada_carmesi');
      expect(r.ok, isTrue);
      expect(r.before!.baseId, 'arco_corto');
      final after = r.after!;
      expect(after.baseId, 'espada_carmesi');
      expect(after.rarity, Rarity.epico);
      expect(after.itemLevel, 20);
      expect(after.name, 'Alba Silente');
      expect(after.affixes.map((a) => a.affixId), ['feroz', 'del_oso']);
      expect(after.passiveId, 'impetu');
      expect(r.lost, ['Mod +1 stack de Veneno al aplicar (T2) (no sale en espada)']);
      final next = r.profile!;
      expect(next.itemByUid('e1'), after);
      expect(next.credits, 10000 - 1200);
      expect(next.material(CraftMaterial.prisma), 1);
      expect(next.material(CraftMaterial.cristal), 1);
      // Arco → báculo: también se pierde la pasiva.
      final b = _craft.reforge(p, 'e1', 'baculo_fuego');
      expect(b.after!.passiveId, isNull);
      expect(b.lost, contains('Pasiva Ímpetu (no sale en báculo)'));
      // Escudo → espada: se pierde la forja de Defensa.
      final s = _craft.reforge(p, 'sh', 'espada_ignea');
      expect(s.after!.forge.def, 0);
      expect(s.after!.affixes, isEmpty, reason: 'del Baluarte solo en escudos');
      expect(s.lost, contains('Forja de Defensa +1 (la base nueva no tiene escudo)'));
    });

    test('motivos', () {
      final p = _p();
      expect(_craft.reforge(p, 'espada_bronce', 'espada_ignea').error,
          'Está equipada');
      expect(_craft.reforge(p, 'l1', 'espada_ignea').error,
          'Un Legendario no cambia de base');
      expect(_craft.reforge(p, 'e1', 'arco_corto').error, 'Ya tiene esa base');
      expect(_craft.reforge(p, 'e1', 'nada').error, 'Elige una base');
      expect(_craft.reforge(p, 'e1', 'espada_runica').error,
          'Base de nivel 24 (el arma es de nivel 20)');
      expect(_craft.reforge(_p(mats: const {}), 'e1', 'espada_ignea').error,
          'Falta Cristal de Era');
      expect(_craft.reforge(_p(credits: 100), 'c2', 'espada_ignea').error,
          'Falta Esquirla del Eco');
      final bases = _craft.reforgeBases(p.itemByUid('c2')!);
      expect(bases.every((w) => w.level <= 2 && w.id != 'baculo_fuego'), isTrue);
      expect(bases.first.level, 2);
    });
  });

  group('acciones', () {
    test('apply y CraftAction: nuevas operaciones', () {
      final p = _p();
      expect(_craft.apply(p, CraftOp.reforge, 'e1').error, 'Elige una base');
      expect(
          _craft
              .apply(p, CraftOp.reforge, 'e1', sourceUid: 'espada_ignea')
              .after!
              .baseId,
          'espada_ignea');
      expect(_craft.apply(p, CraftOp.sellAll, '*', index: 9).error,
          'Elige una rareza');
      expect(_craft.apply(p, CraftOp.salvageAll, '*').consumed,
          ['c4', 'c2', 'c3']);
      expect(CraftOp.salvage.destroys && CraftOp.sellAll.isBatch, isTrue);
      expect(CraftOp.reforge.destroys, isFalse);
    });

    test('serialización ida y vuelta', () {
      final actions = <CraftAction>[
        const CraftAction(CraftOp.salvage, 'c2'),
        const CraftAction(CraftOp.sell, 'c3'),
        const CraftAction.reforge('e1', 'espada_ignea'),
        CraftAction.batch(CraftOp.salvageAll, Rarity.magico),
        CraftAction.batch(CraftOp.sellAll, Rarity.comun),
      ];
      for (final a in actions) {
        final j = _wire(ActionJson.toJson(a));
        final back = ActionJson.fromJson(j) as CraftAction;
        expect(ActionJson.toJson(back), j);
        expect([back.op, back.targetUid, back.sourceUid, back.index],
            [a.op, a.targetUid, a.sourceUid, a.index]);
      }
      expect(ActionJson.toJson(CraftAction.batch(CraftOp.sellAll, Rarity.raro)),
          {'t': 'craft', 'op': 'sellAll', 'w': '*', 'i': 2});
    });

    test('en la sesión: lobby sí (con el azar del host), campo no', () {
      final e = sessionEngine(fieldFallback: 0.1);
      final s = e.addPlayer(e.create(), 'p0', _p())!.state;
      final sold = e.apply(s, 'p0', const CraftAction(CraftOp.sell, 'c3'))!;
      expect(sold.state.players['p0']!.profile.credits, 10693);
      expect(sold.events.whereType<CraftedEvent>().single.op, CraftOp.sell);
      // 0.1 < 25%: el Mágico da Cristal.
      final sal = e.apply(s, 'p0', const CraftAction(CraftOp.salvage, 'm1'))!;
      expect(sal.state.players['p0']!.profile.material(CraftMaterial.cristal), 3);
      final batch = e.apply(
          s, 'p0', CraftAction.batch(CraftOp.salvageAll, Rarity.comun))!;
      expect(batch.state.players['p0']!.profile.material(CraftMaterial.esquirla),
          5);
      final rf = e.apply(
          s, 'p0', const CraftAction.reforge('e1', 'espada_carmesi'))!;
      expect(rf.state.players['p0']!.profile.itemByUid('e1')!.baseId,
          'espada_carmesi');
      expect(e.apply(s, 'p0', const CraftAction(CraftOp.sell, 'espada_bronce')),
          isNull);
      final f = inField(sessionEngine(), 'm1', profiles: [_p()]);
      expect(f.mode, SessionMode.field);
      expect(sessionEngine().apply(f, 'p0', const CraftAction(CraftOp.sell, 'c3')),
          isNull);
    });
  });
}
