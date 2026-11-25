import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/life_give_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/oficio_storage_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Dar materiales de oficio a un compañero (share_materials.md).

final _crop = cropKey('nabo_claro', CropQuality.raro);

PlayerProfile _ana() {
  final p = newProfile('Ana', 'guerrero');
  return p.copyWith(
      life: p.life.copyWith(
          crafts: {'tabla': 7},
          bag: {'carpa_musgo': 3},
          ores: {'ingot_copper': 4},
          farm: p.life.farm.copyWith(crops: {_crop: 2})));
}

(SessionEngine, GameSession) _room({PlayerProfile? a, PlayerProfile? b}) {
  final e = sessionEngine();
  var s = e.create();
  s = e.addPlayer(s, 'p0', a ?? _ana())!.state;
  s = e.addPlayer(s, 'p1', b ?? newProfile('Beto', 'mago'))!.state;
  return (e, s);
}

void main() {
  test('el paso del medio del selector sale de Balance', () {
    expect(LifeGiveRules.step, kTuning[TuningId.town]!.i('giveStep'));
  });

  test('pasa cada tipo de pila y descuenta al que da', () {
    final (e, s0) = _room();
    var s = act(e, s0, 'p0', const GiveLifeAction('p1', 'craft:tabla', count: 5));
    expect(s.players['p0']!.profile.life.craft('tabla'), 2);
    expect(s.players['p1']!.profile.life.craft('tabla'), 5);
    s = act(e, s, 'p0', GiveLifeAction('p1', 'crop:$_crop', count: 2));
    expect(s.players['p0']!.profile.life.farm.crops.containsKey(_crop), isFalse);
    expect(s.players['p1']!.profile.life.farm.cropCount(_crop), 2);
    s = act(e, s, 'p0', const GiveLifeAction('p1', 'fish:carpa_musgo'));
    expect(s.players['p1']!.profile.life.count('carpa_musgo'), 1);
    s = act(e, s, 'p0', const GiveLifeAction('p1', 'ore:ingot_copper', count: 4));
    expect(s.players['p0']!.profile.life.ore('ingot_copper'), 0);
    expect(s.players['p1']!.profile.life.ore('ingot_copper'), 4);
  });

  test('rechaza cantidades, celdas y destinatarios inválidos', () {
    final (e, s) = _room();
    for (final a in [
      const GiveLifeAction('p1', 'craft:tabla', count: 8), // no alcanza
      const GiveLifeAction('p1', 'craft:tabla', count: 0),
      const GiveLifeAction('p1', 'craft:tabla', count: -3),
      const GiveLifeAction('p0', 'craft:tabla'), // a sí mismo
      const GiveLifeAction('nadie', 'craft:tabla'),
      const GiveLifeAction('p1', 'tool:cana_rama'), // herramientas no
      const GiveLifeAction('p1', 'fish:no_existe'),
      const GiveLifeAction('p1', 'craft'),
    ]) {
      expect(e.apply(s, 'p0', a), isNull, reason: '$a');
    }
  });

  test('fuera del pueblo (en una misión) no se puede', () {
    final e = sessionEngine();
    final s = inField(e, 'm1',
        profiles: [_ana(), newProfile('Beto', 'mago')]);
    expect(e.apply(s, 'p0', const GiveLifeAction('p1', 'craft:tabla')),
        isNull);
  });

  test('si la bolsa del otro está llena, una pila nueva no entra', () {
    const crops = ['nabo_claro', 'trigo_dorado', 'papa_piedra',
        'calabaza_sendero', 'frutilla_rocio', 'cebolla_cobre', 'flor_runica',
        'melon_engranaje', 'trigo_manana', 'rosa_reloj'];
    final b0 = newProfile('Beto', 'mago');
    final full = b0.copyWith(
        life: b0.life.copyWith(
            farm: b0.life.farm.copyWith(seeds: const {}, crops: {
      for (var i = 0; i < OficioStorageRules.cap; i++)
        cropKey(crops[i % 10], CropQuality.values[i ~/ 10]): 1,
    })));
    expect(OficioStorageRules.used(full, OficioBag.cultivo),
        greaterThanOrEqualTo(OficioStorageRules.cap));
    const seedKey = 'seed:nabo_claro';
    final ana0 = _ana();
    final ana = ana0.copyWith(
        life: ana0.life.copyWith(
            farm: ana0.life.farm.copyWith(seeds: {'nabo_claro': 3})));
    expect(LifeGiveRules.block(ana, full, seedKey, 1),
        LifeGiveBlock.recipientFull);
    final (e, s) = _room(a: ana, b: full);
    expect(e.apply(s, 'p0', const GiveLifeAction('p1', seedKey)), isNull);
    // Sumar a una pila que ya tiene entra; HERRERÍA tiene lugar.
    expect(LifeGiveRules.block(ana, full, 'crop:$_crop', 1), isNull);
    expect(LifeGiveRules.block(ana, full, 'craft:tabla', 1), isNull);
  });

  test('viaja por la red', () {
    const a = GiveLifeAction('p1', 'ore:ingot_copper', count: 5);
    final back = ActionJson.fromJson(ActionJson.toJson(a)) as GiveLifeAction;
    expect((back.toPlayerId, back.cell, back.count), ('p1', 'ore:ingot_copper', 5));
  });
}
