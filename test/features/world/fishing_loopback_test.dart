import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Pesca en red (fishing.md § 7): el cliente clava, el anfitrión tira el
/// pez, el cliente dice que lo sacó y el anfitrión lo otorga.
void main() {
  final controllers = <SessionController>[];
  tearDown(() {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
  });

  SessionController make(NetSession net, PlayerProfile p) {
    final c = SessionController(
      engine: sessionEngine(),
      store: InMemoryProfileStore(p),
      clock: const SessionClock(autoStart: false),
      net: net,
    );
    controllers.add(c);
    return c;
  }

  Future<void> tick(SessionController host, SessionController me,
      [double s = 0.05]) async {
    me.advance(0.05);
    await pumpEventQueue();
    host.advance(s);
    await pumpEventQueue();
  }

  test('loopback: picada del host, resultado del cliente, pez otorgado',
      () async {
    final hub = LoopbackHub();
    final hn = LoopbackNetSession(hub), cn = LoopbackNetSession(hub);
    final hp = progression.normalize(PlayerProfile(name: 'Host', classId: 'maga'));
    final cp = progression.normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'));
    await hn.connect(SessionConfig(profile: hp));
    final host = make(hn, hp);
    await host.start();
    await cn.connect(SessionConfig(profile: cp, roomCode: hn.roomCode));
    final me = make(cn, cp);
    await me.start();
    for (var i = 0; i < 3; i++) {
      await tick(host, me);
    }
    final bites = <FishBiteEvent>[];
    final caught = <FishCaughtEvent>[];
    final chat = <String>[];
    host.events.listen((e) {
      if (e is FishCaughtEvent) caught.add(e);
      if (e is SystemMessageEvent) chat.add(e.text);
    });
    me.events.listen((e) {
      if (e is FishBiteEvent) bites.add(e);
    });
    final spot = TownLayout.fishingSpots.first;
    // ignore: invalid_use_of_visible_for_testing_member
    me.teleport((spot.$1 + 1) * 16.0 + 4, (spot.$2 + 0.5) * 16.0);
    await tick(host, me);
    expect(me.nearFishing, isTrue);
    me.fishBite(0.8);
    await tick(host, me);
    await tick(host, me);
    expect(bites, hasLength(1));
    expect(bites.single.playerId, me.localId);
    expect(bites.single.species, isIn(kTownLakeDefault));
    for (var i = 0; i < 40; i++) {
      await tick(host, me, 0.1);
    }
    me.fishResult(true);
    for (var i = 0; i < 3; i++) {
      await tick(host, me);
    }
    expect(caught.single.species, bites.single.species);
    final mine = me.view!.me!.profile;
    expect(mine.life.count(bites.single.species), 1);
    expect(mine.life.fishXp, greaterThan(0));
    expect(chat.any((t) => t.contains('Ana pescó')), isTrue);
    // El host también lo ve en su copia del perfil del cliente.
    expect(host.session!.players[me.localId]!.profile.life.bagTotal, 1);
  });
}
