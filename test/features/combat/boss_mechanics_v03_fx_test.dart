import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/features/combat/domain/turn_order.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_hud.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
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
import 'package:flutter_test/flutter_test.dart';

// Jefes v0.3 → escena, HUD y sonido (docs/specs/battle_presentation.md
// § "Mecánicas de jefe v0.3", audio.md § "Mecánicas de jefe v0.3").

Combatant _hero(String id, {bool marked = false, bool defending = false}) => Combatant(
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
      voidMarked: marked,
      defending: defending,
    );

Combatant _foe(String id, String type, {bool boss = false, int lava = 0, int phase = 0, int actions = 0}) =>
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
      lava: lava,
      phase: phase,
      actions: actions,
    );

BattleState _boss(String type, {List<String> adds = const [], int lava = 0, int phase = 0}) => BattleState(
      boss: true,
      party: [_hero('p1'), _hero('p2')],
      enemies: [
        _foe('e0', type, boss: true, lava: lava, phase: phase),
        for (var i = 0; i < adds.length; i++) _foe('e${i + 1}', adds[i]),
      ],
    );

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
    test('ecos: aparecen con arco y cartel; el golpe a un eco dice ECO ×0.5', () {
      final s = _boss('hechicera', adds: ['ecoHechicera', 'ecoHechicera']);
      final fx = mapBattleEvents(const [
        BossMechanicEvent('e0', BossMechanicPhase.echoSummon, targetId: 'e1'),
      ], s, _pos(s));
      expect(_texts(fx), contains('¡ECO!'));
      expect(fx.any((f) => f.kind == FxKind.arc && f.color == echoColor), isTrue);
      final hit = mapBattleEvents(const [
        ActionEvent('p1', BattleActionKind.attack, targetId: 'e1'),
        BossMechanicEvent('e1', BossMechanicPhase.echoResist, value: 0.5),
        DamageEvent('e1', 6),
      ], s, _pos(s));
      expect(_texts(hit), contains('ECO ×0.5'));
    });

    test('lava: erupción bajo cada aliado con el golpe; quema al que se defiende; se enfría', () {
      final s = _boss('bestiaMagma');
      final rise = mapBattleEvents(const [
        ActionEvent('e0', BattleActionKind.enemyAttack, targetId: 'p1'),
        DamageEvent('p1', 10),
        BossMechanicEvent('e0', BossMechanicPhase.lavaRise, value: 2),
      ], s, _pos(s));
      final bursts = rise.where((f) => f.kind == FxKind.lavaBurst).toList();
      expect(bursts, hasLength(2));
      expect(bursts.first.delayMs, greaterThan(BattleFx.enemyStrikeMs));
      expect(_texts(rise), contains('¡LAVA 2 TURNOS!'));
      final burn = mapBattleEvents(const [
        BossMechanicEvent('e0', BossMechanicPhase.lavaBurn, targetId: 'p1', value: 2),
      ], s, _pos(s));
      expect(_texts(burn), contains('¡LAVA! Q+2'));
      expect(burn.where((f) => f.kind == FxKind.lavaBurst), hasLength(1));
      expect(_texts(mapBattleEvents(const [BossMechanicEvent('e0', BossMechanicPhase.lavaFade)], s, _pos(s))),
          contains('LA LAVA SE ENFRÍA'));
    });

    test('séquito: invocación e INMUNE con el golpe', () {
      final s = _boss('espectroCoronado', adds: ['siervoEspectral']);
      expect(_texts(mapBattleEvents(const [
        BossMechanicEvent('e0', BossMechanicPhase.summon, targetId: 'e1'),
      ], s, _pos(s))), contains('¡SIERVO!'));
      final imm = mapBattleEvents(const [
        ActionEvent('p1', BattleActionKind.skill, skillId: 'chispa', targetId: 'e0'),
        DamageEvent('e0', 6),
        BossMechanicEvent('e0', BossMechanicPhase.immune),
      ], s, _pos(s));
      final t = imm.firstWhere((f) => f.text == 'INMUNE');
      expect(t.color, immuneColor);
    });

    test('marca: retícula en el marcado; el golpe ×2; protegido o anulado', () {
      final s = _boss('centinela');
      final cast = mapBattleEvents(const [
        BossMechanicEvent('e0', BossMechanicPhase.markCast, targetId: 'p1'),
      ], s, _pos(s));
      expect(cast.any((f) => f.kind == FxKind.reticle && f.color == voidMarkColor), isTrue);
      expect(_texts(cast), contains('¡MARCADO!'));
      final hit = mapBattleEvents(const [
        ActionEvent('e0', BattleActionKind.enemyHeavy, targetId: 'p1'),
        BossMechanicEvent('e0', BossMechanicPhase.markHit, targetId: 'p1', value: 2),
        DamageEvent('p1', 40),
      ], s, _pos(s));
      final x2 = hit.firstWhere((f) => f.text == 'MARCA ×2');
      expect(x2.delayMs, BattleFx.enemyStrikeMs);
      expect(_texts(mapBattleEvents(const [
        ActionEvent('e0', BattleActionKind.enemyAttack, targetId: 'p2'),
        BossMechanicEvent('p2', BossMechanicPhase.markGuarded, targetId: 'p1'),
      ], s, _pos(s))), contains('¡PROTEGE LA MARCA!'));
      expect(_texts(mapBattleEvents(const [
        ActionEvent('e0', BattleActionKind.enemyAttack, targetId: 'p1'),
        BossMechanicEvent('p1', BossMechanicPhase.markGuarded, targetId: 'p1'),
      ], s, _pos(s))), contains('MARCA ANULADA'));
    });

    test('Devorador: cinemática de transformación, destello y cartel FASE 2 después del golpe', () {
      final s = _boss('devorador', phase: 2);
      final fx = mapBattleEvents(const [
        ActionEvent('p1', BattleActionKind.attack, targetId: 'e0'),
        DamageEvent('e0', 50),
        BossMechanicEvent('e0', BossMechanicPhase.phaseShift, value: 2),
      ], s, _pos(s));
      final tr = fx.firstWhere((f) => f.kind == FxKind.transform);
      expect(tr.color, phaseColor);
      expect(tr.durationMs, BattleFx.transformMs);
      final tag = fx.firstWhere((f) => f.kind == FxKind.tag);
      expect([tag.text, tag.big], ['FASE 2', true]);
      expect(tag.delayMs, greaterThan(tr.delayMs + BattleFx.transformFlashMs));
      expect(fx.any((f) => f.kind == FxKind.flash && f.color == phaseColor), isTrue);
    });

    test('esquiva de un común', () {
      final s = BattleState(party: [_hero('p1')], enemies: [_foe('e0', 'ecoSombra')]);
      expect(_texts(mapBattleEvents(const [
        ActionEvent('p1', BattleActionKind.attack, targetId: 'e0'),
        BossMechanicEvent('e0', BossMechanicPhase.evaded),
        DamageEvent('e0', 3),
      ], s, _pos(s))), contains('¡ESQUIVA!'));
    });

    test('ULT nuevas: guion de grupo, color y elemento propios', () {
      const ults = {
        'eult_coro': UltStyle.echoChorus,
        'eult_erupcion': UltStyle.totalEruption,
        'eult_lamento': UltStyle.eternalLament,
        'eult_colapsoVacio': UltStyle.voidCollapse,
      };
      for (final e in ults.entries) {
        expect(isEnemyUlt(e.key), isTrue, reason: e.key);
        expect(kEnemyUltColors, contains(e.key));
        expect(ultScriptFor(e.key).style, e.value);
        expect(ultScriptFor(e.key).focus, UltFocus.group);
      }
      expect(enemyUltElement('eult_erupcion'), FxElement.burn);
      expect(enemyUltElement('eult_lamento'), FxElement.freeze);
    });
  });

  group('escena', () {
    test('lava, inmunidad, ecos y el sprite de la fase 2', () {
      final lava = _boss('bestiaMagma', lava: 2);
      expect(BattleScenePainter.lavaTurns(lava), 2);
      expect(BattleScenePainter.lavaTurns(_boss('bestiaMagma')), 0);
      final court = _boss('espectroCoronado', adds: ['siervoEspectral']);
      expect(BattleScenePainter.immuneNow(court, court.enemies[0]), isTrue);
      court.enemies[1].hp = 0;
      expect(BattleScenePainter.immuneNow(court, court.enemies[0]), isFalse);
      final echoes = _boss('hechicera', adds: ['ecoHechicera']);
      expect(BattleScenePainter.isEcho(echoes.enemies[1]), isTrue);
      expect(BattleScenePainter.isEcho(echoes.enemies[0]), isFalse);
      // Los ecos y siervos tienen turno (no son cristales).
      expect(isPassiveAdd(echoes.enemies[1]), isFalse);
      expect(predictTurns(echoes, 6), contains('e1'));
      // Sin sprites, el id es el tipo.
      const GameSprites? none = null;
      expect(none.enemySpriteId('devorador', 2), 'devorador');
      // Los siervos van en las posiciones de acompañantes (no delante).
      final l = BattleLayout.compute(court, null);
      expect(l.of('e1'), isNot(l.of('e0')));
    });

    test('cartel de entrada de cada jefe nuevo con su título', () {
      for (final b in ['hechicera', 'bestiaMagma', 'espectroCoronado', 'centinela']) {
        final scene = BattleSceneController();
        final s = _boss(b);
        scene.sync(battleId: 1, eventSeq: 0, events: const [], state: s, layout: BattleLayout.compute(s, null));
        expect(scene.intro?.title, kEnemies[b]!.title, reason: b);
        scene.dispose();
      }
    });
  });

  group('HUD', () {
    test('chips de cada mecánica con cómo contrarrestarla', () {
      final ech = _boss('hechicera', adds: ['ecoHechicera', 'ecoHechicera']);
      final e = bossMechanicChips(ech).single;
      expect(e.long, contains('Ecos: 2 vivos'));
      expect(e.tip, contains('concentrá'));
      ech.enemies[1].hp = 0;
      ech.enemies[0].mechTurns = 1;
      expect(bossMechanicChips(ech).single.long, contains('vuelven en 2 turnos'));

      final lava = _boss('bestiaMagma', lava: 2);
      expect(bossMechanicChips(lava).single.short, 'LAVA 2');
      expect(bossMechanicChips(lava).single.long, contains('no te defiendas'));
      final calm = _boss('bestiaMagma');
      calm.enemies[0].actions = 1;
      expect(bossMechanicChips(calm).single.long, contains('sube en 2 acciones'));

      final court = _boss('espectroCoronado', adds: ['siervoEspectral', 'siervoEspectral']);
      expect(bossMechanicChips(court).single.short, 'INMUNE (2)');
      court.enemies[1].hp = 0;
      court.enemies[2].hp = 0;
      expect(bossMechanicChips(court).single.long, contains('los estados entran'));

      final sent = _boss('centinela');
      sent.party[0].voidMarked = true;
      final m = bossMechanicChips(sent).single;
      expect(m.short, 'MARCA ×2');
      expect(m.tip, contains('Proteja'));
      expect(combatantChips(sent.party[0]).map((c) => c.short), contains('Marcado ×2'));

      final dev = _boss('devorador');
      expect(bossMechanicChips(dev).single.short, 'FASE 1');
      dev.enemies[0]
        ..phase = 2
        ..actions = 1;
      expect(bossMechanicChips(dev).single.long, contains('Colapso Temporal cada 2 (en 1)'));
    });

    test('marca del Vigilante con su origen en el chip', () {
      final p = _hero('p1')
        ..effects = [const TimedEffect(sourceId: 'vigilancia', stat: BuffStat.damageTaken, value: 0.2, turns: 2)];
      final chip = combatantChips(p).firstWhere((c) => c.short == 'Marca');
      expect(chip.tip, contains('Vigilante del Vacío'));
    });
  });

  group('sonido', () {
    test('cada fase nueva suena', () {
      final rec = _Recorder();
      final sfx = SessionSfx(rec, localId: 'p1')..battle = _boss('centinela');
      final ids = [
        for (final c in sfx.battleSounds(const [
          BossMechanicEvent('e0', BossMechanicPhase.echoSummon, targetId: 'e1'),
          BossMechanicEvent('e1', BossMechanicPhase.echoResist, value: 0.5),
          BossMechanicEvent('e0', BossMechanicPhase.lavaRise, value: 2),
          BossMechanicEvent('e0', BossMechanicPhase.lavaBurn, targetId: 'p1', value: 2),
          BossMechanicEvent('e0', BossMechanicPhase.lavaFade),
          BossMechanicEvent('e0', BossMechanicPhase.summon, targetId: 'e1'),
          BossMechanicEvent('e0', BossMechanicPhase.immune),
          BossMechanicEvent('e0', BossMechanicPhase.markCast, targetId: 'p1'),
          ActionEvent('e0', BattleActionKind.enemyHeavy, targetId: 'p1'),
          BossMechanicEvent('e0', BossMechanicPhase.markHit, targetId: 'p1', value: 2),
          BossMechanicEvent('p2', BossMechanicPhase.markGuarded, targetId: 'p1'),
        ]))
          c.id,
        // Otro paso (tope de 12 sonidos por paso).
        for (final c in sfx.battleSounds(const [
          BossMechanicEvent('e0', BossMechanicPhase.phaseShift, value: 2),
          BossMechanicEvent('e0', BossMechanicPhase.evaded),
        ]))
          c.id,
      ];
      const expected = [
        Sfx.echoSummon, Sfx.echoResist, Sfx.lavaRise, Sfx.lavaBurn, Sfx.lavaFade, Sfx.summon, Sfx.immune,
        Sfx.markCast, Sfx.markHit, Sfx.markGuard, Sfx.phaseShift, Sfx.evade,
      ];
      expect(ids, containsAll(expected));
      for (final id in expected) {
        expect(kSfxCatalog, contains(id), reason: id);
      }
    });

    test('golpe al marcado: la implosión cae con el golpe (160 ms)', () {
      final sfx = SessionSfx(_Recorder(), localId: 'p1')..battle = _boss('centinela');
      final cues = sfx.battleSounds(const [
        ActionEvent('e0', BattleActionKind.enemyHeavy, targetId: 'p1'),
        BossMechanicEvent('e0', BossMechanicPhase.markHit, targetId: 'p1', value: 2),
        DamageEvent('p1', 40),
      ]);
      expect(cues.firstWhere((c) => c.id == Sfx.markHit).delayMs, BattleFx.enemyStrikeMs);
    });

    test('jefes nuevos más fuertes; comunes con impacto propio; ULT con tres partes', () {
      for (final b in ['hechicera', 'bestiaMagma', 'espectroCoronado', 'centinela', 'devorador']) {
        expect(kSfxCatalog[Sfx.enemy(b)]!.peak, SfxLevel.enemyBoss, reason: b);
      }
      for (final c in [
        'ecoSombra', 'guardianReloj', 'salamandra', 'golemMagma', 'necrofago', 'almaErrante',
        'vigilanteVacio', 'ojoAbismo', 'heraldoEras', 'fragmentoTiempo', 'ecoHechicera', 'siervoEspectral',
      ]) {
        expect(kSfxCatalog[Sfx.enemy(c)]!.peak, SfxLevel.enemy, reason: c);
        expect(kSfxCatalog, contains(Sfx.enemyHit(c)));
      }
      for (final u in ['eult_coro', 'eult_erupcion', 'eult_lamento', 'eult_colapsoVacio']) {
        for (final part in Sfx.ultParts) {
          expect(kSfxCatalog, contains(Sfx.ult(u, part)), reason: '$u.$part');
        }
      }
    });
  });
}
