// Capturas del TUTORIAL v0.9.6 (todos actúan, votación de roles, ENTRENAR) (docs/release_shots/v0.9.6). NO es parte de la
// suite: vive fuera de test/. Correr con
//   flutter test tool/shots/v096_shots_test.dart
//
// Todo se dibuja dentro de `EcosApp` con los GameSettings por defecto (lo
// que ve un jugador nuevo: ALTO CONTRASTE, texto normal, CRT FUERTE…).
// 03 y 04 son la `WorldScreen` real con un `SessionController` real.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/core/settings/crt_filter.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/party_store.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/tutorial_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.9.6';
const _size = Size(1280, 720); // lógicos; ×1.5 = 1920×1080
const _dpr = 1.5;

late GameSprites _sprites;

Future<void> _setup(WidgetTester tester) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = _size * _dpr;
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.reset);
  await tester.runAsync(() async {
    _sprites = await GameSprites.load(await SpriteCatalog.load());
    await CrtShaders.load();
  });
}

/// Los ajustes de un jugador nuevo.
List<Override> _settings() => [
      gameSettingsProvider.overrideWith((ref) => GameSettingsController(
          store: InMemoryGameSettingsStore(), initial: const GameSettings())),
    ];

Future<void> _shot(WidgetTester tester, String name) async {
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  await tester.runAsync(() async {
    final img = await layer.toImage(Offset.zero & (_size * _dpr));
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_out/$name');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// La app real en el lobby: Ana (sin TUTORIAL) con su party de 3.
Future<SessionController> _world(WidgetTester tester) async {
  await tester.pumpWidget(EcosApp(
    overrides: [
      ..._settings(),
      sessionEngineProvider.overrideWithValue(sessionEngine()),
      profileStoreProvider.overrideWithValue(InMemoryProfileStore(
          progression.normalize(PlayerProfile(
              name: 'Ana', classId: 'guerrero', level: 8)))),
      partyStoreProvider.overrideWithValue(InMemoryPartyStore(slots: {
        's2': progression
            .normalize(PlayerProfile(name: 'Beto', classId: 'maga', level: 8)),
        's3': progression.normalize(
            PlayerProfile(name: 'Caro', classId: 'tirador', level: 8)),
        's4': progression.normalize(
            PlayerProfile(name: 'Dani', classId: 'paladin', level: 8)),
      }, party: const [
        's2',
        's3',
        's4'
      ])),
      tutorialStoreProvider.overrideWithValue(InMemoryTutorialStore(0)),
      sessionClockProvider
          .overrideWithValue(const SessionClock(autoStart: false)),
      gameSpritesProvider.overrideWith((ref) => _sprites),
    ],
    home: const WorldScreen(),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final c = ProviderScope.containerOf(tester.element(find.byType(WorldScreen)))
      .read(sessionControllerProvider.notifier);
  // Los compañeros cargan async.
  for (var i = 0; i < 20 && c.view!.session.playerList.length < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 20)));
    c.advance(0.05);
    await tester.pump();
  }
  expect(c.view!.session.playerList.length, 4);
  return c;
}

/// Avanza el tutorial real (Ana sola con 3 compañeros) hasta que [stop]
/// diga basta. Ana hace lo que dice el panel y vota SIGUIENTE.
Future<void> _until(WidgetTester tester, SessionController c,
    bool Function(GameSession s, TutorialState t) stop) async {
  const rules = TutorialRules();
  var ok = false;
  for (var i = 0; i < 4000; i++) {
    c.advance(0.05);
    final s = c.view!.session;
    final t = s.tutorial!;
    if (stop(s, t)) {
      ok = true;
      break;
    }
    final step = rules.currentStep(t);
    if (t.card != null) {
      c.ackTutorial();
    } else if (step is TutorialPlayerStep &&
        t.prepared &&
        s.battle!.state.currentId == c.view!.localId) {
      c.battleCommand(
          rules.scripted(step, s.battle!.state.byId(c.view!.localId)!)!);
    }
  }
  expect(ok, isTrue);
  await tester.pump();
}

void main() {
  const rules = TutorialRules();

  testWidgets('01 etapa con todos actuando', (tester) async {
    await _setup(tester);
    final c = await _world(tester);
    expect(c.startTutorial(), isTrue);
    // Etapa 3: un compañero hace su parte (MIRÁ … · para qué) antes de la
    // acción clave.
    await _until(
        tester,
        c,
        (s, t) =>
            rules.currentStage(t)?.number == 3 &&
            t.step == 1 &&
            t.card == null &&
            t.prepared);
    await _settle(tester, 400);
    await _shot(tester, '01_etapa_todos_actuan.png');
    await _settle(tester, 3000); // los sonidos terminan
  });

  testWidgets('02 votación de roles', (tester) async {
    await _setup(tester);
    final c = await _world(tester);
    expect(c.startTutorial(), isTrue);
    await _until(tester, c, (s, t) => t.phase == TutorialPhase.menu);
    expect(c.tutorialPick('roles'), isTrue);
    for (var i = 0; i < 4; i++) {
      c.advance(0.05);
    }
    expect(c.view!.session.tutorial!.phase, TutorialPhase.roles);
    await tester.pump();
    await _settle(tester, 400);
    await _shot(tester, '02_votacion_roles.png');
    await _settle(tester, 3000); // los sonidos terminan
  });

  testWidgets('03 ENTRENAR con narrador', (tester) async {
    await _setup(tester);
    final c = await _world(tester);
    expect(c.startTutorial(), isTrue);
    await _until(tester, c, (s, t) => t.phase == TutorialPhase.menu);
    expect(c.tutorialPick('train'), isTrue);
    for (var i = 0; i < 4000; i++) {
      c.advance(0.05);
      final s = c.view!.session;
      final t = s.tutorial!;
      if (t.narration.length >= 7) break;
      final b = s.battle!;
      if (b.waitingForPlayer && b.state.currentId == c.view!.localId) {
        final me = b.state.current!;
        final sk = me.skillIds.firstWhere(
            (id) => me.mp >= (c.engine.catalog.skills[id]?.mp ?? 99) &&
                (c.engine.catalog.skills[id]?.requires.isEmpty ?? false),
            orElse: () => '');
        c.battleCommand(sk.isEmpty
            ? const AttackCommand(targetId: 'e0')
            : SkillCommand(sk, targetId: 'e0'));
      }
    }
    await tester.pump();
    await _settle(tester, 600);
    await _shot(tester, '03_entrenar_narrador.png');
    await _settle(tester, 3000); // los sonidos terminan
  });
}
