import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Lugares fijos movibles en red (town_editor.md § 3.3 y § 8).
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

  test('loopback: el dueño mueve la forja y el cliente la usa ahí', () async {
    final hub = LoopbackHub();
    final hn = LoopbackNetSession(hub), cn = LoopbackNetSession(hub);
    final hp =
        progression.normalize(PlayerProfile(name: 'Host', classId: 'maga'));
    final cp =
        progression.normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'));
    await hn.connect(SessionConfig(profile: hp));
    final host = make(hn, hp);
    await host.start();
    await cn.connect(SessionConfig(profile: cp, roomCode: hn.roomCode));
    final me = make(cn, cp);
    await me.start();
    for (var i = 0; i < 3; i++) {
      await tick(host, me);
    }
    expect(host.enterTownEdit(), isTrue);
    // Clic en la forja (19..23, 3): MOVER.
    host.editClick(21, 3);
    expect(host.townEdit!.step, TownEditStep.options);
    expect(host.editLandmark!.spot, TownSpot.forge);
    host.editStartMove();
    host.editHover(26, 8);
    expect(host.editGhostError, isNull);
    host.editClick(26, 8);
    for (var i = 0; i < 4; i++) {
      await tick(host, me);
    }
    expect(me.town.marks['@forge'], (26, 8));
    final m = MapGenerator.townOf(me.town);
    expect(m.tileAt(26, 8), TownLayout.landmark(TownSpot.forge).tile);
    expect(WorldRules.townSpot(28 * 16, 9 * 16 + 4, map: m), TownSpot.forge);
    expect(WorldRules.townSpot(21 * 16, 4 * 16 + 4, map: m),
        isNot(TownSpot.forge));
    // El tablero y el comerciante movidos: E abre su panel donde quedaron.
    for (final (id, x, y) in [('@board', 3, 8), ('@trader', 25, 2)]) {
      host.editClick(TownLayout.byId(id)!.x, TownLayout.byId(id)!.y);
      host.editStartMove();
      host.editHover(x, y);
      expect(host.editGhostError, isNull, reason: id);
      host.editClick(x, y);
      for (var i = 0; i < 4; i++) {
        await tick(host, me);
      }
    }
    host.exitTownEdit();
    final b = TownLayout.byId('@board')!;
    me.teleport(4 * 16, (8 + b.h) * 16 + 4.0);
    await tick(host, me);
    expect(me.nearCounter, isTrue);
    me.interact();
    expect(me.view!.panel, WorldPanel.missionBoard);
    me.closePanel();
    me.teleport(26 * 16, 3 * 16 + 4.0);
    await tick(host, me);
    expect(me.nearTrader, isTrue);
    me.interact();
    expect(me.view!.panel, WorldPanel.trader);
  });
}
