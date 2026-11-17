import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/fx_style.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/proc_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Disparadores del árbol → efectos (docs/specs/battle_presentation.md
// § "Disparadores del árbol (procs)"). Los escenarios salen del motor
// real cuando es fácil y, si no, de eventos armados a mano.

final _stats = StatsCalculator(
    classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree));

BattleEngine _engine([List<double> rolls = const []]) {
  var i = 0;
  return BattleEngine(
      stats: _stats, random: () => i < rolls.length ? rolls[i++] : 0.99);
}

Combatant _hero(
        {String id = 'p1',
        Set<String> mech = const {},
        Set<String> keys = const {},
        double crit = 0,
        List<String> skills = const [],
        String weapon = 'espada'}) =>
    Combatant(
      id: id,
      name: id,
      isPlayer: true,
      hp: 100,
      maxHp: 100,
      speed: 10,
      attack: 20,
      magic: 20,
      critChance: crit,
      mp: 50,
      maxMp: 50,
      mechanics: {...mech},
      keystones: {...keys},
      skillIds: skills,
      classId: 'guerrero',
      weaponType: weapon,
    );

Combatant _foe(String id, {Map<StatusKind, int>? st}) => Combatant(
      id: id,
      name: id,
      isPlayer: false,
      hp: 100,
      maxHp: 100,
      speed: 5,
      attack: 10,
      critChance: 0,
      enemyType: 'slime',
      statuses: st,
      nextTurn: 50,
    );

BattleState _battle(List<Combatant> party, {int foes = 3,
        Map<StatusKind, int>? st}) =>
    BattleState(
        party: party,
        enemies: [for (var i = 0; i < foes; i++) _foe('e$i', st: st)],
        currentId: party.first.id);

/// x = 100·índice (jugadores primero), y = 200.
Offset Function(String) _positions(BattleState s) {
  final ids = [...s.party.map((p) => p.id), ...s.enemies.map((e) => e.id)];
  return (id) => Offset(100.0 * ids.indexOf(id), 200);
}

List<BattleFx> _map(List<BattleEvent> events, BattleState s) =>
    mapBattleEvents(events, s, _positions(s));

Iterable<BattleFx> _of(List<BattleFx> fx, FxKind k) =>
    fx.where((f) => f.kind == k);

BattleFx _txt(List<BattleFx> fx, String text) =>
    _of(fx, FxKind.txt).singleWhere((f) => f.text == text);

const _base = ProcTiming.afterMs; // cuerpo a cuerpo: golpe a 0

void main() {
  group('rebotes', () {
    test('Rebote + Cadena Infinita: cartel único, arco por salto desde el '
        'objetivo anterior, números con su salto', () {
      final s = _battle([
        _hero(mech: {'rebote', 'cadena'}, keys: {'cadena'})
      ]);
      final step =
          _engine().command(s, 'p1', const AttackCommand(targetId: 'e1'))!;
      final fx = _map(step.events, step.state);

      final tag = _of(fx, FxKind.tag).single;
      expect(tag.text, 'Rebote');
      expect(tag.color, procNotableColor);
      expect(tag.who, 'p1');
      expect(tag.delayMs, _base);

      final arcs = _of(fx, FxKind.arc).toList();
      expect(arcs, hasLength(2));
      // e1 (x 200) → e2 (x 300) → e0 (x 100).
      expect([arcs[0].x, arcs[0].tx], [200, 300]);
      expect([arcs[1].x, arcs[1].tx], [300, 100]);
      expect(arcs.map((a) => a.delayMs),
          [ProcTiming.hopAt(_base, 0), ProcTiming.hopAt(_base, 1)]);
      expect(arcs.first.el, FxElement.phys);

      final secondary = _of(fx, FxKind.num)
          .where((n) => n.color == const Color(0xFF81ECEC))
          .toList();
      expect(secondary.map((n) => n.x), [300, 100]);
      expect(secondary.map((n) => n.delayMs),
          [ProcTiming.hopHitAt(_base, 0), ProcTiming.hopHitAt(_base, 1)]);
      // El golpe primario sigue en 0.
      expect(_of(fx, FxKind.num).first.delayMs, 0);
    });

    test('Arco Voltaico: rayo eléctrico después del proyectil', () {
      final s = _battle([
        _hero(mech: {'arcoVoltaico'}, skills: ['bola'])
      ]);
      final step = _engine()
          .command(s, 'p1', const SkillCommand('bola', targetId: 'e0'))!;
      final fx = _map(step.events, step.state);
      final arc = _of(fx, FxKind.arc).single;
      const base = BattleFx.projMs + ProcTiming.afterMs;
      expect(arc.delayMs, base);
      expect(arc.el, FxElement.mana);
      expect(arc.color, const Color(0xFF74B9FF));
      expect([arc.x, arc.tx], [100, 200]);
    });
  });

  test('Combustión: estallido en el centro y bola de fuego a cada otro', () {
    final s = _battle([
      _hero(mech: {'combustion'}, skills: ['bola'])
    ], st: {StatusKind.burn: 3});
    final step =
        _engine().command(s, 'p1', const SkillCommand('bola', targetId: 'e0'))!;
    final fx = _map(step.events, step.state);
    const base = BattleFx.projMs + ProcTiming.afterMs;
    final blast = _of(fx, FxKind.blast).single;
    expect([blast.x, blast.delayMs], [100, base]);
    expect(blast.el, FxElement.burn);
    final fire = _of(fx, FxKind.proj).where((p) => p.x == 100).toList();
    expect(fire.map((p) => p.tx), [200, 300]);
    final nums = _of(fx, FxKind.num)
        .where((n) => n.color == const Color(0xFFFF7B29))
        .toList();
    expect(nums.map((n) => n.delayMs),
        [ProcTiming.blastHitAt(base, 0), ProcTiming.blastHitAt(base, 1)]);
    // Cada bola llega cuando cae su número.
    for (var i = 0; i < 2; i++) {
      expect(fire[i].delayMs + BattleFx.projMs, nums[i].delayMs);
    }
  });

  test('Eco Arcano: repetición fantasma con su estado al llegar', () {
    final s = _battle([_hero(skills: ['bola'])]);
    final fx = _map(const [
      ActionEvent('p1', BattleActionKind.skill, skillId: 'bola', targetId: 'e0'),
      DamageEvent('e0', 18),
      StatusAppliedEvent('e0', StatusKind.burn, 1),
      ProcEvent('p1', 'ecoArcano'),
      DamageEvent('e0', 9, sourceId: 'ecoArcano'),
      StatusAppliedEvent('e0', StatusKind.burn, 1),
    ], s);
    const base = BattleFx.projMs + ProcTiming.afterMs;
    final ghosts = fx.where((f) => f.ghost).toList();
    expect(ghosts.map((f) => f.kind),
        containsAll([FxKind.ring, FxKind.proj, FxKind.slash]));
    final proj = ghosts.singleWhere((f) => f.kind == FxKind.proj);
    expect(proj.delayMs, ProcTiming.echoAt(base, 0));
    final hit = ProcTiming.echoAt(base, 0) + BattleFx.projMs;
    expect(ghosts.singleWhere((f) => f.kind == FxKind.slash).delayMs, hit);
    final statuses = _of(fx, FxKind.txt).where((t) => t.text == 'Q+1').toList();
    expect(statuses.map((t) => t.delayMs), [BattleFx.projMs, hit]);
  });

  test('Contraataque y Represalia en el golpe enemigo: carteles '
      'escalonados, héroe que se lanza, tajo blanco y destello naranja', () {
    final s = _battle([
      _hero(mech: {'contraataque', 'represalia'})..defending = true
    ], foes: 1);
    final step =
        _engine().enemyTurn(BattleState(party: s.party, enemies: [
      _foe('e0')..nextTurn = 0,
    ], currentId: 'e0'))!;
    final fx = _map(step.events, step.state);

    final tags = _of(fx, FxKind.tag).toList();
    // El buff propio va en el cartel.
    expect(tags.map((t) => t.text),
        ['Contraataque', 'Represalia · ATQ +30%']);
    expect(tags.map((t) => t.delayMs),
        [ProcTiming.tagAt(_base, 0), ProcTiming.tagAt(_base, 1)]);
    expect(tags.map((t) => t.slot), [0, 1]);

    expect(_of(fx, FxKind.act).where((a) => a.who == 'p1').single.delayMs,
        _base);
    final arc = _of(fx, FxKind.arc).single;
    expect([arc.x, arc.tx, arc.color], [0, 100, fxWhite]);
    final slash = _of(fx, FxKind.slash).singleWhere((f) => f.who == 'e0');
    expect(slash.delayMs, _base + ProcTiming.counterHitMs);

    expect(_of(fx, FxKind.pulse).single.color, ProcColors.retaliate);
    final arrow = _of(fx, FxKind.arrow).single;
    expect(arrow.up, isTrue);
    expect(arrow.delayMs, _base);
    expect(_of(fx, FxKind.txt).where((t) => t.text == 'ATQ +30%'), isEmpty);
  });

  test('Castigo Divino: rayo dorado y el daño cuando llega abajo', () {
    final s = _battle([_hero()]);
    final fx = _map(const [
      ActionEvent('p1', BattleActionKind.attack, targetId: 'e0'),
      DamageEvent('e0', 20),
      StatusAppliedEvent('e0', StatusKind.stun, 1),
      ProcEvent('p1', 'castigoDivino', targetId: 'e0'),
      DamageEvent('e0', 12, sourceId: 'castigoDivino'),
    ], s);
    final beam = _of(fx, FxKind.beam).single;
    expect([beam.x, beam.y, beam.delayMs], [100, 200, _base]);
    final num = _of(fx, FxKind.num).singleWhere((n) => n.text == '12');
    expect(num.delayMs, _base + ProcTiming.beamHitMs);
    expect(num.color, const Color(0xFFFFD166));
    expect(_of(fx, FxKind.slash).last.el, FxElement.holy);
  });

  group('escudos', () {
    test('Égida Eterna al empezar el turno: cartel rojo de keystone y '
        'burbuja', () {
      final s = _battle([_hero(mech: {'egida'})]);
      final fx = _map(const [
        TurnStartedEvent('p1'),
        ProcEvent('p1', 'egida', targetId: 'p1'),
        ShieldEvent('p1', 10),
      ], s);
      final tag = _of(fx, FxKind.tag).single;
      expect(tag.text, 'Égida Eterna · ESCUDO +10');
      expect(tag.color, procKeystoneColor);
      expect(tag.delayMs, 0);
      final bubble = _of(fx, FxKind.bubble).single;
      expect([bubble.who, bubble.delayMs], ['p1', 0]);
    });

    test('absorbe todo: la grieta es el golpe (sin número, tajo ni sacudida)',
        () {
      final s = _battle([_hero()]);
      final fx = _map(const [
        ActionEvent('e0', BattleActionKind.enemyAttack, targetId: 'p1'),
        ShieldEvent('p1', 7, absorbed: true),
        DamageEvent('p1', 0),
      ], s);
      expect(_of(fx, FxKind.crack).single.delayMs, 0);
      expect(_txt(fx, 'ABSORBE 7').delayMs, 0);
      expect(_of(fx, FxKind.num), isEmpty);
      expect(_of(fx, FxKind.slash), isEmpty);
    });

    test('absorbe una parte: grieta y el número de lo que pasó', () {
      final s = _battle([_hero()]);
      final fx = _map(const [
        ActionEvent('e0', BattleActionKind.enemyAttack, targetId: 'p1'),
        ShieldEvent('p1', 7, absorbed: true),
        DamageEvent('p1', 3),
      ], s);
      expect(_of(fx, FxKind.crack), hasLength(1));
      expect(_of(fx, FxKind.num).single.text, '3');
    });
  });

  test('Danza de Cuchillas: congelado y ¡OTRA VEZ! después', () {
    final s = _battle([
      _hero(mech: {'danza'}, keys: {'danza'}, crit: 1)
    ]);
    final step =
        _engine([0.0]).command(s, 'p1', const AttackCommand(targetId: 'e0'))!;
    final fx = _map(step.events, step.state);
    final stop = _of(fx, FxKind.timeStop).single;
    expect(stop.delayMs, _base);
    final tags = _of(fx, FxKind.tag).toList();
    final name = tags.singleWhere((t) => t.text == 'Danza de Cuchillas');
    expect(name.color, procKeystoneColor);
    final banner = tags.singleWhere((t) => t.text == '¡OTRA VEZ!');
    expect(banner.big, isTrue);
    expect(banner.delayMs, _base + ProcTiming.bannerMs);
    expect(banner.y, 200 - 10, reason: 'sobre el cuerpo del actor');
  });

  test('Sed de Sangre: latido y la cura después del golpe que mata', () {
    final s = _battle([_hero(mech: {'sedSangre'})]);
    s.enemies.first.hp = 5;
    final step =
        _engine().command(s, 'p1', const AttackCommand(targetId: 'e0'))!;
    final fx = _map(step.events, step.state);
    final pulse = _of(fx, FxKind.pulse).single;
    expect(pulse.heavy, isTrue);
    expect(pulse.color, ProcColors.blood);
    expect(pulse.delayMs, _base);
    final heal = _of(fx, FxKind.num).singleWhere((n) => n.text == '+10');
    expect(heal.delayMs, _base + ProcTiming.healAfterMs);
    expect(_of(fx, FxKind.tag), hasLength(1), reason: 'un cartel por paso');
  });

  test('Plaga Contagiosa: chorro del caído al nuevo huésped', () {
    final s = _battle([
      _hero(mech: {'plagaContagiosa'})
    ], st: {StatusKind.poison: 3});
    s.enemies.first.hp = 5;
    final step =
        _engine().command(s, 'p1', const AttackCommand(targetId: 'e0'))!;
    final fx = _map(step.events, step.state);
    final stream = _of(fx, FxKind.stream).single;
    expect(stream.x, 100); // e0, el caído
    expect(stream.tx, isNot(100));
    final arrive = stream.delayMs + ProcTiming.streamMs;
    final v = _of(fx, FxKind.txt).singleWhere((t) => t.text == 'V+3');
    expect(v.delayMs, arrive);
  });

  test('Choque Térmico: vapor y ¡ATURDIDO! con el estado', () {
    final s = _battle([_hero()]);
    final fx = _map(const [
      ActionEvent('p1', BattleActionKind.attack, targetId: 'e0'),
      DamageEvent('e0', 20),
      StatusAppliedEvent('e0', StatusKind.burn, 1),
      ProcEvent('p1', 'choqueTermico', targetId: 'e0'),
      StatusAppliedEvent('e0', StatusKind.stun, 1),
    ], s);
    expect(_of(fx, FxKind.puff).single.delayMs, _base);
    expect(_txt(fx, '¡ATURDIDO!').delayMs, _base);
    expect(_txt(fx, 'A+1').delayMs, _base);
    expect(_txt(fx, 'Q+1').delayMs, 0);
  });

  group('buffs', () {
    test('Frenesí: estela roja y VEL +20%', () {
      final s = _battle([_hero(mech: {'frenesi'}, crit: 1)]);
      final step =
          _engine([0.0]).command(s, 'p1', const AttackCommand(targetId: 'e0'))!;
      final fx = _map(step.events, step.state);
      final trail = _of(fx, FxKind.afterimage).single;
      expect([trail.who, trail.delayMs], ['p1', _base]);
      final tags = _of(fx, FxKind.tag).map((t) => t.text);
      expect(tags, contains('Frenesí · VEL +20%'));
    });

    test('Debilitar: flecha verde abajo; Marca: retícula roja', () {
      final s = _battle([_hero()]);
      final fx = _map(const [
        ActionEvent('p1', BattleActionKind.attack, targetId: 'e0'),
        DamageEvent('e0', 20),
        ProcEvent('p1', 'marcaCazador', targetId: 'e0'),
        BuffAppliedEvent('e0', 'marcaCazador', BuffStat.damageTaken, 0.15, 3),
        ProcEvent('p1', 'debilitar', targetId: 'e0'),
        BuffAppliedEvent('e0', 'debilitar', BuffStat.attack, -0.15, 2),
      ], s);
      final arrow = _of(fx, FxKind.arrow).single;
      expect([arrow.up, arrow.color], [false, ProcColors.weaken]);
      expect(_txt(fx, 'ATQ −15%').who, isNull);
      final ret = _of(fx, FxKind.reticle).single;
      expect([ret.who, ret.color, ret.delayMs], ['e0', ProcColors.mark, _base]);
      expect(_txt(fx, '+15% DAÑO').x, 100);
    });

    test('Martillo Bendito: aura de aturdido y ATURDIDO +1', () {
      final s = _battle([_hero()]);
      final fx = _map(const [
        ActionEvent('p1', BattleActionKind.attack, targetId: 'e0'),
        DamageEvent('e0', 20),
        StatusAppliedEvent('e0', StatusKind.stun, 1),
        ProcEvent('p1', 'martilloBendito', targetId: 'e0'),
        BuffAppliedEvent('e0', 'martilloBendito', BuffStat.stunLock, 1, 1),
      ], s);
      expect(_of(fx, FxKind.aura).single.el, FxElement.stun);
      expect(_txt(fx, 'ATURDIDO +1').delayMs, _base);
    });
  });

  test('Guardián: chispas y +8 ULT en la escena', () {
    final s = _battle([_hero(), _hero(id: 'p2')]);
    final fx = _map(const [
      ActionEvent('e0', BattleActionKind.enemyAttack, targetId: 'p2'),
      DamageEvent('p1', 4),
      ProcEvent('p1', 'guardian'),
    ], s);
    expect(_of(fx, FxKind.spark).single.who, 'p1');
    expect(_of(fx, FxKind.tag).single.text, 'Guardián · +8 ULT');
  });

  test('Viento a Favor: el ataque gratis se corre después de la habilidad',
      () {
    final s = _battle([_hero(mech: {'vientoFavor'}, skills: ['rafaga'])]);
    s.enemies[1].hp = 30;
    final step = _engine().command(s, 'p1', const SkillCommand('rafaga'))!;
    final fx = _map(step.events, step.state);
    final acts = _of(fx, FxKind.act).toList();
    expect(acts.map((a) => a.delayMs), [0, _base]);
    final free = _of(fx, FxKind.num).singleWhere((n) => n.x == 200 && n.text == '20');
    expect(free.delayMs, _base);
    expect(_of(fx, FxKind.tag).single.text, 'Viento a Favor');
  });

  test('en una ULT, los procs van después de todos sus impactos', () {
    final s = _battle([_hero(mech: {'frenesi'})]);
    final script = ultScriptFor('ult_espada');
    final fx = _map(const [
      UltimateUsedEvent('p1', 'Tajo Final'),
      ActionEvent('p1', BattleActionKind.ultimate,
          skillId: 'ult_espada', targetId: 'e0'),
      DamageEvent('e0', 80, critical: true),
      ProcEvent('p1', 'frenesi'),
      BuffAppliedEvent('p1', 'frenesi', BuffStat.speed, 0.2, 2),
    ], s);
    final tag = _of(fx, FxKind.tag).single;
    expect(tag.delayMs, script.returnAt);
    expect(tag.delayMs, greaterThan(script.lastImpact(1)));
    expect(_of(fx, FxKind.afterimage).single.delayMs, script.returnAt);
  });

  test('carteles: uno por actor y mecánica, escalonados por actor', () {
    final s = _battle([_hero(), _hero(id: 'p2')]);
    final fx = _map(const [
      ActionEvent('p1', BattleActionKind.skill, skillId: 'cura'),
      HealEvent('p1', 10),
      HealEvent('p2', 10),
      ProcEvent('p1', 'manoSanadora', targetId: 'p1'),
      ShieldEvent('p1', 2),
      ProcEvent('p1', 'manoSanadora', targetId: 'p2'),
      ShieldEvent('p2', 2),
      ProcEvent('p2', 'guardian'),
      ProcEvent('p1', 'guardian'),
    ], s);
    final tags = _of(fx, FxKind.tag).toList();
    // El escudo propio de p1 va en su cartel; el de p2, sobre p2.
    expect(tags.map((t) => '${t.who}:${t.text}'), [
      'p1:Mano Sanadora · ESCUDO +2',
      'p2:Guardián · +8 ULT',
      'p1:Guardián · +8 ULT',
    ]);
    expect(_txt(fx, 'ESCUDO +2').x, 100);
    // p2 tiene su primer cartel en la base; p1 el segundo, escalonado.
    expect(tags.map((t) => t.delayMs), [
      ProcTiming.tagAt(_base, 0),
      ProcTiming.tagAt(_base, 0),
      ProcTiming.tagAt(_base, 1),
    ]);
    expect(tags.map((t) => t.slot), [0, 0, 1]);
    expect(_of(fx, FxKind.bubble).map((b) => b.who), ['p1', 'p2']);
  });

  test('todos los nombres de las mecánicas con evento tienen cartel', () {
    expect(kKeystoneMechanics, {'danza', 'almaHielo', 'cadena', 'egida'});
    expect(procName('corteCadena'), 'Corte en Cadena');
    expect(procTagColor('rebote'), procNotableColor);
    expect(procTagColor('danza'), procKeystoneColor);
    for (final id in kChainMechanics) {
      expect(procHitStyle(id), isNotNull, reason: id);
    }
  });

  group('escena', () {
    test('el congelado de Danza frena el reloj y el estallido sacude', () {
      final scene = BattleSceneController();
      scene.addEffects(const [
        BattleFx(FxKind.timeStop, who: 'p1'),
        BattleFx(FxKind.blast, x: 10, y: 10),
      ]);
      scene.advance(16);
      expect(scene.hitStop, greaterThan(0));
      expect(scene.particles.shake, greaterThan(0));
      final t0 = scene.t;
      scene.advance(40);
      expect(scene.t, t0, reason: 'el tiempo está congelado');
      scene.advance(200);
      expect(scene.t, greaterThan(t0));
    });

    test('la estela de Frenesí se ve mientras dura', () {
      final scene = BattleSceneController();
      scene.addEffects(const [BattleFx(FxKind.afterimage, who: 'p1')]);
      scene.advance(16);
      expect(scene.activeOn(FxKind.afterimage, 'p1'), isNotNull);
      expect(scene.activeOn(FxKind.afterimage, 'p2'), isNull);
      scene.advance(BattleFx.afterimageMs.toDouble());
      expect(scene.activeOn(FxKind.afterimage, 'p1'), isNull);
    });
  });
}
