import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/house_assign_panel.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';

/// ASIGNAR CASAS (town_editor.md § 1.1). Preview PNG with
/// `HOUSES_PREVIEW=1 flutter test <this file>`.
final _preview = Platform.environment['HOUSES_PREVIEW'] != null;

Widget _host(Widget child, {GlobalKey? key}) => MaterialApp(
      home: Scaffold(
        backgroundColor: DsColors.background,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: DsColors.background,
              width: 1280,
              height: 720,
              padding: const EdgeInsets.all(160),
              child: child,
            ),
          ),
        ),
      ),
    );

const _houses = [
  HouseCellData('h1', 'CASA 1', 'Nivel 1'),
  HouseCellData('h2', 'CASA 2', 'Nivel 2'),
];
const _people = [
  HouseCandidateData('brann', 'Brann', 'Beneficio: forja'),
  HouseCandidateData('ilda', 'Ilda', 'Beneficio: huerta'),
];

void main() {
  setUpAll(() async {
    if (_preview) await loadRealFonts();
  });

  testWidgets('empty state when nobody can be assigned', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(HouseAssignView(
        houses: _houses, candidates: const [], onAssign: (_, __) {})));
    expect(find.text('No hay nadie para asignar'), findsOneWidget);
    expect(find.byKey(const ValueKey('houses-assign')), findsNothing);
  });

  testWidgets('pick a house, a resident and ASIGNAR', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <(String, String)>[];
    final shot = GlobalKey();
    await tester.pumpWidget(_host(
        SizedBox(
          height: 320,
          child: HouseAssignView(
              houses: _houses,
              candidates: _people,
              onAssign: (n, h) => calls.add((n, h))),
        ),
        key: shot));
    await tester.tap(find.byKey(const ValueKey('houses-cell-h2')));
    await tester.pump();
    // Grey until a resident is chosen.
    await tester.tap(find.byKey(const ValueKey('houses-assign')));
    expect(calls, isEmpty);
    await tester.tap(find.byKey(const ValueKey('houses-npc-brann')));
    await tester.pump();
    if (_preview) {
      await tester.runAsync(() async {
        final b = shot.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory('docs/preview').createSync(recursive: true);
        File('docs/preview/fountain_houses.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    await tester.tap(find.byKey(const ValueKey('houses-assign')));
    await tester.pump();
    expect(calls, [('brann', 'h2')]);
  });

  testWidgets('ASIGNAR grey while another player edits', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final calls = <(String, String)>[];
    await tester.pumpWidget(_host(SizedBox(
        height: 320,
        child: HouseAssignView(
            houses: _houses,
            candidates: _people,
            blockedWhy: 'Está editando Ana',
            onAssign: (n, h) => calls.add((n, h))))));
    await tester.tap(find.byKey(const ValueKey('houses-npc-ilda')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('houses-assign')));
    expect(calls, isEmpty);
  });
}
