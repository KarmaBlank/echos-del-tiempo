import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Guardado del pueblo al editar y aviso de guardado
/// (docs/specs/save_indicator.md). Todo en memoria: nunca toca disco.
void main() {
  test('el pueblo se guarda al terminar de editar y se ve el aviso', () async {
    final saved = <TownState>[];
    final p = newProfile('Ana', 'guerrero');
    final net = LoopbackNetSession(LoopbackHub());
    await net.connect(SessionConfig(profile: p));
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(p),
      clock: const SessionClock(autoStart: false),
      net: net,
      world: WorldSave(
          id: 'w',
          name: 'W',
          label: WorldLabel.solitario,
          created: DateTime.utc(2026, 11, 1)),
      onWorldTown: (_, t) => saved.add(t),
    );
    await c.start();
    for (var i = 0; i < 4; i++) {
      c.advance(0.05);
      await pumpEventQueue();
    }
    // Sin editar, avanzar no escribe el pueblo.
    expect(saved, isEmpty);
    expect(c.enterTownEdit(), isTrue);
    c.advance(0.05);
    await pumpEventQueue();
    c.exitTownEdit();
    c.advance(0.05);
    await pumpEventQueue();
    expect(saved, hasLength(1), reason: 'guardado al salir de la edición');
    expect(c.saving, isTrue);
    expect(c.state!.saving, isTrue, reason: 'el HUD muestra el aviso');
    // Queda a la vista el mínimo y después se va.
    await Future<void>.delayed(
        SessionController.savingMinVisible + const Duration(milliseconds: 100));
    expect(c.saving, isFalse);
    c.dispose();
  });
}
