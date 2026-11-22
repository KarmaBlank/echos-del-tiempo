import 'dart:io';

import 'package:echos_del_tiempo/features/lobby/data/json_file_profile_store.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../game_engine/session_test_helpers.dart';
import 'world_test_helpers.dart';

void main() {
  late InMemoryProfileStore store;
  late SessionController c;

  Future<void> started() async {
    store = InMemoryProfileStore();
    c = SessionController(
      engine: sessionEngine(),
      store: store,
      clock: const SessionClock(autoStart: false),
    );
    await c.start();
  }

  tearDown(() {
    if (c.mounted) c.dispose();
  });

  test('arranca en el lobby con un perfil nuevo y lo guarda', () async {
    await started();
    final v = c.view!;
    expect(v.mode, SessionMode.lobby);
    expect(v.me!.name, SessionController.defaultName);
    expect(v.messages.last, contains('se unió'));
    // El jugador local adopta la posición de spawn del host.
    expect(c.local.x, v.me!.x);
    expect(c.local.y, v.me!.y);
    await pumpEventQueue();
    expect((await store.load())!.name, SessionController.defaultName);
  });

  test('carga el perfil guardado', () async {
    store = InMemoryProfileStore(
        progression.normalize(PlayerProfile(name: 'Ana', classId: 'maga')));
    c = SessionController(
        engine: sessionEngine(),
        store: store,
        clock: const SessionClock(autoStart: false));
    await c.start();
    expect(c.view!.me!.profile.classId, 'maga');
    expect(c.view!.me!.name, 'Ana');
  });

  test('moverse hasta el mostrador y abrirlo con E', () async {
    await started();
    const ts = MapGenerator.tileSize;
    // Hacia arriba hasta chocar con el mostrador (fila 2).
    for (var i = 0; i < 60; i++) {
      c.updateLocal(0.05, 0, -1);
    }
    expect(c.local.y, lessThan(4.6 * ts));
    c.advance(0.05); // el host recibe la posición y recalcula avisos
    expect(c.view!.prompt, WorldPrompt.missionBoard);
    expect(c.handleKey(LogicalKeyboardKey.keyE), isTrue);
    expect(c.view!.panel, WorldPanel.missionBoard);
    // Con un panel abierto no se mueve.
    final y = c.local.y;
    c.updateLocal(0.05, 0, 1);
    expect(c.local.y, y);
    c.handleKey(LogicalKeyboardKey.escape);
    expect(c.view!.panel, isNull);
  });

  test('misión: votación, preparación, campo, batalla y resultado', () async {
    await started();
    final events = <SessionEvent>[];
    c.events.listen(events.add);

    expect(c.proposeMission('m1'), isTrue);
    c.advance(0.05);
    expect(c.view!.mode, SessionMode.prep);
    expect(c.view!.panel, WorldPanel.prep);
    c.closePanel(); // en preparación no se cierra
    expect(c.view!.panel, WorldPanel.prep);

    final lobbyEpoch = c.local.epoch;
    expect(c.setReady(true), isTrue);
    c.advance(0.05);
    expect(c.view!.mode, SessionMode.field);
    expect(c.view!.panel, isNull);
    expect(c.local.epoch, greaterThan(lobbyEpoch));
    expect(c.view!.map.lobby, isFalse);

    startBattleWithFirstGroup(c);
    expect(c.view!.mode, SessionMode.battle);
    waitForMyTurn(c);
    final seq = c.view!.battleEventSeq;
    expect(c.battleCommand(const AttackCommand()), isTrue);
    expect(c.view!.battleEventSeq, greaterThan(seq));
    await pumpEventQueue(); // el stream entrega en microtareas
    expect(events.whereType<BattleStepEvent>(), isNotEmpty);

    playUntilResult(c);
    expect(c.view!.session.result, isNotNull);
    expect(c.view!.session.result, isNotNull);
    await pumpEventQueue();
    // Al terminar la misión el perfil se guarda.
    final saved = await store.load();
    expect(saved!.xp + saved.level, greaterThan(1));

    expect(c.backToLobby(), isTrue);
    expect(c.view!.mode, SessionMode.lobby);
  });

  test('la subida de nivel obliga a repartir puntos', () async {
    await started();
    c.proposeMission('m1');
    c.advance(0.05);
    c.setReady(true);
    c.advance(0.05);
    // Batallas hasta subir de nivel.
    for (var i = 0; i < 6 && c.view!.mode != SessionMode.levelUp; i++) {
      if (c.view!.mode != SessionMode.field) break;
      startBattleWithFirstGroup(c);
      while (c.view!.mode == SessionMode.battle) {
        if (c.view!.myTurn) c.battleCommand(const AttackCommand());
        c.advance(0.05);
      }
    }
    expect(c.view!.mode, SessionMode.levelUp);
    expect(c.view!.mustAllocate, isTrue);
    expect(c.view!.panel, WorldPanel.character);
    c.closePanel();
    expect(c.view!.panel, WorldPanel.character, reason: 'no se puede cerrar');
    final pts = c.view!.me!.profile.points;
    expect(c.allocate({Attribute.vit: pts}), isTrue);
    c.advance(0.05);
    expect(c.view!.mode, SessionMode.field);
    expect(c.view!.panel, isNull);
  });

  group('JsonFileProfileStore', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ecos_profile'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('ida y vuelta por disco', () async {
      final s = JsonFileProfileStore(File('${dir.path}/sub/profile.json'));
      expect(await s.load(), isNull);
      final p = progression.normalize(
          PlayerProfile(name: 'Ana', classId: 'tirador', credits: 77));
      await s.save(p);
      final back = await s.load();
      expect(back!.name, 'Ana');
      expect(back.classId, 'tirador');
      expect(back.credits, 77);
    });

    test('un JSON corrupto es "sin perfil"', () async {
      final f = File('${dir.path}/profile.json')..writeAsStringSync('{nope');
      expect(await JsonFileProfileStore(f).load(), isNull);
    });
  });

  test('ProfileStore por defecto en escritorio', () {
    expect(JsonFileProfileStore.forPlatform(), isA<ProfileStore>());
  }, skip: !(Platform.isWindows || Platform.isLinux || Platform.isMacOS));
}
