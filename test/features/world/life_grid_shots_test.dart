// Grilla de oficios (AGROPECUARIO y PESCA Y CULTIVO) y OFICIOS a
// 1280Ã—720 y 1024Ã—640 (v0.24.4): sin desbordes ni textos cortados en el
// detalle. Con LIFE_SHOTS=<carpeta> guarda las capturas:
//   $env:LIFE_SHOTS = "docs\release_shots\v0.24.4"; flutter test test/features/world/life_grid_shots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/trader_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

final _out = Platform.environment['LIFE_SHOTS'];

PlayerProfile _profile() => progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: 900,
      life: LifeSkills(
        fishXp: 400,
        bag: const {'mojarra_claro': 4, 'perca_rayada': 2, 'carpa_musgo': 1},
        rods: const ['cana_rama'],
        farm: FarmSkills(
          xp: 300,
          seeds: const {'nabo_claro': 6, 'trigo_dorado': 4},
          hoes: const ['azada_rama'],
          cans: const ['regadera_lata'],
          crops: const {
            'nabo_claro@0': 5,
            'nabo_claro@1': 2,
            'trigo_dorado@2': 1,
            'papa_piedra@0': 3,
          },
        ),
      ),
    ));

Future<GameSprites?> _sprites(WidgetTester tester) => tester.runAsync(() async {
      final cat = await SpriteCatalog.load();
      await cat.loadProcedural();
      return GameSprites.load(cat);
    });

Future<void> _shot(WidgetTester tester, Finder of, String name) async {
  final out = _out;
  if (out == null) return;
  await tester.runAsync(() async {
    final b = tester.renderObject<RenderRepaintBoundary>(find
        .ancestor(of: of, matching: find.byType(RepaintBoundary))
        .last);
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(out).createSync(recursive: true);
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void _noEllipsis(WidgetTester tester, Finder of) {
  for (final p in tester.renderObjectList<RenderParagraph>(
      find.descendant(of: of, matching: find.byType(RichText)))) {
    expect(p.didExceedMaxLines, isFalse);
  }
}

void main() {
  for (final size in const [Size(1280, 720), Size(1024, 640)]) {
    final w = size.width.toInt();
    final sfx = w == 1280 ? '' : '_1024';

    for (final (mode, tab, cell, name) in const [
      (0, 0, 'trade-rod-cana_roble', 'agro_comprar_pesca'),
      (0, 1, 'trade-seed-trigo_dorado', 'agro_comprar_cultivo'),
      (1, 1, 'trade-crop-nabo_claro@1', 'agro_vender_cultivo'),
    ]) {
      testWidgets('$name a $w', (tester) async {
        await pumpPanel(tester,
            profile: _profile(),
            sprites: await _sprites(tester),
            build: (v, c) =>
                TraderPanel(view: v, controller: c, mode: mode, tab: tab));
        tester.view.physicalSize = size;
        await tester.pump();
        final f = find.byKey(ValueKey(cell));
        if (f.evaluate().isNotEmpty) {
          await tester.tap(f);
          await tester.pump();
        }
        expect(find.byKey(const ValueKey('life-detail')), findsOneWidget);
        _noEllipsis(tester, find.byKey(const ValueKey('life-detail')));
        expect(tester.takeException(), isNull);
        await _shot(tester, find.byKey(const ValueKey('panel-trader')),
            '$name$sfx');
      });
    }

    testWidgets('PESCA Y CULTIVO cosechas a $w', (tester) async {
      await pumpPanel(tester,
          profile: _profile(),
          sprites: await _sprites(tester),
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.lifeItems));
      tester.view.physicalSize = size;
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('life-cat-cosechas')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('life-crop-trigo_dorado-2')));
      await tester.pump();
      _noEllipsis(tester, find.byKey(const ValueKey('life-detail')));
      expect(tester.takeException(), isNull);
      await _shot(tester, find.byKey(const ValueKey('life-items')),
          'pesca_cultivo_cosechas$sfx');
    });

    testWidgets('OFICIOS a $w', (tester) async {
      await pumpPanel(tester,
          profile: _profile(),
          sprites: await _sprites(tester),
          build: (v, c) => CharacterPanel(
              view: v, controller: c, initialTab: CharacterTab.oficios));
      tester.view.physicalSize = size;
      await tester.pump();
      _noEllipsis(tester, find.byKey(const ValueKey('life-row-pesca')));
      _noEllipsis(tester, find.byKey(const ValueKey('life-row-cultivo')));
      expect(tester.takeException(), isNull);
      await _shot(tester, find.byKey(const ValueKey('life-row-pesca')),
          'oficios$sfx');
    });
  }
}
