import 'dart:io';

import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/ascension/domain/ascension_text.dart';
import 'package:echos_del_tiempo/features/ascension/presentation/ascension_cinematic.dart';
import 'package:echos_del_tiempo/features/ascension/presentation/ascension_panel.dart';
import 'package:echos_del_tiempo/features/ascension/presentation/ascension_views.dart';
import 'package:echos_del_tiempo/features/combat/presentation/game_sprites.dart';
import 'package:echos_del_tiempo/features/combat/presentation/sprite_catalog.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/ascension.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../inventory/loot_fixtures.dart';
import '../panel_test_harness.dart';

/// Estatua del Tiempo, elección, mini-árbol, cinemática y títulos
/// (docs/specs/ascension.md § 1-5).
PlayerProfile _hero(
    {int level = 30, Set<int> trials = const {}, String? asc}) {
  final p = zoneProgression
      .normalize(PlayerProfile(name: 'Ana', classId: 'maga', level: level));
  return zoneProgression.normalize(zoneProgression
      .allocate(p, {Attribute.esp: p.points})!
      .copyWith(ascension: AscensionProgress(trials: trials, id: asc)));
}

/// Un bundle que lee los PNG del disco; los que faltan fallan al cargar.
class _DiskBundle extends CachingAssetBundle {
  _DiskBundle(this.manifest);
  final String manifest;

  @override
  Future<ByteData> load(String key) async {
    final f = File(key);
    if (!f.existsSync()) throw FlutterError('falta $key');
    return ByteData.sublistView(f.readAsBytesSync());
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      key == SpriteCatalog.manifestPath ? manifest : super.loadString(key);
}

void main() {
  testWidgets('PRUEBAS: requisitos, ficha y PROPONER', (tester) async {
    final c = await pumpPanel(tester,
        profile: _hero(level: 29),
        engine: sessionEngine(zones: true),
        build: (v, c) => AscensionPanel(
            view: v, controller: c, initialTab: AscensionTab.trials));
    expect(find.byKey(const ValueKey('trial-row-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('trial-row-3')), findsOneWidget);
    final d = plain(tester, 'trial-detail');
    expect(d, contains('Prueba del Tiempo I · El Umbral'));
    expect(d, contains('Jefe: Gólem Reloj'));
    expect(d, contains('8% de vida'));
    expect(d, contains('+2 puntos de ascensión'));
    expect(button(tester, 'trial-propose').reason, 'Requiere nivel 30');
    expect(find.byKey(const ValueKey('trial-dev-1')), findsNothing);
    expect(c.session!.vote, isNull);
  });

  testWidgets('PRUEBAS: con nivel 30 PROPONER abre la votación',
      (tester) async {
    final c = await pumpPanel(tester,
        profile: _hero(),
        engine: sessionEngine(zones: true),
        build: (v, c) => AscensionPanel(
            view: v, controller: c, initialTab: AscensionTab.trials));
    await tapVisible(tester, find.byKey(const ValueKey('trial-propose')));
    expect(c.session!.vote?.missionId, 'trial');
    expect(c.session!.trial, 1);
  });

  testWidgets('ASCENSIÓN sin la Prueba I: aviso; con ella: las 2 tarjetas',
      (tester) async {
    await pumpPanel(tester,
        profile: _hero(),
        engine: sessionEngine(zones: true),
        build: (v, c) => AscensionPanel(
            view: v, controller: c, initialTab: AscensionTab.ascension));
    expect(find.byKey(const ValueKey('asc-choice')), findsNothing);

    final c = await pumpPanel(tester,
        profile: _hero(trials: {1}),
        engine: sessionEngine(zones: true),
        build: (v, c) => AscensionPanel(view: v, controller: c));
    expect(find.byKey(const ValueKey('asc-card-cronomante')), findsOneWidget);
    expect(find.byKey(const ValueKey('asc-card-elementalista')), findsOneWidget);
    expect(plain(tester, 'asc-card-cronomante'),
        allOf(contains('CRONOMANTE'), contains('Bucle Temporal'),
            contains('Acelerón'), contains('Detener el Tiempo')));
    await tapVisible(tester, find.byKey(const ValueKey('asc-choose-cronomante')));
    expect(c.session!.players[c.localId]!.profile.ascension.id, 'cronomante');
  });

  testWidgets('mini-árbol: tomar, puntos y reiniciar', (tester) async {
    final c = await pumpPanel(tester,
        profile: _hero(level: 40, trials: {1, 2}, asc: 'elementalista'),
        engine: sessionEngine(zones: true),
        build: (v, c) => AscensionPanel(view: v, controller: c));
    expect(find.byKey(const ValueKey('asc-tree')), findsOneWidget);
    expect(plain(tester, 'asc-points'), contains('Puntos libres 4'));
    await tapVisible(tester, find.byKey(const ValueKey('asc-node-elementalista_b1')));
    expect(plain(tester, 'asc-node-detail'), contains('Estallido Glacial'));
    await tapVisible(tester, find.byKey(const ValueKey('asc-take')));
    expect(c.session!.players[c.localId]!.profile.ascension.nodes,
        ['elementalista_b1']);
    await tester.pump();
    expect(plain(tester, 'asc-points'), contains('Puntos libres 3'));
    // b3 sin b2: no conectado.
    await tapVisible(tester, find.byKey(const ValueKey('asc-node-elementalista_b3')));
    expect(button(tester, 'asc-take').reason, 'No está conectado');
    await tapVisible(tester, find.byKey(const ValueKey('asc-reset')));
    expect(c.session!.players[c.localId]!.profile.ascension.nodes, isEmpty);
    await tapVisible(tester, find.byKey(const ValueKey('asc-change')));
    expect(c.session!.players[c.localId]!.profile.ascension.id, isNull);
  });

  Future<void> pumpCine(WidgetTester tester, {int? at, VoidCallback? done}) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: AscensionCinematic(
            key: UniqueKey(),
            playerName: 'Ana',
            classId: 'maga',
            ascensionId: 'cronomante',
            at: at,
            onDone: done),
      ),
    ));
  }

  testWidgets('cinemática: congela, transforma y muestra el cartel',
      (tester) async {
    await pumpCine(tester, at: 1200);
    expect(find.byKey(const ValueKey('asc-cinematic')), findsOneWidget);
    expect(find.byKey(const ValueKey('asc-banner')), findsNothing);
    await pumpCine(tester, at: 3200);
    expect(find.text('CRONOMANTE'), findsOneWidget);
    expect(find.text('ASCENSION'), findsOneWidget); // retroText sin tilde
    expect(find.text('Ana · Maga'), findsOneWidget);
  });

  testWidgets('cinemática: corre sola, se salta después de 1 s', (tester) async {
    var done = 0;
    await pumpCine(tester, done: () => done++);
    final state = tester.state<AscensionCinematicState>(
        find.byType(AscensionCinematic));
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.skip(), isFalse);
    await tester.pump(const Duration(milliseconds: 700));
    expect(state.skip(), isTrue);
    expect(done, 1);
    // Sin saltar termina a los 5.2 s.
    var done2 = 0;
    await pumpCine(tester, done: () => done2++);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: AscensionCinematicTiming.totalMs));
    expect(done2, 1);
  });

  testWidgets('elección suelta (resultado): ELEGIR llama con el id',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? chosen;
    await tester.pumpWidget(MaterialApp(
      theme: RetroTheme.build(),
      home: Scaffold(
        body: AscensionChoiceView(
            classId: 'paladin', sprites: null, onChoose: (id) => chosen = id),
      ),
    ));
    expect(find.byKey(const ValueKey('asc-card-templario')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('asc-choose-guardian')));
    expect(chosen, 'guardian');
  });

  testWidgets('HUD: título "Ana, Cronomante"', (tester) async {
    await pumpPanel(tester,
        profile: _hero(trials: {1}, asc: 'cronomante'),
        engine: sessionEngine(zones: true),
        build: (v, c) => WorldHud(view: v, controller: c));
    expect(plain(tester, 'hud-name-local'), contains('Ana, Cronomante'));
    expect(heroTitle('Bo', 'maga', 'berserker'), 'Bo',
        reason: 'de otra clase no vale');
    expect(heroSpriteId('maga', 'cronomante'), 'maga_cronomante');
  });

  testWidgets('sprites: sin el arte de la ascensión, cae al de la clase',
      (tester) async {
    final sprites = await tester.runAsync(() async {
      final bundle = _DiskBundle('''
characters:
  maga:
    idle: characters/maga/idle.png
  maga_cronomante:
    idle: characters/maga/no_existe.png
enemies: {}
''');
      return GameSprites.load(await SpriteCatalog.load(bundle: bundle));
    });
    final s = sprites!;
    final base = s.hero('maga');
    expect(base, isNotNull);
    expect(s.heroFor('maga', 'cronomante'), same(base));
    expect(s.heroFor('maga', null), same(base));
    expect(s.aura('cronomante'), isNull);
  });

  test('cada ascensión tiene color, sprite id y es de una clase', () {
    for (final a in kAscensions.values) {
      expect(ascensionHex(a), startsWith('#'));
      expect(heroSpriteId(a.classId, a.id), a.spriteId);
    }
  });

  test('WorldPanel tiene la estatua', () {
    expect(WorldPanel.values, contains(WorldPanel.ascension));
    expect(WorldPrompt.statue.label, '[E] Estatua del Tiempo');
  });
}
