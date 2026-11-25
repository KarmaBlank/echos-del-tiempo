import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/missions/presentation/gather_panel.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Dungeon-entry gathering card (free_movement.md § 2.1.1).
void main() {
  const g = Gathering(
      byId: 'p0',
      byName: 'Ana',
      kind: GatherKind.mission,
      target: 'm1',
      label: 'Cripta',
      left: 14.2);

  Future<List<Object>> pump(WidgetTester tester, Gathering g, String me) async {
    final got = <Object>[];
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: RetroTheme.build(),
            home: Scaffold(
                body: Center(
                    child: GatherPanel(
                        gather: g,
                        localId: me,
                        onOp: got.add,
                        onIgnore: () => got.add('ignore')))))));
    await tester.pump();
    return got;
  }

  String text(WidgetTester tester, String key) {
    final t = tester.widget<Text>(find.byKey(ValueKey(key)));
    return t.textSpan?.toPlainText() ?? t.data!;
  }

  testWidgets('proposer: waiting, countdown, ENTRAR YA and CANCELAR',
      (tester) async {
    final got = await pump(tester, g, 'p0');
    expect(text(tester, 'gather-joined'), contains('Esperando'));
    expect(text(tester, 'gather-countdown'), contains('15'));
    expect(find.text('ENTRAR YA'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gather-go')));
    await tester.tap(find.byKey(const ValueKey('gather-cancel')));
    expect(got, [GatherOp.go, GatherOp.cancel]);
    expect(find.byKey(const ValueKey('gather-ignore')), findsNothing);
  });

  testWidgets('others: persistent UNIRSE / IGNORAR, joined list',
      (tester) async {
    final got = await pump(
        tester, g.withJoined(const [AwayPlayer('p1', 'Beto', '')]), 'p2');
    expect(text(tester, 'gather-joined'), allOf(contains('Ana'), contains('Beto')));
    // Does not go away on its own.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const ValueKey('gather-panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gather-join')));
    await tester.tap(find.byKey(const ValueKey('gather-ignore')));
    expect(got, [GatherOp.join, 'ignore']);
  });
}
