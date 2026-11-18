import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/bestiary.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Bestiario en co-op por el protocolo real (docs/specs/bestiary.md §
/// 2.2): ganar una batalla suma las muertes al bestiario de la cuenta de
/// CADA jugador que estaba, también del cliente (sin cambios de
/// protocolo: sale del estado de la batalla que ya llega).
void main() {
  late LoopbackHub hub;
  late SessionController host, ana;
  late InMemoryBestiaryStore hostBest, anaBest;
  final controllers = <SessionController>[];

  Future<SessionController> make(
      NetSession net, ProfileStore store, BestiaryStore best) async {
    final c = SessionController(
      engine: sessionEngine(),
      store: store,
      bestiaryStore: best,
      clock: const SessionClock(autoStart: false),
      net: net,
    );
    controllers.add(c);
    await c.start();
    return c;
  }

  Future<void> net([double seconds = 0.05]) async {
    if (ana.mounted) ana.advance(0.05);
    await pumpEventQueue();
    host.advance(seconds);
    await pumpEventQueue();
  }

  setUp(() async {
    hub = LoopbackHub();
    hostBest = InMemoryBestiaryStore();
    // Ana ya había matado 3 limos con otro personaje de su cuenta.
    anaBest = InMemoryBestiaryStore(BestiaryProgress({'slime': 3}));
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    host = await make(
        hn, InMemoryProfileStore(newProfile('Host', 'guerrero')), hostBest);
    final an = LoopbackNetSession(hub);
    await an.connect(SessionConfig(
        profile: newProfile('Ana', 'maga'), roomCode: hn.roomCode));
    ana = await make(an, InMemoryProfileStore(), anaBest);
    await net();
  });

  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
    await pumpEventQueue();
  });

  test('una victoria desbloquea las fichas en las dos cuentas', () async {
    expect(host.bestiary.isEmpty, isTrue);
    expect(ana.bestiary.killsOf('slime'), 3, reason: 'cargado de la cuenta');

    host.proposeMission('m1');
    await net();
    ana.vote(true);
    await net(0.1);
    host.setReady(true);
    ana.setReady(true);
    await net(0.1);
    expect(host.session!.mode, SessionMode.field);

    await net(host.session!.graceLeft + 0.1);
    final en = host.session!.mission!.enemies
        .firstWhere((e) => e.alive && !e.boss && !e.elite);
    host.teleport(en.x, en.y);
    await net();
    await net();
    expect(host.session!.mode, SessionMode.battle);
    final types = [
      for (final e in host.session!.battle!.state.enemies) e.enemyType!,
    ];
    expect(ana.view!.bestiary, isNotNull);

    for (var i = 0; i < 4000 && host.session!.mode == SessionMode.battle; i++) {
      final b = host.session!.battle!;
      for (final e in b.state.enemies) {
        if (e.hp > 1) e.hp = 1;
      }
      for (final c in b.state.party) {
        if (c.alive) c.hp = c.maxHp;
      }
      if (host.view!.myTurn) host.battleCommand(const AttackCommand());
      if (ana.view!.myTurn) ana.battleCommand(const AttackCommand());
      await net(0.1);
    }
    await net();
    await net();
    expect(host.session!.mode, isNot(SessionMode.battle));

    int count(String t) => types.where((x) => x == t).length;
    for (final t in types.toSet()) {
      expect(host.bestiary.killsOf(t), count(t), reason: 'host $t');
      expect(ana.bestiary.killsOf(t), count(t) + (t == 'slime' ? 3 : 0),
          reason: 'cliente $t');
      expect(ana.view!.bestiary!.knows(t), isTrue);
    }
    // Se guardó en la cuenta de cada uno.
    expect((await hostBest.load()).kills, host.bestiary.kills);
    expect((await anaBest.load()).kills, ana.bestiary.kills);
    expect(hostBest.saves, 1);
    expect(anaBest.saves, 1);
    // Aviso local de lo nuevo (el host no conocía nada).
    expect(host.lastUnlocked, types.toSet());
    expect(ana.lastUnlocked, types.toSet().difference({'slime'}));
  });
}
