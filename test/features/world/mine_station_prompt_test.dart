import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/tool_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/game_engine/data/biomes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/rules/mining_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../panel_test_harness.dart';

/// The cart-station spot in a mine (mining_smithing.md § 1.7): E near it
/// builds the station even with the pick in hand, and the tool prompt
/// wraps instead of truncating.
PlayerProfile _profile({int credits = 100000}) {
  final p = newProfile('Ana', 'guerrero');
  return p.copyWith(
      level: 40,
      credits: credits,
      life: p.life.copyWith(ores: {MiningRules.stationIngot: 20}));
}

Future<SessionController> _atStation(WidgetTester tester,
    {int credits = 100000}) async {
  final c = await pumpPanel(tester,
      profile: _profile(credits: credits),
      engine: sessionEngine(zones: true),
      build: (v, c) => Align(
          alignment: Alignment.bottomCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ToolPrompt(controller: c),
            ToolHud(controller: c, profile: v.me!.profile),
          ])));
  expect(c.travelPlace(kBosque), isTrue);
  expect(c.travelMine(0), isTrue);
  final (sx, sy) = c.mineLevel!.station;
  // Diagonal, one tile off and not facing it: still in reach.
  c.teleport((sx + 1.5) * 16, (sy + 1.5) * 16);
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('E at the station spot builds it with the pick in hand',
      (tester) async {
    final c = await _atStation(tester);
    expect(c.mineHand, MineHand.pick);
    expect(c.mineStationSpot, isNotNull);
    expect(c.toolPrompt, contains('₵${MiningRules.t.i('stationGold')}'));
    final swing = c.lastSwingMs;
    expect(c.mineUse(), isTrue);
    // A held E right after never turns into swings.
    c.holdStart();
    c.holdRepeat();
    c.holdRelease();
    expect(c.mineState.station, isTrue);
    expect(c.lastSwingMs, swing);
    expect(c.session!.players[c.localId]!.profile.credits,
        100000 - MiningRules.t.i('stationGold'));
  });

  testWidgets('without the gold E says what is missing and does not swing',
      (tester) async {
    final c = await _atStation(tester, credits: 0);
    final swing = c.lastSwingMs;
    expect(c.mineUse(), isFalse);
    expect(c.mineState.station, isFalse);
    expect(c.lastSwingMs, swing);
  });

  testWidgets('the tool prompt wraps with the gold coin, never truncated',
      (tester) async {
    await _atStation(tester);
    final prompt = find.byKey(const ValueKey('hud-tool-prompt'));
    expect(prompt, findsOneWidget);
    expect(find.descendant(of: prompt, matching: find.byKey(DsGold.coinKey)),
        findsOneWidget);
    for (final p in tester.renderObjectList<RenderParagraph>(
        find.descendant(of: prompt, matching: find.byType(RichText)))) {
      expect(p.didExceedMaxLines, isFalse);
      expect(p.text.toPlainText(), isNot(contains('…')));
    }
    final w = tester.widget<DsGoldText>(prompt);
    expect(w.maxLines, isNull);
  });
}
