import 'dart:convert';

import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

Account _roundTrip(Account a) => Account.fromJson(
    jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>);

void main() {
  final rules = CharacterRules(progression);
  final t0 = DateTime(2026, 11, 17, 21, 5);

  group('Account', () {
    test('crear: perfil inicial normalizado, elegido, id nuevo', () {
      var a = Account();
      expect(a.selected, isNull);
      a = rules.create(a, '  Anastasia Larga ', 'maga', now: t0)!;
      final c = a.selected!;
      expect(c.id, 'c1');
      expect(c.created, t0);
      expect(c.lastPlayed, isNull);
      expect(c.profile.name, 'Anastasia'); // 10 caracteres y sin espacios
      expect(c.profile.classId, 'maga');
      expect(c.profile.level, 1);
      expect(c.profile.equipped, 'baculo_aprendiz');
      expect(c.profile.potions, PlayerProfile.defaultPotions);
      expect(c.profile.ethers, PlayerProfile.defaultEthers);

      a = rules.create(a, '', 'tirador')!;
      expect(a.selected!.id, 'c2');
      expect(a.selected!.profile.name, Account.defaultName);
      expect(rules.create(a, 'X', 'no_existe'), isNull);
    });

    test('máximo 8 y los id no se reusan al borrar', () {
      var a = Account();
      for (var i = 0; i < Account.maxCharacters; i++) {
        a = rules.create(a, 'P$i', 'guerrero')!;
      }
      expect(a.isFull, isTrue);
      expect(rules.create(a, 'Otro', 'guerrero'), isNull);
      a = a.remove('c8');
      a = rules.create(a, 'Nuevo', 'paladin')!;
      expect(a.selected!.id, 'c9');
    });

    test('elegir, renombrar y borrar (con el nombre escrito)', () {
      var a = Account();
      a = rules.create(a, 'Ana', 'maga')!;
      a = rules.create(a, 'Bo', 'tirador')!;
      a = rules.create(a, 'Cid', 'paladin')!;
      expect(a.selectedId, 'c3');
      a = a.select('c2');
      expect(a.selected!.profile.name, 'Bo');
      expect(a.select('zzz').selectedId, 'c2', reason: 'id inexistente');

      a = rules.rename(a, 'c2', '  Boris el Grande ');
      expect(a.byId('c2')!.profile.name, 'Boris el G');
      expect(a.byId('c2')!.profile.classId, 'tirador');

      // Sin la confirmación correcta no borra.
      expect(CharacterRules.delete(a, 'c2', ''), isNull);
      expect(CharacterRules.delete(a, 'c2', 'Bo'), isNull);
      final b = CharacterRules.delete(a, 'c2', '  boris el g ')!;
      expect(b.characters.map((c) => c.id), ['c1', 'c3']);
      expect(b.selectedId, 'c1', reason: 'el elegido pasa al primero');
      // Borrar otro que no es el elegido lo mantiene.
      expect(b.select('c3').remove('c1').selectedId, 'c3');
      expect(b.remove('c1').remove('c3').selected, isNull);
    });

    test('confirmación de un nombre vacío: Héroe', () {
      final a = Account().add(PlayerProfile(name: ''))!;
      expect(a.selected!.displayName, 'Héroe');
      expect(CharacterRules.delete(a, 'c1', 'heroe'), isNull);
      expect(CharacterRules.delete(a, 'c1', 'héroe'), isNotNull);
    });

    test('ida y vuelta por JSON con fechas, elegido y alijo', () {
      var a = rules.create(Account(), 'Ana', 'maga', now: t0)!;
      a = rules.create(a, 'Bo', 'tirador', now: t0)!;
      a = a.touch('c1', t0.add(const Duration(hours: 1))).select('c1');
      a = a.withStash(Stash.empty()
          .put(
              3,
              const StashEntry.item(
                  ItemInstance(uid: 'x', baseId: 'espada_bronce')))
          .put(50, const StashEntry.material(CraftMaterial.cristal, 120)));
      final b = _roundTrip(a);
      expect(b.selectedId, 'c1');
      expect(b.seq, 2);
      expect(b.characters.map((c) => c.profile.name), ['Ana', 'Bo']);
      expect(b.byId('c1')!.lastPlayed, t0.add(const Duration(hours: 1)));
      expect(b.byId('c2')!.lastPlayed, isNull);
      expect(b.byId('c2')!.created, t0);
      expect(b.stash.cells[3]!.item!.baseId, 'espada_bronce');
      expect(b.stash.cells[50]!.material, CraftMaterial.cristal);
      expect(b.stash.cells[50]!.count, 120);
      expect(b.stash.used, 2);
    });

    test('lectura tolerante', () {
      final a = Account.fromJson({
        'sel': 'nada',
        'chars': [
          'basura',
          {
            'id': 'c1',
            'p': {'name': 'Ana', 'cls': 'maga'}
          },
          {
            'id': 'c1',
            'p': {'name': 'Dup'}
          },
          {
            'p': {'name': 'SinId'}
          },
        ],
        'stash': 7,
      });
      expect(a.characters.map((c) => c.profile.name), ['Ana']);
      expect(a.selectedId, 'c1', reason: 'elegido inexistente → el primero');
      expect(a.stash.isEmpty, isTrue);
      expect(Account.fromJson(const {}).characters, isEmpty);
    });
  });
}
