import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/quest_track_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_plan.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// v0.32.2: cofre al lado del cartel (misma fila) y DIARIO solo con los
// habitantes conocidos.

void main() {
  test('el cofre de cada construcción queda en la fila del cartel', () {
    const t = TownState();
    expect(t.builds, isNotEmpty);
    for (final b in t.builds) {
      final (sx, sy) = TownPlan.signOf(t, b);
      final (cx, cy) = TownRules.chestOf(t, b);
      expect(cy, sy, reason: b.id);
      expect((cx - sx).abs(), 1, reason: b.id);
      expect(b.contains(cx, cy), isFalse, reason: b.id);
    }
  });

  test('conocido = habló alguna vez (npcSeen)', () {
    final p = newProfile('Ana', 'guerrero');
    expect(QuestTrackRules.met(p, 'ilda'), isFalse);
    final q = QuestTrackRules.markSeen(p, const TownState(), 'ilda');
    expect(QuestTrackRules.met(q!, 'ilda'), isTrue);
    expect(QuestTrackRules.met(q, 'velda'), isFalse);
  });
}
