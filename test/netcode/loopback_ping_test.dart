import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:echos_del_tiempo/netcode/loopback/loopback_net_session.dart';
import 'package:echos_del_tiempo/netcode/protocol/wire.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game_engine/session_test_helpers.dart';

/// Ping / pong (docs/specs/netcode.md § "Ping") sobre loopback, con un
/// reloj falso por extremo.
void main() {
  late LoopbackHub hub;
  final opened = <NetSession>[];
  // Un reloj por sesión (cada extremo mide con el suyo).
  final clocks = <LoopbackNetSession, Duration>{};

  Future<LoopbackNetSession> open({
    String? code,
    String name = 'Host',
    Duration interval = const Duration(hours: 1), // los ping, a mano
  }) async {
    late LoopbackNetSession n;
    n = LoopbackNetSession(hub,
        clock: () => clocks[n] ?? Duration.zero, pingInterval: interval);
    clocks[n] = const Duration(seconds: 10);
    opened.add(n);
    await n.connect(SessionConfig(
        profile: newProfile(name, code == null ? 'guerrero' : 'maga'),
        roomCode: code));
    return n;
  }

  void tick(LoopbackNetSession n, int ms) =>
      clocks[n] = clocks[n]! + Duration(milliseconds: ms);

  setUp(() => hub = LoopbackHub());
  tearDown(() async {
    for (final n in opened) {
      await n.disconnect();
    }
    opened.clear();
    clocks.clear();
  });

  test('wire: ping y pong ida y vuelta', () {
    final codec = WireCodec();
    expect(codec.decode(codec.encode(const PingMessage(123456))),
        isA<PingMessage>().having((m) => m.ts, 'ts', 123456));
    expect(codec.decode(codec.encode(const PongMessage(42))),
        isA<PongMessage>().having((m) => m.ts, 'ts', 42));
    expect(codec.decode('{"t":"ping"}'), isNull);
  });

  test('cliente: ida y vuelta al host con su propio reloj; no son acciones',
      () async {
    final h = await open();
    final hostEvents = <NetEvent>[];
    h.events.listen(hostEvents.add);
    final a = await open(code: h.roomCode, name: 'Ana');
    expect(a.latency, isNull);
    final got = <NetLatency>[];
    final sub = a.latencyChanges.listen(got.add); // primer ping enseguida
    // El reloj del cliente avanza 23 ms hasta que vuelve el pong; el del
    // host no importa.
    tick(a, 23);
    clocks[h] = const Duration(days: 3);
    await pumpEventQueue();
    expect(got, hasLength(1));
    expect(a.latency!.rtt, const Duration(milliseconds: 23));
    expect(a.latency!.max, const Duration(milliseconds: 23));
    expect(a.latency!.isHost, isFalse);
    expect(a.latency!.peers, 1);

    a.pingNow();
    tick(a, 41);
    await pumpEventQueue();
    expect(a.latency!.rtt, const Duration(milliseconds: 41));
    expect(got, hasLength(2));

    // Nada de eso llegó como acción al host; una acción sí.
    expect(hostEvents.whereType<PeerActionEvent>(), isEmpty);
    a.sendAction(const ChatAction('hola'));
    await pumpEventQueue();
    expect(hostEvents.whereType<PeerActionEvent>(), hasLength(1));
    // El host contestó, pero no midió nada (nadie lo escucha).
    expect(h.latency, isNull);
    await sub.cancel();
  });

  test('host: promedio y peor de sus clientes; el que se va sale', () async {
    final h = await open();
    h.events.listen((_) {});
    final a = await open(code: h.roomCode, name: 'Ana');
    final sub = h.latencyChanges.listen((_) {}); // ping a Ana
    tick(h, 10);
    await pumpEventQueue();
    expect(h.latency!.rtt, const Duration(milliseconds: 10));
    expect(h.latency!.isHost, isTrue);
    expect(h.latency!.peers, 1);

    // Bea entra con el indicador prendido: el host la mide enseguida.
    final b = await open(code: h.roomCode, name: 'Bea');
    tick(h, 40);
    await pumpEventQueue();
    expect(h.latency!.peers, 2);
    expect(h.latency!.rtt, const Duration(milliseconds: 25));
    expect(h.latency!.max, const Duration(milliseconds: 40));

    // Bea se va: queda solo Ana.
    await b.disconnect();
    await pumpEventQueue();
    expect(h.latency!.peers, 1);
    expect(h.latency!.rtt, const Duration(milliseconds: 10));
    expect(a.latency, isNull, reason: 'el cliente no midió (sin oyente)');
    await sub.cancel();
  });

  test('agregación del host (pura)', () {
    final l = NetLatency.aggregate(isHost: true, rtts: const [
      Duration(milliseconds: 10),
      Duration(milliseconds: 20),
      Duration(milliseconds: 41),
    ]);
    expect(l.rtt!.inMicroseconds, 23667);
    expect(l.max, const Duration(milliseconds: 41));
    expect(l.peers, 3);
    final none = NetLatency.aggregate(isHost: true, rtts: const []);
    expect(none.rtt, isNull);
    expect(none.max, isNull);
    expect(none.peers, 0);
  });

  test('pong con ts del futuro o muy viejo se descarta', () async {
    final h = await open();
    final a = await open(code: h.roomCode, name: 'Ana');
    final sub = a.latencyChanges.listen((_) {});
    clocks[a] = const Duration(seconds: 5); // reloj "para atrás"
    await pumpEventQueue();
    expect(a.latency, isNull);
    a.pingNow();
    tick(a, 61000);
    await pumpEventQueue();
    expect(a.latency, isNull);
    await sub.cancel();
  });

  test('temporizador: mide cada pingInterval solo mientras alguien escucha',
      () async {
    final h = await open(interval: const Duration(milliseconds: 20));
    await open(code: h.roomCode, name: 'Ana');
    // Sin oyentes: nada.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(h.latency, isNull);
    final sub = h.latencyChanges.listen((_) {});
    tick(h, 5);
    await pumpEventQueue();
    expect(h.latency!.rtt, const Duration(milliseconds: 5));
    // El próximo tick (20 ms reales) vuelve a medir; el reloj falso está
    // quieto, así que esa ida y vuelta da 0.
    // Espera hasta 2 s (bajo carga los timers reales se atrasan).
    for (var i = 0; i < 100 && h.latency!.rtt != Duration.zero; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(h.latency!.rtt, Duration.zero);
    await sub.cancel();
    // Sin oyentes, el temporizador se apaga.
    final before = h.latency;
    tick(h, 100);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(h.latency, before);
  });
}
