import 'dart:math' as math;

import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/proc_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Quiebre, aviso y ULT enemigas → efectos (docs/specs/
// battle_presentation.md § "Quiebre" y § "ULT enemigas").

Combatant _hero(String id) => Combatant(
      id: id,
      name: id,
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      critChance: 0,
      classId: 'guerrero',
      weaponType: 'espada',
    );

Combatant _foe(String id,
        {String type = 'golem', bool boss = false, String? ult}) =>
    Combatant(
      id: id,
      name: id == 'e0' && boss ? 'Rey Limo' : 'Gólem',
      isPlayer: false,
      hp: 100,
      maxHp: 100,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: type,
      boss: boss,
      breakBase: 50,
      ultId: ult,
    );

BattleState _battle({bool boss = false}) => BattleState(party: [
      _hero('p1'),
      _hero('p2'),
    ], enemies: [
      _foe('e0', type: boss ? 'reyLimo' : 'golem', boss: boss, ult: boss ? 'eult_diluvio' : null),
      _foe('e1'),
    ]);

Offset Function(String) _positions(BattleState s) {
  final ids = [...s.party.map((p) => p.id), ...s.enemies.map((e) => e.id)];
  return (id) => Offset(100.0 * ids.indexOf(id), 200);
}

List<BattleFx> _map(List<BattleEvent> events, BattleState s) =>
    mapBattleEvents(events, s, _positions(s));

Iterable<BattleFx> _of(List<BattleFx> fx, FxKind k) =>
    fx.where((f) => f.kind == k);

Iterable<BattleFx> _txt(List<BattleFx> fx, String text) =>
    _of(fx, FxKind.txt).where((f) => f.text == text);

void main() {
  group('quiebre', () {
    test('¡QUIEBRE!: cristal, destello y cartel grande en el ms del golpe '
        'que lo quiebra; cancelar la ULT se dice', () {
      final s = _battle(boss: true);
      final fx = _map(const [
        ActionEvent('p1', BattleActionKind.skill, skillId: 'bola', targetId: 'e0'),
        DamageEvent('e0', 30),
        BreakEvent('e0', BreakPhase.broken, 50, 50, cancelledUlt: true),
      ], s);
      const dl = BattleFx.projMs; // bola: proyectil
      final shatter = _of(fx, FxKind.shatter).single;
      expect([shatter.who, shatter.delayMs, shatter.color], ['e0', dl, breakColor]);
      expect(_of(fx, FxKind.flash).single.delayMs, dl);
      final banner = _of(fx, FxKind.tag).single;
      expect([banner.text, banner.big, banner.delayMs],
          ['¡QUIEBRE!', true, dl + BattleFx.breakBannerMs]);
      expect(_txt(fx, 'ULT CANCELADA').single.delayMs, greaterThan(dl));
    });

    test('llenar o bajar no dibuja nada (lo muestra la barra)', () {
      final fx = _map(const [
        BreakEvent('e0', BreakPhase.fill, 12, 50),
        BreakEvent('e0', BreakPhase.decay, 7, 50),
      ], _battle());
      expect(fx, isEmpty);
    });

    test('pierde el turno: ¡QUEBRADO!; se recupera: SE RECUPERA', () {
      final fx = _map(const [
        TurnStartedEvent('e0'),
        BreakEvent('e0', BreakPhase.skipped, 50, 50),
        BreakEvent('e1', BreakPhase.recovered, 0, 62.5),
      ], _battle());
      expect(_txt(fx, '¡QUEBRADO!'), hasLength(1));
      expect(_of(fx, FxKind.aura).single.el, FxElement.stun);
      expect(_txt(fx, 'SE RECUPERA'), hasLength(1));
    });

    test('golpe a un quebrado: número amarillo grande y QUIEBRE ×1.5 una '
        'vez', () {
      final fx = _map(const [
        ActionEvent('p1', BattleActionKind.skill, skillId: 'giro', allTargets: true),
        DamageEvent('e0', 30, vulnerable: true),
        DamageEvent('e1', 20),
        DamageEvent('e0', 9, sourceId: 'rebote', vulnerable: true),
      ], _battle());
      final nums = _of(fx, FxKind.num).toList();
      expect([nums[0].color, nums[0].big], [breakColor, true]);
      expect([nums[1].color, nums[1].big], [fxWhite, false]);
      expect(_txt(fx, 'QUIEBRE ×1.5'), hasLength(1));
    });
  });

  group('ataque enemigo', () {
    test('se echa atrás, se lanza y el golpe cae después', () {
      final fx = _map(const [
        ActionEvent('e1', BattleActionKind.enemyAttack, targetId: 'p1'),
        DamageEvent('p1', 7),
        StatusAppliedEvent('p1', StatusKind.poison, 1),
        KnockedOutEvent('p1'),
      ], _battle());
      final w = _of(fx, FxKind.windup).single;
      expect([w.who, w.delayMs], ['e1', 0]);
      expect(_of(fx, FxKind.act).single.delayMs, BattleFx.enemyLungeMs);
      expect(_of(fx, FxKind.num).single.delayMs, BattleFx.enemyStrikeMs);
      expect(_of(fx, FxKind.slash).single.delayMs, BattleFx.enemyStrikeMs);
      expect(_txt(fx, 'V+1').single.delayMs, BattleFx.enemyStrikeMs);
      expect(_txt(fx, 'K.O.').single.delayMs, BattleFx.enemyStrikeMs);
      expect(BattleFx.enemyLungeMs, lessThan(BattleFx.enemyStrikeMs));
    });
  });

  group('ULT enemigas', () {
    test('aviso: cartel con el nombre del enemigo y de la ULT, y pulso rojo',
        () {
      final fx = _map(const [
        TurnStartedEvent('e0'),
        EnemyUltWarningEvent('e0', 'eult_diluvio', 'Diluvio Ácido'),
      ], _battle(boss: true));
      final w = _of(fx, FxKind.warn).single;
      expect(w.text, '¡El Rey Limo se prepara para Diluvio Ácido!');
      expect(w.durationMs, BattleFx.warnMs);
      expect(_of(fx, FxKind.pulse).single.who, 'e0');
    });

    for (final id in kEnemyUlts.keys) {
      test('$id: cinemática con su guion; golpes al grupo en sus impactos',
          () {
        final s = _battle(boss: true);
        final script = ultScriptFor(id);
        final ult = kEnemyUlts[id]!;
        final fx = _map([
          EnemyUltEvent('e0', id, ult.name,
              targetId: ult.allTargets ? null : 'p2',
              allTargets: ult.allTargets,
              wipedBuffs: ult.wipeBuffs),
          if (ult.allTargets) const DamageEvent('p1', 15, critical: true),
          const DamageEvent('p2', 14),
          const StatusAppliedEvent('p2', StatusKind.poison, 2),
          if (ult.delayAll > 0) ...const [DelayedEvent('p1'), DelayedEvent('p2')],
        ], s);
        final c = _of(fx, FxKind.ult).single;
        expect(c.ult!.enemy, isTrue);
        expect(c.ult!.enemyType, 'reyLimo');
        expect(c.ult!.script, same(script));
        expect(c.ult!.name, ult.name);
        expect(c.color, enemyUltColor(id));
        final targets = ult.allTargets ? ['p1', 'p2'] : ['p2'];
        expect(c.ult!.targets, targets);
        final nums = _of(fx, FxKind.num).toList();
        expect(nums.map((n) => n.delayMs),
            [for (var i = 0; i < targets.length; i++) script.impactFor(i)]);
        expect(nums.every((n) => n.heavy && n.hurt), isTrue);
        expect(_of(fx, FxKind.act).single.delayMs, script.buildMs);
        expect(_txt(fx, 'V+2').single.delayMs, script.impactFor(targets.length - 1));
        if (ult.delayAll > 0) {
          expect(_txt(fx, 'RETRASO'), hasLength(2));
        }
        expect(_txt(fx, 'BUFFS BORRADOS'), hasLength(ult.wipeBuffs ? 2 : 0));
        // Los procs de quien recibe van después de la cinemática.
        expect(ProcTiming.base(inAction: true, ult: script), script.returnAt);
      });
    }

    test('guiones: entran en la pausa de la sesión y en los rangos de las '
        'ULT del grupo', () {
      for (final e in kEnemyUlts.keys) {
        final s = kEnemyUltScripts[e]!;
        expect(isEnemyUlt(e), isTrue);
        expect(ultScriptFor(e), same(s));
        expect(s.returnAt, lessThanOrEqualTo(2100), reason: e);
        expect(s.buildMs, inInclusiveRange(600, 1000), reason: e);
        expect(s.releaseMs, inInclusiveRange(800, 1500), reason: e);
        for (var i = 0; i < 4; i++) {
          expect(s.phaseAt(s.impactFor(i).toDouble()), UltPhase.release);
        }
        for (final h in s.preHitsMs) {
          expect(h, inExclusiveRange(s.buildMs, s.impactMs));
        }
      }
      expect(kEnemyUltScripts.keys.toSet(), kEnemyUlts.keys.toSet());
      expect(isEnemyUlt('ult_espada'), isFalse);
    });
  });

  group('escena', () {
    SceneFrame frameOf(BattleState s) {
      final g = SceneGeometry.fit(const Size(1280, 418));
      return SceneFrame(
          battle: s,
          geometry: g,
          layout: BattleLayout.compute(s, null, vw: g.virtualWidth));
    }

    test('el quiebre sacude, frena el reloj un instante y tira astillas', () {
      final scene = BattleSceneController(random: math.Random(1));
      scene.addEffects(const [BattleFx(FxKind.shatter, x: 10, y: 10, who: 'e0')]);
      scene.advance(16);
      expect(scene.hitStop, greaterThan(0));
      expect(scene.particles.shake, greaterThanOrEqualTo(6));
      expect(scene.particles.particles, isNotEmpty);
      final t0 = scene.t;
      scene.advance(40);
      expect(scene.t, t0);
      scene.advance(200);
      expect(scene.t, greaterThan(t0));
    });

    test('la ULT enemiga usa al grupo como objetivos y congela el tiempo',
        () {
      final s = _battle(boss: true);
      final f = frameOf(s);
      final c = BattleSceneController(random: math.Random(3))..frame = f;
      c.addEffects(mapBattleEvents(const [
        EnemyUltEvent('e0', 'eult_diluvio', 'Diluvio Ácido', allTargets: true),
        DamageEvent('p1', 15),
        DamageEvent('p2', 14),
      ], s, f.layout.of));
      c.advance(10);
      expect(c.ult, isNotNull);
      expect(c.frozen, isTrue);
      final st = c.ultStage()!;
      expect(st.caster, f.layout.of('e0'));
      expect(st.targets, [f.layout.of('p1'), f.layout.of('p2')]);
      final script = ultScriptFor('eult_diluvio');
      for (var t = 0.0; t < script.totalMs + 200; t += 10) {
        c.advance(10);
      }
      expect(c.ult, isNull);
    });

    test('etiquetas: barra de quiebre, carga de ULT y chip VULNERABLE '
        'agrandan la del enemigo, sin superponerse', () {
      double measure(String s, double size) => s.length * size;
      final s = BattleState(party: [
        for (var i = 0; i < 4; i++) _hero('p$i'),
      ], enemies: [
        _foe('e0', type: 'reyLimo', boss: true, ult: 'eult_diluvio')
          ..vulnerable = 2
          ..breakGauge = 50,
        for (var i = 1; i < 4; i++) _foe('e$i')..breakGauge = 10.0 * i,
      ]);
      final f = frameOf(s);
      final vp = SceneViewport(f.geometry.worldRect, f.layout.frame(f.geometry, null));
      final rects = BattleScenePainter.labelRects(f, vp, measure: measure);
      expect(rects['e0']!.height, BattleScenePainter.enemyLabelHeight(s.enemies[0], 1));
      expect(rects['e0']!.height, (15 + 4 + 3 + 12).toDouble());
      expect(rects['e1']!.height, 19);
      final list = rects.entries.toList();
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          expect(list[i].value.overlaps(list[j].value), isFalse,
              reason: '${list[i].key} y ${list[j].key}');
        }
      }
    });
  });
}
