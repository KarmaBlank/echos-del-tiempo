import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/map/animal_layer.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/animal_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/trader_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/animal_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../../real_fonts.dart';
import '../panel_test_harness.dart';

/// Previews of the farm animals (docs/specs/animals.md § 10): a coop with
/// chickens, a barn with a cow and sheep, the coop panel and the GRANJA
/// shop. Written with `PREVIEW=1 flutter test <this file>` to
/// `docs/preview/animals/`.
final _on = Platform.environment['PREVIEW'] != null;
const _out = 'docs/preview/animals';
const _ts = 16.0;

PlayerProfile _farmer() {
  final b = newProfile('Ana', 'guerrero');
  var xp = 0;
  for (var l = 1; l < 10; l++) {
    xp += FarmingRules.xpNeed(l);
  }
  return progression.normalize(b.copyWith(
      credits: 2400,
      life: b.life.copyWith(
          farm: b.life.farm.copyWith(
              xp: xp,
              hay: 14,
              crops: const {'nabo_claro@0': 6},
              goods: const {'huevo@0': 5, 'huevo@1': 2, 'leche@2': 1},
              rtools: const ['cubeta']))));
}

TownBuild _coop(int x, int y) => TownBuild(
    'g0', BuildKind.gallinero, [TownRect(x, y, 5, 4)],
    hay: 8,
    animals: const [
      FarmAnimal(0, 'gallina', aff: 420, ready: CropQuality.raro),
      FarmAnimal(1, 'gallina', aff: 180, fed: 1, pet: 1),
      FarmAnimal(2, 'gallina', aff: 60, ready: CropQuality.normal),
      FarmAnimal(3, 'pato', aff: 250),
    ]);

TownBuild _barn(int x, int y) => TownBuild(
    'e0', BuildKind.establo, [TownRect(x, y, 7, 5)],
    animals: const [
      FarmAnimal(0, 'vaca', aff: 300, ready: CropQuality.normal),
      FarmAnimal(1, 'oveja', aff: 120),
      FarmAnimal(2, 'oveja', aff: 500, ready: CropQuality.epico),
    ]);

Future<ui.Image?> _png(String id) async {
  final f = File('assets/sprites/items/vida_$id.png');
  if (!f.existsSync()) return null;
  final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
  return (await codec.getNextFrame()).image;
}

void _text(Canvas c, String s, double x, double y, Color col, double size) {
  final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              color: col, fontSize: size, fontFamily: RetroType.pixelFamily)),
      textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
}

Future<ui.Image> _map(WidgetTester tester, TownBuild b, String name,
    {String? selectedHouse, bool write = true}) async {
  await loadRealFonts(tester);
  final town = TownState(builds: [b]);
  final ids = <String>{
    for (var m = 0; m < 16; m++) 'decor_fence_$m',
    'decor_fence_gate_h',
    for (final h in kAnimalHomes.values) h.sprite,
    for (final a in kAnimals.values) ...[a.sprite, '${a.sprite}_b'],
    for (final p in kAnimalProducts.values) p.sprite,
  };
  final imgs = (await tester.runAsync(() async =>
      {for (final id in ids) id: await _png(id)}))!;
  final (ox, oy) = town.origin;
  final r = b.bounds;
  const pad = 1, scale = 4.0;
  final w = (r.w + pad * 2) * _ts, h = (r.h + pad * 2) * _ts;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)
    ..scale(scale)
    ..translate(-(r.x + ox - pad) * _ts, -(r.y + oy - pad) * _ts);
  c.drawRect(
      Rect.fromLTWH((r.x + ox - pad) * _ts, (r.y + oy - pad) * _ts, w, h),
      Paint()..color = const Color(0xFF4E8A3C));
  AnimalLayer().draw(c, town, 12.0, 0, (id) => imgs[id],
      asleep: false,
      selectedHouse: selectedHouse,
      text: (s, x, y, col, size) => _text(c, s, x, y, col, size));
  return (await tester.runAsync(() async {
    final img = await rec.endRecording()
        .toImage((w * scale).round(), (h * scale).round());
    if (write) {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(_out).createSync(recursive: true);
      File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    }
    return img;
  }))!;
}

Future<int> _whites(WidgetTester tester, ui.Image im) async {
  final px = (await tester.runAsync(
      () => im.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  var n = 0;
  for (var i = 0; i < px.lengthInBytes; i += 4) {
    if (px.getUint32(i) == 0xFFFFFFFF) n++;
  }
  return n;
}

Future<GameSprites?> _sprites(WidgetTester tester) => tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      return GameSprites.load(cat);
    });

Future<void> _shot(WidgetTester tester, Finder of, String name) async {
  await tester.runAsync(() async {
    final b = tester.renderObject<RenderRepaintBoundary>(find
        .ancestor(of: of, matching: find.byType(RepaintBoundary))
        .last);
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('preview: coop with chickens', (tester) async {
    if (!_on) return;
    await _map(tester, _coop(4, 4), 'coop');
  });

  testWidgets('preview: barn with a cow and sheep', (tester) async {
    if (!_on) return;
    await _map(tester, _barn(4, 4), 'barn');
  });

  testWidgets('preview: barn targeted (white outline)', (tester) async {
    if (!_on) return;
    await _map(tester, _barn(4, 4), 'barn_targeted', selectedHouse: 'e0');
  });

  // controls.md § Cursor de acción: the targeted barn gets a white 1 px
  // silhouette outline instead of the green tile box.
  testWidgets('the targeted barn house is outlined in white', (tester) async {
    final plain = await _map(tester, _barn(4, 4), 'x', write: false);
    final sel = await _map(tester, _barn(4, 4), 'x',
        selectedHouse: 'e0', write: false);
    final other = await _map(tester, _barn(4, 4), 'x',
        selectedHouse: 'g9', write: false);
    final base = await _whites(tester, plain);
    expect(await _whites(tester, sel), greaterThan(base + 40));
    expect(await _whites(tester, other), base);
  });

  testWidgets('preview: coop panel', (tester) async {
    if (!_on) return;
    final c = await pumpPanel(tester,
        profile: _farmer(),
        sprites: await _sprites(tester),
        build: (v, c) => RepaintBoundary(
            child: AnimalPanel(view: v, controller: c)));
    c.session!.town = c.session!.town.copyWith(builds: [_coop(2, 2)]);
    c.openAnimals('g0', uid: 0);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('panel-animals')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shot(tester, find.byKey(const ValueKey('panel-animals')), 'panel');
  });

  testWidgets('preview: barn panel', (tester) async {
    if (!_on) return;
    final c = await pumpPanel(tester,
        profile: _farmer(),
        sprites: await _sprites(tester),
        build: (v, c) => RepaintBoundary(
            child: AnimalPanel(view: v, controller: c)));
    c.session!.town = c.session!.town.copyWith(builds: [_barn(2, 2)]);
    c.openAnimals('e0', uid: 2);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _shot(
        tester, find.byKey(const ValueKey('panel-animals')), 'panel_barn');
  });

  testWidgets('preview: GRANJA shop', (tester) async {
    if (!_on) return;
    await pumpPanel(tester,
        profile: _farmer(),
        sprites: await _sprites(tester),
        build: (v, c) => RepaintBoundary(
            child: TraderPanel(view: v, controller: c, mode: 0, tab: 3)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ranch-animal-vaca')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _shot(tester, find.byKey(const ValueKey('panel-trader')), 'shop');
  });
}
