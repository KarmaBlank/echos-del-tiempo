import 'package:echos_del_tiempo/features/inventory/presentation/workshop_panel.dart';
import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../panel_test_harness.dart';
import 'armory_panel_test.dart' show richWarrior;

void main() {
  testWidgets('taller de oficios: grilla, chips por oficio y detalle',
      (tester) async {
    await pumpPanel(tester,
        profile: richWarrior(),
        build: (v, c) => WorkshopPanel(view: v, controller: c));
    expect(find.byKey(const ValueKey('workshop-cell-fibra')), findsOneWidget);
    expect(find.byKey(const ValueKey('workshop-cell-cebo')), findsOneWidget);
    expect(find.byKey(const ValueKey('workshop-detail')), findsOneWidget);
    // Sin cosechas no alcanza: los botones quedan grises.
    expect(
        tester
            .widget<DsButton>(find.byKey(const ValueKey('workshop-fibra-×1')))
            .onPressed,
        isNull);
    // PESCA: solo el cebo.
    await tapVisible(tester, find.byKey(const ValueKey('workshop-filter-2')));
    expect(find.byKey(const ValueKey('workshop-cell-fibra')), findsNothing);
    expect(find.byKey(const ValueKey('workshop-cell-cebo')), findsOneWidget);
  });
}
