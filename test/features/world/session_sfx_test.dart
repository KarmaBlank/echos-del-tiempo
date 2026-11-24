import '../../support/legacy_solo_mode.dart';
import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/proc_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/duo_cinematic.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_sfx.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/passive_mechanic.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';
import 'world_test_helpers.dart';

class _Recorder extends SfxService {
  final played = <String>[];
  final cues = <SfxCue>[];

  @override
  void play(String id, {int delayMs = 0}) {
    played.add(id);
    cues.add(cue(id, delayMs));
  }
}

Combatant _player(String id, String weapon, String classId) => Combatant(
      id: id,
      name: id,
      isPlayer: true,
      hp: 50,
      maxHp: 50,
      speed: 10,
      attack: 10,
      critChance: 0,
      weaponType: weapon,
      classId: classId,
    );

Combatant _enemy(String id, String type) => Combatant(
      id: id,
      name: type,
      isPlayer: false,
      hp: 30,
      maxHp: 30,
      speed: 7,
      attack: 7,
      critChance: 0,
      enemyType: type,
    );

/// Sala de prueba: maga (báculo), tirador (arco), guerrero (espada) y
/// paladín (martillo) contra un limo, un murciélago y dos gólems.
SessionSfx _sfx(_Recorder rec) => SessionSfx(rec, localId: 'mage')
  ..battle = BattleState(party: [
    _player('mage', 'báculo', 'maga'),
    _player('archer', 'arco', 'tirador'),
    _player('knight', 'espada', 'guerrero'),
    _player('pal', 'martillo+escudo', 'paladin'),
  ], enemies: [
    _enemy('e1', 'slime'),
    _enemy('e2', 'bat'),
    _enemy('e3', 'golem'),
    _enemy('e4', 'golem'),
  ]);

void main() {
  useRoundsDefault();
  SessionController? c;

  Future<SessionController> started() async {
    final ctrl = SessionController(
      engine: sessionEngine(),
      store: InMemoryProfileStore(),
      clock: const SessionClock(autoStart: false),
    );
    c = ctrl;
    await ctrl.start();
    return ctrl;
  }

  tearDown(() {
    final ctrl = c;
    if (ctrl != null && ctrl.mounted) ctrl.dispose();
    c = null;
  });

  const m = SessionSfx.meleeImpactMs;
  // Golpe enemigo: después del wind-up.
  const k = BattleFx.enemyStrikeMs;
  const st = SessionSfx.staggerMs;
  const p = BattleFx.projMs;

  test('magia a un objetivo con estado: firma al lanzar, impacto del '
      'elemento y estado cuando llega el proyectil', () {
    final sfx = _sfx(_Recorder());
    expect(
        sfx.battleSounds(const [
          ActionEvent('mage', BattleActionKind.skill,
              skillId: 'bola', targetId: 'e1'),
          DamageEvent('e1', 20),
          StatusAppliedEvent('e1', StatusKind.burn, 2),
        ]),
        [
          cue('skill.bola'),
          cue(Sfx.impactFire, p),
          cue('status.burn', p + SessionSfx.statusAfterMs),
        ]);
  });

  test('físico a varios: arma + firma, 3 impactos escalonados como máximo '
      'y el estado una sola vez', () {
    final sfx = _sfx(_Recorder());
    expect(
        sfx.battleSounds(const [
          ActionEvent('knight', BattleActionKind.skill,
              skillId: 'giro', allTargets: true),
          DamageEvent('e1', 5),
          DamageEvent('e2', 5),
          DamageEvent('e3', 5),
          DamageEvent('e4', 5),
          KnockedOutEvent('e2'),
        ]),
        [
          cue(Sfx.swingBlade),
          cue('skill.giro'),
          cue(Sfx.impactSlash, m),
          cue(Sfx.impactSlash, m + st),
          cue(Sfx.impactSlash, m + 2 * st),
          cue(Sfx.koEnemy, m + st + SessionSfx.koAfterMs),
        ]);
    expect(
        sfx.battleSounds(const [
          ActionEvent('pal', BattleActionKind.skill,
              skillId: 'temblor', allTargets: true),
          DamageEvent('e1', 5),
          StatusAppliedEvent('e1', StatusKind.stun, 1),
          DamageEvent('e2', 5),
          StatusAppliedEvent('e2', StatusKind.stun, 1),
        ]),
        [
          cue(Sfx.swingHeavy),
          cue('skill.temblor'),
          cue(Sfx.impactBlunt, m),
          cue('status.stun', m + SessionSfx.statusAfterMs),
          cue(Sfx.impactBlunt, m + st),
        ]);
  });

  test('crítico: un clink por golpe crítico, en el tiempo de su impacto '
      '(también si el impacto no suena por el tope)', () {
    final sfx = _sfx(_Recorder());
    // Flecha a un objetivo: impacto y clink al llegar la flecha.
    expect(
        sfx.battleSounds(const [
          ActionEvent('archer', BattleActionKind.attack, targetId: 'e3'),
          DamageEvent('e3', 30, critical: true),
        ]),
        [
          cue(Sfx.shotBow),
          cue(Sfx.impactArrow, p),
          cue(Sfx.critClink, p),
        ]);
    // Lluvia de flechas: proyectil a cada uno, escalonados.
    final cues = sfx.battleSounds(const [
      ActionEvent('archer', BattleActionKind.skill,
          skillId: 'lluvia', allTargets: true),
      DamageEvent('e1', 9, critical: true),
      DamageEvent('e2', 9),
      DamageEvent('e3', 9, critical: true),
      DamageEvent('e4', 9, critical: true),
    ]);
    expect(cues.where((c) => c.id == Sfx.critClink).toList(), [
      cue(Sfx.critClink, p),
      cue(Sfx.critClink, p + 2 * st),
      cue(Sfx.critClink, p + 3 * st),
    ]);
    expect(cues.where((c) => c.id == Sfx.impactArrow), hasLength(3));
  });

  test('cura: firma y destellos por aliado (tope 3); poción y éter', () {
    final sfx = _sfx(_Recorder());
    const h = SessionSfx.healAfterMs;
    expect(
        sfx.battleSounds(const [
          ActionEvent('mage', BattleActionKind.skill, skillId: 'curaM'),
          HealEvent('mage', 10),
          HealEvent('archer', 10),
          HealEvent('knight', 10),
          HealEvent('pal', 10),
          ActionEvent('knight', BattleActionKind.potion, targetId: 'knight'),
          HealEvent('knight', 30),
          ActionEvent('mage', BattleActionKind.ether, targetId: 'mage'),
          HealEvent('mage', 5, mana: true),
        ]),
        [
          cue('skill.curaM'),
          cue(Sfx.healSparkle, h),
          cue(Sfx.healSparkle, h + st),
          cue(Sfx.healSparkle, h + 2 * st),
          cue(Sfx.potion),
          cue(Sfx.healSparkle, SessionSfx.potionHealMs),
          cue(Sfx.ether),
          cue(Sfx.manaUp),
        ]);
  });

  test('ataques enemigos según el tipo; golpe brutal y área', () {
    final sfx = _sfx(_Recorder());
    expect(
        sfx.battleSounds(const [
          ActionEvent('e1', BattleActionKind.enemyAttack, targetId: 'mage'),
          DamageEvent('mage', 7),
          StatusAppliedEvent('mage', StatusKind.poison, 1),
          ActionEvent('e2', BattleActionKind.enemyAttack, targetId: 'mage'),
          DamageEvent('mage', 9, critical: true),
          ActionEvent('e3', BattleActionKind.enemyHeavy, targetId: 'pal'),
          DamageEvent('pal', 20),
          KnockedOutEvent('pal'),
        ]),
        [
          cue('enemy.slime'),
          cue(Sfx.enemyHit('slime'), k),
          cue('status.poison', k + SessionSfx.statusAfterMs),
          cue('enemy.bat'),
          cue(Sfx.enemyHit('bat'), k),
          cue(Sfx.critClink, k),
          cue('enemy.golem'),
          cue(Sfx.enemyHeavy, k),
          cue(Sfx.enemyHit('golem'), k),
          cue(Sfx.koPlayer, k + SessionSfx.koAfterMs),
        ]);
    expect(
        sfx.battleSounds(const [
          ActionEvent('x', BattleActionKind.enemyArea, allTargets: true),
          DamageEvent('mage', 4),
          DamageEvent('archer', 4),
        ]),
        [
          cue(Sfx.enemyGeneric), // tipo desconocido
          cue(Sfx.flash, k),
          cue(Sfx.impactHurt, k),
          cue(Sfx.impactHurt, k + st),
        ]);
  });

  test('tope global de sonidos por paso', () {
    final sfx = _sfx(_Recorder());
    final cues = sfx.battleSounds([
      for (var i = 0; i < 10; i++) ...const [
        ActionEvent('e1', BattleActionKind.enemyAttack, targetId: 'mage'),
        DamageEvent('mage', 1),
      ],
    ]);
    expect(cues, hasLength(SessionSfx.maxCuesPerStep));
  });

  test('tics de estado al empezar el turno, Regeneración, salteos', () {
    final sfx = _sfx(_Recorder());
    expect(
        sfx.battleSounds(const [
          TurnStartedEvent('e1'),
          DamageEvent('e1', 4, fromStatus: true, statusSource: StatusKind.burn),
          TurnStartedEvent('mage'),
          DamageEvent('mage', 3,
              fromStatus: true, statusSource: StatusKind.poison),
          HealEvent('mage', 6),
          HealEvent('mage', 2, mana: true),
          TurnSkippedEvent('mage', StatusKind.freeze),
          TurnSkippedEvent('e2', StatusKind.stun),
          RevivedEvent('pal'),
        ]),
        [
          cue('tick.burn'),
          cue('tick.poison'),
          cue('tick.regen'),
          cue(Sfx.skipFreeze),
          cue(Sfx.skipStun),
          cue(Sfx.revive),
        ]);
  });

  test('ULT: preparación, descarga e impacto propios en los tiempos del '
      'guion (más el clink del crítico al impacto); dúo con destello', () {
    final sfx = _sfx(_Recorder());
    final tajo = kUltScripts['ult_espada']!;
    expect(
        sfx.battleSounds(const [
          UltimateUsedEvent('knight', 'Tajo Final'),
          ActionEvent('knight', BattleActionKind.ultimate,
              skillId: 'ult_espada', targetId: 'e1'),
          DamageEvent('e1', 90, critical: true),
          KnockedOutEvent('e1'),
          ActionEvent('knight', BattleActionKind.dual,
              partnerId: 'mage', targetId: 'e2'),
          DamageEvent('e2', 30),
        ]),
        [
          cue(Sfx.ult('ult_espada', Sfx.ultBuild)),
          cue(Sfx.ult('ult_espada', Sfx.ultRelease), tajo.buildMs),
          cue(Sfx.ult('ult_espada', Sfx.ultImpact), tajo.impactMs),
          cue(Sfx.critClink, tajo.impactMs),
          cue(Sfx.koEnemy, tajo.impactMs + SessionSfx.koAfterMs),
          // v0.8.3: subida, acorde + destello al descargar, choque en el
          // impacto de la cinemática de dúo.
          cue(Sfx.dualRise),
          cue(Sfx.flash, kDuoScript.buildMs),
          cue(Sfx.dualCast, kDuoScript.buildMs),
          cue(Sfx.dualClash, kDuoScript.impactMs),
          // guerrero+maga = Espada Llameante (Quemadura).
          cue(Sfx.impactFire, kDuoScript.impactMs),
        ]);
  });

  test('ULT de cada tipo de arma: preparación @0, descarga al terminar la '
      'preparación, impacto en el impacto del guion de cada objetivo (3 '
      'como máximo) y clink en los críticos', () {
    for (final e in kAllUltimates.entries) {
      final sk = e.value;
      final script = ultScriptFor(sk.id);
      final sfx = SessionSfx(_Recorder(), localId: 'p')
        ..battle = BattleState(party: [
          _player('p', e.key, 'guerrero'),
          _player('q', 'arco', 'tirador'),
        ], enemies: [
          for (var i = 0; i < 4; i++) _enemy('e$i', 'golem'),
        ]);
      final cues = sfx.battleSounds([
        UltimateUsedEvent('p', sk.name),
        ActionEvent('p', BattleActionKind.ultimate, skillId: sk.id),
        if (sk.dealsDamage)
          for (var i = 0; i < 4; i++) DamageEvent('e$i', 10, critical: i == 3)
        else ...[
          const HealEvent('p', 10),
          const HealEvent('q', 10),
        ],
      ]);
      final impact = Sfx.ult(sk.id, Sfx.ultImpact);
      expect(cues.take(2), [
        cue(Sfx.ult(sk.id, Sfx.ultBuild)),
        cue(Sfx.ult(sk.id, Sfx.ultRelease), script.buildMs),
      ], reason: sk.name);
      if (sk.dealsDamage) {
        expect(cues.skip(2), [
          for (var i = 0; i < 3; i++) cue(impact, script.impactFor(i)),
          cue(Sfx.critClink, script.impactFor(3)),
        ], reason: sk.name);
      } else {
        expect(cues.skip(2), [cue(impact, script.impactFor(0))]);
      }
      for (final c in cues) {
        expect(kSfxCatalog, contains(c.id), reason: c.id);
      }
    }
    // Arma desconocida: el beep del prototipo.
    expect(
        SessionSfx(_Recorder(), localId: 'x')
            .battleSounds(const [UltimateUsedEvent('x', '?')]),
        [cue(Sfx.ultimate)]);
  });

  test('onEvent manda cada sonido con su retraso; subida de nivel', () {
    final rec = _Recorder();
    final sfx = _sfx(rec);
    sfx.onEvent(const BattleStepEvent([
      ActionEvent('mage', BattleActionKind.skill,
          skillId: 'chispa', targetId: 'e1'),
      DamageEvent('e1', 5),
    ]));
    sfx.onEvent(const LevelUpEvent('mage', 2));
    sfx.onEvent(const SystemMessageEvent('nada'));
    expect(rec.cues, [
      cue('skill.chispa'),
      cue(Sfx.impactFire, p),
      cue(Sfx.levelUp),
    ]);
  });

  test('sin estado de batalla: sonidos genéricos (no falla)', () async {
    final ctrl = await started();
    final rec = _Recorder();
    final sfx = SessionSfx(rec, localId: ctrl.localId)..onView(ctrl.view);
    expect(
        sfx.battleSounds(const [
          ActionEvent('local', BattleActionKind.attack, targetId: 'e1'),
          DamageEvent('e1', 9),
          ActionEvent('e1', BattleActionKind.enemyAttack, targetId: 'local'),
          DamageEvent('local', 7),
        ]),
        [
          cue(Sfx.swingBlade),
          cue(Sfx.impactSlash, m),
          cue(Sfx.enemyGeneric),
          cue(Sfx.impactHurt, k),
        ]);
  });

  test('tu turno suena una vez y la cuenta regresiva con ≤ 5 s', () async {
    final c = await started();
    c.proposeMission('m1');
    c.advance(0.1);
    c.setReady(true);
    c.advance(0.1);
    expect(c.view!.mode, SessionMode.field);
    startBattleWithFirstGroup(c);
    waitForMyTurn(c);
    expect(c.view!.myTurn, isTrue);

    final rec = _Recorder();
    final sfx = SessionSfx(rec, localId: c.localId);
    sfx.onView(c.view);
    sfx.onView(c.view);
    expect(rec.played, [Sfx.myTurn]);
    // La vista trae el estado de la batalla (armas y tipos de enemigo).
    expect(sfx.battle, isNotNull);

    c.advance(24); // quedan 6 s
    sfx.onView(c.view);
    expect(rec.played, [Sfx.myTurn]);
    c.advance(1.5); // quedan 4.5 s → 5
    sfx.onView(c.view);
    sfx.onView(c.view);
    expect(rec.played, [Sfx.myTurn, Sfx.turnTick]);
    c.advance(1);
    sfx.onView(c.view);
    expect(rec.played, [Sfx.myTurn, Sfx.turnTick, Sfx.turnTick]);
  });

  test('el oyente se engancha a los eventos del controlador', () async {
    final c = await started();
    final rec = _Recorder();
    final sfx = SessionSfx(rec, localId: c.localId);
    final sub = c.events.listen(sfx.onEvent);
    addTearDown(sub.cancel);
    expect(c.sendChat('hola'), isTrue);
    expect(c.view!.chat.last.text, 'hola');
    expect(c.sendChat('   '), isFalse);
    await pumpEventQueue();
    // El chat no tiene sonido en el prototipo.
    expect(rec.played, isEmpty);
    expect(const ChatAction('x').text, 'x');
  });

  // docs/specs/audio.md § "Procs del árbol".
  group('procs del árbol', () {
    const base = ProcTiming.afterMs; // cuerpo a cuerpo: golpe a 0

    test('rebotes: un zip por salto que sube, en el tiempo de su arco; el '
        'daño secundario no suena como impacto', () {
      final cues = _sfx(_Recorder()).battleSounds(const [
        ActionEvent('knight', BattleActionKind.attack, targetId: 'e1'),
        DamageEvent('e1', 16),
        ProcEvent('knight', 'rebote', targetId: 'e2'),
        DamageEvent('e2', 6, sourceId: 'rebote'),
        ProcEvent('knight', 'rebote', targetId: 'e3'),
        DamageEvent('e3', 4, sourceId: 'rebote'),
        ProcEvent('knight', 'rebote', targetId: 'e4'),
        DamageEvent('e4', 2, sourceId: 'rebote'),
        KnockedOutEvent('e4'),
      ]);
      expect(cues, [
        cue(Sfx.swingBlade),
        cue(Sfx.impactSlash, m),
        cue(Sfx.koEnemy,
            ProcTiming.hopHitAt(base, 2) + SessionSfx.koAfterMs),
        cue(Sfx.zip(0), ProcTiming.hopAt(base, 0)),
        cue(Sfx.zip(1), ProcTiming.hopAt(base, 1)),
        cue(Sfx.zip(2), ProcTiming.hopAt(base, 2)),
      ]);
      expect(Sfx.zip(5), Sfx.zip(Sfx.maxZip));
    });

    test('Combustión (whump), Castigo Divino (campana) y Contraataque '
        '(metal) en sus tiempos', () {
      final sfx = _sfx(_Recorder());
      // Bola de fuego: el golpe llega con el proyectil.
      expect(
          sfx.battleSounds(const [
            ActionEvent('mage', BattleActionKind.skill,
                skillId: 'bola', targetId: 'e1'),
            DamageEvent('e1', 18),
            ProcEvent('mage', 'combustion', targetId: 'e1'),
            DamageEvent('e2', 9, sourceId: 'combustion'),
            DamageEvent('e3', 9, sourceId: 'combustion'),
          ]).where((c) => c.id.startsWith('proc.')),
          [cue(Sfx.whump, p + base)]);
      expect(
          sfx.battleSounds(const [
            ActionEvent('pal', BattleActionKind.attack, targetId: 'e1'),
            DamageEvent('e1', 18),
            StatusAppliedEvent('e1', StatusKind.stun, 1),
            ProcEvent('pal', 'castigoDivino', targetId: 'e1'),
            DamageEvent('e1', 12, sourceId: 'castigoDivino'),
          ]).last,
          cue(Sfx.bell, base));
      expect(
          sfx.battleSounds(const [
            ActionEvent('e1', BattleActionKind.enemyAttack,
                targetId: 'knight'),
            DamageEvent('knight', 5),
            ProcEvent('knight', 'contraataque', targetId: 'e1'),
            DamageEvent('e1', 3, sourceId: 'contraataque'),
            ProcEvent('knight', 'represalia'),
            BuffAppliedEvent('knight', 'represalia', BuffStat.attack, 0.3, 1),
          ]),
          [
            cue('enemy.slime'),
            cue(Sfx.enemyHit('slime'), k),
            cue(Sfx.clang, k + base + ProcTiming.counterHitMs),
            cue(Sfx.flare, k + base),
          ]);
    });

    test('Eco Arcano: la firma con eco cuando arranca la repetición', () {
      final cues = _sfx(_Recorder()).battleSounds(const [
        ActionEvent('mage', BattleActionKind.skill,
            skillId: 'bola', targetId: 'e1'),
        DamageEvent('e1', 18),
        ProcEvent('mage', 'ecoArcano'),
        DamageEvent('e1', 9, sourceId: 'ecoArcano'),
        KnockedOutEvent('e1'),
      ]);
      expect(cues, contains(cue(Sfx.echo('bola'), ProcTiming.echoAt(p + base, 0))));
      expect(
          cues,
          contains(cue(
              Sfx.koEnemy,
              ProcTiming.echoAt(p + base, 0) +
                  p +
                  SessionSfx.koAfterMs)));
    });

    test('escudos: se arma una vez por paso; se quiebra con el golpe', () {
      final sfx = _sfx(_Recorder());
      expect(
          sfx.battleSounds(const [
            ActionEvent('pal', BattleActionKind.skill, skillId: 'cura'),
            HealEvent('pal', 10),
            HealEvent('mage', 10),
            ProcEvent('pal', 'manoSanadora', targetId: 'pal'),
            ShieldEvent('pal', 2),
            ProcEvent('pal', 'manoSanadora', targetId: 'mage'),
            ShieldEvent('mage', 2),
          ]).where((c) => c.id == Sfx.shieldUp),
          [cue(Sfx.shieldUp, base)]);
      expect(
          sfx.battleSounds(const [
            ActionEvent('e1', BattleActionKind.enemyAttack, targetId: 'pal'),
            ShieldEvent('pal', 2, absorbed: true),
            DamageEvent('pal', 5),
          ]),
          [
            cue('enemy.slime'),
            cue(Sfx.enemyHit('slime'), k),
            cue(Sfx.shieldBreak, k),
          ]);
      // Égida al empezar el turno: en el acto.
      expect(
          sfx.battleSounds(const [
            TurnStartedEvent('pal'),
            ProcEvent('pal', 'egida', targetId: 'pal'),
            ShieldEvent('pal', 5),
          ]),
          [cue(Sfx.shieldUp)]);
    });

    test('Danza, Sed de Sangre, Frenesí, Marca y Debilitar', () {
      final sfx = _sfx(_Recorder());
      expect(
          sfx.battleSounds(const [
            ActionEvent('knight', BattleActionKind.attack, targetId: 'e1'),
            DamageEvent('e1', 30, critical: true),
            ProcEvent('knight', 'frenesi'),
            BuffAppliedEvent('knight', 'frenesi', BuffStat.speed, 0.2, 2),
            ProcEvent('knight', 'danza'),
            KnockedOutEvent('e1'),
            ProcEvent('knight', 'sedSangre'),
            ProcEvent('knight', 'sedSangre', targetId: 'knight'),
            HealEvent('knight', 5),
          ]),
          [
            cue(Sfx.swingBlade),
            cue(Sfx.impactSlash, m),
            cue(Sfx.critClink, m),
            cue(Sfx.koEnemy, m + SessionSfx.koAfterMs),
            cue(Sfx.healSparkle, base + ProcTiming.healAfterMs),
            cue(Sfx.frenzyWhoosh, base),
            cue(Sfx.extraTurn, base),
            cue(Sfx.heartbeat, base),
          ]);
      expect(
          sfx.battleSounds(const [
            ActionEvent('archer', BattleActionKind.attack, targetId: 'e1'),
            DamageEvent('e1', 10),
            ProcEvent('archer', 'marcaCazador', targetId: 'e1'),
            BuffAppliedEvent('e1', 'marcaCazador', BuffStat.damageTaken, 0.15, 3),
            StatusAppliedEvent('e1', StatusKind.poison, 1),
            ProcEvent('archer', 'debilitar', targetId: 'e1'),
            BuffAppliedEvent('e1', 'debilitar', BuffStat.attack, -0.15, 2),
          ]).where((c) => c.id.startsWith('proc.')),
          [cue(Sfx.mark, p + base), cue(Sfx.weaken, p + base)]);
    });

    test('Plaga, Choque Térmico, Guardián y Martillo Bendito', () {
      final cues = _sfx(_Recorder()).battleSounds(const [
        ActionEvent('archer', BattleActionKind.attack, targetId: 'e1'),
        DamageEvent('e1', 10),
        KnockedOutEvent('e1'),
        ProcEvent('archer', 'plagaContagiosa', targetId: 'e2'),
        StatusAppliedEvent('e2', StatusKind.poison, 3),
      ]);
      expect(cues, contains(cue(Sfx.plague, p + base)));
      expect(
          cues,
          contains(cue(Sfx.status('poison'),
              p + base + ProcTiming.streamMs + SessionSfx.statusAfterMs)));
      final more = _sfx(_Recorder()).battleSounds(const [
        ActionEvent('mage', BattleActionKind.skill,
            skillId: 'bola', targetId: 'e1'),
        DamageEvent('e1', 18),
        ProcEvent('mage', 'choqueTermico', targetId: 'e1'),
        StatusAppliedEvent('e1', StatusKind.stun, 1),
        ProcEvent('pal', 'guardian'),
        ProcEvent('pal', 'martilloBendito', targetId: 'e1'),
      ]).map((c) => c.id);
      expect(more, containsAll([Sfx.steam, Sfx.ultCharge, Sfx.anvil]));
    });

    test('en una ULT los procs suenan después de los impactos', () {
      final tajo = ultScriptFor('ult_espada');
      final cues = _sfx(_Recorder()).battleSounds(const [
        UltimateUsedEvent('knight', 'Tajo Final'),
        ActionEvent('knight', BattleActionKind.ultimate,
            skillId: 'ult_espada', targetId: 'e1'),
        DamageEvent('e1', 90, critical: true),
        ProcEvent('knight', 'frenesi'),
        BuffAppliedEvent('knight', 'frenesi', BuffStat.speed, 0.2, 2),
      ]);
      expect(cues.last, cue(Sfx.frenzyWhoosh, tajo.returnAt));
      expect(tajo.returnAt, greaterThan(tajo.lastImpact(1)));
    });

    test('Viento a Favor: el ataque gratis suena después de la habilidad',
        () {
      final cues = _sfx(_Recorder()).battleSounds(const [
        ActionEvent('knight', BattleActionKind.skill,
            skillId: 'giro', allTargets: true),
        DamageEvent('e1', 10),
        DamageEvent('e2', 10),
        ProcEvent('knight', 'vientoFavor', targetId: 'e1'),
        ActionEvent('knight', BattleActionKind.attack, targetId: 'e1'),
        DamageEvent('e1', 20),
      ]);
      expect(
          cues.where((c) => c.id == Sfx.swingBlade).map((c) => c.delayMs),
          [0, base]);
      expect(cues, contains(cue(Sfx.wind, base)));
    });

    test('tope: los procs entran (hasta 4) recortando primarios y el '
        'total no pasa de 12', () {
      final cues = _sfx(_Recorder()).battleSounds([
        for (var i = 0; i < 10; i++) ...const [
          ActionEvent('e1', BattleActionKind.enemyAttack, targetId: 'mage'),
          DamageEvent('mage', 1),
        ],
        const ProcEvent('mage', 'danza'),
        const ProcEvent('mage', 'guardian'),
        const ProcEvent('mage', 'sedSangre'),
        const ProcEvent('mage', 'combustion', targetId: 'e1'),
        const ProcEvent('mage', 'castigoDivino', targetId: 'e1'),
      ]);
      expect(cues, hasLength(SessionSfx.maxCuesPerStep));
      expect(cues.where((c) => c.id.startsWith('proc.')),
          hasLength(SessionSfx.maxProcCues));
      expect(cues.first, cue('enemy.slime'));
    });
  });

  // docs/specs/audio.md § "Quiebre y ULT enemigas".
  group('quiebre y ULT enemigas', () {
    test('tic de la barra una vez por paso, con el golpe; cristal al '
        'quebrarse en el golpe que quiebra', () {
      final sfx = _sfx(_Recorder());
      expect(
          sfx.battleSounds(const [
            ActionEvent('archer', BattleActionKind.attack, targetId: 'e1'),
            DamageEvent('e1', 10),
            BreakEvent('e1', BreakPhase.fill, 10, 50),
          ]),
          [cue(Sfx.shotBow), cue(Sfx.impactArrow, p), cue(Sfx.breakTick, p)]);
      expect(
          sfx.battleSounds(const [
            ActionEvent('knight', BattleActionKind.skill,
                skillId: 'giro', allTargets: true),
            DamageEvent('e1', 5),
            BreakEvent('e1', BreakPhase.fill, 5, 50),
            DamageEvent('e2', 5),
            BreakEvent('e2', BreakPhase.fill, 5, 50),
            DamageEvent('e3', 5),
            BreakEvent('e3', BreakPhase.broken, 50, 50),
          ]).where((c) => c.id.startsWith('break.')),
          [cue(Sfx.breakTick, m), cue(Sfx.breakShatter, m + 2 * st)]);
    });

    test('golpes a un quebrado: el acento una vez por acción', () {
      final cues = _sfx(_Recorder()).battleSounds(const [
        ActionEvent('knight', BattleActionKind.skill,
            skillId: 'giro', allTargets: true),
        DamageEvent('e1', 9, vulnerable: true),
        DamageEvent('e2', 9, vulnerable: true),
      ]);
      expect(cues.where((c) => c.id == Sfx.breakVuln), [cue(Sfx.breakVuln, m)]);
    });

    test('aviso de ULT, quebrado que pierde el turno; bajar o recuperarse '
        'no suenan', () {
      expect(
          _sfx(_Recorder()).battleSounds(const [
            TurnStartedEvent('e1'),
            BreakEvent('e1', BreakPhase.decay, 5, 50),
            EnemyUltWarningEvent('e1', 'eult_diluvio', 'Diluvio Ácido'),
            TurnStartedEvent('e2'),
            BreakEvent('e2', BreakPhase.skipped, 50, 50),
            BreakEvent('e3', BreakPhase.recovered, 0, 62.5),
          ]),
          [cue(Sfx.enemyUltWarn), cue(Sfx.breakDazed)]);
    });

    test('cada ULT enemiga: preparación, descarga e impacto propios en los '
        'tiempos de su guion; los estados no suenan encima', () {
      for (final id in kEnemyUltScripts.keys) {
        final script = ultScriptFor(id);
        final cues = _sfx(_Recorder()).battleSounds([
          EnemyUltEvent('e1', id, '?', allTargets: true),
          const DamageEvent('mage', 20),
          const StatusAppliedEvent('mage', StatusKind.poison, 2),
          const DamageEvent('archer', 20, critical: true),
          const DamageEvent('knight', 20),
          const DamageEvent('pal', 20),
          const KnockedOutEvent('pal'),
        ]);
        final impact = Sfx.ult(id, Sfx.ultImpact);
        expect(cues, [
          cue(Sfx.ult(id, Sfx.ultBuild)),
          cue(Sfx.ult(id, Sfx.ultRelease), script.buildMs),
          cue(impact, script.impactFor(0)),
          cue(impact, script.impactFor(1)),
          cue(Sfx.critClink, script.impactFor(1)),
          cue(impact, script.impactFor(2)),
          cue(Sfx.koPlayer, script.impactFor(3) + SessionSfx.koAfterMs),
        ], reason: id);
        for (final c in cues) {
          expect(kSfxCatalog, contains(c.id), reason: c.id);
        }
      }
    });

    test('ULT enemiga sin sonidos propios: el beep del prototipo', () {
      expect(
          _sfx(_Recorder())
              .battleSounds(const [EnemyUltEvent('e1', 'eult_x', '?')]),
          [cue(Sfx.ultimate)]);
    });
  });
}
