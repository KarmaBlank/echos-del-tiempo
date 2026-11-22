import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:echos_del_tiempo/game_engine/rules/zone_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Sin overworld (town_loop.md § 2, v0.21.0): toda zona se elige desde el
/// tablero de encargos (`ProposeMissionAction`), con el estado de
/// desbloqueo de siempre, y al volver se está otra vez en el pueblo.
void main() {
  test('el tablero llega a todas las zonas jugables desbloqueadas', () {
    final e = sessionEngine(zones: true);
    final p = zoneProgression.normalize(PlayerProfile(
        name: 'Ana', classId: 'guerrero', unlockedZone: ZoneRules.maxZone));
    final list = ZoneRules.zoneList(e.catalog, p);
    final playable = list.where((z) => z.mission != null).toList();
    expect(playable, isNotEmpty);
    for (final z in playable) {
      expect(z.unlocked, isTrue, reason: z.zone.name);
      final s = inField(e, z.mission!.id, profiles: [p]);
      expect(s.mission!.zone, z.zone.index, reason: z.zone.name);
      expect(e.mapFor(s).lobby, isFalse);
    }
  });

  test('el lobby es el pueblo, sin entradas de zona', () {
    final e = sessionEngine(zones: true);
    final s =
        e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
    expect(s.mode, SessionMode.lobby);
    expect(identical(e.mapFor(s), MapGenerator.town()), isTrue);
    expect(e.mapFor(s).entrances, isEmpty);
  });

  test('una zona bloqueada no sale del tablero', () {
    final e = sessionEngine(zones: true);
    var s = e.create();
    s = e.addPlayer(s, 'p0', newProfile('Ana', 'guerrero'))!.state;
    final z2 = ZoneRules.zoneList(e.catalog, s.players['p0']!.profile)
        .firstWhere((z) => z.zone.index == 2);
    expect(z2.unlocked, isFalse);
    expect(e.apply(s, 'p0', ProposeMissionAction(z2.mission!.id)), isNull);
  });

  test('el mundo de la sala viaja en el estado (protocolo 41)', () {
    final e = sessionEngine(zones: true);
    var s = e.setWorld(e.create(), 'w1', 'Claro del Eco').state;
    s = e.addPlayer(s, 'p0', newProfile('Ana', 'guerrero'))!.state;
    expect(s.worldId, 'w1');
    expect(s.copy().worldName, 'Claro del Eco');
  });
}
