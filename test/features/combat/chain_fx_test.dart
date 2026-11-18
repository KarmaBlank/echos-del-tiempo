import 'dart:convert';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/chain_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/json_read.dart';
import 'package:flutter_test/flutter_test.dart';

// Saltos visibles (docs/specs/battle_presentation.md § "Saltos").

const _catalog = GameCatalog(
  classes: kClasses,
  weapons: kWeapons,
  skills: kSkills,
  ultimates: kAllUltimates,
  duals: kDuals,
  enemies: kEnemies,
);

Combatant _hero(String skill, {String weapon = 'arco'}) => Combatant(
      id: 'p1',
      name: 'Tira',
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: 0,
      mp: 50,
      maxMp: 50,
      skillIds: [skill],
      classId: 'tirador',
      weaponType: weapon,
    );

Combatant _foe(String id) => Combatant(
      id: id,
      name: 'Limo $id',
      isPlayer: false,
      hp: 500,
      maxHp: 500,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: 'slime',
      nextTurn: 50,
    );

/// Usa [skill] sobre [target] con [n] enemigos.
BattleStep _use(String skill, int n, {String target = 'e0'}) {
  final s = BattleState(
      party: [_hero(skill)],
      enemies: [for (var i = 0; i < n; i++) _foe('e$i')],
      currentId: 'p1');
  final e = BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      catalog: _catalog,
      random: () => 0.99);
  return e.command(s, 'p1', SkillCommand(skill, targetId: target))!;
}

List<DamageEvent> _hits(BattleStep s) => [
      for (final d in s.events.whereType<DamageEvent>())
        if (d.targetId.startsWith('e')) d
    ];

Offset _pos(String id) => switch (id) {
      'p1' => const Offset(300, 200),
      'e0' => const Offset(100, 200),
      'e1' => const Offset(80, 170),
      'e2' => const Offset(60, 230),
      _ => const Offset(40, 200),
    };

void main() {
  group('eventos del motor, en orden', () {
    test('Tiro de Rebote: el primario y cada salto dice de quién viene', () {
      final h = _hits(_use('tiroRebote', 3));
      expect(h, hasLength(3));
      expect(h[0].targetId, 'e0');
      expect(h[0].chainFrom, isNull);
      expect(h[1].chainFrom, 'e0');
      expect(h[2].chainFrom, h[1].targetId);
      expect(h[1].targetId, isNot('e0'));
      expect(h[2].targetId, isNot(h[1].targetId));
    });

    test('Daga Saltarina: 3 saltos encadenados', () {
      final h = _hits(_use('dagaSaltarina', 4));
      expect(h, hasLength(4));
      for (var i = 1; i < h.length; i++) {
        expect(h[i].chainFrom, h[i - 1].targetId);
      }
    });

    test('Flecha Perforante: los de atrás, en orden de fila', () {
      final h = _hits(_use('flechaPerforante', 3));
      expect([for (final d in h) d.targetId], ['e0', 'e1', 'e2']);
      expect([for (final d in h) d.pierced], [false, true, true]);
    });

    test('Ráfaga Triple: golpes 0, 1 y 2 al mismo objetivo', () {
      final h = _hits(_use('rafagaTriple', 2));
      expect([for (final d in h) d.targetId], ['e0', 'e0', 'e0']);
      expect([for (final d in h) d.hitIndex], [0, 1, 2]);
    });

    test('JSON: los campos nuevos viajan y los viejos siguen igual', () {
      const ej = EventJson();
      BattleEvent round(BattleEvent e) =>
          ej.battleFromJson(asJson(jsonDecode(jsonEncode(ej.battleToJson(e)))));
      final a = round(const DamageEvent('e1', 12,
          hitIndex: 2, chainFrom: 'e0', pierced: true)) as DamageEvent;
      expect(a.hitIndex, 2);
      expect(a.chainFrom, 'e0');
      expect(a.pierced, isTrue);
      const plain = DamageEvent('e1', 12);
      final j = ej.battleToJson(plain);
      expect(j.containsKey('hi') || j.containsKey('cf') || j.containsKey('pc'),
          isFalse);
      final b = round(plain) as DamageEvent;
      expect(b.hitIndex, 0);
      expect(b.chainFrom, isNull);
      expect(b.pierced, isFalse);
    });
  });

  group('planificador (puro)', () {
    test('rebote: cada salto sale cuando llega el anterior', () {
      final p = ChainPlanner()..primaryHit('e0', 280);
      final a = p.place(const DamageEvent('e1', 5, chainFrom: 'e0'), _pos)!;
      final b = p.place(const DamageEvent('e2', 5, chainFrom: 'e1'), _pos)!;
      expect(a.delayMs, 280 + ChainTiming.hopMs);
      expect(b.delayMs, 280 + 2 * ChainTiming.hopMs);
      final hopA = a.fx.firstWhere((f) => f.kind == FxKind.hop);
      final hopB = b.fx.firstWhere((f) => f.kind == FxKind.hop);
      expect(hopA.delayMs, 280);
      expect(hopB.delayMs, a.delayMs);
      expect((hopA.x, hopA.tx), (_pos('e0').dx, _pos('e1').dx));
      expect((hopB.x, hopB.tx), (_pos('e1').dx, _pos('e2').dx));
      expect([
        for (final f in [...a.fx, ...b.fx])
          if (f.kind == FxKind.txt) f.text
      ], ['×2', '×3']);
      expect(p.links, 2);
    });

    test('golpe común: no lo toca; sin primario, tampoco', () {
      expect(ChainPlanner().place(const DamageEvent('e1', 5, chainFrom: 'e0'),
              _pos),
          isNull);
      final p = ChainPlanner()..primaryHit('e0', 0);
      expect(p.place(const DamageEvent('e1', 5), _pos), isNull);
    });

    test('ráfaga: números escalonados y cada uno más arriba', () {
      final p = ChainPlanner(hits: 5)..primaryHit('e0', 100);
      final dls = [
        for (var i = 1; i < 5; i++)
          p.place(DamageEvent('e0', 5, hitIndex: i), _pos)!
      ];
      for (var i = 0; i < dls.length; i++) {
        expect(dls[i].delayMs, 100 + (i + 1) * ChainTiming.multiHitMs);
        expect(dls[i].dy, ChainTiming.multiHitDy * (i + 1));
        expect(dls[i].fx, isEmpty);
      }
    });

    test('atraviesa: estela del primario al de atrás y de ahí al siguiente',
        () {
      final p = ChainPlanner()..primaryHit('e0', 0);
      final a = p.place(const DamageEvent('e1', 5, pierced: true), _pos)!;
      final b = p.place(const DamageEvent('e2', 5, pierced: true), _pos)!;
      final s1 = a.fx.firstWhere((f) => f.kind == FxKind.streak);
      final s2 = b.fx.firstWhere((f) => f.kind == FxKind.streak);
      expect(s1.x, _pos('e0').dx);
      expect(s2.x, _pos('e1').dx);
      expect(a.delayMs, ChainTiming.pierceMs);
      expect(b.delayMs, 2 * ChainTiming.pierceMs);
    });

    test('nunca pasa de maxMs después del primario', () {
      final p = ChainPlanner()..primaryHit('e0', 50);
      var last = 0;
      for (var i = 0; i < 10; i++) {
        last = p
            .place(DamageEvent('e${(i + 1) % 3}', 5, chainFrom: 'e${i % 3}'),
                _pos)!
            .delayMs;
      }
      expect(last, lessThanOrEqualTo(50 + ChainTiming.maxMs));
    });
  });

  group('eventos → efectos', () {
    test('Daga Saltarina: un número por enemigo, en fila, con su salto', () {
      final step = _use('dagaSaltarina', 4);
      final fx = mapBattleEvents(step.events, step.state, _pos);
      final hops = fx.where((f) => f.kind == FxKind.hop).toList();
      expect(hops, hasLength(3));
      final nums = [
        for (final f in fx)
          if (f.kind == FxKind.num && f.x != _pos('p1').dx) f.delayMs
      ];
      expect(nums, hasLength(4));
      for (var i = 1; i < nums.length; i++) {
        expect(nums[i] - nums[i - 1], ChainTiming.hopMs);
      }
      expect(nums.last - nums.first, lessThanOrEqualTo(ChainTiming.maxMs));
      // No salen proyectiles desde el lanzador a los rebotados.
      expect(fx.where((f) => f.kind == FxKind.proj).length,
          lessThanOrEqualTo(1));
    });

    test('Ráfaga Triple: 3 números escalonados en el mismo enemigo', () {
      final step = _use('rafagaTriple', 1);
      final fx = mapBattleEvents(step.events, step.state, _pos);
      final nums = [
        for (final f in fx)
          if (f.kind == FxKind.num && f.x == _pos('e0').dx) f
      ];
      expect(nums, hasLength(3));
      expect(nums[1].delayMs - nums[0].delayMs, ChainTiming.multiHitMs);
      expect(nums[2].delayMs - nums[1].delayMs, ChainTiming.multiHitMs);
      expect(nums[2].y, lessThan(nums[0].y));
    });

    test('Flecha Perforante: estelas por la fila', () {
      final step = _use('flechaPerforante', 3);
      final fx = mapBattleEvents(step.events, step.state, _pos);
      expect(fx.where((f) => f.kind == FxKind.streak), hasLength(2));
    });
  });

  test('dibujo: saltos de cada estilo y estelas, con y sin movimiento', () {
    final r = ui.PictureRecorder();
    final c = ui.Canvas(r);
    for (final w in ['dagas', 'arco', null]) {
      for (final el in [FxElement.phys, FxElement.arcane]) {
        for (final still in [false, true]) {
          final f = BattleFx(FxKind.hop,
              x: 0, y: 0, tx: 40, ty: 10, el: el, weapon: w);
          for (var a = 0.0; a < ChainTiming.hopMs + 20; a += 20) {
            ChainFxPainter.paint(c, f, a, still: still, density: 0.3);
          }
        }
      }
    }
    const s = BattleFx(FxKind.streak, x: 0, y: 0, tx: -60, ty: 4);
    for (var a = 0.0; a < ChainTiming.streakMs + 20; a += 20) {
      ChainFxPainter.paint(c, s, a);
    }
    r.endRecording().dispose();
    expect(hopStyleFor('dagas', FxElement.phys), HopStyle.dagger);
    expect(hopStyleFor('arco', FxElement.phys), HopStyle.arrow);
    expect(hopStyleFor('baculo', FxElement.arcane), HopStyle.bolt);
    expect(const BattleFx(FxKind.hop).durationMs, ChainTiming.hopMs);
    expect(const BattleFx(FxKind.streak).durationMs, ChainTiming.streakMs);
  });
}
