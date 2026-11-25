import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/raft_rules.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Lake rafts over the real protocol (fishing.md § 15): each player
/// boards their own raft, everyone sees both, the host keeps positions.
void main() {
  final controllers = <SessionController>[];
  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
    BiomeRegions.bind(0);
    await pumpEventQueue();
  });

  Future<SessionController> make(NetSession net, ProfileStore store) async {
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: store,
      clock: const SessionClock(autoStart: false),
      net: net,
    );
    controllers.add(c);
    await c.start();
    return c;
  }

  test('two rafts at once, synced both ways', () async {
    var seed = 0;
    for (; seed < 60; seed++) {
      BiomeRegions.bind(seed);
      if (biomeLayout(kBosque)!.raftDocks.isNotEmpty) break;
    }
    final hub = LoopbackHub();
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    final host =
        await make(hn, InMemoryProfileStore(newProfile('Host', 'guerrero')));
    final an = LoopbackNetSession(hub);
    await an.connect(SessionConfig(
        profile: newProfile('Ana', 'maga'), roomCode: hn.roomCode));
    final ana = await make(an, InMemoryProfileStore());

    Future<void> net([int n = 3]) async {
      for (var i = 0; i < n; i++) {
        ana.advance(0.05);
        await pumpEventQueue();
        host.advance(0.05);
        await pumpEventQueue();
      }
    }

    await net();
    host.debugTown((t) => t.copyWith(sky: t.sky.copyWith(seed: seed, day: 1)));
    expect(host.travelPlace(kBosque), isTrue);
    await net();
    BiomeRegions.bind(seed);
    final d = biomeLayout(kBosque)!.raftDocks.first;
    for (final c in [host, ana]) {
      c.teleport((d.x + 0.5) * 16, (d.y + 0.5) * 16);
    }
    await net();
    final ap = ana.session!.players['p1']!;
    expect(ana.nearRaftDock, isNotNull,
        reason: '${ana.session!.place} ${ana.session!.town.sky.seed} $seed ${ap.x},${ap.y} $d ${ana.local.x}');
    expect(ana.boardRaft(), isTrue);
    expect(host.boardRaft(), isTrue);
    await net();
    for (final c in [host, ana]) {
      expect(c.session!.players['h']!.rafting, isTrue);
      expect(c.session!.players['p1']!.rafting, isTrue);
    }
    // Ana paddles out; the host sees her on the water.
    final start = ana.session!.players['p1']!;
    for (var i = 0; i < 10; i++) {
      ana.updateLocal(0.05, (d.wx - d.x).toDouble(), (d.wy - d.y).toDouble());
      await net(1);
    }
    ana.updateLocal(0.05, 0, 0);
    await net();
    final moved = host.session!.players['p1']!;
    expect((moved.x - start.x).abs() + (moved.y - start.y).abs(),
        greaterThan(8));
    expect(RaftRules.onWater(host.engine.mapFor(host.session!), moved.x, moved.y), isTrue);
    // Back to the dock and off.
    ana.teleport(start.x, start.y);
    await net();
    expect(ana.canLeaveRaft, isTrue);
    expect(ana.leaveRaft(), isTrue);
    await net();
    expect(host.session!.players['p1']!.rafting, isFalse);
    expect(ana.session!.players['p1']!.rafting, isFalse);
    expect(ana.session!.players['h']!.rafting, isTrue);
  });
}
