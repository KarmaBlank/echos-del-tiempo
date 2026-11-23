import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

DsTransferItem _it(String id, int n, String tag) => DsTransferItem(
    id: id,
    icon: const SizedBox.square(dimension: 24),
    name: id,
    border: DsColors.border,
    count: n,
    tag: tag);

void main() {
  testWidgets('traspaso: elegir, pasar, filtrar y botones grises',
      (t) async {
    final moves = <String>[];
    t.view.physicalSize = const Size(1280, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 780,
                child: DsTransferTemplate(
                  keyPrefix: 'tt',
                  leftTitle: 'MÍO',
                  rightTitle: 'OTRO',
                  left: [_it('a', 5, 'x'), _it('b', 2, 'y')],
                  right: [_it('c', 1, 'x')],
                  filters: const [
                    DsTransferFilter('TODAS', null),
                    DsTransferFilter('Y', 'y'),
                  ],
                  canMove: (s, id) => id == 'c' ? 'No se puede' : null,
                  onMove: (s, id, q) => moves.add('${s.name}-$id-$q'),
                )))));
    DsButton btn(String k) => t.widget<DsButton>(find.byKey(ValueKey(k)));
    expect(btn('tt-give-1').onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('tt-cell-l-a')));
    await t.pump();
    expect(find.text('a ×5'), findsOneWidget);
    expect(btn('tt-take-1').onPressed, isNull);
    await t.tap(find.byKey(const ValueKey('tt-give-TODO')));
    expect(moves, ['left-a-0']);
    await t.tap(find.byKey(const ValueKey('tt-cell-r-c')));
    await t.pump();
    expect(btn('tt-take-1').onPressed, isNull);
    expect(btn('tt-take-1').tooltip, 'No se puede');
    await t.tap(find.byKey(const ValueKey('tt-filter-1')));
    await t.pump();
    expect(find.byKey(const ValueKey('tt-cell-l-a')), findsNothing);
    expect(find.byKey(const ValueKey('tt-cell-l-b')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
