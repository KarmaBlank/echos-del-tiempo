import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/oficio_storage_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Bolsas de oficio (docs/specs/oficio_storage.md).
PlayerProfile _withBag(Map<String, int> bag, {int credits = 0}) =>
    newProfile('Ana', 'guerrero')
        .copyWith(credits: credits, life: LifeSkills(bag: bag));

/// Especies que entran en la bolsa (pescados y basura del agua).
final _all = [
  for (final id in kFish.keys)
    if (id != kWaterBundle) id
];

/// [n] especies distintas.
Map<String, int> _species(int n) => {for (final id in _all.take(n)) id: 1};

void main() {
  test('qué cuenta en cada bolsa', () {
    final p = newProfile('Ana', 'guerrero');
    // Caña de rama en PESCA; azada, regadera y semillas iniciales en CULTIVO.
    expect(OficioStorageRules.used(p, OficioBag.pesca), 1);
    expect(OficioStorageRules.used(p, OficioBag.cultivo), greaterThan(1));
    expect(OficioStorageRules.used(p, OficioBag.herreria), 0);
    final q = p.copyWith(life: p.life.copyWith(crafts: {'tabla': 3}));
    expect(OficioStorageRules.used(q, OficioBag.herreria), 1);
  });

  test('una especie nueva con la bolsa llena se vende sola', () {
    final before = _withBag(_species(39)); // + la caña = 40
    expect(OficioStorageRules.used(before, OficioBag.pesca), 40);
    final extra = kFish[_all[39]]!;
    final after = before.copyWith(life: before.life.addFish(extra.id, 2));
    expect(OficioStorageRules.overflows(before, after), isTrue);
    final r = OficioStorageRules.settle(before, after);
    expect(r.profile.life.count(extra.id), 0);
    expect(r.gold, extra.price * 2);
    expect(r.profile.credits, extra.price * 2);
    expect(OficioStorageRules.used(r.profile, OficioBag.pesca), 40);
    // Sumar a una pila que ya existe siempre entra.
    final first = _species(1).keys.first;
    final more = before.copyWith(life: before.life.addFish(first, 5));
    expect(OficioStorageRules.overflows(before, more), isFalse);
  });

  test('un save viejo con más de 40 no pierde nada, pero no crece', () {
    final before = _withBag(_species(45));
    expect(OficioStorageRules.used(before, OficioBag.pesca), 46);
    expect(OficioStorageRules.room(before, OficioBag.pesca), 46);
    final same = before.copyWith(
        life: before.life.addFish(_species(1).keys.first));
    expect(OficioStorageRules.overflows(before, same), isFalse);
  });

  test('las compras que no entran las rechaza el host', () {
    expect(OficioStorageRules.isPurchase(const BuyRodAction('cana_roble')),
        isTrue);
    expect(
        OficioStorageRules.isPurchase(
            const FarmShopAction(FarmShopOp.buySeed, id: 'nabo_claro')),
        isTrue);
    expect(OficioStorageRules.isPurchase(const SellFishAction()), isFalse);
    final e = sessionEngine();
    var s = e.addPlayer(e.create(), 'p0', _withBag(_species(39), credits: 5000))!
        .state;
    expect(e.apply(s, 'p0', const BuyRodAction('cana_roble')), isNull);
    s = e.addPlayer(e.create(), 'p0', _withBag(_species(3), credits: 5000))!
        .state;
    expect(e.apply(s, 'p0', const BuyRodAction('cana_roble')), isNotNull);
  });
}
