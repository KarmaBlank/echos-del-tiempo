import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/duo_cinematic.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/game_engine/data/weapon_duals_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Combatant _hero(String id, String cls, String weapon) => Combatant(
      id: id,
      name: id.toUpperCase(),
      isPlayer: true,
      hp: 50,
      maxHp: 50,
      speed: 10,
      attack: 10,
      critChance: 0,
      weaponType: weapon,
      classId: cls,
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

BattleState _state() => BattleState(
      party: [_hero('p1', 'tirador', 'arco'), _hero('p2', 'maga', 'báculo')],
      enemies: [_foe('e0'), _foe('e1'), _foe('e2')],
    );

List<BattleEvent> _duoEvents(String? id) => [
      ActionEvent('p1', BattleActionKind.dual,
          skillId: id, partnerId: 'p2', allTargets: true),
      const DamageEvent('e0', 40),
      const DamageEvent('e1', 41, critical: true),
      const DamageEvent('e2', 42),
      const StatusAppliedEvent('e0', StatusKind.charged, 1),
    ];

SceneFrame _frame(BattleState s) {
  final g = SceneGeometry.fit(const Size(1280, 418));
  return SceneFrame(
      battle: s,
      geometry: g,
      layout: BattleLayout.compute(s, null, vw: g.virtualWidth));
}

void main() {
  group('guion del dúo', () {
    test('dura 1.2–1.6 s, impacto dentro de la descarga', () {
      const s = kDuoScript;
      expect(s.style, UltStyle.duo);
      expect(s.totalMs, inInclusiveRange(1200, 1600));
      expect(s.impactMs, greaterThan(s.buildMs));
      expect(s.lastImpact(4), lessThan(s.returnAt));
      expect(s.impactFor(1) - s.impactFor(0), s.staggerMs);
      expect(s.hitStopMs, greaterThan(0));
    });

    test('tarjeta partida: entra deslizándose y se va antes de la descarga',
        () {
      expect(duoCardPose(-1).hidden, isTrue);
      final start = duoCardPose(0);
      expect(start.left, 0);
      expect(start.right, lessThan(start.left + 0.01));
      final mid = duoCardPose(400);
      expect(mid.left, 1);
      expect(mid.right, closeTo(1, 1e-9));
      expect(mid.banner, 1);
      expect(mid.alpha, 1);
      expect(mid.speedLines, isTrue);
      // La derecha va detrás de la izquierda mientras entran.
      final half = duoCardPose(120);
      expect(half.right, lessThan(half.left));
      expect(duoCardPose(kDuoCardMs - 50.0).alpha, lessThan(1));
      expect(duoCardPose(kDuoCardMs.toDouble()).hidden, isTrue);
      expect(kDuoCardMs, lessThanOrEqualTo(kDuoScript.impactMs));
    });

    test('REDUCIR MOVIMIENTO: sin deslizar, fundido corto, sin líneas', () {
      for (final a in [0.0, 40.0, 120.0, 400.0]) {
        final p = duoCardPose(a, reduceMotion: true);
        expect(p.left, 1, reason: '$a');
        expect(p.right, 1, reason: '$a');
        expect(p.speedLines, isFalse);
      }
      expect(duoCardPose(0, reduceMotion: true).alpha, 0);
      expect(duoCardPose(75, reduceMotion: true).alpha, closeTo(0.5, 1e-9));
      expect(duoCardPose(300, reduceMotion: true).alpha, 1);
      expect(duoCardPose(kDuoCardMs.toDouble(), reduceMotion: true).hidden,
          isTrue);
    });

    test('las estelas convergen en el impacto', () {
      expect(duoTrailProgress(0), 0);
      expect(duoTrailProgress(kDuoScript.buildMs.toDouble()), 0);
      expect(duoTrailProgress(kDuoScript.impactMs.toDouble()), 1);
      expect(duoTrailProgress(825), inExclusiveRange(0, 0.5)); // acelera
    });
  });

  group('eventos → efectos del dúo', () {
    test('dúo de armas: cinemática con los dos, armas, color y elemento', () {
      final s = _state();
      final f = _frame(s);
      final fx = mapBattleEvents(_duoEvents('w_flechaArcana'), s, f.layout.of);
      final ult = fx.singleWhere((e) => e.kind == FxKind.ult);
      final u = ult.ult!;
      expect(u.duo, isTrue);
      expect(u.name, 'Flecha Arcana Gemela');
      expect(u.casterName, 'P1');
      expect(u.partnerName, 'P2');
      expect(u.casterWeapon, 'arco');
      expect(u.partnerWeapon, 'báculo');
      expect(u.script, same(kDuoScript));
      expect(u.targets, ['e0', 'e1', 'e2']);
      expect(ult.color, kDualColors['w_flechaArcana']);
      expect(ult.el, elementOfStatus(StatusKind.charged));
      // Los dos se lanzan al descargar.
      final acts = fx.where((e) => e.kind == FxKind.act).toList();
      expect(acts.map((e) => e.who), containsAll(['p1', 'p2']));
      expect(acts.every((e) => e.delayMs >= kDuoScript.buildMs), isTrue);
      // Números pesados en el impacto del guion + ×2 DÚO por golpeado.
      final nums = fx.where((e) => e.kind == FxKind.num).toList();
      expect(nums, hasLength(3));
      expect(nums.every((n) => n.heavy), isTrue);
      expect([for (final n in nums) n.delayMs],
          [for (var i = 0; i < 3; i++) kDuoScript.impactFor(i)]);
      final tags = fx.where((e) => e.kind == FxKind.txt && e.text == '×2 DÚO');
      expect(tags, hasLength(3));
      // Sin proyectiles: las estelas son de la cinemática.
      expect(fx.where((e) => e.kind == FxKind.proj), isEmpty);
    });

    test('dúo de clase sin id (host v0.8.2): el de clase del par', () {
      final s = _state();
      final f = _frame(s);
      final u = mapBattleEvents(_duoEvents(null), s, f.layout.of)
          .singleWhere((e) => e.kind == FxKind.ult)
          .ult!;
      expect(u.name, 'Lluvia Estelar'); // maga+tirador
      expect(u.ultId, 'maga+tirador');
    });

    test('todos los dúos tienen color', () {
      for (final MapEntry(:key, :value) in kAllDuals.entries) {
        expect(dualColor(key, value), isNotNull);
        expect(kDualColors.containsKey(key), isTrue, reason: key);
      }
    });
  });

  group('escena con un dúo', () {
    BattleSceneController withDuo({bool reduce = false}) {
      final s = _state();
      final c = BattleSceneController(random: math.Random(5))
        ..options = SceneOptions(reduceMotion: reduce, shake: !reduce);
      final f = _frame(s);
      c.frame = f;
      c.addEffects(mapBattleEvents(_duoEvents('w_flechaArcana'), s, f.layout.of));
      return c;
    }

    test('ocupa la escena hasta el regreso y se puede saltear', () {
      final c = withDuo();
      c.advance(10);
      expect(c.ult, isNotNull);
      expect(c.ult!.style, UltStyle.duo);
      expect(c.holding, isTrue);
      expect(c.ultStage()!.partner, isNotNull);
      c.advance(200);
      expect(c.skipDuo(), isTrue);
      expect(c.ult!.skipped, isTrue);
      expect(c.holding, isFalse);
      // Los números ya arrancaron.
      final nums = c.fx.where((e) => e.fx.kind == FxKind.num);
      expect(nums.every((n) => n.age(c.t) >= 0), isTrue);
      expect(c.skipDuo(), isFalse);
    });

    test('termina solo a los 1.6 s (con hit-stop) y se pinta sin errores',
        () {
      for (final reduce in [false, true]) {
        final c = withDuo(reduce: reduce);
        for (var t = 0; t < 2200; t += 16) {
          c.advance(16);
          if (t % 160 == 0) {
            final r = ui.PictureRecorder();
            final canvas = Canvas(r);
            BattleScenePainter(c).paint(canvas, const Size(1280, 418));
            BattleOverlayPainter(c).paint(canvas, const Size(1280, 418));
            r.endRecording().dispose();
          }
        }
        expect(c.ult, isNull);
        if (reduce) expect(c.particles.shake, 0);
      }
    });
  });
}
