import 'dart:convert';

import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/tutorial_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// TUTORIAL en red y la bandera de la cuenta (docs/specs/combat_tutorial.md
/// § 2 y § 6). Nada toca la carpeta real de datos: cuentas en memoria.

void main() {
  group('cuenta: tutV junto a bv', () {
    test('ida y vuelta, nunca baja y sobrevive a borrar un personaje', () {
      final a = Account().withTutorial(1);
      final json = jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>;
      expect(json['tutV'], 1);
      expect(json.containsKey('bv'), isTrue);
      expect(Account.fromJson(json).tutorialVersion, 1);
      expect(a.withTutorial(0).tutorialVersion, 1);
      expect(Account().toJson().containsKey('tutV'), isFalse,
          reason: 'cuenta nueva: tutV = 0');
      final p = progression
          .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'));
      final b = a.add(p)!;
      expect(b.remove(b.selectedId!).tutorialVersion, 1);
    });
  });

  test('el hello lleva tv (protocolo 15)', () {
    expect(kProtocolVersion, 15);
    final codec = WireCodec();
    final p = PlayerProfile(name: 'Ana', classId: 'guerrero');
    final msg = codec.decode(
        codec.encode(HelloMessage(p, tutorialVersion: 0))) as HelloMessage;
    expect(msg.tutorialVersion, 0);
    expect(jsonDecode(codec.encode(HelloMessage(p)))['tv'], kTutorialVersion);
  });

  group('en red (loopback)', () {
    final controllers = <SessionController>[];
    tearDown(() {
      for (final c in controllers) {
        if (c.mounted) c.dispose();
      }
      controllers.clear();
    });

    SessionController make(NetSession net, PlayerProfile p,
        TutorialStore store) {
      final c = SessionController(
        engine: sessionEngine(),
        store: InMemoryProfileStore(p),
        tutorialStore: store,
        clock: const SessionClock(autoStart: false),
        net: net,
      );
      controllers.add(c);
      return c;
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

    /// Cada uno hace lo que le dice su cartel (como en la pantalla).
    Future<void> playTurns(SessionController host,
        List<SessionController> all) async {
      for (final c in all) {
        final s = c.session;
        final t = s?.tutorial;
        final b = s?.battle;
        if (t == null || b == null) continue;
        final card = t.card;
        if (card != null) {
          if (card.actorId == c.localId ||
              (card.actorId == null && c == host)) {
            c.ackTutorial();
          }
          continue;
        }
        final cur = b.state.current;
        if (!b.waitingForPlayer || cur == null || cur.id != c.localId) {
          continue;
        }
        final step = c.tutorialRules.currentStep(t);
        if (step is TutorialPlayerStep && t.prepared) {
          c.battleCommand(c.tutorialRules.scripted(step, cur)!);
        } else if (step is TutorialFreeStep) {
          c.battleCommand(const DefendCommand());
        }
      }
    }

    Future<(SessionController, SessionController, InMemoryTutorialStore,
        InMemoryTutorialStore)> room() async {
      final hub = LoopbackHub();
      final hn = LoopbackNetSession(hub);
      final cn = LoopbackNetSession(hub);
      final hs = InMemoryTutorialStore(0), cs = InMemoryTutorialStore(0);
      final ana = progression
          .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'));
      final beto =
          progression.normalize(PlayerProfile(name: 'Beto', classId: 'maga'));
      await hn.connect(SessionConfig(profile: ana, tutorialVersion: 0));
      final host = make(hn, ana, hs);
      await host.start();
      await cn.connect(SessionConfig(
          profile: beto, roomCode: hn.roomCode, tutorialVersion: 0));
      final client = make(cn, beto, cs);
      await client.start();
      for (var i = 0; i < 4; i++) {
        await tick(host, [host, client]);
      }
      return (host, client, hs, cs);
    }

    test('el sello bloquea y el tutorial en grupo marca las dos cuentas',
        () async {
      final (host, client, hs, cs) = await room();
      final all = [host, client];
      expect(client.session!.players['p1']!.tutorialVersion, 0,
          reason: 'tutV viajó en el hello');
      expect(host.tutorialRules.lockText(host.session!),
          'Primero, todos tienen que hacer el TUTORIAL. Falta: Ana, Beto');
      expect(host.proposeMission('m1'), isFalse);
      // Solo el host lo inicia.
      client.startTutorial(); // el cliente lo pide; el host lo rechaza
      await tick(host, all);
      expect(host.session!.tutorial, isNull);
      expect(host.startTutorial(), isTrue);
      await tick(host, all);
      expect(client.session!.tutorial, isNotNull,
          reason: 'TutorialState viaja en el snapshot');
      for (var i = 0; i < 20000 && host.session!.tutorial != null; i++) {
        await playTurns(host, all);
        await tick(host, all);
      }
      await tick(host, all);
      await tick(host, all);
      expect(host.session!.mode, SessionMode.lobby);
      expect(hs.version, kTutorialVersion);
      expect(cs.version, kTutorialVersion);
      expect(host.tutorialRules.lockText(host.session!), isNull);
      expect(host.proposeMission('m1'), isTrue);
    });

    test('si el host se va, el tutorial se corta y nadie lo completa',
        () async {
      final (host, client, hs, cs) = await room();
      final all = [host, client];
      expect(host.startTutorial(), isTrue);
      for (var i = 0; i < 300; i++) {
        await playTurns(host, all);
        await tick(host, all);
      }
      expect(client.session!.tutorial, isNotNull);
      host.dispose();
      for (var i = 0; i < 5; i++) {
        await pumpEventQueue();
        client.advance(0.05);
      }
      expect(cs.version, 0);
      expect(hs.version, 0);
    });
  });
}
