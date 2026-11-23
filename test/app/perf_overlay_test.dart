import 'dart:async';

import 'package:echos_del_tiempo/app/theme/proto_colors.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/widgets/perf_overlay.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/netcode/contracts/net_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../real_fonts.dart';

/// Una sala falsa que mide ping (lo que le dice el test).
class _FakeNet implements NetSession, LatencyProbe {
  _FakeNet({required this.isHost});

  @override
  final bool isHost;

  final _out = StreamController<NetLatency>.broadcast();
  @override
  NetLatency? latency;

  void emit(NetLatency l) {
    latency = l;
    _out.add(l);
  }

  @override
  Stream<NetLatency> get latencyChanges => _out.stream;
  @override
  String get localId => isHost ? 'h' : 'p1';
  @override
  String? get roomCode => 'ABCDE';
  @override
  Stream<NetEvent> get events => const Stream.empty();
  @override
  Future<void> connect(SessionConfig config) async {}
  @override
  void sendAction(SessionAction action) {}
  @override
  void broadcast(GameSession state, List<SessionEvent> events,
      {Set<String>? only}) {}
  @override
  Future<void> disconnect() async => _out.close();
}

/// Una app con el indicador como `EcosApp` y un botón que cuenta clics
/// en cada esquina (para ver que el indicador no los tapa).
Future<
    ({
      GameSettingsController settings,
      ValueNotifier<double?> fps,
      List<int> clicks,
    })> _pump(
  WidgetTester tester, {
  GameSettings initial = const GameSettings(),
  NetSession? net,
  double? fps = 59.6,
}) async {
  await loadRealFonts(tester); // el tamaño de la caja, con los glifos reales
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = GameSettingsController(
      store: InMemoryGameSettingsStore(), initial: initial);
  final rate = ValueNotifier<double?>(fps);
  addTearDown(rate.dispose);
  final clicks = <int>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      gameSettingsProvider.overrideWith((ref) => settings),
      frameRateProvider.overrideWithValue(rate),
      if (net != null) activeNetSessionProvider.overrideWith((ref) => net),
    ],
    child: MaterialApp(
      theme: RetroTheme.build(),
      builder: (context, child) => PerfOverlay(child: child!),
      home: Scaffold(
        body: Stack(children: [
          for (final a in [Alignment.topRight, Alignment.bottomLeft])
            Align(
              alignment: a,
              child: GestureDetector(
                key: ValueKey('under-$a'),
                behavior: HitTestBehavior.opaque,
                onTap: () => clicks.add(1),
                child: const SizedBox(width: 200, height: 200),
              ),
            ),
        ]),
      ),
    ),
  ));
  await tester.pump();
  return (settings: settings, fps: rate, clicks: clicks);
}

Finder get _box => find.byKey(const ValueKey('perf-overlay'));

String _text(WidgetTester tester, String key) {
  final t = find.descendant(
      of: find.byKey(ValueKey(key)), matching: find.byType(Text));
  return tester.widget<Text>(t).data!;
}

int _barsOn(WidgetTester tester, String key) => [
      for (var i = 0; i < 3; i++)
        find
            .descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byKey(ValueKey('perf-bar-$i-on')))
            .evaluate()
            .length,
    ].fold(0, (a, b) => a + b);

void main() {
  test('textos y niveles (puros)', () {
    expect(PerfText.fps(59.6, null), '60 FPS');
    expect(PerfText.fps(59.6, 60), '60 FPS (máx 60)');
    expect(PerfText.fps(null, 30), '-- FPS (máx 30)');
    expect(PerfText.ping(null), 'ping --');
    expect(
        PerfText.ping(const NetLatency(
            isHost: false,
            rtt: Duration(milliseconds: 23),
            max: Duration(milliseconds: 23),
            peers: 1)),
        'ping 23 ms');
    expect(
        PerfText.ping(const NetLatency(
            isHost: true,
            rtt: Duration(milliseconds: 23),
            max: Duration(milliseconds: 41),
            peers: 2)),
        'ping 23 ms (máx 41)');
    expect(
        PerfText.ping(const NetLatency(
            isHost: true, rtt: null, max: null, peers: 0)),
        'ping --');
    expect(
        PerfText.ping(const NetLatency(
            isHost: false,
            rtt: Duration(microseconds: 300),
            max: Duration(microseconds: 300),
            peers: 1)),
        'ping <1 ms');
    expect(PerfLevel.ping(const Duration(milliseconds: 79)), PerfLevel.good);
    expect(PerfLevel.ping(const Duration(milliseconds: 80)), PerfLevel.medium);
    expect(PerfLevel.ping(const Duration(milliseconds: 150)), PerfLevel.bad);
    expect(PerfLevel.ping(null), PerfLevel.unknown);
    expect(PerfLevel.fps(58, 60), PerfLevel.good);
    expect(PerfLevel.fps(40, 60), PerfLevel.medium);
    expect(PerfLevel.fps(20, 60), PerfLevel.bad);
    expect(PerfLevel.fps(28, 30), PerfLevel.good);
    expect(PerfLevel.fps(144, null), PerfLevel.good);
    expect(PerfLevel.good.color, ProtoColors.green);
    expect(PerfLevel.bad.color, ProtoColors.red);
    expect([for (final l in PerfLevel.values) l.bars], [0, 1, 2, 3]);
  });

  testWidgets('apagado por defecto; se prende en vivo con el tope de FPS',
      (tester) async {
    final f = await _pump(tester);
    expect(_box, findsNothing);
    await f.settings.update(const GameSettings(perfOverlay: true));
    await tester.pump();
    expect(_box, findsOneWidget);
    expect(_text(tester, 'perf-fps'), '60 FPS (máx 60)');
    expect(_barsOn(tester, 'perf-fps'), 3);
    // Solo: no hay línea de ping.
    expect(find.byKey(const ValueKey('perf-ping')), findsNothing);
    // Sin tope y los FPS bajan: regular, 2 barras.
    await f.settings.update(const GameSettings(
        perfOverlay: true, fpsLimit: FpsLimit.none));
    f.fps.value = 41;
    await tester.pump();
    expect(_text(tester, 'perf-fps'), '41 FPS');
    expect(_barsOn(tester, 'perf-fps'), 2);
    await f.settings.update(const GameSettings());
    await tester.pump();
    expect(_box, findsNothing);
  });

  testWidgets('cada esquina, con margen; nunca tapa los clics',
      (tester) async {
    final f = await _pump(tester,
        initial: const GameSettings(perfOverlay: true));
    const screen = Size(1280, 720);
    for (final c in OverlayCorner.values) {
      await f.settings.update(GameSettings(perfOverlay: true, perfCorner: c));
      await tester.pump();
      final r = tester.getRect(_box);
      if (c.right) {
        expect(r.right, closeTo(screen.width - 8, 0.5), reason: '$c');
      } else {
        expect(r.left, closeTo(8, 0.5), reason: '$c');
      }
      // Una línea dentro de la franja libre de 16 px del borde (el HUD
      // del mapa empieza a 16 px: ≡ MENU, Sala: COPIAR, minimapa).
      expect(r.height, lessThanOrEqualTo(15), reason: '$c');
      if (c.top) {
        expect(r.top, closeTo(1, 0.5), reason: '$c');
      } else {
        expect(r.bottom, closeTo(screen.height - 1, 0.5), reason: '$c');
      }
      expect(r.width, lessThan(240), reason: 'chico');
    }
    // Encima de un botón: el clic pasa.
    await f.settings.update(const GameSettings(
        perfOverlay: true, perfCorner: OverlayCorner.topRight));
    await tester.pump();
    await tester.tapAt(tester.getCenter(_box));
    expect(f.clicks, [1]);
    await f.settings.update(const GameSettings(
        perfOverlay: true, perfCorner: OverlayCorner.bottomLeft));
    await tester.pump();
    await tester.tapAt(tester.getCenter(_box));
    expect(f.clicks, [1, 1]);
  });

  testWidgets('cliente en sala: ping al host con color y barras',
      (tester) async {
    final net = _FakeNet(isHost: false);
    await _pump(tester,
        net: net, initial: const GameSettings(perfOverlay: true));
    expect(_text(tester, 'perf-ping'), 'ping --');
    expect(_barsOn(tester, 'perf-ping'), 0);
    expect(net._out.hasListener, isTrue, reason: 'escucha la sala');
    net.emit(const NetLatency(
        isHost: false,
        rtt: Duration(milliseconds: 23),
        max: Duration(milliseconds: 23),
        peers: 1));
    // El evento del stream llega en el primer pump; se dibuja en el otro.
    await tester.pump();
    await tester.pump();
    expect(_text(tester, 'perf-ping'), 'ping 23 ms');
    expect(_barsOn(tester, 'perf-ping'), 3);
    net.emit(const NetLatency(
        isHost: false,
        rtt: Duration(milliseconds: 210),
        max: Duration(milliseconds: 210),
        peers: 1));
    await tester.pump();
    await tester.pump();
    expect(_text(tester, 'perf-ping'), 'ping 210 ms');
    expect(_barsOn(tester, 'perf-ping'), 1);
    final t = tester.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('perf-ping')),
        matching: find.byType(Text)));
    expect(t.style!.color, ProtoColors.red);
    expect(t.style!.fontWeight, isNot(FontWeight.bold));
  });

  testWidgets('host: promedio y máximo de los clientes', (tester) async {
    final net = _FakeNet(isHost: true)
      ..latency = const NetLatency(
          isHost: true,
          rtt: Duration(milliseconds: 23),
          max: Duration(milliseconds: 41),
          peers: 2);
    await _pump(tester,
        net: net, initial: const GameSettings(perfOverlay: true));
    expect(_text(tester, 'perf-ping'), 'ping 23 ms (máx 41)');
    expect(_barsOn(tester, 'perf-ping'), 3);
  });
}
