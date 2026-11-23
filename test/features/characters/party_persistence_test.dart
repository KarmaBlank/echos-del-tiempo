import '../../support/legacy_solo_mode.dart';
import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/features/characters/data/account_repository.dart';
import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/party_store.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Party jugando solo: cada miembro guarda en su ranura y el progreso
/// sigue al reabrir (docs/specs/solo_party.md § 5, characters.md § 1.4).

void main() {
  useTimelineSoloDefault();
  group('Account.party', () {
    Account three() {
      var a = Account();
      for (final n in ['Ana', 'Leo', 'Mia', 'Teo', 'Bo']) {
        a = a.add(newProfile(n, 'guerrero'))!;
      }
      return a.select('c1');
    }

    test('saneada: existe, sin repetir, nunca el elegido, hasta 3', () {
      final a = three().withParty(['c2', 'c2', 'c1', 'c9', 'c3', 'c4', 'c5']);
      expect(a.companions, ['c2', 'c3', 'c4']);
    });

    test('elegir como líder a un compañero lo saca de la party', () {
      final a = three().withParty(['c2', 'c3']).select('c2');
      expect(a.selectedId, 'c2');
      expect(a.companions, ['c3']);
    });

    test('borrar un personaje lo saca de la party y del AUTO', () {
      final a = three().withParty(['c2', 'c3']).withAuto('c2', true).remove('c2');
      expect(a.companions, ['c3']);
      expect(a.partyAuto, isEmpty);
    });

    test('JSON: ida y vuelta; sin `party` = solo', () {
      final a = three().withParty(['c3', 'c2']).withAuto('c3', true);
      final b = Account.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>);
      expect(b.companions, ['c3', 'c2']);
      expect(b.partyAuto, {'c3'});
      expect(three().toJson().containsKey('party'), isFalse);
    });
  });

  late Directory dir;
  final controllers = <SessionController>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ecos_party');
  });

  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
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

  AccountRepository openApp() => AccountRepository(JsonFileAccountStore(dir));

  /// Ana (líder) a 1 XP de subir, Leo y Mia de compañeros.
  Future<void> seed({List<String> party = const ['c2', 'c3']}) async {
    var a = Account();
    a = a.add(progression.normalize(PlayerProfile(
        name: 'Ana',
        classId: 'guerrero',
        xp: ProgressionRules.xpNeed(1) - 1)))!;
    a = a.add(newProfile('Leo', 'maga'))!;
    a = a.add(newProfile('Mia', 'tirador'))!;
    a = a.add(newProfile('Teo', 'guerrero'))!;
    await JsonFileAccountStore(dir).save(a.select('c1').withParty(party));
  }

  SessionController make(AccountRepository repo, {PartyStore? party}) {
    final c = SessionController(
      engine: sessionEngine(),
      store: SelectedCharacterProfileStore(repo),
      atlasStore: AccountAtlasStore(repo),
      clock: const SessionClock(autoStart: false),
      party: party ?? AccountPartyStore(repo),
    );
    controllers.add(c);
    return c;
  }

  Future<void> tick(SessionController c, [double s = 0.05]) async {
    await pumpEventQueue();
    c.advance(s);
    await pumpEventQueue();
  }

  /// `m1` hasta el resultado (enemigos a 1 de vida), sin AUTO: el líder
  /// elige por cada compañero en su turno. Vuelve al pueblo.
  Future<void> adventure(SessionController c) async {
    expect(c.proposeMission('m1'), isTrue);
    await tick(c, 0.1);
    expect(c.session!.mode, SessionMode.prep,
        reason: 'los compañeros no votan');
    c.setReady(true);
    await tick(c, 0.1);
    expect(c.session!.mode, SessionMode.field);
    await tick(c, c.session!.graceLeft + 0.1);
    final actors = <String>{};
    for (var i = 0; i < 6000 && c.session!.result == null; i++) {
      final s = c.session!;
      switch (s.mode) {
        case SessionMode.battle:
          final b = s.battle!;
          for (final en in b.state.enemies) {
            if (en.hp > 1) en.hp = 1;
          }
          if (c.view?.myTurn ?? false) {
            actors.add(b.state.currentId!);
            expect(c.battleCommand(const AttackCommand()), isTrue);
          }
        case SessionMode.levelUp:
          final v = c.view!;
          if (v.mustAllocate) {
            c.allocate({Attribute.vit: v.me!.profile.points});
          }
        case SessionMode.field:
          final boss = s.mission!.enemies.firstWhere((e) => e.boss);
          c.teleport(boss.x, boss.y);
        default:
          break;
      }
      await tick(c, 0.1);
    }
    expect(c.session!.result, isNotNull);
    expect(actors, containsAll(['local', 'local-c2', 'local-c3']),
        reason: 'cada compañero actuó en su turno');
    expect(c.backToLobby(), isTrue);
    for (var i = 0; i < 20; i++) {
      await tick(c);
    }
    expect(c.session!.mode, SessionMode.lobby);
  }

  test('cada miembro guarda en su ranura y sigue al reabrir', () async {
    await seed();
    final repo = openApp();
    final c = make(repo);
    await c.start();
    expect(c.session!.players.keys, ['local', 'local-c2', 'local-c3']);
    expect(c.view!.companions, ['local-c2', 'local-c3']);
    await adventure(c);
    final played = {
      for (final p in c.session!.playerList) p.id: p.profile,
    };
    expect(played['local-c2']!.xp + played['local-c2']!.level,
        greaterThan(1), reason: 'Leo ganó XP');
    c.dispose();
    await pumpEventQueue();
    await repo.flush();

    final a = await openApp().load();
    expect(a.selectedId, 'c1');
    String j(PlayerProfile p) => jsonEncode(p.toJson());
    expect(j(a.byId('c1')!.profile), j(played['local']!));
    expect(j(a.byId('c2')!.profile), j(played['local-c2']!));
    expect(j(a.byId('c3')!.profile), j(played['local-c3']!));
    expect(a.byId('c4')!.profile.xp, 0, reason: 'Teo no jugó');
    expect(a.byId('c2')!.lastPlayed, isNotNull);
    expect(a.byId('c2')!.profile.name, 'Leo');

    // Reabrir la sesión: los compañeros vuelven con lo ganado.
    final again = make(openApp());
    await again.start();
    expect(j(again.session!.players['local-c2']!.profile),
        j(played['local-c2']!));
  });

  test('cambiar la party en el pueblo: guarda al que sale, carga al que '
      'entra; en preparación no', () async {
    await seed(party: const ['c2']);
    final repo = openApp();
    final c = make(repo);
    await c.start();
    // Leo gana algo antes de salir.
    final leo = c.session!.players['local-c2']!;
    leo.profile = leo.profile.copyWith(credits: leo.profile.credits + 77);
    expect(await c.setParty(['c3', 'c4']), isTrue);
    expect(c.session!.players.keys, ['local', 'local-c3', 'local-c4']);
    await repo.flush();
    expect((await openApp().load()).byId('c2')!.profile.credits,
        leo.profile.credits);
    expect((await openApp().load()).companions, ['c3', 'c4']);

    expect(c.proposeMission('m1'), isTrue);
    expect(c.canEditParty, isFalse);
    expect(await c.setParty(['c2']), isFalse);
    expect(c.session!.players.keys, ['local', 'local-c3', 'local-c4']);
  });

  test('AUTO: los compañeros actúan solos y se recuerda en la cuenta',
      () async {
    await seed();
    final repo = openApp();
    final c = make(repo);
    await c.start();
    c.setAuto('local-c2', true);
    c.setAuto('local-c3', true);
    expect(c.view!.auto, {'local-c2', 'local-c3'});
    await repo.flush();
    expect((await openApp().load()).partyAuto, {'c2', 'c3'});
    expect(c.proposeMission('m1'), isTrue);
    await tick(c, 0.1);
    c.setReady(true);
    await tick(c, 0.1);
    await tick(c, c.session!.graceLeft + 0.1);
    final en = c.session!.mission!.enemy(0)!;
    c.teleport(en.x, en.y);
    await tick(c);
    expect(c.session!.mode, SessionMode.battle);
    var companionTurns = 0;
    for (var i = 0; i < 4000 && c.session!.mode == SessionMode.battle; i++) {
      final b = c.session!.battle!;
      if (b.waitingForPlayer && b.state.currentId != 'local') {
        expect(c.view!.myTurn, isFalse, reason: 'con AUTO no hay menú');
        companionTurns++;
      }
      if (c.view!.myTurn) c.battleCommand(const AttackCommand());
      await tick(c);
    }
    expect(c.session!.mode, isNot(SessionMode.battle));
    expect(companionTurns, greaterThan(0));
  });

  test('una escritura fallida de un compañero avisa y se reintenta', () async {
    final party = InMemoryPartyStore(
        slots: {'c2': newProfile('Leo', 'maga')}, party: ['c2']);
    final c = SessionController(
      engine: sessionEngine(),
      store: InMemoryProfileStore(newProfile('Ana', 'guerrero')),
      clock: const SessionClock(autoStart: false),
      party: party,
    );
    controllers.add(c);
    await c.start();
    await pumpEventQueue();
    final leo = c.session!.players['local-c2']!;
    party.failNext = true;
    leo.profile = leo.profile.copyWith(credits: 999);
    await tick(c, SessionController.saveEvery + 0.1);
    expect(c.view!.saveError, isNotNull);
    expect(party.profileOf('c2')!.credits, isNot(999));
    await tick(c, SessionController.saveEvery + 0.1);
    expect(party.profileOf('c2')!.credits, 999);
    expect(c.view!.saveError, isNull);
  });

  test('v0.8.3: lo que el líder le hace a un compañero se guarda en SU '
      'ranura', () async {
    var a = Account();
    a = a.add(newProfile('Ana', 'guerrero'))!;
    a = a.add(progression.normalize(
        newProfile('Leo', 'guerrero').copyWith(level: 5, credits: 5000)))!;
    await JsonFileAccountStore(dir).save(a.select('c1').withParty(['c2']));
    final repo = openApp();
    final c = make(repo);
    await c.start();
    final ana0 = jsonEncode(c.session!.players['local']!.profile.toJson());
    expect(c.setActing('local-c2'), isTrue);
    expect(c.view!.actorId, 'local-c2');
    final pts = c.session!.players['local-c2']!.profile.points;
    expect(pts, greaterThan(0), reason: 'Leo tiene puntos de nivel');
    expect(c.allocate({Attribute.vit: 1}), isTrue);
    final node = progression.treeRules.catalog.nodes.keys.firstWhere((id) =>
        progression.takeNode(c.session!.players['local-c2']!.profile, id) !=
        null);
    expect(c.takeNode(node), isTrue);
    expect(c.buyItem(BattleItem.potion), isTrue);
    final leo = c.session!.players['local-c2']!.profile;
    expect(leo.points, pts - 1);
    expect(leo.tree, [node]);
    expect(jsonEncode(c.session!.players['local']!.profile.toJson()), ana0,
        reason: 'Ana no cambió');
    c.dispose();
    await pumpEventQueue();
    await repo.flush();

    String j(PlayerProfile p) => jsonEncode(p.toJson());
    final b = await openApp().load();
    expect(j(b.byId('c2')!.profile), j(leo));
    expect(j(b.byId('c1')!.profile), ana0);
    // Reabrir: Leo vuelve con sus puntos gastados, su árbol y su poción.
    final again = make(openApp());
    await again.start();
    expect(j(again.session!.players['local-c2']!.profile), j(leo));
    expect(again.view!.actorId, 'local', reason: 'arranca con el líder');
  });

  test('en una sala (anfitrión) no hay compañeros', () async {
    final party = InMemoryPartyStore(
        slots: {'c2': newProfile('Leo', 'maga')}, party: ['c2']);
    final ana = newProfile('Ana', 'guerrero');
    final hn = LoopbackNetSession(LoopbackHub());
    await hn.connect(SessionConfig(profile: ana));
    final c = SessionController(
      engine: sessionEngine(),
      store: InMemoryProfileStore(ana),
      clock: const SessionClock(autoStart: false),
      net: hn,
      party: party,
    );
    controllers.add(c);
    await c.start();
    expect(c.session!.players.length, 1);
    expect(c.companionIds, isEmpty);
    expect(c.canEditParty, isFalse);
    expect(await c.setParty(['c2']), isFalse);
  });
}
