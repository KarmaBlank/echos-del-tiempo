import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/features/combat/domain/turn_order.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_sfx.dart';
import 'package:echos_del_tiempo/game_engine/data/enemies_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/features/combat/presentation/combat_strings.dart';
import 'package:flutter_test/flutter_test.dart';

// Mecánicas de jefe v0.2 → escena, HUD y sonido (docs/specs/
// battle_presentation.md § "Mecánicas de jefe", audio.md § "Mecánicas de
// jefe").

Combatant _hero(String id, {bool webbed = false}) => Combatant(
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
      webbed: webbed,
    );

Combatant _foe(String id, String type, {bool boss = false, int stance = 0, int stanceTurns = 0}) =>
    Combatant(
      id: id,
      name: kEnemies[type]!.name,
      isPlayer: false,
      hp: 100,
      maxHp: 100,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: type,
      boss: boss,
      stance: stance,
      stanceTurns: stanceTurns,
    );

BattleState _sierpe() => BattleState(boss: true, party: [
      _hero('p1'),
      _hero('p2'),
    ], enemies: [
      _foe('e0', 'sierpe', boss: true),
      _foe('e1', 'cristalHielo'),
      _foe('e2', 'cristalHielo'),
    ]);

Offset Function(String) _pos(BattleState s) {
  final ids = [...s.party.map((p) => p.id), ...s.enemies.map((e) => e.id)];
  return (id) => Offset(100.0 * ids.indexOf(id), 200);
}

List<String> _texts(List<BattleFx> fx) => [for (final f in fx) if (f.text != null) f.text!];

class _Recorder extends SfxService {
  final played = <String>[];
  @override
  void play(String id, {int delayMs = 0}) => played.add(id);
}

void main() {
  group('eventos → efectos', () {
    test('telaraña: cartel en el atrapado con el golpe; liberar; perder el turno', () {
      final s = BattleState(party: [_hero('p1', webbed: true), _hero('p2')], enemies: [
        _foe('e0', 'matriarca', boss: true),
      ]);
      final fx = mapBattleEvents(const [
        ActionEvent('e0', BattleActionKind.enemyAttack, targetId: 'p1'),
        DamageEvent('p1', 8),
        BossMechanicEvent('e0', BossMechanicPhase.webCast, targetId: 'p1'),
      ], s, _pos(s));
      final web = fx.firstWhere((f) => f.text == '¡TELARAÑA!');
      expect(web.delayMs, greaterThan(BattleFx.enemyStrikeMs));
      expect(web.color, webColor);
      final free = mapBattleEvents(const [
        ActionEvent('p2', BattleActionKind.attack, targetId: 'p1'),
        BossMechanicEvent('p2', BossMechanicPhase.webFreed, targetId: 'p1'),
      ], s, _pos(s));
      expect(_texts(free), contains('¡LIBRE!'));
      expect(_texts(mapBattleEvents(const [
        BossMechanicEvent('p1', BossMechanicPhase.webSkip, targetId: 'p1'),
      ], s, _pos(s))), contains('¡ATRAPADO!'));
      expect(_texts(mapBattleEvents(const [
        BossMechanicEvent('p1', BossMechanicPhase.webStruggle, targetId: 'p1'),
      ], s, _pos(s))), contains('FORCEJEA ½'));
    });

    test('campo helado: VEL −% en cada aliado; deshielo; cristal roto y rearmado', () {
      final s = _sierpe();
      final fx = mapBattleEvents(const [
        BossMechanicEvent('e0', BossMechanicPhase.frost, value: 0.2),
      ], s, _pos(s));
      expect(_texts(fx).where((t) => t == 'VEL −20%'), hasLength(2));
      expect(_texts(mapBattleEvents(const [BossMechanicEvent('e0', BossMechanicPhase.thaw)], s, _pos(s))),
          everyElement('DESHIELO'));
      final sh = mapBattleEvents(const [
        BossMechanicEvent('e0', BossMechanicPhase.shatter, targetId: 'e1'),
      ], s, _pos(s));
      expect(sh.any((f) => f.kind == FxKind.shatter), isTrue);
      expect(_texts(sh), contains('CRISTAL ROTO'));
      expect(_texts(mapBattleEvents(const [
        BossMechanicEvent('e0', BossMechanicPhase.reform, targetId: 'e1'),
      ], s, _pos(s))), contains('SE REFORMA'));
    });

    test('postura: cartel grande con la postura nueva; bloqueo con el golpe', () {
      final s = BattleState(party: [_hero('p1')], enemies: [_foe('e0', 'caballeroHueco', boss: true, stance: 2)]);
      final fx = mapBattleEvents(const [
        BossMechanicEvent('e0', BossMechanicPhase.stanceShift, value: 2),
      ], s, _pos(s));
      final tag = fx.firstWhere((f) => f.kind == FxKind.tag);
      expect([tag.text, tag.color, tag.big], ['POSTURA: ESPADA', stanceSwordColor, true]);
      final hit = mapBattleEvents(const [
        ActionEvent('p1', BattleActionKind.attack, targetId: 'e0'),
        BossMechanicEvent('e0', BossMechanicPhase.resisted, value: 0.7),
        DamageEvent('e0', 6),
      ], s, _pos(s));
      expect(_texts(hit), contains('BLOQUEA −70%'));
    });

    test('ULT nuevas: guion, color y elemento propios', () {
      for (final id in ['eult_nido', 'eult_aliento', 'eult_juicio']) {
        expect(isEnemyUlt(id), isTrue, reason: id);
        expect(kEnemyUltColors, contains(id));
      }
      expect(ultScriptFor('eult_nido').style, UltStyle.venomNest);
      expect(ultScriptFor('eult_aliento').focus, UltFocus.group);
      expect(ultScriptFor('eult_juicio').focus, UltFocus.single);
      expect(enemyUltElement('eult_aliento'), FxElement.freeze);
    });
  });

  group('escena', () {
    test('los cristales van delante del jefe, entre él y el grupo, y no tienen turno', () {
      final s = _sierpe();
      final l = BattleLayout.compute(s, null);
      final boss = l.of('e0'), c1 = l.of('e1'), c2 = l.of('e2'), p = l.of('p1');
      for (final c in [c1, c2]) {
        expect(c.dx, greaterThan(boss.dx));
        expect(c.dx, lessThan(p.dx));
      }
      expect(c1.dy, lessThan(c2.dy));
      expect(predictTurns(s, 10), everyElement(isNot(anyOf('e1', 'e2'))));
      expect(isPassiveAdd(s.enemies[1]), isTrue);
    });

    test('nivel de escarcha y la línea de tiempo con la velocidad perdida', () {
      final s = _sierpe();
      expect(BattleScenePainter.frostLevel(s), 0);
      s.party[0].effects = [
        const TimedEffect(sourceId: 'escarcha', stat: BuffStat.speed, value: -0.3, turns: 99),
      ];
      expect(BattleScenePainter.frostLevel(s), closeTo(0.3, 1e-9));
      expect(turnInterval(s.party[0]), closeTo(100 / (10 * 0.7), 1e-9));
    });

    test('cartel de entrada del jefe con su título', () {
      final scene = BattleSceneController();
      final s = _sierpe();
      scene.sync(battleId: 1, eventSeq: 0, events: const [], state: s, layout: BattleLayout.compute(s, null));
      expect(scene.intro?.name, 'Sierpe de Escarcha');
      expect(scene.intro?.title, kEnemies['sierpe']!.title);
      scene.advance(BossIntro.durationMs + 50.0);
      expect(scene.intro, isNull);
      // Un combate común no tiene cartel.
      final common = BattleState(party: [_hero('p1')], enemies: [_foe('e0', 'lobo')]);
      final sc2 = BattleSceneController();
      sc2.sync(battleId: 2, eventSeq: 0, events: const [], state: common, layout: BattleLayout.compute(common, null));
      expect(sc2.intro, isNull);
      scene.dispose();
      sc2.dispose();
    });
  });

  group('HUD', () {
    test('chips de cada mecánica con cómo contrarrestarla', () {
      final web = BattleState(party: [_hero('p1', webbed: true), _hero('p2')], enemies: [
        _foe('e0', 'matriarca', boss: true),
      ]);
      final w = bossMechanicChips(fallbackCombatStrings(), web).single;
      expect(w.long, contains('1 atrapado'));
      expect(w.tip, contains('Liberar'));
      expect(combatantChips(fallbackCombatStrings(), web.party[0]).map((c) => c.short), contains('Telaraña'));

      final ice = _sierpe();
      ice.party[0].effects = [
        const TimedEffect(sourceId: 'escarcha', stat: BuffStat.speed, value: -0.2, turns: 99),
      ];
      final f = bossMechanicChips(fallbackCombatStrings(), ice).single;
      expect(f.long, 'Campo Helado: 2 cristales · VEL −20%');
      expect(f.tip, contains('cristales'));
      final slow = combatantChips(fallbackCombatStrings(), ice.party[0]).firstWhere((c) => c.short == '▼VEL');
      expect(slow.long, '▼VEL −20%');
      expect(slow.tip, contains('Campo Helado'));

      final knight = BattleState(party: [_hero('p1')], enemies: [
        _foe('e0', 'caballeroHueco', boss: true, stance: 1, stanceTurns: 1),
      ]);
      final k = bossMechanicChips(fallbackCombatStrings(), knight).single;
      expect(k.short, 'ESCUDO');
      expect(k.long, contains('cambia en su próximo turno'));
      knight.enemies[0].vulnerable = 2;
      expect(bossMechanicChips(fallbackCombatStrings(), knight).single.long, contains('rota'));
      expect(bossMechanicChips(fallbackCombatStrings(), BattleState(party: [_hero('p1')], enemies: [_foe('e0', 'lobo')])), isEmpty);
    });
  });

  group('sonido', () {
    test('cada mecánica suena y el jefe tiene cartel de entrada', () {
      final rec = _Recorder();
      final sfx = SessionSfx(rec, localId: 'p1')..battle = _sierpe();
      final ids = [
        for (final c in sfx.battleSounds(const [
          BossMechanicEvent('e0', BossMechanicPhase.frost, value: 0.1),
          BossMechanicEvent('e0', BossMechanicPhase.thaw),
          BossMechanicEvent('e0', BossMechanicPhase.webCast, targetId: 'p1'),
          BossMechanicEvent('p2', BossMechanicPhase.webFreed, targetId: 'p1'),
          BossMechanicEvent('p1', BossMechanicPhase.webSkip, targetId: 'p1'),
          BossMechanicEvent('e0', BossMechanicPhase.shatter, targetId: 'e1'),
          BossMechanicEvent('e0', BossMechanicPhase.stanceShift, value: 2),
          BossMechanicEvent('e0', BossMechanicPhase.resisted, value: 0.7),
        ]))
          c.id,
      ];
      expect(ids, containsAll([Sfx.frost, Sfx.thaw, Sfx.webCast, Sfx.webFree, Sfx.webStuck,
          Sfx.crystalBreak, Sfx.stanceShift, Sfx.stanceBlock]));
      for (final id in [...ids, Sfx.bossIntro, Sfx.crystalReform]) {
        expect(kSfxCatalog, contains(id), reason: id);
      }
    });

    test('jefes nuevos más fuertes que los comunes; ULT nuevas con tres partes', () {
      for (final b in ['matriarca', 'sierpe', 'caballeroHueco']) {
        expect(kSfxCatalog[Sfx.enemy(b)]!.peak, SfxLevel.enemyBoss, reason: b);
      }
      for (final c in ['arana', 'lobo', 'murcielagoHielo', 'elementalEscarcha', 'esqueleto', 'caballeroCaido']) {
        expect(kSfxCatalog[Sfx.enemy(c)]!.peak, SfxLevel.enemy, reason: c);
        expect(kSfxCatalog, contains(Sfx.enemyHit(c)));
      }
      for (final u in ['eult_nido', 'eult_aliento', 'eult_juicio']) {
        for (final part in Sfx.ultParts) {
          expect(kSfxCatalog, contains(Sfx.ult(u, part)), reason: '$u.$part');
        }
      }
    });
  });
}
