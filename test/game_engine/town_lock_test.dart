import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/sky_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/town_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Candado de la edición del pueblo (town_editor.md § 1.3), lugar del
// pescador (farming.md § 8.1) y reloj del HUD (day_night_weather.md
// § 1.1), v0.28.0.

void main() {
  test('uno edita a la vez; se suelta al salir o al irse de la sala', () {
    final e = sessionEngine();
    var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
    s = e.addPlayer(s, 'p1', newProfile('Beto', 'maga'))!.state;
    s = act(e, s, 'p1', const TownAction(TownOp.lock));
    expect(s.townEditor, 'p1');
    expect(e.apply(s, 'p0', const TownAction(TownOp.lock)), isNull);
    expect(e.apply(s, 'p0', const TownAction(TownOp.unlock)), isNull);
    s = act(e, s, 'p1', const TownAction(TownOp.unlock));
    expect(s.townEditor, isNull);
    s = act(e, s, 'p1', const TownAction(TownOp.lock));
    s = e.removePlayer(s, 'p1')!.state;
    expect(s.townEditor, isNull);
  });

  test('el pescador queda en la orilla pegado al agua, cerca del cartel', () {
    const t = TownState();
    final lake = t.builds.firstWhere((b) => b.id == 'l0');
    final (x, y) = TownRules.fisherSpot(t, lake, 0);
    expect(lake.contains(x, y), isFalse);
    expect(
        lake.contains(x + 1, y) ||
            lake.contains(x - 1, y) ||
            lake.contains(x, y + 1) ||
            lake.contains(x, y - 1),
        isTrue);
    expect((x, y), isNot(TownRules.chestOf(t, lake)));
  });

  test('reloj: amanece 06:00, anochece 20:00', () {
    const s = SkyState(day: 1);
    expect(SkyRules.clockLabel(s), '06:00');
    expect(SkyRules.clockLabel(s.copyWith(clock: SkyRules.daySec)), '20:00');
  });
}
