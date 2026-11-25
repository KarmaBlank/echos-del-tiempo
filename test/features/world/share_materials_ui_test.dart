import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/life_items_view.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/farming_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/oficio_storage_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../panel_test_harness.dart';

// OFICIOS → INVENTARIO: DAR A <compañero> con 1 / paso / todo
// (share_materials.md). With `SHARE_PREVIEW=1` it also writes
// docs/preview/share_materials.png.

final _preview = Platform.environment['SHARE_PREVIEW'] != null;
final _shot = GlobalKey();

Future<void> _save(WidgetTester tester) async {
  if (!_preview) return;
  await tester.runAsync(() async {
    final b =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/preview').createSync(recursive: true);
    File('docs/preview/share_materials.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
  });
}

VoidCallback? _onPressed(WidgetTester tester, String key) =>
    tester.widget<DsButton>(find.byKey(ValueKey(key))).onPressed;

void main() {
  testWidgets('DAR A: un botón por compañero, gris si no entra o no alcanza',
      (tester) async {
    final base = PlayerProfile(name: 'Ana', classId: 'guerrero', level: 5);
    final me = base.copyWith(
        life: base.life.copyWith(
            crafts: {'tabla': 3, 'fibra': 12},
            ores: {'ingot_copper': 6}));
    // Caro has a full CULTIVO bag; Beto has room.
    const crops = ['nabo_claro', 'trigo_dorado', 'papa_piedra',
        'calabaza_sendero', 'frutilla_rocio', 'cebolla_cobre', 'flor_runica',
        'melon_engranaje', 'trigo_manana', 'rosa_reloj'];
    final caro0 = PlayerProfile(name: 'Caro', classId: 'mago', level: 5);
    final caro = caro0.copyWith(
        life: caro0.life.copyWith(
            farm: caro0.life.farm.copyWith(seeds: const {}, crops: {
      for (var i = 0; i < OficioStorageRules.cap; i++)
        cropKey(crops[i % 10], CropQuality.values[i ~/ 10]): 1,
    })));
    final beto = PlayerProfile(name: 'Beto', classId: 'mago', level: 5);
    await pumpPanel(tester,
        profile: me,
        build: (v, c) => RepaintBoundary(
              key: _shot,
              child: Container(
                color: DsColors.background,
                padding: const EdgeInsets.all(16),
                child: LifeItemsView(
                    profile: v.me!.profile,
                    controller: c,
                    inTown: true,
                    mates: [('p2', 'Beto', beto), ('p3', 'Caro', caro)]),
              ),
            ));
    await tester.pumpAndSettle();
    // CULTIVO: Caro's bag is full, a new seed stack is grey for her only.
    await tester.tap(find.byKey(const ValueKey('oficio-bag-cultivo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life-seed-nabo_claro')).first);
    await tester.pumpAndSettle();
    expect(_onPressed(tester, 'life-give-seed-nabo_claro-p2'), isNotNull);
    expect(_onPressed(tester, 'life-give-seed-nabo_claro-p3'), isNull);

    await tester.tap(find.byKey(const ValueKey('oficio-bag-herreria')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life-craft-tabla')).first);
    await tester.pumpAndSettle();

    // ×1 by default: both mates can take a tabla (HERRERÍA has room).
    expect(_onPressed(tester, 'life-give-craft-tabla-p2'), isNotNull);
    expect(_onPressed(tester, 'life-give-craft-tabla-p3'), isNotNull);
    // Only 3 tablas: the ×5 preset is grey.
    expect(_onPressed(tester, 'life-give-amt-craft-tabla-1'), isNull);
    expect(find.text('DAR A BETO'), findsOneWidget);

    // The ingots (MINERALES) can be given too.
    await tester.tap(find.byKey(const ValueKey('oficio-filter-minerales')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life-ore-ingot_copper')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life-give-amt-ore-ingot_copper-1')));
    await tester.pumpAndSettle();
    expect(_onPressed(tester, 'life-give-ore-ingot_copper-p2'), isNotNull);
    await _save(tester);
  });

  testWidgets('sin compañeros en el pueblo: DAR A... gris', (tester) async {
    final base = PlayerProfile(name: 'Ana', classId: 'guerrero', level: 5);
    final me = base.copyWith(life: base.life.copyWith(crafts: {'tabla': 3}));
    await pumpPanel(tester,
        profile: me,
        build: (v, c) => LifeItemsView(
            profile: v.me!.profile,
            controller: c,
            inTown: true,
            mates: const []));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('oficio-bag-herreria')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('life-craft-tabla')).first);
    await tester.pumpAndSettle();
    expect(_onPressed(tester, 'life-give-craft-tabla-none'), isNull);
  });
}
