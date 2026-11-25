import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/cooking_view.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/cooking_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';

// COCINA: escalones, DAR A… y FESTÍN (farming.md § 19). With
// `MEAL_PREVIEW=1` it also writes docs/preview/farming/*.png.

final _preview = Platform.environment['MEAL_PREVIEW'] != null;
final _shot = GlobalKey();

Future<void> _save(WidgetTester tester, String name) async {
  if (!_preview) return;
  await tester.runAsync(() async {
    final b =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview/farming').createSync(recursive: true);
    File('docs/preview/farming/$name.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('COMIDAS: escalón en el nombre, DAR A y FESTÍN', (tester) async {
    final base = PlayerProfile(name: 'Ana', classId: 'guerrero', level: 5);
    final legend = mealKey('caldo_invierno', CropQuality.legendario);
    final fine = mealKey('sopa_nabo', CropQuality.raro);
    final start = base.copyWith(
        life: base.life.copyWith(
            farm: base.life.farm.copyWith(crops: {
      cropKey('nabo_claro', CropQuality.normal): 7,
      cropKey('trigo_dorado', CropQuality.epico): 3,
    }, meals: {
      legend: 1,
      fine: 2,
    })));
    final c = await pumpPanel(tester,
        profile: start,
        build: (v, c) => RepaintBoundary(
              key: _shot,
              child: Container(
                color: DsColors.background,
                padding: const EdgeInsets.all(16),
                child: CookingView(
                    profile: v.me!.profile,
                    controller: c,
                    mates: const [('p2', 'Beto'), ('p3', 'Caro')]),
              ),
            ));
    await tester.pumpAndSettle();

    // RECETAS: FESTÍN habilitado con ingredientes ×2.
    await tester.tap(find.byKey(const ValueKey('cook-cell-sopa_nabo')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('feast-sopa_nabo')), findsOneWidget);
    await _save(tester, 'cook_feast');

    // COMIDAS: el escalón legendario muestra su extra y DAR A por compañero.
    await tester.tap(find.byKey(const ValueKey('cook-tab-comidas')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('meal-cell-caldo_invierno-3')).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Legendaria'), findsWidgets);
    expect(find.byKey(ValueKey('give-$legend-p2')), findsOneWidget);
    expect(find.byKey(ValueKey('give-$legend-p3')), findsOneWidget);
    await _save(tester, 'meal_give');

    // FESTÍN (solo en el pueblo): el cocinero queda con la comida.
    expect(c.feastMeal('sopa_nabo', 0), isTrue);
    await tester.pumpAndSettle();
    expect(c.view!.me!.profile.life.farm.meal?.meal, 'sopa_nabo');
  });
}
