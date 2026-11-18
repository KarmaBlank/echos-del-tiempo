import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/build_plan.dart';
import 'package:echos_del_tiempo/game_engine/models/build_wants.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// El resumen del plan de build viaja del cliente al host por el
/// protocolo real (acción `wants`; docs/specs/netcode.md § "Build y
/// filtro") y solo el host lo usa para los drops de ese jugador.
void main() {
  late LoopbackHub hub;
  final controllers = <SessionController>[];

  Future<SessionController> make(NetSession net, ProfileStore store) async {
    final c = SessionController(
      engine: sessionEngine(),
      store: store,
      clock: const SessionClock(autoStart: false),
      net: net,
    );
    controllers.add(c);
    await c.start();
    return c;
  }

  tearDown(() async {
    for (final c in controllers) {
      if (c.mounted) c.dispose();
    }
    controllers.clear();
    await pumpEventQueue();
  });

  test('el plan del cliente llega al host al entrar y cuando cambia',
      () async {
    hub = LoopbackHub();
    final hn = LoopbackNetSession(hub);
    await hn.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    final host =
        await make(hn, InMemoryProfileStore(newProfile('Host', 'guerrero')));
    final an = LoopbackNetSession(hub);
    await an.connect(SessionConfig(
        profile: newProfile('Ana', 'maga'), roomCode: hn.roomCode));
    final ana = await make(an, InMemoryProfileStore());

    Future<void> net() async {
      ana.advance(0.05);
      await pumpEventQueue();
      host.advance(0.05);
      await pumpEventQueue();
    }

    // El plan se fija antes del primer snapshot: se manda al recibirlo.
    final axe = BuildWants.fromPlan(const BuildPlan(
        weaponTypes: ['hacha'], mods: [ModGoal('feroz', 3)]));
    ana.setBuildWants(axe);
    await net();
    await net();
    expect(host.session!.players['p1']!.buildWants, axe);
    // No viaja a los clientes (ni al propio).
    expect(ana.session!.players['p1']!.buildWants, isNull);

    // Cambia el plan: llega el nuevo.
    final staff = BuildWants.fromPlan(const BuildPlan(weaponTypes: ['báculo']));
    ana.setBuildWants(staff);
    await net();
    expect(host.session!.players['p1']!.buildWants, staff);

    // El host también guarda el suyo (aplicado localmente).
    host.setBuildWants(axe);
    expect(host.session!.players['h']!.buildWants, axe);

    // La ★ de la UI: el plan local solo para el jugador local.
    const drop = LootDrop.item(
        ItemInstance(uid: 'x', baseId: 'baculo_fuego', itemLevel: 1));
    expect(ana.lootVerdictFor('p1', drop)!.buildMatch, isTrue);
    expect(ana.lootVerdictFor('h', drop)!.buildMatch, isFalse);
    expect(host.lootVerdictFor('p1', drop)!.buildMatch, isFalse,
        reason: 'el host no muestra el plan de un compañero');

    // Borrar el plan.
    ana.setBuildWants(BuildWants.none);
    await net();
    expect(host.session!.players['p1']!.buildWants, isNull);
  });
}
