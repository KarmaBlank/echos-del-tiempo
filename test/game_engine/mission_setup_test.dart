import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Valores esperados: `startMission` del prototipo corrido con node 20
// sobre ecos-del-tiempo.html con `Math.random = () => 0.5` (semilla
// `(0.5 * 1e9) | 0 = 500000000`). Ver map_generator_test.dart.
const _expected = {
  'm1': (
    ['0 664 376 slime+slime -', '1 488 392 bat+bat -', '2 376 440 slime+slime+slime -', '3 664 536 slime+bat -', '4 888 328 bat+bat -', '5 392 584 slime+slime+slime -', '6 584 472 bat+bat -', '7 136 504 bat+bat -', '8 968 408 slime+slime+slime -', '9 648 648 slime+bat -', '10 264 664 slime+slime -', '11 200 376 bat+bat -', '12 472 648 slime+slime+slime -', '13 808 552 slime+slime -', '14 728 328 slime+slime -', '15 728 456 slime+bat -', '16 216 136 reyLimo+slime+slime B', '17 984 312 bat+bat E'],
    ['0 seal 360 680', '1 seal 184 680', '2 chest 856 408', '3 chest 392 328', '4 chest 440 584'],
    ['kills 7', 'seal 2'],
  ),
  'm2': (
    ['0 664 376 golem -', '1 488 392 bat+bat+slime -', '2 376 440 golem+slime -', '3 664 536 golem+bat -', '4 888 328 bat+bat+slime -', '5 392 584 golem+slime -', '6 584 472 bat+bat+slime -', '7 136 504 bat+bat+slime -', '8 968 408 golem+slime -', '9 648 648 golem+bat -', '10 264 664 golem -', '11 200 376 bat+bat+slime -', '12 472 648 golem+slime -', '13 808 552 golem -', '14 728 328 golem -', '15 728 456 golem+bat -', '16 984 312 bat+bat+slime -', '17 216 136 golemReloj+golem B', '18 392 328 golem+golem E', '19 440 584 golem+bat E'],
    ['0 seal 200 648', '1 seal 856 408', '2 chest 152 344', '3 chest 856 584', '4 chest 600 520'],
    ['kills 8', 'seal 2', 'elite 1'],
  ),
  'm3': (
    ['0 664 376 ghost+ghost -', '1 488 392 golem+golem -', '2 376 440 ghost+bat+bat -', '3 664 536 ghost+golem -', '4 888 328 golem+golem -', '5 392 584 ghost+bat+bat -', '6 584 472 golem+golem -', '7 136 504 golem+golem -', '8 968 408 ghost+bat+bat -', '9 648 648 ghost+golem -', '10 264 664 ghost+ghost -', '11 200 376 golem+golem -', '12 472 648 ghost+bat+bat -', '13 808 552 ghost+ghost -', '14 728 328 ghost+ghost -', '15 728 456 ghost+golem -', '16 984 312 golem+golem -', '17 392 328 ghost+ghost -', '18 216 136 devorador+ghost+ghost B', '19 408 632 ghost+ghost E', '20 248 408 ghost+ghost E'],
    ['0 frag 152 344', '1 frag 856 584', '2 frag 600 520', '3 chest 1016 408', '4 chest 696 600', '5 chest 472 456', '6 chest 200 696'],
    ['kills 9', 'frag 3', 'elite 1'],
  ),
};

String _fmt(num v) => v == v.truncate() ? v.toInt().toString() : '$v';

const _itemKey = {
  MissionItemKind.fragment: 'frag',
  MissionItemKind.seal: 'seal',
  MissionItemKind.chest: 'chest',
};
const _objKey = {
  ObjectiveKind.kills: 'kills',
  ObjectiveKind.fragments: 'frag',
  ObjectiveKind.seals: 'seal',
  ObjectiveKind.elite: 'elite',
};

void main() {
  for (final entry in _expected.entries) {
    test('startMission ${entry.key}: mismos enemigos, objetos y objetivos', () {
      final e = sessionEngine();
      final s = inField(e, entry.key);
      final m = s.mission!;
      expect(m.seed, 500000000);
      expect(
        [
          for (final f in m.enemies)
            '${f.id} ${_fmt(f.x)} ${_fmt(f.y)} ${f.group.join('+')} '
                '${f.boss ? 'B' : f.elite ? 'E' : '-'}',
        ],
        entry.value.$1,
      );
      expect(
        [
          for (final i in m.items)
            '${i.id} ${_itemKey[i.kind]} ${_fmt(i.x)} ${_fmt(i.y)}',
        ],
        entry.value.$2,
      );
      expect([for (final o in m.objectives) '${_objKey[o.kind]} ${o.goal}'],
          entry.value.$3);
      expect(m.open, isFalse);
      // Jugador en spawnPos(0) del mapa de la misión, gracia de 2.5 s.
      final map = e.mapFor(s);
      expect(s.players['p0']!.x, map.spawn.x - 7);
      expect(s.players['p0']!.y, map.spawn.y - 7);
      expect(s.graceLeft, closeTo(2.5, 1e-9));
    });
  }
}
