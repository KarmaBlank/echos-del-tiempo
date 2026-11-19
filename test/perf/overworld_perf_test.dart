import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/core/perf/frame_stats.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_cache.dart';
import 'package:flame/game.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/loot.dart';
import 'package:echos_del_tiempo/game_engine/models/party_store.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../game_engine/session_test_helpers.dart';
import '../real_fonts.dart';

/// Arnés de rendimiento del overworld (docs/specs/exploration.md §
/// "Rendimiento"): `WorldScreen` real dentro de `EcosApp` (ALTO
/// CONTRASTE, CRT FUERTE, partículas ALTAS: los ajustes por defecto),
/// party de 4 en la zona 1, loot con etiquetas en el piso. Mide en CPU
/// (modo JIT de los tests: sirve para comparar antes / después, no como
/// número absoluto) el `render` del mapa, el cuadro entero (`pump`) y
/// cuántos widgets se reconstruyen, quieto y caminando hacia zonas que
/// todavía no estaban en pantalla.
///
/// `flutter test test/perf/overworld_perf_test.dart` imprime la tabla.

/// Los widgets del HUD que se cuentan aparte.
const _hudTypes = {
  'WorldHud',
  'CompactPlayerBox',
  '_PlayerBox',
  'Minimap',
  'ChatBox',
  '_MissionBar',
  '_Objectives',
  'PartyBox',
};

class _Phase {
  _Phase(this.name);
  final String name;
  final render = <int>[];
  final pump = <int>[];
  int frames = 0, rebuilds = 0;
  final hud = <String, int>{};
  final all = <String, int>{};

  String report() {
    final r = FrameStats(render), p = FrameStats(pump);
    String perFrame(Map<String, int> m, {int? top}) {
      final l = m.entries.toList()
        ..sort((a, b) =>
            top == null ? a.key.compareTo(b.key) : b.value.compareTo(a.value));
      return l
          .take(top ?? l.length)
          .map((e) => '${e.key} ${(e.value / frames).toStringAsFixed(2)}')
          .join(', ');
    }

    return '[$name] $frames cuadros\n'
        '  render del mapa: ${r.summary} (media ${r.mean.toStringAsFixed(2)})\n'
        '  cuadro (pump):   ${p.summary} (media ${p.mean.toStringAsFixed(2)})\n'
        '  reconstrucciones/cuadro: ${(rebuilds / frames).toStringAsFixed(1)}'
        ' · HUD: ${perFrame(hud)}\n'
        '  más reconstruidos: ${perFrame(all, top: 12)}';
  }
}

GameSprites? _sprites;

/// Entra a la zona 1 con Ana + Leo, Mia y Cid.
Future<SessionController> pumpField(WidgetTester tester,
    {MoveInputReader? input}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (_sprites == null) {
    await tester.runAsync(() async {
      _sprites = await GameSprites.load(await SpriteCatalog.load());
    });
  }
  final g = GameSettingsController(
      store: InMemoryGameSettingsStore(), initial: const GameSettings());
  await tester.pumpWidget(EcosApp(
    overrides: [
      sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore(
          zoneProgression.normalize(PlayerProfile(
              name: 'Ana', classId: 'guerrero', unlockedZone: 1)))),
      partyStoreProvider.overrideWithValue(InMemoryPartyStore(slots: {
        's2': zoneProgression
            .normalize(PlayerProfile(name: 'Leo', classId: 'maga')),
        's3': zoneProgression
            .normalize(PlayerProfile(name: 'Mia', classId: 'tirador')),
        's4': zoneProgression
            .normalize(PlayerProfile(name: 'Cid', classId: 'paladin')),
      }, party: const [
        's2',
        's3',
        's4'
      ])),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
      gameSpritesProvider.overrideWith((ref) => _sprites!),
      gameSettingsProvider.overrideWith((ref) => g),
    ],
    home: WorldScreen(moveInput: input),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final container =
      ProviderScope.containerOf(tester.element(find.byType(WorldScreen)));
  final c = container.read(sessionControllerProvider.notifier);
  final e = c.view!.map.entrances.firstWhere((e) => e.zone == 1);
  c.teleport(e.front.x, e.front.y);
  c.advance(0.05);
  c.handleKey(LogicalKeyboardKey.keyE);
  c.advance(0.05);
  c.setReady(true);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.field);
  expect(c.view!.session.playerList.length, 4);
  // Sin batallas en la medición: los grupos se quedan lejos.
  c.session!.mission!.enemies.removeWhere((en) => !en.boss && !en.elite);
  // Loot con etiqueta alrededor del jugador.
  final s = c.session!;
  for (var i = 0; i < 10; i++) {
    s.ground.add(GroundLoot(
        id: 9000 + i,
        drop: LootDrop.stack(
            StackKind.values[i % StackKind.values.length], i + 1),
        x: c.local.x + (i % 5) * 26 - 52,
        y: c.local.y + (i ~/ 5) * 30 + 30,
        floor: s.mission!.floor));
  }
  c.advance(0.05);
  await tester.pump();
  return c;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('overworld: perfil de cuadros (quieto y caminando)',
      (tester) async {
    var dir = (0.0, 0.0);
    final c = await pumpField(tester, input: () => dir);
    addTearDown(() {
      MapGame.debugRenderTiming = null;
      debugOnRebuildDirtyWidget = null;
    });

    _Phase? phase;
    MapGame.debugRenderTiming = (us) => phase?.render.add(us);
    debugOnRebuildDirtyWidget = (e, _) {
      final p = phase;
      if (p == null) return;
      p.rebuilds++;
      final n = e.widget.runtimeType.toString();
      if (_hudTypes.contains(n)) p.hud[n] = (p.hud[n] ?? 0) + 1;
      p.all[n] = (p.all[n] ?? 0) + 1;
    };

    Future<void> run(
        _Phase p, int frames, (double, double) Function(int i) input) async {
      phase = p;
      for (var i = 0; i < frames; i++) {
        dir = input(i);
        // Host a 20 Hz (cada 3 cuadros de 60 Hz), como el timer real.
        if (i % 3 == 0) c.advance(0.05);
        final sw = Stopwatch()..start();
        await tester.pump(const Duration(microseconds: 16667));
        p.pump.add(sw.elapsedMicroseconds);
        p.frames++;
      }
      phase = null;
    }

    final game = tester
        .widget<GameWidget>(find.byWidgetPredicate((w) => w is GameWidget))
        .game as MapGame;
    final out = StringBuffer('\n=== Overworld ===\n');
    final start = (c.local.x, c.local.y);
    for (final cached in [false, true]) {
      // Sin caché = el dibujo directo de antes (tile por tile).
      game.tileLayer
        ..dispose()
        ..animatedShareLimit = cached ? TileLayerCache.maxAnimatedShare : -1;
      c.teleport(start.$1, start.$2);
      final tag = cached ? 'con caché' : 'sin caché';
      await run(_Phase('calentamiento'), 60, (_) => (0, 0));
      final idle = _Phase('quieto, $tag');
      await run(idle, 240, (_) => (0, 0));
      final walk = _Phase('caminando (zonas nuevas), $tag');
      final from = (c.local.x, c.local.y);
      // Un rectángulo grande: derecha, abajo, izquierda, arriba.
      await run(
          walk,
          480,
          (i) => switch ((i ~/ 120) % 4) {
                0 => (1.0, 0.0),
                1 => (0.0, 1.0),
                2 => (-1.0, 0.0),
                _ => (0.0, -1.0),
              });
      out
        ..writeln(idle.report())
        ..writeln(walk.report())
        ..writeln('  caminó ${(c.local.x - from.$1).abs().round()} / '
            '${(c.local.y - from.$2).abs().round()} px al final; '
            'bloques grabados ${game.tileLayer.built}, reutilizados '
            '${game.tileLayer.hits}, directo ${game.tileLayer.direct}');
    }
    expect(c.view!.mode, SessionMode.field);
    // ignore: avoid_print
    print(out);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el HUD no reconstruye lo que no cambió en cada tick',
      (tester) async {
    final c = await pumpField(tester);
    // Quieto en el campo: la vista cambia en cada tick (reloj, etc.).
    for (var i = 0; i < 5; i++) {
      c.advance(0.05);
      await tester.pump(const Duration(milliseconds: 50));
    }
    final counts = <String, int>{};
    debugOnRebuildDirtyWidget = (e, _) {
      final n = e.widget.runtimeType.toString();
      counts[n] = (counts[n] ?? 0) + 1;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    const ticks = 20;
    for (var i = 0; i < ticks; i++) {
      c.advance(0.05);
      await tester.pump(const Duration(milliseconds: 50));
    }
    // El HUD sí se arma (vista nueva) ...
    expect(counts['WorldHud'], ticks);
    // ... pero las cajas del grupo, el chat, los botones y los avisos no.
    for (final w in [
      'CompactPlayerBox',
      'PartyBox',
      'ChatBox',
      'LootLog',
      'LootToasts',
      'BuildToasts',
      'UnusedPointsToast',
      'PauseMenuButton',
    ]) {
      expect(counts[w] ?? 0, 0, reason: w);
    }
    // La barra de misión solo cuando cambia el texto (el reloj, por
    // segundo): 20 ticks = 1 s → a lo sumo 2.
    expect(counts['_MissionBar'] ?? 0, lessThanOrEqualTo(2));

    // Cambia el HP de un compañero: solo SU caja.
    counts.clear();
    final mate =
        c.session!.playerList.firstWhere((p) => p.id != c.view!.localId);
    mate.hp = (mate.maxHp / 2).floorToDouble();
    c.advance(0.05);
    await tester.pump(const Duration(milliseconds: 50));
    expect(counts['CompactPlayerBox'], 1);
    final hp = c.session!.players[mate.id]!.hp;
    expect(
        tester
            .widget<Text>(find.byKey(ValueKey('hud-hp-${mate.id}')))
            .data,
        startsWith('${hp.ceil()}/'));

    // Llega un mensaje de chat: el chat se arma, las cajas no.
    counts.clear();
    c.addLocalNotice('Hola');
    await tester.pump(const Duration(milliseconds: 50));
    expect(counts['ChatBox'], 1);
    expect(counts['CompactPlayerBox'] ?? 0, 0);
    debugOnRebuildDirtyWidget = null;
    // Sin avisos pendientes al terminar.
    await tester.pump(const Duration(seconds: 30));
  });
}
