import 'package:echos_del_tiempo/app/theme/panel_frame.dart';
import 'package:echos_del_tiempo/app/theme/retro_theme.dart';
import 'package:echos_del_tiempo/features/endgame/presentation/atlas_view.dart';
import 'package:echos_del_tiempo/features/endgame/presentation/eco_portal_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/hud/world_hud.dart';
import 'package:echos_del_tiempo/features/world/presentation/panels/character_panel.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_controller.dart';
import 'package:echos_del_tiempo/features/world/presentation/session_view.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas.dart';
import 'package:echos_del_tiempo/game_engine/models/atlas_store.dart';
import 'package:echos_del_tiempo/game_engine/models/attributes.dart';
import 'package:echos_del_tiempo/game_engine/models/eco.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/profile_store.dart';
import 'package:echos_del_tiempo/game_engine/rules/inventory_rules.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../game_engine/session_test_helpers.dart';
import '../inventory/loot_fixtures.dart';
import '../panel_test_harness.dart';

/// Portal del Eco, Atlas, ficha de Eco y Maestría en el HUD
/// (docs/specs/ecos_atlas.md).
const _eco = EcoItem(
  uid: 'x',
  tier: 5,
  zone: 2,
  boss: 3,
  rarity: Rarity.raro,
  mods: [EcoModRoll('vida', 30), EcoModRoll('horda', 2)],
  floors: 2,
  seed: 5,
  name: 'Eco Hueco del Olvido',
);

PlayerProfile _hero(
    {bool unlocked = true,
    List<EcoItem> ecos = const [_eco],
    int mastery = 0,
    int xp = 0}) {
  final p = zoneProgression
      .normalize(PlayerProfile(name: 'Ana', classId: 'guerrero', level: 50));
  var q = zoneProgression.allocate(p, {Attribute.vit: p.points})!.copyWith(
      ecosUnlocked: unlocked, mastery: mastery, xp: xp);
  for (final e in ecos) {
    q = InventoryRules.addEco(q, e).$1;
  }
  return q;
}

Future<SessionController> _portal(WidgetTester tester, PlayerProfile p,
        {EcoPortalTab tab = EcoPortalTab.ecos, AtlasStore? atlas}) =>
    pumpPanel(tester,
        profile: p,
        engine: sessionEngine(zones: true),
        atlas: atlas,
        build: (v, c) =>
            EcoPortalPanel(view: v, controller: c, initialTab: tab));

void main() {
  testWidgets('ECOS: lista, ficha clara y ABRIR propone al grupo',
      (tester) async {
    final c = await _portal(tester, _hero());
    final uid = c.view!.me!.profile.ecos.single.uid;
    expect(find.byKey(ValueKey('eco-row-$uid')), findsOneWidget);
    final d = plain(tester, 'eco-detail');
    expect(d, contains('Eco Hueco del Olvido'));
    expect(d, contains('Tier 5'));
    expect(d, contains('monstruos nivel 58'));
    expect(d, contains('Zona: Bosque Hondo'));
    expect(d, contains('Jefe: Gólem Reloj'));
    expect(d, contains('Enemigos con +30% de vida'));
    expect(d, contains('+2 grupos por piso'));
    expect(d, contains('Botín: +18% cantidad · +6% rareza'));
    // Sin materiales: los crafteos dicen qué falta.
    expect(button(tester, 'eco-craft-tier').reason, 'Falta Ancla Temporal');
    expect(button(tester, 'eco-craft-reroll').reason, 'Falta Esquirla del Eco');
    // Sin devTools no hay atajos.
    expect(find.byKey(const ValueKey('eco-dev-1')), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('eco-open')));
    final s = c.session!;
    expect(s.vote?.missionId, 'eco');
    expect(s.eco?.uid, uid);
  });

  testWidgets('portal apagado: aviso y ABRIR bloqueado', (tester) async {
    await _portal(tester, _hero(unlocked: false));
    expect(find.textContaining('Portal apagado'), findsOneWidget);
    expect(button(tester, 'eco-open').reason, 'Vencé al Devorador de Eras');
  });

  testWidgets('sin Ecos: explica de dónde salen', (tester) async {
    await _portal(tester, _hero(ecos: const []));
    expect(find.textContaining('No tenés Ecos'), findsOneWidget);
    expect(find.byKey(const ValueKey('eco-open')), findsNothing);
  });

  testWidgets('ATLAS: puntos, ficha del nodo, tomar y reiniciar',
      (tester) async {
    final store = InMemoryAtlasStore(AtlasProgress(done: ['t1', 'z1', 'b1']));
    final c =
        await _portal(tester, _hero(), tab: EcoPortalTab.atlas, atlas: store);
    expect(find.byType(AtlasView), findsOneWidget);
    expect(plain(tester, 'atlas-points'), contains('Puntos libres 3'));
    expect(find.textContaining('3 puntos libres'), findsOneWidget);
    // Un nodo que no está unido: no se puede.
    await tapVisible(tester, find.byKey(const ValueKey('atlas-node-potencia')));
    expect(plain(tester, 'atlas-detail'), contains('Potencia'));
    expect(button(tester, 'atlas-take').reason, 'No está unido a tu Atlas');
    // Grietas: próximamente.
    await tapVisible(tester, find.byKey(const ValueKey('atlas-node-grieta')));
    expect(plain(tester, 'atlas-detail'), contains('Próximamente'));
    expect(find.byKey(const ValueKey('atlas-take')), findsNothing);
    // Tomar "Modificador Gratis".
    await tapVisible(tester, find.byKey(const ValueKey('atlas-node-gratis')));
    expect(button(tester, 'atlas-take').reason, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('atlas-take')));
    expect(c.atlas.nodes, ['gratis']);
    expect(c.session!.atlas, ['gratis'], reason: 'la sala usa este Atlas');
    expect(plain(tester, 'atlas-points'), contains('Puntos libres 1'));
    expect((await store.load()).nodes, ['gratis']);
    // Reiniciar es gratis.
    await tapVisible(tester, find.byKey(const ValueKey('atlas-reset')));
    expect(c.atlas.nodes, isEmpty);
    expect(c.atlas.done, {'t1', 'z1', 'b1'});
  });

  testWidgets('inventario: la ficha del Eco no rompe el panel', (tester) async {
    final c = await pumpPanel(tester,
        profile: _hero(),
        engine: sessionEngine(zones: true),
        build: (v, c) => CharacterPanel(
            view: v, controller: c, initialTab: CharacterTab.inventory));
    final p = c.view!.me!.profile;
    final uid = p.ecos.single.uid;
    final cell = InventoryRules.layout(p).cells.indexOf(uid);
    await tapVisible(tester, find.byKey(ValueKey('inv-cell-$cell')));
    expect(plain(tester, 'inv-eco-detail'), contains('Jefe: Gólem Reloj'));
    expect(find.byKey(const ValueKey('inv-compare')), findsNothing);
    expect(find.byKey(const ValueKey('inv-equip')), findsNothing);
    expect(find.byKey(const ValueKey('inv-drop')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HUD: con nivel 50 muestra la Maestría', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = SessionController(
      engine: sessionEngine(zones: true),
      store: InMemoryProfileStore(_hero(mastery: 3, xp: 4000)),
      clock: const SessionClock(autoStart: false),
    );
    addTearDown(c.dispose);
    await c.start();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionEngineProvider.overrideWithValue(sessionEngine(zones: true)),
        profileStoreProvider.overrideWithValue(InMemoryProfileStore()),
        sessionClockProvider
            .overrideWithValue(const SessionClock(autoStart: false)),
      ],
      child: MaterialApp(
        theme: RetroTheme.build(),
        home: Scaffold(body: WorldHud(view: c.view!, controller: c)),
      ),
    ));
    expect(c.view!.mode, SessionMode.lobby);
    expect(find.byKey(const ValueKey('hud-mastery-bar')), findsOneWidget);
    expect(find.textContaining('MAESTRIA 3 · XP 4000/21000'), findsOneWidget);
  });

  testWidgets('frente al portal: aviso y E abre el panel', (tester) async {
    final c = await _portal(tester, _hero());
    c.teleport(4.5 * 16, 3.5 * 16);
    await tester.pump();
    expect(c.nearPortal, isTrue);
    expect(c.view!.prompt, WorldPrompt.ecoPortal);
    c.interact();
    await tester.pump();
    expect(c.view!.panel, WorldPanel.ecoPortal);
    expect(find.widgetWithText(PanelButton, 'CERRAR [ESC]'), findsOneWidget);
  });
}
