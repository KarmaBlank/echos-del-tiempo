import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/world_event_cells.dart';
import 'package:echos_del_tiempo/game_engine/data/world_events_catalog.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../real_fonts.dart';

// world_events.md § 6: en el mapa de viaje, los lugares con eventos
// llevan una marca "!" compacta con los títulos en el tooltip.

const _place = 'pueblo';

String get _defId => kWorldEvents.events.first.id;

WorldEventsState _state(int n) => WorldEventsState(active: [
      for (var i = 0; i < n; i++)
        ActiveWorldEvent(_defId, biome: _place, start: i, end: 99),
    ]);

Widget _app(WorldEventsState s, {GlobalKey? boundary}) => MaterialApp(
    home: Scaffold(
        backgroundColor: DsColors.surface,
        body: Center(
            child: RepaintBoundary(
                key: boundary,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Builder(
                      builder: (c) =>
                          worldEventBadge(c, s, _place) ?? const SizedBox()),
                )))));

void main() {
  setUpAll(loadRealFonts);

  testWidgets('marca "!" en vez de EVENTO, con tooltip de los títulos',
      (tester) async {
    await tester.pumpWidget(_app(_state(1)));
    final mark = find.byKey(const ValueKey('travel-event-$_place'));
    expect(mark, findsOneWidget);
    expect(find.byType(DsMark), findsOneWidget);
    expect(find.text('!'), findsOneWidget);
    expect(find.textContaining('EVENTO'), findsNothing);
    final title = kWorldEvents.def(_defId)!.title.text;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(mark));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
    await mouse.removePointer();
    await tester.pump();
  });

  testWidgets('varios eventos: una sola marca "!"', (tester) async {
    await tester.pumpWidget(_app(_state(2)));
    expect(find.text('!'), findsOneWidget);
    expect(find.textContaining('EVENTOS'), findsNothing);
  });

  testWidgets('sin eventos no hay marca', (tester) async {
    await tester.pumpWidget(_app(const WorldEventsState()));
    expect(find.byType(DsMark), findsNothing);
  });

  // PREVIEW=1 flutter test test/features/world/travel_event_mark_test.dart
  testWidgets('preview PNG', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_app(_state(1), boundary: key));
    await tester.runAsync(() async {
      final ro =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await ro.toImage(pixelRatio: 4);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('docs/preview/travel_event_mark.png');
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }, skip: Platform.environment['PREVIEW'] != '1');
}
