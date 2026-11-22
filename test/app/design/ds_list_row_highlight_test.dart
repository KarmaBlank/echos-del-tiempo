import 'package:echos_del_tiempo/app/design/ds_components.dart';
import 'package:echos_del_tiempo/app/design/ds_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Color? _border(WidgetTester t) {
  final c = t.widgetList<Container>(find.byType(Container)).firstWhere(
      (c) => c.decoration is BoxDecoration &&
          (c.decoration as BoxDecoration).border != null);
  return ((c.decoration as BoxDecoration).border as Border).top.color;
}

Future<void> _pump(WidgetTester t, {bool selected = false, bool enabled = true}) =>
    t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DsListRow(
                title: 'Golpe',
                highlighted: true,
                selected: selected,
                enabled: enabled,
                onTap: () {}))));

void main() {
  testWidgets('condición lista: borde azul, distinto del de selección',
      (t) async {
    await _pump(t);
    expect(_border(t), DsColors.conditionReady);
    await _pump(t, selected: true);
    expect(_border(t), DsColors.selected);
    await _pump(t, enabled: false);
    expect(_border(t), Colors.transparent);
  });
}
