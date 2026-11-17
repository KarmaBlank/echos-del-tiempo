import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_fx.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_sfx.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
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
          cue(Sfx.impactHurt, m),
          cue('status.poison', m + SessionSfx.statusAfterMs),
          cue('enemy.bat'),
          cue(Sfx.impactHurt, m),
          cue(Sfx.critClink, m),
          cue('enemy.golem'),
          cue(Sfx.enemyHeavy, SessionSfx.heavyBoomMs),
          cue(Sfx.impactHurt, m),
          cue(Sfx.koPlayer, m + SessionSfx.koAfterMs),
        ]);
    expect(
        sfx.battleSounds(const [
          ActionEvent('x', BattleActionKind.enemyArea, allTargets: true),
          DamageEvent('mage', 4),
          DamageEvent('archer', 4),
        ]),
        [
          cue(Sfx.flash),
          cue(Sfx.enemyGeneric), // tipo desconocido
          cue(Sfx.impactHurt, m),
          cue(Sfx.impactHurt, m + st),
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
          cue(Sfx.flash),
          cue(Sfx.dualCast),
          // guerrero+maga = Espada Llameante (Quemadura).
          cue(Sfx.impactFire, BattleFx.dualDelayMs),
        ]);
  });

  test('ULT de cada tipo de arma: preparación @0, descarga al terminar la '
      'preparación, impacto en el impacto del guion de cada objetivo (3 '
      'como máximo) y clink en los críticos', () {
    for (final e in kUltimates.entries) {
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
          cue(Sfx.impactHurt, m),
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
}
