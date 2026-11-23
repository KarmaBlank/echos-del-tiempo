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

  test('el pueblo que cambia solo (cielo, ayudantes) no se guarda a cada rato',
      () async {
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
    for (var i = 0; i < 40; i++) {
      c.advance(0.1);
      await pumpEventQueue();
    }
    await Future<void>.delayed(
        SessionController.townSaveDelay + const Duration(milliseconds: 300));
    c.advance(0.1);
    await pumpEventQueue();
    expect(saved, isEmpty, reason: 'sin editar, mismo día: no escribe');
    expect(c.saving, isFalse, reason: 'sin aviso de guardado');
    c.dispose();
  });

  group('política de guardado del perfil (save_indicator.md § 1)', () {
    late InMemoryProfileStore store;
    late SessionController c;

    Future<void> step([double dt = 0.05]) async {
      c.advance(dt);
      await pumpEventQueue();
    }

    setUp(() async {
      final p = newProfile('Ana', 'guerrero');
      store = InMemoryProfileStore(p);
      final net = LoopbackNetSession(LoopbackHub());
      await net.connect(SessionConfig(profile: p));
      c = SessionController(
        engine: sessionEngine(zones: true),
        store: store,
        clock: const SessionClock(autoStart: false),
        net: net,
        world: WorldSave(
            id: 'w',
            name: 'W',
            label: WorldLabel.solitario,
            created: DateTime.utc(2026, 11, 1)),
        onWorldTown: (a, b) {},
      );
      await c.start();
      await step();
    });
    tearDown(() => c.dispose());

    void touch(int credits) {
      final me = c.session!.players[c.localId]!;
      me.profile = me.profile.copyWith(credits: credits);
    }

    test('jugando dentro del mismo día no se guarda', () async {
      touch(4321);
      for (var i = 0; i < 60; i++) {
        touch(4321);
        await step(0.1);
      }
      expect((await store.load())!.credits, isNot(4321));
    });

    test('al cambiar de día se guarda con aviso', () async {
      // El cielo arranca en el día 0 y pasa al 1 enseguida.
      while (c.session!.town.sky.day < 1) {
        await step();
      }
      final day = c.session!.town.sky.day;
      for (var i = 0; i < 100000 && c.session!.town.sky.day == day; i++) {
        touch(4321);
        await step(1);
      }
      await step();
      expect(c.session!.town.sky.day, isNot(day));
      expect((await store.load())!.credits, 4321);
      expect(c.saving, isTrue);
    });

    test('al cerrar un menú se guarda lo hecho con él abierto', () async {
      c.toggleInventory();
      await step();
      touch(4321);
      await step();
      expect((await store.load())!.credits, isNot(4321), reason: 'dentro no guarda');
      c.toggleInventory();
      await step();
      await step();
      expect((await store.load())!.credits, 4321);
      expect(c.saving, isTrue);
    });
  });
}
