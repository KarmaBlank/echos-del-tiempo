import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/world/presentation/map/tile_painter.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_map.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/raft_rules.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

/// Raft prompts and E (fishing.md § 15). `RAFT_PREVIEW=1` also writes
/// docs/preview/lake_raft.png.
final _preview = Platform.environment['RAFT_PREVIEW'] != null;

void main() {
  tearDown(() => BiomeRegions.bind(0));

  int forestSeed() {
    for (var seed = 0; seed < 60; seed++) {
      BiomeRegions.bind(seed);
      if (biomeLayout(kBosque)!.raftDocks.isNotEmpty) return seed;
    }
    fail('no forest raft dock');
  }

  test('dock prompt, E boards, shore prompt, E gets off', () async {
    final seed = forestSeed();
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(newProfile('Ana', 'guerrero')),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(c.dispose);
    await c.start();
    c.debugTown((t) => t.copyWith(sky: t.sky.copyWith(seed: seed, day: 1)));
    expect(c.travelPlace(kBosque), isTrue);
    BiomeRegions.bind(seed);
    final d = biomeLayout(kBosque)!.raftDocks.first;
    c.teleport((d.x + 0.5) * 16, (d.y + 0.5) * 16);
    c.advance(0.05);
    expect(c.view!.promptText, c.strings.t('ui.world.raft.prompt_board'));
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    c.advance(0.05);
    expect(c.onRaft, isTrue);
    c.updateLocal(0.05, 0, 0);
    expect(c.view!.promptText, c.strings.t('ui.world.raft.prompt_leave'));
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    c.advance(0.05);
    expect(c.onRaft, isFalse);
  });

  testWidgets('preview', (tester) async {
    if (!_preview) return;
    forestSeed();
    final lay = biomeLayout(kBosque)!;
    final d = lay.raftDocks.first;
    final map = MapGenerator.biome(lay, const {});
    const w = 320.0, h = 200.0;
    final cx = (d.wx + 0.5) * 16, cy = (d.wy + 0.5) * 16;
    final view = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    Future<ui.Image> png(String id) async => (await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
              File('assets/sprites/items/vida_$id.png').readAsBytesSync());
          return (await codec.getNextFrame()).image;
        }))!;
    final raft = await png('balsa'), dock = await png('muelle_balsa');
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..translate(-view.left, -view.top);
    final painter = TilePainter();
    for (var y = (view.top / 16).floor(); y <= (view.bottom / 16).ceil(); y++) {
      for (var x = (view.left / 16).floor(); x <= (view.right / 16).ceil(); x++) {
        if (!map.contains(x, y)) continue;
        painter.draw(c, map.tileAt(x, y), x * 16.0, y * 16.0, map.theme, x, y,
            t: 1000, gateOpen: false, lobby: true);
      }
    }
    void img(ui.Image i, double x, double y) => c.drawImageRect(
        i, const Rect.fromLTWH(0, 0, 16, 16), Rect.fromLTWH(x, y, 16, 16),
        Paint()..filterQuality = FilterQuality.none);
    img(dock, d.x * 16.0, d.y * 16.0);
    img(raft, d.wx * 16.0, d.wy * 16.0);
    // A second raft out on open water.
    var bx = cx, by = cy;
    for (var i = 0; i < 40; i++) {
      final p = RaftRules.step(map, bx, by, (d.wx - d.x).toDouble(),
          (d.wy - d.y).toDouble(), 0.05);
      bx = p.x;
      by = p.y;
    }
    img(raft, bx - 8, by - 8);
    expect(Tile.water, isNotEmpty);
    final out = (await tester.runAsync(
        () => rec.endRecording().toImage(w.toInt(), h.toInt())))!;
    await tester.runAsync(() async {
      final b = await out.toByteData(format: ui.ImageByteFormat.png);
      File('docs/preview/lake_raft.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(b!.buffer.asUint8List());
    });
  });
}
