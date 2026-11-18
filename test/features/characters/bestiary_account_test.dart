import 'dart:convert';

import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/bestiary.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

// Bestiario en la cuenta (docs/specs/bestiary.md § 2.1).

Combatant _e(String type) => Combatant(
    id: type,
    name: type,
    isPlayer: false,
    hp: 0,
    maxHp: 1,
    speed: 1,
    attack: 1,
    critChance: 0,
    enemyType: type);

void main() {
  group('BestiaryProgress', () {
    test('la primera muerte desbloquea; las repetidas suman', () {
      final b = BestiaryProgress.empty.record(['slime', 'slime', 'bat']);
      expect(b.knows('slime'), isTrue);
      expect(b.knows('lobo'), isFalse);
      expect(b.killsOf('slime'), 2);
      expect(b.discovered, 2);
      expect(b.newIn(['slime', 'lobo']), {'lobo'});
      expect(identical(b.record(const []), b), isTrue);
    });

    test('JSON de ida y vuelta, lectura tolerante', () {
      final b = BestiaryProgress({'slime': 3, 'golem': 1});
      expect(BestiaryProgress.fromJson(b.toJson()).kills, b.kills);
      final bad = BestiaryProgress.fromJson({
        'k': {'slime': 2, 'x': 'mucho', 'y': 0, 'z': -3, 'w': 1.9}
      });
      expect(bad.kills, {'slime': 2, 'w': 1});
      expect(BestiaryProgress.fromJson('basura').isEmpty, isTrue);
      expect(BestiaryProgress.fromJson(null).isEmpty, isTrue);
    });

    test('al ganar cuentan todos los enemigos de la batalla', () {
      final s = BattleState(party: const [], enemies: [
        _e('sierpe'),
        _e('cristalHielo'),
        _e('elementalEscarcha'),
      ]);
      expect(bestiaryKills(s), ['sierpe', 'cristalHielo', 'elementalEscarcha']);
    });
  });

  group('Account', () {
    test('cuentas viejas (sin "best"): bestiario vacío, se lee igual', () {
      final old = {
        'v': 1,
        'sel': 'c1',
        'seq': 1,
        'chars': [
          {
            'id': 'c1',
            'p': PlayerProfile(name: 'Ana', classId: 'guerrero').toJson()
          },
        ],
        'stash': const <String, Object?>{},
      };
      final a = Account.fromJson(old);
      expect(a.characters.single.id, 'c1');
      expect(a.bestiary.isEmpty, isTrue);
      // Vacío: no se escribe la clave (archivo igual al de antes).
      expect(a.toJson().containsKey('best'), isFalse);
    });

    test('se guarda en "best" y sobrevive a borrar personajes', () {
      var a = Account().add(PlayerProfile(name: 'Ana', classId: 'guerrero'))!;
      a = a.withBestiary(BestiaryProgress({'lobo': 2}));
      final json = jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>;
      expect(json['best'], {
        'k': {'lobo': 2}
      });
      final back = Account.fromJson(json);
      expect(back.bestiary.killsOf('lobo'), 2);
      expect(back.remove(back.selectedId!).bestiary.killsOf('lobo'), 2);
      expect(back.withAtlas(back.atlas).bestiary.killsOf('lobo'), 2);
    });

    test('AccountBestiaryStore: guarda en la cuenta sin pisar conteos mayores',
        () async {
      final repo = AccountRepository(InMemoryAccountStore());
      final store = AccountBestiaryStore(repo);
      await store.save(BestiaryProgress({'slime': 5, 'bat': 1}));
      expect((await store.load()).kills, {'slime': 5, 'bat': 1});
      // Otra sesión que cargó antes (slime 2) guarda: queda el máximo.
      await store.save(BestiaryProgress({'slime': 2, 'lobo': 1}));
      expect((await repo.load()).bestiary.kills,
          {'slime': 5, 'bat': 1, 'lobo': 1});
    });
  });
}
