import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Pociones fuera de batalla (docs/specs/loot.md § 17.5): `useItem`
/// validado por el host.
void main() {
  group('motor', () {
    final e = sessionEngine();

    test('en misión cura 45% y consume la poción', () {
      var s = inField(e, 'm1');
      final p = s.players['p0']!..hp = 1;
      final before = p.profile.potions;
      s = act(e, s, 'p0', const UseItemAction(BattleItem.potion));
      final me = s.players['p0']!;
      expect(me.hp, closeTo(1 + (me.maxHp * 0.45).round(), 0.01));
      expect(me.profile.potions, before - 1);
    });

    test('maná: restaura 50%', () {
      var s = inField(e, 'm1');
      s.players['p0']!.mp = 0;
      s = act(e, s, 'p0', const UseItemAction(BattleItem.ether));
      final me = s.players['p0']!;
      expect(me.mp, closeTo((me.maxMp * 0.5).round(), 0.01));
    });

    test('vida llena, sin pociones y en batalla: rechazado', () {
      final s = inField(e, 'm1');
      expect(e.apply(s, 'p0', const UseItemAction(BattleItem.potion)), isNull);
      s.players['p0']!
        ..hp = 1
        ..profile = s.players['p0']!.profile.copyWith(potions: 0);
      expect(e.apply(s, 'p0', const UseItemAction(BattleItem.potion)), isNull);
      s.players['p0']!.profile =
          s.players['p0']!.profile.copyWith(potions: 2);
      s.mode = SessionMode.battle;
      expect(e.apply(s, 'p0', const UseItemAction(BattleItem.potion)), isNull);
    });

    test('viaja por la red', () {
      const a = UseItemAction(BattleItem.ether);
      final back = ActionJson.fromJson(ActionJson.toJson(a)) as UseItemAction;
      expect(back.item, BattleItem.ether);
    });
  });

  group('loopback host + cliente', () {
    final controllers = <SessionController>[];
    tearDown(() {
      for (final c in controllers) {
        if (c.mounted) c.dispose();
      }
      controllers.clear();
    });

    SessionController make(NetSession net, ProfileStore store) {
      final c = SessionController(
        engine: sessionEngine(),
        store: store,
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

    Future<(SessionController, SessionController)> setup() async {
      final hub = LoopbackHub();
      final hn = LoopbackNetSession(hub), cn = LoopbackNetSession(hub);
      final other = newProfile('Amigo', 'maga');
      final mine = newProfile('Ana', 'guerrero');
      await hn.connect(SessionConfig(profile: other));
      final host = make(hn, InMemoryProfileStore(other));
      await host.start();
      await cn.connect(SessionConfig(profile: mine, roomCode: hn.roomCode));
      final me = make(cn, InMemoryProfileStore(mine));
      await me.start();
      for (var i = 0; i < 3; i++) {
        await tick(host, me);
      }
      return (host, me);
    }

    SessionPlayer hostSide(SessionController host, SessionController me) =>
        host.session!.players[me.view!.localId]!;

    test('lobby: vida llena bloqueado; herido la usa', () async {
      final (host, me) = await setup();
      expect(me.useItemBlock(BattleItem.potion), 'Vida llena');
      expect(me.useItem(BattleItem.potion), isFalse);
      hostSide(host, me).hp = 1;
      await tick(host, me);
      await tick(host, me);
      expect(me.useItemBlock(BattleItem.potion), isNull);
      final before = me.view!.me!.profile.potions;
      expect(me.useItem(BattleItem.potion), isTrue);
      for (var i = 0; i < 4; i++) {
        await tick(host, me);
      }
      expect(me.view!.me!.profile.potions, before - 1);
      expect(me.view!.me!.hp, greaterThan(1));
      expect(hostSide(host, me).profile.potions, before - 1);
    });

    test('misión: tecla 2 usa maná; sin pociones bloqueado', () async {
      final (host, me) = await setup();
      expect(host.proposeMission('m1'), isTrue);
      await tick(host, me);
      me.vote(true);
      await tick(host, me, 0.1);
      await tick(host, me, 0.1);
      host.setReady(true);
      me.setReady(true);
      await tick(host, me, 0.1);
      await tick(host, me, 0.1);
      expect(me.session!.mode, SessionMode.field);
      final p = hostSide(host, me)
        ..mp = 0
        ..hp = 1;
      p.profile = p.profile.copyWith(potions: 0);
      await tick(host, me);
      await tick(host, me);
      expect(me.useItemBlock(BattleItem.potion), 'No te quedan');
      final ethers = me.view!.me!.profile.ethers;
      expect(me.handleKey(LogicalKeyboardKey.digit2), isTrue);
      for (var i = 0; i < 4; i++) {
        await tick(host, me);
      }
      expect(me.view!.me!.profile.ethers, ethers - 1);
      expect(me.view!.me!.mp, greaterThan(0));
    });
  });
}
