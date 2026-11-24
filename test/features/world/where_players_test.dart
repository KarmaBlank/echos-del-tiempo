import 'dart:convert';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/app/widgets/players_here_badge.dart';
import 'package:echos_del_tiempo/features/missions/presentation/mission_board_panel.dart';
import 'package:echos_del_tiempo/features/world/domain/player_locations.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:echos_del_tiempo/game_engine/serialization/session_json.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Where the other players are (free_movement.md § 4.1).
void main() {
  test('away keeps the destination key over the wire (protocol 63)', () {
    const json = SessionJson();
    final s = GameSession(away: const [
      AwayPlayer('p1', 'Ana', 'Bosque', 'bosque'),
      AwayPlayer('p2', 'Beto', 'Cripta', 'm:z1'),
    ]);
    final back = json.fromJson(asJson(jsonDecode(jsonEncode(json.toJson(s)))));
    expect(back.away.map((a) => a.placeId), ['bosque', 'm:z1']);
  });

  test('playersByPlace groups the others by destination', () {
    final s = GameSession(away: const [
      AwayPlayer('me', 'Yo', 'Pueblo', 'pueblo'),
      AwayPlayer('p1', 'Ana', 'Bosque', 'bosque'),
      AwayPlayer('p2', 'Beto', 'Bosque', 'bosque'),
      AwayPlayer('p3', 'Cata', 'Cripta', 'm:z1'),
      AwayPlayer('p4', 'Old', '?'),
    ]);
    final at = playersByPlace(s, 'me');
    expect(at['bosque'], ['Ana', 'Beto']);
    expect(at['m:z1'], ['Cata']);
    expect(at.containsKey('pueblo'), isFalse);
    expect(at.containsKey(''), isFalse);
  });

  testWidgets('mission board shows a badge on the row with players',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const cat = GameCatalog.standard;
    final m = cat.missions.first;
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: MissionBoardPanel(
          missions: cat.missions,
          voteOpen: false,
          onPropose: (_) {},
          onClose: () {},
          playersAt: {
            m.id: const ['Ana', 'Beto'],
          },
        ),
      ),
    )));
    await tester.pump();
    final badge = find.byKey(ValueKey('mission-players-${m.id}'));
    expect(badge, findsOneWidget);
    expect(tester.widget<PlayersHereBadge>(badge).names, ['Ana', 'Beto']);
    expect(find.descendant(of: badge, matching: find.text('2')),
        findsOneWidget);
    expect(find.byType(PlayersHereBadge), findsOneWidget);
  });
}
