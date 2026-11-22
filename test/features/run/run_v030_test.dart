import 'package:echos_del_tiempo/features/run/presentation/run_screen.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_mode.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/rules/battle_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:echos_del_tiempo/game_engine/rules/progression_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/run_tuning.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';

/// Travesía v0.3.0 (roguelike.md § 12.2).
void main() {
  final travesiaRules = ProgressionRules(
      stats: statsCalc,
      catalog: GameCatalog.standard,
      ignoreRequirements: true);

  SessionEngine engine() => SessionEngine(
        battles: BattleEngine(stats: statsCalc, random: () => 0.5),
        progression: travesiaRules,
        random: mulberry32(3),
        seeds: () => 777,
        achievementsEnabled: false,
        gameMode: GameModeKind.travesia,
      );

  Future<SessionController> started() async {
    final c = SessionController(
      engine: engine(),
      store: InMemoryProfileStore(travesiaRules
          .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero'))),
      clock: const SessionClock(autoStart: false),
    );
    await c.start();
    expect(c.startRun(), isTrue);
    return c;
  }

  /// Para al grupo en el primer nodo de [type] del piso.
  void stopAt(SessionController c, RunNodeType type) {
    final r = c.session!.run!;
    r
      ..phase = RunPhase.stop
      ..node = RunRules.floorOf(r).nodes.firstWhere((n) => n.type == type).id;
  }

  test('ARMERÍA del mapa: abre y deja mejorar el arma con oro', () async {
    final c = await started();
    addTearDown(c.dispose);
    stopAt(c, RunNodeType.armeria);
    c.openPanel(WorldPanel.armory);
    // Antes se cerraba sola al emitir (solo valía en el pueblo).
    c.advance(0.05);
    expect(c.view!.panel, WorldPanel.armory);
    final me = c.session!.players[c.localId]!;
    me.profile = me.profile.copyWith(credits: 5000);
    final uid = me.profile.equippedUid ?? me.profile.items.first.uid;
    expect(c.engine.apply(c.session!, c.localId, UpgradeAction(uid, UpgradeStat.pow)),
        isNotNull);
  });

  test('TIENDA del mapa abre; DESCANSO no necesita panel', () async {
    final c = await started();
    addTearDown(c.dispose);
    stopAt(c, RunNodeType.tienda);
    c.openPanel(WorldPanel.armory);
    c.advance(0.05);
    expect(c.view!.panel, WorldPanel.armory);
    // Fuera de la parada se cierra.
    c.session!.run!.phase = RunPhase.map;
    c.advance(0.05);
    expect(c.view!.panel, isNull);
  });

  test('tecla I abre el inventario y C el personaje', () async {
    final c = await started();
    addTearDown(c.dispose);
    expect(c.handleKey(LogicalKeyboardKey.keyI), isTrue);
    expect(c.view!.panel, WorldPanel.inventory);
    expect(c.handleKey(LogicalKeyboardKey.keyI), isTrue);
    expect(c.view!.panel, isNull);
    expect(c.handleKey(LogicalKeyboardKey.keyC), isTrue);
    expect(c.view!.panel, WorldPanel.character);
    // Sin alijo.
    expect(c.openStash(), isFalse);
  });

  test('sin niveles: el personaje queda en nivel 1 y sin crecer', () async {
    final c = await started();
    addTearDown(c.dispose);
    final before = c.session!.players[c.localId]!.profile.attributes;
    final r = c.session!.run!;
    final far = RunRules.floorOf(r).nodes.lastWhere((n) => n.layer > 8);
    expect(c.voteRunNode(RunRules.reachable(r).first), isTrue);
    c.advance(0.05);
    r.node = far.id;
    final p = c.session!.players[c.localId]!;
    expect(p.profile.level, 1);
    expect(p.profile.attributes, before);
  });

  test('maná lleno al empezar cada pelea; vida y ULT siguen', () async {
    final c = await started();
    addTearDown(c.dispose);
    final p = c.session!.players[c.localId]!;
    p
      ..mp = 0
      ..hp = 10
      ..ult = 40;
    expect(c.voteRunNode(RunRules.reachable(c.session!.run!).first), isTrue);
    c.advance(0.05);
    expect(c.session!.mode, SessionMode.battle);
    final m = c.session!.battle!.state.party.first;
    expect(m.mp, m.maxMp);
    expect(m.hp, 10);
    expect(m.ult, 40);
  });

  test('habilidad nueva sin lugar: hay que sacrificar una libre', () {
    final e = engine();
    var s = e.create();
    s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
    s = act(e, s, 'p0', const RunStartAction());
    final r = s.run!;
    final full = [
      for (final id in GameCatalog.standard.skills.keys.take(30))
        if (!r.ownedSkills('p0').contains(id)) id
    ].take(RunTuning.freeSkillSlots).toList();
    r
      ..loadout['p0'] = [...full]
      ..phase = RunPhase.reward
      ..offers['p0'] = const RunOffer(extras: [
        RunExtra(RunExtraKind.habilidad, 1, skill: 'golpeEscudo'),
      ]);
    // Sin sacrificio: rechazado; la recompensa sigue abierta.
    expect(e.apply(s, 'p0', const RunRewardAction(extra: 0)), isNull);
    final step =
        e.apply(s, 'p0', RunRewardAction(extra: 0, drop: full.first))!;
    final eq = step.state.run!.loadout['p0']!;
    expect(eq, contains('golpeEscudo'));
    expect(eq, isNot(contains(full.first)));
    expect(eq.length, RunTuning.freeSkillSlots);
  });

  test('equipar / guardar habilidades libres y mejorarlas en la armería', () {
    final e = engine();
    var s = e.create();
    s = e.addPlayer(s, 'p0', newProfile('A', 'guerrero'))!.state;
    s = act(e, s, 'p0', const RunStartAction());
    final r = s.run!;
    r
      ..loadout['p0'] = ['golpeEscudo']
      ..skills['p0'] = [];
    s = act(e, s, 'p0', const RunSkillAction('golpeEscudo', equip: false));
    expect(s.run!.loadout['p0'], isEmpty);
    expect(s.run!.skills['p0'], ['golpeEscudo']);
    s = act(e, s, 'p0', const RunSkillAction('golpeEscudo', equip: true));
    expect(s.run!.loadout['p0'], ['golpeEscudo']);
    // Mejorar: solo en la armería.
    s.players['p0']!.profile =
        s.players['p0']!.profile.copyWith(credits: 9999);
    expect(e.apply(s, 'p0', const RunUpgradeSkillAction('golpeEscudo')),
        isNull);
    s.run!
      ..phase = RunPhase.stop
      ..node = RunRules.floorOf(s.run!)
          .nodes
          .firstWhere((n) => n.type == RunNodeType.armeria)
          .id;
    s = act(e, s, 'p0', const RunUpgradeSkillAction('golpeEscudo'));
    expect(s.run!.skillLevel('p0', 'golpeEscudo'), 1);
    expect(RunRules.skillScale(s.run!.skillUps['p0']!)['golpeEscudo'],
        closeTo(1 + RunTuning.skillUpPower, 1e-9));
  });

  test('acciones nuevas viajan por la red', () {
    for (final a in const <SessionAction>[
      RunBuyUltAction('x'),
      RunSkillAction('y', equip: true),
      RunUpgradeSkillAction('z'),
      RunRewardAction(extra: 1, drop: 'w'),
    ]) {
      final back = ActionJson.fromJson(ActionJson.toJson(a));
      expect(ActionJson.toJson(back), ActionJson.toJson(a));
    }
  });

  testWidgets('la recompensa dice OBJETOS (no ÁRBOL)', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await started();
    addTearDown(c.dispose);
    final r = c.session!.run!;
    r
      ..phase = RunPhase.reward
      ..offers[c.localId] = RunOffer(
          nodes: [c.engine.progression.treeRules.catalog.nodes.values
              .firstWhere((n) => n.kind != 'st' && n.pathId != null)
              .id]);
    c.advance(0.05);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RunScreen(view: c.view!, controller: c, onExit: () {}))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('OBJETOS'), findsOneWidget);
    expect(find.text('ÁRBOL'), findsNothing);
  });
}
