import 'dart:convert';

import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Perfiles solo cuando cambian (docs/specs/netcode.md § "Perfiles solo
/// cuando cambian", protocolo 11).
void main() {
  /// Perfil con el inventario lleno de armas épicas (lo que más pesa).
  PlayerProfile loaded(String name, String cls) {
    final bases = GameCatalog.standard.weapons.keys.toList();
    return newProfile(name, cls).copyWith(items: [
      for (var i = 0; i < 40; i++)
        ItemInstance(
            uid: '$name-$i',
            baseId: bases[i % bases.length],
            rarity: Rarity.epico,
            itemLevel: 30,
            name: 'Arma $i'),
    ]);
  }

  late LoopbackNetSession host;
  late List<LoopbackNetSession> clients;
  late List<List<GameSession>> got;
  late GameSession s;

  setUp(() async {
    final hub = LoopbackHub();
    host = LoopbackNetSession(hub);
    await host.connect(SessionConfig(profile: newProfile('Host', 'guerrero')));
    clients = [];
    got = [];
    for (final (n, c) in [('Ana', 'maga'), ('Bea', 'tirador')]) {
      final net = LoopbackNetSession(hub);
      await net.connect(
          SessionConfig(profile: newProfile(n, c), roomCode: host.roomCode));
      final mine = <GameSession>[];
      net.events.listen((e) {
        if (e is SnapshotEvent) mine.add(e.session);
      });
      clients.add(net);
      got.add(mine);
    }
    final e = sessionEngine();
    s = e.create();
    s = e.addPlayer(s, 'h', loaded('Host', 'guerrero'))!.state;
    s = e.addPlayer(s, 'p1', loaded('Ana', 'maga'))!.state;
    s = e.addPlayer(s, 'p2', loaded('Bea', 'tirador'))!.state;
  });

  tearDown(() async {
    for (final n in [...clients, host]) {
      await n.disconnect();
    }
  });

  Map<String, Object?> profilesOf(GameSession x) => {
        for (final p in x.playerList) p.id: jsonEncode(p.profile.toJson()),
      };

  test('el primero lleva todos; después solo el que cambió', () async {
    final full = WireCodec().encode(StateMessage(s, const [])).length;

    host.broadcast(s, const []);
    await pumpEventQueue();
    final first = host.lastStateBytes;
    expect(first, closeTo(full, full * 0.05), reason: 'primero: todo');

    // Se mueven, pasa el tiempo: los perfiles son los mismos.
    s.players['p1']!.x += 3;
    s.time += 1;
    host.broadcast(s, const []);
    await pumpEventQueue();
    final quiet = host.lastStateBytes;

    // Ana gasta créditos: solo viaja su perfil.
    final ana = s.players['p1']!;
    ana.profile = ana.profile.copyWith(credits: ana.profile.credits + 5);
    host.broadcast(s, const []);
    await pumpEventQueue();
    final oneChanged = host.lastStateBytes;

    // ignore: avoid_print
    print('state con 3 jugadores de 40 armas: antes $full B; '
        'ahora $quiet B sin cambios, $oneChanged B si cambia uno');
    expect(quiet, lessThan(full ~/ 4));
    expect(oneChanged, greaterThan(quiet));
    expect(oneChanged, lessThan(full * 0.6));

    // Los dos clientes ven exactamente los perfiles del host.
    for (final mine in got) {
      expect(mine, hasLength(3));
      expect(profilesOf(mine.last), profilesOf(s));
      expect(mine.last.players['p1']!.x, s.players['p1']!.x);
    }
  });

  test('un jugador nuevo: su perfil viaja; el que entra tarde recibe todos',
      () async {
    host.broadcast(s, const []);
    await pumpEventQueue();
    final quietBefore = host.lastStateBytes;
    expect(got.first.single.players.keys, ['h', 'p1', 'p2']);

    // Entra un tercer cliente con la sala andando.
    final cal = LoopbackNetSession(host.hub);
    await cal.connect(SessionConfig(
        profile: newProfile('Cal', 'paladin'), roomCode: host.roomCode));
    final calGot = <GameSession>[];
    cal.events.listen((e) {
      if (e is SnapshotEvent) calGot.add(e.session);
    });
    clients.add(cal);
    s = sessionEngine().addPlayer(s, 'p3', loaded('Cal', 'paladin'))!.state;
    host.broadcast(s, const []);
    await pumpEventQueue();
    // Cal recibió los 4; los demás, solo el de Cal.
    expect(profilesOf(calGot.single), profilesOf(s));
    expect(profilesOf(got.first.last), profilesOf(s));
    expect(host.lastStateBytes, greaterThan(quietBefore));
  });

  test('en una misión también baja (medición)', () async {
    final e = sessionEngine();
    var m = inField(e, 'm1', profiles: [
      loaded('Host', 'guerrero'),
      loaded('Ana', 'maga'),
      loaded('Bea', 'tirador'),
    ]);
    m = e.tick(m, 0.05).state;
    final full = WireCodec().encode(StateMessage(m, const [])).length;
    host.broadcast(m, const []);
    await pumpEventQueue();
    m = e.tick(m, 0.05).state;
    host.broadcast(m, const []);
    await pumpEventQueue();
    final quiet = host.lastStateBytes;
    // ignore: avoid_print
    print('misión con 3 jugadores de 40 armas: antes $full B; ahora $quiet B');
    expect(quiet, lessThan(full * 0.7));
  });

  test('sin un perfil conocido el state es inválido (no se adopta)', () {
    final codec = WireCodec();
    final body = codec.stateBody(s);
    final text = WireCodec.stateText(body, '[]', const {});
    expect(codec.decode(text, profiles: {}), isNull);
    final all = {
      for (final p in s.playerList) p.id: jsonEncode(p.profile.toJson()),
    };
    final ok = codec.decode(WireCodec.stateText(body, '[]', all),
        profiles: {}) as StateMessage;
    expect(profilesOf(ok.session), profilesOf(s));
  });
}
