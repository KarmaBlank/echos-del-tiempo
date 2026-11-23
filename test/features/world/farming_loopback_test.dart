import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/farm_plot.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Huerta en red (farming.md § 10): el cliente ara, planta, riega y
/// cosecha; el anfitrión valida, hace crecer y otorga la cosecha.
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

  test('loopback: el dueño mueve la huerta en la edición y el cliente la ve',
      () async {
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
    // Uno a la vez (town_editor.md § 1.3): edita el host y el cliente
    // ve el botón bloqueado.
    expect(host.enterTownEdit(), isTrue);
    await tick(host, me);
    expect(me.cannotEditTown, 'Está editando Host');
    expect(me.enterTownEdit(), isFalse);
    host.editClick(20, 19);
    expect(host.townEdit!.step, TownEditStep.options);
    expect(host.editSelected!.id, 'h0');
    host.editStartMove();
    host.editHover(4, 8);
    expect(host.editGhostError, isNull);
    host.editClick(4, 8);
    for (var i = 0; i < 4; i++) {
      await tick(host, me);
    }
    expect(me.town.build('h0')!.bounds.x, 4);
    expect(me.town.build('h0')!.bounds.y, 8);
  });

  test('loopback: el cliente planta y cosecha; el host otorga', () async {
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
    final harvested = <CropHarvestedEvent>[];
    me.events.listen((e) {
      if (e is CropHarvestedEvent) harvested.add(e);
    });
    const bf = TownLayout.baseFarm;
    // ignore: invalid_use_of_visible_for_testing_member
    me.teleport((bf.x + 1.5) * 16.0, (bf.y + 1.5) * 16.0);
    await tick(host, me);
    // Trabaja el tile de enfrente (o el que pisa), siempre en la huerta.
    final (tx, ty) = me.farmTile!;
    expect(tx, inInclusiveRange(bf.x, bf.x + bf.w - 1));

    Future<void> work(FarmOp op) async {
      expect(me.farmOp, op);
      expect(me.farmWork(), isTrue);
      for (var i = 0; i < 6; i++) {
        await tick(host, me);
      }
    }

    await work(FarmOp.till);
    expect(host.session!.town.plots[plotKey(tx, ty)], isNotNull);
    await work(FarmOp.plant);
    final planted = me.plotAt(tx, ty)!;
    expect(planted.planted, isTrue);
    expect(planted.planter, 'Ana');
    await work(FarmOp.water);
    expect(me.plotAt(tx, ty)!.waterer, 'Ana');
    // El host la hace crecer (pasos de 1 s) hasta madurar.
    for (var i = 0; i < 600 && me.farmOp != FarmOp.harvest; i++) {
      await tick(host, me, 1);
    }
    expect(me.farmOp, FarmOp.harvest);
    expect(me.plotInfo(tx, ty), contains('Si la cosechás vos'));
    await work(FarmOp.harvest);
    expect(harvested, hasLength(1));
    expect(harvested.single.playerId, me.localId);
    final mine = me.view!.me!.profile.life.farm;
    expect(mine.crops.values.fold(0, (a, b) => a + b),
        harvested.single.count);
    expect(mine.xp, greaterThan(0));
    // La parcela queda arada y vacía, igual para el host.
    expect(host.session!.town.plots[plotKey(tx, ty)]!.planted, isFalse);
  });
}
