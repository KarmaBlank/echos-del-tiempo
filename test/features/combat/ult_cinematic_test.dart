import 'dart:math' as math;

import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Guiones esperados (docs/specs/battle_presentation.md § "Guiones").
const _expected = {
  //                    estilo, prep, descarga, regreso, impacto, escalón
  'espada': (UltStyle.finalSlash, 800, 1000, 400, 1380, 0),
  'hacha': (UltStyle.cataclysm, 900, 1100, 400, 1300, 60),
  'báculo': (UltStyle.meteor, 900, 1200, 400, 1350, 120),
  'tomo': (UltStyle.paradox, 900, 1100, 400, 1450, 50),
  'arco': (UltStyle.arrowStorm, 700, 1200, 400, 1300, 70),
  'rifle': (UltStyle.deadShot, 900, 900, 400, 1350, 0),
  'espada+escudo': (UltStyle.bulwark, 800, 1100, 400, 1150, 60),
  'maza+escudo': (UltStyle.judgment, 900, 1100, 400, 1300, 90),
  'martillo+escudo': (UltStyle.skyHammer, 900, 1000, 400, 1300, 0),
  // loot v2 (`kNewUltimates`).
  'lanza': (UltStyle.spearRain, 800, 1100, 400, 1300, 80),
  'varita': (UltStyle.arcaneStorm, 800, 1200, 400, 1350, 60),
  'ballesta': (UltStyle.volley, 900, 900, 400, 1300, 0),
  'dagas': (UltStyle.thousandCuts, 700, 1100, 400, 1500, 0),
};

Combatant _hero(String id, String weapon) => Combatant(
      id: id,
      name: id.toUpperCase(),
      isPlayer: true,
      hp: 50,
      maxHp: 50,
      speed: 10,
      attack: 10,
      critChance: 0,
      weaponType: weapon,
      classId: 'guerrero',
    );

Combatant _foe(String id) => Combatant(
      id: id,
      name: 'Gólem',
      isPlayer: false,
      hp: 30,
      maxHp: 30,
      speed: 7,
      attack: 7,
      critChance: 0,
      enemyType: 'golem',
    );

BattleState _state(String weapon) => BattleState(
      party: [_hero('p1', weapon), _hero('p2', 'arco')],
      enemies: [_foe('e0'), _foe('e1'), _foe('e2')],
    );

/// Los eventos de una ULT del arma [weapon] (de daño a 3 enemigos, uno
/// de ellos crítico; Baluarte cura al grupo).
List<BattleEvent> _ultEvents(String weapon) {
  final sk = kAllUltimates[weapon]!;
  return [
    UltimateUsedEvent('p1', sk.name),
    ActionEvent('p1', BattleActionKind.ultimate, skillId: sk.id, targetId: 'e0'),
    if (sk.dealsDamage) ...[
      const DamageEvent('e0', 40),
      const DamageEvent('e1', 41, critical: true),
      const DamageEvent('e2', 42),
    ] else ...[
      const HealEvent('p1', 15),
      const HealEvent('p2', 15),
    ],
  ];
}

Iterable<BattleFx> _of(List<BattleFx> fx, FxKind k) =>
    fx.where((f) => f.kind == k);

void main() {
  group('guiones', () {
    test('cada ULT tiene su guion con las fases y tiempos del spec', () {
      expect(kUltScripts.keys.toSet(),
          {for (final s in kAllUltimates.values) s.id});
      for (final e in _expected.entries) {
        final sk = kAllUltimates[e.key]!;
        final s = ultScriptFor(sk.id);
        final (style, build, release, ret, impact, stagger) = e.value;
        expect(s.style, style, reason: sk.name);
        expect(s.buildMs, build, reason: sk.name);
        expect(s.releaseMs, release, reason: sk.name);
        expect(s.returnMs, ret, reason: sk.name);
        expect(s.impactMs, impact, reason: sk.name);
        expect(s.staggerMs, stagger, reason: sk.name);
        // 2-3.5 s en total; la descarga termina antes de la pausa de 2.3 s
        // de la sesión tras una ULT.
        expect(s.totalMs, inInclusiveRange(2000, 3500), reason: sk.name);
        expect(s.returnAt, lessThanOrEqualTo(2100), reason: sk.name);
        // Preparación 0.6-1.0 s, descarga 0.8-1.5 s.
        expect(s.buildMs, inInclusiveRange(600, 1000), reason: sk.name);
        expect(s.releaseMs, inInclusiveRange(800, 1500), reason: sk.name);
        // Todos los impactos (hasta 4 objetivos) caen dentro de la descarga.
        for (var i = 0; i < 6; i++) {
          expect(s.phaseAt(s.impactFor(i).toDouble()), UltPhase.release,
              reason: '${sk.name} #$i');
        }
        for (final h in s.preHitsMs) {
          expect(s.phaseAt(h.toDouble()), UltPhase.release);
          expect(h, lessThan(s.impactMs));
        }
        // Fases en orden.
        expect(s.phaseAt(0), UltPhase.buildUp);
        expect(s.phaseAt(build - 1), UltPhase.buildUp);
        expect(s.phaseAt(build.toDouble()), UltPhase.release);
        expect(s.phaseAt(s.returnAt.toDouble()), UltPhase.recover);
        expect(s.phaseAt(s.totalMs.toDouble()), UltPhase.done);
      }
    });

    test('el escalón por objetivo se corta en el 4.º', () {
      final s = kUltScripts['ult_baculo']!;
      expect(s.impactFor(0), 1350);
      expect(s.impactFor(3), 1350 + 3 * 120);
      expect(s.impactFor(7), s.impactFor(3));
      expect(s.lastImpact(2), s.impactFor(1));
    });

    test('cámara: zoom al lanzador en la preparación, a los objetivos en '
        'la descarga y de vuelta a la base', () {
      const base = CameraView(Offset(200, 100), 3);
      const caster = Offset(260, 100), target = Offset(150, 90);
      for (final s in kUltScripts.values) {
        CameraView at(double a) => ultCameraAt(s, a,
            base: base, caster: caster, targets: [target], party: [caster]);
        final hold = at(s.buildMs - 1);
        expect(hold.zoom, greaterThan(base.zoom));
        expect(hold.zoom, hold.zoom.roundToDouble()); // nítido en la pausa
        expect(hold.center, caster.translate(0, -12));
        final rel = at(s.returnAt - 1);
        expect(rel.zoom, greaterThanOrEqualTo(base.zoom));
        final end = at(s.totalMs.toDouble());
        expect(end.center, base.center);
        expect(end.zoom, base.zoom);
        expect(at(0).zoom, base.zoom);
      }
    });
  });

  group('eventos → cinemática', () {
    for (final weapon in _expected.keys) {
      test('$weapon: guion, objetivos y números en el impacto de cada uno',
          () {
        final st = _state(weapon);
        final sk = kAllUltimates[weapon]!;
        final script = ultScriptFor(sk.id);
        final fx = mapBattleEvents(_ultEvents(weapon), st,
            (id) => Offset(10.0 * id.codeUnitAt(1), 100));
        final ult = _of(fx, FxKind.ult).single;
        expect(ult.ult!.script, same(script));
        expect(ult.ult!.ultId, sk.id);
        expect(ult.durationMs, script.totalMs);
        final nums = _of(fx, FxKind.num).toList();
        if (sk.dealsDamage) {
          expect(ult.ult!.targets, ['e0', 'e1', 'e2']);
          expect(nums.map((n) => n.delayMs),
              [for (var i = 0; i < 3; i++) script.impactFor(i)]);
          // El crítico: destello blanco con el mismo retraso.
          final flash = _of(fx, FxKind.flash).single;
          expect(flash.delayMs, script.impactFor(1));
          expect(nums[1].big, isTrue);
        } else {
          expect(ult.ult!.bulwark, isTrue);
          expect(ult.ult!.targets, ['p1', 'p2']);
          expect(nums.map((n) => n.delayMs),
              [script.impactFor(0), script.impactFor(1)]);
        }
        expect(nums.every((n) => n.heavy), isTrue);
        expect(nums.first.durationMs, BattleFx.heavyNumMs);
        expect(_of(fx, FxKind.act).single.delayMs, script.buildMs);
      });
    }
  });

  group('BattleSceneController con una ULT', () {
    SceneFrame frameOf(BattleState s) {
      final g = SceneGeometry.fit(const Size(1280, 418));
      return SceneFrame(
          battle: s,
          geometry: g,
          layout: BattleLayout.compute(s, null, vw: g.virtualWidth));
    }

    BattleSceneController withUlt(String weapon) {
      final s = _state(weapon);
      final c = BattleSceneController(random: math.Random(3));
      final f = frameOf(s);
      c.frame = f;
      c.addEffects(mapBattleEvents(_ultEvents(weapon), s, f.layout.of));
      return c;
    }

    void run(BattleSceneController c, double ms, {double step = 10}) {
      for (var t = 0.0; t < ms; t += step) {
        c.advance(step);
      }
    }

    test('el número aparece en el impacto de la descarga, con hit-stop en '
        'el último y el tiempo congelado durante la cinemática', () {
      final c = withUlt('báculo');
      final s = kUltScripts['ult_baculo']!;
      c.advance(10);
      expect(c.ult, isNotNull);
      expect(c.frozen, isTrue);
      final pose = c.poseT;
      final nums = c.fx.where((e) => e.fx.kind == FxKind.num).toList();
      expect(nums, hasLength(3));
      // Justo antes del primer impacto, ningún número a la vista.
      run(c, s.impactFor(0) - 30);
      expect(nums.every((n) => n.age(c.t) < 0), isTrue);
      expect(c.poseT, pose); // sin flotación
      // Al llegar el impacto, el número 0 empieza (edad ≈ 0).
      while (nums[0].age(c.t) < 0) {
        c.advance(5);
      }
      expect(c.t - c.ult!.t0, closeTo(s.impactFor(0), 6));
      expect(nums[1].age(c.t), lessThan(0));
      // Último impacto: hit-stop.
      while (c.t - c.ult!.t0 < s.lastImpact(3)) {
        c.advance(5);
      }
      c.advance(5);
      expect(c.hitStop, greaterThan(0));
      final frozenT = c.t;
      c.advance(20);
      expect(c.t, frozenT); // el reloj de la escena se detuvo
      run(c, 300);
      expect(c.t, greaterThan(frozenT));
      // Termina y la pose vuelve a correr.
      run(c, s.totalMs.toDouble());
      expect(c.ult, isNull);
      expect(c.frozen, isFalse);
    });

    test('un paso nuevo durante la cinemática espera y arranca en el '
        'regreso; dos en cola la adelantan', () {
      final c = withUlt('hacha');
      final s = kUltScripts['ult_hacha']!;
      c.advance(10);
      run(c, 300);
      const later = [BattleFx(FxKind.txt, text: 'X')];
      c.addEffects(later);
      expect(c.pending, hasLength(1));
      expect(c.fx.where((e) => e.fx.text == 'X'), isEmpty);
      run(c, s.returnAt.toDouble());
      expect(c.pending, isEmpty);
      expect(c.fx.where((e) => e.fx.text == 'X'), hasLength(1));

      final d = withUlt('hacha');
      d.advance(10);
      run(d, 200);
      d.addEffects(later);
      d.addEffects(later);
      expect(d.pending, isEmpty);
      final u = d.ult!;
      expect(u.skipped, isTrue);
      expect(u.script.phaseAt(d.t - u.t0), UltPhase.recover);
      // Los números de la ULT arrancaron ya.
      expect(
          d.fx
              .where((e) => e.fx.kind == FxKind.num)
              .every((e) => e.age(d.t) >= 0),
          isTrue);
      expect(d.fx.where((e) => e.fx.text == 'X'), hasLength(2));
    });

    test('el enemigo que cae por la ULT sigue entero hasta su impacto', () {
      final s = _state('báculo');
      s.enemies.first.hp = 0;
      final c = BattleSceneController(random: math.Random(3));
      final f = frameOf(s);
      c.frame = f;
      c.addEffects(mapBattleEvents(_ultEvents('báculo'), s, f.layout.of));
      c.advance(10);
      final script = kUltScripts['ult_baculo']!;
      run(c, script.impactFor(0) - 50);
      expect(c.deathAlpha('e0'), 1);
      run(c, 700);
      expect(c.deathAlpha('e0'), isNull);
    });

    test('la cámara se acerca al lanzador y vuelve a la base', () {
      final c = withUlt('rifle');
      final s = kUltScripts['ult_rifle']!;
      c.advance(10);
      final base = c.baseView(c.frame!);
      run(c, s.buildMs - 50);
      expect(c.camera!.zoom, greaterThan(base.zoom));
      run(c, s.totalMs.toDouble());
      expect(c.camera!.zoom, base.zoom);
      expect(c.camera!.center, base.center);
    });
  });
}
