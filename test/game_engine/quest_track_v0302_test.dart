import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../design/ds_harness.dart';

/// Encargos seguidos, marcas y diálogo de habitantes (roles.md § 7,
/// ui_minimal.md § 10).
void main() {
  test('revelar, marcar, seguir y guardar', () {
    final ilda = biomeNpc('ilda')!;
    final town =
        const TownState().withResident(const ResidentState('ilda', rep: 1));
    var p = PlayerProfile(name: 'A', classId: 'guerrero');
    // El paso nuevo no aparece hasta que te lo cuenta: "!" en su cabeza.
    expect(QuestTrackRules.forNpc(p, town, ilda), isEmpty);
    expect(QuestTrackRules.mark(p, town, ilda), NpcMark.news);
    p = QuestTrackRules.markSeen(p, town, 'ilda')!;
    expect(QuestTrackRules.markSeen(p, town, 'ilda'), isNull);
    expect(QuestTrackRules.mark(p, town, ilda), isNot(NpcMark.news));
    final a = QuestTrackRules.forNpc(p, town, ilda).single;
    expect(a.kind, QuestTrackKind.encargo);
    p = QuestTrackRules.toggle(p, town, a.key)!;
    expect(QuestTrackRules.active(p, town).single.tracked, isTrue);
    final back = PlayerProfile.fromJson(p.toJson());
    expect(back.tracked, p.tracked);
    expect(back.npcSeen, p.npcSeen);
    // Tope de seguidos.
    final full = p.copyWith(tracked: [for (var i = 0; i < 5; i++) 'x:$i']);
    expect(QuestTrackRules.toggle(full, town, a.key), isNull);
    expect(QuestTrackRules.toggle(p, town, a.key)!.tracked, isEmpty);
  });

  testWidgets('diálogo: se escribe, se saltea y muestra opciones',
      (tester) async {
    var picked = '';
    await pumpDs(
        tester,
        SizedBox(
          width: 1200,
          child: DsDialogueBox(
            portrait: const SizedBox(),
            name: 'Ilda',
            role: 'Herbolaria',
            text: 'Hola, viajero del eco.',
            choices: [
              DsChoice('Comprar',
                  key: const ValueKey('c-buy'),
                  onSelected: () => picked = 'buy'),
              const DsChoice('Casa',
                  key: ValueKey('c-house'), reason: 'Primero invitalo'),
            ],
          ),
        ));
    expect(find.byKey(const ValueKey('c-buy')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ds-dialogue')));
    await tester.pump();
    expect(find.text('Hola, viajero del eco.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('c-house')));
    expect(picked, '');
    await tester.tap(find.byKey(const ValueKey('c-buy')));
    expect(picked, 'buy');
  });
}
