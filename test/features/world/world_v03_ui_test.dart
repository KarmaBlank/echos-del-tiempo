import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_text.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/missions/domain/mission_text.dart';
import 'package:echos_del_tiempo/features/missions/presentation/mission_board_panel.dart';
import 'package:echos_del_tiempo/features/missions/presentation/results_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/minimap.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_game.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/map_themes.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/void_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/zone_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

const _cat = GameCatalog.standard;

/// Pruebas de la UI del mundo de la v0.3.0 (zonas 6–10). Ver
/// docs/specs/exploration.md § "Zonas 6–10".

const _newCodes = [
  Tile.voidTile,
  Tile.bridge,
  Tile.lava,
  Tile.tombstone,
  Tile.gear,
];

const _newThemes = ['laberinto', 'grieta', 'cementerio', 'abismo', 'corazon'];

/// Píxeles magenta (`#ff00ff`, tile desconocido) en [img].
Future<int> _magenta(ui.Image img) async {
  final data = await img.toByteData();
  final b = data!.buffer.asUint8List();
  var n = 0;
  for (var i = 0; i < b.length; i += 4) {
    if (b[i] == 255 && b[i + 1] == 0 && b[i + 2] == 255 && b[i + 3] == 255) {
      n++;
    }
  }
  return n;
}

Future<SessionController> _controller(int unlockedZone) async {
  final c = SessionController(
    engine: sessionEngine(zones: true),
    store: InMemoryProfileStore(zoneProgression.normalize(PlayerProfile(
        name: 'Ana', classId: 'guerrero', unlockedZone: unlockedZone))),
    clock: const SessionClock(autoStart: false),
  );
  await c.start();
  return c;
}

/// Entra a la zona [zone] por su puerta y la arranca (un jugador).
void _startZone(SessionController c, int zone) {
  final e = c.view!.map.entrances.firstWhere((e) => e.zone == zone);
  c.teleport(e.front.x, e.front.y);
  c.advance(0.05);
  c.handleKey(LogicalKeyboardKey.keyE);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.prep);
  c.setReady(true);
  c.advance(0.05);
  expect(c.view!.mode, SessionMode.field);
}

void main() {
  group('tiles v0.3', () {
    Set<String> chars(GameMap m) => {for (final r in m.rows) ...r.split('')};

    test('los atlas de las zonas 6-10 (3 semillas) solo usan tiles conocidos',
        () {
      final all = <String>{};
      for (var z = 6; z <= 10; z++) {
        final zone = _cat.zone(z)!;
        expect(zone.playable, isTrue, reason: 'zona $z');
        for (final seed in [1, 777, 500000000]) {
          final m = MapGenerator.zone(zone, seed);
          expect(m.theme, zone.theme);
          final cs = chars(m);
          expect(cs.where((ch) => !TilePainter.handles(ch)), isEmpty,
              reason: 'zona $z semilla $seed');
          all.addAll(cs);
        }
      }
      for (final ch in [
        Tile.voidTile,
        Tile.bridge,
        Tile.lava,
        Tile.tombstone
      ]) {
        expect(all, contains(ch));
      }
      for (final ch in _newCodes) {
        expect(TilePainter.handles(ch), isTrue, reason: ch);
      }
    });

    testWidgets('cada código nuevo en cada tema nuevo, sin magenta',
        (tester) async {
      final p = TilePainter();
      // Vecindarios: aislado, con vacío arriba/abajo y con lava al lado.
      final hoods = <TileAt?>[
        null,
        (x, y) => y < 20 ? Tile.voidTile : Tile.floor,
        (x, y) => x < 30 ? Tile.lava : Tile.voidTile,
        (x, y) => Tile.voidTile,
      ];
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      var col = 0.0;
      for (final theme in [..._newThemes, 'mundo', 'pradera']) {
        for (final ch in [..._newCodes, '.', ',', '#', ':', '>', '<', 'G']) {
          for (final at in hoods) {
            for (final t in [0.0, 777.0]) {
              p.draw(c, ch, col % 640, (col ~/ 640) * 16, theme, 30, 20,
                  t: t,
                  gateOpen: false,
                  lobby: false,
                  at: at,
                  voidBackdrop: t > 0,
                  density: t > 0 ? 0.3 : 1);
              col += 16;
            }
          }
        }
      }
      VoidPainter().draw(c, 'abismo', 480, 288, camX: 100, camY: 50, t: 500);
      final pic = rec.endRecording();
      await tester.runAsync(() async {
        final img = await pic.toImage(640, (col ~/ 640 + 1).toInt() * 16);
        expect(await _magenta(img), 0);
        img.dispose();
      });
      pic.dispose();
    });

    testWidgets('pisos enteros de las zonas 6-10 sin magenta', (tester) async {
      final p = TilePainter();
      for (var z = 6; z <= 10; z++) {
        final m = MapGenerator.zone(_cat.zone(z)!, 1);
        final b = m.floor(0)!.bounds;
        String? at(int x, int y) => m.contains(x, y) ? m.tileAt(x, y) : null;
        final rec = ui.PictureRecorder();
        final c = ui.Canvas(rec);
        for (var y = b.y; y < b.y + b.h; y++) {
          for (var x = b.x; x < b.x + b.w; x++) {
            p.draw(c, m.tileAt(x, y), (x - b.x) * 16.0, (y - b.y) * 16.0,
                m.theme, x, y,
                t: 1234, gateOpen: false, lobby: false, at: at);
          }
        }
        final pic = rec.endRecording();
        await tester.runAsync(() async {
          final img = await pic.toImage(b.w * 16, b.h * 16);
          expect(await _magenta(img), 0, reason: 'zona $z');
          img.dispose();
        });
        pic.dispose();
      }
    });

    test('minimapa: vacío, puente, lava, lápida y engranaje con su color', () {
      expect(minimapTileColor(Tile.voidTile), kMinimapVoid);
      expect(minimapTileColor(Tile.voidTile), kMapBackground);
      expect(minimapTileColor(Tile.bridge), const Color(0xFFA07A44));
      expect(minimapTileColor(Tile.lava), const Color(0xFFFF5A1F));
      expect(minimapTileColor(Tile.tombstone), const Color(0xFF6C707A));
      expect(minimapTileColor(Tile.gear), const Color(0xFFB08A3A));
      final floor = minimapTileColor(Tile.floor);
      final colors = {for (final ch in _newCodes) minimapTileColor(ch)};
      expect(colors, hasLength(_newCodes.length));
      expect(colors, isNot(contains(floor)));
    });

    test('temas nuevos definidos; los de abismo marcados', () {
      for (final t in _newThemes) {
        expect(kMapThemes.containsKey(t), isTrue, reason: t);
      }
      expect(kAbyssThemes, {'abismo', 'cementerio', 'corazon'});
      for (var z = 6; z <= 10; z++) {
        expect(kMapThemes.containsKey(_cat.zone(z)!.theme), isTrue);
      }
    });
  });

  group('caída al vacío', () {
    testWidgets(
        'el jugador local cae: se achica, aparece en la llegada y '
        've el cartel; el chat tiene el mensaje', (tester) async {
      late GameSprites sprites;
      await tester.runAsync(() async {
        sprites = await GameSprites.load(await SpriteCatalog.load());
      });
      final c = await _controller(10);
      _startZone(c, 9);
      final game =
          MapGame(controller: c, sprites: sprites, input: () => (0.0, 0.0));
      final view = c.view!;
      final f = view.map.floor(view.session.mission!.floor)!;
      // Un tile de vacío del piso actual.
      (int, int)? hole;
      for (var y = f.bounds.y + 1; y < f.bounds.y + f.bounds.h - 1; y++) {
        for (var x = f.bounds.x + 1; x < f.bounds.x + f.bounds.w - 1; x++) {
          if (view.map.tileAt(x, y) == Tile.voidTile) {
            hole = (x, y);
            break;
          }
        }
        if (hole != null) break;
      }
      expect(hole, isNotNull);
      final hx = hole!.$1 * 16.0 + 8, hy = hole.$2 * 16.0 + 8;
      game.update(0.016);
      c.teleport(hx, hy);
      game.drawWorld(ui.Canvas(ui.PictureRecorder()), c.view!);
      expect(game.fallProgress(c.localId), isNull);
      c.advance(0.05);
      await tester.pump();
      // El host lo llevó a la llegada del piso.
      final me = c.view!.me!;
      expect((me.x - f.spawn.x).abs() + (me.y - f.spawn.y).abs(), lessThan(48));
      expect(c.view!.chat.map((l) => l.text), contains('Ana cayó al vacío.'));
      // La animación arrancó donde cayó.
      expect(game.fallProgress(c.localId), isNotNull);
      expect(game.fallOrigin(c.localId), (hx, hy));
      expect(game.showingFallToast, isTrue);
      // Se dibuja en las dos mitades sin errores.
      for (final dt in [0.1, 0.3, 0.2]) {
        game.update(dt);
        final rec = ui.PictureRecorder();
        game.drawWorld(ui.Canvas(rec), c.view!);
        rec.endRecording().dispose();
      }
      game.update(0.4);
      expect(game.fallProgress(c.localId), isNull);
      expect(game.showingFallToast, isTrue);
      game.update(1.2);
      expect(game.showingFallToast, isFalse);
      c.dispose();
    });

    testWidgets('otro jugador cae: animación sin cartel propio',
        (tester) async {
      late GameSprites sprites;
      await tester.runAsync(() async {
        sprites = await GameSprites.load(await SpriteCatalog.load());
      });
      final c = await _controller(10);
      _startZone(c, 9);
      final game =
          MapGame(controller: c, sprites: sprites, input: () => (0.0, 0.0));
      game.startFall('otro');
      expect(game.fallProgress('otro'), isNotNull);
      expect(game.showingFallToast, isFalse);
      c.dispose();
    });
  });

  group('mostrador y resultado v0.3', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(body: child),
      ));
      await tester.pump();
    }

    testWidgets('tarjetas z6..z10 con línea de zona; abiertas hasta la 10',
        (tester) async {
      final zones = ZoneRules.zoneList(
          _cat, PlayerProfile(name: 'A', classId: 'guerrero', unlockedZone: 8));
      await pump(
          tester,
          MissionBoardPanel(
            missions: _cat.missions,
            zones: zones,
            voteOpen: false,
            bossName: (m) => missionBossName(_cat, m),
            onPropose: (_) {},
            onClose: () {},
          ));
      expect(find.textContaining('Próximamente'), findsNothing);
      for (var z = 6; z <= 10; z++) {
        final zone = _cat.zone(z)!;
        final key = ValueKey('mission-${zone.missionId}');
        await tester.ensureVisible(find.byKey(key));
        expect(find.byKey(key), findsOneWidget);
        expect(
            find.textContaining(
                retroText('Zona $z · ${zone.name} · ${zone.levelText} · '
                    '${zone.floors} pisos')),
            findsOneWidget);
        final b = tester.widget<PanelButton>(
            find.byKey(ValueKey('propose-${zone.missionId}')));
        expect(b.reason, z <= 8 ? isNull : 'Bloqueada', reason: 'zona $z');
      }
      expect(find.textContaining('Bloqueada: vencé a Espectro Coronado'),
          findsOneWidget);
    });

    MissionResult result({required int zone, required bool success}) =>
        MissionResult(
          id: 1,
          missionId: 'z$zone',
          missionName: _cat.zone(zone)!.name,
          success: success,
          rank: MissionRank.a,
          time: 900,
          xp: 10,
          credits: 10,
          bonus: 5,
          bonusPercent: 0.25,
          kos: 0,
          elites: 0,
          eliteDrops: const [],
          drops: const {},
          zone: zone,
          unlocked: zone < 10 && success ? {'p0': zone + 1} : const {},
        );

    testWidgets('resultado: ¡Zona 10 desbloqueada!', (tester) async {
      final r = result(zone: 9, success: true);
      expect(ResultsPanel.isFinalVictory(r), isFalse);
      await pump(
          tester,
          ResultsPanel(
            result: r,
            localId: 'p0',
            playerName: (_) => 'Ana',
            weaponName: (id) => id,
            onBack: () {},
            unlocked: zoneUnlockedText(10, _cat.zone(10)!.name),
            finalVictory: ResultsPanel.isFinalVictory(r),
          ));
      expect(find.text('¡Zona 10 desbloqueada! Corazón del Tiempo'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('results-final')), findsNothing);
    });

    testWidgets('resultado: cartel final al vencer al Devorador',
        (tester) async {
      expect(ResultsPanel.isFinalVictory(result(zone: 10, success: false)),
          isFalse);
      final r = result(zone: 10, success: true);
      expect(ResultsPanel.isFinalVictory(r), isTrue);
      await pump(
          tester,
          ResultsPanel(
            result: r,
            localId: 'p0',
            playerName: (_) => 'Ana',
            weaponName: (id) => id,
            onBack: () {},
            finalVictory: ResultsPanel.isFinalVictory(r),
          ));
      expect(find.byKey(const ValueKey('results-final')), findsOneWidget);
      expect(find.text('¡Venciste al Devorador de Eras!'), findsOneWidget);
      expect(find.text(ResultsPanel.finalSubtitle), findsOneWidget);
    });
  });
}
