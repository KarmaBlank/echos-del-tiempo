import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_recipes.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/particles.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/weapon_overlay.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/loot_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Tipos de arma de loot v2 (docs/specs/loot.md § 8.1).
const _newTypes = ['lanza', 'varita', 'ballesta', 'dagas'];

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

/// Corre la parte "una vez" de la ULT de [type] de 0 al final.
({ParticleSystem p, List<int> hitStops, UltCinematic u}) _runTick(String type,
    {int targets = 3}) {
  final sk = kAllUltimates[type]!;
  final script = ultScriptFor(sk.id);
  final u = UltCinematic(
      BattleFx(FxKind.ult,
          ult: UltFx(name: sk.name, casterName: 'A', bulwark: false, ultId: sk.id, script: script)),
      0);
  final st = UltStage(
    caster: const Offset(300, 120),
    targets: [for (var i = 0; i < targets; i++) Offset(120 + i * 30.0, 110 + i * 6.0)],
    party: const [Offset(300, 120)],
  );
  final p = ParticleSystem(math.Random(1));
  final stops = <int>[];
  for (var a = 0.0; a <= script.totalMs; a += 10) {
    UltDirector.tick(u, a, st, p, stops.add);
  }
  return (p: p, hitStops: stops, u: u);
}

void main() {
  group('ULT de los tipos nuevos', () {
    test('cada tipo nuevo tiene ULT en la UI (kAllUltimates) y su guion', () {
      for (final t in _newTypes) {
        final sk = kAllUltimates[t];
        expect(sk, isNotNull, reason: t);
        expect(kUltScripts, contains(sk!.id), reason: t);
      }
      final styles = {for (final t in _newTypes) ultScriptFor(kAllUltimates[t]!.id).style};
      expect(styles, {UltStyle.spearRain, UltStyle.arcaneStorm, UltStyle.volley, UltStyle.thousandCuts});
      // Ningún estilo nuevo se repite con los del prototipo.
      for (final t in kUltimates.keys) {
        expect(styles, isNot(contains(ultScriptFor(kUltimates[t]!.id).style)));
      }
    });

    test('impactos, golpes previos y virotes chicos caen en la descarga', () {
      for (final t in _newTypes) {
        final s = ultScriptFor(kAllUltimates[t]!.id);
        for (var i = 0; i < 4; i++) {
          expect(s.phaseAt(s.impactFor(i).toDouble()), UltPhase.release, reason: '$t #$i');
        }
        expect(s.totalMs, inInclusiveRange(2000, 3500));
        expect(s.returnAt, lessThanOrEqualTo(2100));
        expect(s.hitStopMs, greaterThan(0), reason: t);
      }
      final cuts = ultScriptFor('ult_dagas');
      expect(cuts.preHitsMs, hasLength(7));
      for (final h in cuts.preHitsMs) {
        expect(cuts.phaseAt(h.toDouble()), UltPhase.release);
        expect(h, lessThan(cuts.impactMs));
      }
      // A uno: Andanada y Danza (cámara en la línea / el objetivo).
      expect(ultScriptFor('ult_ballesta').focus, UltFocus.line);
      expect(ultScriptFor('ult_dagas').focus, UltFocus.single);
      expect(kAllUltimates['ballesta']!.allTargets, isFalse);
      expect(kAllUltimates['dagas']!.allTargets, isFalse);
    });

    for (final t in _newTypes) {
      test('$t: partículas, un hit-stop en el último impacto y dibujo en '
          'todas las fases', () {
        final sk = kAllUltimates[t]!;
        final s = ultScriptFor(sk.id);
        final n = sk.allTargets ? 3 : 1;
        final r = _runTick(t, targets: n);
        expect(r.hitStops, [s.hitStopMs], reason: t);
        for (var i = 0; i < n; i++) {
          expect(r.u.done, contains('imp$i'));
        }
        expect(r.p.particles, isNotEmpty);
        expect(UltDirector.element(s.style), isNotNull);
        // Dibujo: preparación, descarga, impacto y regreso sin errores.
        final st = UltStage(
          caster: const Offset(300, 120),
          targets: [for (var i = 0; i < n; i++) Offset(120 + i * 30.0, 110)],
          party: const [Offset(300, 120)],
        );
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        for (var a = 0.0; a <= s.totalMs; a += 25) {
          UltDirector.paintWorld(c, r.u, a, st, const Rect.fromLTWH(0, 0, 480, 260));
        }
        rec.endRecording().dispose();
      });
    }

    test('mapeo de eventos: los números caen en el impacto del guion', () {
      for (final t in _newTypes) {
        final sk = kAllUltimates[t]!;
        final script = ultScriptFor(sk.id);
        final st = BattleState(party: [_hero('p1', t)], enemies: [_foe('e0'), _foe('e1')]);
        final fx = mapBattleEvents([
          UltimateUsedEvent('p1', sk.name),
          ActionEvent('p1', BattleActionKind.ultimate, skillId: sk.id, targetId: 'e0'),
          const DamageEvent('e0', 40),
          if (sk.allTargets) const DamageEvent('e1', 40),
        ], st, (id) => Offset(10.0 * id.codeUnitAt(1), 100));
        final ult = fx.firstWhere((f) => f.kind == FxKind.ult);
        expect(ult.ult!.ultId, sk.id);
        expect(ult.color, skillColor(sk.id));
        expect(ult.color, isNot(fxWhite));
        final nums = fx.where((f) => f.kind == FxKind.num).toList();
        expect(nums.first.delayMs, script.impactFor(0));
      }
    });
  });

  group('armas nuevas: dibujo y efectos', () {
    test('cada tipo de arma del catálogo tiene arte; los nuevos, el suyo', () {
      for (final w in kWeapons.values) {
        expect(WeaponOverlay.kWeaponArt, contains(w.type), reason: w.type);
      }
      expect(WeaponOverlay.artFor('maga', 'lanza'), WeaponArt.spear);
      expect(WeaponOverlay.artFor('guerrero', 'varita'), WeaponArt.wand);
      expect(WeaponOverlay.artFor('paladin', 'ballesta'), WeaponArt.crossbow);
      expect(WeaponOverlay.artFor('tirador', 'dagas'), WeaponArt.daggers);
      // Sin tipo: el de la clase (prototipo).
      expect(WeaponOverlay.artFor('maga', null), WeaponArt.staff);
      expect(WeaponOverlay.hasShield('guerrero', 'maza+escudo'), isTrue);
      expect(WeaponOverlay.hasShield('paladin', 'lanza'), isFalse);
      expect(WeaponOverlay.hasShield('paladin', null), isTrue);
    });

    test('el dibujo de cada arte es distinto (píxeles)', () async {
      Future<List<int>> render(String type) async {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec)..translate(16, 28);
        WeaponOverlay.draw(c, 'guerrero', type);
        final img = await rec.endRecording().toImage(32, 32);
        final data = await img.toByteData();
        img.dispose();
        return data!.buffer.asUint8List().toList();
      }

      final seen = <String>{};
      for (final t in ['espada', 'báculo', 'martillo+escudo', 'maza+escudo', 'rifle', ..._newTypes]) {
        final px = await render(t);
        expect(px.any((b) => b != 0), isTrue, reason: t);
        expect(seen.add(px.join(',')), isTrue, reason: '$t repite dibujo');
      }
    });

    test('proyectil y tajo por tipo de arma', () {
      expect(projStyleFor('ballesta', FxElement.phys), ProjStyle.bolt);
      expect(projStyleFor('varita', FxElement.arcane), ProjStyle.missile);
      expect(projStyleFor('arco', FxElement.phys), ProjStyle.arrow);
      expect(projStyleFor('báculo', FxElement.burn), ProjStyle.orb);
      expect(slashStyleFor('lanza'), SlashStyle.thrust);
      expect(slashStyleFor('dagas'), SlashStyle.twin);
      expect(slashStyleFor('espada'), SlashStyle.cross);
      expect(kRangedWeaponTypes, containsAll(['varita', 'ballesta']));
      expect(kRangedWeaponTypes, isNot(contains('lanza')));
    });

    test('el ataque lleva el tipo de arma al proyectil y al tajo', () {
      for (final (t, ranged) in [('ballesta', true), ('varita', true), ('lanza', false), ('dagas', false)]) {
        final st = BattleState(party: [_hero('p1', t)], enemies: [_foe('e0')]);
        final fx = mapBattleEvents([
          const ActionEvent('p1', BattleActionKind.attack, targetId: 'e0'),
          const DamageEvent('e0', 12),
        ], st, (id) => Offset(10.0 * id.codeUnitAt(1), 100));
        final proj = fx.where((f) => f.kind == FxKind.proj);
        expect(proj.isNotEmpty, ranged, reason: t);
        if (ranged) expect(proj.single.weapon, t);
        expect(fx.singleWhere((f) => f.kind == FxKind.slash).weapon, t);
      }
    });

    test('las 10 habilidades y 4 ULT nuevas tienen color propio', () {
      for (final id in [
        'perforar', 'barrido', 'empalar', 'misil', 'escarchaFugaz', 'rayoArcano', //
        'virote', 'viroteIgneo', 'tajoGemelo', 'abanico',
        for (final t in _newTypes) kAllUltimates[t]!.id,
      ]) {
        expect(kSkillColors, contains(id), reason: id);
        expect(kSkillsById, contains(id), reason: id);
      }
    });
  });

  group('sonido de las armas nuevas y del loot', () {
    String sig(String id) => kSfxCatalog[id]!
        .voices
        .map((v) => '${v.wave}:${v.frequency}:${v.duration}:${v.delay}')
        .join(',');

    test('arranque e impacto propios de cada tipo nuevo, distintos de todos', () {
      final starts = {for (final t in _newTypes) kWeaponStartSfx[t]!};
      final impacts = {for (final t in _newTypes) kWeaponImpactSfx[t]!};
      expect(starts, {Sfx.swingSpear, Sfx.swingDaggers, Sfx.shotWand, Sfx.shotCrossbow});
      expect(impacts, {Sfx.impactPierce, Sfx.impactDagger, Sfx.impactWand, Sfx.impactBolt});
      final all = {
        ...kWeaponStartSfx.values,
        ...kWeaponImpactSfx.values,
      };
      final sigs = {for (final id in all) sig(id)};
      expect(sigs, hasLength(all.length));
      for (final id in [...starts, ...impacts]) {
        expect(kSfxCatalog[id]!.length, lessThan(0.4), reason: id);
      }
    });

    test('las 4 ULT nuevas: preparación, descarga e impacto, distintas', () {
      for (final t in _newTypes) {
        final id = kAllUltimates[t]!.id;
        for (final part in Sfx.ultParts) {
          expect(kSfxCatalog, contains(Sfx.ult(id, part)), reason: '$id.$part');
        }
      }
      for (final part in Sfx.ultParts) {
        final sigs = {for (final sk in kAllUltimates.values) sig(Sfx.ult(sk.id, part))};
        expect(sigs, hasLength(kAllUltimates.length), reason: part);
      }
    });

    test('un sonido por cada nombre del filtro, levantar y el haz', () {
      for (final name in kLootFilterSounds) {
        expect(kSfxCatalog, contains(Sfx.loot(name)), reason: name);
      }
      expect(kSfxCatalog, contains(Sfx.lootPickup));
      expect(kSfxCatalog, contains(Sfx.lootBeam));
      final sigs = {
        for (final n in kLootFilterSounds) sig(Sfx.loot(n)),
        sig(Sfx.lootPickup),
        sig(Sfx.lootBeam),
      };
      expect(sigs, hasLength(kLootFilterSounds.length + 2));
      expect(kSfxCatalog[Sfx.lootBeam]!.peak, SfxLevel.lootBeam);
    });
  });
}
