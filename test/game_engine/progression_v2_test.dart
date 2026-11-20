import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_mechanics.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_tree.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/balance_migration.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Progresión v2 (docs/specs/progression_v2.md).

PlayerProfile _fresh(String cls, int level) {
  final p = zoneProgression.normalize(PlayerProfile(
      name: 'Ana', classId: cls, level: level, inventory: const []));
  return zoneProgression.resetBuild(p);
}

void main() {
  group('atributos', () {
    test('1 punto por nivel, cada uno suma +3', () {
      final p = _fresh('guerrero', 5);
      expect(p.points, 4);
      final fue = p.attributes[Attribute.fue];
      final q = zoneProgression.allocate(p, {Attribute.fue: 2})!;
      expect(q.attributes[Attribute.fue], fue + 6);
      expect(q.points, 2);
      expect(zoneProgression.allocate(p, {Attribute.fue: 5}), isNull);
      // Un perfil que no está en múltiplos de 3 se reinicia.
      final bad = zoneProgression.normalize(q.copyWith(
          attributes: q.attributes.add({Attribute.vit: 1}), points: 1));
      expect(bad.points, 4);
      expect(bad.attributes[Attribute.fue], fue);
      // Al 50: 49 puntos = +147, igual que antes.
      expect(_fresh('maga', 50).points * kAttrPerPoint, 147);
    });

    test('topes blandos: pasado el tope cada +1 rinde +0.5', () {
      expect(effectiveAttr(Attribute.fue, 60), 60);
      expect(effectiveAttr(Attribute.fue, 70), 65);
      expect(effectiveAttr(Attribute.agi, 40), 40);
      expect(effectiveAttr(Attribute.agi, 44), 42);
      expect(effectiveAttr(Attribute.des, 60), 60);
      expect(effectiveAttr(Attribute.vit, 61), 60.5);
    });

    test('sin pasar el tope los stats son los de antes; volcado rinde menos',
        () {
      final p = _fresh('guerrero', 50);
      // VIT hasta 60 justo: vida = 20 + 60 × 4 + nivel × 2.
      final toCap = (60 - p.attributes[Attribute.vit]) ~/ 3;
      final atCap = zoneProgression.allocate(p, {Attribute.vit: toCap})!;
      expect(atCap.attributes[Attribute.vit], lessThanOrEqualTo(60));
      String hpBase(PlayerProfile x) =>
          zoneProgression.derivedStats(x).breakdown['HP']!.steps.first;
      final hp = hpBase(atCap);
      expect(hp, 'base ${20 + atCap.attributes[Attribute.vit] * 4 + 100}');
      // Todo a VIT: pasado 60 cada punto (+3) da +1.5 VIT efectivo = +6 vida.
      final all = zoneProgression.allocate(p, {Attribute.vit: 49})!;
      final raw = all.attributes[Attribute.vit];
      expect(hpBase(all),
          'base ${(20 + (60 + (raw - 60) * 0.5) * 4 + 100).round()}');
    });

    test('vista previa en puntos y con el tope', () {
      final p = _fresh('guerrero', 50);
      final a = zoneProgression.previewAllocation(p, {Attribute.vit: 1});
      final b = zoneProgression.derivedStats(p);
      expect(a.maxHp - b.maxHp, inInclusiveRange(12, 13), reason: '+3 VIT = +12 base, × árbol');
    });
  });

  group('árbol v7', () {
    final rules = PassiveTreeRules(kPassiveTree);

    test('fusión: menos nodos, con dobles, notables menores y sin sueltos',
        () {
      final t = kPassiveTree;
      expect(t.nodes.length, lessThan(kPassiveTreeV6.nodes.length));
      expect(t.nodes.values.where((n) => n.isDouble), isNotEmpty);
      expect(kTreeV7.promoted, hasLength(24));
      for (final id in kTreeV7.promoted) {
        expect(t.nodes[id]!.kind, 'n', reason: id);
        expect(t.nodes[id]!.isMinor, isTrue, reason: id);
      }
      // Ningún id fusionado sigue existiendo y todos apuntan a uno vivo.
      kTreeV7Merged.forEach((gone, keep) {
        expect(t.nodes.containsKey(gone), isFalse, reason: gone);
        expect(t.nodes.containsKey(keep), isTrue, reason: keep);
      });
      // Enlaces simétricos y todo conectado.
      for (final n in t.nodes.values) {
        for (final l in n.links) {
          expect(t.nodes[l]!.links, contains(n.id), reason: '${n.id}-$l');
        }
      }
      for (final m in [for (final n in t.nodes.values) ...n.mechanicIds]) {
        expect(kMechanics[m], isNotNull, reason: m);
      }
    });

    test('todo el árbol: mismos stats que el v6 salvo el × 2 de los menores',
        () {
      TreeMods all(PassiveTreeCatalog c) {
        final r = PassiveTreeRules(c);
        final ids = [
          for (final n in c.nodes.values)
            if (n.kind != 'st' && c.exclusions[n.id] == null) n.id
        ];
        return r.aggregate('guerrero', PlayerPassiveProgress(ids));
      }

      final v6 = all(kPassiveTreeV6), v7 = all(kPassiveTree);
      for (final k in ['hp', 'mp', 'atk', 'mag', 'crit', 'spd', 'def', 'ult',
        'heal', 'burn', 'poi', 'frz']) {
        var extra = 0.0;
        for (final id in kTreeV7.promoted) {
          extra += (kPassiveTreeV6.nodes[id]!.effects[k] ?? 0).toDouble();
        }
        expect(v7[k], closeTo(v6[k] + extra, 1e-9), reason: k);
      }
      expect(v7.keys, v6.keys);
      expect(v7.mechanics.containsAll(v6.mechanics), isTrue);
    });

    test('keystones cercanas: 7 puntos; hito 20 a 8 / 13', () {
      for (final c in kPassiveTree.startNodeByClass.keys) {
        final o10 = rules.milestoneOptions(c, 10);
        final o20 = rules.milestoneOptions(c, 20);
        expect(o10, hasLength(3), reason: c);
        expect(o20, hasLength(3), reason: c);
        expect(o10.toSet().intersection(o20.toSet()), isEmpty);
        for (final k in o10) {
          expect(rules.pathTo(c, PlayerPassiveProgress.empty, k)!.length, 7);
        }
      }
    });

    test('puntos: 1 por nivel y Maestría, 2 por Prueba, hitos 7 y 10', () {
      expect(PassiveTreeRules.pointsEarned(1), 0);
      expect(PassiveTreeRules.pointsEarned(50), 49);
      expect(PassiveTreeRules.pointsEarned(70, trials: 3, ms10: true,
          ms20: true), 92);
    });

    test('camino en un clic: toma en orden hasta donde alcance', () {
      final p = _fresh('guerrero', 5);
      final k = rules.milestoneOptions('guerrero', 10).first;
      final path = rules.pathTo('guerrero', p.passiveProgress, k)!;
      final (q, n) = zoneProgression.takeNodes(p, path)!;
      expect(n, 4);
      expect(q.tree, path.take(4));
      expect(zoneProgression.takeNodes(q, path.skip(4).toList()), isNull);
    });
  });

  group('hitos', () {
    final rules = PassiveTreeRules(kPassiveTree);

    test('elegir en el 10 toma el camino con los 7 puntos del hito', () {
      final p = _fresh('maga', 10);
      expect(p.pendingMilestones, [10]);
      expect(p.treePoints, 9);
      final k = rules.milestoneOptions('maga', 10)[1];
      final q = zoneProgression.chooseMilestone(p, 10, k)!;
      expect(q.milestone10, k);
      expect(q.tree.last, k);
      expect(q.tree, hasLength(7));
      expect(q.treePoints - q.tree.length, 9, reason: 'los libres intactos');
      expect(q.pendingMilestones, isEmpty);
      // No se puede elegir dos veces ni una que no es opción.
      expect(zoneProgression.chooseMilestone(q, 10, k), isNull);
      expect(
          zoneProgression.chooseMilestone(
              p, 10, rules.milestoneOptions('maga', 20).first),
          isNull);
      // Antes del nivel 10, no.
      expect(zoneProgression.chooseMilestone(_fresh('maga', 9), 10, k), isNull);
    });

    test('una keystone tomada a mano no se vuelve a ofrecer en el hito', () {
      // Maga 9 con 7 puntos libres: toma a mano la primera opción del 10.
      var p = _fresh('maga', 9);
      final o10 = rules.milestoneOptions('maga', 10);
      final o20 = rules.milestoneOptions('maga', 20);
      final k = o10.first;
      final path = rules.pathTo('maga', p.passiveProgress, k)!;
      // Tomada antes del nivel 10 (con un hito pendiente ya no se puede,
      // § 11.4).
      p = zoneProgression.takeNodes(p, path)!.$1;
      p = zoneProgression.normalize(p.copyWith(level: 20));
      expect(p.tree, contains(k));
      expect(p.pendingMilestones, [10, 20]);
      final manual = PassiveTreeRules.milestoneTaken(
          p.tree, p.milestone10, p.milestone20);
      final n10 = rules.milestoneOptions('maga', 10, taken: manual);
      final n20 = rules.milestoneOptions('maga', 20, taken: manual);
      expect(n10, isNot(contains(k)));
      expect(n10, hasLength(3));
      // La que falta la reemplaza la siguiente de la clase (la 4.ª).
      expect(n10, [...o10.skip(1), o20.first]);
      expect(n20, hasLength(3));
      expect(n10.toSet().intersection(n20.toSet()), isEmpty);
      expect(n20, isNot(contains(k)));
      // El host la rechaza aunque llegue por red.
      expect(zoneProgression.chooseMilestone(p, 10, k), isNull);
      // Sanear no invalida una elección válida hecha después.
      final q = zoneProgression.chooseMilestone(p, 10, n10.first)!;
      expect(zoneProgression.normalize(q).milestone10, n10.first);
    });

    test('el hito paga solo los nodos que faltan del camino', () {
      var p = _fresh('maga', 9);
      final k = rules.milestoneOptions('maga', 10)[1];
      final path = rules.pathTo('maga', p.passiveProgress, k)!;
      // Ya tiene los 3 primeros nodos del camino con puntos libres
      // (tomados antes del hito: con el hito pendiente no se puede).
      p = zoneProgression.takeNodes(p, path.take(3).toList())!.$1;
      p = zoneProgression.normalize(p.copyWith(level: 12));
      expect(zoneProgression.takeNodes(p, path.skip(3).toList()), isNull);
      final freeBefore = p.treePoints - p.tree.length;
      final q = zoneProgression.chooseMilestone(p, 10, k)!;
      expect(q.tree, [...path.take(3), ...path.skip(3)]);
      expect(q.tree.last, k);
      // 7 de hito, 4 gastados: sobran 3 libres más (no se pierden).
      expect(q.treePoints - q.tree.length, freeBefore + 3);
    });

    test('reiniciar el árbol deja los hitos pendientes, sin duplicar puntos',
        () {
      var p = _fresh('paladin', 20);
      final a10 = rules.milestoneOptions('paladin', 10);
      final a20 = rules.milestoneOptions('paladin', 20);
      p = zoneProgression.chooseMilestone(p, 10, a10[0])!;
      p = zoneProgression.chooseMilestone(p, 20, a20[0])!;
      final earned = p.treePoints;
      expect(earned, 19 + 17);
      var r = zoneProgression.resetTree(p);
      expect(r.pendingMilestones, [10, 20]);
      expect(r.tree, isEmpty);
      r = zoneProgression.resetTree(r);
      expect(r.treePoints, 19, reason: 'sin elegir, solo los libres');
      r = zoneProgression.chooseMilestone(r, 10, a10[2])!;
      r = zoneProgression.chooseMilestone(r, 20, a20[1])!;
      expect(r.treePoints, earned);
      expect(r.milestone10, a10[2]);
      // Viaja en el JSON y sobrevive a normalize.
      final back = zoneProgression
          .normalize(PlayerProfile.fromJson(r.toJson()));
      expect(back.milestone10, a10[2]);
      expect(back.milestone20, a20[1]);
      expect(back.tree, r.tree);
    });

    test('acciones nuevas por red', () {
      for (final a in [
        const TakeNodesAction(['a', 'b']),
        const ChooseMilestoneAction(10, 'x_k'),
      ]) {
        final back = ActionJson.fromJson(ActionJson.toJson(a));
        expect(back.runtimeType, a.runtimeType);
      }
    });
  });

  group('migración (bv 2 → 3, tv 5 → 6)', () {
    Map<String, Object?> oldChar() => {
          'name': 'Vieja',
          'cls': 'guerrero',
          'lvl': 12,
          'st': {'VIT': 20, 'ESP': 4, 'AGI': 9, 'FUE': 30, 'DES': 9},
          'pts': 0,
          'tree': ['gue_r1', 'gue_f3'],
          'tv': 5,
        };

    test('devuelve todo y migrar dos veces no cambia nada', () {
      final acc = Account.fromJson({
        'bv': 2,
        'chars': [
          {'id': 'c1', 'p': oldChar()},
        ],
      });
      final (a, notice) = migrateAccountBalance(acc, fromBv: 2);
      expect(notice, contains('La progresión cambió'));
      final p = zoneProgression.normalize(a.characters.single.profile);
      expect(p.tree, isEmpty);
      expect(p.points, 11);
      expect(p.attributes.values, kClasses['guerrero']!.baseAttributes);
      final (b, again) = migrateAccountBalance(a, fromBv: 2);
      expect(again, isNull);
      expect(b.characters.single.profile.toJson(),
          a.characters.single.profile.toJson());
      final (c, none) = migrateAccountBalance(a, fromBv: kBalanceVersion);
      expect(none, isNull);
      expect(c.characters.single.profile.toJson(),
          a.characters.single.profile.toJson());
    });
  });
}
