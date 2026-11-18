import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/characters/domain/stash.dart';
import 'package:echos_del_tiempo/features/lobby/data/json_file_profile_store.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';
import '../inventory/loot_fixtures.dart';

/// Store que falla al leer (disco bloqueado) y cuenta las escrituras.
class _BrokenStore implements AccountStore {
  int saves = 0;
  @override
  Future<AccountLoad> load() async =>
      throw const FileSystemException('bloqueado');
  @override
  Future<void> save(Account account) async => saves++;
}

void main() {
  final rules = CharacterRules(progression);
  final t0 = DateTime(2026, 11, 17, 21, 5, 9);

  // Siempre en carpetas temporales: nunca la carpeta real del jugador.
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ecos_account'));
  tearDown(() => dir.deleteSync(recursive: true));

  File at(String name) => File('${dir.path}${Platform.pathSeparator}$name');

  group('JsonFileAccountStore', () {
    test('sin archivos: cuenta vacía y no escribe nada', () async {
      final l = await JsonFileAccountStore(dir).load();
      expect(l.account.characters, isEmpty);
      expect(l.notice, isNull);
      expect(l.migrated, isFalse);
      expect(dir.listSync(), isEmpty);
    });

    test('migra profile.json como personaje #1 y lo deja intacto', () async {
      final legacy = at('profile.json');
      await JsonFileProfileStore(legacy).save(progression.normalize(
          PlayerProfile(name: 'Ana', classId: 'maga', level: 7, credits: 321)));
      final before = legacy.readAsBytesSync();
      final modified = legacy.lastModifiedSync();

      final store = JsonFileAccountStore(dir);
      final l = await store.load();
      expect(l.migrated, isTrue);
      final c = l.account.selected!;
      expect(c.id, 'c1');
      expect(c.profile.name, 'Ana');
      expect(c.profile.classId, 'maga');
      expect(c.profile.level, 7);
      expect(c.profile.credits, 321);
      expect(c.lastPlayed, modified);
      expect(at('account.json').existsSync(), isTrue);
      expect(legacy.readAsBytesSync(), before, reason: 'copia de seguridad');

      // La segunda vez se lee account.json (profile.json ya no manda).
      await JsonFileProfileStore(legacy)
          .save(PlayerProfile(name: 'Viejo', classId: 'guerrero'));
      final again = await JsonFileAccountStore(dir).load();
      expect(again.migrated, isFalse);
      expect(again.account.characters.map((c) => c.profile.name), ['Ana']);
    });

    test('profile.json corrupto: cuenta vacía, sin tocarlo', () async {
      at('profile.json').writeAsStringSync('{nope');
      final l = await JsonFileAccountStore(dir).load();
      expect(l.account.characters, isEmpty);
      expect(at('profile.json').readAsStringSync(), '{nope');
      expect(at('account.json').existsSync(), isFalse);
    });

    test('account.json corrupto: copia, cuenta nueva y aviso', () async {
      at('account.json').writeAsStringSync('{"chars": [ roto');
      final l = await JsonFileAccountStore(dir, now: () => t0).load();
      expect(l.account.characters, isEmpty);
      const backup = 'account.corrupt-20261117-210509.json';
      expect(l.notice, contains(backup));
      expect(l.notice, contains('dañado'));
      expect(at(backup).readAsStringSync(), '{"chars": [ roto');
      // Se escribió una cuenta vacía válida.
      final fresh = jsonDecode(at('account.json').readAsStringSync());
      expect(fresh, isA<Map<String, Object?>>());
      expect(
          Account.fromJson(fresh as Map<String, Object?>).characters, isEmpty);

      // Otra vez corrupto en el mismo segundo: otra copia, no pisa.
      at('account.json').writeAsStringSync('[]');
      final l2 = await JsonFileAccountStore(dir, now: () => t0).load();
      expect(l2.notice, contains('account.corrupt-20261117-210509-2.json'));
      expect(at(backup).readAsStringSync(), '{"chars": [ roto');
    });

    test('UTF-8 inválido también es "dañado"', () async {
      at('account.json').writeAsBytesSync([0xff, 0xfe, 0x00, 0x7b]);
      final l = await JsonFileAccountStore(dir, now: () => t0).load();
      expect(l.notice, isNotNull);
      expect(at('account.corrupt-20261117-210509.json').readAsBytesSync(),
          [0xff, 0xfe, 0x00, 0x7b]);
    });

    test('guarda atómico (sin .tmp) y vuelve igual', () async {
      var a = rules.create(Account(), 'Ana', 'maga', now: t0)!;
      a = rules.create(a, 'Bo', 'tirador', now: t0)!;
      a = a.withStash(Stash.empty()
          .put(9, const StashEntry.item(epicSword))
          .put(10, const StashEntry.material(CraftMaterial.prisma, 400)));
      final s = JsonFileAccountStore(Directory('${dir.path}/sub'));
      await s.save(a);
      expect(Directory('${dir.path}/sub').listSync().map((e) => e.path),
          [endsWith('account.json')]);
      final back = (await s.load()).account;
      expect(back.selectedId, 'c2');
      expect(back.characters.map((c) => c.profile.name), ['Ana', 'Bo']);
      expect(back.stash.cells[9]!.item!.name, 'Filo del Alba');
      expect(back.stash.cells[10]!.count, 400);
    });
  });

  group('AccountRepository + SelectedCharacterProfileStore', () {
    test('la sesión lee y escribe el personaje elegido', () async {
      var a = rules.create(Account(), 'Ana', 'maga')!;
      a = rules.create(a, 'Bo', 'tirador')!;
      a = rules.create(a, 'Cid', 'paladin')!.select('c2');
      final mem = InMemoryAccountStore(a);
      final repo = AccountRepository(mem, now: () => t0);
      final ps = SelectedCharacterProfileStore(repo);

      final p = (await ps.load())!;
      expect(p.name, 'Bo');
      await ps.save(p.copyWith(credits: 999, level: 3));
      final saved = (await mem.load()).account;
      expect(saved.byId('c2')!.profile.credits, 999);
      expect(saved.byId('c2')!.lastPlayed, t0);
      expect(saved.byId('c1')!.profile.credits, 0, reason: 'los otros no');
      expect(saved.byId('c3')!.lastPlayed, isNull);
    });

    test('sin personajes: load null y save lo agrega', () async {
      final mem = InMemoryAccountStore();
      final repo = AccountRepository(mem, now: () => t0);
      final ps = SelectedCharacterProfileStore(repo);
      expect(await ps.load(), isNull);
      await ps.save(PlayerProfile(name: 'Héroe'));
      final saved = (await mem.load()).account;
      expect(saved.characters.single.profile.name, 'Héroe');
      expect(saved.selected!.lastPlayed, t0);
    });

    test('avisa cambios y los escribe en orden', () async {
      final mem = InMemoryAccountStore();
      final repo = AccountRepository(mem);
      final seen = <int>[];
      repo.changes.listen((a) => seen.add(a.characters.length));
      await Future.wait([
        repo.update((a) => rules.create(a, 'A', 'maga')!),
        repo.update((a) => rules.create(a, 'B', 'maga')!),
      ]);
      await pumpEventQueue();
      expect(seen, [1, 2]);
      expect((await mem.load()).account.characters.length, 2);
      expect(mem.saves, 2);
    });

    test('si no se pudo leer, no escribe (no pisa el archivo)', () async {
      final broken = _BrokenStore();
      final repo = AccountRepository(broken);
      final a = await repo.load();
      expect(a.characters, isEmpty);
      expect(repo.readOnly, isTrue);
      expect(repo.notice, contains('no se guardará'));
      await repo.update((a) => rules.create(a, 'A', 'maga')!);
      expect(repo.current!.characters.length, 1, reason: 'en memoria sí');
      expect(broken.saves, 0);
    });

    test('el SessionController juega con el personaje elegido', () async {
      var a = rules.create(Account(), 'Ana', 'maga')!;
      a = rules.create(a, 'Bo', 'tirador')!.select('c1');
      final mem = InMemoryAccountStore(a);
      final repo = AccountRepository(mem, now: () => t0);
      final c = SessionController(
        engine: sessionEngine(),
        store: SelectedCharacterProfileStore(repo),
        clock: const SessionClock(autoStart: false),
      );
      await c.start();
      expect(c.view!.me!.name, 'Ana');
      expect(c.view!.me!.profile.classId, 'maga');
      c.dispose();
      await pumpEventQueue();
      await repo.flush();
      final saved = (await mem.load()).account;
      expect(saved.byId('c1')!.lastPlayed, t0);
      expect(saved.byId('c2')!.lastPlayed, isNull);
      expect(saved.byId('c2')!.profile.name, 'Bo');
    });

    test('dos personajes en el disco: cada uno con su progreso', () async {
      final store = JsonFileAccountStore(dir);
      var a = rules.create(Account(), 'Ana', 'maga')!;
      a = rules.create(a, 'Bo', 'tirador')!;
      await store.save(a.select('c1'));
      final repo = AccountRepository(store);
      final ps = SelectedCharacterProfileStore(repo);
      await ps.save((await ps.load())!.copyWith(credits: 50));
      await repo.update((a) => a.select('c2'));
      await ps.save((await ps.load())!.copyWith(credits: 7));
      final back = (await JsonFileAccountStore(dir).load()).account;
      expect(back.byId('c1')!.profile.credits, 50);
      expect(back.byId('c2')!.profile.credits, 7);
      expect(back.selectedId, 'c2');
    });
  });
}
