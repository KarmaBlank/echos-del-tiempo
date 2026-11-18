import 'dart:collection';

import 'package:echos_del_tiempo/core/audio/music/music_catalog.dart';
import 'package:echos_del_tiempo/core/audio/music/music_service.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/ult_cinematic.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_music.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/map_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/audio/fake_music_player.dart';
import '../../game_engine/session_test_helpers.dart';
import 'world_test_helpers.dart';

void main() {
  group('MusicSelector.trackFor', () {
    test('pueblo, mapa del mundo, preparación y resultado', () {
      expect(MusicSelector.trackFor(mode: SessionMode.lobby, inTown: true),
          Music.town);
      expect(MusicSelector.trackFor(mode: SessionMode.lobby, inTown: false),
          Music.overworld);
      expect(MusicSelector.trackFor(mode: SessionMode.prep, inTown: false),
          Music.town);
      expect(MusicSelector.trackFor(mode: SessionMode.result), Music.town);
    });

    test('cada zona en el campo (y en la pausa de nivel)', () {
      for (var z = 1; z <= 10; z++) {
        expect(MusicSelector.trackFor(mode: SessionMode.field, zone: z),
            'zone$z');
        expect(MusicSelector.trackFor(mode: SessionMode.levelUp, zone: z),
            'zone$z');
        expect(kMusicCatalog.containsKey(Music.zone(z)), isTrue, reason: '$z');
      }
    });

    test('las zonas 6–10 tienen pieza propia (no prestada)', () {
      expect(
          [
            for (var z = 6; z <= 10; z++)
              MusicSelector.trackFor(
                  mode: SessionMode.field, zone: z, theme: 'abismo'),
          ],
          ['zone6', 'zone7', 'zone8', 'zone9', 'zone10']);
    });

    test('misiones sin zona por el tema del mapa', () {
      for (final (theme, z) in [
        ('pradera', 1),
        ('bosque', 2),
        ('ruinas', 3),
        ('cavernas', 4),
        ('fortaleza', 5),
        ('laberinto', 6),
        ('grieta', 7),
        ('cementerio', 8),
        ('abismo', 9),
        ('corazon', 10),
        ('otro', 3),
        (null, 3),
      ]) {
        expect(
            MusicSelector.trackFor(
                mode: SessionMode.field, zone: 0, theme: theme),
            Music.zone(z),
            reason: '$theme');
      }
    });

    test('batalla y jefe', () {
      expect(MusicSelector.trackFor(mode: SessionMode.battle, zone: 2),
          Music.battle);
      expect(
          MusicSelector.trackFor(
              mode: SessionMode.battle, zone: 2, boss: true),
          Music.boss);
      expect(
          MusicSelector.trackFor(
              mode: SessionMode.battle, zone: 7, boss: true,
              bossId: 'bestiaMagma'),
          Music.boss);
    });

    test('jefe final: el Devorador tiene su variante', () {
      expect(
          MusicSelector.trackFor(
              mode: SessionMode.battle, zone: 10, boss: true,
              bossId: MusicSelector.finalBossId),
          Music.bossFinal);
      expect(MusicSelector.finalBossId, 'devorador');
      expect(kMusicCatalog.containsKey(Music.bossFinal), isTrue);
      // Sin jefe (un común del Corazón del Tiempo) es la de batalla.
      expect(
          MusicSelector.trackFor(
              mode: SessionMode.battle, zone: 10, bossId: 'devorador'),
          Music.battle);
    });

    test('el id del jefe sale del enemigo marcado como jefe', () {
      Combatant enemy(String type, {bool boss = false}) => Combatant(
          id: type,
          name: type,
          isPlayer: false,
          hp: 10,
          maxHp: 10,
          speed: 1,
          attack: 1,
          critChance: 0,
          enemyType: type,
          boss: boss);
      expect(MusicSelector.bossIdOf(null), isNull);
      expect(
          MusicSelector.bossIdOf(BattleState(
              party: [], enemies: [enemy('heraldoEras')])),
          isNull);
      expect(
          MusicSelector.bossIdOf(BattleState(party: [], enemies: [
            enemy('fragmentoTiempo'),
            enemy('devorador', boss: true),
          ])),
          'devorador');
    });

    test('pueblo con histéresis en el borde', () {
      expect(MusicSelector.inTown(25, 13, wasInTown: false), isTrue);
      expect(MusicSelector.inTown(26, 5, wasInTown: false), isFalse);
      // Saliendo: recién a 2 tiles del borde deja de ser pueblo.
      expect(MusicSelector.inTown(27, 5, wasInTown: true), isTrue);
      expect(MusicSelector.inTown(28, 5, wasInTown: true), isFalse);
      expect(MusicSelector.inTown(5, 15, wasInTown: true), isTrue);
      expect(MusicSelector.inTown(5, 16, wasInTown: true), isFalse);
    });

    test('duración del duck: la ULT más larga del paso', () {
      final player = ultScriptFor('ult_espada').totalMs;
      expect(MusicSelector.ultMs(const [DamageEvent('e1', 3)]), 0);
      expect(
          MusicSelector.ultMs(const [
            ActionEvent('p', BattleActionKind.ultimate, skillId: 'ult_espada'),
          ]),
          player);
      expect(
          MusicSelector.ultMs(const [EnemyUltEvent('e1', 'x', 'X')]),
          kDefaultUltScript.totalMs);
    });
  });

  group('SessionMusic con una sesión real', () {
    SessionController? c;

    tearDown(() {
      final ctrl = c;
      if (ctrl != null && ctrl.mounted) ctrl.dispose();
      c = null;
    });

    test('pueblo → mapa → zona → batalla → victoria → ... → resultado',
        () async {
      final ctrl = c = SessionController(
        engine: sessionEngine(),
        store: InMemoryProfileStore(),
        clock: const SessionClock(autoStart: false),
      );
      await ctrl.start();
      final music = _RecMusic();
      final sm = SessionMusic(music, localId: ctrl.localId,
          themeOf: (id) => ctrl.engine.catalog.mission(id)?.theme);
      final jingles = music.played;
      final tracks = <String>[];
      final won = <int>{}, lost = <int>{};
      final remove = ctrl.addListener((v) {
        sm.onView(v);
        final b = v?.session.battle;
        final o = b?.state.outcome;
        if (b != null && o != null) (o.victory ? won : lost).add(b.id);
        final t = music.current;
        if (t != null && (tracks.isEmpty || tracks.last != t)) tracks.add(t);
        music.tick(0.05);
      });
      addTearDown(remove);

      // Arranca en el pueblo.
      expect(music.current, Music.town);

      // Fuera del pueblo, en el mapa del mundo.
      const ts = MapGenerator.tileSize;
      ctrl.teleport(40.0 * ts, 30.0 * ts);
      ctrl.advance(0.05);
      expect(ctrl.view!.mode, SessionMode.lobby);
      expect(music.current, Music.overworld);

      // Misión de la pradera.
      ctrl.proposeMission('m1');
      ctrl.advance(0.1);
      expect(music.current, Music.town, reason: 'preparación');
      ctrl.setReady(true);
      ctrl.advance(0.1);
      expect(ctrl.view!.mode, SessionMode.field);
      expect(music.current, Music.zone(1));

      startBattleWithFirstGroup(ctrl);
      expect(ctrl.view!.mode, SessionMode.battle);
      expect(music.current, Music.battle);

      playUntilResult(ctrl);
      expect(ctrl.view!.mode, SessionMode.result);
      expect(music.current, Music.town);
      expect(
          tracks,
          containsAllInOrder([
            Music.town, Music.overworld, Music.town, Music.zone(1),
            Music.battle, Music.boss, Music.town,
          ]));
      // Un jingle por batalla terminada; el resultado no repite el de la
      // última (la del jefe).
      expect(won.length + lost.length, greaterThanOrEqualTo(2));
      expect(jingles.where((j) => j == Music.victory).length, won.length);
      expect(jingles.where((j) => j == Music.defeat).length, lost.length);
    });

    test('subir de nivel toca su jingle después de la victoria', () async {
      final ctrl = c = SessionController(
        engine: sessionEngine(),
        store: InMemoryProfileStore(),
        clock: const SessionClock(autoStart: false),
      );
      await ctrl.start();
      final music = _RecMusic();
      final sm = SessionMusic(music, localId: ctrl.localId,
          themeOf: (id) => ctrl.engine.catalog.mission(id)?.theme);
      addTearDown(ctrl.addListener(sm.onView));
      ctrl.proposeMission('m1');
      ctrl.advance(0.05);
      ctrl.setReady(true);
      ctrl.advance(0.05);
      for (var i = 0; i < 6 && ctrl.view!.mode != SessionMode.levelUp; i++) {
        if (ctrl.view!.mode != SessionMode.field) break;
        startBattleWithFirstGroup(ctrl);
        while (ctrl.view!.mode == SessionMode.battle) {
          if (ctrl.view!.myTurn) ctrl.battleCommand(const AttackCommand());
          ctrl.advance(0.05);
        }
      }
      expect(ctrl.view!.mode, SessionMode.levelUp);
      expect(music.played.sublist(music.played.length - 2),
          [Music.victory, Music.levelUp]);
      expect(music.current, Music.zone(1));
    });
  });

  group('jingles del resultado', () {
    SessionView view(GameSession s) =>
        SessionView(session: s, localId: 'p0', map: MapGenerator.overworld());

    GameSession session(SessionMode mode, {MissionResult? result}) =>
        GameSession(
          mode: mode,
          players: LinkedHashMap.of({
            'p0': SessionPlayer(
                id: 'p0',
                profile: newProfile('Ana', 'guerrero'),
                x: 0,
                y: 0,
                hp: 10,
                mp: 10,
                maxHp: 10,
                maxMp: 10),
          }),
          result: result,
        );

    MissionResult result({required bool success, Map<String, int>? unlocked}) =>
        MissionResult(
          id: 7,
          missionId: 'z2',
          missionName: 'Bosque Hondo',
          success: success,
          rank: success ? MissionRank.a : MissionRank.d,
          time: 100,
          xp: 0,
          credits: 0,
          bonus: 0,
          bonusPercent: 0,
          kos: 0,
          elites: 0,
          eliteDrops: const [],
          drops: const {},
          zone: 2,
          unlocked: unlocked ?? const {},
        );

    test('misión ganada sin batalla final: victoria + zona desbloqueada', () {
      final music = _RecMusic();
      final sm = SessionMusic(music, localId: 'p0')
        ..onView(view(session(SessionMode.field)))
        ..onView(view(session(SessionMode.result,
            result: result(success: true, unlocked: {'p0': 3}))));
      expect(music.played, [Music.victory, Music.zoneUnlocked]);
      // La misma pantalla de resultado no vuelve a sonar.
      sm.onView(view(session(SessionMode.result,
          result: result(success: true, unlocked: {'p0': 3}))));
      expect(music.played, [Music.victory, Music.zoneUnlocked]);
      expect(music.current, Music.town);
    });

    test('la zona que desbloquea otro jugador no suena', () {
      final music = _RecMusic();
      SessionMusic(music, localId: 'p0')
        ..onView(view(session(SessionMode.field)))
        ..onView(view(session(SessionMode.result,
            result: result(success: true, unlocked: {'p1': 3}))));
      expect(music.played, [Music.victory]);
    });

    test('misión fallada: derrota', () {
      final music = _RecMusic();
      SessionMusic(music, localId: 'p0')
        ..onView(view(session(SessionMode.field)))
        ..onView(view(session(SessionMode.result,
            result: result(success: false))));
      expect(music.played, [Music.defeat]);
    });

    test('lo que ya pasó antes de mirar no suena (unirse a mitad)', () {
      final music = _RecMusic();
      SessionMusic(music, localId: 'p0').onView(view(session(
          SessionMode.result,
          result: result(success: true, unlocked: {'p0': 3}))));
      expect(music.played, isEmpty);
      expect(music.current, Music.town);
    });
  });
}

/// Música con el reproductor falso que registra los jingles pedidos.
class _RecMusic extends MusicService {
  _RecMusic() : super(player: FakeMusicPlayer(), autoTick: false);

  final played = <String>[];

  @override
  void playJingle(String id) {
    played.add(id);
    super.playJingle(id);
  }
}
