import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/npc_talk_rules.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/npc_talk.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'ds_harness.dart';

/// Dialogue box UX (ui_minimal.md § 10): fixed size, skip, disabled
/// options while typing and the VOLVER node stack.
void main() {
  const line = 'Hola, viajero del eco. Hoy el río suena distinto.';
  var picked = '';

  Widget box() => SizedBox(
        width: 1200,
        child: DsDialogueBox(
          portrait: const SizedBox(),
          name: 'Ilda',
          role: 'Herbolaria',
          text: line,
          skipLabel: 'Saltar [Enter]',
          choices: [
            DsChoice('Comprar',
                key: const ValueKey('c-buy'), onSelected: () => picked = 'buy'),
            DsChoice('Adiós', onSelected: () => picked = 'bye'),
          ],
        ),
      );

  Size size(WidgetTester t) =>
      t.getSize(find.byKey(const ValueKey('ds-dialogue')));
  String shown(WidgetTester t) =>
      t.widget<Text>(find.byKey(const ValueKey('ds-dialogue-text'))).data!;

  testWidgets('box size is constant while typing and after', (t) async {
    await pumpDs(t, box());
    final start = size(t);
    expect(find.byKey(const ValueKey('c-buy')), findsOneWidget);
    await t.pump(const Duration(milliseconds: 100));
    expect(shown(t).length, lessThan(line.length));
    expect(size(t), start);
    await t.pump(const Duration(seconds: 3));
    expect(shown(t), line);
    expect(size(t), start);
    expect(start.height, DsDialogueBox.height);
  });

  testWidgets('skip button and Enter reveal the full line', (t) async {
    await pumpDs(t, box());
    expect(find.text('Saltar [Enter]'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ds-dialogue-skip')));
    await t.pump();
    expect(shown(t), line);

    await pumpDs(t, const SizedBox());
    await pumpDs(t, box());
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(shown(t), line);
  });

  testWidgets('options are disabled while typing', (t) async {
    picked = '';
    await pumpDs(t, box());
    // Inside the speech area the tap is a skip, so hit the option itself.
    await t.tap(find.byKey(const ValueKey('c-buy')));
    await t.pump();
    expect(picked, '');
    // That tap revealed the line; now the option works.
    expect(shown(t), line);
    await t.pump();
    await t.tap(find.byKey(const ValueKey('c-buy')));
    expect(picked, 'buy');
    // Enter (second press) chooses the option under the cursor.
    picked = '';
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(picked, 'buy');
  });

  testWidgets('asking a question then VOLVER returns to the menu', (t) async {
    final town = NpcTalkRules.talk(const TownState(), 'ilda', 1)!;
    final topics = NpcTalkRules.topics(town, 'ilda', inTown: true);
    expect(topics, isNotEmpty);
    final first = topics.first;
    final talk = NpcTalk('ilda');
    await pumpDs(t, StatefulBuilder(
      builder: (context, set) {
        void refresh() => set(() {});
        return SizedBox(
          width: 1200,
          child: DsDialogueBox(
            portrait: const SizedBox(),
            name: 'Ilda',
            text: talk.text('Hola.'),
            skipLabel: 'Saltar [Enter]',
            charDelay: Duration.zero,
            choices: talk.active
                ? talk.choices(town, refresh,
                    inTown: true, strings: worldFallbackStrings())
                : [
                    talk.entry(town, refresh,
                        inTown: true, strings: worldFallbackStrings())
                  ],
          ),
        );
      },
    ));
    await t.tap(find.byKey(const ValueKey('npc-choice-hablar')));
    await t.pump();
    final q = ValueKey('npc-topic-${first.id}');
    await t.tap(find.byKey(q));
    await t.pump();
    // The answer node: the asked question is gone, only its branch + VOLVER.
    expect(find.byKey(q), findsNothing);
    expect(shown(t), first.lines.map((l) => l.text).join(' '));
    for (final s in first.sub) {
      expect(find.byKey(ValueKey('npc-topic-${s.id}')), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('npc-topic-back')));
    await t.pump();
    // Back in the previous menu: the question is there again, dimmed.
    expect(find.byKey(q), findsOneWidget);
    final label = t.widget<Text>(
        find.descendant(of: find.byKey(q), matching: find.byType(Text)));
    expect(label.style!.color, isNot(DsColors.text));
    await t.tap(find.byKey(q));
    await t.pump();
    expect(shown(t), first.lines.map((l) => l.text).join(' '));
  });
}
