// Capturas de novedades v0.9 (docs/release_shots/v0.9.0). NO es parte de la
// suite: vive fuera de test/. Correr con
//   flutter test tool/shots/v090_shots_test.dart
//
// Todo se dibuja dentro de `EcosApp` con los GameSettings por defecto (lo
// que ve un jugador nuevo: ALTO CONTRASTE, texto normal, CRT FUERTE…).
// 03 y 04 son la `WorldScreen` real con un `SessionController` real.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/core/settings/crt_filter.dart';
import 'package:echos_del_tiempo/core/settings/game_settings.dart';
import 'package:echos_del_tiempo/core/settings/settings_providers.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_command_window.dart';
import 'package:echos_del_tiempo/features/combat/presentation/battle_screen.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/arena/arena_painter.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/arena/arena_spec.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_layout.dart';
import 'package:echos_del_tiempo/features/combat/presentation/scene/battle_scene.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/world_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/classes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/passive_tree_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_command.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_event.dart';
import 'package:echos_del_tiempo/game_engine/models/battle_state.dart';
import 'package:echos_del_tiempo/game_engine/models/party_store.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/player_state.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/status.dart';
import 'package:echos_del_tiempo/game_engine/models/tutorial_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/passive_tree_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/stats_calculator.dart';
import 'package:echos_del_tiempo/game_engine/rules/tutorial_rules.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../test/game_engine/session_test_helpers.dart';
import '../../test/real_fonts.dart';

const _out = 'docs/release_shots/v0.9.0';
const _size = Size(1280, 720); // lógicos; ×1.5 = 1920×1080
const _dpr = 1.5;

BattlePartyMember _member(String classId, String name, int level) {
  final cls = kClasses[classId]!;
  return BattlePartyMember(
    id: classId,
    name: name,
    potions: 2,
    ethers: 1,
    build: PlayerBuild(
      classId: classId,
      level: level,
      attributes: PlayerAttributes.base(cls.baseAttributes),
      equippedWeapon: kWeapons[cls.startWeaponId]!,
    ),
  );
}

BattleEngine _engine() => BattleEngine(
      stats: StatsCalculator(
          classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)),
      random: () => 0.99,
    );

BattleState _start(BattleEngine e, List<String> enemies,
    {String first = 'guerrero'}) {
  final s = e.start(
    party: [
      _member('guerrero', 'Ana', 8),
      _member('maga', 'Beto', 8),
      _member('tirador', 'Caro', 8),
      _member('paladin', 'Dani', 8),
    ],
    enemyTypes: enemies,
    triggeredBy: first,
  );
  return e.nextTurn(s.state).state;
}

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

final _arenas = ArenaPainter();

/// [BattleView] como la arma `SessionBattleScreen` (arena de zona 1).
Widget _battle(BattleState b,
        {GlobalKey? key,
        List<BattleEvent> events = const [],
        int seq = 0,
        required String localId,
        bool canAct = true,
        SceneOptions options = const SceneOptions()}) =>
    BattleView(
      key: key,
      battle: b,
      canAct: canAct,
      localId: localId,
      sprites: _sprites,
      events: events,
      eventSeq: seq,
      battleId: 1,
      random: _FixedRandom(),
      sceneOptions: options,
      arena: BattleArena.stage(
          paintWorld: (c, r, t) => _arenas.paint(c, r, t,
              const ArenaSpec(
                  theme: ArenaTheme.pradera, kind: EncounterKind.normal))),
      onCommand: (_) => true,
    );

Future<void> _app(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(EcosApp(
    overrides: _settings(),
    home: Scaffold(body: body),
  ));
  await tester.pump();
}

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

void main() {
  testWidgets('01 fisurado y quebrar', (tester) async {
    await _setup(tester);
    final e = _engine();
    final s = _start(e, const ['golem', 'slime', 'bat'], first: 'tirador');
    final foe = s.enemies.first;
    foe.fissured = true;
    foe.breakGauge = foe.breakBase * 0.85;
    for (final p in s.party) {
      p.pulse = BattleEngine.pulseMax - 1;
    }
    final events = [
      BreakEvent(foe.id, BreakPhase.fissured, foe.breakGauge, foe.breakBase)
    ];
    await _app(tester, _battle(s, localId: 'tirador', events: events, seq: 1));
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    menu.selectCategory(BattleCategory.skills);
    await tester.pump();
    final ids = s.current!.skillIds;
    for (var i = 0; i < ids.indexOf('quebrar'); i++) {
      menu.handleKey(LogicalKeyboardKey.arrowDown);
    }
    await _settle(tester, 700);
    await _shot(tester, '01_fisurado_y_quebrar.png');
  });

  testWidgets('02 convergencia', (tester) async {
    await _setup(tester);
    final e = _engine();
    BattleStep? step;
    BattleState? before;
    for (final who in ['tirador', 'guerrero', 'maga', 'paladin']) {
      final probe = _start(e, const ['slime'], first: who);
      if (probe.currentId != who) continue;
      for (final sk in probe.current!.skillIds) {
        final s = _start(e, const ['slime'], first: who);
        s.enemies.first.statuses = {StatusKind.burn: 10};
        s.current!
          ..pulse = BattleEngine.pulseMax
          ..mp = s.current!.maxMp.toDouble();
        final snap = _start(e, const ['slime'], first: who);
        snap.enemies.first.statuses = {StatusKind.burn: 10};
        final r = e.command(s, who, SkillCommand(sk, targetId: 'e0'));
        if (r != null &&
            r.events.whereType<ReactionEvent>().any((x) => x.kind.convergence)) {
          step = r;
          before = snap;
          break;
        }
      }
      if (step != null) break;
    }
    expect(step, isNotNull, reason: 'ninguna habilidad dispara Convergencia');
    final key = GlobalKey();
    const opts = SceneOptions(extendedLog: true);
    await _app(tester,
        _battle(before!, key: key, localId: 'tirador', options: opts));
    await _app(
        tester,
        _battle(step!.state,
            key: key,
            localId: 'tirador',
            events: step.events,
            seq: 1,
            options: opts));
    await _settle(tester, 450);
    // Con REGISTRO EXTENDIDO, la línea de la Convergencia pasa debajo de
    // la banda (entera) cuando Caro usa su acción del Instante.
    final cur = step.state.currentId!;
    final next = e.command(
        step.state, cur, AttackCommand(targetId: step.state.enemies.first.id))!;
    await _app(
        tester,
        _battle(next.state,
            key: key,
            localId: 'tirador',
            canAct: false,
            events: step.events,
            seq: 1,
            options: opts));
    await _settle(tester, 150);
    await _shot(tester, '02_convergencia.png');
  });

  testWidgets('03 tutorial (flujo real)', (tester) async {
    await _setup(tester);
    final c = await _world(tester);
    expect(c.startTutorial(), isTrue);
    const rules = TutorialRules();
    var ok = false;
    for (var i = 0; i < 4000; i++) {
      c.advance(0.05);
      final s = c.view!.session;
      final t = s.tutorial!;
      final st = rules.currentStage(t);
      final step = rules.currentStep(t);
      if (st?.number == 3 &&
          step is TutorialPlayerStep &&
          t.card == null &&
          t.prepared &&
          s.battle!.state.currentId == c.view!.localId) {
        ok = true;
        break;
      }
      if (t.card != null) {
        c.ackTutorial();
      } else if (step is TutorialPlayerStep &&
          t.prepared &&
          s.battle!.state.currentId == c.view!.localId) {
        // Ana hace lo que dice su cartel en las etapas 1 y 2.
        c.battleCommand(
            rules.scripted(step, s.battle!.state.byId(c.view!.localId)!)!);
      }
    }
    expect(ok, isTrue, reason: 'llegó a la etapa 3 con el turno de Ana');
    await tester.pump();
    final menu = tester.state<BattleViewState>(find.byType(BattleView));
    menu.selectCategory(BattleCategory.skills);
    await _settle(tester, 400);
    expect(find.textContaining('TE TOCA'), findsOneWidget);
    await _shot(tester, '03_tutorial.png');
  });

  testWidgets('04 mostrador', (tester) async {
    await _setup(tester);
    final c = await _world(tester);
    c.openPanel(WorldPanel.missionBoard);
    await _settle(tester, 300);
    expect(find.textContaining('Primero, todos tienen que hacer el TUTORIAL'),
        findsWidgets);
    await _shot(tester, '04_mostrador_tutorial.png');
  });
}

class _FixedRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.5;
  @override
  int nextInt(int max) => 0;
}
