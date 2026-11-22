import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/features/lobby/data/world_store.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';

/// Mundos por cuenta (town_loop.md § 11c, v0.21.0): lista, disco (solo
/// carpetas temporales), migración de un save viejo y la sala con el
/// mundo del anfitrión.
void main() {
  final t0 = DateTime.utc(2026, 11, 1);

  group('WorldBook', () {
    test('crear, renombrar, elegir, borrar y agrupar por etiqueta', () {
      var b = WorldBook()
          .create('  Claro  del   Eco ', WorldLabel.cooperativo,
              now: t0, id: 'a')
          .create('', WorldLabel.solitario,
              now: t0.add(const Duration(days: 1)), id: 'b');
      expect(b.worlds.map((w) => w.name), ['Claro del Eco', 'Mundo 2']);
      expect(b.selectedId, 'b', reason: 'el recién creado queda elegido');
      expect(b.grouped[WorldLabel.solitario]!.single.id, 'b');
      expect(b.grouped[WorldLabel.cooperativo]!.single.id, 'a');
      b = b.rename('b', 'Mi refugio').select('a');
      expect(b.byId('b')!.name, 'Mi refugio');
      expect(b.rename('b', '   ').byId('b')!.name, 'Mi refugio');
      expect(b.selected!.id, 'a');
      b = b.remove('a');
      expect(b.worlds.single.id, 'b');
      expect(b.selectedId, 'b', reason: 'borrar el elegido elige otro');
      // La etiqueta no bloquea: es solo un dato.
      expect(b.byId('b')!.label, WorldLabel.solitario);
    });

    test('ida y vuelta por JSON con el pueblo', () {
      final w = WorldSave(
          id: 'x',
          name: 'X',
          label: WorldLabel.solitario,
          created: t0,
          town: const TownState(
              upgrades: {'forja': 2},
              cycle: 3,
              lostLoot: [
                {'id': 7},
              ]));
      final r = WorldSave.fromJson(jsonDecode(jsonEncode(w.toJson())))!;
      expect(r.label, WorldLabel.solitario);
      expect(r.town.cycle, 3);
      expect(r.town.upgrades, {'forja': 2});
      expect(r.town.lostLoot.single['id'], 7);
      expect(r.created, t0);
      expect(WorldSave.fromJson({'nada': 1}), isNull);
    });
  });

  group('JsonFileWorldStore (carpeta temporal)', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('ecos_worlds_test');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('migración: un save viejo (sin mundos) arma el primero, Cooperativo',
        () async {
      // Fixture: la cuenta de antes de v0.21.0, sin carpeta accounts/.
      final account = File('${dir.path}${Platform.pathSeparator}account.json');
      const old = '{"v":3,"selected":"c1","characters":[{"id":"c1",'
          '"profile":{"name":"Ana","classId":"guerrero","level":7}}]}';
      await account.writeAsString(old);
      final store = JsonFileWorldStore(dir, now: () => t0, newId: (_) => 'w1');
      final b = await store.load();
      expect(b.worlds, hasLength(1));
      final w = b.selected!;
      expect(w.name, WorldBook.firstWorldName);
      expect(w.label, WorldLabel.cooperativo);
      expect(await store.worldFile('w1').exists(), isTrue);
      expect(
          store.worldFile('w1').path,
          endsWith(
              ['accounts', 'worlds', 'w1.json'].join(Platform.pathSeparator)));
      // La cuenta vieja no se toca (los personajes siguen donde estaban).
      expect(await account.readAsString(), old);
      // Leer otra vez no vuelve a migrar.
      final again = await JsonFileWorldStore(dir, newId: (_) => 'otro').load();
      expect(again.worlds.single.id, 'w1');
    });

    test('CRUD en disco: un archivo por mundo y el elegido', () async {
      final store = JsonFileWorldStore(dir, now: () => t0, newId: (_) => 'w1');
      var b = await store.load();
      b = b.create('Solo mío', WorldLabel.solitario,
          now: t0.add(const Duration(hours: 1)), id: 'w2');
      await store.save(b);
      expect(await store.worldFile('w2').exists(), isTrue);
      var r = await JsonFileWorldStore(dir).load();
      expect(r.worlds.map((w) => w.id), ['w1', 'w2']);
      expect(r.selectedId, 'w2');
      r = r.rename('w2', 'Refugio').remove('w1');
      await store.save(r);
      expect(await store.worldFile('w1').exists(), isFalse);
      final r2 = await JsonFileWorldStore(dir).load();
      expect(r2.worlds.single.name, 'Refugio');
      expect(r2.worlds.single.label, WorldLabel.solitario);
    });
  });

  group('sala', () {
    test('el cliente entra al mundo del anfitrión; el pueblo vuelve al host',
        () async {
      final hub = LoopbackHub();
      final saved = <String, TownState>{};
      final hostWorld = WorldSave(
          id: 'wh',
          name: 'Claro del Eco',
          label: WorldLabel.solitario,
          created: t0,
          town: const TownState(cycle: 4));
      final hp = newProfile('Ana', 'guerrero');
      final hn = LoopbackNetSession(hub);
      await hn.connect(SessionConfig(profile: hp));
      final host = SessionController(
        engine: sessionEngine(zones: true),
        store: InMemoryProfileStore(hp),
        clock: const SessionClock(autoStart: false),
        net: hn,
        world: hostWorld,
        onWorldTown: (id, t) => saved[id] = t,
      );
      await host.start();
      final cp = newProfile('Leo', 'tirador');
      final cn = LoopbackNetSession(hub);
      await cn.connect(SessionConfig(profile: cp, roomCode: hn.roomCode));
      // El cliente trae su propio mundo elegido: no cuenta en la sala.
      final client = SessionController(
        engine: sessionEngine(zones: true),
        store: InMemoryProfileStore(cp),
        clock: const SessionClock(autoStart: false),
        net: cn,
        world: WorldSave(
            id: 'wc', name: 'Otro', label: WorldLabel.cooperativo, created: t0),
        onWorldTown: (id, t) => saved[id] = t,
      );
      await client.start();
      for (var i = 0; i < 6; i++) {
        client.advance(0.05);
        await pumpEventQueue();
        host.advance(0.05);
        await pumpEventQueue();
      }
      expect(host.session!.worldId, 'wh');
      expect(client.session!.worldId, 'wh');
      expect(client.session!.worldName, 'Claro del Eco');
      expect(client.session!.players, hasLength(2));
      // En el JSON de la sala.
      final j = const SessionJson().toJson(host.session!);
      expect(j['wid'], 'wh');
      expect(
          const SessionJson()
              .fromJson(asJson(jsonDecode(jsonEncode(j))))
              .worldName,
          'Claro del Eco');
      client.dispose();
      host.dispose();
      expect(saved.keys, ['wh'], reason: 'solo el anfitrión guarda el pueblo');
      expect(saved['wh']!.cycle, 4);
    });

    test('jugando solo, un mundo Cooperativo se juega igual', () async {
      final p = newProfile('Ana', 'guerrero');
      final c = SessionController(
        engine: sessionEngine(zones: true),
        store: InMemoryProfileStore(p),
        clock: const SessionClock(autoStart: false),
        world: WorldSave(
            id: 'w1',
            name: 'Mi mundo',
            label: WorldLabel.cooperativo,
            created: t0),
      );
      await c.start();
      expect(c.session!.worldId, 'w1');
      expect(c.session!.mode, SessionMode.lobby);
      c.dispose();
    });
  });

  test('PlayerProfile sigue igual (los personajes no cambian)', () {
    expect(
        PlayerProfile(name: 'Ana', classId: 'guerrero')
            .toJson()
            .containsKey('world'),
        isFalse);
  });
}
