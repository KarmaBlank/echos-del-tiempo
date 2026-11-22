import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/ults_v2_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/ult_rules.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Regresión: en una sala de 3, la ULT elegida del ANFITRIÓN (una Maga)
/// no debe volver a la base (Meteoro) con las acciones de siempre
/// (ultimates_v2.md § 2.1).
void main() {
  test('la ULT elegida del anfitrión sobrevive a una misión completa',
      () async {
    final ult = kUltV2List.firstWhere((u) =>
        u.classes.isEmpty || u.classes.contains('maga'));
    final base = UltRules.baseUltId('maga');
    expect(ult.id, isNot(base));
    final hub = LoopbackHub();
    final all = <SessionController>[];
    Future<SessionController> make(NetSession net, PlayerProfile p) async {
      final c = SessionController(
        engine: sessionEngine(),
        store: InMemoryProfileStore(p),
        clock: const SessionClock(autoStart: false),
        net: net,
      );
      all.add(c);
      await c.start();
      return c;
    }

    final hp = progression.normalize(PlayerProfile(
        name: 'Ana', classId: 'maga', credits: 5000, ultKnown: {ult.id}));
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: hp));
    final host = await make(hn, hp);
    for (final (n, cls) in [('Leo', 'guerrero'), ('Mia', 'tirador')]) {
      final p = newProfile(n, cls);
      final cn = LoopbackNetSession(hub);
      await cn.connect(SessionConfig(profile: p, roomCode: hn.roomCode));
      await make(cn, p);
    }
    Future<void> tick([double s = 0.05]) async {
      for (final c in all.skip(1)) {
        c.advance(0.05);
      }
      await pumpEventQueue();
      host.advance(s);
      await pumpEventQueue();
    }

    void check(String when) {
      final s = host.session!;
      final me = s.players[host.localId]!;
      expect(me.profile.ultSel, ult.id, reason: 'ultSel tras $when');
      final c = s.battle?.state.party
          .where((c) => c.id == host.localId)
          .firstOrNull;
      if (c != null) {
        expect(ultimateOf(c, host.engine.catalog)?.id, ult.id,
            reason: 'ULT en batalla tras $when');
      }
      final v = host.view?.me?.profile.ultSel;
      expect(v, ult.id, reason: 'vista del anfitrión tras $when');
    }

    await tick();
    await tick();
    expect(host.selectUlt(ult.id), isTrue);
    await tick();
    check('elegir');
    expect(host.buyWeapon(progression.catalog.weapons.keys.firstWhere(
            (id) => progression.buyWeapon(
                    host.session!.players[host.localId]!.profile, id) !=
                null)),
        isTrue);
    await tick();
    check('comprar');

    for (var round = 0; round < 2; round++) {
      expect(host.proposeMission('m1'), isTrue);
      await tick();
      for (final c in all.skip(1)) {
        c.vote(true);
      }
      await tick(0.1);
      await tick(0.1);
      for (final c in all) {
        c.setReady(true);
      }
      await tick(0.1);
      await tick(0.1);
      expect(host.session!.mode, SessionMode.field);
      check('entrar');
      // Santuario: la bendición de la misión (la causa de v0.20.12).
      host.session!.mission!.blessing = BlessingKind.values[round];
      await tick(host.session!.graceLeft + 0.1);
      for (var i = 0;
          i < 6000 && host.session!.mode != SessionMode.result;
          i++) {
        final s = host.session!;
        switch (s.mode) {
          case SessionMode.battle:
            for (final en in s.battle!.state.enemies) {
              if (en.hp > 1) en.hp = 1;
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
        await tick(0.1);
        check('tick $i (${s.mode.name})');
      }
      expect(host.backToLobby(), isTrue);
      for (var i = 0; i < 40; i++) {
        await tick();
        check('volver');
      }
    }
    for (final c in all) {
      c.dispose();
    }
  });
}
