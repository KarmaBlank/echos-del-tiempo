import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart'
    show RandomSource;
import 'package:echos_del_tiempo/game_engine/rules/eco_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ecos_session_test.dart' show endgamer, lobby, atPortal;
import 'session_test_helpers.dart';

/// Fusión de Ecos (docs/specs/ecos_atlas.md § 4.2).

EcoItem _eco(int tier, int zone, Rarity r, {List<EcoModRoll> mods = const []}) =>
    EcoItem(
        uid: 'x',
        tier: tier,
        zone: zone,
        boss: 1,
        rarity: r,
        mods: mods,
        floors: 1,
        seed: 1);

RandomSource _seq(int seed) {
  var x = seed;
  return () {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    return x / 0x80000000;
  };
}

const _rules = EcoRules();

void main() {
  group('reglas', () {
    test('cuenta por defecto 3 y costo extra 0', () {
      expect(EcoRules.fuseCount, 3);
      expect(EcoRules.fuseAnchors, 0);
    });

    test('mismo tier, distintos, propios y < 16', () {
      final p = endgamer('Ana', ecos: [
        _eco(4, 1, Rarity.comun),
        _eco(4, 2, Rarity.comun),
        _eco(4, 3, Rarity.comun),
        _eco(5, 3, Rarity.comun),
      ]);
      final u = [for (final e in p.ecos) e.uid];
      expect(EcoRules.cannotFuse(p, u.sublist(0, 3)), isNull);
      expect(EcoRules.cannotFuse(p, u.sublist(0, 2)), EcoFuseBlock.count);
      expect(EcoRules.cannotFuse(p, [u[0], u[0], u[1]]),
          EcoFuseBlock.duplicate);
      expect(EcoRules.cannotFuse(p, [u[0], u[1], 'nope']),
          EcoFuseBlock.missing);
      expect(EcoRules.cannotFuse(p, [u[0], u[1], u[3]]),
          EcoFuseBlock.mixedTier);
      final top = endgamer('Ana', ecos: [
        for (var i = 0; i < 3; i++) _eco(16, 1, Rarity.comun),
      ]);
      expect(
          EcoRules.cannotFuse(top, [for (final e in top.ecos) e.uid]),
          EcoFuseBlock.maxTier);
    });

    test('resultado: tier+1, rareza mayor, mods mínimos sin repetir, '
        'zona compartida', () {
      for (var seed = 1; seed < 30; seed++) {
        final p = endgamer('Ana', ecos: [
          _eco(7, 4, Rarity.magico, mods: const [EcoModRoll('vida', 30)]),
          _eco(7, 4, Rarity.epico),
          _eco(7, 4, Rarity.comun),
        ]);
        final r = _rules.fuse(p, [for (final e in p.ecos) e.uid], _seq(seed));
        expect(r.ok, isTrue);
        final e = r.after!;
        expect(r.profile!.ecos, [e]);
        expect(e.tier, 8);
        expect(e.zone, 4);
        expect(e.rarity, Rarity.epico);
        expect(e.mods.length, ecoModRangeMin(Rarity.epico));
        expect(e.mods.map((m) => m.id).toSet().length, e.mods.length);
        expect(e.name, isNotNull);
      }
    });

    test('zonas distintas: una de las 3 al azar (con semilla)', () {
      final seen = <int>{};
      for (var seed = 1; seed < 60; seed++) {
        final p = endgamer('Ana', ecos: [
          _eco(2, 1, Rarity.comun),
          _eco(2, 5, Rarity.comun),
          _eco(2, 9, Rarity.comun),
        ]);
        final u = [for (final e in p.ecos) e.uid];
        final a = _rules.fuse(p, u, _seq(seed)).after!;
        final b = _rules.fuse(p, u, _seq(seed)).after!;
        expect(a.zone, b.zone);
        expect([1, 5, 9], contains(a.zone));
        expect(a.mods, isEmpty);
        seen.add(a.zone);
      }
      expect(seen, {1, 5, 9});
      final pre = EcoRules.fusePreview([
        _eco(2, 1, Rarity.comun),
        _eco(2, 5, Rarity.raro),
        _eco(2, 1, Rarity.comun),
      ]);
      expect(pre.tier, 3);
      expect(pre.rarity, Rarity.raro);
      expect(pre.zones, [1, 5]);
    });

    test('el resultado se craftea como cualquier Eco', () {
      var p = endgamer('Ana', ecos: [
        for (var i = 0; i < 3; i++) _eco(3, 2, Rarity.magico),
      ]).copyWith(materials: {
        CraftMaterial.ancla: 1,
        CraftMaterial.esquirla: 1,
        CraftMaterial.cristal: 1,
        CraftMaterial.prisma: 4,
      });
      final rng = _seq(3);
      final f = _rules.fuse(p, [for (final e in p.ecos) e.uid], rng);
      p = f.profile!;
      final uid = f.after!.uid;
      for (final op in [
        EcoCraftOp.tier,
        EcoCraftOp.reroll,
        EcoCraftOp.addMod,
        EcoCraftOp.rarity,
      ]) {
        final r = _rules.craft(p, uid, op, rng);
        expect(r.ok, isTrue, reason: '$op: ${r.error}');
        p = r.profile!;
      }
      final e = p.ecoByUid(uid)!;
      expect(e.tier, 5);
      expect(e.rarity, Rarity.raro);
    });
  });

  group('en la sala (host)', () {
    test('lobby: fusiona; la acción viaja por la red', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [
        endgamer('Ana', ecos: [
          for (var i = 0; i < 3; i++) _eco(6, 3, Rarity.raro),
        ]),
        endgamer('Beto', ecos: [_eco(6, 3, Rarity.raro)]),
      ]);
      final mine = [for (final x in s.players['p0']!.profile.ecos) x.uid];
      final theirs = s.players['p1']!.profile.ecos.single.uid;
      // Ajeno: no.
      expect(e.apply(s, 'p0', EcoFuseAction([mine[0], mine[1], theirs])),
          isNull);
      final a = ActionJson.fromJson(ActionJson.toJson(EcoFuseAction(mine)))
          as EcoFuseAction;
      expect(a.uids, mine);
      s = act(e, s, 'p0', a);
      final got = s.players['p0']!.profile.ecos.single;
      expect(got.tier, 7);
      expect(got.zone, 3);
      expect(mine, isNot(contains(got.uid)));
    });

    test('el Eco en votación no se fusiona', () {
      final e = sessionEngine(zones: true);
      var s = lobby(e, [
        endgamer('Ana', ecos: [
          for (var i = 0; i < 3; i++) _eco(2, 1, Rarity.comun),
        ]),
      ]);
      final u = [for (final x in s.players['p0']!.profile.ecos) x.uid];
      s = act(e, atPortal(s, 'p0', u.first), 'p0', ProposeEcoAction(u.first));
      expect(e.apply(s, 'p0', EcoFuseAction(u)), isNull);
    });
  });
}

int ecoModRangeMin(Rarity r) => switch (r) {
      Rarity.comun => 0,
      Rarity.magico => 1,
      Rarity.raro => 2,
      Rarity.epico => 3,
      _ => 4,
    };
