import 'package:echos_del_tiempo/features/world/presentation/world_strings.dart';
import 'package:echos_del_tiempo/app/design/design.dart';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/missions/domain/mission_text.dart';
import 'package:echos_del_tiempo/features/missions/presentation/mission_board_panel.dart';
import 'package:echos_del_tiempo/features/missions/presentation/results_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_themes.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/zone_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../app/square_ui_audit.dart';

const _cat = GameCatalog.standard;

/// Controlador local con el catálogo de zonas (sin timer).
Future<SessionController> _controller({int unlockedZone = 1}) async {
  final c = SessionController(
    engine: sessionEngine(zones: true),
    store: InMemoryProfileStore(zoneProgression.normalize(PlayerProfile(
        name: 'Ana', classId: 'guerrero', unlockedZone: unlockedZone))),
    clock: const SessionClock(autoStart: false),
  );
  await c.start();
  return c;
}

/// Propone la zona [zone] desde el tablero (v0.21.0: sin overworld).
bool _propose(SessionController c, int zone) {
  final ok = c.proposeMission(c.zoneStatus(zone)!.mission!.id);
  c.advance(0.05);
  return ok;
}

/// Elige la zona 1 en el tablero y la arranca (un jugador).
void _startZone1(SessionController c) {
  _propose(c, 1); // la votación de uno pasa sola
  expect(c.view!.mode, SessionMode.prep);
  c.setReady(true);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.field);
}

/// Junto a la escalera de bajada del piso actual (a 16 px: dentro del
/// alcance de E y fuera del de pisarla).
void _nearStairsDown(SessionController c) {
  final f = c.view!.map.floor(c.view!.session.mission!.floor)!;
  final d = f.stairsDown!;
  c.teleport(d.x, d.y + 16);
  c.advance(0.05);
}

void main() {
  group('tiles', () {
    Set<String> chars(GameMap m) => {for (final r in m.rows) ...r.split('')};

    test('el mundo y los pisos de las zonas 1-5 solo usan tiles conocidos', () {
      final all = <String>{...chars(MapGenerator.town())};
      for (final z in _cat.zones.where((z) => z.playable)) {
        for (final seed in [1, 777, 500000000]) {
          all.addAll(chars(MapGenerator.zone(z, seed)));
        }
      }
      expect(all.where((ch) => !TilePainter.handles(ch)), isEmpty);
      // Los códigos nuevos aparecen de verdad.
      for (final ch in [
        Tile.grass,
        Tile.tree,
        Tile.stairsDown,
        Tile.stairsUp,
        Tile.vaultFloor,
        Tile.fountain,
        Tile.fishing,
        Tile.sign,
      ]) {
        expect(all, contains(ch));
      }
    });

    test('cada código se dibuja en cada tema sin el magenta de desconocido',
        () {
      final codes = [
        '.', ',', '#', '~', 'G', 'C', 'A', 'M', 'g', 'T', '^', '>', '<', ':',
        'F', 'f', 'Y',
        for (var z = 0; z < 10; z++) '$z',
      ];
      final p = TilePainter();
      for (final theme in [
        'mundo', 'lobby', 'pueblo', 'pradera', 'bosque', 'ruinas', 'cavernas',
        'fortaleza', 'abismo',
      ]) {
        for (final ch in codes) {
          expect(TilePainter.handles(ch), isTrue, reason: ch);
          final rec = ui.PictureRecorder();
          p.draw(ui.Canvas(rec), ch, 0, 0, theme, 30, 20,
              t: 0, gateOpen: false, lobby: false);
          rec.endRecording().dispose();
        }
      }
      for (var z = 1; z <= 10; z++) {
        final rec = ui.PictureRecorder();
        p.entrance(ui.Canvas(rec), 8, 22, z, open: z < 3, t: 100);
        rec.endRecording().dispose();
      }
      expect(TilePainter.handles('?'), isFalse);
      expect(mapTheme('cavernas'), isNot(same(mapTheme('pradera'))));
      expect(inTown(25, 13), isTrue);
      expect(inTown(26, 13), isFalse);
    });
  });

  group('tablero = mapa de viaje (sin overworld)', () {
    late SessionController c;
    tearDown(() {
      if (c.mounted) c.dispose();
    });

    test('el pueblo no tiene entradas: la zona abierta sale del tablero',
        () async {
      c = await _controller();
      expect(c.view!.map.entrances, isEmpty);
      expect(c.mapAvailable, isFalse, reason: 'sin mapa del mundo en el pueblo');
      expect(c.zones, hasLength(10));
      expect(_propose(c, 1), isTrue);
      final s = c.view!.session;
      expect(s.vote?.missionId ?? s.prep?.missionId, 'm1');
    });

    test('bloqueada: el tablero dice por qué y no se propone', () async {
      c = await _controller();
      expect(c.zoneStatus(2)!.label,
          'Bloqueada: vencé a Rey Limo en Pradera Esmeralda');
      expect(_propose(c, 2), isFalse);
      expect(c.view!.session.vote, isNull);
      expect(c.view!.mode, SessionMode.lobby);
      expect(c.zoneStatus(10)!.label,
          contains('Bloqueada: vencé a Centinela del Vacío'));
    });

    test('con todo desbloqueado, el tablero propone z10', () async {
      c = await _controller(unlockedZone: 10);
      expect(_propose(c, 10), isTrue);
      final s = c.view!.session;
      expect(s.vote?.missionId ?? s.prep?.missionId, 'z10');
    });
  });

  group('pisos', () {
    late SessionController c;
    tearDown(() {
      if (c.mounted) c.dispose();
    });

    test('escalera: aviso [E] Bajar al piso 2 y E cambia de piso', () async {
      c = await _controller();
      final events = <SessionEvent>[];
      c.events.listen(events.add);
      _startZone1(c);
      final m = c.view!.session.mission!;
      expect(m.floors, 2);
      expect(m.floor, 0);
      _nearStairsDown(c);
      expect(c.view!.prompt, WorldPrompt.stairs);
      expect(c.view!.promptLabel, '[E] Bajar al piso 2');
      c.handleKey(LogicalKeyboardKey.keyE);
      await pumpEventQueue();
      expect(c.view!.session.mission!.floor, 1);
      expect(events.whereType<FloorChangedEvent>(), isNotEmpty);
      // Llegó al spawn del piso 2: el jugador local adopta la posición.
      final f1 = c.view!.map.floor(1)!;
      expect(f1.containsTile((c.local.x / 16).floor(), (c.local.y / 16).floor()),
          isTrue);

      // Subir con E desde la `<`.
      final up = f1.stairsUp!;
      c.teleport(up.x, up.y + 16);
      c.advance(0.05);
      expect(c.view!.promptLabel, '[E] Subir al piso 1');
      c.handleKey(LogicalKeyboardKey.keyE);
      expect(c.view!.session.mission!.floor, 0);
    });

    testWidgets('HUD: piso, aviso de jefe y minimapa del piso',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      c = await _controller();
      _startZone1(c);
      Future<void> pumpHud() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
            profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
            sessionClockProvider
                .overrideWithValue(const SessionClock(autoStart: false)),
          ],
          child: MaterialApp(
            theme: RetroTheme.build(),
            home: Scaffold(body: WorldHud(view: c.view!, controller: c)),
          ),
        ));
      }

      await pumpHud();
      expect(roundedUi(tester), isEmpty, reason: 'regla pixel: sin redondeos');
      final lv = ZoneRules.floorLevel(_cat.zone(1)!, 0);
      expect(find.text('Pradera Esmeralda · Piso 1/2 · Lv $lv'), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-boss-floor')), findsNothing);
      expect(find.textContaining('Escalera: despejá el piso'), findsOneWidget);
      expect(find.textContaining('Pradera Esmeralda · Piso 1/2 ·'),
          findsWidgets); // también en la barra de misión

      _nearStairsDown(c);
      c.handleKey(LogicalKeyboardKey.keyE);
      await pumpHud();
      expect(find.textContaining('Pradera Esmeralda · Piso 2/2'), findsWidgets);
      expect(find.text('¡Piso del JEFE!'), findsOneWidget);
      c.dispose();
    });

    testWidgets('mapa: fundido al cambiar de piso y cámara dentro del piso',
        (tester) async {
      late GameSprites sprites;
      await tester.runAsync(() async {
        sprites = await GameSprites.load(await SpriteCatalog.load());
      });
      c = await _controller();
      _startZone1(c);
      final game = MapGame(
          controller: c, sprites: sprites, input: () => (0.0, 0.0));
      game.update(0.016);
      expect(game.fading, isFalse);
      _nearStairsDown(c);
      c.handleKey(LogicalKeyboardKey.keyE);
      await tester.pump();
      expect(game.fading, isTrue);
      for (var i = 0; i < 60; i++) {
        game.update(0.05);
      }
      expect(game.fading, isFalse);
      final b = c.view!.map.floor(1)!.bounds;
      expect(game.camX, greaterThanOrEqualTo(b.x * 16.0 - 1));
      expect(game.camX + MapGame.vw, lessThanOrEqualTo((b.x + b.w) * 16.0 + 1));
      // Dibuja el piso sin errores.
      final rec = ui.PictureRecorder();
      game.drawWorld(ui.Canvas(rec), c.view!);
      rec.endRecording().dispose();
      c.dispose();
    });
  });

  group('mostrador y resultado', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(child: MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(body: child),
      )));
      await tester.pump();
    }

    testWidgets('zonas: línea de zona y bloqueadas con motivo',
        (tester) async {
      final zones = ZoneRules.zoneList(
          _cat, PlayerProfile(name: 'A', classId: 'guerrero'));
      String? proposed;
      await pump(
          tester,
          MissionBoardPanel(
            missions: _cat.missions,
            zones: zones,
            voteOpen: false,
            bossName: (m) => missionBossName(worldFallbackStrings(), _cat, m),
            onPropose: (id) => proposed = id,
            onClose: () {},
          ));
      expect(find.textContaining('Zona 1 · Pradera Esmeralda · Lv 1-5 · 2 pisos'),
          findsOneWidget);
      expect(find.textContaining('Derrota 4 grupos por piso (2 pisos)'),
          findsOneWidget);
      // Lista + detalle: la zona 2 (bloqueada) muestra su motivo al elegirla.
      await tester.tap(find.byKey(const ValueKey('mission-z2')));
      await tester.pump();
      expect(find.textContaining('Bloqueada: vencé a Rey Limo en Pradera'),
          findsOneWidget);
      final z2 = tester.widget<DsButton>(find.byKey(const ValueKey('propose-z2')));
      expect(z2.tooltip, 'Bloqueada');
      // v0.3.0: las 10 zonas tienen tarjeta (worldgen.md § 9.4).
      for (var i = 6; i <= 10; i++) {
        expect(find.byKey(ValueKey('zone-soon-$i')), findsNothing);
      }
      expect(find.textContaining('Próximamente'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('mission-m1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('propose-m1')));
      expect(proposed, 'm1');
    });

    testWidgets('resultado: progreso de la zona y ¡Zona N desbloqueada!',
        (tester) async {
      await pump(
          tester,
          ResultsPanel(
            result: MissionResult(
              id: 1,
              missionId: 'm1',
              missionName: 'Pradera Esmeralda',
              success: true,
              rank: MissionRank.s,
              time: 100,
              xp: 10,
              credits: 10,
              bonus: 5,
              bonusPercent: 0.5,
              kos: 0,
              elites: 0,
              eliteDrops: const [],
              drops: const {},
              zone: 1,
              unlocked: const {'p0': 2, 'p1': 2},
            ),
            localId: 'p0',
            playerName: (id) => id == 'p1' ? 'Bo' : 'Ana',
            weaponName: (id) => id,
            onBack: () {},
            zoneProgress: 'Zona 1 · Pradera Esmeralda · Piso 2/2',
            unlocked: zoneUnlockedText(worldFallbackStrings(), 2, _cat.zone(2)!.name),
            othersUnlocked: 'También desbloquearon · Bo: Zona 2',
          ));
      expect(find.text('Zona 1 · Pradera Esmeralda · Piso 2/2'), findsOneWidget);
      expect(find.text('¡Zona 2 desbloqueada! Bosque Hondo'), findsOneWidget);
      expect(find.textContaining('Bo: Zona 2'), findsOneWidget);
    });
  });

  test('textos de piso', () {
    expect(floorLabelText(worldFallbackStrings(), 'Bosque Hondo', 1, 3), 'Bosque Hondo · Piso 2/3');
    expect(zoneLineText(worldFallbackStrings(), _cat.zone(5)!),
        startsWith('Zona 5 · Fortaleza Caída · Lv 21-25 · 3 pisos · Jefe: '));
  });
}
