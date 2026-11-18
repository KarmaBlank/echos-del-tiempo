import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/core/persistence/ecos_log.dart';
import 'package:echos_del_tiempo/core/persistence/exit_guard.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Falla las primeras [failures] escrituras.
class _FlakyStore extends InMemoryAccountStore {
  _FlakyStore(super.initial, this.failures);
  int failures;

  @override
  Future<void> save(Account account) async {
    if (failures > 0) {
      failures--;
      throw const FileSystemException('trabado', 'account.json');
    }
    await super.save(account);
  }
}

class _FlakyProfiles extends InMemoryProfileStore {
  _FlakyProfiles(super.initial, this.failures);
  int failures;

  @override
  Future<void> save(PlayerProfile profile) async {
    if (failures > 0) {
      failures--;
      throw const FileSystemException('trabado', 'account.json');
    }
    await super.save(profile);
  }
}

const _fast = [Duration(milliseconds: 1)];

void main() {
  late Directory dir;
  final hero = progression
      .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', credits: 900));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ecos_hardening');
    EcosLog.reset();
  });

  tearDown(() async {
    EcosLog.reset();
    for (var i = 0;; i++) {
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        if (i > 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  JsonFileAccountStore store() =>
      JsonFileAccountStore(dir, retryDelays: _fast);

  group('AccountRepository', () {
    test('una escritura fallida se reintenta sola hasta que sale', () async {
      final disk = _FlakyStore(Account().add(hero), 2);
      final repo = AccountRepository(disk, retryDelays: _fast);
      final errors = <String?>[];
      repo.saveStatus.listen(errors.add);
      await repo.load();
      final a = repo.current!;
      await expectLater(
          repo.update((x) => x.replace(a.selectedId!,
              hero.copyWith(level: 7))),
          throwsA(isA<FileSystemException>()));
      expect(repo.saveError, isNotNull, reason: 'no en silencio');
      expect(repo.dirty, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.flush();
      expect(repo.saveError, isNull);
      expect(repo.dirty, isFalse);
      expect((await disk.load()).account.selected!.profile.level, 7);
      expect(errors.first, isNotNull);
      expect(errors.last, isNull);
      expect(EcosLog.recent.any((l) => l.contains('ERROR Guardado')), isTrue);
    });

    test('otra ventana con la cuenta: esta no escribe y lo avisa', () async {
      await store().save(Account().add(hero)!);
      final first =
          JsonFileAccountStore(dir, singleInstance: true, retryDelays: _fast);
      addTearDown(first.release);
      final a = AccountRepository(first);
      await a.load();
      expect(a.readOnly, isFalse);
      final second =
          JsonFileAccountStore(dir, singleInstance: true, retryDelays: _fast);
      addTearDown(second.release);
      final b = AccountRepository(second);
      await b.load();
      expect(b.readOnly, isTrue);
      expect(b.notice, contains('otra ventana'));
      // La segunda no pisa lo que guarda la primera.
      await a.update((x) => x.replace(x.selectedId!, hero.copyWith(level: 9)));
      await b.update((x) => x.add(hero.copyWith(level: 2))!);
      final disk = (await store().load()).account;
      expect(disk.characters, hasLength(1));
      expect(disk.selected!.profile.level, 9);
    }, skip: !Platform.isWindows ? 'El candado es por proceso fuera de '
        'Windows: no se puede probar en un solo proceso.' : false);
  });

  group('JsonFileAccountStore', () {
    test('account.json abierto por otro (antivirus): igual se guarda',
        () async {
      final s = store();
      await s.save(Account().add(hero)!);
      // Un lector con el archivo abierto: en Windows no deja renombrar
      // encima (plan B: escribir sobre el archivo).
      final reader = await s.file.open();
      try {
        await s.save(Account().add(hero.copyWith(level: 4))!);
      } finally {
        await reader.close();
      }
      expect((await store().load()).account.selected!.profile.level, 4);
    });

    test('se cortó entre la copia y el reemplazo: se recupera la copia',
        () async {
      final s = store();
      await s.tempFile.writeAsString(
          jsonEncode(Account().add(hero.copyWith(level: 6))!.toJson()));
      final l = await store().load();
      expect(l.account.selected!.profile.level, 6);
      expect(await s.file.exists(), isTrue);
    });

    test('una copia completa más nueva que account.json gana', () async {
      final s = store();
      await s.save(Account().add(hero.copyWith(level: 3))!);
      await s.file.setLastModified(DateTime(2020));
      await s.tempFile.writeAsString(
          jsonEncode(Account().add(hero.copyWith(level: 8))!.toJson()));
      expect((await store().load()).account.selected!.profile.level, 8);
    });

    test('v0.3 profile.json → cuenta, se juega y se reabre', () async {
      await File('${dir.path}${Platform.pathSeparator}profile.json')
          .writeAsString(jsonEncode(hero.copyWith(level: 5).toJson()));
      final repo = AccountRepository(store());
      expect((await repo.load()).selected!.profile.level, 5);
      await SelectedCharacterProfileStore(repo)
          .save(hero.copyWith(level: 6, xp: 3));
      await repo.flush();
      final again = (await AccountRepository(store()).load()).selected!;
      expect(again.profile.level, 6, reason: 'no vuelve a migrar el viejo');
      expect(again.profile.xp, 3);
    });
  });

  group('sesión', () {
    test('un guardado fallido se avisa en el HUD y se reintenta', () async {
      final profiles = _FlakyProfiles(hero, 1);
      final c = SessionController(
        engine: sessionEngine(),
        store: profiles,
        clock: const SessionClock(autoStart: false),
      );
      await c.start();
      await pumpEventQueue();
      expect(c.view!.saveError, isNotNull);
      expect(c.buyItem(BattleItem.potion), isTrue);
      c.advance(2.1);
      await pumpEventQueue();
      expect(c.view!.saveError, isNull);
      expect((await profiles.load())!.potions, hero.potions + 1);
      c.dispose();
    });

    test('cerrar la ventana a mitad de partida guarda lo último', () async {
      await store().save(Account().add(hero)!);
      final repo = AccountRepository(store());
      ExitGuard.register(repo, repo.flush, last: true);
      final c = SessionController(
        engine: sessionEngine(),
        store: SelectedCharacterProfileStore(repo),
        clock: const SessionClock(autoStart: false),
      );
      await c.start();
      await pumpEventQueue();
      expect(c.buyItem(BattleItem.potion), isTrue);
      // Sin esperar los 2 s del guardado periódico: se cierra la ventana.
      await ExitGuard.flushAll();
      ExitGuard.unregister(repo);
      expect((await store().load()).account.selected!.profile.potions,
          hero.potions + 1);
      c.dispose();
      await pumpEventQueue();
      await repo.flush();
    });
  });

  test('ecos.log registra y rota', () async {
    EcosLog.init(dir.path);
    EcosLog.error('Guardado', 'disco lleno');
    final f = File('${dir.path}${Platform.pathSeparator}ecos.log');
    expect(await f.readAsString(), contains('ERROR Guardado: disco lleno'));
    await f.writeAsString('x' * (EcosLog.maxBytes + 1));
    EcosLog.info('otra');
    expect(await File('${f.path}.1').exists(), isTrue);
    expect(await f.length(), lessThan(1000));
  });
}
