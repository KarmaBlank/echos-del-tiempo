import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/core/di/service_locator.dart';
import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas_store.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Invariante del dueño: "no importa dónde juegues, el progreso del
/// personaje se mantiene" (docs/specs/characters.md § 1.4). El mismo
/// personaje del mismo `account.json` se lee y se escribe igual jugando
/// solo, como anfitrión o como cliente. Regresión del bug de v0.4 ("el
/// progreso no se guardaba" de un amigo que jugó como cliente).
enum _Mode { solo, host, client }

void main() {
  late Directory dir;
  final controllers = <SessionController>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ecos_progress');
  });

  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
    // El guardado del `dispose` puede seguir escribiendo un momento.
    for (var i = 0;; i++) {
      await pumpEventQueue();
      try {
        await dir.delete(recursive: true);
        break;
      } on FileSystemException {
        if (i > 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  /// "Abrir la app": repositorio nuevo sobre el disco.
  AccountRepository openApp() => AccountRepository(
      JsonFileAccountStore(dir));

  /// Personaje a 1 XP de subir de nivel, con créditos y materiales.
  Future<PlayerProfile> seed() async {
    final p = progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      xp: ProgressionRules.xpNeed(1) - 1,
      credits: 5000,
      materials: const {CraftMaterial.esquirla: 2},
    ));
    await JsonFileAccountStore(dir)
        .save(Account().add(p)!);
    return p;
  }

  SessionController make(NetSession? net, ProfileStore store,
      [AtlasStore? atlas]) {
    final c = SessionController(
      engine: sessionEngine(),
      store: store,
      atlasStore: atlas,
      clock: const SessionClock(autoStart: false),
      net: net,
    );
    controllers.add(c);
    return c;
  }

  /// Arma la partida en [mode] para el personaje de [repo]. Devuelve
  /// (yo, el que corre las reglas, todos).
  Future<(SessionController, SessionController, List<SessionController>)>
      play(_Mode mode, AccountRepository repo) async {
    final store = SelectedCharacterProfileStore(repo);
    final atlas = AccountAtlasStore(repo);
    if (mode == _Mode.solo) {
      final me = make(null, store, atlas);
      await me.start();
      return (me, me, [me]);
    }
    final hub = LoopbackHub();
    final other =
        progression.normalize(PlayerProfile(name: 'Amigo', classId: 'maga'));
    final hn = LoopbackNetSession(hub);
    final cn = LoopbackNetSession(hub);
    // Como el título: el perfil que viaja sale de la cuenta.
    final mine = progression.normalize((await repo.load()).selected!.profile);
    if (mode == _Mode.host) {
      await hn.connect(SessionConfig(profile: mine));
      final me = make(hn, store, atlas);
      await me.start();
      await cn.connect(SessionConfig(profile: other, roomCode: hn.roomCode));
      final friend = make(cn, InMemoryProfileStore(other));
      await friend.start();
      return (me, me, [me, friend]);
    }
    await hn.connect(SessionConfig(profile: other));
    final host = make(hn, InMemoryProfileStore(other));
    await host.start();
    await cn.connect(SessionConfig(profile: mine, roomCode: hn.roomCode));
    final me = make(cn, store, atlas);
    await me.start();
    return (me, host, [host, me]);
  }

  Future<void> tick(SessionController host, List<SessionController> all,
      [double s = 0.05]) async {
    for (final c in all) {
      if (c != host && c.mounted) c.advance(0.05);
    }
    await pumpEventQueue();
    host.advance(s);
    await pumpEventQueue();
  }

  /// En el pueblo compra una poción y un arma; después juega `m1` hasta
  /// el resultado (enemigos a 1 de vida) y vuelve al pueblo.
  Future<void> adventure(SessionController me, SessionController host,
      List<SessionController> all) async {
    await tick(host, all);
    await tick(host, all);
    final p = me.view!.me!.profile;
    expect(me.buyItem(BattleItem.potion), isTrue);
    final weapon = progression.catalog.weapons.keys
        .firstWhere((id) => progression.buyWeapon(p, id) != null);
    expect(me.buyWeapon(weapon), isTrue);
    await tick(host, all);
    await tick(host, all);

    expect(host.proposeMission('m1'), isTrue);
    await tick(host, all);
    for (final c in all) {
      if (c != host) c.vote(true);
    }
    await tick(host, all, 0.1);
    await tick(host, all, 0.1);
    expect(host.session!.mode, SessionMode.prep);
    for (final c in all) {
      c.setReady(true);
    }
    await tick(host, all, 0.1);
    await tick(host, all, 0.1);
    expect(host.session!.mode, SessionMode.field);
    await tick(host, all, host.session!.graceLeft + 0.1);
    for (var i = 0;
        i < 6000 && host.session!.result == null;
        i++) {
      final s = host.session!;
      switch (s.mode) {
        case SessionMode.battle:
          final b = s.battle!;
          for (final en in b.state.enemies) {
            if (en.hp > 1) en.hp = 1;
          }
          for (final c in b.state.party) {
            if (c.alive) c.hp = c.maxHp;
          }
          for (final c in all) {
            if (c.view?.myTurn ?? false) {
              c.battleCommand(const AttackCommand());
            }
          }
        case SessionMode.levelUp:
          for (final c in all) {
            final v = c.view;
            if (v != null && v.mustAllocate) {
              c.allocate({Attribute.vit: v.me!.profile.points});
            }
          }
        case SessionMode.field:
          final boss = s.mission!.enemies.firstWhere((e) => e.boss);
          host.teleport(boss.x, boss.y);
        default:
          break;
      }
      await tick(host, all, 0.1);
    }
    expect(host.session!.result, isNotNull);
    expect(host.session!.result!.success, isTrue);
    for (final c in all) {
      c.setLeaveReady(true);
    }
    for (var i = 0; i < 50; i++) {
      await tick(host, all);
    }
    expect(host.session!.mode, SessionMode.lobby);
  }

  for (final mode in _Mode.values) {
    test('${mode.name}: XP, nivel, loot y materiales siguen al reabrir',
        () async {
      final start = await seed();
      final repo = openApp();
      final (me, host, all) = await play(mode, repo);
      await adventure(me, host, all);
      final played = me.view!.me!.profile;
      expect(played.level, greaterThan(start.level), reason: 'subió');
      expect(played.potions, greaterThan(start.potions - 1));
      expect(played.items.length, greaterThan(start.items.length),
          reason: 'compró un arma');
      expect(played.materials[CraftMaterial.esquirla],
          greaterThanOrEqualTo(2));

      // Sale (SALIR AL TÍTULO) y cierra la app.
      me.dispose();
      await pumpEventQueue();
      await repo.flush();

      final saved = (await openApp().load()).selected!.profile;
      expect(jsonEncode(saved.toJson()), jsonEncode(played.toJson()),
          reason: 'el disco tiene exactamente lo jugado');
    });
  }

  test('lo ganado solo viaja al unirse a una sala (y vuelve a disco)',
      () async {
    await seed();
    var repo = openApp();
    var (me, host, all) = await play(_Mode.solo, repo);
    await adventure(me, host, all);
    final solo = me.view!.me!.profile;
    me.dispose();
    await pumpEventQueue();
    await repo.flush();

    repo = openApp();
    (me, host, all) = await play(_Mode.client, repo);
    await tick(host, all);
    await tick(host, all);
    final inRoom = host.session!.players[me.localId]!.profile;
    expect(inRoom.level, solo.level);
    expect(inRoom.xp, solo.xp);
    expect(inRoom.items.length, solo.items.length);
    expect(me.view!.me!.profile.level, solo.level);
  });

  group('cableado de dependencias: una sola cuenta para todos los modos', () {
    tearDown(() => sl.reset());

    for (final (name, register) in [
      ('LAN', registerLanNetcode),
      ('P2P', () => registerP2PNetcode(signaling: null)),
    ]) {
      test(name, () {
        registerSharedDependencies(accountStore: InMemoryAccountStore());
        register();
        final repo = sl<AccountRepository>();
        final profiles = sl<ProfileStore>();
        expect(profiles, isA<SelectedCharacterProfileStore>());
        expect((profiles as SelectedCharacterProfileStore).repository,
            same(repo));
        final atlas = sl<AtlasStore>();
        expect((atlas as AccountAtlasStore).repository, same(repo));
      });
    }
  });
}
