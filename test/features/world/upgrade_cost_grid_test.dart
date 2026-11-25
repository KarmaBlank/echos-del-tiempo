import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/item_source_text.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_icon.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_item_grid.dart';
import 'package:echos_del_tiempo/game_engine/data/farming_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';

/// Cost grid of a house upgrade (docs/specs/item_sources.md § 4). With
/// `COST_PREVIEW=1` it also writes docs/preview/upgrade_cost_grid.png.
final _on = Platform.environment['COST_PREVIEW'] != null;

PlayerProfile _profile() {
  final p = PlayerProfile(name: 'Ana', classId: 'maga', level: 8);
  return p.copyWith(
      life: p.life.copyWith(
          crafts: {'tabla': 3},
          farm: p.life.farm.copyWith(
              crops: {cropKey('pimiento_brasa', CropQuality.values[0]): 1})));
}

Future<void> _pump(WidgetTester tester, {GameSprites? sprites}) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final p = _profile();
  final cell = LifeItemCellData(
    id: 'house-velda',
    icon: const LifeIcon('casa_2', LifeIconKind.herramienta, size: 32),
    border: DsColors.border,
    search: 'casa',
    detail: LifeItemDetail(
      name: 'Casa de Velda',
      nameColor: DsColors.textTitle,
      lines: const ['Nivel 1 de 3', 'Subir a nivel 2: 400 de oro'],
      cost: Builder(
          builder: (context) => itemCostGrid(
              context, p, const {'tabla': 4, 'pimiento_brasa': 4},
              key: const ValueKey('house-cost'))),
    ),
  );
  await tester.pumpWidget(ProviderScope(
    overrides: [
      if (sprites != null)
        gameSpritesProvider.overrideWith((ref) async => sprites),
    ],
    child: RepaintBoundary(
      key: _shot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: DsTheme.apply(RetroTheme.build()),
        home: Scaffold(
          backgroundColor: DsColors.background,
          body: SizedBox.expand(
            child: ColoredBox(
              color: DsColors.background,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: 320,
                      height: 300,
                      child: Builder(
                          builder: (context) => lifeDetailPane(context, cell))),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

final _shot = GlobalKey();

void main() {
  testWidgets('house upgrade cost: cells with have/need and source tip',
      (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('cost-tabla')), findsOneWidget);
    expect(find.byKey(const ValueKey('cost-pimiento_brasa')), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('cost-tabla-count')))
            .data,
        '3/4');
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('cost-pimiento_brasa-count')))
            .data,
        '1/4');

    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(g.removePointer);
    await g.addPointer(location: Offset.zero);
    await g.moveTo(
        tester.getCenter(find.byKey(const ValueKey('cost-pimiento_brasa'))));
    await tester.pumpAndSettle();
    expect(find.text('Se recolecta en GRIETA (plantas silvestres)'),
        findsOneWidget);
    expect(find.text('Tenés 1 de 4'), findsOneWidget);

    if (!_on) return;
    await loadRealFonts(tester);
    final sprites = await tester
        .runAsync(() async => GameSprites.load(await SpriteCatalog.load()));
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, sprites: sprites);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await g.moveTo(Offset.zero);
    await tester.pump();
    await g.moveTo(
        tester.getCenter(find.byKey(const ValueKey('cost-pimiento_brasa'))));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final b =
          _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('docs/preview/upgrade_cost_grid.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
      img.dispose();
    });
  });
}
