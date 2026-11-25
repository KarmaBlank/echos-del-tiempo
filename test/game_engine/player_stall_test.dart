import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/stall_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Tienda del jugador, fase 2 (player_shop.md).

const _fish = 'fish:carpa_musgo';
final _crop = 'crop:${cropKey('nabo_claro', CropQuality.raro)}';

PlayerProfile _ana({int credits = 0}) {
  final p = newProfile('Ana', 'guerrero');
  return p.copyWith(
      credits: credits,
      life: p.life.copyWith(
          bag: {'carpa_musgo': 10},
          farm: p.life.farm.copyWith(
              crops: {cropKey('nabo_claro', CropQuality.raro): 4})));
}

(SessionEngine, GameSession) _room({PlayerProfile? a, PlayerProfile? b}) {
  final e = sessionEngine();
  var s = e.create();
  s = e.addPlayer(s, 'p0', a ?? _ana())!.state;
  s = e.addPlayer(s, 'p1', b ?? newProfile('Beto', 'mago'))!.state;
  return (e, s);
}

double Function() _seq(List<double> xs) {
  var i = 0;
  return () => xs[i++ % xs.length];
}

void main() {
  test('precio de referencia: pez, cosecha por calidad, basura no', () {
    expect(StallRules.refPrice(_fish), kFish['carpa_musgo']!.price);
    expect(StallRules.refPrice(_crop), greaterThan(0));
    final junk =
        kFish.values.firstWhere((f) => f.biome == kWaterJunkBiome).id;
    expect(StallRules.refPrice('fish:$junk'), 0);
    expect(StallRules.refPrice('seed:nabo_claro'), 0);
    expect(StallRules.maxPrice(_fish),
        (StallRules.refPrice(_fish) * kTuning[TuningId.town]!.d('stallMaxMarkup'))
            .round());
  });

  test('poner saca de la bolsa; repetir suma y cambia precio; retirar devuelve',
      () {
    var p = StallRules.list(_ana(), _fish, 4, 10)!;
    expect(p.life.count('carpa_musgo'), 6);
    expect(p.life.stall.listing(_fish), const StallListing(_fish, 4, 10));
    p = StallRules.list(p, _fish, 2, 12)!;
    expect(p.life.stall.listing(_fish), const StallListing(_fish, 6, 12));
    p = StallRules.list(p, _fish, 0, 9)!; // solo precio
    expect(p.life.stall.listing(_fish)!.price, 9);
    p = StallRules.unlist(p, _fish)!;
    expect(p.life.count('carpa_musgo'), 10);
    expect(p.life.stall.listings, isEmpty);
  });

  test('rechaza precio fuera de rango, cantidad sin stock y lugares llenos', () {
    final a = _ana();
    expect(StallRules.listBlock(a, _fish, 1, 0), StallBlock.price);
    expect(StallRules.listBlock(a, _fish, 1, StallRules.maxPrice(_fish) + 1),
        StallBlock.price);
    expect(StallRules.listBlock(a, _fish, 11, 5), StallBlock.missing);
    expect(StallRules.listBlock(a, _fish, 0, 5), StallBlock.amount);
    // Llenar los lugares con cosechas distintas.
    var p = a.copyWith(
        life: a.life.copyWith(
            farm: a.life.farm.copyWith(crops: {
      for (final q in CropQuality.values)
        for (final c in ['nabo_claro', 'trigo_dorado'])
          cropKey(c, q): 1,
    })));
    var n = 0;
    for (final k in p.life.farm.crops.keys) {
      if (n == StallRules.slots) break;
      p = StallRules.list(p, 'crop:$k', 1, 1)!;
      n++;
    }
    expect(StallRules.listBlock(p, _fish, 1, 5), StallBlock.full);
  });

  test('los vecinos compran según el precio y un día se atiende una vez', () {
    var p = StallRules.list(_ana(), _fish, 10, StallRules.refPrice(_fish))!;
    // Azar 0: elige la primera y siempre compra 1 + 0 unidades.
    final (q, sales) = StallRules.visitDay(p, 5, _seq([0.0]));
    final visitors = kTuning[TuningId.town]!.i('stallVisitors');
    expect(sales.length, visitors);
    expect(q.life.stall.listing(_fish)!.qty, 10 - visitors);
    expect(q.credits, p.credits + visitors * StallRules.refPrice(_fish));
    expect(q.life.stall.earned, visitors * StallRules.refPrice(_fish));
    expect(q.life.stall.log.every((s) => s.byVisitor && s.day == 5), isTrue);
    expect(q.life.stall.day, 5);
    // Mismo día: nada.
    final (q2, again) = StallRules.visitDay(q, 5, _seq([0.0]));
    expect(again, isEmpty);
    expect(identical(q2, q), isTrue);
  });

  test('más caro = menos chance (tope y elasticidad de Balance)', () {
    const cheap = StallListing(_fish, 1, 1);
    final pricey = StallListing(_fish, 1, StallRules.maxPrice(_fish));
    final ref = StallListing(_fish, 1, StallRules.refPrice(_fish));
    const s = Season.spring;
    expect(StallRules.chance(cheap, s),
        kTuning[TuningId.town]!.d('stallMaxChance'));
    expect(StallRules.chance(ref, s),
        closeTo(kTuning[TuningId.town]!.d('stallBaseChance'), 1e-9));
    expect(StallRules.chance(pricey, s), lessThan(StallRules.chance(ref, s)));
  });

  test('JSON del puesto: ida y vuelta, y lo inválido se descarta', () {
    final st = PlayerStall(
        listings: const [StallListing(_fish, 3, 7)],
        log: const [StallSale(2, _fish, 1, 7, ''), StallSale(3, _fish, 2, 14, 'Beto')],
        earned: 21,
        day: 3);
    final life = LifeSkills.fromJson(
        LifeSkills.initial.copyWith(stall: st).toJson());
    expect(life.stall, st);
    final bad = PlayerStall.fromJson({
      'l': [
        [_fish, 0, 5],
        ['x', 1],
        [_fish, 2, 4]
      ],
      'g': 'no',
    });
    expect(bad.listings, const [StallListing(_fish, 2, 4)]);
    expect(bad.log, isEmpty);
    expect(LifeSkills.initial.toJson().containsKey('ps'), isFalse);
  });

  test('acción stall: ida y vuelta por JSON', () {
    const a = StallAction(StallOp.buy, _fish, qty: 2, price: 9, owner: 'p0');
    final b = ActionJson.fromJson(ActionJson.toJson(a)) as StallAction;
    expect((b.op, b.cell, b.qty, b.price, b.owner),
        (a.op, a.cell, a.qty, a.price, a.owner));
  });

  test('en la sala: poner, comprar un compañero (anfitrión valida)', () {
    final (e, s0) = _room(b: newProfile('Beto', 'mago').copyWith(credits: 100));
    var s = act(e, s0, 'p0', const StallAction(StallOp.list, _fish, qty: 5, price: 8));
    expect(s.players['p0']!.profile.life.stall.listing(_fish)!.qty, 5);
    // Rechazos: propio, más de lo publicado, dueño inexistente.
    for (final (who, a) in [
      ('p0', const StallAction(StallOp.buy, _fish, qty: 1, owner: 'p0')),
      ('p1', const StallAction(StallOp.buy, _fish, qty: 6, owner: 'p0')),
      ('p1', const StallAction(StallOp.buy, _fish, qty: 1, owner: 'nadie')),
    ]) {
      expect(e.apply(s, who, a), isNull, reason: '$who ${a.qty} ${a.owner}');
    }
    s = act(e, s, 'p1', const StallAction(StallOp.buy, _fish, qty: 3, owner: 'p0'));
    final ana = s.players['p0']!.profile, beto = s.players['p1']!.profile;
    expect(beto.credits, 100 - 24);
    expect(beto.life.count('carpa_musgo'), 3);
    expect(ana.credits, 24);
    expect(ana.life.stall.listing(_fish)!.qty, 2);
    expect(ana.life.stall.log.single.buyer, 'Beto');
    // Sin oro suficiente.
    expect(
        e.apply(s, 'p1',
            const StallAction(StallOp.buy, _fish, qty: 2, owner: 'p0')),
        isNotNull); // 16 ≤ 76
    final poor = s.players['p1']!.profile.copyWith(credits: 1);
    s.players['p1']!.profile = poor;
    expect(
        e.apply(s, 'p1',
            const StallAction(StallOp.buy, _fish, qty: 1, owner: 'p0')),
        isNull);
  });

  test('fuera del pueblo no se puede usar el puesto', () {
    final e = sessionEngine();
    final s = inField(e, 'm1', profiles: [_ana(), newProfile('Beto', 'mago')]);
    expect(
        e.apply(s, 'p0', const StallAction(StallOp.list, _fish, qty: 1, price: 5)),
        isNull);
  });
}
