import 'package:echos_del_tiempo/core/audio/sfx_catalog.dart';
import 'package:echos_del_tiempo/core/audio/sfx_service.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_sfx.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';
import 'world_test_helpers.dart';

class _Recorder extends SfxService {
  final played = <Sfx>[];

  @override
  void play(Sfx sfx) => played.add(sfx);
}

void main() {
  late SessionController c;

  Future<void> started() async {
    c = SessionController(
      engine: sessionEngine(),
      store: InMemoryProfileStore(),
      clock: const SessionClock(autoStart: false),
    );
    await c.start();
  }

  tearDown(() {
    if (c.mounted) c.dispose();
  });

  test('números de batalla, ULT y subida de nivel', () async {
    await started();
    final rec = _Recorder();
    final sfx = SessionSfx(rec, localId: c.localId)..onView(c.view);
    sfx.onEvent(const BattleStepEvent([
      ActionEvent('local', BattleActionKind.skill, skillId: 'cura'),
      HealEvent('local', 10),
      ActionEvent('local', BattleActionKind.ether, targetId: 'local'),
      HealEvent('local', 5, mana: true),
      ActionEvent('e1', BattleActionKind.enemyAttack, targetId: 'local'),
      DamageEvent('local', 7),
      DamageEvent('local', 12, critical: true),
      DamageEvent('local', 3, fromStatus: true, statusSource: StatusKind.poison),
      DamageEvent('e1', 4, fromStatus: true, statusSource: StatusKind.burn),
      DamageEvent('e1', 9),
      UltimateUsedEvent('local', 'Tajo Final'),
      KnockedOutEvent('e1'),
      ActionEvent('local', BattleActionKind.dual, partnerId: 'p2'),
      ActionEvent('e1', BattleActionKind.enemyArea, allTargets: true),
      ActionEvent('local', BattleActionKind.attack),
    ]));
    sfx.onEvent(const LevelUpEvent('local', 2));
    sfx.onEvent(const SystemMessageEvent('nada'));
    expect(rec.played, [
      Sfx.heal, // cura: número verde
      Sfx.hit, // +MP celeste
      Sfx.hurt,
      Sfx.hit, // crítico a un jugador
      Sfx.heal, // veneno: número verde
      Sfx.hit, // quemadura: número naranja
      Sfx.hit, // daño a un enemigo
      Sfx.ultimate,
      Sfx.flash,
      Sfx.flash,
      Sfx.levelUp,
    ]);
  });

  test('Regeneración al empezar el turno: número #55efc4 (420 Hz), el '
      'maná no suena', () async {
    await started();
    final rec = _Recorder();
    final sfx = SessionSfx(rec, localId: c.localId)..onView(c.view);
    sfx.onEvent(const BattleStepEvent([
      TurnStartedEvent('local'),
      HealEvent('local', 6),
      HealEvent('local', 2, mana: true),
      DamageEvent('local', 4, fromStatus: true, statusSource: StatusKind.burn),
    ]));
    expect(rec.played, [Sfx.hit, Sfx.hit]);
  });

  test('tu turno suena una vez y la cuenta regresiva con ≤ 5 s', () async {
    await started();
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
    await started();
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
