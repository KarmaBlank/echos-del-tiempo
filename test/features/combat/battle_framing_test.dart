import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_labels.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _names = ['Guerrero', 'Maga', 'Tirador', 'Paladín'];

/// 4 contra 4, con estados en todos (etiquetas anchas).
BattleState _fourVsFour({bool boss = false}) => BattleState(
      party: [
        for (var i = 0; i < 4; i++)
          Combatant(
            id: 'p$i',
            name: _names[i],
            isPlayer: true,
            hp: 50,
            maxHp: 50,
            speed: 10,
            attack: 10,
            critChance: 0,
            statuses: {StatusKind.burn: 2, StatusKind.regen: 1},
          ),
      ],
      enemies: [
        for (var i = 0; i < 4; i++)
          Combatant(
            id: 'e$i',
            name: 'Gólem',
            isPlayer: false,
            hp: 120,
            maxHp: 120,
            speed: 7,
            attack: 7,
            critChance: 0,
            boss: boss && i == 0,
            elite: i == 3,
            enemyType: 'golem',
            statuses: {StatusKind.poison: 3, StatusKind.freeze: 1},
          ),
      ],
    );

/// PressStart2P es monoespaciada: cada letra mide lo que el tamaño.
double _measure(String s, double size) => s.length * size;

void main() {
  for (final arena in <String, BattleArena?>{
    'sin mapa': null,
    'en el mapa': const BattleArena(
        anchorX: 300, anchorY: 200, side: 1, worldWidth: 960, worldHeight: 640),
    'en el borde del mapa': const BattleArena(
        anchorX: 40, anchorY: 30, side: 1, worldWidth: 400, worldHeight: 300),
  }.entries) {
    for (final size in const [Size(1280, 418), Size(1920, 780), Size(960, 400)]) {
      test('4 contra 4 ${arena.key} en $size: la pelea llena el área del mundo '
          'y entra entera', () {
        final s = _fourVsFour(boss: true);
        final g = SceneGeometry.fit(size);
        final layout = BattleLayout.compute(s, arena.value,
            vw: g.virtualWidth,
            enemySize: (e) => e.boss
                ? const Size(36, 32)
                : e.elite
                    ? const Size(23, 20)
                    : const Size(16, 14));
        final view = layout.frame(g, arena.value);
        expect(view.zoom, view.zoom.roundToDouble()); // entero: nítido
        final vp = SceneViewport(g.worldRect, view);
        for (final id in layout.boxes.keys) {
          final r = vp.rectToScreen(layout.boxOf(id));
          expect(g.worldRect.inflate(0.5).contains(r.topLeft), isTrue,
              reason: '$id $r fuera de ${g.worldRect}');
          expect(g.worldRect.inflate(0.5).contains(r.bottomRight), isTrue,
              reason: '$id $r fuera de ${g.worldRect}');
        }
        // La pelea ocupa buena parte del área (no chiquita en el medio).
        final fight = vp.rectToScreen(layout.fightBox);
        final fill = (fight.width / g.worldRect.width) >
                (fight.height / g.worldRect.height)
            ? fight.width / g.worldRect.width
            : fight.height / g.worldRect.height;
        expect(fill, greaterThan(0.55), reason: '$fight en ${g.worldRect}');
        if (size == const Size(1280, 418)) expect(view.zoom, 3);
      });
    }
  }

  test('las etiquetas de un 4 contra 4 no se superponen y quedan en el área',
      () {
    for (final size in const [Size(1280, 418), Size(1920, 780)]) {
      final s = _fourVsFour();
      final g = SceneGeometry.fit(size);
      final layout = BattleLayout.compute(s, null, vw: g.virtualWidth);
      final f = SceneFrame(battle: s, geometry: g, layout: layout);
      final vp = SceneViewport(g.worldRect, layout.frame(g, null));
      final rects = BattleScenePainter.labelRects(f, vp, measure: _measure);
      expect(rects, hasLength(8));
      final list = rects.entries.toList();
      for (var i = 0; i < list.length; i++) {
        expect(g.worldRect.contains(list[i].value.topLeft), isTrue);
        expect(g.worldRect.contains(list[i].value.bottomRight), isTrue);
        for (var j = i + 1; j < list.length; j++) {
          expect(list[i].value.overlaps(list[j].value), isFalse,
              reason: '${list[i].key} ${list[i].value} y '
                  '${list[j].key} ${list[j].value}');
        }
      }
    }
  });

  test('placeLabels corre las que chocan y respeta los bordes', () {
    final r = placeLabels(const [
      LabelRequest('a', Offset(100, 50), Size(60, 10)),
      LabelRequest('b', Offset(110, 52), Size(60, 10)),
      LabelRequest('c', Offset(5, 8), Size(40, 10)),
    ], const Rect.fromLTWH(0, 0, 300, 200));
    expect(r['a']!.overlaps(r['b']!), isFalse);
    expect(r['c']!.left, greaterThanOrEqualTo(0));
    expect(r['c']!.top, greaterThanOrEqualTo(0));
  });
}
