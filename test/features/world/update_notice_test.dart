import 'package:echos_del_tiempo/features/world/presentation/hud/update_notice.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aviso de versión nueva en el HUD (docs/specs/update_notice.md).
void main() {
  testWidgets('se ve con versión nueva y la X lo cierra', (t) async {
    final src = ValueNotifier<String?>(null);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: UpdateNotice(source: src))));
    expect(find.text(UpdateNotice.text), findsNothing);
    src.value = '9.9.9';
    await t.pump();
    expect(find.text(UpdateNotice.text), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('hud-update-notice-close')));
    await t.pump();
    expect(find.text(UpdateNotice.text), findsNothing);
  });
}
