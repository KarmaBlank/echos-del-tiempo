import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/npc_talk.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_strings.dart';
import 'package:echos_del_tiempo/game_engine/data/npc_talk_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/serialization/npc_data_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// docs/specs/npc_editor.md § 3.3: a topic with an action runs the fixed
/// behaviour of the screen that hosts the talk.
void main() {
  tearDown(NpcData.restore);

  setUp(() {
    NpcData(talks: {
      ...kNpcTalks,
      'ilda': const NpcTalkDef(greet: [
        LocalizedText('Hola')
      ], topics: [
        TalkTopic('charla', LocalizedText('Charla'), [LocalizedText('Sí.')]),
        TalkTopic('tienda', LocalizedText('¿Qué vendés?'), [],
            action: TalkAction.trade),
        TalkTopic('casa', LocalizedText('Una casa'), [],
            action: TalkAction.house),
        TalkTopic('invitar', LocalizedText('Vení'), [],
            action: TalkAction.invite),
      ]),
    }, quests: const {}).install();
  });

  DsChoice byKey(List<DsChoice> l, String id) =>
      l.firstWhere((c) => c.key == ValueKey('npc-topic-$id'));

  test('an action topic triggers its behaviour and leaves HABLAR', () {
    final s = worldFallbackStrings();
    final ran = <TalkAction>[];
    final acts = TalkActions(
      why: (a) => switch (a) {
        TalkAction.trade => null,
        TalkAction.house => 'Sin casa libre',
        TalkAction.invite => '', // not supported here: hidden
        TalkAction.none => '',
      },
      run: ran.add,
    );
    final talk = NpcTalk('ilda');
    const town = TownState();
    talk.entry(town, () {}, inTown: true, strings: s).onSelected!();
    expect(talk.active, isTrue);
    final list =
        talk.choices(town, () {}, inTown: true, strings: s, actions: acts);
    expect(list.map((c) => c.label),
        containsAll(['Charla', '¿Qué vendés?', 'Una casa']));
    expect(list.map((c) => c.label), isNot(contains('Vení')));
    // Blocked action: shown with its reason, not selectable.
    final house = byKey(list, 'casa');
    expect(house.reason, 'Sin casa libre');
    expect(house.onSelected, isNull);
    // Trade: runs the shop and closes HABLAR.
    byKey(list, 'tienda').onSelected!();
    expect(ran, [TalkAction.trade]);
    expect(talk.active, isFalse);
  });

  test('without handlers, action topics are hidden', () {
    final s = worldFallbackStrings();
    final talk = NpcTalk('ilda');
    const town = TownState();
    talk.entry(town, () {}, inTown: true, strings: s).onSelected!();
    final list = talk.choices(town, () {}, inTown: true, strings: s);
    expect(list.map((c) => c.label), ['Charla', 'Volver']);
  });
}
