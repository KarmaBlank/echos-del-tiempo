import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/game_engine/models/achievement.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:flutter_test/flutter_test.dart';

// Hazañas en la cuenta (docs/specs/achievements.md § 6): clave `ach`,
// unión al guardar y migración retroactiva con recompensa.

PlayerProfile _forged({int credits = 100}) => PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: credits,
      items: const [
        ItemInstance(
            uid: 'a',
            baseId: 'espada_ignea',
            rarity: Rarity.raro,
            itemLevel: 12,
            forge: WeaponUpgradeLevels(pow: 3, crit: 1)),
        ItemInstance(
            uid: 'b',
            baseId: 'espada_bronce',
            forge: WeaponUpgradeLevels(pow: 3, crit: 2),
            extraSkills: ['giro']),
      ],
      equipped: 'a',
      milestone10: 'x',
    );

void main() {
  group('migración retroactiva (§ 6.1)', () {
    test('marca las inferidas con su recompensa al elegido, una sola vez',
        () {
      final old = Account().add(_forged())!.add(_forged(credits: 5))!;
      final sel = old.selectedId!;
      expect(old.achievementsRaw, isNull);
      final (a, u) = migrateAccountAchievements(old, nowS: 1000);
      final ids = u.map((x) => x.id).toSet();
      expect(ids, containsAll(
          ['forge_first', 'forge_plus5', 'forge_cap', 'fuse_skill', 'tree_milestone']));
      expect(a.achievements.isDone('forge_plus5'), isTrue);
      expect(a.achievements.count(AchievementCounter.forgeLevels), 18);
      // forgeLevels = 18 → también Forjador II.
      expect(ids, contains('forge_10'));
      var credits = 0;
      for (final x in u) {
        credits += x.reward.credits;
      }
      expect(a.byId(sel)!.profile.credits, 5 + credits,
          reason: 'el paquete va al elegido');
      final other = a.characters.firstWhere((c) => c.id != sel);
      expect(other.profile.credits, 100);
      // Idempotente.
      final (b, u2) = migrateAccountAchievements(a, nowS: 2000);
      expect(u2, isEmpty);
      expect(identical(a, b), isTrue);
      // `ach` en el JSON (con `v`) aunque se vuelva a leer.
      final back = Account.fromJson(a.toJson());
      expect(back.achievementsRaw, isNotNull);
      expect(back.achievements.done.keys.toSet(), a.achievements.done.keys.toSet());
      expect(a.toJson()['ach'], isA<Map>());
    });

    test('Atlas tomado y Abismo vencido se infieren de la cuenta', () {
      final old = Account(
              atlas: AtlasProgress(nodes: const ['c1'], done: const ['x1', 't2']))
          .add(PlayerProfile(name: 'Leo'))!;
      final (a, u) = migrateAccountAchievements(old, nowS: 1);
      expect(u.map((x) => x.id),
          containsAll(['atlas_node', 'abyss_boss', 'eco_first']));
      expect(a.achievements.isDone('fuse_first'), isFalse,
          reason: 'los contadores de fusión no se infieren');
    });

    test('cuenta nueva: `ach` vacío, sin aviso', () {
      final (a, u) = migrateAccountAchievements(Account(), nowS: 1);
      expect(u, isEmpty);
      expect(a.achievementsRaw, isNotNull);
      expect(a.toJson()['ach'], {'v': AchievementProgress.version});
    });

    test('el repositorio migra al cargar y avisa', () async {
      final store = InMemoryAccountStore(Account().add(_forged())!);
      final repo = AccountRepository(store, retryDelays: const []);
      final a = await repo.load();
      expect(a.achievements.isDone('forge_first'), isTrue);
      expect(repo.notice, startsWith('Hazañas recuperadas:'));
      await repo.flush();
      // Al volver a abrir ya no se repite.
      final again = AccountRepository(store, retryDelays: const []);
      await again.load();
      expect(again.notice, isNull);
    });
  });

  group('guardar sin pisar (§ 5.1)', () {
    test('replace une sets y toma el máximo de contadores; el personaje no '
        'guarda `ach`', () {
      var a = Account(
              achievementsRaw: AchievementProgress(
                  done: {'fuse_first': 5}, counters: {'fusions': 4}))
          .add(PlayerProfile(name: 'Ana'))!;
      final id = a.selectedId!;
      final p = a.profileFor(id)!;
      expect(p.achievements.isDone('fuse_first'), isTrue,
          reason: 'a la sala va con lo de la cuenta');
      // Otra sesión (vieja) guarda con menos contador y otra hazaña.
      a = a.replace(
          id,
          p.copyWith(
              achievements: AchievementProgress(
                  done: {'sell_first': 9}, counters: {'fusions': 2, 'salvaged': 3})));
      expect(a.achievements.done.keys.toSet(), {'fuse_first', 'sell_first'});
      expect(a.achievements.counters, {'fusions': 4, 'salvaged': 3});
      expect(a.byId(id)!.profile.achievements.isEmpty, isTrue);
      expect((a.toJson()['chars'] as List).first.toString(),
          isNot(contains('ach:')));
    });

    test('dos personajes no pagan doble: la recompensa es una por cuenta',
        () {
      var a = Account().add(PlayerProfile(name: 'Ana'))!;
      final ana = a.selectedId!;
      a = a.add(PlayerProfile(name: 'Leo'))!;
      final leo = a.selectedId!;
      final (a1, u1) = a.grantAchievements(ana, ['inv_search'], 1);
      expect(u1.map((x) => x.id), ['inv_search']);
      final (a2, u2) = a1.grantAchievements(leo, ['inv_search'], 2);
      expect(u2, isEmpty);
      expect(identical(a1, a2), isTrue);
    });

    test('el perfil de sesión lleva las de la cuenta', () async {
      final store = InMemoryAccountStore(Account(
              achievementsRaw:
                  AchievementProgress(done: {'forge_first': 1}))
          .add(PlayerProfile(name: 'Ana'))!);
      final repo = AccountRepository(store, retryDelays: const []);
      final p = await SelectedCharacterProfileStore(repo).load();
      expect(p!.achievements.isDone('forge_first'), isTrue);
      await SelectedCharacterProfileStore(repo).save(p.copyWith(
          achievements: p.achievements.merge(
              AchievementProgress(done: {'fuse_first': 3}))));
      expect(repo.current!.achievements.done.keys.toSet(),
          {'forge_first', 'fuse_first'});
    });
  });
}
